extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_move_die_swaps_neighbors())
	failures.append_array(_test_move_die_no_op_at_left_boundary())
	failures.append_array(_test_move_die_no_op_at_right_boundary())
	failures.append_array(_test_move_die_invalid_direction())
	return failures


func _make_controller_with_three_dice() -> Dictionary:
	var catalog = ContentCatalogScript.new()
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog
	var run_session = RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{
				"id": "balanced_d6_alpha",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
			{
				"id": "balanced_d6_beta",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
			{
				"id": "balanced_d6_gamma",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			},
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []},
		],
	})
	var encounter_definition = {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4, 2, 3],
	}
	var combat_state = controller.begin_encounter(run_session, encounter_definition)
	controller.combat_state = combat_state
	controller.roll_active_dice(combat_state)
	return {"controller": controller, "state": combat_state}


func _die_id_order(state) -> Array[String]:
	var ids: Array[String] = []
	for roll in (state.roll_results as Array):
		ids.append(str((roll as Dictionary).get("die_id", "")))
	return ids


func _test_move_die_swaps_neighbors() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)
	if before.size() != 3:
		failures.append("expected 3 rolled dice, got %d" % before.size())
		controller.free()
		return failures

	var result: Dictionary = controller.move_die_in_order(state, before[0], 1)
	if not bool(result.get("ok", false)):
		failures.append("move_die_in_order(+1) on first die should succeed; got %s" % str(result))
	var after := _die_id_order(state)
	var expected: Array[String] = [before[1], before[0], before[2]]
	if after != expected:
		failures.append("expected order %s after swap; got %s" % [str(expected), str(after)])
	controller.free()
	return failures


func _test_move_die_no_op_at_left_boundary() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	var result: Dictionary = controller.move_die_in_order(state, before[0], -1)
	if bool(result.get("ok", true)):
		failures.append("move_die_in_order(-1) on first die should fail; got %s" % str(result))
	if str(result.get("error", "")) != "out_of_bounds":
		failures.append("expected error 'out_of_bounds' at left boundary; got '%s'" % str(result.get("error", "")))
	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after a left-boundary no-op")
	controller.free()
	return failures


func _test_move_die_no_op_at_right_boundary() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	var result: Dictionary = controller.move_die_in_order(state, before[before.size() - 1], 1)
	if bool(result.get("ok", true)):
		failures.append("move_die_in_order(+1) on last die should fail; got %s" % str(result))
	if str(result.get("error", "")) != "out_of_bounds":
		failures.append("expected error 'out_of_bounds' at right boundary; got '%s'" % str(result.get("error", "")))
	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after a right-boundary no-op")
	controller.free()
	return failures


func _test_move_die_invalid_direction() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]
	var before := _die_id_order(state)

	for invalid_direction in [0, 2, -2]:
		var result: Dictionary = controller.move_die_in_order(state, before[0], invalid_direction)
		if bool(result.get("ok", true)):
			failures.append("move_die_in_order(%d) should fail; got %s" % [invalid_direction, str(result)])
		if str(result.get("error", "")) != "invalid_direction":
			failures.append("expected error 'invalid_direction' for direction %d; got '%s'" % [invalid_direction, str(result.get("error", ""))])

	if _die_id_order(state) != before:
		failures.append("roll_results should be unchanged after invalid_direction calls")
	controller.free()
	return failures
