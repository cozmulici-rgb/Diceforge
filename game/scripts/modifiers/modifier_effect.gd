class_name ModifierEffect
extends RefCounted

var id: String
var name: String
var modifier_type: String
var application_scope: String
var effect_tags: Array
var stack_mode: String
var effects: Dictionary


func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", data.get("modifier_id", "")))
	name = str(data.get("name", id))
	modifier_type = str(data.get("modifier_type", "curse"))
	application_scope = str(data.get("application_scope", "combat"))
	effect_tags = (data.get("effect_tags", []) as Array).duplicate(true)
	stack_mode = str(data.get("stack_mode", "unique"))
	effects = (data.get("effects", {}) as Dictionary).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"modifier_id": id,
		"modifier_type": modifier_type,
		"application_scope": application_scope,
		"effect_tags": effect_tags.duplicate(true),
		"stack_mode": stack_mode,
		"effects": effects.duplicate(true),
	}
