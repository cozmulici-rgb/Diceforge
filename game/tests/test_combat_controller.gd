extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog
	failures.append_array(_test_enemy_rolls_wait_for_enemy_resolution(catalog))

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
	controller.combat_state = combat_state

	var enemy_display_before_roll := controller.get_enemy_display_rolls(combat_state)
	if not enemy_display_before_roll.is_empty():
		failures.append("enemy dice should stay hidden before the player rolls")

	var roll_result = controller.roll_active_dice(combat_state)
	if not roll_result.get("ok", false):
		failures.append("roll_active_dice should succeed for valid starter dice")
		controller.free()
		return failures
	if ((combat_state.engine_state.get("rolled_faces", []) as Array)).size() != 3:
		failures.append("live controller roll path should advance CombatEngine rolled_faces")
	failures.append_array(_test_enemy_display_rolls_surface_actual_enemy_rolls(controller))

	# _build_player_summary / _build_slots_summary / _build_rolls_summary helpers
	# were removed during the UI refactor (PR #4). Re-add coverage once the new
	# battle-screen rendering surfaces these strings again.
	controller.assign_die_to_action(combat_state, "balanced_d6_alpha", "main_attack")
	controller.assign_die_to_action(combat_state, "balanced_d6_beta", "guard")
	controller.assign_die_to_action(combat_state, "balanced_d6_gamma", "utility")

	var player_result = controller.resolve_player_turn(combat_state)
	if not player_result.get("ok", false):
		failures.append("resolve_player_turn should succeed")
		return failures

	var enemy_hp_after_player: int = int((combat_state.enemy_state as Dictionary).get("hp", 0))
	if enemy_hp_after_player != 18:
		failures.append("player turn should damage but not defeat the tutorial enemy before enemy resolution")
	if int(((combat_state.engine_state.get("enemy", {}) as Dictionary).get("hp", -1))) != enemy_hp_after_player:
		failures.append("live controller resolve path should keep engine_state enemy hp in sync with combat state")

	if combat_state.state != "enemy_turn":
		failures.append("combat should pause on enemy_turn when the tutorial enemy survives player resolution")
	if controller.get_enemy_display_rolls(combat_state).size() != 3:
		failures.append("surviving tutorial enemy should roll dice before enemy resolution")

	var log_text: String = "\n".join(combat_state.turn_log)
	if log_text.find("Player turn resolved") == -1:
		failures.append("combat log should include player turn resolution")
	if log_text.find("incoming 8, absorbed 0, remaining 8, enemy block 0 -> 0") == -1:
		failures.append("combat log should include player damage absorption details")

	var incoming_enemy_damage := _enemy_roll_damage_total((combat_state.engine_state.get("enemy_rolls", []) as Array))
	var player_block_before_enemy := int(combat_state.player_block)
	var enemy_result = controller.resolve_enemy_turn(combat_state)
	if not bool(enemy_result.get("ok", false)):
		failures.append("resolve_enemy_turn should succeed after the enemy dice are shown")
	if combat_state.state != "player_roll":
		failures.append("combat should advance to the next player roll after enemy resolution")
	log_text = "\n".join(combat_state.turn_log)
	var absorbed_enemy_damage := mini(player_block_before_enemy, incoming_enemy_damage)
	var remaining_enemy_damage := maxi(incoming_enemy_damage - absorbed_enemy_damage, 0)
	var block_after_enemy := maxi(player_block_before_enemy - absorbed_enemy_damage, 0)
	var expected_enemy_log := "Enemy turn resolved: incoming %d, absorbed %d, remaining %d, player block %d -> %d" % [
		incoming_enemy_damage,
		absorbed_enemy_damage,
		remaining_enemy_damage,
		player_block_before_enemy,
		block_after_enemy,
	]
	if log_text.find(expected_enemy_log) == -1:
		failures.append("combat log should include enemy dice-derived damage details")

	var skipped_controller = CombatControllerScript.new()
	skipped_controller.content_catalog = catalog
	var skipped_state = skipped_controller.begin_encounter(RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {
			"hp": 30,
			"status_effects": [{"id": "freeze", "stacks": 1, "duration": 1, "timing": "player_turn_start"}],
		},
		"active_dice": [
			{
				"id": "balanced_d6_alpha",
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
	}), {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4],
	})
	if skipped_state == null or skipped_state is Dictionary:
		failures.append("begin_encounter should create combat state for skipped-turn UI test")
		controller.free()
		skipped_controller.free()
		return failures
	skipped_controller.combat_state = skipped_state
	var skipped_roll_result = skipped_controller.roll_active_dice(skipped_state)
	if not skipped_roll_result.get("ok", false):
		failures.append("roll_active_dice should succeed for skipped-turn UI test")
	else:
		if skipped_state.state != "enemy_turn":
			failures.append("battle screen should enter enemy_turn state when player turn is skipped")
		# _build_rolls_summary skipped-turn assertion removed alongside the helper itself.

	controller.free()
	skipped_controller.free()
	return failures


