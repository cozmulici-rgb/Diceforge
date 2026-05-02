# Combat Dice Reorder & Slot Reassignment — Design

## 1. Problem

The current combat prototype rolls dice and immediately auto-assigns each one to an action slot via `_default_slot_for_roll` (`game/scripts/combat/combat_controller.gd:851`). The dice cards and resolution-queue rows render as read-only `PanelContainer`s with no input handling, so the player has no way to change which slot a die targets or in what order assigned dice resolve. This contradicts §3.4 of `docs/design/combat-algorithm.md`, which states "let the player choose the exact order of resolution."

The model layer already supports both operations:
- `assign_die_to_action(state, die_id, action_slot_id)` (`combat_controller.gd:170`) reassigns a die to a different slot.
- `_resolution_queue_from_assignments` (`combat_controller.gd:1008`) builds the queue by iterating `state.roll_results` in array order, so reordering the queue is equivalent to mutating the order of `state.roll_results`.

The gap is exclusively in the view layer.

## 2. Goals

- Let the player change the order in which assigned dice resolve, after rolling and before pressing Resolve.
- Let the player reassign any rolled die to a different action slot (Main Attack / Guard / Utility) after rolling.
- Preserve the current auto-assignment-on-roll default so a player who never touches the new controls plays the same combat they do today.
- Cover the new behavior with deterministic tests in `game/tests/`.

## 3. Non-Goals

- Drag-and-drop interaction. Buttons are sufficient and avoid Godot's drag-target/preview state machine.
- Skip-die / unassign toggle. Out of scope for this change; revisit later if needed.
- Within-slot ordering as a separate axis. Resolution order is `roll_results` order (filtered to assigned dice); changing that array is the only ordering knob.
- Engine, dice model, or scene-file changes. All work stays inside `combat_controller.gd` and the test suite.
- Autoplay-heuristic changes. The autoplay path (`autoplay_heuristic.gd`) is unaffected.

## 4. Architecture

All changes are confined to two files:

- `game/scripts/combat/combat_controller.gd` — adds two public methods, augments `_make_die_card` with a 3-button control row, wires button signals.
- `game/tests/test_combat_controller.gd` — adds new test cases.

No changes to:
- `game/scripts/combat/combat_engine.gd`
- `game/scripts/combat/dice_resolver.gd`
- `game/scripts/combat/autoplay_heuristic.gd`
- `game/scenes/screens/combat_screen.tscn` (the dice row and queue list are populated imperatively from the controller)

## 5. New Controller Methods

### 5.1 `move_die_in_order(state, die_id: String, direction: int) -> Dictionary`

Swap `die_id`'s entry in `state.roll_results` with its neighbor at offset `direction` (`-1` for left, `+1` for right).

