extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const MetaProgressionControllerScript = preload("res://scripts/progression/meta_progression_controller.gd")
const MetaStateScript = preload("res://scripts/progression/meta_state.gd")
const PersistenceServiceScript = preload("res://scripts/persistence/persistence_service.gd")

const TEST_BASE_PATH := "user://diceforge_test_meta"


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var progression = MetaProgressionControllerScript.new(catalog)
	var meta_state = MetaStateScript.new()

	var progression_result = progression.process_run_end({
		"outcome": "victory",
		"boss_defeated": true,
		"run_complete": true,
		"floors_cleared": 2,
	}, meta_state)
	if int(progression_result.get("echo_shards_total", 0)) <= 0:
		failures.append("run completion should award echo shards")

	if (progression_result.get("new_unlock_ids", []) as Array).is_empty():
		failures.append("run completion should resolve unlock progression")

	if (progression_result.get("achievement_ids", []) as Array).is_empty():
		failures.append("run completion should resolve achievements")

	var service = PersistenceServiceScript.new(catalog, TEST_BASE_PATH)
	var save_result = service.save_meta_state(meta_state.to_dictionary())
	if not save_result.get("ok", false):
		failures.append("meta progression changes should persist through the persistence service")

	var load_result = service.load_meta_state()
	if not load_result.get("ok", false):
		failures.append("persisted meta progression should load successfully")
	else:
		var loaded_meta_state: Dictionary = load_result.get("data", {})
		if int(loaded_meta_state.get("echo_shards", 0)) != meta_state.echo_shards:
			failures.append("loaded meta progression should match the saved shard total")
		if not loaded_meta_state.has("last_daily_void_result"):
			failures.append("meta progression saves should preserve daily void result metadata")

	return failures
