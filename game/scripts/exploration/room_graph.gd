class_name RoomGraph
extends RefCounted

const RoomStateScript = preload("res://scripts/exploration/room_state.gd")

var graph_id: String
var graph_name: String
var rooms: Dictionary = {}
var connections: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	graph_id = str(data.get("id", ""))
	graph_name = str(data.get("name", graph_id))
	_build_rooms(data.get("rooms", []), data.get("room_states", {}))
	_build_connections(data.get("links", []))


func get_room(room_id: String):
	if not rooms.has(room_id):
		return null
	return rooms[room_id]


func get_neighbor_ids(room_id: String) -> Array[String]:
	var neighbor_ids: Array[String] = []
	for neighbor_id in (connections.get(room_id, []) as Array):
		neighbor_ids.append(str(neighbor_id))
	return neighbor_ids


func has_room(room_id: String) -> bool:
	return rooms.has(room_id)


func _build_rooms(room_list: Array, room_states: Dictionary) -> void:
	for room_data in room_list:
		if not (room_data is Dictionary):
			continue

		var room_id := str(room_data.get("id", ""))
		if room_id == "":
			continue

		var merged_data: Dictionary = room_data.duplicate(true)
		var state_data = room_states.get(room_id, {})
		if state_data is Dictionary:
			for key in state_data.keys():
				merged_data[key] = state_data[key]

		rooms[room_id] = RoomStateScript.new(merged_data)


func _build_connections(link_list: Array) -> void:
	for link in link_list:
		if not (link is Dictionary):
			continue

		var from_room := str(link.get("from", ""))
		var to_room := str(link.get("to", ""))
		if from_room == "" or to_room == "":
			continue

		_add_connection(from_room, to_room)
		_add_connection(to_room, from_room)


func _add_connection(from_room: String, to_room: String) -> void:
	if not connections.has(from_room):
		connections[from_room] = []

	var neighbor_ids: Array = connections[from_room]
	if not neighbor_ids.has(to_room):
		neighbor_ids.append(to_room)
		connections[from_room] = neighbor_ids
