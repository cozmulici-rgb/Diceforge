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
	var slots_before_daily: Array = coordinator.persistence_service.list_run_slots()
	var non_daily_before: Array = []
	for entry in slots_before_daily:
		if not str((entry as Dictionary).get("slot_id", "")).begins_with("daily_"):
			non_daily_before.append(str((entry as Dictionary).get("slot_id", "")))
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
		# Verify the inner-call's temp standard slot was cleaned up — no new
		# non-daily files appeared on disk relative to the pre-daily snapshot.
		var slots_after_daily: Array = coordinator.persistence_service.list_run_slots()
		var non_daily_after: Array = []
		for entry in slots_after_daily:
			if not str((entry as Dictionary).get("slot_id", "")).begins_with("daily_"):
				non_daily_after.append(str((entry as Dictionary).get("slot_id", "")))
		if non_daily_after.size() != non_daily_before.size():
			failures.append("creating a daily run must not leak the inner standard-slot file")

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

	# Legacy migration failure path: a pre-feature save missing the new fields.
	var bad_legacy_payload: Dictionary = {
		"schema_version": 2,
		"session_id": "legacy_session",
		"archetype_id": "starter_facetwalker",
		"floor_index": 1,
		"current_room_id": "floor_01_start",
		"room_graph_id": "floor_01_rooms",
		"player_state": {"hp": 30},
		"active_dice": [],
		"inventory": {},
		"mode_id": "standard",
		"seed_id": "",
		"numeric_seed": 0,
		"daily_void_config": {},
		"score_summary": {},
	}
	# Write directly via JSON to bypass schema validation (simulates pre-feature save).
	var bad_legacy_path := ProjectSettings.globalize_path("%s/runs/active_run.json" % TEST_BASE_PATH)
	var bad_file := FileAccess.open(bad_legacy_path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(bad_legacy_payload))
	bad_file = null

	var failure_coordinator = GameStateCoordinatorScript.new(catalog)
	failure_coordinator.persistence_service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)
	failure_coordinator._migrate_legacy_active_run_slot_if_needed()
	if failure_coordinator.persistence_service.run_slot_exists("active_run"):
		failures.append("legacy file missing new fields must be deleted by migration")
	if str(failure_coordinator.last_recovery_message) == "":
		failures.append("legacy migration failure path must set last_recovery_message")

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
