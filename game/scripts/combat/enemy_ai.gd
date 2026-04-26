class_name EnemyAI
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")

var _clamping := ClampingScript.new()
var _status_engine := StatusEngineScript.new()


func select_action(enemy_state: Dictionary, turn_index: int) -> Dictionary:
	var pattern := (enemy_state.get("ai_pattern", []) as Array).duplicate(true)
	if pattern.is_empty():
		return {
			"action": "attack",
			"damage": int(enemy_state.get("intent_damage", 0)),
			"label": str(enemy_state.get("intent_label", "Strike")),
		}
	var index := (maxi(turn_index, 1) - 1) % pattern.size()
	return (pattern[index] as Dictionary).duplicate(true)


func resolve_action(action: Dictionary, player: Dictionary, _context: Dictionary) -> Dictionary:
	var updated_player := player.duplicate(true)
	match str(action.get("action", "attack")):
		"attack":
			updated_player = _clamping.apply_damage_to_entity(updated_player, int(action.get("damage", 0)))
		"multi_hit":
			var hits := maxi(int(action.get("hits", 1)), 1)
			var damage_per_hit := int(action.get("damage_per_hit", action.get("damage", 0)))
			for _hit in range(hits):
				updated_player = _clamping.apply_damage_to_entity(updated_player, damage_per_hit)
		"debuff":
			var statuses := (updated_player.get("statuses", []) as Array).duplicate(true)
			statuses = _status_engine.add_status(statuses, {
				"id": str(action.get("status", "poison")),
				"stacks": int(action.get("stacks", 1)),
				"duration": int(action.get("duration", 1)),
				"timing": _timing_for_status(str(action.get("status", "poison"))),
			})
			updated_player["statuses"] = statuses
		"lock":
			pass
	return updated_player


func _timing_for_status(status_id: String) -> String:
	match status_id:
		"burn":
			return "player_turn_end"
		"poison":
			return "enemy_turn_end"
		"freeze", "stun":
			return "enemy_turn_start"
		_:
			return "player_turn_end"
