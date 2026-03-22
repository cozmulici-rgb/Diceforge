class_name DungeonGenerator
extends RefCounted

const FloorStateScript = preload("res://scripts/exploration/floor_state.gd")
const RoomGraphScript = preload("res://scripts/exploration/room_graph.gd")

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func generate_floor(template_id: String, seed: int, run_state = null):
	var floor_template = content_catalog.load_floor_template(template_id)
	if _is_error_result(floor_template):
		return floor_template

	var room_graph_data = content_catalog.load_room_graph(str(floor_template.get("room_graph_id", "")))
	if _is_error_result(room_graph_data):
		return room_graph_data

	var room_ids: Array[String] = []
	for room in room_graph_data.get("rooms", []):
		if room is Dictionary:
			room_ids.append(str(room.get("id", "")))

	var visited_room_ids: Array = []
	var completed_room_ids: Array = []
	if run_state != null:
		for room_id in room_ids:
			var room_state: Dictionary = (run_state.room_states as Dictionary).get(room_id, {})
			if bool(room_state.get("revealed", false)):
				visited_room_ids.append(room_id)
			if bool(room_state.get("completed", false)):
				completed_room_ids.append(room_id)

	return FloorStateScript.new({
		"floor_index": int(run_state.floor_index) if run_state != null else 1,
		"floor_template_id": template_id,
		"start_room_id": str(floor_template.get("starting_room_id", "")),
		"boss_room_id": str(floor_template.get("boss_room_id", "")),
		"next_floor_id": str(floor_template.get("next_floor_id", "")),
		"generation_seed": seed,
		"room_ids": room_ids,
		"visited_room_ids": visited_room_ids,
		"completed_room_ids": completed_room_ids,
	})


func list_reachable_rooms(floor_state, from_room_id: String) -> Array[String]:
	var floor_template = content_catalog.load_floor_template(str(floor_state.floor_template_id))
	if _is_error_result(floor_template):
		return []
	var room_graph_data = content_catalog.load_room_graph(str(floor_template.get("room_graph_id", "")))
	if _is_error_result(room_graph_data):
		return []
	var room_graph = RoomGraphScript.new(room_graph_data)

	var visited: Dictionary = {}
	var pending: Array[String] = [from_room_id]
	while not pending.is_empty():
		var room_id: String = str(pending.pop_front())
		if visited.has(room_id):
			continue
		visited[room_id] = true
		for neighbor_id in room_graph.get_neighbor_ids(room_id):
			if not visited.has(neighbor_id):
				pending.append(neighbor_id)

	var reachable: Array[String] = []
	for room_id in visited.keys():
		reachable.append(str(room_id))
	reachable.sort()
	return reachable


func is_boss_path_reachable(floor_state) -> bool:
	return list_reachable_rooms(floor_state, str(floor_state.start_room_id)).has(str(floor_state.boss_room_id))


func _is_error_result(value: Variant) -> bool:
	return value is Dictionary and not value.get("ok", true)
