class_name CombatController
extends Control

const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const DiceModelScript = preload("res://scripts/combat/dice_model.gd")
const ActionSlotScript = preload("res://scripts/combat/action_slot.gd")
const EnemyEncounterModelScript = preload("res://scripts/combat/enemy_encounter_model.gd")
const BossPhaseControllerScript = preload("res://scripts/combat/boss_phase_controller.gd")
const ModifierRegistryScript = preload("res://scripts/modifiers/modifier_registry.gd")
const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

signal combat_finished(encounter_result)
signal combat_state_updated(combat_state)

@onready var title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
@onready var state_label = get_node_or_null("MarginContainer/VBoxContainer/StateLabel")
@onready var enemy_label = get_node_or_null("MarginContainer/VBoxContainer/SummaryRow/EnemyPanel/EnemyBox/EnemyLabel")
@onready var player_label = get_node_or_null("MarginContainer/VBoxContainer/SummaryRow/PlayerPanel/PlayerBox/PlayerLabel")
@onready var slots_label = get_node_or_null("MarginContainer/VBoxContainer/ActionRow/SlotsPanel/SlotsBox/SlotsLabel")
@onready var rolls_label = get_node_or_null("MarginContainer/VBoxContainer/ActionRow/RollsPanel/RollsBox/RollsLabel")
@onready var log_label = get_node_or_null("MarginContainer/VBoxContainer/LogPanel/LogBox/LogLabel")
@onready var roll_button = get_node_or_null("MarginContainer/VBoxContainer/ButtonRow/RollButton")
@onready var resolve_button = get_node_or_null("MarginContainer/VBoxContainer/ButtonRow/ResolveButton")
@onready var roll_label_graphic: TextureRect = get_node_or_null("MarginContainer/VBoxContainer/ButtonRow/RollButton/RollLabelGraphic")
@onready var resolve_label_graphic: TextureRect = get_node_or_null("MarginContainer/VBoxContainer/ButtonRow/ResolveButton/ResolveLabelGraphic")

var content_catalog
var dice_model = DiceModelScript.new()
var combat_state = null
var boss_phase_controller = BossPhaseControllerScript.new()


func _ready() -> void:
	_apply_theme()
	if roll_button != null:
		roll_button.pressed.connect(_on_roll_pressed)
	if resolve_button != null:
		resolve_button.pressed.connect(_on_resolve_pressed)
	_render()


func setup(catalog, state) -> void:
	content_catalog = catalog
	combat_state = state
	if is_node_ready():
		_render()


func begin_encounter(run_state, encounter_definition: Dictionary) -> Variant:
	var enemy_definition = content_catalog.load_enemy_definition(str(encounter_definition.get("enemy_id", "")))
	if enemy_definition is Dictionary and enemy_definition.get("error", "") != "":
		return enemy_definition

	var action_slots: Array = []
	for slot_data in (run_state.action_slots as Array):
		action_slots.append(ActionSlotScript.new(slot_data).to_dictionary())
	var modifier_registry = ModifierRegistryScript.new(content_catalog)
	var modifier_snapshot: Dictionary = modifier_registry.build_combat_snapshot(run_state.modifiers)

	var enemy_state = EnemyEncounterModelScript.new({
		"enemy_id": str(enemy_definition.get("id", "")),
		"display_name": str(enemy_definition.get("name", "")),
		"hp": max(int(enemy_definition.get("hp", 1)) + int(modifier_snapshot.get("enemy_hp_delta", 0)), 1),
		"block": int(enemy_definition.get("starting_block", 0)),
		"intent_label": str(enemy_definition.get("intent", "Strike")),
		"intent_damage": max(int(enemy_definition.get("damage", 0)) + int(modifier_snapshot.get("enemy_damage_delta", 0)), 0),
	}).to_dictionary()
	var boss_state = boss_phase_controller.initialize_enemy_state(enemy_definition)
	for key in boss_state.keys():
		enemy_state[key] = boss_state[key]

	return CombatStateScript.new({
		"encounter_id": str(encounter_definition.get("id", "")),
		"room_id": str(run_state.current_room_id),
		"round_index": 1,
		"player_hp": int((run_state.player_state as Dictionary).get("hp", 0)) + int(modifier_snapshot.get("player_hp_bonus", 0)),
		"player_block": 0,
		"active_dice": (run_state.active_dice as Array).duplicate(true),
		"action_slots": action_slots,
		"roll_results": [],
		"enemy_state": enemy_state,
		"modifier_snapshot": modifier_snapshot,
		"turn_log": ["Encounter started against %s." % enemy_state.get("display_name", "Unknown Enemy")],
		"pending_player_rolls": (encounter_definition.get("player_rolls", []) as Array).duplicate(true),
		"state": "player_roll",
		"outcome": "",
	})


