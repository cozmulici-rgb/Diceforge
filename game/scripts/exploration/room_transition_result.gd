class_name RoomTransitionResult
extends RefCounted

var room_id: String
var room_type: String
var encounter_id: String
var reward_source_id: String
var floor_complete: bool
var run_complete: bool


func _init(data: Dictionary = {}) -> void:
	room_id = str(data.get("room_id", ""))
	room_type = str(data.get("room_type", "unknown"))
	encounter_id = str(data.get("encounter_id", ""))
	reward_source_id = str(data.get("reward_source_id", ""))
	floor_complete = bool(data.get("floor_complete", false))
	run_complete = bool(data.get("run_complete", false))


func to_dictionary() -> Dictionary:
	return {
		"ok": true,
		"room_id": room_id,
		"room_type": room_type,
		"encounter_id": encounter_id,
		"reward_source_id": reward_source_id,
		"floor_complete": floor_complete,
		"run_complete": run_complete,
	}
