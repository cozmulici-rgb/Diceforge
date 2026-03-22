class_name RoomState
extends RefCounted

var room_id: String
var display_name: String
var room_type: String
var description: String
var encounter_id: String
var position: Vector2
var revealed: bool
var completed: bool
var visit_count: int


func _init(data: Dictionary = {}) -> void:
	room_id = str(data.get("room_id", data.get("id", "")))
	display_name = str(data.get("display_name", data.get("name", room_id)))
	room_type = str(data.get("room_type", data.get("type", "unknown")))
	description = str(data.get("description", ""))
	encounter_id = str(data.get("encounter_id", ""))
	position = _parse_position(data.get("position", [0, 0]))
	revealed = bool(data.get("revealed", false))
	completed = bool(data.get("completed", false))
	visit_count = int(data.get("visit_count", 0))


func to_dictionary() -> Dictionary:
	return {
		"room_id": room_id,
		"display_name": display_name,
		"room_type": room_type,
		"description": description,
		"encounter_id": encounter_id,
		"position": [position.x, position.y],
		"revealed": revealed,
		"completed": completed,
		"visit_count": visit_count,
	}


func _parse_position(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
