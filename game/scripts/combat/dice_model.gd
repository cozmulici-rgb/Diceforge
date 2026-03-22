class_name DiceModel
extends RefCounted

const RollResultScript = preload("res://scripts/combat/roll_result.gd")


func validate_die_build(die_build: Dictionary, body_definitions: Dictionary, face_definitions: Dictionary) -> Dictionary:
	var body_id: String = str(die_build.get("body_id", "standard_d6"))
	if not body_definitions.has(body_id):
		return {"ok": false, "error": "missing_body_definition", "body_id": body_id}

	var face_set = die_build.get("face_set", [])
	if not (face_set is Array) or face_set.is_empty():
		return {"ok": false, "error": "missing_face_set", "die_id": str(die_build.get("id", ""))}

	for face_id in face_set:
		if not face_definitions.has(str(face_id)):
			return {"ok": false, "error": "missing_face_definition", "face_id": str(face_id)}

	return {"ok": true}


func roll_active_dice(active_dice: Array, face_definitions: Dictionary, body_definitions: Dictionary, pending_rolls: Array = []) -> Dictionary:
	var results: Array = []
	var remaining_rolls: Array = pending_rolls.duplicate(true)

	for die_build in active_dice:
		if not (die_build is Dictionary):
			continue

		var validation = validate_die_build(die_build, body_definitions, face_definitions)
		if not validation.get("ok", false):
			return validation

		var face_set: Array = (die_build.get("face_set", []) as Array).duplicate(true)
		var body_id: String = str(die_build.get("body_id", "standard_d6"))
		var body_definition: Dictionary = body_definitions.get(body_id, {})
		var side_count: int = int(body_definition.get("sides", die_build.get("sides", face_set.size())))
		var rolled_value: int = 1
		if not remaining_rolls.is_empty():
			rolled_value = int(remaining_rolls.pop_front())
		rolled_value = clampi(rolled_value, 1, max(side_count, 1))

		var face_id: String = str(face_set[min(rolled_value - 1, face_set.size() - 1)])
		var face_definition: Dictionary = face_definitions.get(face_id, {})

		results.append(RollResultScript.new({
			"die_id": str(die_build.get("id", "")),
			"die_label": str(die_build.get("label", die_build.get("id", ""))),
			"rolled_value": rolled_value,
			"face_id": face_id,
			"face_family": str(face_definition.get("family", "utility")),
			"face_label": str(face_definition.get("name", face_id)),
		}).to_dictionary())

	return {
		"ok": true,
		"roll_results": results,
		"remaining_rolls": remaining_rolls,
	}


func assign_die_to_action(roll_results: Array, action_slots: Array, die_id: String, action_slot_id: String) -> Dictionary:
	var die_index: int = _find_roll_index(roll_results, die_id)
	if die_index == -1:
		return {"ok": false, "error": "invalid_die_id", "die_id": die_id}

	var slot_index: int = _find_slot_index(action_slots, action_slot_id)
	if slot_index == -1:
		return {"ok": false, "error": "invalid_action_slot_id", "action_slot_id": action_slot_id}

	var roll_result: Dictionary = (roll_results[die_index] as Dictionary).duplicate(true)
	if bool(roll_result.get("consumed", false)) or str(roll_result.get("assigned_slot_id", "")) != "":
		return {"ok": false, "error": "die_already_assigned", "die_id": die_id}

	var slot: Dictionary = (action_slots[slot_index] as Dictionary).duplicate(true)
	var allowed_families: Array = (slot.get("allowed_families", []) as Array).duplicate(true)
	if not allowed_families.has(str(roll_result.get("face_family", ""))):
		return {
			"ok": false,
			"error": "slot_family_mismatch",
			"die_id": die_id,
			"action_slot_id": action_slot_id,
		}

	roll_result["assigned_slot_id"] = action_slot_id
	roll_results[die_index] = roll_result

	var assigned_die_ids: Array = (slot.get("assigned_die_ids", []) as Array).duplicate(true)
	assigned_die_ids.append(die_id)
	slot["assigned_die_ids"] = assigned_die_ids
	action_slots[slot_index] = slot

	return {
		"ok": true,
		"roll_results": roll_results,
		"action_slots": action_slots,
	}


func _find_roll_index(roll_results: Array, die_id: String) -> int:
	for index in range(roll_results.size()):
		var roll_result: Dictionary = roll_results[index]
		if str(roll_result.get("die_id", "")) == die_id:
			return index
	return -1


func _find_slot_index(action_slots: Array, action_slot_id: String) -> int:
	for index in range(action_slots.size()):
		var slot: Dictionary = action_slots[index]
		if str(slot.get("slot_id", "")) == action_slot_id:
			return index
	return -1
