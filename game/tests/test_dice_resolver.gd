extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const DiceResolverScript = preload("res://scripts/combat/dice_resolver.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var resolver = DiceResolverScript.new()

	var face_defs := catalog.get_part_definitions("face")
	var body_defs := catalog.get_part_definitions("body")
	var dice := [
		{
			"id": "d_alpha",
			"body_id": "standard_d6",
			"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			"statuses": [],
			"runes": [],
			"core": null,
		},
		{
			"id": "d_beta",
			"body_id": "standard_d6",
			"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			"statuses": [],
			"runes": [],
			"core": null,
		},
	]

	var roll_result := resolver.roll_dice(dice, face_defs, body_defs, [4, 1])
	if not roll_result.get("ok", false):
		failures.append("roll_dice should succeed")
		return failures

	var rolled_faces := roll_result.get("rolled_faces", []) as Array
	if rolled_faces.size() != 2:
		failures.append("roll_dice should return one result per die")
		return failures

	var first := rolled_faces[0] as Dictionary
	if int(first.get("rolled_value", -1)) != 4 or str(first.get("face_id", "")) != "strike":
		failures.append("first roll should be strike on 4")
	if str(first.get("effect", "")) != "damage":
		failures.append("strike should resolve to damage effect")

	var reroll := resolver.reroll_die(rolled_faces, "d_beta", face_defs, body_defs, [6])
	if not reroll.get("ok", false):
		failures.append("reroll_die should succeed")
		return failures

	var rerolled_faces := reroll.get("rolled_faces", []) as Array
	var d_beta := _find_entry(rerolled_faces, "d_beta")
	if int(d_beta.get("rolled_value", -1)) != 6:
		failures.append("rerolled die should use deterministic reroll seed")

	var used_faces := rerolled_faces.map(func(face: Dictionary) -> Dictionary:
		var cloned := face.duplicate(true)
		if str(cloned.get("die_id", "")) == "d_beta":
			cloned["used"] = true
		return cloned
	)
	if resolver.reroll_die(used_faces, "d_beta", face_defs, body_defs, [3]).get("ok", false):
		failures.append("used dice should not be rerollable")

	return failures


func _find_entry(faces: Array, die_id: String) -> Dictionary:
	for face in faces:
		var item: Dictionary = face as Dictionary
		if str(item.get("die_id", "")) == die_id:
			return item
	return {}
