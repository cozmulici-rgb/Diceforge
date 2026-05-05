class_name CombatEngine
extends RefCounted

const BattleLogScript = preload("res://scripts/combat/battle_log.gd")
const HookDispatcherScript = preload("res://scripts/combat/hook_dispatcher.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")
const DiceResolverScript = preload("res://scripts/combat/dice_resolver.gd")
const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")
const EnemyAIScript = preload("res://scripts/combat/enemy_ai.gd")
const AutoplayHeuristicScript = preload("res://scripts/combat/autoplay_heuristic.gd")
const ClampingScript = preload("res://scripts/combat/clamping.gd")

var _catalog
var _log := BattleLogScript.new()
var _hook_dispatcher := HookDispatcherScript.new()
var _status_engine := StatusEngineScript.new()
var _dice_resolver := DiceResolverScript.new()
var _effect_resolver := EffectResolverScript.new()
var _enemy_ai := EnemyAIScript.new()
var _autoplay := AutoplayHeuristicScript.new()
var _clamping := ClampingScript.new()
var _state: Dictionary = {}


func _init(catalog = null) -> void:
	_catalog = catalog


func initialize_battle(player_data: Dictionary, enemy_def: Dictionary) -> Dictionary:
	_state = {
		"turn_index": 1,
		"phase": "battle_start",
		"player": {
			"hp": int(player_data.get("hp", 30)),
			"max_hp": int(player_data.get("max_hp", player_data.get("hp", 30))),
			"block": 0,
			"energy": int(player_data.get("energy", 3)),
			"energy_regen": int(player_data.get("energy_regen", 1)),
			"statuses": (player_data.get("statuses", []) as Array).duplicate(true),
		},
		"enemy": {
			"id": str(enemy_def.get("id", "")),
			"display_name": str(enemy_def.get("name", enemy_def.get("id", "Enemy"))),
			"hp": int(enemy_def.get("hp", 1)),
			"max_hp": int(enemy_def.get("max_hp", enemy_def.get("hp", 1))),
			"block": int(enemy_def.get("starting_block", 0)),
			"statuses": (enemy_def.get("statuses", []) as Array).duplicate(true),
			"ai_pattern": (enemy_def.get("ai_pattern", []) as Array).duplicate(true),
			"phases": (enemy_def.get("phases", []) as Array).duplicate(true),
			"phase_index": 0,
			"is_boss": bool(enemy_def.get("is_boss", false)),
			"final_boss": bool(enemy_def.get("final_boss", false)),
			"intent_label": str(enemy_def.get("intent", "Strike")),
			"intent_damage": int(enemy_def.get("damage", 0)),
		},
		"dice_pool": (player_data.get("dice_pool", []) as Array).duplicate(true),
		"rolled_faces": [],
		"resolution_queue": [],
		"enemy_rolls": [],
		"pending_enemy_action": {},
		"used_dice": [],
		"temporary_modifiers": [],
		"player_skip_turn": false,
		"enemy_skip_turn": false,
		"outcome": "",
	}

	_log = BattleLogScript.new()
	_log.record({
		"turn": 1,
		"step_kind": "battle_start",
		"die_id": null,
		"rolled_value": null,
		"resolved_face": null,
		"family": null,
		"effect": null,
		"base_value": null,
		"modifiers_applied": [],
		"outcome": "battle_initialized",
		"rerolled_from": null,
	})
	return {"ok": true}


func start_player_turn() -> void:
	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	var had_skip_status := _has_skip_status(player.get("statuses", []) as Array)
	player["block"] = 0
	player["energy"] = _clamping.clamp_energy(int(player.get("energy", 0)) + int(player.get("energy_regen", 1)))
	var tick_result := _status_engine.tick_statuses(player.get("statuses", []) as Array, "player_turn_start", player, {})
	player = (tick_result.get("entity", player) as Dictionary).duplicate(true)
	player["statuses"] = (tick_result.get("statuses", []) as Array).duplicate(true)
	_state["player"] = player
	_state["used_dice"] = []
	_state["player_skip_turn"] = had_skip_status
	_state["phase"] = "player_turn_start"


