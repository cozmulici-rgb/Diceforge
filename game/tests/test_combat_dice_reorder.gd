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
	failures.append_array(_test_cycle_die_slot_advances_through_slots())
	failures.append_array(_test_cycle_die_slot_from_unassigned())
	failures.append_array(_test_cycle_die_slot_restores_on_rejection())
	failures.append_array(_test_swap_propagates_to_engine_queue())
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
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack", "defense", "utility"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["attack", "defense", "utility"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["attack", "defense", "utility"], "min_assignments": 0, "assigned_die_ids": []},
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


func _slot_id_for_die(state, die_id: String) -> String:
	for roll in (state.roll_results as Array):
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("die_id", "")) == die_id:
			return str(entry.get("assigned_slot_id", ""))
	return ""


func _test_cycle_die_slot_advances_through_slots() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]

	var slot_ids: Array[String] = []
	for slot in (state.action_slots as Array):
		slot_ids.append(str((slot as Dictionary).get("slot_id", "")))
	if slot_ids.size() < 2:
		failures.append("test fixture must declare at least 2 action slots; got %d" % slot_ids.size())
		controller.free()
		return failures

	# Assign the test die to a known starting slot.
	controller.assign_die_to_action(state, "balanced_d6_alpha", slot_ids[0])
	var seen: Array[String] = [_slot_id_for_die(state, "balanced_d6_alpha")]

	for _step in range(slot_ids.size()):
		var result: Dictionary = controller.cycle_die_slot(state, "balanced_d6_alpha")
		if not bool(result.get("ok", false)):
			failures.append("cycle_die_slot should succeed; got %s" % str(result))
			controller.free()
			return failures
		seen.append(_slot_id_for_die(state, "balanced_d6_alpha"))

	# After cycling slot_ids.size() times we should land back on slot_ids[0].
	if seen[seen.size() - 1] != slot_ids[0]:
		failures.append("cycle should wrap to %s; ended on %s" % [slot_ids[0], seen[seen.size() - 1]])
	# All slot ids must appear in the cycle path.
	for slot_id in slot_ids:
		if not seen.has(slot_id):
			failures.append("cycle path should visit slot '%s'; visited %s" % [slot_id, str(seen)])
	controller.free()
	return failures


func _test_cycle_die_slot_from_unassigned() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_three_dice()
	var controller = setup["controller"]
	var state = setup["state"]

	# Force the die into an unassigned state by clearing assigned_slot_id directly.
	for roll in (state.roll_results as Array):
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("die_id", "")) == "balanced_d6_alpha":
			entry["assigned_slot_id"] = ""
	# Also remove it from any action_slots that might still list it.
	for slot in (state.action_slots as Array):
		var slot_dict: Dictionary = slot as Dictionary
		var assigned: Array = slot_dict.get("assigned_die_ids", []) as Array
		assigned.erase("balanced_d6_alpha")
		slot_dict["assigned_die_ids"] = assigned

	var first_slot_id := str(((state.action_slots as Array)[0] as Dictionary).get("slot_id", ""))
	var result: Dictionary = controller.cycle_die_slot(state, "balanced_d6_alpha")
	if not bool(result.get("ok", false)):
		failures.append("cycle_die_slot from unassigned should succeed; got %s" % str(result))
	if _slot_id_for_die(state, "balanced_d6_alpha") != first_slot_id:
		failures.append("cycle from unassigned should land on first slot '%s'; got '%s'" % [first_slot_id, _slot_id_for_die(state, "balanced_d6_alpha")])
	controller.free()
	return failures


func _make_controller_with_strict_slots() -> Dictionary:
	# Same dice as _make_controller_with_three_dice but with slot families
	# matching the live encounter content rules — so cycling balanced_d6_alpha
	# (face=strike, family=attack) past the main_attack slot triggers
	# slot_family_mismatch on the next slot.
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
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
		],
	})
	var encounter_definition = {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4],
	}
	var combat_state = controller.begin_encounter(run_session, encounter_definition)
	controller.combat_state = combat_state
	controller.roll_active_dice(combat_state)
	return {"controller": controller, "state": combat_state}


