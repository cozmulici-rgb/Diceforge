class_name BossPhaseController
extends RefCounted


func initialize_enemy_state(enemy_definition: Dictionary) -> Dictionary:
	var phases: Array = (enemy_definition.get("phases", []) as Array).duplicate(true)
	if phases.is_empty():
		return {"ok": false, "error": "enemy_has_no_phases"}

	var first_phase: Dictionary = (phases[0] as Dictionary).duplicate(true)
	return {
		"phase_index": int(first_phase.get("phase_index", 1)),
		"total_phases": phases.size(),
		"is_boss": true,
		"final_boss": bool(enemy_definition.get("final_boss", false)),
		"phase_definitions": phases,
		"hp": int(first_phase.get("hp", enemy_definition.get("hp", 1))),
		"block": int(first_phase.get("starting_block", enemy_definition.get("starting_block", 0))),
		"intent_label": str(first_phase.get("intent", enemy_definition.get("intent", "Strike"))),
		"intent_damage": int(first_phase.get("damage", enemy_definition.get("damage", 0))),
	}


func advance_phase(enemy_state: Dictionary) -> Dictionary:
	var phases: Array = (enemy_state.get("phase_definitions", []) as Array).duplicate(true)
	var current_phase_index := int(enemy_state.get("phase_index", 1))
	if current_phase_index >= phases.size():
		return {
			"transitioned": false,
			"enemy_state": enemy_state.duplicate(true),
		}

	var next_phase: Dictionary = (phases[current_phase_index] as Dictionary).duplicate(true)
	var updated_enemy_state: Dictionary = enemy_state.duplicate(true)
	updated_enemy_state["phase_index"] = int(next_phase.get("phase_index", current_phase_index + 1))
	updated_enemy_state["hp"] = int(next_phase.get("hp", 1))
	updated_enemy_state["block"] = int(next_phase.get("starting_block", 0))
	updated_enemy_state["intent_label"] = str(next_phase.get("intent", "Strike"))
	updated_enemy_state["intent_damage"] = int(next_phase.get("damage", 0))
	return {
		"transitioned": true,
		"enemy_state": updated_enemy_state,
	}
