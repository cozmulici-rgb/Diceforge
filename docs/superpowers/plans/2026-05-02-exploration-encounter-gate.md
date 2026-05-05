# Exploration Encounter Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block the player from leaving an encounter room until its encounter has been resolved. Affects only encounter rooms (rooms with a non-empty `encounter_id`); start, event, shop, reward, and already-completed rooms remain freely traversable.

**Architecture:** Defense in depth. (1) `GameStateCoordinator.enter_room` enforces the rule at the engine layer — any caller (controller, future automation, tests) gets a structured `encounter_unresolved` error. (2) `ExplorationController._refresh_primary_action` mirrors the rule in the UI by disabling the travel button and relabelling it ("Resolve current encounter first"), so the player gets immediate feedback rather than a silent rejection. The pure rule lives in the coordinator; the controller is a thin presenter on top.

**Tech Stack:** Godot 4.3-stable, GDScript, the project's existing `tests/test_runner.gd` headless harness (run via `make test` or `godot --headless --path game -s res://tests/test_runner.gd`).

**Spec:** none — this is a small bug-fix-shaped feature. Behavior summary inline below.

**Behavior matrix:**

| Current room state | Selected room | Expected outcome |
|---|---|---|
| `encounter_id == ""` (start/event/shop) | neighbor | Travel allowed |
| `encounter_id != ""`, `completed == false` | neighbor | Travel blocked; coordinator returns `encounter_unresolved`; UI shows disabled "Resolve current encounter first" button |
| `encounter_id != ""`, `completed == true` | neighbor | Travel allowed |
| any | itself (re-select current) | Existing "Enter Encounter" / "No Encounter In Current Room" behavior unchanged |
| any | non-neighbor | Existing "Select A Connected Node" / `invalid_room_transition` error unchanged |

---

## File Structure

- **Modify** `game/scripts/core/game_state_coordinator.gd` (function `enter_room`, ~lines 159-193) — add a guard right after the existing neighbor check that rejects transitions out of an unresolved encounter room.
- **Modify** `game/scripts/exploration/exploration_controller.gd` (function `_refresh_primary_action`, ~lines 436-461) — add a UI gate that disables and relabels the primary action button when the current room is an unresolved encounter and the selected room is a neighbor. No changes to `_on_primary_action_pressed`; the coordinator-level gate already handles the press defensively if the button were ever clicked.
- **Modify** `game/tests/test_exploration_flow.gd` — extend the existing test with two assertions: (a) leaving an unresolved encounter room returns `encounter_unresolved`, (b) after the encounter is resolved, the same transition succeeds.

No new files. No scene changes. No `project.godot` changes.

---

## Task 1: TDD the coordinator-level encounter gate

**Files:**
- Modify: `game/tests/test_exploration_flow.gd` — append two assertions inside the existing `run()` body.
- Modify: `game/scripts/core/game_state_coordinator.gd:159-193` — add the guard inside `enter_room`.

- [ ] **Step 1: Add the failing test assertions**

Edit `game/tests/test_exploration_flow.gd`. Find the block that begins:

```gdscript
	var encounter_result = coordinator.begin_encounter("tutorial_slime")
	if not encounter_result.get("ok", false):
		failures.append("begin_encounter should produce a stub encounter state")
		return failures
```

Immediately AFTER that block (so we still have an active, unresolved encounter on `floor_01_fight`), and BEFORE the existing line `if encounter_result.get("state", "") != "combat_active":`, insert:

```gdscript
	var blocked_move = coordinator.enter_room("floor_01_gallery")
	if blocked_move.get("ok", false):
		failures.append("leaving an unresolved encounter room should be blocked")
	if str(blocked_move.get("error", "")) != "encounter_unresolved":
		failures.append("expected encounter_unresolved error, got: %s" % str(blocked_move.get("error", "")))
	if str(blocked_move.get("from_room_id", "")) != "floor_01_fight":
		failures.append("encounter_unresolved error should report the source room")
	if coordinator.current_session.current_room_id != "floor_01_fight":
		failures.append("blocked enter_room must not mutate current_room_id")
```

Then find the line:

```gdscript
	var resolved_session = coordinator.apply_encounter_result({
```