func roll_phase(roll_seeds: Array = []) -> Dictionary:
	var face_defs: Dictionary = _catalog.get_part_definitions("face")
	var body_defs: Dictionary = _catalog.get_part_definitions("body")
	var result: Dictionary = _dice_resolver.roll_dice(_state.get("dice_pool", []) as Array, face_defs, body_defs, roll_seeds)
	if not result.get("ok", false):
		return result

	var rolled_faces: Array = (result.get("rolled_faces", []) as Array).duplicate(true)
	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)
	_state["rolled_faces"] = rolled_faces
	_state["phase"] = "player_roll"
	for entry in rolled_faces:
		var entry_data: Dictionary = entry as Dictionary
		var hook_result := _apply_hooks_for_die(entry_data, "on_roll", player, enemy, [])
		player = (hook_result.get("player", player) as Dictionary).duplicate(true)
		enemy = (hook_result.get("enemy", enemy) as Dictionary).duplicate(true)
		_record_roll_entry(entry_data, null)
	_state["player"] = player
	_state["enemy"] = enemy
	return {"ok": true}


func set_resolution_queue(ordered_face_entries: Array) -> void:
	_state["resolution_queue"] = ordered_face_entries.duplicate(true)
	_state["phase"] = "player_assignment"


func build_autoplay_queue() -> void:
	_state["resolution_queue"] = _autoplay.build_queue(_state.get("rolled_faces", []) as Array)
	_state["phase"] = "player_assignment"


func run_resolution_loop() -> Dictionary:
	var queue := (_state.get("resolution_queue", []) as Array).duplicate(true)
	var player := (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy := (_state.get("enemy", {}) as Dictionary).duplicate(true)
	var used_dice := (_state.get("used_dice", []) as Array).duplicate(true)
	var temporary_modifiers := (_state.get("temporary_modifiers", []) as Array).duplicate(true)
	var face_defs: Dictionary = _catalog.get_part_definitions("face")
	var body_defs: Dictionary = _catalog.get_part_definitions("body")

	for index in range(queue.size()):
		var entry: Dictionary = (queue[index] as Dictionary).duplicate(true)
		var die_id := str(entry.get("die_id", ""))

		if bool(entry.get("locked", false)) or bool(entry.get("exhausted", false)):
			continue

		var energy_cost := int(entry.get("energy_cost", 0))
		if energy_cost > int(player.get("energy", 0)):
			continue

		var pre_resolution := _apply_hooks_for_die(entry, "pre_resolution", player, enemy, temporary_modifiers)
		player = (pre_resolution.get("player", player) as Dictionary).duplicate(true)
		enemy = (pre_resolution.get("enemy", enemy) as Dictionary).duplicate(true)
		temporary_modifiers = (pre_resolution.get("temporary_modifiers", temporary_modifiers) as Array).duplicate(true)

		var resolution := _effect_resolver.resolve_face(entry, int(entry.get("rolled_value", 0)), player, enemy, temporary_modifiers, {})
		player = (resolution.get("player", player) as Dictionary).duplicate(true)
		enemy = (resolution.get("enemy", enemy) as Dictionary).duplicate(true)
		temporary_modifiers = (resolution.get("temporary_modifiers", temporary_modifiers) as Array).duplicate(true)
		player["energy"] = _clamping.clamp_energy(int(player.get("energy", 0)) - energy_cost)

		if str(entry.get("effect", "")) == "reroll":
			var targets := _pick_reroll_targets(queue, used_dice, die_id, int(entry.get("value", 1)), index)
			for target_id in targets:
				var reroll_result := _dice_resolver.reroll_die(queue, str(target_id), face_defs, body_defs)
				if reroll_result.get("ok", false):
					var before_entry := _find_queue_entry(queue, str(target_id))
					queue = (reroll_result.get("rolled_faces", queue) as Array).duplicate(true)
					var rerolled_entry := _find_queue_entry(queue, str(target_id))
					_record_roll_entry(rerolled_entry, _step_index_for_entry(before_entry))

		var on_resolution := _apply_hooks_for_die(entry, "on_resolution", player, enemy, temporary_modifiers)
		player = (on_resolution.get("player", player) as Dictionary).duplicate(true)
		enemy = (on_resolution.get("enemy", enemy) as Dictionary).duplicate(true)
		temporary_modifiers = (on_resolution.get("temporary_modifiers", temporary_modifiers) as Array).duplicate(true)

		_log.record({
			"turn": int(_state.get("turn_index", 1)),
			"step_kind": "resolution",
			"die_id": die_id,
			"rolled_value": int(entry.get("rolled_value", 0)),
			"resolved_face": str(entry.get("face_id", "")),
			"family": str(entry.get("face_family", "")),
			"effect": str(entry.get("effect", "")),
			"base_value": int(entry.get("rolled_value", 0)) * int(entry.get("value", 1)),
			"modifiers_applied": [],
			"outcome": "resolved",
			"rerolled_from": null,
		})

		if not used_dice.has(die_id):
			used_dice.append(die_id)

		if int(enemy.get("hp", 0)) <= 0:
			var phase_result := _try_advance_phase(enemy)
			if phase_result.get("transitioned", false):
				enemy = (phase_result.get("enemy", enemy) as Dictionary).duplicate(true)

		if int(player.get("hp", 0)) <= 0:
			break

	_state["resolution_queue"] = queue
	_state["rolled_faces"] = queue.duplicate(true)
	_state["player"] = player
	_state["enemy"] = enemy
	_state["used_dice"] = used_dice
	_state["temporary_modifiers"] = temporary_modifiers
	_state["phase"] = "player_resolution"
	return {"ok": true}


func end_player_turn() -> void:
	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)

	var player_tick := _status_engine.tick_statuses(player.get("statuses", []) as Array, "player_turn_end", player, {})
	player = (player_tick.get("entity", player) as Dictionary).duplicate(true)
	player["statuses"] = (player_tick.get("statuses", []) as Array).duplicate(true)

	var enemy_tick := _status_engine.tick_statuses(enemy.get("statuses", []) as Array, "player_turn_end", enemy, {})
	enemy = (enemy_tick.get("entity", enemy) as Dictionary).duplicate(true)
	enemy["statuses"] = (enemy_tick.get("statuses", []) as Array).duplicate(true)

	_state["player"] = player
	_state["enemy"] = enemy
	_state["temporary_modifiers"] = []
	_state["phase"] = "player_turn_end"


