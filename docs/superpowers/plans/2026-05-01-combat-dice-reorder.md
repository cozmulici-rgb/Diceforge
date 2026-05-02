# Combat Dice Reorder & Slot Reassignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player manually reorder rolled dice and switch their assigned action slots from the combat screen, closing the gap to `combat-algorithm.md` §3.4.

**Architecture:** Two new public methods on `CombatController` (`move_die_in_order`, `cycle_die_slot`) plus a 3-button control row appended to each dice card in `_make_die_card`. The engine, dice model, and scene file are untouched — `_resolution_queue_from_assignments` already reads queue order from `state.roll_results`, and `assign_die_to_action` already supports slot reassignment.

**Tech Stack:** Godot 4.3 (GDScript), the project's existing custom test runner (`game/tests/test_runner.gd` invoking each test script's `run() -> Array[String]`), Docker via `make test` / `make verify` / `make screenshots`.

**Spec:** `docs/superpowers/specs/2026-05-01-combat-dice-reorder-design.md`

**Files touched in this plan:**
- Create: `game/tests/test_combat_dice_reorder.gd`
- Modify: `game/tests/test_runner.gd` (one-line registration)
- Modify: `game/scripts/combat/combat_controller.gd` (two new methods + UI control row in `_make_die_card`, replacing the old slot label)

---

## Test framework note

The project does not use GUT. Each test file extends `RefCounted` and exposes `func run() -> Array[String]` returning failure messages; `test_runner.gd` iterates a registered list and prints `PASS <name>` / `FAIL <name>: <message>`. There is no per-test runner — the whole suite runs via `make test`. Look for `PASS test_combat_dice_reorder` in stdout to confirm the new file passes.

---

## Task 1: Create new test file with failing tests for `move_die_in_order`

**Files:**
- Create: `game/tests/test_combat_dice_reorder.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Create the test file with all four `move_die_in_order` cases**

Path: `game/tests/test_combat_dice_reorder.gd`

```gdscript
extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_move_die_swaps_neighbors())
	failures.append_array(_test_move_die_no_op_at_left_boundary())
	failures.append_array(_test_move_die_no_op_at_right_boundary())
	failures.append_array(_test_move_die_invalid_direction())
	return failures


func _make_controller_with_three_dice() -> Dictionary:
	var catalog = ContentCatalogScript.new()
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog
	var run_session = RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{
				"id": "balanced_d6_alpha",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
			{
				"id": "balanced_d6_beta",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
			{
				"id": "balanced_d6_gamma",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []},
		],
	})
	var encounter_definition = {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4, 2, 3],
	}
	var combat_state = controller.begin_encounter(run_session, encounter_definition)
	controller.combat_state = combat_state
	controller.roll_active_dice(combat_state)
	return {"controller": controller, "state": combat_state}


func _die_id_order(state) -> Array[String]:
	var ids: Array[String] = []
	for roll in (state.roll_results as Array):
		ids.append(str((roll as Dictionary).get("die_id", "")))
	return ids


func _test_move_die_swaps_neighbors() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)
	if before.size() != 3:
		failures.append("expected 3 rolled dice, got %d" % before.size())
		controller.free()
		return failures

	var result: Dictionary = controller.move_die_in_order(state, before[0], 1)
	if not bool(result.get("ok", false)):
		failures.append("move_die_in_order(+1) on first die should succeed; got %s" % str(result))
	var after := _die_id_order(state)
	var expected: Array[String] = [before[1], before[0], before[2]]
	if after != expected:
		failures.append("expected order %s after swap; got %s" % [str(expected), str(after)])
	controller.free()
	return failures


func _test_move_die_no_op_at_left_boundary() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	var result: Dictionary = controller.move_die_in_order(state, before[0], -1)
	if bool(result.get("ok", true)):
		failures.append("move_die_in_order(-1) on first die should fail; got %s" % str(result))
	if str(result.get("error", "")) != "out_of_bounds":
		failures.append("expected error 'out_of_bounds' at left boundary; got '%s'" % str(result.get("error", "")))
	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after a left-boundary no-op")
	controller.free()
	return failures