After the `if resolved_session == null or resolved_session is Dictionary:` early-return block that follows it (look for the line `return failures` inside that `if`), insert this AFTER the early-return block:

```gdscript
	var post_clear_room_state: Dictionary = coordinator.current_session.room_states.get("floor_01_fight", {})
	if not bool(post_clear_room_state.get("completed", false)):
		failures.append("victory should mark the encounter room as completed")
	var allowed_move = coordinator.enter_room("floor_01_gallery")
	if not allowed_move.get("ok", false):
		failures.append("after resolving the encounter the same transition should be allowed: %s" % str(allowed_move.get("error", "")))
	if coordinator.current_session.current_room_id != "floor_01_gallery":
		failures.append("after the unblocked transition current_room_id should advance")
	# Restore expected state for the rest of the test.
	coordinator.current_session.current_room_id = "floor_01_fight"
```

The trailing `coordinator.current_session.current_room_id = "floor_01_fight"` resets state so the existing `complete_reward_flow` assertions further down still see the expected room. (The test continues with `open_reward_flow` and floor advance; those depend on routing being on `floor_01_fight`.)

- [ ] **Step 2: Run the test suite to confirm the new assertions fail**

Run:
```bash
make test
```

(Or, if Godot is on PATH locally: `godot --headless --path game -s res://tests/test_runner.gd`.)

Expected: `FAIL test_exploration_flow: leaving an unresolved encounter room should be blocked` (and the other related assertions). Other tests still pass.

- [ ] **Step 3: Implement the coordinator gate**

Edit `game/scripts/core/game_state_coordinator.gd`. Find `enter_room` (line 159). After the existing neighbor-check block:

```gdscript
	var current_room_id: String = str(current_session.current_room_id)
	if current_room_id != room_id and not _get_neighbor_ids(room_graph, current_room_id).has(room_id):
		return {
			"ok": false,
			"error": "invalid_room_transition",
			"from_room_id": current_room_id,
			"to_room_id": room_id,
		}
```

Add this block immediately AFTER the closing `}` of the dictionary (still inside `enter_room`, before the `current_session.current_room_id = room_id` line):

```gdscript
	if current_room_id != room_id:
		var current_room_definition = _get_room_definition(room_graph, current_room_id)
		var current_room_state: Dictionary = current_session.room_states.get(current_room_id, {})
		if str(current_room_definition.get("encounter_id", "")) != "" and not bool(current_room_state.get("completed", false)):
			return {
				"ok": false,
				"error": "encounter_unresolved",
				"from_room_id": current_room_id,
				"to_room_id": room_id,
			}
```

The outer `if current_room_id != room_id` short-circuits the case where `enter_room` is called with the same room as current (e.g., to re-acknowledge the start room) — the existing flow allows that.

- [ ] **Step 4: Run the test suite to confirm the new assertions pass**

Run:
```bash
make test
```

Expected: `PASS test_exploration_flow` and the existing test count is otherwise unchanged.

- [ ] **Step 5: Commit**

Write the message to `/tmp/encounter-gate-msg-1.txt`:

```
feat(exploration): block leaving an unresolved encounter room

GameStateCoordinator.enter_room now returns
{ok: false, error: "encounter_unresolved", from_room_id: ...} when
the source room has an encounter_id and the room has not been
marked completed. Start/event/shop/already-cleared rooms are
unaffected. UI wiring follows in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Then:

```bash
git add game/scripts/core/game_state_coordinator.gd game/tests/test_exploration_flow.gd
git commit -F /tmp/encounter-gate-msg-1.txt
```

(File-based commit message avoids HEREDOC quoting issues that have bitten this repo's commit pipeline before.)

---

## Task 2: Wire the UI feedback in the exploration controller

**Files:**
- Modify: `game/scripts/exploration/exploration_controller.gd:436-461` (`_refresh_primary_action`).

The coordinator-level gate already fully prevents the broken transition; this task is purely UX (so the button never looks active in a forbidden state).

- [ ] **Step 1: Add the UI gate**

Edit `game/scripts/exploration/exploration_controller.gd`. Find `_refresh_primary_action` (line 436). Locate the block that handles selecting the current room:

```gdscript
	if selected_id == current_id:
		if str(current_room.encounter_id) != "":
			primary_action_button.text = "Enter Encounter  ·  %s" % str(current_room.encounter_id).to_upper()
			return
		primary_action_button.disabled = true
		primary_action_button.text = "No Encounter In Current Room"
		return

	if _is_neighbor(current_room, selected_id):
		primary_action_button.text = "Travel To  ·  %s" % str(selected_room.display_name).to_upper()
		return
