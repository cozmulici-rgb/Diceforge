class_name EffectResolver
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")

var _clamping := ClampingScript.new()
var _status_engine := StatusEngineScript.new()


func resolve_face(face: Dictionary, rolled_value: int, player: Dictionary, enemy: Dictionary, temporary_modifiers: Array, _context: Dictionary) -> Dictionary:
	var effect := str(face.get("effect", "utility"))
	var value := int(face.get("value", 1))
	var updated_player := player.duplicate(true)
	var updated_enemy := enemy.duplicate(true)
	var updated_modifiers := _prune_consumed_modifiers(temporary_modifiers)

	match effect:
		"damage":
			var bonus := _consume_damage_modifier(updated_modifiers)
			var total_damage := rolled_value * value + bonus
			updated_enemy = _clamping.apply_damage_to_entity(updated_enemy, total_damage)

		"block":
			updated_player["block"] = _clamping.clamp_block(int(updated_player.get("block", 0)) + (rolled_value * value))

		"heal":
			var heal_amount := value
			var max_hp := int(updated_player.get("max_hp", updated_player.get("hp", 0)))
			updated_player["hp"] = _clamping.clamp_hp(int(updated_player.get("hp", 0)) + heal_amount, max_hp)

		"burn", "poison", "freeze":
			var statuses := (updated_enemy.get("statuses", []) as Array).duplicate(true)
			statuses = _status_engine.add_status(statuses, {
				"id": effect,
				"stacks": value,
				"duration": int(face.get("duration", 1)),
				"timing": _status_timing_for(effect),
			})
			updated_enemy["statuses"] = statuses

		"amplify":
			updated_modifiers.append({
				"type": "damage_additive",
				"bonus": value,
				"consumed": false,
			})

		"reroll":
			pass

		"utility":
			if str(face.get("utility_kind", "")) == "block":
				updated_player["block"] = _clamping.clamp_block(int(updated_player.get("block", 0)) + value)

	return {
		"player": updated_player,
		"enemy": updated_enemy,
		"temporary_modifiers": updated_modifiers,
	}


func _consume_damage_modifier(modifiers: Array) -> int:
	for index in range(modifiers.size()):
		var item: Dictionary = modifiers[index] as Dictionary
		if str(item.get("type", "")) == "damage_additive" and not bool(item.get("consumed", false)):
			item["consumed"] = true
			modifiers[index] = item
			return int(item.get("bonus", 0))
	return 0


func _prune_consumed_modifiers(modifiers: Array) -> Array:
	var remaining: Array = []
	for modifier in modifiers:
		var item: Dictionary = (modifier as Dictionary).duplicate(true)
		if not bool(item.get("consumed", false)):
			remaining.append(item)
	return remaining


func _status_timing_for(effect: String) -> String:
	match effect:
		"burn":
			return "player_turn_end"
		"poison":
			return "enemy_turn_end"
		"freeze", "stun":
			return "enemy_turn_start"
		_:
			return "player_turn_end"
