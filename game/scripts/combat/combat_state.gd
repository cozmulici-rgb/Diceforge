class_name CombatState
extends RefCounted

var encounter_id: String
var room_id: String
var round_index: int
var player_hp: int
var player_block: int
var active_dice: Array
var action_slots: Array
var roll_results: Array
var enemy_state: Dictionary
var modifier_snapshot: Dictionary
var turn_log: Array
var pending_player_rolls: Array
var state: String
var outcome: String
var engine_state: Dictionary


func _init(data: Dictionary = {}) -> void:
	encounter_id = str(data.get("encounter_id", ""))
	room_id = str(data.get("room_id", ""))
	round_index = int(data.get("round_index", 1))
	player_hp = int(data.get("player_hp", 0))
	player_block = int(data.get("player_block", 0))
	active_dice = (data.get("active_dice", []) as Array).duplicate(true)
	action_slots = (data.get("action_slots", []) as Array).duplicate(true)
	roll_results = (data.get("roll_results", []) as Array).duplicate(true)
	enemy_state = (data.get("enemy_state", {}) as Dictionary).duplicate(true)
	modifier_snapshot = (data.get("modifier_snapshot", {}) as Dictionary).duplicate(true)
	turn_log = (data.get("turn_log", []) as Array).duplicate(true)
	pending_player_rolls = (data.get("pending_player_rolls", []) as Array).duplicate(true)
	state = str(data.get("state", "player_roll"))
	outcome = str(data.get("outcome", ""))
	engine_state = (data.get("engine_state", {}) as Dictionary).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"encounter_id": encounter_id,
		"room_id": room_id,
		"round_index": round_index,
		"player_hp": player_hp,
		"player_block": player_block,
		"active_dice": active_dice.duplicate(true),
		"action_slots": action_slots.duplicate(true),
		"roll_results": roll_results.duplicate(true),
		"enemy_state": enemy_state.duplicate(true),
		"modifier_snapshot": modifier_snapshot.duplicate(true),
		"turn_log": turn_log.duplicate(true),
		"pending_player_rolls": pending_player_rolls.duplicate(true),
		"state": state,
		"outcome": outcome,
		"engine_state": engine_state.duplicate(true),
	}
