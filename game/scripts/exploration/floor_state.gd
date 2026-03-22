class_name FloorState
extends RefCounted

var floor_index: int
var floor_template_id: String
var start_room_id: String
var boss_room_id: String
var next_floor_id: String
var room_ids: Array
var visited_room_ids: Array
var completed_room_ids: Array


func _init(data: Dictionary = {}) -> void:
	floor_index = int(data.get("floor_index", 1))
	floor_template_id = str(data.get("floor_template_id", data.get("id", "")))
	start_room_id = str(data.get("start_room_id", data.get("starting_room_id", "")))
	boss_room_id = str(data.get("boss_room_id", ""))
	next_floor_id = str(data.get("next_floor_id", ""))
	room_ids = (data.get("room_ids", []) as Array).duplicate(true)
	visited_room_ids = (data.get("visited_room_ids", []) as Array).duplicate(true)
	completed_room_ids = (data.get("completed_room_ids", []) as Array).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"floor_index": floor_index,
		"floor_template_id": floor_template_id,
		"start_room_id": start_room_id,
		"boss_room_id": boss_room_id,
		"next_floor_id": next_floor_id,
		"room_ids": room_ids.duplicate(true),
		"visited_room_ids": visited_room_ids.duplicate(true),
		"completed_room_ids": completed_room_ids.duplicate(true),
	}
