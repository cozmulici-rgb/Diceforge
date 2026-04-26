class_name DiceResolver
extends RefCounted

const FAMILY_TO_EFFECT := {
	"attack": "damage",
	"defense": "block",
	"utility": "utility",
}


func roll_dice(dice: Array, face_defs: Dictionary, body_defs: Dictionary, roll_seeds: Array = []) -> Dictionary:
	var rolled_faces: Array = []
	var remaining_seeds := roll_seeds.duplicate(true)

	for die in dice:
		var die_data: Dictionary = die as Dictionary
		var face_set := (die_data.get("face_set", []) as Array).duplicate(true)
		if face_set.is_empty():
			return {"ok": false, "error": "missing_face_set", "die_id": str(die_data.get("id", ""))}

		var body_id := str(die_data.get("body_id", "standard_d6"))
		var body_def: Dictionary = body_defs.get(body_id, {})
		var side_count := int(body_def.get("sides", die_data.get("sides", face_set.size())))
		side_count = maxi(side_count, 1)

		var rolled_value: int
		if not remaining_seeds.is_empty():
			rolled_value = int(remaining_seeds.pop_front())
		else:
			rolled_value = randi_range(1, side_count)
		rolled_value = clampi(rolled_value, 1, side_count)

		var face_index := mini(rolled_value - 1, face_set.size() - 1)
		var face_id := str(face_set[face_index])
		var face_def: Dictionary = face_defs.get(face_id, {})

		rolled_faces.append({
			"die_id": str(die_data.get("id", "")),
			"die_label": str(die_data.get("label", die_data.get("id", ""))),
			"rolled_value": rolled_value,
			"face_id": face_id,
			"face_label": str(face_def.get("name", face_id)),
			"face_family": str(face_def.get("family", "utility")),
			"effect": _resolve_effect(face_def),
			"value": int(face_def.get("value", face_def.get("power_multiplier", 1))),
			"energy_cost": int(face_def.get("energy_cost", 0)),
			"used": false,
			"exhausted": false,
			"locked": false,
			"face_set": face_set.duplicate(true),
			"body_id": body_id,
			"statuses": (die_data.get("statuses", []) as Array).duplicate(true),
			"runes": (die_data.get("runes", []) as Array).duplicate(true),
			"core": die_data.get("core", null),
		})

	return {"ok": true, "rolled_faces": rolled_faces}


func reroll_die(rolled_faces: Array, die_id: String, face_defs: Dictionary, body_defs: Dictionary, roll_seeds: Array = []) -> Dictionary:
	var die_index := _find_die_index(rolled_faces, die_id)
	if die_index == -1:
		return {"ok": false, "error": "die_not_found", "die_id": die_id}

	var existing: Dictionary = rolled_faces[die_index] as Dictionary
	if bool(existing.get("used", false)) or bool(existing.get("exhausted", false)) or bool(existing.get("locked", false)):
		return {"ok": false, "error": "die_not_rerollable", "die_id": die_id}

	var single_die := {
		"id": die_id,
		"label": str(existing.get("die_label", die_id)),
		"body_id": str(existing.get("body_id", "standard_d6")),
		"face_set": (existing.get("face_set", []) as Array).duplicate(true),
		"statuses": (existing.get("statuses", []) as Array).duplicate(true),
		"runes": (existing.get("runes", []) as Array).duplicate(true),
		"core": existing.get("core", null),
	}
	if (single_die["face_set"] as Array).is_empty():
		return {"ok": false, "error": "face_set_not_available_for_reroll", "die_id": die_id}

	var rerolled := roll_dice([single_die], face_defs, body_defs, roll_seeds)
	if not rerolled.get("ok", false):
		return rerolled

	var updated_faces := rolled_faces.duplicate(true)
	var original_value := int(existing.get("rolled_value", 0))
	updated_faces[die_index] = ((rerolled.get("rolled_faces", []) as Array)[0] as Dictionary).duplicate(true)

	return {
		"ok": true,
		"rolled_faces": updated_faces,
		"original_rolled_value": original_value,
	}


func _resolve_effect(face_def: Dictionary) -> String:
	var explicit := str(face_def.get("effect", ""))
	if explicit != "":
		return explicit
	return str(FAMILY_TO_EFFECT.get(str(face_def.get("family", "utility")), "utility"))


func _find_die_index(rolled_faces: Array, die_id: String) -> int:
	for index in range(rolled_faces.size()):
		if str((rolled_faces[index] as Dictionary).get("die_id", "")) == die_id:
			return index
	return -1
