extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")
const PersistenceServiceScript = preload("res://scripts/persistence/persistence_service.gd")

const TEST_BASE_PATH := "user://facetbound_test_persistence"


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)
	var service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)

	var run_session = coordinator.create_run_session("starter_facetwalker")
	if run_session == null or run_session is Dictionary:
		failures.append("persistence tests require a valid run session")
		return failures

	var run_payload = run_session.to_dictionary()
	run_payload["updated_at_unix"] = 123456
	var save_result = service.save_run_state("slot_a", run_payload)
	if not save_result.get("ok", false):
		failures.append("save_run_state should persist a valid run payload")

	var load_result = service.load_run_state("slot_a")
	if not load_result.get("ok", false):
		failures.append("load_run_state should hydrate a persisted valid run payload")
	else:
		if str((load_result.get("data", {}) as Dictionary).get("session_id", "")) != run_session.session_id:
			failures.append("loaded run payload should match the saved session id")

	var slot_summaries = service.list_run_slots()
	if slot_summaries.is_empty():
		failures.append("list_run_slots should expose saved slot summaries")

	var corrupt_path := ProjectSettings.globalize_path("%s/runs/corrupt_slot.json" % TEST_BASE_PATH)
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{\"schema_version\":999}")
	corrupt_file = null

	var corrupt_result = service.load_run_state("corrupt_slot")
	if corrupt_result.get("ok", true):
		failures.append("schema-incompatible run saves should be rejected safely")

	var delete_result = service.delete_run_state("corrupt_slot")
	if not delete_result.get("ok", false):
		failures.append("delete_run_state should remove an invalid save slot")

	return failures
