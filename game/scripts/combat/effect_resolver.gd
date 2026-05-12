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
	var effect_summary := {}

	match effect:
		"damage":
			var bonus := _consume_damage_modifier(updated_modifiers)
			var base_damage := rolled_value * value
			var total_damage := base_damage + bonus
			var enemy_before := updated_enemy.duplicate(true)
			updated_enemy = _clamping.apply_damage_to_entity(updated_enemy, total_damage)
			effect_summary = _damage_summary(enemy_before, updated_enemy, base_damage, bonus, "enemy")

		"block":
			var block_before := int(updated_player.get("block", 0))
			var added_block := rolled_value * value
			updated_player["block"] = _clamping.clamp_block(block_before + added_block)
			effect_summary = {
				"target": "player",
				"effect": "block",
				"block_gained": added_block,
				"block_before": block_before,
				"block_after": int(updated_player.get("block", 0)),
			}

		"heal":
			var hp_before := int(updated_player.get("hp", 0))
			var heal_amount := value
			var max_hp := int(updated_player.get("max_hp", updated_player.get("hp", 0)))
			updated_player["hp"] = _clamping.clamp_hp(hp_before + heal_amount, max_hp)
			effect_summary = {
				"target": "player",
				"effect": "heal",
				"heal_requested": heal_amount,
				"heal_applied": int(updated_player.get("hp", 0)) - hp_before,
				"hp_before": hp_before,
				"hp_after": int(updated_player.get("hp", 0)),
			}

		"burn", "poison", "freeze":
			var statuses := (updated_enemy.get("statuses", []) as Array).duplicate(true)
			statuses = _status_engine.add_status(statuses, {
				"id": effect,
				"stacks": value,
				"duration": int(face.get("duration", 1)),
				"timing": _status_timing_for(effect),
			})
			updated_enemy["statuses"] = statuses
			effect_summary = {
				"target": "enemy",
				"effect": effect,
				"stacks": value,
				"duration": int(face.get("duration", 1)),
			}

		"amplify":
			updated_modifiers.append({
				"type": "damage_additive",
				"bonus": value,
				"consumed": false,
			})
			effect_summary = {
				"target": "player",
				"effect": "amplify",
				"bonus_added": value,
			}

		"reroll":
			effect_summary = {
				"target": "player",
				"effect": "reroll",
				"reroll_count": value,
			}

		"utility":
			if str(face.get("utility_kind", "")) == "block":
				var utility_block_before := int(updated_player.get("block", 0))
				updated_player["block"] = _clamping.clamp_block(utility_block_before + value)
				effect_summary = {
					"target": "player",
					"effect": "utility_block",
					"block_gained": value,
					"block_before": utility_block_before,
					"block_after": int(updated_player.get("block", 0)),
				}

	return {
		"player": updated_player,
		"enemy": updated_enemy,
		"temporary_modifiers": updated_modifiers,
		"effect_summary": effect_summary,
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


func _damage_summary(before_entity: Dictionary, after_entity: Dictionary, raw_damage: int, bonus: int, target: String) -> Dictionary:
	var block_before := int(before_entity.get("block", 0))
	var block_after := int(after_entity.get("block", 0))
	var hp_before := int(before_entity.get("hp", 0))
	var hp_after := int(after_entity.get("hp", 0))
	return {
		"target": target,
		"effect": "damage",
		"raw_damage": raw_damage,
		"bonus_applied": bonus,
		"absorbed_by_block": maxi(block_before - block_after, 0),
		"hp_damage": maxi(hp_before - hp_after, 0),
		"block_before": block_before,
		"block_after": block_after,
		"hp_before": hp_before,
		"hp_after": hp_after,
	}
