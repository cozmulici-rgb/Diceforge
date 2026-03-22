class_name GameStateCoordinator
extends RefCounted

const RunSessionScript = preload("res://scripts/core/run_session.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RewardControllerScript = preload("res://scripts/rewards/reward_controller.gd")
const ForgeAssemblySystemScript = preload("res://scripts/rewards/forge_assembly_system.gd")
const RunInventoryScript = preload("res://scripts/rewards/run_inventory.gd")

var content_catalog
var current_session = null
var _session_sequence := 0
var _reward_controller
var _forge_assembly_system


func _init(catalog) -> void:
	content_catalog = catalog
	_reward_controller = RewardControllerScript.new(catalog)
	_forge_assembly_system = ForgeAssemblySystemScript.new(catalog)


func create_run_session(archetype_id: String) -> Variant:
	var archetype = content_catalog.load_archetype(archetype_id)
	if _is_error_result(archetype):
		return archetype

	var starter_floor = content_catalog.load_floor_template(str(archetype.get("starter_floor_id", "")))
	if _is_error_result(starter_floor):
		return starter_floor

	var room_graph = content_catalog.load_room_graph(str(starter_floor.get("room_graph_id", "")))
	if _is_error_result(room_graph):
		return room_graph

	var starting_room_id: String = str(starter_floor.get("starting_room_id", ""))

	_session_sequence += 1
	var session = RunSessionScript.new({
		"session_id": "run_%03d_%s" % [_session_sequence, archetype_id],
		"archetype_id": archetype_id,
		"floor_index": 1,
		"current_room_id": starting_room_id,
		"room_graph_id": str(starter_floor.get("room_graph_id", "")),
		"player_state": (archetype.get("player_state", {})).duplicate(true),
		"active_dice": (archetype.get("starter_dice", [])).duplicate(true),
		"inventory": {
			"bodies": [],
			"faces": [],
			"runes": [],
			"currencies": {"echo_shards": 0},
		},
		"modifiers": [],
		"flags": {
			"starter_floor_id": str(archetype.get("starter_floor_id", "")),
			"room_history": [starting_room_id],
			"active_encounter": {},
			"screen_state": "exploration",
			"encounter_status": "Run started. Move into the tutorial hall to trigger the encounter stub.",
		},
		"room_states": _build_initial_room_states(room_graph, starting_room_id),
		"action_slots": _build_default_action_slots(),
		"last_encounter_result": {},
		"reward_flow_state": {},
	})

	current_session = session
	return session


func load_run_session(save_slot_id: String) -> Dictionary:
	return {
		"ok": false,
		"error": "not_implemented",
		"operation": "load_run_session",
		"save_slot_id": save_slot_id,
	}


func enter_room(room_id: String) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}

	var room_graph = content_catalog.load_room_graph(str(current_session.room_graph_id))
	if _is_error_result(room_graph):
		return room_graph

	var current_room_id: String = str(current_session.current_room_id)
	if current_room_id != room_id and not _get_neighbor_ids(room_graph, current_room_id).has(room_id):
		return {
			"ok": false,
			"error": "invalid_room_transition",
			"from_room_id": current_room_id,
			"to_room_id": room_id,
		}

	current_session.current_room_id = room_id
	var room_history: Array = current_session.flags.get("room_history", [])
	room_history.append(room_id)
	current_session.flags["room_history"] = room_history
	current_session.flags["encounter_status"] = "Entered room %s." % room_id
	_mark_room_revealed(current_session.room_states, room_id)

	return {"ok": true, "room_id": room_id}


