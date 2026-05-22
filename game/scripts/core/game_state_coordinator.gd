class_name GameStateCoordinator
extends RefCounted

const RunSessionScript = preload("res://scripts/core/run_session.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const RewardControllerScript = preload("res://scripts/rewards/reward_controller.gd")
const ForgeAssemblySystemScript = preload("res://scripts/rewards/forge_assembly_system.gd")
const RunInventoryScript = preload("res://scripts/rewards/run_inventory.gd")
const DungeonGeneratorScript = preload("res://scripts/exploration/dungeon_generator.gd")
const RoomTransitionResultScript = preload("res://scripts/exploration/room_transition_result.gd")
const PersistenceServiceScript = preload("res://scripts/persistence/persistence_service.gd")
const MetaProgressionControllerScript = preload("res://scripts/progression/meta_progression_controller.gd")
const MetaStateScript = preload("res://scripts/progression/meta_state.gd")
const DailyVoidModeAdapterScript = preload("res://scripts/modes/daily_void_mode_adapter.gd")
const ModifierRegistryScript = preload("res://scripts/modifiers/modifier_registry.gd")

var content_catalog
var current_session = null
var _session_sequence := 0
var _reward_controller
var _forge_assembly_system
var _dungeon_generator
var persistence_service
var meta_progression_controller
var meta_state
var daily_void_mode_adapter
var modifier_registry
var last_recovery_message := ""

const _LEGACY_ACTIVE_SLOT_ID := "active_run"


func _init(catalog, base_path_override: String = "") -> void:
	content_catalog = catalog
	_reward_controller = RewardControllerScript.new(catalog)
	_forge_assembly_system = ForgeAssemblySystemScript.new(catalog)
	_dungeon_generator = DungeonGeneratorScript.new(catalog)
	var storage_base_path := base_path_override if base_path_override != "" else "user://diceforge"
	persistence_service = PersistenceServiceScript.new(catalog, storage_base_path)
	meta_progression_controller = MetaProgressionControllerScript.new(catalog)
	daily_void_mode_adapter = DailyVoidModeAdapterScript.new(catalog)
	modifier_registry = ModifierRegistryScript.new(catalog)
	_load_or_initialize_meta_state()
	_migrate_legacy_active_run_slot_if_needed()


func create_run_session(archetype_id: String) -> Variant:
	var archetype = content_catalog.load_archetype(archetype_id)
	if _is_error_result(archetype):
		return archetype

	var starter_floor = content_catalog.load_floor_template(str(archetype.get("starter_floor_id", "")))
	if _is_error_result(starter_floor):
		return starter_floor

	_session_sequence += 1
	var generated_slot_id: String = _generate_run_slot_id(archetype_id)
	var generated_display_name: String = _format_run_display_name(archetype)
	var session = RunSessionScript.new({
		"session_id": "run_%03d_%s" % [_session_sequence, archetype_id],
		"slot_id": generated_slot_id,
		"display_name": generated_display_name,
		"archetype_id": archetype_id,
		"floor_index": 1,
		"current_room_id": str(starter_floor.get("starting_room_id", "")),
		"room_graph_id": str(starter_floor.get("room_graph_id", "")),
		"player_state": (archetype.get("player_state", {})).duplicate(true),
		"active_dice": (archetype.get("starter_dice", [])).duplicate(true),
		"inventory": {
			"bodies": [],
			"faces": [],
			"runes": [],
			"currencies": {"echo_shards": 0},
			"modifiers": [],
		},
		"modifiers": [],
		"mode_id": "standard",
		"seed_id": "",
		"numeric_seed": 0,
		"daily_void_config": {},
		"score_summary": {
			"bosses_defeated": 0,
			"modifier_count": 0,
			"score_bonus": 0,
		},
		"flags": {
			"starter_floor_id": str(archetype.get("starter_floor_id", "")),
			"room_history": [str(starter_floor.get("starting_room_id", ""))],
			"active_encounter": {},
			"screen_state": "exploration",
			"pending_floor_advance": "",
			"pending_run_complete": false,
			"run_mode": "standard",
			"encounter_status": "Run started. Move into the tutorial hall to trigger the encounter stub.",
		},
		"room_states": {},
		"action_slots": _build_default_action_slots(),
		"last_encounter_result": {},
		"reward_flow_state": {},
		"floor_state": {},
		"run_complete": false,
		"progression_result": {},
	})

	var floor_result = _initialize_floor(session, archetype.get("starter_floor_id", ""), 1)
	if _is_error_result(floor_result):
		return floor_result

	current_session = session
	_persist_current_session()
	return session


func create_daily_void_session(archetype_id: String, calendar_day: String = "") -> Variant:
	var target_day := calendar_day if calendar_day != "" else Time.get_date_string_from_system()
	var daily_config = daily_void_mode_adapter.create_daily_run_config(target_day, meta_state)
	if not daily_config.get("ok", false):
		return daily_config
	if not (daily_config.get("allowed_archetype_ids", []) as Array).has(archetype_id):
		return {"ok": false, "error": "archetype_not_allowed", "archetype_id": archetype_id}

	var session = create_run_session(archetype_id)
	if session == null or session is Dictionary:
		return session

	var temp_standard_slot_id: String = str(session.slot_id)

	var session_overrides = daily_void_mode_adapter.create_daily_run_session(daily_config, archetype_id)
	if not session_overrides.get("ok", false):
		return session_overrides
	var overrides: Dictionary = session_overrides.get("session_overrides", {})
	session.session_id = "daily_%s_%s" % [archetype_id, str(overrides.get("session_id_suffix", target_day)).replace("-", "_")]
	session.slot_id = _generate_daily_slot_id(target_day)
	session.display_name = _format_daily_display_name(target_day)
	if temp_standard_slot_id != "" and temp_standard_slot_id != session.slot_id:
		persistence_service.delete_run_state(temp_standard_slot_id)
	session.mode_id = str(overrides.get("mode_id", "daily_void"))
	session.seed_id = str(overrides.get("seed_id", target_day))
	session.numeric_seed = int(overrides.get("numeric_seed", 0))
	session.daily_void_config = daily_config.duplicate(true)
	session.modifiers = (overrides.get("modifiers", []) as Array).duplicate(true)
	session.inventory["modifiers"] = session.modifiers.duplicate(true)
	session.flags["run_mode"] = "daily_void"
	session.flags["daily_void_calendar_day"] = target_day
	session.flags["encounter_status"] = "Daily Void ready for %s." % target_day
	session.score_summary = {
		"bosses_defeated": 0,
		"modifier_count": session.modifiers.size(),
		"score_bonus": int(modifier_registry.build_progression_snapshot(session.modifiers).get("score_bonus", 0)),
	}
	var floor_result = _initialize_floor(session, str(session.flags.get("starter_floor_id", "")), 1)
	if _is_error_result(floor_result):
		return floor_result
	current_session = session
	_persist_current_session()
	return session


func load_run_session(save_slot_id: String) -> Dictionary:
	var load_result = persistence_service.load_run_state(save_slot_id)
	if not load_result.get("ok", false):
		last_recovery_message = "Continue-run data was invalid and could not be loaded."
		if load_result.get("error", "") == "invalid_run_state":
			persistence_service.delete_run_state(save_slot_id)
		return load_result

	current_session = RunSessionScript.new(load_result.get("data", {}))
	return {"ok": true, "run_session": current_session}


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

	if current_room_id != room_id:
		var current_room_definition = _get_room_definition(room_graph, current_room_id)
		var current_room_state: Dictionary = current_session.room_states.get(current_room_id, {})
		if str(current_room_definition.get("encounter_id", "")) != "" and not bool(current_room_state.get("completed", false)):
			return {
				"ok": false,
				"error": "encounter_unresolved",
				"from_room_id": current_room_id,
				"to_room_id": room_id,
			}

	current_session.current_room_id = room_id
	var room_history: Array = current_session.flags.get("room_history", [])
	room_history.append(room_id)
	current_session.flags["room_history"] = room_history
	current_session.flags["encounter_status"] = "Entered room %s." % room_id
	_mark_room_revealed(current_session.room_states, room_id)
	_sync_floor_state_from_room_states()

	var room_definition = _get_room_definition(room_graph, room_id)
	_persist_current_session()
	return RoomTransitionResultScript.new({
		"room_id": room_id,
		"room_type": str(room_definition.get("type", "unknown")),
		"encounter_id": str(room_definition.get("encounter_id", "")),
		"reward_source_id": str(room_definition.get("reward_source_id", "")),
		"floor_complete": bool(current_session.flags.get("pending_floor_advance", "") != ""),
		"run_complete": current_session.run_complete,
	}).to_dictionary()


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
	var current_room_state: Dictionary = current_session.room_states.get(str(current_session.current_room_id), {})
	if bool(current_room_state.get("completed", false)):
		return {"ok": false, "error": "room_already_completed"}
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
	_persist_current_session()

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
		_sync_floor_state_from_room_states()
		if bool(result.get("boss_defeated", false)):
			current_session.score_summary["bosses_defeated"] = int(current_session.score_summary.get("bosses_defeated", 0)) + 1
			var current_floor = content_catalog.load_floor_template(str(current_session.floor_state.get("floor_template_id", "")))
			var next_floor_id := str(current_floor.get("next_floor_id", ""))
			if bool(result.get("run_complete", false)):
				current_session.flags["pending_run_complete"] = true
			elif next_floor_id != "":
				current_session.flags["pending_floor_advance"] = next_floor_id
		current_session.flags["screen_state"] = "reward"
	elif str(result.get("outcome", "")) == "defeat":
		current_session.run_complete = true
		current_session.progression_result = finalize_run(result)
		current_session.flags["screen_state"] = "run_complete"
		_clear_current_run_slot()
		_persist_meta_state()
	else:
		current_session.flags["screen_state"] = "exploration"

	_persist_current_session()
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
	_persist_current_session()
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
	_persist_current_session()
	return {
		"ok": true,
		"run_session": current_session,
		"result": apply_result,
	}


func complete_reward_flow() -> Variant:
	if current_session == null:
		return {"ok": false, "error": "no_active_session"}
	current_session.reward_flow_state = {}
	if bool(current_session.flags.get("pending_run_complete", false)):
		current_session.flags["pending_run_complete"] = false
		current_session.run_complete = true
		current_session.progression_result = finalize_run(current_session.last_encounter_result)
		current_session.flags["screen_state"] = "run_complete"
		current_session.flags["encounter_status"] = "Run complete."
		_clear_current_run_slot()
		_persist_meta_state()
		return current_session

	var next_floor_id := str(current_session.flags.get("pending_floor_advance", ""))
	if next_floor_id != "":
		current_session.flags["pending_floor_advance"] = ""
		var next_floor_index: int = current_session.floor_index + 1
		var floor_result = _initialize_floor(current_session, next_floor_id, next_floor_index)
		if _is_error_result(floor_result):
			return floor_result
		current_session.flags["screen_state"] = "exploration"
		current_session.flags["encounter_status"] = "Advanced to floor %d." % next_floor_index
		_persist_current_session()
		return current_session

	current_session.flags["screen_state"] = "exploration"
	current_session.flags["encounter_status"] = "Exploration resumed."
	_persist_current_session()
	return current_session


func finalize_run(result: Variant) -> Dictionary:
	var run_summary = _build_run_summary(result)
	var progression_result = meta_progression_controller.process_run_end(run_summary, meta_state)
	progression_result = daily_void_mode_adapter.finalize_daily_result(current_session, progression_result)
	meta_state = MetaStateScript.new(progression_result.get("meta_state", {}))
	current_session.progression_result = progression_result.duplicate(true)
	return progression_result


func _is_error_result(value: Variant) -> bool:
	return value is Dictionary and value.has("ok") and not value.get("ok", false)


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


func _initialize_floor(session, floor_template_id: String, floor_index: int) -> Variant:
	var floor_template = content_catalog.load_floor_template(str(floor_template_id))
	if _is_error_result(floor_template):
		return floor_template
	var room_graph = content_catalog.load_room_graph(str(floor_template.get("room_graph_id", "")))
	if _is_error_result(room_graph):
		return room_graph
	var generation_seed := int(floor_template.get("seed", floor_index))
	if int(session.numeric_seed) != 0:
		generation_seed += int(session.numeric_seed)
	var floor_state = _dungeon_generator.generate_floor(str(floor_template_id), generation_seed, session)
	if _is_error_result(floor_state):
		return floor_state
	if not _dungeon_generator.is_boss_path_reachable(floor_state):
		return {"ok": false, "error": "unreachable_boss_path", "floor_template_id": floor_template_id}

	session.floor_index = floor_index
	session.current_room_id = str(floor_template.get("starting_room_id", ""))
	session.room_graph_id = str(floor_template.get("room_graph_id", ""))
	session.room_states = _build_initial_room_states(room_graph, session.current_room_id)
	session.floor_state = floor_state.to_dictionary()
	session.floor_state["floor_index"] = floor_index
	return {"ok": true}


func _sync_floor_state_from_room_states() -> void:
	if current_session == null:
		return
	var visited_room_ids: Array[String] = []
	var completed_room_ids: Array[String] = []
	for room_id in current_session.room_states.keys():
		var room_state: Dictionary = current_session.room_states[room_id]
		if bool(room_state.get("revealed", false)):
			visited_room_ids.append(str(room_id))
		if bool(room_state.get("completed", false)):
			completed_room_ids.append(str(room_id))
	current_session.floor_state["visited_room_ids"] = visited_room_ids
	current_session.floor_state["completed_room_ids"] = completed_room_ids


func _build_run_summary(result: Variant) -> Dictionary:
	var progression_snapshot: Dictionary = modifier_registry.build_progression_snapshot(current_session.modifiers)
	return {
		"outcome": str((result as Dictionary).get("outcome", "unknown")),
		"boss_defeated": bool((result as Dictionary).get("boss_defeated", false)),
		"run_complete": bool((result as Dictionary).get("run_complete", current_session.run_complete)),
		"floors_cleared": int(current_session.floor_index),
		"archetype_id": current_session.archetype_id,
		"session_id": current_session.session_id,
		"mode_id": current_session.mode_id,
		"seed_id": current_session.seed_id,
		"modifier_ids": current_session.modifiers.duplicate(true),
		"modifier_count": current_session.modifiers.size(),
		"bosses_defeated": int(current_session.score_summary.get("bosses_defeated", 0)),
		"score_bonus": int(progression_snapshot.get("score_bonus", 0)),
		"echo_shard_bonus": int(progression_snapshot.get("echo_shard_bonus", 0)),
	}


func _persist_current_session() -> void:
	if current_session == null or current_session.run_complete:
		return
	if str(current_session.slot_id) == "":
		return
	var payload = current_session.to_dictionary()
	payload["updated_at_unix"] = Time.get_unix_time_from_system()
	persistence_service.save_run_state(current_session.slot_id, payload)


func _clear_current_run_slot() -> void:
	if current_session == null or str(current_session.slot_id) == "":
		return
	persistence_service.delete_run_state(current_session.slot_id)


func _persist_meta_state() -> void:
	if meta_state == null:
		return
	persistence_service.save_meta_state(meta_state.to_dictionary())


func _load_or_initialize_meta_state() -> void:
	var load_result = persistence_service.load_meta_state()
	if load_result.get("ok", false):
		meta_state = MetaStateScript.new(load_result.get("data", {}))
		return

	meta_state = MetaStateScript.new()
	_persist_meta_state()
	if load_result.get("error", "") not in ["missing_meta_state", ""]:
		last_recovery_message = "Meta progression data was reset to safe defaults."


func _generate_run_slot_id(archetype_id: String) -> String:
	var unix_now: int = int(Time.get_unix_time_from_system())
	var safe_archetype: String = archetype_id.replace("-", "_").substr(0, 16)
	var base_id: String = "run_%d_%s" % [unix_now, safe_archetype]
	var candidate: String = base_id
	var suffix: int = 2
	while persistence_service.run_slot_exists(candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate


func _generate_daily_slot_id(calendar_day: String) -> String:
	return "daily_%s" % calendar_day.replace("-", "_")


func _format_run_display_name(archetype: Dictionary) -> String:
	var archetype_name: String = str(archetype.get("name", archetype.get("id", "Run")))
	var ts: String = "%s %s" % [Time.get_date_string_from_system(), Time.get_time_string_from_system().substr(0, 5)]
	return "%s · %s" % [archetype_name, ts]


func _format_daily_display_name(calendar_day: String) -> String:
	return "Daily Void · %s" % calendar_day


func _migrate_legacy_active_run_slot_if_needed() -> void:
	if not persistence_service.run_slot_exists(_LEGACY_ACTIVE_SLOT_ID):
		return
	var load_result = persistence_service.load_run_state(_LEGACY_ACTIVE_SLOT_ID)
	if not load_result.get("ok", false):
		persistence_service.delete_run_state(_LEGACY_ACTIVE_SLOT_ID)
		last_recovery_message = "Legacy run save was reset to safe defaults."
		return
	var data: Dictionary = (load_result.get("data", {}) as Dictionary).duplicate(true)
	var archetype_id: String = str(data.get("archetype_id", "run"))
	var new_slot_id: String = _generate_run_slot_id(archetype_id)
	data["slot_id"] = new_slot_id
	if str(data.get("display_name", "")) == "":
		data["display_name"] = "Recovered Run · %s" % Time.get_date_string_from_system()
	data["updated_at_unix"] = Time.get_unix_time_from_system()
	persistence_service.save_run_state(new_slot_id, data)
	persistence_service.delete_run_state(_LEGACY_ACTIVE_SLOT_ID)


func list_resumable_runs() -> Array:
	var result: Array = []
	for slot in list_run_slots():
		var summary: Dictionary = slot
		var slot_id: String = str(summary.get("slot_id", ""))
		if slot_id == "" or slot_id.begins_with("daily_"):
			continue
		if bool(summary.get("is_corrupt", false)):
			# Surface corrupt entries so the popup can offer Delete-only on them.
			result.append(summary.duplicate(true))
			continue
		result.append(summary.duplicate(true))
	result.sort_custom(func(a, b):
		return int((a as Dictionary).get("updated_at_unix", 0)) > int((b as Dictionary).get("updated_at_unix", 0)))
	return result


func rename_run(slot_id: String, new_name: String) -> Dictionary:
	var trimmed: String = new_name.strip_edges()
	if trimmed.length() == 0:
		return {"ok": false, "error": "empty_name"}
	if trimmed.length() > 64:
		return {"ok": false, "error": "name_too_long"}
	var load_result = persistence_service.load_run_state(slot_id)
	if not load_result.get("ok", false):
		return load_result
	var data: Dictionary = (load_result.get("data", {}) as Dictionary).duplicate(true)
	data["display_name"] = trimmed
	data["updated_at_unix"] = Time.get_unix_time_from_system()
	var save_result = persistence_service.save_run_state(slot_id, data)
	if not save_result.get("ok", false):
		return save_result
	if current_session != null and str(current_session.slot_id) == slot_id:
		current_session.display_name = trimmed
	return {"ok": true, "slot_id": slot_id, "display_name": trimmed}


func delete_run(slot_id: String) -> Dictionary:
	if slot_id == "":
		return {"ok": false, "error": "missing_slot_id"}
	if current_session != null and not current_session.run_complete and str(current_session.slot_id) == slot_id:
		return {"ok": false, "error": "active_run_locked"}
	return persistence_service.delete_run_state(slot_id)


func list_run_slots() -> Array:
	return persistence_service.list_run_slots()
