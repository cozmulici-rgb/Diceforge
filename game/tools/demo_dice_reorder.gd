extends SceneTree

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func _initialize() -> void:
	var catalog = ContentCatalogScript.new()
	var controller = CombatControllerScript.new()
	controller.content_catalog = catalog
	var run_session = RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{"id": "balanced_d6_alpha", "label": "Balanced D6", "body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]},
			{"id": "balanced_d6_beta", "label": "Balanced D6", "body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]},
			{"id": "balanced_d6_gamma", "label": "Balanced D6", "body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]},
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack",
				"allowed_families": ["attack", "defense", "utility"],
				"min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard",
				"allowed_families": ["attack", "defense", "utility"],
				"min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility",
				"allowed_families": ["attack", "defense", "utility"],
				"min_assignments": 0, "assigned_die_ids": []},
		],
	})
	var encounter = {
		"id": "demo_fight", "name": "Demo Fight", "enemy_id": "slime_echo",
		"player_rolls": [4, 2, 3],
	}
	var combat_state = controller.begin_encounter(run_session, encounter)
	controller.combat_state = combat_state
	controller.roll_active_dice(combat_state)

	print("=== DICE REORDER DEMO ===")
	_print_state("Initial roll order", combat_state)

	# Reorder: move first die one position to the right.
	var first_die_id := str(((combat_state.roll_results as Array)[0] as Dictionary).get("die_id", ""))
	print("\n>> move_die_in_order(state, %s, +1)" % first_die_id)
	var move_result = controller.move_die_in_order(combat_state, first_die_id, 1)
	print("   result: %s" % str(move_result.get("ok", false)))
	_print_state("After right-shift", combat_state)

	# Boundary: try to push the (now-leftmost) die further left from the start.
	var leftmost_id := str(((combat_state.roll_results as Array)[0] as Dictionary).get("die_id", ""))
	print("\n>> move_die_in_order(state, %s, -1)  (boundary, expect rejection)" % leftmost_id)
	var bad_move = controller.move_die_in_order(combat_state, leftmost_id, -1)
	print("   result: ok=%s error=%s" % [bad_move.get("ok", false), bad_move.get("error", "")])

	# Slot cycle: cycle the original first die through the action slots.
	print("\n>> cycle_die_slot(state, %s)  (twice)" % first_die_id)
	controller.cycle_die_slot(combat_state, first_die_id)
	_print_state("After 1 cycle", combat_state)
	controller.cycle_die_slot(combat_state, first_die_id)
	_print_state("After 2 cycles", combat_state)
	controller.cycle_die_slot(combat_state, first_die_id)
	_print_state("After 3 cycles (should wrap)", combat_state)

	print("\n=== DEMO COMPLETE ===")
	controller.free()
	quit(0)


func _print_state(label: String, state) -> void:
	print("%s:" % label)
	var rolls: Array = state.roll_results as Array
	for index in range(rolls.size()):
		var entry: Dictionary = rolls[index] as Dictionary
		print("  [%d] die=%-22s face=%-7s slot=%s" % [
			index,
			str(entry.get("die_id", "")),
			str(entry.get("face_id", "")),
			str(entry.get("assigned_slot_id", "(unassigned)")),
		])