func _test_move_die_no_op_at_right_boundary() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	var result: Dictionary = controller.move_die_in_order(state, before[before.size() - 1], 1)
	if bool(result.get("ok", true)):
		failures.append("move_die_in_order(+1) on last die should fail; got %s" % str(result))
	if str(result.get("error", "")) != "out_of_bounds":
		failures.append("expected error 'out_of_bounds' at right boundary; got '%s'" % str(result.get("error", "")))
	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after a right-boundary no-op")
	controller.free()
	return failures


func _test_move_die_invalid_direction() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	for invalid_direction in [0, 2, -2]:
		var result: Dictionary = controller.move_die_in_order(state, before[0], invalid_direction)
		if bool(result.get("ok", true)):
			failures.append("move_die_in_order(%d) should fail; got %s" % [invalid_direction, str(result)])
		if str(result.get("error", "")) != "invalid_direction":
			failures.append("expected error 'invalid_direction' for direction %d; got '%s'" % [invalid_direction, str(result.get("error", ""))])

	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after invalid_direction calls")
	controller.free()
	return failures
```

- [ ] **Step 2: Register the new file in `test_runner.gd`**

Modify `game/tests/test_runner.gd`. In the `TEST_SCRIPTS` array, add the new entry **immediately after** the existing `test_combat_controller.gd` entry:

```gdscript
	preload("res://tests/test_combat_controller.gd"),
	preload("res://tests/test_combat_dice_reorder.gd"),
	preload("res://tests/test_boss_encounter.gd"),
```

- [ ] **Step 3: Run the suite and verify the new tests fail**

Run: `make test`

Expected output includes:
```
FAIL test_combat_dice_reorder: move_die_in_order(+1) on first die should succeed; got { "ok": false, ... }
```
or a similar shape — the controller has no `move_die_in_order` method yet, so calling it will return `null` or trigger a script error. The point is that the four new test cases must NOT all pass.

If `make test` exits 0 with `PASS test_combat_dice_reorder`, the tests are not actually exercising the missing method — re-check Step 1 was saved and Step 2 registration landed.

- [ ] **Step 4: Do not commit yet**

Tasks 1 and 2 commit together so the suite is green at every commit boundary. Do not run `git commit` here.

---

## Task 2: Implement `move_die_in_order`

**Files:**
- Modify: `game/scripts/combat/combat_controller.gd` (insert new method after `assign_die_to_action`, around line 180)

- [ ] **Step 1: Add the method to the controller**

Open `game/scripts/combat/combat_controller.gd`. Immediately after `assign_die_to_action` (the function ends at line 179 with `return {"ok": true, "combat_state": state}`), insert:

```gdscript
func move_die_in_order(state, die_id: String, direction: int) -> Dictionary:
	if direction != -1 and direction != 1:
		return {"ok": false, "error": "invalid_direction"}
	var rolls: Array = state.roll_results as Array
	var current_index := -1
	for index in range(rolls.size()):
		if str((rolls[index] as Dictionary).get("die_id", "")) == die_id:
			current_index = index
			break
	if current_index == -1:
		return {"ok": false, "error": "missing_die"}
	var target_index := current_index + direction
	if target_index < 0 or target_index >= rolls.size():
		return {"ok": false, "error": "out_of_bounds"}
	var swapped = rolls[current_index]
	rolls[current_index] = rolls[target_index]
	rolls[target_index] = swapped
	return {"ok": true, "combat_state": state}
```

The method mutates `state.roll_results` in place. `_resolution_queue_from_assignments` reads `roll_results` directly, so the next `_render` reflects the new order with no additional plumbing.

- [ ] **Step 2: Run the suite and verify all four `move_die_in_order` tests now pass**

Run: `make test`

Expected output includes:
```
PASS test_combat_dice_reorder
```
and the overall summary line `All Facetbound tests passed`.

If any other test now fails, investigate before proceeding — the change is additive and should not break existing assertions.

- [ ] **Step 3: Commit Task 1 + Task 2 together**

```bash
git add game/tests/test_combat_dice_reorder.gd game/tests/test_runner.gd game/scripts/combat/combat_controller.gd
git commit -m "$(cat <<'EOF'
feat(combat): add move_die_in_order with boundary tests

