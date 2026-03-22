extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const ModifierRegistryScript = preload("res://scripts/modifiers/modifier_registry.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RunSessionScript = preload("res://scripts/core/run_session.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var registry = ModifierRegistryScript.new(catalog)

	var effects = registry.load_modifier_effects(["void_pressure", "void_pressure", "ember_blessing"])
	if effects.size() != 2:
		failures.append("unique modifiers should not stack duplicate entries in the registry")

	var snapshot = registry.build_combat_snapshot(["void_pressure", "ember_blessing"])
	if int(snapshot.get("enemy_hp_delta", 0)) <= 0:
		failures.append("combat snapshot should expose enemy hp adjustments from curse modifiers")
	if int(snapshot.get("attack_bonus", 0)) <= 0:
		failures.append("combat snapshot should expose attack bonuses from blessing modifiers")

	var baseline_controller = CombatControllerScript.new()
	baseline_controller.content_catalog = catalog
	var modified_controller = CombatControllerScript.new()
	modified_controller.content_catalog = catalog

	var base_session = _build_run_session([])
	var modified_session = _build_run_session(["void_pressure", "ember_blessing", "glass_core"])
	var encounter_definition = {
		"id": "custom_training_fight",
		"name": "Custom Training Fight",
		"enemy_id": "slime_echo",
		"player_rolls": [4, 2, 3],
	}

	var baseline_state = baseline_controller.begin_encounter(base_session, encounter_definition)
	var modified_state = modified_controller.begin_encounter(modified_session, encounter_definition)
	if baseline_state is Dictionary or modified_state is Dictionary:
		failures.append("combat controller should build combat states for modifier registry tests")
		return failures

	if int((modified_state.enemy_state as Dictionary).get("hp", 0)) <= int((baseline_state.enemy_state as Dictionary).get("hp", 0)):
		failures.append("modifier application should raise enemy hp deterministically when a curse is active")
	if int(modified_state.player_hp) <= int(baseline_state.player_hp):
		failures.append("run-scope modifiers should adjust player hp during combat setup")

	return failures


func _build_run_session(modifier_ids: Array) -> RunSession:
	return RunSessionScript.new({
		"current_room_id": "tutorial_hall",
		"player_state": {"hp": 30, "status_effects": []},
		"active_dice": [
			{
				"id": "balanced_d6_alpha",
				"label": "Balanced D6",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"]
			}
		],
		"action_slots": [
			{"slot_id": "main_attack", "display_name": "Main Attack", "allowed_families": ["attack"], "min_assignments": 1, "assigned_die_ids": []},
			{"slot_id": "guard", "display_name": "Guard", "allowed_families": ["defense"], "min_assignments": 0, "assigned_die_ids": []},
			{"slot_id": "utility", "display_name": "Utility", "allowed_families": ["utility"], "min_assignments": 0, "assigned_die_ids": []}
		],
		"modifiers": modifier_ids.duplicate(true),
	})