func check_battle_end() -> Dictionary:
	var enemy: Dictionary = _state.get("enemy", {}) as Dictionary
	var player: Dictionary = _state.get("player", {}) as Dictionary

	if int(enemy.get("hp", 0)) <= 0:
		var phase_result := _try_advance_phase(enemy)
		if phase_result.get("transitioned", false):
			_state["enemy"] = (phase_result.get("enemy", enemy) as Dictionary).duplicate(true)
			return {"result": "ongoing"}
		_state["outcome"] = "victory"
		return {"result": "victory"}

	if int(player.get("hp", 0)) <= 0:
		_state["outcome"] = "defeat"
		return {"result": "defeat"}

	return {"result": "ongoing"}


func run_enemy_turn() -> void:
	prepare_enemy_turn()
	resolve_prepared_enemy_turn()


func prepare_enemy_turn() -> void:
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)
	enemy["block"] = 0

	var had_skip_status := _has_skip_status(enemy.get("statuses", []) as Array)
	var enemy_tick := _status_engine.tick_statuses(enemy.get("statuses", []) as Array, "enemy_turn_start", enemy, {})
	enemy = (enemy_tick.get("entity", enemy) as Dictionary).duplicate(true)
	enemy["statuses"] = (enemy_tick.get("statuses", []) as Array).duplicate(true)

	_state["phase"] = "enemy_turn_start"
	_state["enemy"] = enemy
	_state["enemy_skip_turn"] = had_skip_status
	_state["enemy_rolls"] = []
	_state["pending_enemy_action"] = {}

	if had_skip_status:
		return

	var action := _enemy_ai.select_action(enemy, int(_state.get("turn_index", 1)))
	var enemy_roll_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	enemy_roll_rng.randomize()
	_state["pending_enemy_action"] = action
	_state["enemy_rolls"] = build_enemy_rolls(action, int(_state.get("turn_index", 1)), 3, enemy_roll_rng)
	_state["phase"] = "enemy_roll"