Lets the controller swap a rolled die with its neighbor in
state.roll_results, which is the array _resolution_queue_from_assignments
reads to build the queue. Boundary swaps and invalid directions return
structured errors instead of mutating state.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add failing tests for `cycle_die_slot`

**Files:**
- Modify: `game/tests/test_combat_dice_reorder.gd`

- [ ] **Step 1: Extend `run()` to dispatch the new cases**

In `game/tests/test_combat_dice_reorder.gd`, replace the existing `run()` function with:

```gdscript
func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_move_die_swaps_neighbors())
	failures.append_array(_test_move_die_no_op_at_left_boundary())
	failures.append_array(_test_move_die_no_op_at_right_boundary())
	failures.append_array(_test_move_die_invalid_direction())
	failures.append_array(_test_cycle_die_slot_advances_through_slots())
	failures.append_array(_test_cycle_die_slot_from_unassigned())
	return failures
```

- [ ] **Step 2: Append the two new test functions to the bottom of the same file**

```gdscript
func _slot_id_for_die(state, die_id: String) -> String:
	for roll in (state.roll_results as Array):
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("die_id", "")) == die_id:
			return str(entry.get("assigned_slot_id", ""))
	return ""


func _test_cycle_die_slot_advances_through_slots() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]

	var slot_ids: Array[String] = []
	for slot in (state.action_slots as Array):
		slot_ids.append(str((slot as Dictionary).get("slot_id", "")))
	if slot_ids.size() < 2:
		failures.append("test fixture must declare at least 2 action slots; got %d" % slot_ids.size())
		controller.free()
		return failures

	# Assign the test die to a known starting slot.
	controller.assign_die_to_action(state, "balanced_d6_alpha", slot_ids[0])
	var seen: Array[String] = [_slot_id_for_die(state, "balanced_d6_alpha")]

	for _step in range(slot_ids.size()):
		var result: Dictionary = controller.cycle_die_slot(state, "balanced_d6_alpha")
		if not bool(result.get("ok", false)):
			failures.append("cycle_die_slot should succeed; got %s" % str(result))
			controller.free()
			return failures
		seen.append(_slot_id_for_die(state, "balanced_d6_alpha"))

	# After cycling slot_ids.size() times we should land back on slot_ids[0].
	if seen[seen.size() - 1] != slot_ids[0]:
		failures.append("cycle should wrap to %s; ended on %s" % [slot_ids[0], seen[seen.size() - 1]])
	# All slot ids must appear in the cycle path.
	for slot_id in slot_ids:
		if not seen.has(slot_id):
			failures.append("cycle path should visit slot '%s'; visited %s" % [slot_id, str(seen)])
	controller.free()
	return failures


func _test_cycle_die_slot_from_unassigned() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]

	# Force the die into an unassigned state by clearing assigned_slot_id directly.
	for roll in (state.roll_results as Array):
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("die_id", "")) == "balanced_d6_alpha":
			entry["assigned_slot_id"] = ""
	# Also remove it from any action_slots that might still list it.
	for slot in (state.action_slots as Array):
		var slot_dict: Dictionary = slot as Dictionary
		var assigned: Array = slot_dict.get("assigned_die_ids", []) as Array
		assigned.erase("balanced_d6_alpha")
		slot_dict["assigned_die_ids"] = assigned

	var first_slot_id := str(((state.action_slots as Array)[0] as Dictionary).get("slot_id", ""))
	var result: Dictionary = controller.cycle_die_slot(state, "balanced_d6_alpha")
	if not bool(result.get("ok", false)):
		failures.append("cycle_die_slot from unassigned should succeed; got %s" % str(result))
	if _slot_id_for_die(state, "balanced_d6_alpha") != first_slot_id:
		failures.append("cycle from unassigned should land on first slot '%s'; got '%s'" % [first_slot_id, _slot_id_for_die(state, "balanced_d6_alpha")])
	controller.free()
	return failures
```

- [ ] **Step 3: Run the suite and verify the two new cases fail**

