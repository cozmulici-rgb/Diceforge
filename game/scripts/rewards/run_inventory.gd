class_name RunInventory
extends RefCounted

var bodies: Array
var faces: Array
var runes: Array
var currencies: Dictionary
var modifiers: Array


func _init(data: Dictionary = {}) -> void:
	bodies = (data.get("bodies", []) as Array).duplicate(true)
	faces = (data.get("faces", []) as Array).duplicate(true)
	runes = (data.get("runes", []) as Array).duplicate(true)
	currencies = (data.get("currencies", {}) as Dictionary).duplicate(true)
	modifiers = (data.get("modifiers", []) as Array).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"bodies": bodies.duplicate(true),
		"faces": faces.duplicate(true),
		"runes": runes.duplicate(true),
		"currencies": currencies.duplicate(true),
		"modifiers": modifiers.duplicate(true),
	}


func duplicate_inventory():
	return get_script().new(to_dictionary())


func has_part(part_type: String, content_id: String, quantity: int = 1) -> bool:
	var parts: Array = _parts_for_type(part_type)
	var count := 0
	for part_id in parts:
		if str(part_id) == content_id:
			count += 1
	return count >= quantity


func add_part(part_type: String, content_id: String, quantity: int = 1) -> void:
	var parts: Array = _parts_for_type(part_type)
	for _index in range(max(quantity, 0)):
		parts.append(content_id)
	_set_parts_for_type(part_type, parts)


func remove_part(part_type: String, content_id: String, quantity: int = 1) -> bool:
	var parts: Array = _parts_for_type(part_type)
	var removed := 0
	for index in range(parts.size() - 1, -1, -1):
		if removed >= quantity:
			break
		if str(parts[index]) == content_id:
			parts.remove_at(index)
			removed += 1
	_set_parts_for_type(part_type, parts)
	return removed == quantity


func add_currency(currency_id: String, quantity: int) -> void:
	currencies[currency_id] = int(currencies.get(currency_id, 0)) + quantity


func add_modifier(modifier_id: String, quantity: int = 1) -> void:
	for _index in range(max(quantity, 0)):
		modifiers.append(modifier_id)


func count_spare_parts() -> int:
	return bodies.size() + faces.size() + runes.size()


func _parts_for_type(part_type: String) -> Array:
	if part_type == "body":
		return bodies.duplicate(true)
	if part_type == "face":
		return faces.duplicate(true)
	if part_type == "rune":
		return runes.duplicate(true)
	return []


func _set_parts_for_type(part_type: String, parts: Array) -> void:
	if part_type == "body":
		bodies = parts
	elif part_type == "face":
		faces = parts
	elif part_type == "rune":
		runes = parts
