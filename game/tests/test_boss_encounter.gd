extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog

	var run_session = RunSessionScript.new({
		"current_room_id": "floor_01_boss",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{"id": "balanced_d6_alpha", "label": "Balanced D6", "body_id": "standard_d6", "face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]},
			{"id": "balanced_d6_beta", "label": "Balanced D6", "body_id": "standard_d6", "face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]},
			{"id": "balanced_d6_gamma", "label": "Balanced D6", "body_id": "standard_d6", "face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]}
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []}
		],
	})

	var boss_encounter = catalog.load_encounter("floor_01_overseer")
	var combat_state = controller.begin_encounter(run_session, boss_encounter)
	if combat_state == null or combat_state is Dictionary:
		failures.append("begin_encounter should produce combat state for boss encounters")
		controller.free()
		return failures
	controller.combat_state = combat_state

	controller.run_auto_round()
	if int((combat_state.enemy_state as Dictionary).get("phase_index", 1)) != 2:
		failures.append("boss combat should advance into the next phase before resolving victory")

	controller.run_auto_round()
	var boss_result = controller.finish_encounter(combat_state)
	if not bool(boss_result.get("boss_defeated", false)):
		failures.append("finishing the boss encounter should mark the boss as defeated")
	if bool(boss_result.get("run_complete", false)):
		failures.append("the first floor boss should not mark the entire run complete")

	var coordinator = GameStateCoordinatorScript.new(catalog)
	var session = coordinator.create_run_session("starter_facetwalker")
	if session == null or session is Dictionary:
		failures.append("boss encounter completion test requires a valid run session")
		controller.free()
		return failures

	coordinator.current_session.floor_index = 2
	coordinator.current_session.current_room_id = "floor_02_boss"
	coordinator.current_session.room_graph_id = "floor_02_rooms"
	coordinator.current_session.floor_state = {
		"floor_index": 2,
		"floor_template_id": "floor_02",
		"start_room_id": "floor_02_start",
		"boss_room_id": "floor_02_boss",
		"next_floor_id": "",
		"room_ids": ["floor_02_start", "floor_02_event", "floor_02_fight", "floor_02_boss"],
		"visited_room_ids": ["floor_02_start", "floor_02_boss"],
		"completed_room_ids": [],
	}
	coordinator.current_session.room_states = {
		"floor_02_start": {"revealed": true, "completed": false, "visit_count": 1},
		"floor_02_event": {"revealed": false, "completed": false, "visit_count": 0},
		"floor_02_fight": {"revealed": false, "completed": false, "visit_count": 0},
		"floor_02_boss": {"revealed": true, "completed": false, "visit_count": 1}
	}

	var updated_session = coordinator.apply_encounter_result({
		"outcome": "victory",
		"player_hp_after": 24,
		"encounter_id": "final_warden",
		"room_id": "floor_02_boss",
		"boss_defeated": true,
		"run_complete": true,
		"reward_source": {"reward_type": "encounter", "reward_source_id": "final_boss_rewards"},
	})
	if updated_session == null or updated_session is Dictionary:
		failures.append("applying a final boss victory should preserve the run session before run-end routing")
		return failures

	var reward_flow = coordinator.open_reward_flow({"reward_type": "encounter", "reward_source_id": "final_boss_rewards"})
	if not reward_flow.get("ok", false):
		failures.append("final boss victories should still route through the reward flow")
		return failures

	coordinator.apply_reward_selection((reward_flow.get("available_options", []) as Array)[0])
	var completed_session = coordinator.complete_reward_flow()
	if completed_session == null or completed_session is Dictionary:
		failures.append("completing the final boss reward flow should preserve the run session")
		return failures

	if not bool(coordinator.current_session.run_complete):
		failures.append("completing the final boss reward flow should mark the run complete")

	if int((coordinator.current_session.progression_result as Dictionary).get("echo_shards_total", 0)) <= 0:
		failures.append("run completion should award placeholder echo shards")

	if (coordinator.current_session.progression_result.get("new_unlock_ids", []) as Array).is_empty():
		failures.append("run completion should expose placeholder unlock progression")

	controller.free()
	return failures