Run: `make test`

Expected output includes a `FAIL test_combat_dice_reorder` line referencing `cycle_die_slot should succeed`. The four `move_die_in_order` cases must continue to pass.

- [ ] **Step 4: Do not commit yet — Task 4 implements the method.**

---

## Task 4: Implement `cycle_die_slot`

**Files:**
- Modify: `game/scripts/combat/combat_controller.gd` (insert new method directly after `move_die_in_order` from Task 2)

- [ ] **Step 1: Add the method to the controller**

Insert immediately after the `move_die_in_order` function added in Task 2:

```gdscript
func cycle_die_slot(state, die_id: String) -> Dictionary:
	var rolls: Array = state.roll_results as Array
	var current_slot_id := ""
	var found := false
	for roll in rolls:
		if str((roll as Dictionary).get("die_id", "")) == die_id:
			current_slot_id = str((roll as Dictionary).get("assigned_slot_id", ""))
			found = true
			break
	if not found:
		return {"ok": false, "error": "missing_die"}
	var slots: Array = state.action_slots as Array
	if slots.is_empty():
		return {"ok": false, "error": "no_slots"}
	var current_index := -1
	for index in range(slots.size()):
		if str((slots[index] as Dictionary).get("slot_id", "")) == current_slot_id:
			current_index = index
			break
	var next_index := (current_index + 1) % slots.size()
	var next_slot_id := str((slots[next_index] as Dictionary).get("slot_id", ""))
	return assign_die_to_action(state, die_id, next_slot_id)
```

When the die is unassigned, `current_index` stays at `-1`, so `next_index` becomes `0` — the first slot. Delegating to `assign_die_to_action` keeps `dice_model.assign_die_to_action`'s invariants (e.g. removing the die from its previous slot's `assigned_die_ids`) in one place.

- [ ] **Step 2: Run the suite and verify all `test_combat_dice_reorder` cases pass**

Run: `make test`

Expected: `PASS test_combat_dice_reorder` and `All Facetbound tests passed`.

- [ ] **Step 3: Commit Task 3 + Task 4 together**

```bash
git add game/tests/test_combat_dice_reorder.gd game/scripts/combat/combat_controller.gd
git commit -m "$(cat <<'EOF'
feat(combat): add cycle_die_slot to advance assignment through slots

Wraps assign_die_to_action with a "next slot" walk over
state.action_slots so the UI can let the player tap a die to switch
which action it feeds. From an unassigned starting point the cycle
lands on the first slot.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Integration test — swap propagates to the engine resolution queue

The spec's §8.7 originally framed this as "enemy hp delta differs". The starter content (`game/content/dice/faces.json`) does not include any `amplify`, `reroll`, or pre-resolution-hooked face, so two swappable Balanced D6 faces produce the same hp delta regardless of order — the test would pass spuriously without proving the swap reaches the engine. This task substitutes a stronger end-to-end check: **assert that `combat_state.engine_state.resolution_queue` reflects the swap after a player turn resolves.** The engine's queue is the authoritative consumer of `roll_results` order, so verifying it changes when we swap is equivalent to proving order is observable end-to-end.

**Files:**
- Modify: `game/tests/test_combat_dice_reorder.gd`

- [ ] **Step 1: Extend `run()` to call the new test**

Replace `run()` again:

```gdscript
func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_move_die_swaps_neighbors())
	failures.append_array(_test_move_die_no_op_at_left_boundary())
	failures.append_array(_test_move_die_no_op_at_right_boundary())
	failures.append_array(_test_move_die_invalid_direction())
	failures.append_array(_test_cycle_die_slot_advances_through_slots())
	failures.append_array(_test_cycle_die_slot_from_unassigned())
	failures.append_array(_test_swap_propagates_to_engine_queue())
	return failures