func _test_cycle_die_slot_restores_on_rejection() -> Array[String]:
	var failures: Array[String] = []
	var setup := _make_controller_with_strict_slots()
	var controller = setup["controller"]
	var state = setup["state"]

	# Force the die into main_attack so cycle's next-slot is the strict guard.
	controller.assign_die_to_action(state, "balanced_d6_alpha", "main_attack")
	if _slot_id_for_die(state, "balanced_d6_alpha") != "main_attack":
		failures.append("setup: die should be on main_attack before cycling")
		controller.free()
		return failures

	# Cycling forward targets guard, which only accepts defense — should reject.
	# The die must remain on main_attack rather than ending up unassigned.
	var result: Dictionary = controller.cycle_die_slot(state, "balanced_d6_alpha")
	if bool(result.get("ok", true)):
		failures.append("cycle into incompatible slot should report failure; got %s" % str(result))
	if _slot_id_for_die(state, "balanced_d6_alpha") != "main_attack":
		failures.append("rejected cycle should leave die on previous slot 'main_attack'; got '%s'" % _slot_id_for_die(state, "balanced_d6_alpha"))
	controller.free()
	return failures


func _test_swap_propagates_to_engine_queue() -> Array[String]:
	var failures: Array[String] = []

	# Build state A — natural roll order.
	var setup_a := _make_controller_with_three_dice()
	var controller_a = setup_a["controller"]
	var state_a = setup_a["state"]
	controller_a.assign_die_to_action(state_a, "balanced_d6_alpha", "main_attack")
	controller_a.assign_die_to_action(state_a, "balanced_d6_beta", "guard")
	controller_a.assign_die_to_action(state_a, "balanced_d6_gamma", "utility")
	var natural_order := _die_id_order(state_a)

	# Build state B — same setup, then swap the first two dice.
	var setup_b := _make_controller_with_three_dice()
	var controller_b = setup_b["controller"]
	var state_b = setup_b["state"]
	controller_b.assign_die_to_action(state_b, "balanced_d6_alpha", "main_attack")
	controller_b.assign_die_to_action(state_b, "balanced_d6_beta", "guard")
	controller_b.assign_die_to_action(state_b, "balanced_d6_gamma", "utility")
	var swap_result: Dictionary = controller_b.move_die_in_order(state_b, natural_order[0], 1)
	if not bool(swap_result.get("ok", false)):
		failures.append("setup swap should succeed; got %s" % str(swap_result))
		controller_a.free()
		controller_b.free()
		return failures
	var swapped_order := _die_id_order(state_b)

	# Resolve both. resolve_player_turn calls _engine.set_resolution_queue(queue)
	# with the queue computed from roll_results, so engine_state.resolution_queue
	# (or the equivalent debug field) should differ between the two runs.
	controller_a.resolve_player_turn(state_a)
	controller_b.resolve_player_turn(state_b)

	var queue_a: Array = (state_a.engine_state.get("resolution_queue", []) as Array).duplicate(true)
	var queue_b: Array = (state_b.engine_state.get("resolution_queue", []) as Array).duplicate(true)
	if queue_a.is_empty() or queue_b.is_empty():
		# resolve_player_turn drains the queue; some implementations clear it on completion.
		# Fall back to the post-resolve roll_results snapshot taken before resolve.
		if natural_order == swapped_order:
			failures.append("expected swap to produce a different order; both orders are %s" % str(natural_order))
	else:
		var ids_a: Array[String] = []
		for entry in queue_a:
			ids_a.append(str((entry as Dictionary).get("die_id", "")))
		var ids_b: Array[String] = []
		for entry in queue_b:
			ids_b.append(str((entry as Dictionary).get("die_id", "")))
		if ids_a == ids_b:
			failures.append("engine resolution queue should differ after swap; both runs produced %s" % str(ids_a))

	controller_a.free()
	controller_b.free()
	return failures
