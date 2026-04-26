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
		"used_dice": [],
		"temporary_modifiers": [],
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
	player["block"] = 0
	player["energy"] = _clamping.clamp_energy(int(player.get("energy", 0)) + int(player.get("energy_regen", 1)))
	var tick_result := _status_engine.tick_statuses(player.get("statuses", []) as Array, "player_turn_start", player, {})
	player = (tick_result.get("entity", player) as Dictionary).duplicate(true)
	player["statuses"] = (tick_result.get("statuses", []) as Array).duplicate(true)
	_state["player"] = player
	_state["used_dice"] = []
	_state["phase"] = "player_turn_start"


func roll_phase(roll_seeds: Array = []) -> Dictionary:
	var face_defs: Dictionary = _catalog.get_part_definitions("face")
	var body_defs: Dictionary = _catalog.get_part_definitions("body")
	var result: Dictionary = _dice_resolver.roll_dice(_state.get("dice_pool", []) as Array, face_defs, body_defs, roll_seeds)
	if not result.get("ok", false):
		return result

	var rolled_faces: Array = (result.get("rolled_faces", []) as Array).duplicate(true)
	_state["rolled_faces"] = rolled_faces
	_state["phase"] = "player_roll"
	for entry in rolled_faces:
		_record_roll_entry(entry as Dictionary, null)
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
	var enemy: Dictionary = (_state.get("enemy", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (_state.get("player", {}) as Dictionary).duplicate(true)
	enemy["block"] = 0

	var enemy_tick := _status_engine.tick_statuses(enemy.get("statuses", []) as Array, "enemy_turn_start", enemy, {})
	enemy = (enemy_tick.get("entity", enemy) as Dictionary).duplicate(true)
	enemy["statuses"] = (enemy_tick.get("statuses", []) as Array).duplicate(true)

	_state["phase"] = "enemy_turn_start"
	_state["enemy"] = enemy

	if _has_skip_status(enemy.get("statuses", []) as Array):
		return

	var action := _enemy_ai.select_action(enemy, int(_state.get("turn_index", 1)))
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
	_state["phase"] = "enemy_turn_end"


func get_state() -> Dictionary:
	return _state.duplicate(true)


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