func resolve_prepared_enemy_turn() -> void:
	if bool(_state.get("enemy_skip_turn", false)):
		return

	var action: Dictionary = (_state.get("pending_enemy_action", {}) as Dictionary).duplicate(true)
	if action.is_empty():
		prepare_enemy_turn()
		if bool(_state.get("enemy_skip_turn", false)):
			return
		action = (_state.get("pending_enemy_action", {}) as Dictionary).duplicate(true)
		if action.is_empty():
			return

	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)
	player = _enemy_ai.resolve_action(action, player, {})
	_state["player"] = player
	_state["enemy"] = enemy
	_state["phase"] = "enemy_action"
	_log.record({
		"turn": int(_state.get("turn_index", 1)),
		"step_kind": "enemy_action",
		"die_id": null,
		"rolled_value": null,
		"resolved_face": str(action.get("label", "")),
		"family": "enemy",
		"effect": str(action.get("action", "")),
		"base_value": int(action.get("damage", 0)),
		"modifiers_applied": [],
		"outcome": "enemy_resolved",
		"rerolled_from": null,
	})


func build_enemy_rolls(action: Dictionary, turn_index: int, roll_count: int = 3, rng = null) -> Array:
	var count := maxi(roll_count, 1)
	var preview_rolls: Array = []
	var local_rng = rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	for roll_index in range(count):
		var rolled_value := int(local_rng.randi_range(1, 6))
		preview_rolls.append(_build_enemy_roll_entry(action, turn_index, roll_index, rolled_value))
	return preview_rolls


func end_enemy_turn() -> void:
	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)

	var player_tick := _status_engine.tick_statuses(player.get("statuses", []) as Array, "enemy_turn_end", player, {})
	player = (player_tick.get("entity", player) as Dictionary).duplicate(true)
	player["statuses"] = (player_tick.get("statuses", []) as Array).duplicate(true)

	var enemy_tick := _status_engine.tick_statuses(enemy.get("statuses", []) as Array, "enemy_turn_end", enemy, {})
	enemy = (enemy_tick.get("entity", enemy) as Dictionary).duplicate(true)
	enemy["statuses"] = (enemy_tick.get("statuses", []) as Array).duplicate(true)

	_state["player"] = player
	_state["enemy"] = enemy
	_state["turn_index"] = int(_state.get("turn_index", 1)) + 1
	_state["pending_enemy_action"] = {}
	_state["phase"] = "enemy_turn_end"


func get_state() -> Dictionary:
	return _state.duplicate(true)


func load_state(snapshot: Dictionary) -> void:
	_state = snapshot.duplicate(true)


func get_log():
	return _log


func _try_advance_phase(enemy: Dictionary) -> Dictionary:
	var phases := (enemy.get("phases", []) as Array).duplicate(true)
	var current_index := int(enemy.get("phase_index", 0))
	if phases.is_empty() or current_index + 1 >= phases.size():
		return {"transitioned": false}

	var next_phase: Dictionary = (phases[current_index + 1] as Dictionary).duplicate(true)
	var updated := enemy.duplicate(true)
	updated["phase_index"] = current_index + 1
	updated["hp"] = int(next_phase.get("hp", 1))
	updated["max_hp"] = int(next_phase.get("max_hp", next_phase.get("hp", 1)))
	updated["block"] = int(next_phase.get("starting_block", 0))
	updated["intent_label"] = str(next_phase.get("intent", updated.get("intent_label", "Strike")))
	updated["intent_damage"] = int(next_phase.get("damage", updated.get("intent_damage", 0)))
	if next_phase.has("ai_pattern"):
		updated["ai_pattern"] = (next_phase.get("ai_pattern", []) as Array).duplicate(true)

	_log.record({
		"turn": int(_state.get("turn_index", 1)),
		"step_kind": "phase_transition",
		"die_id": null,
		"rolled_value": null,
		"resolved_face": null,
		"family": null,
		"effect": null,
		"base_value": null,
		"modifiers_applied": [],
		"outcome": "phase_advanced",
		"rerolled_from": null,
	})
	return {"transitioned": true, "enemy": updated}


