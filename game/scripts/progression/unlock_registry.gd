class_name UnlockRegistry
extends RefCounted

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func list_available_unlocks(meta_state) -> Array:
	var unlocks: Array = []
	for unlock_id in content_catalog.get_progression_definitions("unlock").keys():
		var unlock_definition: Dictionary = content_catalog.get_progression_definitions("unlock")[unlock_id]
		if not _is_unlocked(meta_state, unlock_definition):
			unlocks.append(unlock_definition.duplicate(true))
	return unlocks


func apply_unlocks(meta_state, run_summary: Dictionary) -> Array[String]:
	var unlocked_ids: Array[String] = []
	for unlock_definition in list_available_unlocks(meta_state):
		var threshold := int(unlock_definition.get("echo_shard_threshold", 0))
		if meta_state.echo_shards < threshold:
			continue
		var unlock_type := str(unlock_definition.get("unlock_type", ""))
		var target_id := str(unlock_definition.get("target_id", ""))
		if unlock_type == "archetype" and not (meta_state.unlocked_archetype_ids as Array).has(target_id):
			meta_state.unlocked_archetype_ids.append(target_id)
			unlocked_ids.append(str(unlock_definition.get("id", target_id)))
		elif unlock_type == "part" and not (meta_state.unlocked_part_ids as Array).has(target_id):
			meta_state.unlocked_part_ids.append(target_id)
			unlocked_ids.append(str(unlock_definition.get("id", target_id)))
	return unlocked_ids


func _is_unlocked(meta_state, unlock_definition: Dictionary) -> bool:
	var unlock_type := str(unlock_definition.get("unlock_type", ""))
	var target_id := str(unlock_definition.get("target_id", ""))
	if unlock_type == "archetype":
		return (meta_state.unlocked_archetype_ids as Array).has(target_id)
	if unlock_type == "part":
		return (meta_state.unlocked_part_ids as Array).has(target_id)
	return false