func _test_enemy_rolls_wait_for_enemy_resolution(catalog) -> Array[String]:
	var failures: Array[String] = []
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog
	var state = controller.begin_encounter(RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{
				"id": "guard_die",
				"label": "Guard Die",
				"body_id": "standard_d6",
				"face_set": ["guard", "guard", "guard", "guard", "guard", "guard"],
			},
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []}
		],
	}), {
		"id": "enemy_roll_visibility",
		"name": "Enemy Roll Visibility",
		"enemy_id": "slime_echo",
		"player_rolls": [1],
	})
	if state == null or state is Dictionary:
		controller.free()
		return ["begin_encounter should create combat state for enemy roll visibility test"]
	controller.combat_state = state

	var roll_result = controller.roll_active_dice(state)
	if not bool(roll_result.get("ok", false)):
		controller.free()
		return ["roll_active_dice should succeed for enemy roll visibility test"]
	controller.assign_die_to_action(state, "guard_die", "guard")

	var before_player_hp := int(state.player_hp)
	var player_result = controller.resolve_player_turn(state)
	if not bool(player_result.get("ok", false)):
		controller.free()
		return ["resolve_player_turn should succeed for enemy roll visibility test"]
	if str(state.state) != "enemy_turn":
		failures.append("non-lethal player resolve should stop at enemy_turn before enemy damage")
	if int(state.player_hp) != before_player_hp:
		failures.append("enemy should not damage the player while only enemy dice are being shown")
	if (state.roll_results as Array).is_empty():
		failures.append("player dice should remain visible while enemy dice are shown")
	var enemy_rolls: Array = controller.get_enemy_display_rolls(state)
	if enemy_rolls.size() != 3:
		failures.append("enemy dice should be rolled and visible before enemy resolution")

	var enemy_result = controller.resolve_enemy_turn(state)
	if not bool(enemy_result.get("ok", false)):
		controller.free()
		return ["resolve_enemy_turn should succeed for enemy roll visibility test"]
	if str(state.state) != "player_roll":
		failures.append("enemy resolution should advance to the next player roll when battle continues")
	if int(state.player_hp) >= before_player_hp:
		failures.append("enemy resolution should apply damage after enemy dice are shown")
	if not (state.roll_results as Array).is_empty():
		failures.append("player dice should clear after enemy resolution advances the round")

	controller.free()
	return failures


func _enemy_roll_damage_total(enemy_rolls: Array) -> int:
	var total := 0
	for roll in enemy_rolls:
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("effect", "")) != "damage":
			continue
		total += maxi(int(entry.get("damage", entry.get("rolled_value", 0))), 0)
	return total


func _test_enemy_display_rolls_surface_actual_enemy_rolls(controller) -> Array[String]:
	var failures: Array[String] = []
	var hidden_state := {
		"engine_state": {"turn_index": 1, "enemy_rolls": []},
		"enemy_state": {"ai_pattern": []},
	}
	var hidden_rolls: Array = controller.get_enemy_display_rolls(hidden_state)
	if not hidden_rolls.is_empty():
		failures.append("enemy dice helper should return no rolls before the enemy turn")
		return failures

	var visible_state := {
		"engine_state": {
			"turn_index": 2,
			"enemy_rolls": [
				{
					"die_id": "enemy_turn_2_0",
					"die_label": "Enemy Die 1",
					"rolled_value": 1,
					"face_id": "attack",
					"face_family": "enemy",
					"face_label": "Strike",
					"energy_cost": 0,
					"effect_label": "Attack",
					"action_label": "Strike",
				},
				{
					"die_id": "enemy_turn_2_1",
					"die_label": "Enemy Die 2",
					"rolled_value": 4,
					"face_id": "debuff",
					"face_family": "enemy",
					"face_label": "Venom",
					"energy_cost": 0,
					"effect_label": "Debuff",
					"action_label": "Venom",
				},
				{
					"die_id": "enemy_turn_2_2",
					"die_label": "Enemy Die 3",
					"rolled_value": 6,
					"face_id": "lock",
					"face_family": "enemy",
					"face_label": "Seal",
					"energy_cost": 0,
					"effect_label": "Lock",
					"action_label": "Seal",
				},
			],
		},
		"enemy_state": {"ai_pattern": []},
	}
	var enemy_display_rolls: Array = controller.get_enemy_display_rolls(visible_state)
	if enemy_display_rolls.size() != 3:
		failures.append("enemy dice helper should mirror actual enemy rolls; got %d" % enemy_display_rolls.size())
		return failures

	var expected_values := [1, 4, 6]
	for index in range(enemy_display_rolls.size()):
		var roll: Dictionary = enemy_display_rolls[index] as Dictionary
		if str(roll.get("die_id", "")) == "":
			failures.append("enemy dice roll %d should have a die_id" % (index + 1))
		if str(roll.get("face_label", "")) == "":
			failures.append("enemy dice roll %d should have a face label" % (index + 1))
		if int(roll.get("rolled_value", 0)) != expected_values[index]:
			failures.append("enemy dice roll %d should preserve the rolled value" % (index + 1))
	return failures
