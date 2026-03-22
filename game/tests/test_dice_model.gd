extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const DiceModelScript = preload("res://scripts/combat/dice_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var dice_model = DiceModelScript.new()

	var body_definitions: Dictionary = catalog.get_part_definitions("body")
	var face_definitions: Dictionary = catalog.get_part_definitions("face")
	var active_dice = [
		{
			"id": "die_alpha",
			"label": "Die Alpha",
			"body_id": "standard_d6",
			"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
		}
	]

	var roll_result = dice_model.roll_active_dice(active_dice, face_definitions, body_definitions, [4])
	if not roll_result.get("ok", false):
		failures.append("expected deterministic roll generation to succeed")
		return failures

	var roll_results: Array = roll_result.get("roll_results", [])
	var action_slots = [
		{
			"slot_id": "main_attack",
			"display_name": "Main Attack",
			"allowed_families": ["attack"],
			"min_assignments": 1,
			"assigned_die_ids": [],
		},
		{
			"slot_id": "guard",
			"display_name": "Guard",
			"allowed_families": ["defense"],
			"min_assignments": 0,
			"assigned_die_ids": [],
		},
	]

	var invalid_die_result = dice_model.assign_die_to_action(roll_results.duplicate(true), action_slots.duplicate(true), "missing_die", "main_attack")
	if invalid_die_result.get("error", "") != "invalid_die_id":
		failures.append("assign_die_to_action should reject unknown dice ids")

	var invalid_slot_result = dice_model.assign_die_to_action(roll_results.duplicate(true), action_slots.duplicate(true), "die_alpha", "missing_slot")
	if invalid_slot_result.get("error", "") != "invalid_action_slot_id":
		failures.append("assign_die_to_action should reject unknown slot ids")

	var mismatch_result = dice_model.assign_die_to_action(roll_results.duplicate(true), action_slots.duplicate(true), "die_alpha", "guard")
	if mismatch_result.get("error", "") != "slot_family_mismatch":
		failures.append("assign_die_to_action should reject incompatible slot families")

	return failures
