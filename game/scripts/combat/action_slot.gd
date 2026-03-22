class_name ActionSlot
extends RefCounted

var slot_id: String
var display_name: String
var allowed_families: Array
var min_assignments: int
var assigned_die_ids: Array


func _init(data: Dictionary = {}) -> void:
	slot_id = str(data.get("slot_id", ""))
	display_name = str(data.get("display_name", slot_id))
	allowed_families = (data.get("allowed_families", []) as Array).duplicate(true)
	min_assignments = int(data.get("min_assignments", 0))
	assigned_die_ids = (data.get("assigned_die_ids", []) as Array).duplicate(true)


func accepts_family(face_family: String) -> bool:
	return allowed_families.has(face_family)


func to_dictionary() -> Dictionary:
	return {
		"slot_id": slot_id,
		"display_name": display_name,
		"allowed_families": allowed_families.duplicate(true),
		"min_assignments": min_assignments,
		"assigned_die_ids": assigned_die_ids.duplicate(true),
	}
