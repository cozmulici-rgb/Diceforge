class_name StatusEngine
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")

const DAMAGE_STATUSES := ["burn", "poison"]
const STACK_DECREMENT_STATUSES := ["freeze", "stun"]

var _clamping := ClampingScript.new()


func tick_statuses(statuses: Array, timing_key: String, entity: Dictionary, _context: Dictionary) -> Dictionary:
	var remaining: Array = []
	var updated_entity := entity.duplicate(true)

	for status_entry in statuses:
		var status: Dictionary = (status_entry as Dictionary).duplicate(true)
		if str(status.get("timing", "")) != timing_key:
			remaining.append(status)
			continue

		var stacks := int(status.get("stacks", 0))
		var duration := int(status.get("duration", 0))
		var status_id := str(status.get("id", ""))

		if DAMAGE_STATUSES.has(status_id):
			updated_entity = _clamping.apply_damage_to_entity(updated_entity, stacks)

		if STACK_DECREMENT_STATUSES.has(status_id):
			stacks = _clamping.clamp_stacks(stacks - 1)
			status["stacks"] = stacks
		else:
			duration = _clamping.clamp_stacks(duration - 1)
			status["duration"] = duration

		if stacks > 0 and duration > 0:
			remaining.append(status)

	return {
		"statuses": remaining,
		"entity": updated_entity,
	}


func add_status(statuses: Array, new_status: Dictionary) -> Array:
	var updated := statuses.duplicate(true)
	var existing_index := _find_status_index(updated, str(new_status.get("id", "")))
	if existing_index == -1:
		updated.append(new_status.duplicate(true))
		return updated

	var existing: Dictionary = (updated[existing_index] as Dictionary).duplicate(true)
	existing["stacks"] = int(existing.get("stacks", 0)) + int(new_status.get("stacks", 0))
	existing["duration"] = maxi(int(existing.get("duration", 0)), int(new_status.get("duration", 0)))
	updated[existing_index] = existing
	return updated


func _find_status_index(statuses: Array, status_id: String) -> int:
	for index in range(statuses.size()):
		if str((statuses[index] as Dictionary).get("id", "")) == status_id:
			return index
	return -1