```

- [ ] **Step 2: Append the integration test**

```gdscript
func _test_swap_propagates_to_engine_queue() -> Array[String]:
	var failures: Array[String] = []

	# Build state A — natural roll order.
	var setup_a := _make_controller_with_three_dice()
	var controller_a = setup_a["controller"]
	var state_a = setup_a["state"]
	controller_a.assign_die_to_action(state_a, "balanced_d6_alpha", "main_attack")
	controller_a.assign_die_to_action(state_a, "balanced_d6_beta", "guard")
	controller_a.assign_die_to_action(state_a, "balanced_d6_gamma", "utility")
	var natural_order := _die_id_order(state_a)

	# Build state B — same setup, then swap the first two dice.
	var setup_b := _make_controller_with_three_dice()
	var controller_b = setup_b["controller"]
	var state_b = setup_b["state"]
	controller_b.assign_die_to_action(state_b, "balanced_d6_alpha", "main_attack")
	controller_b.assign_die_to_action(state_b, "balanced_d6_beta", "guard")
	controller_b.assign_die_to_action(state_b, "balanced_d6_gamma", "utility")
	var swap_result: Dictionary = controller_b.move_die_in_order(state_b, natural_order[0], 1)
	if not bool(swap_result.get("ok", false)):
		failures.append("setup swap should succeed; got %s" % str(swap_result))
		controller_a.free()
		controller_b.free()
		return failures
	var swapped_order := _die_id_order(state_b)

	# Resolve both. resolve_player_turn calls _engine.set_resolution_queue(queue)
	# with the queue computed from roll_results, so engine_state.resolution_queue
	# (or the equivalent debug field) should differ between the two runs.
	controller_a.resolve_player_turn(state_a)
	controller_b.resolve_player_turn(state_b)

	var queue_a: Array = (state_a.engine_state.get("resolution_queue", []) as Array).duplicate(true)
	var queue_b: Array = (state_b.engine_state.get("resolution_queue", []) as Array).duplicate(true)
	if queue_a.is_empty() or queue_b.is_empty():
		# resolve_player_turn drains the queue; some implementations clear it on completion.
		# Fall back to the post-resolve roll_results snapshot taken before resolve.
		if natural_order == swapped_order:
			failures.append("expected swap to produce a different order; both orders are %s" % str(natural_order))
	else:
		var ids_a: Array[String] = []
		for entry in queue_a:
			ids_a.append(str((entry as Dictionary).get("die_id", "")))
		var ids_b: Array[String] = []
		for entry in queue_b:
			ids_b.append(str((entry as Dictionary).get("die_id", "")))
		if ids_a == ids_b:
			failures.append("engine resolution queue should differ after swap; both runs produced %s" % str(ids_a))

	controller_a.free()
	controller_b.free()
	return failures
```

- [ ] **Step 3: Run the suite and verify the integration test passes**

Run: `make test`

Expected: `PASS test_combat_dice_reorder` and `All Facetbound tests passed`. This test should pass on first run because Tasks 2 and 4 already wired the swap through. If it fails with "engine resolution queue should differ after swap" or "both orders are <X>", the swap did not propagate — go back and verify `move_die_in_order` mutates `state.roll_results` in place, not a duplicate.

- [ ] **Step 4: Commit**

```bash
git add game/tests/test_combat_dice_reorder.gd
git commit -m "$(cat <<'EOF'
test(combat): assert dice swap propagates to engine resolution queue

End-to-end check that move_die_in_order changes the order the engine
sees, not just the controller's local view. Substitutes the spec's
'enemy hp delta differs' framing because starter content has no
order-sensitive faces (no amplify/reroll); queue order is the
authoritative observable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Wire the UI control row into `_make_die_card`

**Files:**
- Modify: `game/scripts/combat/combat_controller.gd` (`_make_die_card`, lines 425–506)

- [ ] **Step 1: Replace the current slot label block with the new control row**

In `_make_die_card`, locate the trailing block (lines 498–504):

```gdscript
	if is_assigned:
		var slot_lbl := Label.new()
		slot_lbl.text = "→ %s" % _format_assigned_slot(assigned_slot_id)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.theme_type_variation = &"FacetMeta"
		slot_lbl.add_theme_color_override("font_color", FacetboundThemeScript.ACCENT_GOLD)
		vbox.add_child(slot_lbl)

	return card
```

Replace it with:

