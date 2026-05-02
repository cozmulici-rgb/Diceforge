# Named Run Saves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-slot run save with a multi-slot system where each "New Run" creates a separately-stored, auto-named save resumable from a Continue popup that supports rename and delete.

**Architecture:** `PersistenceService` already supports multi-slot reads/writes. We add `slot_id` and `display_name` to the run state, generate fresh slot ids on session creation, and route auto-save / cleanup through `current_session.slot_id` instead of a shared constant. Daily Void uses its own per-day slot id (`daily_<YYYY_MM_DD>`) so it never collides with named runs. The Start Menu gains a "Continue" menu row that opens a popup dialog listing resumable saves with Resume / Rename / Delete actions.

**Tech Stack:** Godot 4.3 / GDScript. Headless tests live under `game/tests/test_*.gd` and are registered in `game/tests/test_runner.gd`. Each test script defines `run() -> Array[String]` returning failure messages.

---

## File Structure

**New files:**
- `game/scripts/screens/continue_runs_dialog.gd` — popup dialog logic + UI build
- `game/tests/test_named_run_saves.gd` — coverage for slot lifecycle, rename/delete, migration, daily isolation

**Modified files:**
- `game/scripts/persistence/save_schema.gd` — require `slot_id` and `display_name` on run state
- `game/scripts/persistence/save_slot_summary.gd` — add `display_name`
- `game/scripts/persistence/persistence_service.gd` — rename `delete_corrupt_run_state` → `delete_run_state`; populate `display_name` in summaries
- `game/scripts/core/run_session.gd` — add `slot_id` and `display_name`
- `game/scripts/core/game_state_coordinator.gd` — generate `slot_id`/`display_name`, persist by current slot, add `list_resumable_runs` / `rename_run` / `delete_run`, legacy migration, daily slot id
- `game/scripts/screens/start_menu_controller.gd` — `configure` takes `resumable_summaries: Array`; add Continue menu row + signal; remove inline `ContinueStrip` from controller wiring
- `game/scenes/screens/start_menu.tscn` — drop the inline `ContinueStrip` and `ContinueSpacer` nodes (cleanup)
- `game/scripts/app_root.gd` — wire Continue popup, refresh after rename/delete
- `game/tests/test_runner.gd` — register new test script
- `game/tests/test_persistence_service.gd` — switch to renamed `delete_run_state`

---

## Task 1: Add `display_name` to `SaveSlotSummary`

**Files:**
- Modify: `game/scripts/persistence/save_slot_summary.gd`

- [ ] **Step 1: Add `display_name` field, constructor read, and dictionary export**

Replace the contents of `game/scripts/persistence/save_slot_summary.gd` with:

```gdscript
class_name SaveSlotSummary
extends RefCounted

var slot_id: String
var session_id: String
var archetype_id: String
var display_name: String
var floor_index: int
var room_id: String
var updated_at_unix: int
var is_corrupt: bool


func _init(data: Dictionary = {}) -> void:
	slot_id = str(data.get("slot_id", ""))
	session_id = str(data.get("session_id", ""))
	archetype_id = str(data.get("archetype_id", ""))
	display_name = str(data.get("display_name", ""))
	floor_index = int(data.get("floor_index", 0))
	room_id = str(data.get("room_id", ""))
	updated_at_unix = int(data.get("updated_at_unix", 0))
	is_corrupt = bool(data.get("is_corrupt", false))


func to_dictionary() -> Dictionary:
	return {
		"slot_id": slot_id,
		"session_id": session_id,
		"archetype_id": archetype_id,
		"display_name": display_name,
		"floor_index": floor_index,
		"room_id": room_id,
		"updated_at_unix": updated_at_unix,
		"is_corrupt": is_corrupt,
	}
```

- [ ] **Step 2: Run tests — they should still pass**

Run: `make test`
Expected: PASS (unchanged behavior — new field defaults to empty string).

- [ ] **Step 3: Commit**

```bash
git add game/scripts/persistence/save_slot_summary.gd
git commit -m "feat(persistence): add display_name to SaveSlotSummary"
```

---

## Task 2: Add `slot_id` and `display_name` to `RunSession`

**Files:**
- Modify: `game/scripts/core/run_session.gd`

- [ ] **Step 1: Add the two properties to constructor and dictionary**

Edit `game/scripts/core/run_session.gd`. After the existing `var session_id: String` declaration block, add the two new properties at the top of the var list:

```gdscript
var slot_id: String
var display_name: String
```

In `_init`, after `session_id = str(data.get("session_id", ""))`, add:

```gdscript
	slot_id = str(data.get("slot_id", ""))
	display_name = str(data.get("display_name", ""))
```

In `to_dictionary()`, add these two entries directly after the `"session_id"` entry:

```gdscript
		"slot_id": slot_id,
		"display_name": display_name,
```

- [ ] **Step 2: Run tests — should still pass**

Run: `make test`
Expected: PASS. Existing tests don't read these fields, and `to_dictionary` round-trips with empty strings.

- [ ] **Step 3: Commit**

```bash
git add game/scripts/core/run_session.gd
git commit -m "feat(core): add slot_id and display_name to RunSession"
```

---

## Task 3: Generalize PersistenceService delete + populate display_name

**Files:**
- Modify: `game/scripts/persistence/persistence_service.gd`
- Modify: `game/tests/test_persistence_service.gd`

