extends RefCounted

const BattleLogScript = preload("res://scripts/combat/battle_log.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var log = BattleLogScript.new()

	log.record({
		"turn": 1,
		"step_kind": "roll",
		"die_id": "d_strike_01",
		"rolled_value": 4,
		"resolved_face": "Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 8,
		"modifiers_applied": [],
		"outcome": "rolled",
		"rerolled_from": null,
	})
	log.record({
		"turn": 1,
		"step_kind": "resolution",
		"die_id": "d_strike_01",
		"rolled_value": 4,
		"resolved_face": "Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 8,
		"modifiers_applied": [],
		"outcome": "8 damage to enemy",
		"rerolled_from": null,
	})
	log.record({
		"turn": 1,
		"step_kind": "roll",
		"die_id": "d_strike_01",
		"rolled_value": 6,
		"resolved_face": "Heavy Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 18,
		"modifiers_applied": [],
		"outcome": "rerolled",
		"rerolled_from": 0,
	})

	var entries := log.get_entries()
	if entries.size() != 3:
		failures.append("BattleLog should have 3 entries")
	if int((entries[0] as Dictionary).get("step_index", -1)) != 0:
		failures.append("first step_index should be 0")
	if int((entries[2] as Dictionary).get("rerolled_from", -1)) != 0:
		failures.append("reroll entry should reference original step")
	if log.get_entries_for_turn(1).size() != 3:
		failures.append("turn filter should return all turn 1 entries")

	return failures
