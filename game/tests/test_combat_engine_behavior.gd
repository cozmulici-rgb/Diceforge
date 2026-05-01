extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()

	_test_player_freeze_skips_exactly_one_turn(catalog, failures)
	_test_enemy_freeze_skips_exactly_one_turn(catalog, failures)
	_test_player_poison_ticks_on_player_turn_end(catalog, failures)
	_test_phase_transition_keeps_resolution_loop_going(catalog, failures)

	return failures


func _test_player_freeze_skips_exactly_one_turn(catalog, failures: Array[String]) -> void:
	var engine = CombatEngineScript.new(catalog)
	engine.initialize_battle({
		"hp": 20,
		"max_hp": 20,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [{"id": "freeze", "stacks": 1, "duration": 1, "timing": "player_turn_start"}],
		"dice_pool": [
			{
				"id": "d_strike",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
		],
	}, {
		"id": "slime_echo",
		"name": "Slime Echo",
		"hp": 8,
		"max_hp": 8,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 2, "label": "Gel Strike"}],
	})

	engine.start_player_turn()
	var state_after_start: Dictionary = engine.get_state()
	if not bool(state_after_start.get("player_skip_turn", false)):
		failures.append("freeze on player should mark the upcoming player turn as skipped")
	if not ((state_after_start.get("player", {}) as Dictionary).get("statuses", []) as Array).is_empty():
		failures.append("freeze should be consumed during player_turn_start tick")

	engine.end_player_turn()
	if str(engine.check_battle_end().get("result", "")) != "ongoing":
		failures.append("skipped player turn should still continue the battle when both sides live")

	engine.run_enemy_turn()
	engine.end_enemy_turn()
	var state_after_enemy_turn: Dictionary = engine.get_state()
	if int(((state_after_enemy_turn.get("player", {}) as Dictionary).get("hp", -1))) != 18:
		failures.append("enemy attack should still resolve after a skipped player turn")

	engine.start_player_turn()
	var state_next_turn: Dictionary = engine.get_state()
	if bool(state_next_turn.get("player_skip_turn", false)):
		failures.append("freeze should only skip one player turn")


func _test_enemy_freeze_skips_exactly_one_turn(catalog, failures: Array[String]) -> void:
	var engine = CombatEngineScript.new(catalog)
	engine.initialize_battle({
		"hp": 20,
		"max_hp": 20,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [],
	}, {
		"id": "frozen_enemy",
		"name": "Frozen Enemy",
		"hp": 10,
		"max_hp": 10,
		"starting_block": 0,
		"statuses": [{"id": "freeze", "stacks": 1, "duration": 1, "timing": "enemy_turn_start"}],
		"ai_pattern": [{"action": "attack", "damage": 3, "label": "Claw"}],
	})

	engine.run_enemy_turn()
	var state_after_skip: Dictionary = engine.get_state()
	if not bool(state_after_skip.get("enemy_skip_turn", false)):
		failures.append("freeze on enemy should mark the enemy turn as skipped")
	if int(((state_after_skip.get("player", {}) as Dictionary).get("hp", -1))) != 20:
		failures.append("skipped enemy turn should not damage the player")
	if not ((state_after_skip.get("enemy", {}) as Dictionary).get("statuses", []) as Array).is_empty():
		failures.append("enemy freeze should be consumed during enemy_turn_start tick")

	engine.end_enemy_turn()
	engine.run_enemy_turn()
	var state_after_live_turn: Dictionary = engine.get_state()
	if int(((state_after_live_turn.get("player", {}) as Dictionary).get("hp", -1))) != 17:
		failures.append("enemy should act normally on the turn after freeze is consumed")


func _test_player_poison_ticks_on_player_turn_end(catalog, failures: Array[String]) -> void:
	var engine = CombatEngineScript.new(catalog)
	engine.initialize_battle({
		"hp": 20,
		"max_hp": 20,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [{"id": "poison", "stacks": 2, "duration": 2, "timing": "player_turn_end"}],
		"dice_pool": [],
	}, {
		"id": "poison_witness",
		"name": "Poison Witness",
		"hp": 10,
		"max_hp": 10,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [],
	})

	engine.start_player_turn()
	var after_start: Dictionary = engine.get_state()
	if int(((after_start.get("player", {}) as Dictionary).get("hp", -1))) != 20:
		failures.append("player poison should not tick at player_turn_start")

	engine.end_player_turn()
	var after_end: Dictionary = engine.get_state()
	var poisoned_player: Dictionary = (after_end.get("player", {}) as Dictionary).duplicate(true)
	var remaining_statuses: Array = (poisoned_player.get("statuses", []) as Array).duplicate(true)
	if int(poisoned_player.get("hp", -1)) != 18:
		failures.append("player poison should tick for stacks damage at player_turn_end")
	if remaining_statuses.size() != 1 or int((remaining_statuses[0] as Dictionary).get("duration", -1)) != 1:
		failures.append("player poison should persist with decremented duration after first tick")


func _test_phase_transition_keeps_resolution_loop_going(catalog, failures: Array[String]) -> void:
	var engine = CombatEngineScript.new(catalog)
	engine.initialize_battle({
		"hp": 20,
		"max_hp": 20,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [
			{
				"id": "d_alpha",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
			{
				"id": "d_beta",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
		],
	}, {
		"id": "phase_target",
		"name": "Phase Target",
		"hp": 4,
		"max_hp": 4,
		"starting_block": 0,
		"statuses": [],
		"is_boss": true,
		"ai_pattern": [{"action": "attack", "damage": 1, "label": "Tap"}],
		"phases": [
			{
				"phase_index": 1,
				"hp": 4,
				"max_hp": 4,
				"starting_block": 0,
				"intent": "Tap",
				"damage": 1,
				"ai_pattern": [{"action": "attack", "damage": 1, "label": "Tap"}],
			},
			{
				"phase_index": 2,
				"hp": 10,
				"max_hp": 10,
				"starting_block": 0,
				"intent": "Swing",
				"damage": 2,
				"ai_pattern": [{"action": "attack", "damage": 2, "label": "Swing"}],
			},
		],
	})

	engine.roll_phase([4, 4])
	engine.set_resolution_queue((engine.get_state().get("rolled_faces", []) as Array).duplicate(true))
	engine.run_resolution_loop()

	var state_after_resolution: Dictionary = engine.get_state()
	var enemy_after_resolution: Dictionary = (state_after_resolution.get("enemy", {}) as Dictionary).duplicate(true)
	if int(enemy_after_resolution.get("phase_index", -1)) != 1:
		failures.append("enemy should advance into the second phase when first phase hp reaches zero")
	if int(enemy_after_resolution.get("hp", -1)) != 2:
		failures.append("resolution loop should continue into the new phase with remaining dice")
	if (engine.get_log().get_entries().filter(func(entry: Dictionary) -> bool:
		return str(entry.get("step_kind", "")) == "phase_transition"
	) as Array).is_empty():
		failures.append("phase transition should be recorded in the battle log")