- [ ] **Step 1: Update existing test to call new method name**

In `game/tests/test_persistence_service.gd`, replace lines 47–49:

```gdscript
	var delete_result = service.delete_run_state("corrupt_slot")
	if not delete_result.get("ok", false):
		failures.append("delete_run_state should remove an invalid save slot")
```

- [ ] **Step 2: Run tests to confirm the rename hasn't been applied yet**

Run: `make test`
Expected: FAIL (`PersistenceService` still has `delete_corrupt_run_state`, so the test reports a missing method).

- [ ] **Step 3: Rename method and surface display_name in summaries**

In `game/scripts/persistence/persistence_service.gd`:

- Rename `delete_corrupt_run_state` to `delete_run_state` (function declaration only — body unchanged).
- In `list_run_slots()`, inside the `else:` branch where the summary is built, add the `display_name` field. Replace the existing summary construction so the dict passed to `SaveSlotSummaryScript.new(...)` reads:

```gdscript
				summaries.append(SaveSlotSummaryScript.new({
					"slot_id": slot_id,
					"session_id": str(data.get("session_id", "")),
					"archetype_id": str(data.get("archetype_id", "")),
					"display_name": str(data.get("display_name", "")),
					"floor_index": int(data.get("floor_index", 0)),
					"room_id": str(data.get("current_room_id", "")),
					"updated_at_unix": int(data.get("updated_at_unix", Time.get_unix_time_from_system())),
					"is_corrupt": not save_schema.validate_run_state(data, content_catalog).get("ok", false),
				}).to_dictionary())
```

- [ ] **Step 4: Run tests to confirm green**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/persistence/persistence_service.gd game/tests/test_persistence_service.gd
git commit -m "feat(persistence): rename delete_corrupt_run_state to delete_run_state and surface display_name"
```

---

## Task 4: Schema validation + per-session slot id + legacy migration

This task is intentionally a single cluster because schema validation, slot generation, and persistence routing all break atomically: turning on schema validation without populating the fields would reject every freshly-created run.

**Files:**
- Modify: `game/scripts/persistence/save_schema.gd`
- Modify: `game/scripts/core/game_state_coordinator.gd`

### Step group A — schema and coordinator

- [ ] **Step 1: Require `slot_id` and `display_name` in the run schema**

In `game/scripts/persistence/save_schema.gd`, edit the `REQUIRED_RUN_FIELDS` constant. Add `"slot_id"` and `"display_name"` to the array (place them right after `"session_id"`):

```gdscript
const REQUIRED_RUN_FIELDS := [
	"schema_version",
	"session_id",
	"slot_id",
	"display_name",
	"archetype_id",
	"floor_index",
	"current_room_id",
	"room_graph_id",
	"player_state",
	"active_dice",
	"inventory",
	"mode_id",
	"seed_id",
	"numeric_seed",
	"daily_void_config",
	"score_summary",
]
```

- [ ] **Step 2: Replace the active-slot constant with slot id helpers in the coordinator**

In `game/scripts/core/game_state_coordinator.gd`:

- Delete line 30: `const ACTIVE_RUN_SLOT := "active_run"`.
- After the `last_recovery_message := ""` declaration, add a small helper section. Insert these helper functions just above the closing `func _init` at the top of the file (or grouped with other helpers near the end):

```gdscript
const _LEGACY_ACTIVE_SLOT_ID := "active_run"


