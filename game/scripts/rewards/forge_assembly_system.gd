class_name ForgeAssemblySystem
extends RefCounted

const RunInventoryScript = preload("res://scripts/rewards/run_inventory.gd")

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func preview_change(active_die: Dictionary, mutation: Dictionary, inventory: Variant) -> Dictionary:
	return _resolve_change(active_die, mutation, inventory, false)


func apply_change(active_die: Dictionary, mutation: Dictionary, inventory: Variant) -> Dictionary:
	return _resolve_change(active_die, mutation, inventory, true)


func validate_die_build(die_build: Dictionary) -> Dictionary:
	var body_definition = content_catalog.load_part_definition(str(die_build.get("body_id", "standard_d6")))
	if _is_error_result(body_definition):
		return body_definition

	var face_set = die_build.get("face_set", [])
	if not (face_set is Array) or face_set.is_empty():
		return {"ok": false, "error": "missing_face_set"}
	if (face_set as Array).size() > int(body_definition.get("sides", 0)):
		return {"ok": false, "error": "face_count_exceeds_body_sides"}

	for face_id in face_set:
		var face_definition = content_catalog.load_part_definition(str(face_id))
		if _is_error_result(face_definition) or str(face_definition.get("family", "")) == "":
			return {"ok": false, "error": "missing_face_definition", "face_id": str(face_id)}

	var equipped_runes: Array = (die_build.get("equipped_runes", []) as Array).duplicate(true)
	var rune_slots: Array = (body_definition.get("rune_slots", []) as Array).duplicate(true)
	for equipped_rune in equipped_runes:
		if not (equipped_rune is Dictionary):
			return {"ok": false, "error": "invalid_rune_payload"}
		var slot_id := str(equipped_rune.get("slot_id", ""))
		var rune_id := str(equipped_rune.get("rune_id", ""))
		var rune_definition = content_catalog.load_part_definition(rune_id)
		if _is_error_result(rune_definition) or str(rune_definition.get("family", "")) == "":
			return {"ok": false, "error": "missing_rune_definition", "rune_id": rune_id}
		var slot_definition := _find_rune_slot(rune_slots, slot_id)
		if slot_definition.is_empty():
			return {"ok": false, "error": "missing_rune_slot", "slot_id": slot_id}
		var allowed_families: Array = (slot_definition.get("allowed_families", []) as Array).duplicate(true)
		if not allowed_families.has(str(rune_definition.get("family", ""))):
			return {"ok": false, "error": "incompatible_rune_family", "slot_id": slot_id, "rune_id": rune_id}

	return {"ok": true}


func _resolve_change(active_die: Dictionary, mutation: Dictionary, inventory_input: Variant, consume_inventory: bool) -> Dictionary:
	var inventory = _coerce_inventory(inventory_input)
	var operation := str(mutation.get("operation", ""))
	var part_id := str(mutation.get("part_id", ""))
	var mutated_die: Dictionary = active_die.duplicate(true)

	var inventory_part_type := _inventory_part_type(operation)
	if inventory_part_type == "":
		return {"ok": false, "error": "unsupported_forge_operation", "operation": operation}
	if not inventory.has_part(inventory_part_type, part_id):
		return {"ok": false, "error": "missing_inventory_part", "part_type": inventory_part_type, "part_id": part_id}

	match operation:
		"swap_body":
			mutated_die["body_id"] = part_id
		"replace_face":
			var face_index := _parse_face_slot_index(str(mutation.get("slot_id", "")))
			if face_index < 0:
				return {"ok": false, "error": "invalid_face_slot_id", "slot_id": str(mutation.get("slot_id", ""))}
			var face_set: Array = (mutated_die.get("face_set", []) as Array).duplicate(true)
			if face_index >= face_set.size():
				return {"ok": false, "error": "face_slot_out_of_range", "slot_id": str(mutation.get("slot_id", ""))}
			face_set[face_index] = part_id
			mutated_die["face_set"] = face_set
		"socket_rune":
			var body_definition = content_catalog.load_part_definition(str(mutated_die.get("body_id", "standard_d6")))
			if _is_error_result(body_definition):
				return body_definition
			var rune_definition = content_catalog.load_part_definition(part_id)
			if _is_error_result(rune_definition):
				return rune_definition
			var slot_id := str(mutation.get("slot_id", ""))
			var slot_definition := _find_rune_slot((body_definition.get("rune_slots", []) as Array), slot_id)
			if slot_definition.is_empty():
				return {"ok": false, "error": "missing_rune_slot", "slot_id": slot_id}
			var allowed_families: Array = (slot_definition.get("allowed_families", []) as Array).duplicate(true)
			if not allowed_families.has(str(rune_definition.get("family", ""))):
				return {"ok": false, "error": "incompatible_rune_slotting", "slot_id": slot_id, "rune_id": part_id}
			var equipped_runes: Array = (mutated_die.get("equipped_runes", []) as Array).duplicate(true)
			_upsert_equipped_rune(equipped_runes, slot_id, part_id)
			mutated_die["equipped_runes"] = equipped_runes
		_:
			return {"ok": false, "error": "unsupported_forge_operation", "operation": operation}

	var validation = validate_die_build(mutated_die)
	if not validation.get("ok", false):
		return validation

	var next_inventory = inventory.duplicate_inventory()
	if consume_inventory:
		next_inventory.remove_part(inventory_part_type, part_id)

	return {
		"ok": true,
		"die_build": mutated_die,
		"inventory": next_inventory.to_dictionary(),
		"mutation": mutation.duplicate(true),
		"consumed_inventory": consume_inventory,
	}


func _coerce_inventory(inventory_input: Variant):
	if inventory_input is Object and inventory_input.has_method("to_dictionary"):
		return RunInventoryScript.new(inventory_input.to_dictionary())
	if inventory_input is Dictionary:
		return RunInventoryScript.new(inventory_input)
	return RunInventoryScript.new()


func _inventory_part_type(operation: String) -> String:
	if operation == "swap_body":
		return "body"
	if operation == "replace_face":
		return "face"
	if operation == "socket_rune":
		return "rune"
	return ""


func _parse_face_slot_index(slot_id: String) -> int:
	if not slot_id.begins_with("face_"):
		return -1
	return int(slot_id.trim_prefix("face_"))


func _find_rune_slot(rune_slots: Array, slot_id: String) -> Dictionary:
	for rune_slot in rune_slots:
		if rune_slot is Dictionary and str(rune_slot.get("slot_id", "")) == slot_id:
			return (rune_slot as Dictionary).duplicate(true)
	return {}


func _upsert_equipped_rune(equipped_runes: Array, slot_id: String, rune_id: String) -> void:
	for index in range(equipped_runes.size()):
		var equipped_rune: Dictionary = equipped_runes[index]
		if str(equipped_rune.get("slot_id", "")) == slot_id:
			equipped_runes[index] = {"slot_id": slot_id, "rune_id": rune_id}
			return
	equipped_runes.append({"slot_id": slot_id, "rune_id": rune_id})


func _is_error_result(value: Variant) -> bool:
	return value is Dictionary and not value.get("ok", true)
