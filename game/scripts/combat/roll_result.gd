class_name RollResult
extends RefCounted

var die_id: String
var die_label: String
var rolled_value: int
var face_id: String
var face_family: String
var face_label: String
var assigned_slot_id: String
var consumed: bool


func _init(data: Dictionary = {}) -> void:
	die_id = str(data.get("die_id", ""))
	die_label = str(data.get("die_label", die_id))
	rolled_value = int(data.get("rolled_value", 1))
	face_id = str(data.get("face_id", ""))
	face_family = str(data.get("face_family", "utility"))
	face_label = str(data.get("face_label", face_id))
	assigned_slot_id = str(data.get("assigned_slot_id", ""))
	consumed = bool(data.get("consumed", false))


func to_dictionary() -> Dictionary:
	return {
		"die_id": die_id,
		"die_label": die_label,
		"rolled_value": rolled_value,
		"face_id": face_id,
		"face_family": face_family,
		"face_label": face_label,
		"assigned_slot_id": assigned_slot_id,
		"consumed": consumed,
	}