func roll_active_dice(state) -> Dictionary:
	var body_definitions = content_catalog.get_part_definitions("body")
	var face_definitions = content_catalog.get_part_definitions("face")
	var roll_result = dice_model.roll_active_dice(state.active_dice, face_definitions, body_definitions, state.pending_player_rolls)
	if not roll_result.get("ok", false):
		return roll_result

	state.roll_results = (roll_result.get("roll_results", []) as Array).duplicate(true)
	state.pending_player_rolls = (roll_result.get("remaining_rolls", []) as Array).duplicate(true)
	state.state = "player_assignment"
	state.turn_log.append("Player rolled %s." % _summarize_rolls(state.roll_results))
	return {"ok": true, "combat_state": state}


func assign_die_to_action(state, die_id: String, action_slot_id: String) -> Dictionary:
	var cloned_rolls: Array = (state.roll_results as Array).duplicate(true)
	var cloned_slots: Array = (state.action_slots as Array).duplicate(true)
	var assignment_result = dice_model.assign_die_to_action(cloned_rolls, cloned_slots, die_id, action_slot_id)
	if not assignment_result.get("ok", false):
		return assignment_result

	state.roll_results = assignment_result.get("roll_results", [])
	state.action_slots = assignment_result.get("action_slots", [])
	return {"ok": true, "combat_state": state}


func resolve_player_turn(state) -> Dictionary:
	var face_definitions = content_catalog.get_part_definitions("face")
	var enemy_definition = content_catalog.load_enemy_definition(str((state.enemy_state as Dictionary).get("enemy_id", "")))
	var total_attack: int = 0
	var total_block: int = 0

	for roll_result in state.roll_results:
		var roll: Dictionary = roll_result
		if str(roll.get("assigned_slot_id", "")) == "":
			continue

		var face_definition: Dictionary = face_definitions.get(str(roll.get("face_id", "")), {})
		var family: String = str(face_definition.get("family", roll.get("face_family", "utility")))
		var power_multiplier: int = int(face_definition.get("power_multiplier", 1))
		if family == "attack":
			total_attack += int(roll.get("rolled_value", 0)) * power_multiplier
		elif family == "defense":
			total_block += int(roll.get("rolled_value", 0)) * power_multiplier
		elif family == "utility":
			total_block += int(face_definition.get("bonus_block", 1))

	total_attack += int((state.modifier_snapshot as Dictionary).get("attack_bonus", 0))
	total_block += int((state.modifier_snapshot as Dictionary).get("block_bonus", 0))

	var enemy_state: Dictionary = state.enemy_state.duplicate(true)
	var enemy_block: int = int(enemy_state.get("block", 0))
	var damage_to_enemy: int = max(total_attack - enemy_block, 0)
	enemy_state["block"] = max(enemy_block - total_attack, 0)
	enemy_state["hp"] = max(int(enemy_state.get("hp", 0)) - damage_to_enemy, 0)
	state.enemy_state = enemy_state
	state.player_block += total_block
	state.turn_log.append("Player turn resolved: %d damage, %d block." % [damage_to_enemy, total_block])
	state.state = "enemy_turn"
	if int(enemy_state.get("hp", 0)) <= 0:
		if bool(enemy_state.get("is_boss", false)):
			var phase_result = boss_phase_controller.advance_phase(enemy_state)
			if bool(phase_result.get("transitioned", false)):
				state.enemy_state = (phase_result.get("enemy_state", {}) as Dictionary).duplicate(true)
				state.turn_log.append("Boss advanced to phase %d." % int((state.enemy_state as Dictionary).get("phase_index", 1)))
				state.round_index += 1
				state.state = "player_roll"
				state.roll_results = []
				state.action_slots = _reset_action_slots(state.action_slots)
			else:
				state.outcome = "victory"
				state.state = "complete"
		else:
			state.outcome = "victory"
			state.state = "complete"

	return {"ok": true, "combat_state": state}


