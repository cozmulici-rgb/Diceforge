extends RefCounted

const EnemyAIScript = preload("res://scripts/combat/enemy_ai.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var ai = EnemyAIScript.new()

	var action := ai.select_action({"ai_pattern": [{"action": "attack", "damage": 5, "label": "Strike"}]}, 1)
	if str(action.get("action", "")) != "attack" or int(action.get("damage", -1)) != 5:
		failures.append("single-action pattern should select attack")

	var cycled := {"ai_pattern": [
		{"action": "attack", "damage": 3, "label": "Gel Strike"},
		{"action": "debuff", "status": "poison", "stacks": 2, "duration": 2, "label": "Venom Splash"},
	]}
	var turn_two_action := str(ai.select_action(cycled, 2).get("action", ""))
	var turn_three_action := str(ai.select_action(cycled, 3).get("action", ""))
	if not ["attack", "debuff"].has(turn_two_action):
		failures.append("randomized selection should still return a valid pattern action for turn 2")
	if not ["attack", "debuff"].has(turn_three_action):
		failures.append("randomized selection should still return a valid pattern action for turn 3")
	failures.append_array(_test_select_action_ignores_turn_index_with_supplied_rng(ai))

	var player_after := ai.resolve_action({"action": "attack", "damage": 7, "label": "Strike"}, {"hp": 20, "max_hp": 20, "block": 3}, {})
	if int(player_after.get("hp", -1)) != 16 or int(player_after.get("block", -1)) != 0:
		failures.append("attack should drain block then hp")

	var poisoned := ai.resolve_action({"action": "debuff", "status": "poison", "stacks": 2, "duration": 3, "label": "Venom"}, {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, {})
	if (poisoned.get("statuses", []) as Array).size() != 1:
		failures.append("debuff should add one player status")
	else:
		var poison_status: Dictionary = ((poisoned.get("statuses", []) as Array)[0] as Dictionary)
		if str(poison_status.get("timing", "")) != "player_turn_end":
			failures.append("player poison should tick on player_turn_end")

	var frozen := ai.resolve_action({"action": "debuff", "status": "freeze", "stacks": 1, "duration": 1, "label": "Crystal Cage"}, {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, {})
	if (frozen.get("statuses", []) as Array).size() != 1:
		failures.append("freeze debuff should add one player status")
	else:
		var freeze_status: Dictionary = ((frozen.get("statuses", []) as Array)[0] as Dictionary)
		if str(freeze_status.get("timing", "")) != "player_turn_start":
			failures.append("player freeze should tick on player_turn_start")

	return failures


func _test_select_action_ignores_turn_index_with_supplied_rng(ai) -> Array[String]:
	var failures: Array[String] = []
	var enemy_state := {
		"id": "seeded_enemy",
		"phase_index": 1,
		"ai_pattern": [
			{"action": "attack", "damage": 3, "label": "Gel Strike"},
			{"action": "debuff", "status": "poison", "stacks": 2, "duration": 2, "label": "Venom Splash"},
			{"action": "lock", "label": "Crystal Seal"},
		],
	}

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 424242
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 424242

	var action_a: Dictionary = ai.select_action(enemy_state, 1, rng_a)
	var action_b: Dictionary = ai.select_action(enemy_state, 99, rng_b)
	if str(action_a.get("action", "")) != str(action_b.get("action", "")):
		failures.append("select_action should not depend on turn_index when a caller supplies the RNG")
	if not ["attack", "debuff", "lock"].has(str(action_a.get("action", ""))):
		failures.append("seeded select_action should still return a valid ai_pattern entry")
	return failures