```

Insert a new gate BETWEEN the `if selected_id == current_id: ...` block and the `if _is_neighbor(...)` block:

```gdscript
	if str(current_room.encounter_id) != "" and not current_room.completed:
		primary_action_button.disabled = true
		primary_action_button.text = "Resolve Current Encounter First"
		return
```

The placement matters:
- If the user has selected the current room itself, the earlier branch already handled it (with "Enter Encounter" — which is exactly what they SHOULD do here).
- If the user has selected a neighbor (or non-neighbor), we now block before the "Travel To" / "Select A Connected Node" branches.
- The `is_paused` early-return at the top of the function is unchanged and still wins (combat-in-progress overrides everything).

- [ ] **Step 2: Run the test suite**

Run:
```bash
make test
```

Expected: all tests still pass. The UI logic isn't unit-tested, but we're verifying we haven't broken existing tests by editing the file.

- [ ] **Step 3: Run headless validation**

Run:
```bash
make verify
```

Expected: passes with no parse or runtime errors.

- [ ] **Step 4: Commit**

Write the message to `/tmp/encounter-gate-msg-2.txt`:

```
feat(exploration): UI gate for unresolved encounter rooms

When the current room has an unresolved encounter and the player
selects a neighbor on the map, the primary action button is now
disabled and labelled "Resolve Current Encounter First". The
coordinator-level guard remains the source of truth; this is UX
feedback so the button never looks clickable in a forbidden state.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Then:

```bash
git add game/scripts/exploration/exploration_controller.gd
git commit -F /tmp/encounter-gate-msg-2.txt
```

---

## Task 3: Manual verification

This task has no code changes. It documents the manual play-tests that the unit test cannot cover (button rendering, click behavior, labels).

**Files:** none

- [ ] **Step 1: Build and launch the game in the browser-viewable Docker session**

Run:
```bash
make gui
```

Then open `http://localhost:6080/vnc.html` in a browser.

- [ ] **Step 2: Verify the gate triggers on an unresolved encounter**

1. Start a new run from the archetype menu. The exploration screen renders with the start room as current.
2. Click the first encounter room neighbor (e.g. `floor_01_fight`). The primary action says "Travel To  ·  ...". Click it. You're now in the encounter room.
3. The current room (`floor_01_fight`) has an encounter and is not yet completed.
4. Click another neighbor on the map (e.g. `floor_01_gallery` or `floor_01_vault`).
5. Expected: the primary action button is **disabled** and says **"Resolve Current Encounter First"**.

- [ ] **Step 3: Verify clicking the current room still enters the encounter**

1. Continuing from step 2, click the current room (`floor_01_fight`) on the map.
2. Expected: the primary action button is enabled and says "Enter Encounter  ·  TUTORIAL_SLIME".
3. Click it. Combat begins.

- [ ] **Step 4: Verify the gate clears after winning the encounter**

1. Win the combat encounter and proceed through the reward flow (or continue) back to the exploration screen.
2. The room `floor_01_fight` should now be marked CLEARED in the room metadata.
3. Click a neighbor (e.g. `floor_01_gallery`).
4. Expected: the primary action button is **enabled** and says "Travel To  ·  ...". Click it. The transition succeeds.

- [ ] **Step 5: Verify the gate does NOT trigger from non-encounter rooms**

1. Start a new run.
2. From the start room (no encounter), click any neighbor.
3. Expected: the primary action button is **enabled** and says "Travel To  ·  ...". The gate must not affect non-encounter rooms.

- [ ] **Step 6: Document the result**

If any step fails, file the symptom in the commit message of a follow-up fix or open an issue. If everything passes, no commit is needed for this task — the manual verification is logged here in the plan.
