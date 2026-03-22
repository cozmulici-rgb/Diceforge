class_name RunSession
extends RefCounted

const SCHEMA_VERSION := 1

var session_id: String
var archetype_id: String
var floor_index: int
var current_room_id: String
var room_graph_id: String
var player_state: Dictionary
var active_dice: Array
var inventory: Dictionary
var modifiers: Array
var flags: Dictionary
var room_states: Dictionary


func _init(data: Dictionary = {}) -> void:
	session_id = str(data.get("session_id", ""))
	archetype_id = str(data.get("archetype_id", ""))
	floor_index = int(data.get("floor_index", 1))
	current_room_id = str(data.get("current_room_id", ""))
	room_graph_id = str(data.get("room_graph_id", ""))
	player_state = (data.get("player_state", {})).duplicate(true)
	active_dice = (data.get("active_dice", [])).duplicate(true)
	inventory = (data.get("inventory", {})).duplicate(true)
	modifiers = (data.get("modifiers", [])).duplicate(true)
	flags = (data.get("flags", {})).duplicate(true)
	room_states = (data.get("room_states", {})).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id,
		"archetype_id": archetype_id,
		"floor_index": floor_index,
		"current_room_id": current_room_id,
		"room_graph_id": room_graph_id,
		"player_state": player_state.duplicate(true),
		"active_dice": active_dice.duplicate(true),
		"inventory": inventory.duplicate(true),
		"modifiers": modifiers.duplicate(true),
		"flags": flags.duplicate(true),
		"room_states": room_states.duplicate(true),
	}
