extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)

	var run_result = coordinator.create_run_session("starter_facetwalker")
	if run_result == null or run_result is Dictionary:
		failures.append("valid archetype should create a run session")
		return failures

	if run_result.session_id != "run_001_starter_facetwalker":
		failures.append("session id should be deterministic for the first run")

	if run_result.current_room_id != "floor_01_start":
		failures.append("new session should start in the floor_01 start room")

	if run_result.room_graph_id != "floor_01_rooms":
		failures.append("new session should reference the floor_01 room graph")

	if int((run_result.player_state as Dictionary).get("hp", 0)) != 30:
		failures.append("new session should hydrate seeded player hp")

	if run_result.active_dice.size() != 3:
		failures.append("new session should contain the seeded starter dice")

	if str(run_result.mode_id) != "standard":
		failures.append("new standard sessions should record the standard mode id")

	if run_result.action_slots.size() != 3:
		failures.append("new session should hydrate the default action slots")

	var starting_room_state: Dictionary = run_result.room_states.get("floor_01_start", {})
	if not bool(starting_room_state.get("revealed", false)):
		failures.append("starting room should be revealed when the run begins")

	if bool(starting_room_state.get("completed", false)):
		failures.append("starting room should not begin completed")

	if not run_result.last_encounter_result.is_empty():
		failures.append("new session should not begin with a last encounter result")

	if str(run_result.flags.get("screen_state", "")) != "exploration":
		failures.append("new sessions should begin in the exploration screen state")

	if not run_result.reward_flow_state.is_empty():
		failures.append("new sessions should not begin with an active reward flow")

	if str((run_result.floor_state as Dictionary).get("boss_room_id", "")) != "floor_01_boss":
		failures.append("new sessions should hydrate the active floor state including the boss room")

	if coordinator.current_session != run_result:
		failures.append("coordinator should retain the active run session")

	var invalid_result = coordinator.create_run_session("does_not_exist")
	if not (invalid_result is Dictionary) or invalid_result.get("error", "") != "missing_content":
		failures.append("invalid archetype should fail with missing_content")

	return failures