- Locate the die's current index in `state.roll_results`.
- If the die is missing, return `{"ok": false, "error": "missing_die"}`.
- If `direction` is not `-1` or `+1`, return `{"ok": false, "error": "invalid_direction"}`.
- If the swap target index is `< 0` or `>= roll_results.size()`, return `{"ok": false, "error": "out_of_bounds"}` (no-op at boundaries).
- Otherwise swap the two entries in place (operating on `state.roll_results` itself, not a duplicated list, so the controller's `_render` reads the updated state on the same call).
- Return `{"ok": true, "combat_state": state}`.

The method does not touch `state.action_slots` because slot membership is unchanged by reordering. `_resolution_queue_from_assignments` reads `roll_results` directly, so the queue reflects the new order on the next `_render`.

### 5.2 `cycle_die_slot(state, die_id: String) -> Dictionary`

Advance the die's `assigned_slot_id` to the next slot in `state.action_slots`, wrapping back to the first slot.

- Locate the die's roll entry; if missing, return `{"ok": false, "error": "missing_die"}`.
- Read the slot id list from `state.action_slots` (each entry has a `slot_id` field). If `state.action_slots` is empty, return `{"ok": false, "error": "no_slots"}`.
- Find the index of the die's current `assigned_slot_id` in the slot list. If the die is currently unassigned (empty slot id), treat the index as `-1` so the wrap math advances to slot index `0`.
- Compute `next_index = (current_index + 1) % slot_count`.
- Delegate to the existing `assign_die_to_action(state, die_id, next_slot_id)` so that `dice_model.assign_die_to_action` enforces whatever assignment invariants it already enforces (e.g., removing the die from its previous slot's `assigned_die_ids`).
- Return the result of `assign_die_to_action`.

This method intentionally cycles only through slots that exist in the current run state; it does not hard-code `main_attack`/`guard`/`utility`.

## 6. UI Changes in `_make_die_card`

`_make_die_card` (`combat_controller.gd:425`) currently builds a vertical card with: die name, value pill, face label, effect label, energy cost, and (if assigned) a slot label. The slot label becomes interactive and a control row is appended.

### 6.1 Control row

Append a `HBoxContainer` to `vbox` after the existing slot label. It contains three children, in order:

1. **Left button** — `Button` with text `◀`, `custom_minimum_size = Vector2(28, 24)`. Disabled if the die is the first entry in `combat_state.roll_results`. On `pressed`, call `move_die_in_order(combat_state, die_id, -1)` then `combat_state_updated.emit(combat_state); _render()`.
2. **Slot pill** — `Button` with text `→ <slot display name>`, `size_flags_horizontal = SIZE_EXPAND_FILL`, flat styled to read like the existing slot label. On `pressed`, call `cycle_die_slot(combat_state, die_id)` then `combat_state_updated.emit(combat_state); _render()`. If the die is unassigned (no `assigned_slot_id`), the button reads `→ Assign` and clicking it assigns to the first slot.
3. **Right button** — `Button` with text `▶`. Disabled if the die is the last entry in `combat_state.roll_results`. On `pressed`, call `move_die_in_order(combat_state, die_id, +1)` then `combat_state_updated.emit(combat_state); _render()`.

All three buttons set `disabled = true` when `str(combat_state.state) != "player_assignment"` so the player cannot reorder during the enemy turn or before rolling.

### 6.2 Replacing the existing slot label

The current `slot_lbl` (`combat_controller.gd:498-504`) is removed. Its information lives in the new slot pill.

### 6.3 Re-render after every interaction

Each button handler emits `combat_state_updated` and calls `_render()`. `_render` already calls `_rebuild_dice_cards()` and `_rebuild_queue_rows()`, so the queue panel updates without extra work.

## 7. Auto-Assignment Stays the Default

`_on_roll_pressed` (`combat_controller.gd:780`) still calls `_default_slot_for_roll` for every freshly rolled die. The new controls only adjust state after that initial assignment. If the player never presses any of the new buttons, combat plays exactly as before.

## 8. Tests

Add to `game/tests/test_combat_controller.gd` (or create a sibling file if the existing file is already large — check size during implementation and split if it's nearing 500 lines):

1. `test_move_die_in_order_swaps_neighbors` — given three rolled dice in known order, calling `move_die_in_order(state, dice[0].die_id, +1)` produces `roll_results` with dice[1], dice[0], dice[2] in that order.
2. `test_move_die_in_order_no_op_at_left_boundary` — `move_die_in_order(state, dice[0].die_id, -1)` returns `{"ok": false, "error": "out_of_bounds"}` and leaves `roll_results` unchanged.
3. `test_move_die_in_order_no_op_at_right_boundary` — symmetric for the rightmost die with `+1`.
4. `test_move_die_in_order_invalid_direction` — `direction = 0` or `direction = 2` returns `{"ok": false, "error": "invalid_direction"}`.
5. `test_cycle_die_slot_advances_through_slots` — starting from the auto-assigned slot, calling `cycle_die_slot` `slot_count` times returns the die to the original slot. Each intermediate call lands on a different slot id in the `action_slots` list.
6. `test_cycle_die_slot_from_unassigned` — manually clear a die's `assigned_slot_id` to `""`, call `cycle_die_slot`, expect the die to land on the first slot.
7. `test_resolution_order_changes_outcome` — set up two rolled dice where ordering matters end-to-end (e.g. an `amplify` face and a `damage` face). Build combat state A, run `resolve_player_turn`, capture enemy hp delta. Build a separate fresh combat state B with the same dice, call `move_die_in_order` to swap the two dice, run `resolve_player_turn`, and assert the enemy hp delta differs. This is the integration test that proves order is observable.

Existing tests must continue to pass without modification.

## 9. Verification

1. `make test` passes (existing suite plus the new cases).
2. `make verify` passes (Godot import + headless smoke).
3. `make screenshots` regenerates `dist/screenshots/05_combat_action.png` and `06_battle_active.png` showing the new ◀ / slot pill / ▶ row under each dice card.
4. Optional manual: extend `scripts/take_screenshots.sh` with one `xdotool` click on the `▶` button of the first dice card and capture an `08_reordered.png` to demonstrate the queue panel reflects the swap. Skipped if it adds non-trivial coordinate-tweaking effort; it is not gating.

## 10. Out-of-Scope Risks (acknowledged, not solved here)

- The autoplay heuristic still produces its own ordering when no manual interaction occurs; this design does not unify the two paths. Manual ordering only applies when the player presses Resolve directly without invoking autoplay.
- Slot cycling is wrap-only and does not surface "currently incompatible" slots (e.g., a slot that has reached its capacity). If `dice_model.assign_die_to_action` rejects the next slot, the cycle stops at the rejection and the slot pill text does not update. A future iteration may skip past unassignable slots; that's beyond this change.

## 11. Delivery

One commit (or a small fan of commits) on `feat/ui-theme-and-screenshots`, or a fresh branch — to be decided when the implementation plan is created.