func _generate_run_slot_id(archetype_id: String) -> String:
	var unix_now: int = int(Time.get_unix_time_from_system())
	var safe_archetype: String = archetype_id.replace("-", "_").substr(0, 16)
	var base_id: String = "run_%d_%s" % [unix_now, safe_archetype]
	var candidate: String = base_id
	var suffix: int = 2
	while persistence_service.run_slot_exists(candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate


func _generate_daily_slot_id(calendar_day: String) -> String:
	return "daily_%s" % calendar_day.replace("-", "_")


func _format_run_display_name(archetype: Dictionary) -> String:
	var archetype_name: String = str(archetype.get("name", archetype.get("id", "Run")))
	var ts: String = "%s %s" % [Time.get_date_string_from_system(), Time.get_time_string_from_system().substr(0, 5)]
	return "%s · %s" % [archetype_name, ts]


func _format_daily_display_name(calendar_day: String) -> String:
	return "Daily Void · %s" % calendar_day
```

- [ ] **Step 3: Add `run_slot_exists` to `PersistenceService`**

In `game/scripts/persistence/persistence_service.gd`, add this method just below `_run_slot_path`:

```gdscript
func run_slot_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(_run_slot_path(slot_id))
```

- [ ] **Step 4: Populate `slot_id` and `display_name` on standard session creation**

In `game/scripts/core/game_state_coordinator.gd`, modify `create_run_session`. After the line `_session_sequence += 1` (around line 54), insert:

```gdscript
	var generated_slot_id: String = _generate_run_slot_id(archetype_id)
	var generated_display_name: String = _format_run_display_name(archetype)
```

Then in the dictionary passed to `RunSessionScript.new({...})`, add the two new fields right after `"session_id"`:

```gdscript
		"session_id": "run_%03d_%s" % [_session_sequence, archetype_id],
		"slot_id": generated_slot_id,
		"display_name": generated_display_name,
```

- [ ] **Step 5: Re-slot the daily session and clean up the inner standard slot**

`create_daily_void_session` calls `create_run_session(archetype_id)` first, which already generated a standard slot id and wrote one save to disk. After the daily overrides apply, the session needs to move to a daily slot id, and the standard slot file must be removed.

In `create_daily_void_session`, immediately after the inner call returns successfully (right after `if session == null or session is Dictionary: return session` at around line 117), capture the inner slot id:

```gdscript
	var temp_standard_slot_id: String = str(session.slot_id)
```

Then, after the line that currently sets `session.session_id = "daily_%s_%s" % [...]`, set the daily slot id and display name and remove the temporary standard-slot file:

```gdscript
	session.slot_id = _generate_daily_slot_id(target_day)
	session.display_name = _format_daily_display_name(target_day)
	if temp_standard_slot_id != "" and temp_standard_slot_id != session.slot_id:
		persistence_service.delete_run_state(temp_standard_slot_id)
```

- [ ] **Step 6: Persist by current session slot id and rename the cleanup helper**

Replace `_persist_current_session()` and `_clear_active_run_slot()` near the bottom of `game_state_coordinator.gd` with:

```gdscript
func _persist_current_session() -> void:
	if current_session == null or current_session.run_complete:
		return
	if str(current_session.slot_id) == "":
		return
	var payload = current_session.to_dictionary()
	payload["updated_at_unix"] = Time.get_unix_time_from_system()
	persistence_service.save_run_state(current_session.slot_id, payload)


func _clear_current_run_slot() -> void:
	if current_session == null or str(current_session.slot_id) == "":
		return
	persistence_service.delete_run_state(current_session.slot_id)
```

Update the two call sites that previously called `_clear_active_run_slot()` (lines 284 and 392) to call `_clear_current_run_slot()`.

- [ ] **Step 7: Update `load_run_session` to use the new delete name**

In `game/scripts/core/game_state_coordinator.gd`, line 152 currently calls `persistence_service.delete_corrupt_run_state(save_slot_id)`. Replace with:

```gdscript
			persistence_service.delete_run_state(save_slot_id)
```

- [ ] **Step 8: Replace `get_continue_run_summary` with most-recent-resumable lookup**

Replace the body of `get_continue_run_summary()` at the bottom of `game_state_coordinator.gd` so it returns the most recently updated non-daily resumable slot (preserves the existing app-root caller until Task 6 swaps it):

```gdscript
func get_continue_run_summary() -> Dictionary:
	var best: Dictionary = {}
	var best_unix: int = -1
	for run_slot in list_run_slots():
		var summary: Dictionary = run_slot
		var slot_id: String = str(summary.get("slot_id", ""))
		if slot_id == "" or slot_id.begins_with("daily_"):
			continue
		if bool(summary.get("is_corrupt", false)):
			continue
		var updated: int = int(summary.get("updated_at_unix", 0))
		if updated > best_unix:
			best_unix = updated
			best = summary
	return best.duplicate(true)
```

- [ ] **Step 9: Add legacy migration on coordinator init**

In `game_state_coordinator.gd`, at the very end of `_init` (after `_load_or_initialize_meta_state()`), add:

```gdscript
	_migrate_legacy_active_run_slot_if_needed()
```

Add the method itself near the other private helpers:

```gdscript
func _migrate_legacy_active_run_slot_if_needed() -> void:
	if not persistence_service.run_slot_exists(_LEGACY_ACTIVE_SLOT_ID):
		return
	var load_result = persistence_service.load_run_state(_LEGACY_ACTIVE_SLOT_ID)
	if not load_result.get("ok", false):
		# Legacy file is unreadable or invalid under the new schema. Drop it; same recovery message contract as today.
		persistence_service.delete_run_state(_LEGACY_ACTIVE_SLOT_ID)
		last_recovery_message = "Legacy run save was reset to safe defaults."
		return
	var data: Dictionary = (load_result.get("data", {}) as Dictionary).duplicate(true)
	var archetype_id: String = str(data.get("archetype_id", "run"))
	var new_slot_id: String = _generate_run_slot_id(archetype_id)
	data["slot_id"] = new_slot_id
	if str(data.get("display_name", "")) == "":
		data["display_name"] = "Recovered Run · %s" % Time.get_date_string_from_system()
	data["updated_at_unix"] = Time.get_unix_time_from_system()
	persistence_service.save_run_state(new_slot_id, data)
	persistence_service.delete_run_state(_LEGACY_ACTIVE_SLOT_ID)
```

Note: because `REQUIRED_RUN_FIELDS` now requires `slot_id` and `display_name`, an in-memory legacy payload that lacks those fields will fail `load_run_state`'s validation. The migration above tolerates that by handling the not-ok case with a delete + recovery message. A legacy file that does have the fields (newly-written runs after this change) will migrate cleanly.

- [ ] **Step 10: Run tests**

Run: `make test`
Expected: PASS. The persistence test creates a session via the coordinator, which now populates `slot_id` and `display_name`, so schema validation passes. The corrupt-slot test still works (corrupt JSON fails validation regardless of fields).

If a test fails complaining about `slot_id` being empty for a daily session, double-check Step 5's `temp_standard_slot_id` ordering — capture it BEFORE setting `session.slot_id` to the daily id.

- [ ] **Step 11: Commit**

```bash
git add game/scripts/persistence/save_schema.gd \
        game/scripts/persistence/persistence_service.gd \
        game/scripts/core/game_state_coordinator.gd
git commit -m "feat(core): per-session slot ids, display names, and legacy migration"
```

---

## Task 5: Coordinator public API for the Continue popup

**Files:**
- Modify: `game/scripts/core/game_state_coordinator.gd`
- Create: `game/tests/test_named_run_saves.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write failing test for the new public API**

Create `game/tests/test_named_run_saves.gd`:

```gdscript
extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")
const PersistenceServiceScript = preload("res://scripts/persistence/persistence_service.gd")

const TEST_BASE_PATH := "user://facetbound_test_named_runs"


func run() -> Array[String]:
	var failures: Array[String] = []
	_clear_test_dir()

	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)
	# Redirect persistence to an isolated test path for this test only.
	coordinator.persistence_service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)

	# Two distinct named runs coexist.
	var first = coordinator.create_run_session("starter_facetwalker")
	if first == null or first is Dictionary:
		failures.append("first run should be created")
		return failures
	var first_slot: String = str(first.slot_id)
	if first_slot == "":
		failures.append("first run should be assigned a slot_id")
	if str(first.display_name) == "":
		failures.append("first run should be assigned a display_name")

	var second = coordinator.create_run_session("starter_facetwalker")
	if second == null or second is Dictionary:
		failures.append("second run should be created")
		return failures
	if str(second.slot_id) == first_slot:
		failures.append("two runs created back-to-back must use distinct slot ids")

	# After the second run, the file for the first slot should still exist.
	if not coordinator.persistence_service.run_slot_exists(first_slot):
		failures.append("starting a new run must not delete an existing run's save")

	# list_resumable_runs returns both, newest first.
	var resumable = coordinator.list_resumable_runs()
	if resumable.size() < 2:
		failures.append("list_resumable_runs should return both saved runs")

	# Rename the first slot.
	var rename_result = coordinator.rename_run(first_slot, "My Heroic Run")
	if not rename_result.get("ok", false):
		failures.append("rename_run should accept a non-empty name")
	var renamed = coordinator.persistence_service.load_run_state(first_slot)
	if not renamed.get("ok", false) or str((renamed.get("data", {}) as Dictionary).get("display_name", "")) != "My Heroic Run":
		failures.append("rename_run should persist the new display_name")

	# Empty rename rejected.
	var bad_rename = coordinator.rename_run(first_slot, "   ")
	if bad_rename.get("ok", false):
		failures.append("rename_run should reject blank names")

	# Delete the first slot.
	var delete_result = coordinator.delete_run(first_slot)
	if not delete_result.get("ok", false):
		failures.append("delete_run should remove an existing slot")
	if coordinator.persistence_service.run_slot_exists(first_slot):
		failures.append("delete_run must remove the file from disk")

	# Cannot delete the currently active run.
	var second_slot: String = str(second.slot_id)
	# Re-load the second session as the current session to guarantee currency.
	coordinator.load_run_session(second_slot)
	var bad_delete = coordinator.delete_run(second_slot)
	if bad_delete.get("ok", false):
		failures.append("delete_run must refuse to delete the active session's slot")

	# Daily Void uses a daily_ slot and stays out of list_resumable_runs.
	var daily = coordinator.create_daily_void_session("starter_facetwalker", "2026-05-02")
	if daily == null or daily is Dictionary:
		failures.append("daily void session should be created")
	else:
		if not str(daily.slot_id).begins_with("daily_"):
			failures.append("daily void session must use a daily_ slot id")
		var resumable_after_daily = coordinator.list_resumable_runs()
		for entry in resumable_after_daily:
			if str((entry as Dictionary).get("slot_id", "")).begins_with("daily_"):
				failures.append("list_resumable_runs must exclude daily_ slots")

	# Legacy migration: write a legacy active_run.json and reinit the coordinator.
	var legacy_payload: Dictionary = first.to_dictionary()
	legacy_payload["slot_id"] = "active_run"
	legacy_payload["display_name"] = ""
	legacy_payload["updated_at_unix"] = Time.get_unix_time_from_system()
	coordinator.persistence_service.save_run_state("active_run", legacy_payload)

	var migrated_coordinator = GameStateCoordinatorScript.new(catalog)
	migrated_coordinator.persistence_service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)
	# Trigger the migration by calling the same method the constructor calls.
	migrated_coordinator._migrate_legacy_active_run_slot_if_needed()
	if migrated_coordinator.persistence_service.run_slot_exists("active_run"):
		failures.append("legacy active_run.json must be removed after migration")

	return failures


func _clear_test_dir() -> void:
	var globalized: String = ProjectSettings.globalize_path(TEST_BASE_PATH)
	var dir = DirAccess.open(globalized)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				_remove_dir_recursive("%s/%s" % [globalized, name])
		else:
			DirAccess.remove_absolute("%s/%s" % [globalized, name])
		name = dir.get_next()
	dir.list_dir_end()


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child = "%s/%s" % [path, name]
		if dir.current_is_dir():
			if name != "." and name != "..":
				_remove_dir_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Register the new test**

Edit `game/tests/test_runner.gd`. Insert this entry into the `TEST_SCRIPT_PATHS` array, alphabetically next to the other `test_meta_*` / `test_modifier_*` entries (place it right after `test_modifier_registry.gd`):

```gdscript
	"res://tests/test_modifier_registry.gd",
	"res://tests/test_named_run_saves.gd",
```

- [ ] **Step 3: Run tests to confirm the new test fails**

Run: `make test`
Expected: FAIL with "list_resumable_runs" / "rename_run" / "delete_run" — the methods do not yet exist.

- [ ] **Step 4: Implement `list_resumable_runs`, `rename_run`, `delete_run`**

In `game/scripts/core/game_state_coordinator.gd`, add these methods just above `list_run_slots()`:

```gdscript
func list_resumable_runs() -> Array:
	var result: Array = []
	for slot in list_run_slots():
		var summary: Dictionary = slot
		var slot_id: String = str(summary.get("slot_id", ""))
		if slot_id == "" or slot_id.begins_with("daily_"):
			continue
		if bool(summary.get("is_corrupt", false)):
			# Surface corrupt entries so the popup can offer Delete-only on them.
			result.append(summary.duplicate(true))
			continue
		result.append(summary.duplicate(true))
	result.sort_custom(func(a, b):
		return int((a as Dictionary).get("updated_at_unix", 0)) > int((b as Dictionary).get("updated_at_unix", 0)))
	return result


func rename_run(slot_id: String, new_name: String) -> Dictionary:
	var trimmed: String = new_name.strip_edges()
	if trimmed.length() == 0:
		return {"ok": false, "error": "empty_name"}
	if trimmed.length() > 64:
		return {"ok": false, "error": "name_too_long"}
	var load_result = persistence_service.load_run_state(slot_id)
	if not load_result.get("ok", false):
		return load_result
	var data: Dictionary = (load_result.get("data", {}) as Dictionary).duplicate(true)
	data["display_name"] = trimmed
	data["updated_at_unix"] = Time.get_unix_time_from_system()
	var save_result = persistence_service.save_run_state(slot_id, data)
	if not save_result.get("ok", false):
		return save_result
	if current_session != null and str(current_session.slot_id) == slot_id:
		current_session.display_name = trimmed
	return {"ok": true, "slot_id": slot_id, "display_name": trimmed}


func delete_run(slot_id: String) -> Dictionary:
	if slot_id == "":
		return {"ok": false, "error": "missing_slot_id"}
	if current_session != null and not current_session.run_complete and str(current_session.slot_id) == slot_id:
		return {"ok": false, "error": "active_run_locked"}
	return persistence_service.delete_run_state(slot_id)
```

- [ ] **Step 5: Run tests to confirm green**

Run: `make test`
Expected: PASS for `test_named_run_saves` and all existing tests.

- [ ] **Step 6: Commit**

```bash
git add game/scripts/core/game_state_coordinator.gd \
        game/tests/test_named_run_saves.gd \
        game/tests/test_runner.gd
git commit -m "feat(core): list_resumable_runs / rename_run / delete_run with tests"
```

---

## Task 6: Start menu — Continue menu row + new configure signature

**Files:**
- Modify: `game/scripts/screens/start_menu_controller.gd`
- Modify: `game/scenes/screens/start_menu.tscn`
- Modify: `game/scripts/app_root.gd`

- [ ] **Step 1: Replace the inline ContinueStrip with a Continue menu row in the controller**

In `game/scripts/screens/start_menu_controller.gd`:

1. Replace the `MENU_ITEMS` constant (lines 63–71) with:

```gdscript
const MENU_ITEMS := [
	{"id": "new-run", "label": "New Run", "hint": "Enter the Void Labyrinth", "hotkey": "↵", "accent": true, "enabled": true},
	{"id": "continue", "label": "Continue", "hint": "Resume a saved run", "hotkey": "R", "accent": false, "enabled": false},
	{"id": "archetypes", "label": "Archetypes", "hint": "Choose your Facetwalker", "hotkey": "A", "accent": false, "enabled": true},
	{"id": "forge", "label": "Eternal Forge", "hint": "Spend Echo Shards", "hotkey": "F", "accent": false, "enabled": false},
	{"id": "daily", "label": "Daily Void", "hint": "Seeded challenge run", "hotkey": "D", "accent": false, "enabled": true},
	{"id": "settings", "label": "Settings", "hint": "Audio · Video · Controls", "hotkey": "S", "accent": false, "enabled": false},
	{"id": "credits", "label": "Credits", "hint": "The Facetwalkers", "hotkey": "C", "accent": false, "enabled": false},
	{"id": "quit", "label": "Quit", "hint": "Leave the labyrinth", "hotkey": "Q", "accent": false, "enabled": true},
]
```

2. Change the signal block at lines 40–42 to:

```gdscript
signal run_requested(archetype_id: String)
signal daily_void_requested(archetype_id: String)
signal continue_runs_requested()
```

(The old `continue_requested(slot_id)` signal is replaced by the popup's own `resume_requested`. Removed from the start menu.)

3. Replace the `var _continue_summary: Dictionary = {}` declaration (line 87) with:

```gdscript
var _resumable_summaries: Array = []
```

4. Remove the `@onready var continue_spacer` and `@onready var continue_strip` and `@onready var continue_button` declarations (lines 54–56) since those nodes are being deleted from the scene in Step 2 below. Also remove their setup in `_ready()` (the `continue_button.pressed.connect(...)` line and the lines `continue_spacer.visible = false` / `continue_strip.visible = false`).

5. Replace `configure(...)` (around lines 142–168) with:

```gdscript
func configure(archetypes: Array, resumable_summaries: Array = [], recovery_message: String = "", last_daily_void_result: Dictionary = {}, shards_count: int = 0) -> void:
	_archetypes = archetypes.duplicate(true)
	_resumable_summaries = resumable_summaries.duplicate(true)
	_recovery_message = recovery_message
	_last_daily_void_result = last_daily_void_result.duplicate(true)
	_shards_count = shards_count
	if not is_node_ready():
		await ready

	archetype_options.clear()
	for index in range(_archetypes.size()):
		var archetype: Dictionary = _archetypes[index]
		archetype_options.add_item(str(archetype.get("name", archetype.get("id", "Unknown"))), index)

	var has_archetypes := not _archetypes.is_empty()
	_set_menu_row_enabled("new-run", has_archetypes)
	_set_menu_row_enabled("daily", has_archetypes)
	_set_menu_row_enabled("continue", _resumable_summaries.size() > 0)

	_refresh_shards()
	_update_summary()
```

6. Replace `_on_menu_pressed(id)` (the match block around line 636) by adding a `"continue":` arm and removing references to the deleted button:

```gdscript
func _on_menu_pressed(id: String) -> void:
	match id:
		"new-run":
			_trigger_run()
		"continue":
			continue_runs_requested.emit()
		"archetypes":
			archetype_options.grab_focus()
			if _archetypes.size() > 1:
				archetype_options.show_popup()
		"daily":
			_trigger_daily_void()
		"quit":
			get_tree().quit()
		_:
			pass
```

7. Delete the `_on_continue_pressed()` function entirely.

8. Update `_update_summary()` to drop the per-resume sentence (since the popup owns that information). Replace its body with:

```gdscript
func _update_summary() -> void:
	var selected := _get_selected_archetype()
	if selected.is_empty():
		summary_label.text = "No starter archetypes are available."
		return

	var parts: Array[String] = []
	parts.append("Starter floor: %s  |  HP: %s  |  Dice: %d" % [
		str(selected.get("starter_floor_id", "unknown")),
		str((selected.get("player_state", {}) as Dictionary).get("hp", 0)),
		(selected.get("starter_dice", []) as Array).size(),
	])
	if _resumable_summaries.size() > 0:
		parts.append("%d saved run(s) available — open Continue to resume." % _resumable_summaries.size())
	if _recovery_message != "":
		parts.append("Recovery: %s" % _recovery_message)
	if not _last_daily_void_result.is_empty():
		parts.append("Daily Void: %s · Score %d · %s" % [
			str(_last_daily_void_result.get("seed_id", "")),
			int(_last_daily_void_result.get("score", 0)),
			str(_last_daily_void_result.get("submission_status", "not_attempted")),
		])
	summary_label.text = "\n".join(parts)
```

9. Add `KEY_R: "continue"` to the `key_to_id` dictionary in `_input(event)` near line 722:

```gdscript
	var key_to_id := {
		KEY_ENTER: "new-run",
		KEY_KP_ENTER: "new-run",
		KEY_R: "continue",
		KEY_A: "archetypes",
		KEY_F: "forge",
		KEY_D: "daily",
		KEY_S: "settings",
		KEY_C: "credits",
		KEY_Q: "quit",
	}
```

- [ ] **Step 2: Remove the inline ContinueStrip from `start_menu.tscn`**

Edit `game/scenes/screens/start_menu.tscn`. Delete these node blocks (lines 191–203 in the original):

```
[node name="ContinueSpacer" type="Control" parent="ContentColumn"]
custom_minimum_size = Vector2(0, 10)
layout_mode = 2

[node name="ContinueStrip" type="HBoxContainer" parent="ContentColumn"]
layout_mode = 2
theme_override_constants/separation = 14

[node name="ContinueRunButton" type="Button" parent="ContentColumn/ContinueStrip"]
layout_mode = 2
size_flags_horizontal = 3
text = "Continue Run"
```

Save the file.

- [ ] **Step 3: Update `app_root.gd` to pass `list_resumable_runs()` and connect to the new signal**

In `game/scripts/app_root.gd`:

1. Replace the `start_menu.configure(...)` block (lines 38–44) with:

```gdscript
	start_menu.configure(
		archetypes,
		game_state_coordinator.list_resumable_runs(),
		game_state_coordinator.last_recovery_message,
		game_state_coordinator.meta_state.last_daily_void_result,
		int(game_state_coordinator.meta_state.echo_shards)
	)
```

2. Replace the three signal-connect lines (45–47) with:

```gdscript
	start_menu.run_requested.connect(_on_run_requested)
	start_menu.daily_void_requested.connect(_on_daily_void_requested)
	start_menu.continue_runs_requested.connect(_on_continue_runs_requested)
```

3. Add a stub handler temporarily (the full popup arrives in Task 7):

```gdscript
func _on_continue_runs_requested() -> void:
	# Filled in by Task 7 — instantiates the Continue popup.
	pass
```

4. Delete the existing `_on_continue_requested(slot_id)` handler. The popup will own this path in Task 7 (and reuse the same coordinator method via a different name).

- [ ] **Step 4: Run tests to confirm nothing else regressed**

Run: `make test`
Expected: PASS. The headless tests don't drive the start menu UI, so this is mostly a compile check.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/screens/start_menu_controller.gd \
        game/scenes/screens/start_menu.tscn \
        game/scripts/app_root.gd
git commit -m "feat(ui): replace inline Continue strip with menu row + emit continue_runs_requested"
```

---

## Task 7: Continue popup dialog with Resume / Rename / Delete

**Files:**
- Create: `game/scripts/screens/continue_runs_dialog.gd`
- Modify: `game/scripts/app_root.gd`

- [ ] **Step 1: Create the dialog script**

Create `game/scripts/screens/continue_runs_dialog.gd`:

```gdscript
class_name ContinueRunsDialog
extends AcceptDialog

const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

signal resume_requested(slot_id: String)
signal rename_requested(slot_id: String, new_name: String)
signal delete_requested(slot_id: String)

const TEXT_PRIMARY := Color("e7e3da")
const TEXT_DIM := Color("73808d")
const ACCENT_BRIGHT := Color("6ebeff")
const ERROR_COLOR := Color("d97070")

var _list_container: VBoxContainer
var _empty_label: Label
var _summaries: Array = []
var _editing_slot_id: String = ""


func _init() -> void:
	title = "Continue Run"
	min_size = Vector2(560, 420)
	dialog_hide_on_ok = true
	get_ok_button().text = "Close"


func _ready() -> void:
	theme = FacetboundThemeScript.build()
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)

	_empty_label = Label.new()
	_empty_label.text = "No saved runs."
	_empty_label.add_theme_color_override("font_color", TEXT_DIM)
	_empty_label.visible = false
	root.add_child(_empty_label)


func configure(summaries: Array) -> void:
	_summaries = summaries.duplicate(true)
	_editing_slot_id = ""
	_rebuild()


func _rebuild() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	if _summaries.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for entry in _summaries:
		_list_container.add_child(_make_row(entry as Dictionary))


func _make_row(summary: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var slot_id: String = str(summary.get("slot_id", ""))
	var is_corrupt: bool = bool(summary.get("is_corrupt", false))
	var display_name: String = str(summary.get("display_name", ""))
	if display_name == "":
		display_name = slot_id
	var archetype: String = str(summary.get("archetype_id", ""))
	var floor_index: int = int(summary.get("floor_index", 0))
	var room_id: String = str(summary.get("room_id", ""))
	var updated_unix: int = int(summary.get("updated_at_unix", 0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	if _editing_slot_id == slot_id and not is_corrupt:
		var line_edit := LineEdit.new()
		line_edit.text = display_name
		line_edit.placeholder_text = "Run name"
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.text_submitted.connect(func(value: String):
			_editing_slot_id = ""
			rename_requested.emit(slot_id, value))
		info.add_child(line_edit)
		line_edit.grab_focus.call_deferred()
	else:
		var name_label := Label.new()
		name_label.text = display_name
		name_label.add_theme_color_override("font_color", ERROR_COLOR if is_corrupt else TEXT_PRIMARY)
		info.add_child(name_label)

	var detail_text: String = ""
	if is_corrupt:
		detail_text = "Save data is corrupt."
	else:
		detail_text = "%s · Floor %d · Room %s · %s" % [
			archetype if archetype != "" else "unknown archetype",
			floor_index,
			room_id if room_id != "" else "?",
			_format_relative_time(updated_unix),
		]
	var detail_label := Label.new()
	detail_label.text = detail_text
	detail_label.add_theme_color_override("font_color", TEXT_DIM)
	info.add_child(detail_label)

	if not is_corrupt:
		var resume_btn := Button.new()
		resume_btn.text = "Resume"
		resume_btn.pressed.connect(func():
			hide()
			resume_requested.emit(slot_id))
		hbox.add_child(resume_btn)

		var rename_btn := Button.new()
		rename_btn.text = "Rename"
		rename_btn.pressed.connect(func():
			_editing_slot_id = slot_id
			_rebuild())
		hbox.add_child(rename_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func():
		_confirm_delete(slot_id, display_name))
	hbox.add_child(delete_btn)

	return row


func _confirm_delete(slot_id: String, name_for_message: String) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete save?"
	confirm.dialog_text = "Delete \"%s\"? This cannot be undone." % name_for_message
	add_child(confirm)
	confirm.confirmed.connect(func():
		delete_requested.emit(slot_id)
		confirm.queue_free())
	confirm.canceled.connect(func():
		confirm.queue_free())
	confirm.popup_centered()


func _format_relative_time(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "unknown time"
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = max(0, now - unix_seconds)
	if delta < 60:
		return "just now"
	if delta < 3600:
		return "%d minutes ago" % int(delta / 60.0)
	if delta < 86400:
		return "%d hours ago" % int(delta / 3600.0)
	return "%d days ago" % int(delta / 86400.0)
```

- [ ] **Step 2: Wire the dialog into `app_root.gd`**

In `game/scripts/app_root.gd`:

1. Add the preload near the other scene preloads at the top:

```gdscript
const ContinueRunsDialogScript = preload("res://scripts/screens/continue_runs_dialog.gd")
```

2. Add a member to hold the active dialog instance, near `_confirm_dialog`:

```gdscript
var _continue_runs_dialog: ContinueRunsDialog = null
```

3. Replace the stub `_on_continue_runs_requested()` from Task 6 with the full handler, and add the supporting handlers:

```gdscript
func _on_continue_runs_requested() -> void:
	if _continue_runs_dialog == null:
		_continue_runs_dialog = ContinueRunsDialogScript.new()
		hud.add_child(_continue_runs_dialog)
		_continue_runs_dialog.resume_requested.connect(_on_continue_resume_requested)
		_continue_runs_dialog.rename_requested.connect(_on_continue_rename_requested)
		_continue_runs_dialog.delete_requested.connect(_on_continue_delete_requested)
	_continue_runs_dialog.configure(game_state_coordinator.list_resumable_runs())
	_continue_runs_dialog.popup_centered()


func _on_continue_resume_requested(slot_id: String) -> void:
	var load_result = game_state_coordinator.load_run_session(slot_id)
	if not load_result.get("ok", false):
		hud.show_error("Continue failed. Safe defaults restored.")
		_show_start_menu()
		return
	_show_exploration(load_result.get("run_session"))


func _on_continue_rename_requested(slot_id: String, new_name: String) -> void:
	var result = game_state_coordinator.rename_run(slot_id, new_name)
	if not result.get("ok", false):
		hud.show_error("Rename failed.")
	_refresh_continue_dialog()


func _on_continue_delete_requested(slot_id: String) -> void:
	var result = game_state_coordinator.delete_run(slot_id)
	if not result.get("ok", false):
		hud.show_error("Delete failed.")
	_refresh_continue_dialog()


func _refresh_continue_dialog() -> void:
	if _continue_runs_dialog == null:
		return
	_continue_runs_dialog.configure(game_state_coordinator.list_resumable_runs())
```

- [ ] **Step 3: Run tests**

Run: `make test`
Expected: PASS. The headless test runner does not drive the popup directly; this step is verifying nothing fails to compile.

- [ ] **Step 4: Smoke test the UI**

Run: `make gui` and open `http://localhost:6080/vnc.html`. Verify:

- "Continue" appears in the main menu, disabled when no runs exist.
- Clicking "New Run" twice (returning via Escape between runs) leaves both saves on disk; "Continue" becomes enabled.
- Clicking "Continue" opens the popup with both runs, newest-first.
- Resume loads the chosen save into exploration.
- Rename swaps to a LineEdit; Enter commits the new name.
- Delete shows a confirmation; OK removes the row.
- Escape closes the popup and returns to the start menu.

If the popup behaves correctly, proceed.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/screens/continue_runs_dialog.gd \
        game/scripts/app_root.gd
git commit -m "feat(ui): Continue popup with Resume, Rename, Delete"
```

---

## Task 8: Run-end auto-delete + new-run-isolation integration test

**Files:**
- Modify: `game/tests/test_named_run_saves.gd`

- [ ] **Step 1: Extend the test with a defeat-isolation case**

Open `game/tests/test_named_run_saves.gd`. Just before the `return failures` at the bottom of `run()`, add:

```gdscript
	# Run-end deletes only the active slot.
	_clear_test_dir()
	coordinator = GameStateCoordinatorScript.new(catalog)
	coordinator.persistence_service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)
	var run_a = coordinator.create_run_session("starter_facetwalker")
	if run_a == null or run_a is Dictionary:
		failures.append("isolation test: run A should be created")
		return failures
	var run_a_slot: String = str(run_a.slot_id)
	var run_b = coordinator.create_run_session("starter_facetwalker")
	if run_b == null or run_b is Dictionary:
		failures.append("isolation test: run B should be created")
		return failures
	var run_b_slot: String = str(run_b.slot_id)
	# Re-load run A as the active session.
	coordinator.load_run_session(run_a_slot)
	var defeat_result := {
		"outcome": "defeat",
		"player_hp_after": 0,
		"room_id": str(coordinator.current_session.current_room_id),
	}
	coordinator.apply_encounter_result(defeat_result)
	if coordinator.persistence_service.run_slot_exists(run_a_slot):
		failures.append("defeat must remove the active run's slot")
	if not coordinator.persistence_service.run_slot_exists(run_b_slot):
		failures.append("defeat must not affect other runs' slots")
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add game/tests/test_named_run_saves.gd
git commit -m "test(core): defeat in one run leaves other runs intact"
```

---

## Self-Review Notes (built-in checks)

- **Spec coverage:** all spec sections map to a task — slot model & generation (Task 4), run state additions (Tasks 2, 4), summary additions (Tasks 1, 3), migration (Task 4), New Run flow (Task 4), Continue popup behavior (Task 7), Daily Void slot (Task 4 + 5 test), no save cap (no task needed — list is unbounded by construction), error handling (Tasks 5, 7).
- **Naming consistency:** `slot_id` / `display_name` / `list_resumable_runs` / `rename_run` / `delete_run` / `_clear_current_run_slot` / `delete_run_state` are used identically everywhere. The legacy constant `_LEGACY_ACTIVE_SLOT_ID = "active_run"` only appears inside the migration helper.
- **No placeholders:** every code step shows the actual code. No "implement appropriate error handling" or "similar to before."
- **Hotkey collision:** Continue uses `R` (Resume); the existing menu uses A, F, D, S, C, Q, ↵ — no collision.
