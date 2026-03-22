class_name ForgeMutation
extends RefCounted

var target_die_id: String
var operation: String
var part_id: String
var slot_id: String


func _init(data: Dictionary = {}) -> void:
	target_die_id = str(data.get("target_die_id", ""))
	operation = str(data.get("operation", ""))
	part_id = str(data.get("part_id", ""))
	slot_id = str(data.get("slot_id", ""))


func to_dictionary() -> Dictionary:
	return {
		"target_die_id": target_die_id,
		"operation": operation,
		"part_id": part_id,
		"slot_id": slot_id,
	}
