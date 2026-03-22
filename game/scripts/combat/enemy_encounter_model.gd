class_name EnemyEncounterModel
extends RefCounted

var enemy_id: String
var display_name: String
var hp: int
var block: int
var intent_label: String
var intent_damage: int


func _init(data: Dictionary = {}) -> void:
	enemy_id = str(data.get("enemy_id", data.get("id", "")))
	display_name = str(data.get("display_name", data.get("name", enemy_id)))
	hp = int(data.get("hp", 1))
	block = int(data.get("block", 0))
	intent_label = str(data.get("intent_label", data.get("intent", "Strike")))
	intent_damage = int(data.get("intent_damage", data.get("damage", 0)))


func to_dictionary() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"display_name": display_name,
		"hp": hp,
		"block": block,
		"intent_label": intent_label,
		"intent_damage": intent_damage,
	}
