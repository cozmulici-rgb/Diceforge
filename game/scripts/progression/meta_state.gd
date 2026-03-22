class_name MetaState
extends RefCounted

const SCHEMA_VERSION := 1

var echo_shards: int
var unlocked_archetype_ids: Array
var unlocked_part_ids: Array
var unlocked_upgrade_ids: Array
var achievement_ids: Array
var daily_void_history: Array


func _init(data: Dictionary = {}) -> void:
	echo_shards = int(data.get("echo_shards", 0))
	unlocked_archetype_ids = (data.get("unlocked_archetype_ids", ["starter_facetwalker"]) as Array).duplicate(true)
	unlocked_part_ids = (data.get("unlocked_part_ids", []) as Array).duplicate(true)
	unlocked_upgrade_ids = (data.get("unlocked_upgrade_ids", []) as Array).duplicate(true)
	achievement_ids = (data.get("achievement_ids", []) as Array).duplicate(true)
	daily_void_history = (data.get("daily_void_history", []) as Array).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"echo_shards": echo_shards,
		"unlocked_archetype_ids": unlocked_archetype_ids.duplicate(true),
		"unlocked_part_ids": unlocked_part_ids.duplicate(true),
		"unlocked_upgrade_ids": unlocked_upgrade_ids.duplicate(true),
		"achievement_ids": achievement_ids.duplicate(true),
		"daily_void_history": daily_void_history.duplicate(true),
	}
