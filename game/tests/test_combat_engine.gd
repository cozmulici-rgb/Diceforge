extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")


class FakeRng:
	extends RefCounted

	var _values: Array = []
	var _index: int = 0

	func _init(values: Array = []) -> void:
		_values = values.duplicate(true)

	func randi_range(minimum: int, maximum: int) -> int:
		if _values.is_empty():
			return minimum
		var value := int(_values[min(_index, _values.size() - 1)])
		_index += 1
		return clampi(value, minimum, maximum)


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()

	var engine = CombatEngineScript.new(catalog)
	var player_data := {
		"hp": 20,
		"max_hp": 30,
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
		],
	}
	var enemy_def := {
		"id": "slime_echo",
		"name": "Slime Echo",
		"hp": 4,
		"max_hp": 4,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 2, "label": "Gel Strike"}],
	}
	if not engine.initialize_battle(player_data, enemy_def).get("ok", false):
		failures.append("initialize_battle should succeed")
		return failures
	if not engine.roll_phase([4]).get("ok", false):
		failures.append("roll_phase should succeed")
		return failures
	engine.build_autoplay_queue()
	if not engine.run_resolution_loop().get("ok", false):
		failures.append("run_resolution_loop should succeed")
		return failures
	if int(((engine.get_state().get("enemy", {}) as Dictionary).get("hp", -1))) != 0:
		failures.append("enemy should be reduced to 0 hp")
	engine.end_player_turn()
	if str(engine.check_battle_end().get("result", "")) != "victory":
		failures.append("combat should end in victory")

	var engine2 = CombatEngineScript.new(catalog)
	engine2.initialize_battle({
		"hp": 2,
		"max_hp": 10,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [
			{
				"id": "d_guard",
				"body_id": "standard_d6",
				"face_set": ["guard", "guard", "guard", "guard", "guard", "guard"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
		],
	}, {
		"id": "crusher",
		"name": "Crusher",
		"hp": 100,
		"max_hp": 100,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 10, "label": "Smash"}],
	})
	engine2.roll_phase([1])
	engine2.build_autoplay_queue()
	engine2.run_resolution_loop()
	engine2.end_player_turn()
	if str(engine2.check_battle_end().get("result", "")) != "ongoing":
		failures.append("battle should continue after non-lethal player turn")
	engine2.run_enemy_turn()
	engine2.end_enemy_turn()
	if str(engine2.check_battle_end().get("result", "")) != "defeat":
		failures.append("enemy turn should defeat the player")
	if int((engine2.get_state() as Dictionary).get("turn_index", -1)) < 2:
		failures.append("turn_index should increment after enemy turn")
	if (engine.get_log().get_entries() as Array).is_empty():
		failures.append("BattleLog should contain entries")

	var preview_rolls: Array = engine.build_enemy_rolls({"action": "attack", "damage": 3, "label": "Gel Strike"}, 1, 3, FakeRng.new([1, 4, 6]))
	if preview_rolls.size() != 3:
		failures.append("enemy roll builder should return three preview rolls")
	else:
		var values: Array[int] = []
		for entry in preview_rolls:
			values.append(int((entry as Dictionary).get("rolled_value", 0)))
		if values != [1, 4, 6]:
			failures.append("enemy roll builder should preserve the RNG sequence; got %s" % str(values))
		if str(((preview_rolls[0] as Dictionary).get("die_label", ""))) != "Enemy Die 1":
			failures.append("enemy roll builder should label rolls by position")

	var engine3 = CombatEngineScript.new(catalog)
	engine3.initialize_battle({
		"hp": 20,
		"max_hp": 30,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [
			{
				"id": "d_hooked",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
				"statuses": [],
				"runes": ["ember_rune"],
				"core": "ember_core",
			},
		],
	}, {
		"id": "hook_target",
		"name": "Hook Target",
		"hp": 20,
		"max_hp": 20,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 1, "label": "Tap"}],
	})
	engine3.roll_phase([1])
	var enemy_after_roll: Dictionary = (engine3.get_state().get("enemy", {}) as Dictionary).duplicate(true)
	var statuses_after_roll: Array = (enemy_after_roll.get("statuses", []) as Array).duplicate(true)
	if statuses_after_roll.is_empty():
		failures.append("on_roll core hooks should apply enemy statuses")
	engine3.build_autoplay_queue()
	engine3.run_resolution_loop()
	var enemy_after_resolution: Dictionary = (engine3.get_state().get("enemy", {}) as Dictionary).duplicate(true)
	var statuses_after_resolution: Array = (enemy_after_resolution.get("statuses", []) as Array).duplicate(true)
	if statuses_after_resolution.is_empty() or int((statuses_after_resolution[0] as Dictionary).get("stacks", 0)) < 2:
		failures.append("on_resolution rune hooks should stack onto existing statuses")

	return failures