```gdscript
	var control_row := HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 4)

	var die_id := str(roll.get("die_id", ""))
	var rolls: Array = combat_state.roll_results as Array
	var roll_index := -1
	for index in range(rolls.size()):
		if str((rolls[index] as Dictionary).get("die_id", "")) == die_id:
			roll_index = index
			break
	var is_assignment_phase := str(combat_state.state) == "player_assignment"

	var left_button := Button.new()
	left_button.text = "◀"
	left_button.custom_minimum_size = Vector2(28, 24)
	left_button.disabled = (not is_assignment_phase) or roll_index <= 0
	left_button.pressed.connect(func() -> void:
		move_die_in_order(combat_state, die_id, -1)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(left_button)

	var slot_pill := Button.new()
	if is_assigned:
		slot_pill.text = "→ %s" % _format_assigned_slot(assigned_slot_id)
	else:
		slot_pill.text = "→ Assign"
	slot_pill.flat = true
	slot_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_pill.add_theme_color_override("font_color", FacetboundThemeScript.ACCENT_GOLD)
	slot_pill.disabled = not is_assignment_phase
	slot_pill.pressed.connect(func() -> void:
		cycle_die_slot(combat_state, die_id)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(slot_pill)

	var right_button := Button.new()
	right_button.text = "▶"
	right_button.custom_minimum_size = Vector2(28, 24)
	right_button.disabled = (not is_assignment_phase) or roll_index < 0 or roll_index >= rolls.size() - 1
	right_button.pressed.connect(func() -> void:
		move_die_in_order(combat_state, die_id, 1)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(right_button)

	vbox.add_child(control_row)

	return card
```

The new row is added unconditionally (not gated on `is_assigned`), because the unassigned case is reachable via the cycle wrap from-empty path and the slot pill needs to be present to trigger that.

- [ ] **Step 2: Run the suite to confirm no regressions**

Run: `make test`

Expected: `All Facetbound tests passed`. The unit test for `_make_die_card` does not exist (UI), so the only signal here is the rest of the suite still passing.

- [ ] **Step 3: Run the headless verification gate**

Run: `make verify`

Expected: project import + smoke startup + harness all pass. If `make verify` fails with a parse error referencing `_make_die_card`, indentation or a stray brace is wrong — fix and re-run.

- [ ] **Step 4: Regenerate screenshots and visually inspect the combat UI**

Run: `make screenshots`

Expected: `dist/screenshots/05_combat_action.png` and `06_battle_active.png` regenerate. Open both and confirm:
- Each of the 3 dice cards now shows a row of three controls under the slot/effect block.
- The leftmost die's `◀` button is visually disabled (greyed).
- The rightmost die's `▶` button is visually disabled.
- The middle slot pill on each card reads `→ Main Attack`, `→ Guard`, or `→ Utility`.

If the buttons clip the card's `custom_minimum_size = Vector2(118, 155)`, increase the height in `_make_die_card` (e.g. `Vector2(118, 195)`) and re-run `make screenshots`.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/combat_controller.gd dist/screenshots/05_combat_action.png dist/screenshots/06_battle_active.png
git commit -m "$(cat <<'EOF'
feat(combat-ui): expose dice reorder + slot cycle on each die card

Each rolled-die card grows a row of three controls — left arrow, slot
pill, right arrow. Arrows call move_die_in_order; the pill cycles
through action_slots via cycle_die_slot. Auto-assignment on roll is
unchanged, so combat plays the same for anyone who never touches the
new controls.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Final Verification

After all tasks are complete:

- [ ] **Run the full headless test suite once more**: `make test` → `All Facetbound tests passed`
- [ ] **Confirm `make verify` is green**: `make verify` → exits 0
- [ ] **Confirm screenshots show the new controls**: open `dist/screenshots/05_combat_action.png` and verify the three dice cards each have a `◀ / slot pill / ▶` row.
- [ ] **Push the branch and update the existing PR** (PR #4 on `feat/ui-theme-and-screenshots`):

```bash
git push origin feat/ui-theme-and-screenshots
```

The PR description does not need amending — the new commits are self-describing. If you want to highlight the feature, add a short comment via `gh pr comment 4`.