func _pick_reroll_targets(queue: Array, used_dice: Array, host_die_id: String, count: int, current_index: int) -> Array:
	var targets: Array = []
	for index in range(queue.size()):
		if index == current_index:
			continue
		var entry: Dictionary = queue[index] as Dictionary
		var die_id := str(entry.get("die_id", ""))
		if die_id == host_die_id or used_dice.has(die_id):
			continue
		if bool(entry.get("locked", false)) or bool(entry.get("exhausted", false)):
			continue
		targets.append(die_id)
		if targets.size() >= count:
			break
	return targets


func _build_enemy_roll_entry(action: Dictionary, turn_index: int, roll_index: int, rolled_value: int) -> Dictionary:
	var label := str(action.get("label", "Enemy Action"))
	var action_type := str(action.get("action", "attack"))
	var damage := int(action.get("damage", action.get("damage_per_hit", 0)))
	var hits := maxi(int(action.get("hits", 1)), 1)
	var total_damage := damage * hits
	return {
		"die_id": "enemy_turn_%d_%d" % [turn_index, roll_index],
		"die_label": "Enemy Die %d" % (roll_index + 1),
		"rolled_value": clampi(rolled_value, 1, 6),
		"face_id": action_type,
		"face_family": "enemy",
		"face_label": label,
		"energy_cost": 0,
		"effect_label": action_type.capitalize(),
		"action_label": label,
		"action_type": action_type,
		"hits": hits,
		"damage": damage,
		"damage_total": total_damage,
	}


func _record_roll_entry(entry: Dictionary, rerolled_from: Variant) -> void:
	_log.record({
		"turn": int(_state.get("turn_index", 1)),
		"step_kind": "roll",
		"die_id": str(entry.get("die_id", "")),
		"rolled_value": int(entry.get("rolled_value", 0)),
		"resolved_face": str(entry.get("face_id", "")),
		"family": str(entry.get("face_family", "")),
		"effect": str(entry.get("effect", "")),
		"base_value": int(entry.get("rolled_value", 0)) * int(entry.get("value", 1)),
		"modifiers_applied": [],
		"outcome": "rolled" if rerolled_from == null else "rerolled",
		"rerolled_from": rerolled_from,
	})


func _apply_hooks_for_die(entry: Dictionary, timing_key: String, player: Dictionary, enemy: Dictionary, temporary_modifiers: Array) -> Dictionary:
	var hooks := _collect_die_hooks(entry, timing_key)
	var updated_player := player.duplicate(true)
	var updated_enemy := enemy.duplicate(true)
	var updated_modifiers := temporary_modifiers.duplicate(true)

	for hook in hooks:
		var hook_result := _apply_hook(hook as Dictionary, updated_player, updated_enemy, updated_modifiers)
		updated_player = (hook_result.get("player", updated_player) as Dictionary).duplicate(true)
		updated_enemy = (hook_result.get("enemy", updated_enemy) as Dictionary).duplicate(true)
		updated_modifiers = (hook_result.get("temporary_modifiers", updated_modifiers) as Array).duplicate(true)

	return {
		"player": updated_player,
		"enemy": updated_enemy,
		"temporary_modifiers": updated_modifiers,
	}


func _collect_die_hooks(entry: Dictionary, timing_key: String) -> Array:
	var hooks: Array = []
	var core_ref = entry.get("core", null)
	if core_ref != null:
		hooks.append_array(_hooks_from_part_reference(core_ref, timing_key))

	var rune_refs: Array = (entry.get("runes", []) as Array).duplicate(true)
	for rune_ref in rune_refs:
		hooks.append_array(_hooks_from_part_reference(rune_ref, timing_key))

	return _hook_dispatcher.collect_and_sort(hooks, timing_key)