func begin_encounter(encounter_id: String) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}

	var room_graph = content_catalog.load_room_graph(str(current_session.room_graph_id))
	if _is_error_result(room_graph):
		return room_graph

	var current_room = _get_room_definition(room_graph, str(current_session.current_room_id))
	if current_room.is_empty():
		return {"ok": false, "error": "missing_current_room"}

	var expected_encounter_id: String = str(current_room.get("encounter_id", ""))
	if expected_encounter_id == "":
		return {"ok": false, "error": "room_has_no_encounter"}
	if encounter_id != expected_encounter_id:
		return {
			"ok": false,
			"error": "encounter_mismatch",
			"expected_encounter_id": expected_encounter_id,
			"encounter_id": encounter_id,
		}

	var encounter_definition = content_catalog.load_encounter(encounter_id)
	if _is_error_result(encounter_definition):
		return encounter_definition

	var combat_controller = CombatControllerScript.new()
	combat_controller.content_catalog = content_catalog
	var combat_state = combat_controller.begin_encounter(current_session, encounter_definition)
	combat_controller.free()
	if _is_error_result(combat_state):
		return combat_state

	current_session.flags["active_encounter"] = {
		"encounter_id": encounter_id,
		"room_id": str(current_session.current_room_id),
		"state": "combat_active",
	}
	current_session.flags["screen_state"] = "combat"
	current_session.flags["encounter_status"] = "Combat started: %s" % encounter_id

	return {
		"ok": true,
		"state": "combat_active",
		"encounter_id": encounter_id,
		"room_id": str(current_session.current_room_id),
		"combat_state": combat_state,
	}


func apply_encounter_result(result: Dictionary) -> Variant:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}

	current_session.player_state["hp"] = int(result.get("player_hp_after", current_session.player_state.get("hp", 0)))
	current_session.last_encounter_result = result.duplicate(true)
	current_session.flags["active_encounter"] = {}
	current_session.flags["encounter_status"] = "Encounter resolved: %s" % str(result.get("outcome", "unknown"))

	if str(result.get("outcome", "")) == "victory":
		_mark_room_completed(current_session.room_states, str(result.get("room_id", current_session.current_room_id)))
		current_session.flags["screen_state"] = "reward"
	else:
		current_session.flags["screen_state"] = "exploration"

	return current_session


func open_reward_flow(source: Variant) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	if not (source is Dictionary):
		return {"ok": false, "error": "invalid_reward_source"}

	var reward_flow = _reward_controller.open_reward_flow(source, current_session)
	if not reward_flow.get("ok", false):
		return reward_flow

	current_session.reward_flow_state = reward_flow.duplicate(true)
	current_session.flags["screen_state"] = "reward"
	current_session.flags["encounter_status"] = "Reward selection active."
	return reward_flow


func apply_reward_selection(option_data: Dictionary) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}

	var apply_result = _reward_controller.apply_reward_option(current_session, option_data)
	if not apply_result.get("ok", false):
		return apply_result

	current_session.reward_flow_state["selected_option"] = option_data.duplicate(true)
	current_session.reward_flow_state["inventory_snapshot"] = current_session.inventory.duplicate(true)
	current_session.flags["screen_state"] = "reward"
	return {
		"ok": true,
		"run_session": current_session,
		"reward_flow_state": current_session.reward_flow_state.duplicate(true),
	}


func can_enter_forge() -> bool:
	if current_session == null:
		return false
	var inventory := RunInventoryScript.new(current_session.inventory)
	return bool(current_session.reward_flow_state.get("can_enter_forge", false)) and inventory.count_spare_parts() > 0


func open_forge_flow() -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	if not can_enter_forge():
		return {"ok": false, "error": "forge_unavailable"}

	current_session.flags["screen_state"] = "forge"
	current_session.flags["encounter_status"] = "Forge active."
	return {
		"ok": true,
		"active_dice": current_session.active_dice.duplicate(true),
		"inventory": current_session.inventory.duplicate(true),
	}


func preview_forge_mutation(mutation: Dictionary) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	var die_index := _find_active_die_index(str(mutation.get("target_die_id", "")))
	if die_index == -1:
		return {"ok": false, "error": "missing_target_die", "target_die_id": str(mutation.get("target_die_id", ""))}
	return _forge_assembly_system.preview_change(current_session.active_dice[die_index], mutation, current_session.inventory)