func resolve_enemy_turn(state) -> Dictionary:
	if state.outcome == "victory":
		return {"ok": true, "combat_state": state}

	var enemy_state: Dictionary = state.enemy_state.duplicate(true)
	var incoming_damage: int = int(enemy_state.get("intent_damage", 0))
	var mitigated_damage: int = max(incoming_damage - state.player_block, 0)
	state.player_block = max(state.player_block - incoming_damage, 0)
	state.player_hp = max(state.player_hp - mitigated_damage, 0)
	state.turn_log.append("Enemy turn resolved: %d incoming, %d taken." % [incoming_damage, mitigated_damage])

	if state.player_hp <= 0:
		state.outcome = "defeat"
		state.state = "complete"
	else:
		state.round_index += 1
		state.state = "player_roll"
		state.roll_results = []
		state.action_slots = _reset_action_slots(state.action_slots)

	return {"ok": true, "combat_state": state}


func finish_encounter(state) -> Dictionary:
	var encounter_definition = content_catalog.load_encounter(str(state.encounter_id))
	var outcome: String = state.outcome
	if outcome == "":
		if int((state.enemy_state as Dictionary).get("hp", 0)) <= 0:
			outcome = "victory"
		elif state.player_hp <= 0:
			outcome = "defeat"
		else:
			outcome = "retreat"

	return {
		"ok": true,
		"outcome": outcome,
		"player_hp_after": state.player_hp,
		"rewards_unlocked": [],
		"echo_shards_awarded": 0,
		"boss_defeated": bool((state.enemy_state as Dictionary).get("is_boss", false)) and outcome == "victory",
		"floor_complete": bool((state.enemy_state as Dictionary).get("is_boss", false)) and outcome == "victory",
		"run_complete": outcome == "defeat" or (bool((state.enemy_state as Dictionary).get("final_boss", false)) and outcome == "victory"),
		"encounter_id": state.encounter_id,
		"room_id": state.room_id,
		"reward_source": {
			"reward_type": "encounter",
			"reward_source_id": str(encounter_definition.get("reward_table_id", "")),
		},
		"turn_log": (state.turn_log as Array).duplicate(true),
	}


func run_auto_round() -> Dictionary:
	if combat_state == null:
		return {"ok": false, "error": "missing_combat_state"}

	var roll_result = roll_active_dice(combat_state)
	if not roll_result.get("ok", false):
		return roll_result

	for roll in combat_state.roll_results:
		var slot_id = _default_slot_for_roll(roll)
		if slot_id == "":
			continue
		var assign_result = assign_die_to_action(combat_state, str((roll as Dictionary).get("die_id", "")), slot_id)
		if not assign_result.get("ok", false):
			return assign_result

	var player_result = resolve_player_turn(combat_state)
	if not player_result.get("ok", false):
		return player_result
	if combat_state.state != "complete":
		var enemy_result = resolve_enemy_turn(combat_state)
		if not enemy_result.get("ok", false):
			return enemy_result

	combat_state_updated.emit(combat_state)
	_render()

	if combat_state.state == "complete":
		var encounter_result = finish_encounter(combat_state)
		combat_finished.emit(encounter_result)
		return encounter_result

	return {"ok": true, "combat_state": combat_state}


