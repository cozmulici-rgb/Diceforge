extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const ForgeAssemblySystemScript = preload("res://scripts/rewards/forge_assembly_system.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var forge = ForgeAssemblySystemScript.new(catalog)

	var active_die := {
		"id": "balanced_d6_alpha",
		"label": "Balanced D6",
		"body_id": "standard_d6",
		"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
		"equipped_runes": [],
	}

	var invalid_rune = forge.preview_change(active_die, {
		"target_die_id": "balanced_d6_alpha",
		"operation": "socket_rune",
		"part_id": "ember_rune",
		"slot_id": "core",
	}, {
		"bodies": [],
		"faces": [],
		"runes": ["ember_rune"],
		"currencies": {},
		"modifiers": [],
	})
	if invalid_rune.get("ok", false):
		failures.append("socketing an attack rune into the neutral starter body should be rejected")

	var replace_face = forge.apply_change(active_die, {
		"target_die_id": "balanced_d6_alpha",
		"operation": "replace_face",
		"part_id": "heavy_strike",
		"slot_id": "face_0",
	}, {
		"bodies": [],
		"faces": ["heavy_strike"],
		"runes": [],
		"currencies": {},
		"modifiers": [],
	})
	if not replace_face.get("ok", false):
		failures.append("replacing a face with an owned spare should succeed")
		return failures

	var die_build: Dictionary = replace_face.get("die_build", {})
	if str((die_build.get("face_set", []) as Array)[0]) != "heavy_strike":
		failures.append("replace_face should update the targeted die face")

	if (replace_face.get("inventory", {}).get("faces", []) as Array).has("heavy_strike"):
		failures.append("apply_change should consume the spare face from inventory")

	return failures
