extends RefCounted

const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var resolver = EffectResolverScript.new()
	var player := {"hp": 20, "max_hp": 30, "block": 5, "energy": 3}
	var enemy := {"hp": 20, "max_hp": 20, "block": 3, "statuses": []}

	var damage_result := resolver.resolve_face({"effect": "damage", "value": 2, "energy_cost": 0}, 4, player.duplicate(true), enemy.duplicate(true), [], {})
	if int(((damage_result.get("enemy", {}) as Dictionary).get("hp", -1))) != 15:
		failures.append("damage should apply after block")
	var damage_summary: Dictionary = (damage_result.get("effect_summary", {}) as Dictionary).duplicate(true)
	if int(damage_summary.get("raw_damage", -1)) != 8 or int(damage_summary.get("absorbed_by_block", -1)) != 3 or int(damage_summary.get("hp_damage", -1)) != 5:
		failures.append("damage summary should expose raw damage, absorbed block, and hp damage")

	var block_result := resolver.resolve_face({"effect": "block", "value": 1, "energy_cost": 0}, 3, player.duplicate(true), enemy.duplicate(true), [], {})
	if int(((block_result.get("player", {}) as Dictionary).get("block", -1))) != 8:
		failures.append("block should scale from rolled value")
	if int((((block_result.get("effect_summary", {}) as Dictionary).get("block_gained", -1)))) != 3:
		failures.append("block summary should expose gained block")

	var heal_result := resolver.resolve_face({"effect": "heal", "value": 15, "energy_cost": 0}, 5, {"hp": 20, "max_hp": 30, "block": 0, "energy": 3}, enemy.duplicate(true), [], {})
	if int(((heal_result.get("player", {}) as Dictionary).get("hp", -1))) != 30:
		failures.append("heal should clamp to max hp")

	var burn_result := resolver.resolve_face({"effect": "burn", "value": 2, "duration": 3, "energy_cost": 0}, 1, player.duplicate(true), {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, [], {})
	var burn_statuses := (((burn_result.get("enemy", {}) as Dictionary).get("statuses", [])) as Array)
	if burn_statuses.size() != 1:
		failures.append("burn should add an enemy status")

	var amp_result := resolver.resolve_face({"effect": "amplify", "value": 3, "energy_cost": 0}, 2, player.duplicate(true), enemy.duplicate(true), [], {})
	var mods := amp_result.get("temporary_modifiers", []) as Array
	if mods.size() != 1 or int((mods[0] as Dictionary).get("bonus", -1)) != 3:
		failures.append("amplify should append one additive modifier")

	var amp_damage := resolver.resolve_face({"effect": "damage", "value": 2, "energy_cost": 0}, 3, player.duplicate(true), {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, [{"bonus": 3, "type": "damage_additive", "consumed": false}], {})
	if int((((amp_damage.get("enemy", {}) as Dictionary).get("hp", -1)))) != 11:
		failures.append("damage should consume amplify bonus")

	return failures
