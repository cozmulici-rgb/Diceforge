class_name SaveSlotSummary
extends RefCounted

var slot_id: String
var session_id: String
var archetype_id: String
var display_name: String
var floor_index: int
var room_id: String
var updated_at_unix: int
var is_corrupt: bool


func _init(data: Dictionary = {}) -> void:
	slot_id = str(data.get("slot_id", ""))
	session_id = str(data.get("session_id", ""))
	archetype_id = str(data.get("archetype_id", ""))
	display_name = str(data.get("display_name", ""))
	floor_index = int(data.get("floor_index", 0))
	room_id = str(data.get("room_id", ""))
	updated_at_unix = int(data.get("updated_at_unix", 0))
	is_corrupt = bool(data.get("is_corrupt", false))


func to_dictionary() -> Dictionary:
	return {
		"slot_id": slot_id,
		"session_id": session_id,
		"archetype_id": archetype_id,
		"display_name": display_name,
		"floor_index": floor_index,
		"room_id": room_id,
		"updated_at_unix": updated_at_unix,
		"is_corrupt": is_corrupt,
	}