func _hooks_from_part_reference(part_ref: Variant, timing_key: String) -> Array:
	var part_id := _extract_part_id(part_ref)
	if part_id == "":
		return []

	var definition: Dictionary = _catalog.load_part_definition(part_id)
	if definition is Dictionary and definition.get("error", "") != "":
		return []

	var hooks_value = definition.get("hooks", {})
	if not (hooks_value is Dictionary):
		return []
	if not (hooks_value as Dictionary).has(timing_key):
		return []

	var timing_hook = (hooks_value as Dictionary).get(timing_key)
	var results: Array = []
	if timing_hook is Array:
		for hook_entry in timing_hook:
			if hook_entry is Dictionary:
				var hook_data: Dictionary = (hook_entry as Dictionary).duplicate(true)
				hook_data["timing"] = timing_key
				hook_data["source"] = part_id
				results.append(hook_data)
	elif timing_hook is Dictionary:
		var hook_data: Dictionary = (timing_hook as Dictionary).duplicate(true)
		hook_data["timing"] = timing_key
		hook_data["source"] = part_id
		results.append(hook_data)
	return results


func _extract_part_id(part_ref: Variant) -> String:
	if part_ref is String:
		return str(part_ref)
	if part_ref is Dictionary:
		var ref_dict: Dictionary = part_ref as Dictionary
		for key in ["id", "part_id", "rune_id", "core_id"]:
			if str(ref_dict.get(key, "")) != "":
				return str(ref_dict.get(key, ""))
	return ""


func _apply_hook(hook: Dictionary, player: Dictionary, enemy: Dictionary, temporary_modifiers: Array) -> Dictionary:
	var updated_player := player.duplicate(true)
	var updated_enemy := enemy.duplicate(true)
	var updated_modifiers := temporary_modifiers.duplicate(true)
	match str(hook.get("type", "")):
		"apply_status":
			var target_side := str(hook.get("target", "enemy"))
			var status_id := str(hook.get("status", ""))
			var statuses: Array = []
			if target_side == "player":
				statuses = (updated_player.get("statuses", []) as Array).duplicate(true)
				statuses = _status_engine.add_status(statuses, {
					"id": status_id,
					"stacks": int(hook.get("stacks", 1)),
					"duration": int(hook.get("duration", 1)),
					"timing": _timing_for_status(status_id, target_side),
				})
				updated_player["statuses"] = statuses
			else:
				statuses = (updated_enemy.get("statuses", []) as Array).duplicate(true)
				statuses = _status_engine.add_status(statuses, {
					"id": status_id,
					"stacks": int(hook.get("stacks", 1)),
					"duration": int(hook.get("duration", 1)),
					"timing": _timing_for_status(status_id, target_side),
				})
				updated_enemy["statuses"] = statuses
		"damage_bonus":
			updated_modifiers.append({
				"type": "damage_additive",
				"bonus": int(hook.get("value", 0)),
				"consumed": false,
			})

	return {
		"player": updated_player,
		"enemy": updated_enemy,
		"temporary_modifiers": updated_modifiers,
	}


func _timing_for_status(status_id: String, target_side: String) -> String:
	match status_id:
		"freeze", "stun":
			return "%s_turn_start" % target_side
		"poison":
			return "%s_turn_end" % target_side
		"burn":
			return "enemy_turn_end" if target_side == "player" else "player_turn_end"
		_:
			return "%s_turn_end" % target_side


func _find_queue_entry(queue: Array, die_id: String) -> Dictionary:
	for entry in queue:
		var item: Dictionary = entry as Dictionary
		if str(item.get("die_id", "")) == die_id:
			return item.duplicate(true)
	return {}


func _step_index_for_entry(entry: Dictionary) -> Variant:
	if entry.is_empty():
		return null
	var die_id := str(entry.get("die_id", ""))
	var rolled_value := int(entry.get("rolled_value", -1))
	var entries := _log.get_entries()
	for index in range(entries.size() - 1, -1, -1):
		var item: Dictionary = entries[index] as Dictionary
		if str(item.get("step_kind", "")) == "roll" and str(item.get("die_id", "")) == die_id and int(item.get("rolled_value", -2)) == rolled_value:
			return int(item.get("step_index", -1))
	return null


func _has_skip_status(statuses: Array) -> bool:
	for status in statuses:
		var item: Dictionary = status as Dictionary
		if (str(item.get("id", "")) == "freeze" or str(item.get("id", "")) == "stun") and int(item.get("stacks", 0)) > 0:
			return true
	return false