func apply_forge_mutation(mutation: Dictionary) -> Dictionary:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	var die_index := _find_active_die_index(str(mutation.get("target_die_id", "")))
	if die_index == -1:
		return {"ok": false, "error": "missing_target_die", "target_die_id": str(mutation.get("target_die_id", ""))}

	var apply_result = _forge_assembly_system.apply_change(current_session.active_dice[die_index], mutation, current_session.inventory)
	if not apply_result.get("ok", false):
		return apply_result

	current_session.active_dice[die_index] = (apply_result.get("die_build", {}) as Dictionary).duplicate(true)
	current_session.inventory = (apply_result.get("inventory", {}) as Dictionary).duplicate(true)
	current_session.reward_flow_state["inventory_snapshot"] = current_session.inventory.duplicate(true)
	current_session.flags["encounter_status"] = "Forge mutation applied: %s" % str(mutation.get("operation", "unknown"))
	return {
		"ok": true,
		"run_session": current_session,
		"result": apply_result,
	}


func complete_reward_flow() -> Variant:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	current_session.flags["screen_state"] = "exploration"
	current_session.flags["encounter_status"] = "Exploration resumed."
	current_session.reward_flow_state = {}
	return current_session


func finalize_run(result: Variant) -> Dictionary:
	return {
		"ok": false,
		"error": "not_implemented",
		"operation": "finalize_run",
		"result": result,
	}


func _is_error_result(value: Variant) -> bool:
	return value is Dictionary and not value.get("ok", true)


func _build_initial_room_states(room_graph: Dictionary, starting_room_id: String) -> Dictionary:
	var room_states: Dictionary = {}
	for room in room_graph.get("rooms", []):
		if not (room is Dictionary):
			continue

		var room_id := str(room.get("id", ""))
		if room_id == "":
			continue

		room_states[room_id] = {
			"revealed": room_id == starting_room_id,
			"completed": false,
			"visit_count": 1 if room_id == starting_room_id else 0,
		}

	return room_states


func _build_default_action_slots() -> Array:
	return [
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
		{
			"slot_id": "utility",
			"display_name": "Utility",
			"allowed_families": ["utility"],
			"min_assignments": 0,
			"assigned_die_ids": [],
		},
	]


func _get_neighbor_ids(room_graph: Dictionary, room_id: String) -> Array[String]:
	var neighbor_ids: Array[String] = []
	for link in room_graph.get("links", []):
		if not (link is Dictionary):
			continue

		var from_room := str(link.get("from", ""))
		var to_room := str(link.get("to", ""))
		if from_room == room_id and not neighbor_ids.has(to_room):
			neighbor_ids.append(to_room)
		elif to_room == room_id and not neighbor_ids.has(from_room):
			neighbor_ids.append(from_room)

	return neighbor_ids


func _get_room_definition(room_graph: Dictionary, room_id: String) -> Dictionary:
	for room in room_graph.get("rooms", []):
		if room is Dictionary and str(room.get("id", "")) == room_id:
			return room
	return {}


func _mark_room_revealed(room_states: Dictionary, room_id: String) -> void:
	var room_state: Dictionary = room_states.get(room_id, {})
	room_state["revealed"] = true
	room_state["visit_count"] = int(room_state.get("visit_count", 0)) + 1
	room_states[room_id] = room_state


func _mark_room_completed(room_states: Dictionary, room_id: String) -> void:
	var room_state: Dictionary = room_states.get(room_id, {})
	room_state["revealed"] = true
	room_state["completed"] = true
	room_state["visit_count"] = max(int(room_state.get("visit_count", 1)), 1)
	room_states[room_id] = room_state


func _find_active_die_index(target_die_id: String) -> int:
	for index in range(current_session.active_dice.size()):
		var die_build: Dictionary = current_session.active_dice[index]
		if str(die_build.get("id", "")) == target_die_id:
			return index
	return -1