func _default_slot_for_roll(roll: Dictionary) -> String:
	var family: String = str(roll.get("face_family", "utility"))
	if family == "attack":
		return "main_attack"
	if family == "defense":
		return "guard"
	return "utility"


func _reset_action_slots(action_slots: Array) -> Array:
	var reset_slots: Array = []
	for slot in action_slots:
		var cloned_slot: Dictionary = (slot as Dictionary).duplicate(true)
		cloned_slot["assigned_die_ids"] = []
		reset_slots.append(cloned_slot)
	return reset_slots


func _summarize_rolls(roll_results: Array) -> String:
	var parts: Array[String] = []
	for roll in roll_results:
		var result: Dictionary = roll
		parts.append("%s=%d(%s)" % [
			str(result.get("die_id", "")),
			int(result.get("rolled_value", 0)),
			str(result.get("face_id", "")),
		])
	return ", ".join(parts)


func _render() -> void:
	if combat_state == null or title_label == null:
		return

	title_label.text = str((combat_state.enemy_state as Dictionary).get("display_name", "Encounter"))
	if state_label != null:
		state_label.text = "Round %d  |  Phase %s" % [
			int(combat_state.round_index),
			_format_combat_state(str(combat_state.state)),
		]
	enemy_label.text = _build_enemy_summary()
	player_label.text = _build_player_summary()
	slots_label.text = _build_slots_summary()
	rolls_label.text = _build_rolls_summary()
	log_label.text = _build_log_summary()
	if roll_button != null:
		roll_button.disabled = combat_state.state != "player_roll"
	if resolve_button != null:
		resolve_button.disabled = combat_state.state == "complete"
	_sync_button_graphics()


func _on_roll_pressed() -> void:
	if combat_state == null:
		return
	var result = roll_active_dice(combat_state)
	if not result.get("ok", false):
		return
	for roll in combat_state.roll_results:
		var slot_id = _default_slot_for_roll(roll)
		if slot_id != "":
			assign_die_to_action(combat_state, str((roll as Dictionary).get("die_id", "")), slot_id)
	combat_state_updated.emit(combat_state)
	_render()


func _on_resolve_pressed() -> void:
	if combat_state == null:
		return
	if combat_state.state == "player_assignment":
		resolve_player_turn(combat_state)
		if combat_state.state != "complete":
			resolve_enemy_turn(combat_state)
	elif combat_state.state == "player_roll":
		run_auto_round()
		return

	combat_state_updated.emit(combat_state)
	_render()
	if combat_state.state == "complete":
		combat_finished.emit(finish_encounter(combat_state))


func _apply_theme() -> void:
	theme = FacetboundThemeScript.build()
	if title_label != null:
		title_label.theme_type_variation = &"FacetTitle"
	if state_label != null:
		state_label.theme_type_variation = &"FacetSubtitle"
	if enemy_label != null:
		enemy_label.theme_type_variation = &"FacetBodyMuted"
	if player_label != null:
		player_label.theme_type_variation = &"FacetBodyMuted"
	if slots_label != null:
		slots_label.theme_type_variation = &"FacetBodyMuted"
	if rolls_label != null:
		rolls_label.theme_type_variation = &"FacetBodyMuted"
	if log_label != null:
		log_label.theme_type_variation = &"FacetInfo"
	if roll_button != null:
		roll_button.theme_type_variation = &"FacetPrimaryButton"
		roll_button.text = ""
	if resolve_button != null:
		resolve_button.theme_type_variation = &"FacetSecondaryButton"
		resolve_button.text = ""


func _sync_button_graphics() -> void:
	if roll_label_graphic != null and roll_button != null:
		roll_label_graphic.modulate = Color(1, 1, 1, 0.42) if roll_button.disabled else Color(1, 1, 1, 1)
	if resolve_label_graphic != null and resolve_button != null:
		resolve_label_graphic.modulate = Color(1, 1, 1, 0.42) if resolve_button.disabled else Color(1, 1, 1, 1)


