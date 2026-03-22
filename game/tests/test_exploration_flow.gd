extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)

	var run_session = coordinator.create_run_session("starter_facetwalker")
	if run_session == null or run_session is Dictionary:
		failures.append("exploration flow requires a valid starter run session")
		return failures

	var move_result = coordinator.enter_room("floor_01_fight")
	if not move_result.get("ok", false):
		failures.append("expected a legal transition into the first branching encounter room")
		return failures

	if coordinator.current_session.current_room_id != "floor_01_fight":
		failures.append("enter_room should update the current room")

	var room_state: Dictionary = coordinator.current_session.room_states.get("floor_01_fight", {})
	if not bool(room_state.get("revealed", false)):
		failures.append("enter_room should reveal the destination room")

	var encounter_result = coordinator.begin_encounter("tutorial_slime")
	if not encounter_result.get("ok", false):
		failures.append("begin_encounter should produce a stub encounter state")
		return failures

	if encounter_result.get("state", "") != "combat_active":
		failures.append("begin_encounter should return the combat_active state")

	room_state = coordinator.current_session.room_states.get("floor_01_fight", {})
	if bool(room_state.get("completed", false)):
		failures.append("room completion should wait until encounter results are applied")

	if str((coordinator.current_session.flags.get("active_encounter", {}) as Dictionary).get("encounter_id", "")) != "tutorial_slime":
		failures.append("active_encounter should be stored in run-session flags")

	if encounter_result.get("combat_state", null) == null:
		failures.append("begin_encounter should return a combat state for routing")

	var resolved_session = coordinator.apply_encounter_result({
		"outcome": "victory",
		"player_hp_after": 27,
		"encounter_id": "tutorial_slime",
		"room_id": "floor_01_fight",
		"reward_source": {"reward_type": "encounter", "reward_source_id": "tutorial_slime_rewards"},
	})
	if resolved_session == null or resolved_session is Dictionary:
		failures.append("apply_encounter_result should preserve the run session")
		return failures

	if str(coordinator.current_session.flags.get("screen_state", "")) != "reward":
		failures.append("a victory should route the run into the reward screen state")

	var reward_flow = coordinator.open_reward_flow({"reward_type": "encounter", "reward_source_id": "tutorial_slime_rewards"})
	if not reward_flow.get("ok", false):
		failures.append("post-combat victories should resolve into a reward flow")

	coordinator.current_session.flags["pending_floor_advance"] = "floor_02"
	var resumed_session = coordinator.complete_reward_flow()
	if resumed_session == null or resumed_session is Dictionary:
		failures.append("complete_reward_flow should preserve the run session during floor advancement")
		return failures

	if coordinator.current_session.floor_index != 2 or coordinator.current_session.current_room_id != "floor_02_start":
		failures.append("floor completion should advance the run into the next floor start room")

	return failures
