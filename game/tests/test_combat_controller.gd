extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
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
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []}
		],
	})

	var encounter_definition = {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4, 2, 3],
	}

	var combat_state = controller.begin_encounter(run_session, encounter_definition)
	if combat_state == null or combat_state is Dictionary:
		failures.append("begin_encounter should create a combat state")
		return failures

	var roll_result = controller.roll_active_dice(combat_state)
	if not roll_result.get("ok", false):
		failures.append("roll_active_dice should succeed for valid starter dice")
		return failures

	controller.assign_die_to_action(combat_state, "balanced_d6_alpha", "main_attack")
	controller.assign_die_to_action(combat_state, "balanced_d6_beta", "guard")
	controller.assign_die_to_action(combat_state, "balanced_d6_gamma", "utility")

	var player_result = controller.resolve_player_turn(combat_state)
	if not player_result.get("ok", false):
		failures.append("resolve_player_turn should succeed")
		return failures

	var enemy_hp_after_player: int = int((combat_state.enemy_state as Dictionary).get("hp", 0))
	if enemy_hp_after_player != 0:
		failures.append("player turn should damage the enemy before enemy resolution")

	if combat_state.state != "complete":
		failures.append("combat should complete when the enemy reaches zero hp before the enemy turn")

	var log_text: String = "\n".join(combat_state.turn_log)
	if log_text.find("Player turn resolved") == -1:
		failures.append("combat log should include player turn resolution")

	var encounter_result_output = controller.finish_encounter(combat_state)
	if encounter_result_output.get("outcome", "") != "victory":
		failures.append("finish_encounter should report a victory when the enemy is defeated")

	controller.free()
	return failures