func _build_enemy_summary() -> String:
	var enemy_state: Dictionary = combat_state.enemy_state as Dictionary
	var lines: Array[String] = []
	lines.append("%s" % str(enemy_state.get("display_name", "Unknown Enemy")))
	lines.append("HP %d   Block %d" % [
		int(enemy_state.get("hp", 0)),
		int(enemy_state.get("block", 0)),
	])
	lines.append("Intent: %s (%d)" % [
		str(enemy_state.get("intent_label", "Strike")),
		int(enemy_state.get("intent_damage", 0)),
	])
	if bool(enemy_state.get("is_boss", false)):
		lines.append("Boss phase %d" % int(enemy_state.get("phase_index", 1)))
	return "\n".join(lines)


func _build_player_summary() -> String:
	var lines: Array[String] = []
	lines.append("HP %d   Block %d" % [int(combat_state.player_hp), int(combat_state.player_block)])
	lines.append("State: %s" % _format_combat_state(str(combat_state.state)))
	lines.append("Dice in pool: %d" % (combat_state.active_dice as Array).size())
	var modifier_snapshot: Dictionary = combat_state.modifier_snapshot as Dictionary
	var attack_bonus := int(modifier_snapshot.get("attack_bonus", 0))
	var block_bonus := int(modifier_snapshot.get("block_bonus", 0))
	if attack_bonus != 0 or block_bonus != 0:
		lines.append("Bonuses: +%d atk / +%d block" % [attack_bonus, block_bonus])
	return "\n".join(lines)


func _build_slots_summary() -> String:
	var lines: Array[String] = []
	for slot in (combat_state.action_slots as Array):
		var slot_data: Dictionary = slot
		var assigned_die_ids: Array = slot_data.get("assigned_die_ids", [])
		var families: Array = slot_data.get("allowed_families", [])
		var assigned_text := "Empty"
		if not assigned_die_ids.is_empty():
			assigned_text = ", ".join(_stringify_values(assigned_die_ids))
		lines.append("%s [%s]\n%s" % [
			str(slot_data.get("display_name", slot_data.get("slot_id", "Slot"))),
			"/".join(_stringify_values(families)),
			assigned_text,
		])
	return "\n\n".join(lines)


func _build_rolls_summary() -> String:
	var lines: Array[String] = []
	for roll in (combat_state.roll_results as Array):
		var roll_data: Dictionary = roll
		lines.append("%s  %s %d  -> %s" % [
			str(roll_data.get("die_label", roll_data.get("die_id", "Die"))),
			str(roll_data.get("face_label", roll_data.get("face_id", "face"))),
			int(roll_data.get("rolled_value", 0)),
			_format_assigned_slot(str(roll_data.get("assigned_slot_id", ""))),
		])
	if lines.is_empty():
		return "Roll to populate the action tray."
	return "\n".join(lines)


func _build_log_summary() -> String:
	var lines: Array = combat_state.turn_log as Array
	if lines.is_empty():
		return "Encounter started."
	var tail := lines.slice(max(lines.size() - 4, 0), lines.size())
	return "\n".join(_stringify_values(tail))


func _format_combat_state(state: String) -> String:
	match state:
		"player_roll":
			return "Awaiting Roll"
		"player_assignment":
			return "Assigning Dice"
		"enemy_turn":
			return "Enemy Turn"
		"complete":
			return "Complete"
		_:
			return state.capitalize()


func _format_assigned_slot(slot_id: String) -> String:
	if slot_id == "":
		return "Unassigned"
	for slot in (combat_state.action_slots as Array):
		var slot_data: Dictionary = slot
		if str(slot_data.get("slot_id", "")) == slot_id:
			return str(slot_data.get("display_name", slot_id))
	return slot_id


func _stringify_values(values: Array) -> PackedStringArray:
	var parts := PackedStringArray()
	for value in values:
		parts.append(str(value))
	return parts
