extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)

	var run_session = coordinator.create_run_session("starter_facetwalker")
	if run_session == null or not run_session.has_method("to_dictionary"):
		failures.append("exploration flow requires a valid starter run session")
		return failures

	var move_result = coordinator.enter_room("tutorial_hall")
	if not move_result.get("ok", false):
		failures.append("expected a legal transition into tutorial_hall")
		return failures

	if coordinator.current_session.current_room_id != "tutorial_hall":
		failures.append("enter_room should update the current room")

	var room_state: Dictionary = coordinator.current_session.room_states.get("tutorial_hall", {})
	if not bool(room_state.get("revealed", false)):
		failures.append("enter_room should reveal the destination room")

	var encounter_result = coordinator.begin_encounter("tutorial_slime")
	if not encounter_result.get("ok", false):
		failures.append("begin_encounter should produce a stub encounter state")
		return failures

	if encounter_result.get("state", "") != "combat_active":
		failures.append("begin_encounter should return the combat_active state")

	room_state = coordinator.current_session.room_states.get("tutorial_hall", {})
	if bool(room_state.get("completed", false)):
		failures.append("room completion should wait until encounter results are applied")

	if str((coordinator.current_session.flags.get("active_encounter", {}) as Dictionary).get("encounter_id", "")) != "tutorial_slime":
		failures.append("active_encounter should be stored in run-session flags")

	if encounter_result.get("combat_state", null) == null:
		failures.append("begin_encounter should return a combat state for routing")

	return failures
