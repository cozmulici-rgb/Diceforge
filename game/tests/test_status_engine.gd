extends RefCounted

const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = StatusEngineScript.new()

	var enemy := {"hp": 20, "max_hp": 20, "block": 0}
	var statuses := [{"id": "burn", "stacks": 3, "duration": 2, "timing": "player_turn_end"}]
	var tick_result := engine.tick_statuses(statuses, "player_turn_end", enemy, {})
	var remaining := tick_result.get("statuses", []) as Array
	var entity_after := tick_result.get("entity", {}) as Dictionary
	if int(entity_after.get("hp", -1)) != 17:
		failures.append("burn should deal damage equal to stacks")
	if remaining.size() != 1 or int((remaining[0] as Dictionary).get("duration", -1)) != 1:
		failures.append("burn duration should decrement to 1")

	var tick_result2 := engine.tick_statuses(remaining, "player_turn_end", entity_after, {})
	if (tick_result2.get("statuses", []) as Array).size() != 0:
		failures.append("burn should expire when duration hits 0")

	var freeze_statuses := [{"id": "freeze", "stacks": 2, "duration": 2, "timing": "enemy_turn_start"}]
	var freeze_result := engine.tick_statuses(freeze_statuses, "enemy_turn_start", enemy, {})
	var freeze_remaining := freeze_result.get("statuses", []) as Array
	if freeze_remaining.size() != 1 or int((freeze_remaining[0] as Dictionary).get("stacks", -1)) != 1:
		failures.append("freeze should decrement stacks")

	var no_tick := engine.tick_statuses([{"id": "poison", "stacks": 2, "duration": 3, "timing": "enemy_turn_end"}], "player_turn_end", enemy, {})
	if int((((no_tick.get("statuses", []) as Array)[0]) as Dictionary).get("duration", -1)) != 3:
		failures.append("non-matching timing should not tick status")

	return failures
