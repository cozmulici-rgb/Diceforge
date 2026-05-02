class_name CombatController
extends Control

const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const DiceModelScript = preload("res://scripts/combat/dice_model.gd")
const ActionSlotScript = preload("res://scripts/combat/action_slot.gd")
const EnemyEncounterModelScript = preload("res://scripts/combat/enemy_encounter_model.gd")
const BossPhaseControllerScript = preload("res://scripts/combat/boss_phase_controller.gd")
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")
const ModifierRegistryScript = preload("res://scripts/modifiers/modifier_registry.gd")
const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

signal combat_finished(encounter_result)
signal combat_state_updated(combat_state)

# Left panel — enemy
@onready var _enemy_header: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHeaderLabel
@onready var _enemy_portrait: TextureRect = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyPortrait
@onready var _boss_phase_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/BossPhaseLabel
@onready var _enemy_hp_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHpVBox/EnemyHpRow/EnemyHpLabel
@onready var _enemy_block_badge: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHpVBox/EnemyHpRow/EnemyBlockBadge
@onready var _enemy_hp_bar: ProgressBar = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHpVBox/EnemyHpBar
@onready var _intent_header: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/IntentHeader
@onready var _intent_name_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/IntentNameLabel
@onready var _intent_detail_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/IntentDetailLabel
@onready var _enemy_status_header: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyStatusHeader
@onready var _enemy_status_row: HBoxContainer = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyStatusRow
@onready var _enemy_turn_header: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyTurnHeader
@onready var _enemy_turn_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyTurnLabel
@onready var _skip_header: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/SkipHeader
@onready var _skip_label: Label = $RootMargin/MainRow/LeftPanel/EnemyVBox/SkipLabel

# Center — title + dice + queue + buttons
@onready var _enemy_name_label: Label = $RootMargin/MainRow/CenterVBox/TitleVBox/EnemyNameLabel
@onready var _round_label: Label = $RootMargin/MainRow/CenterVBox/TitleVBox/RoundLabel
@onready var _state_label: Label = $RootMargin/MainRow/CenterVBox/TitleVBox/StateLabel
@onready var _dice_header: Label = $RootMargin/MainRow/CenterVBox/DiceSectionVBox/DiceHeader
@onready var _dice_row: HBoxContainer = $RootMargin/MainRow/CenterVBox/DiceSectionVBox/DiceRow
@onready var _queue_header: Label = $RootMargin/MainRow/CenterVBox/QueueSectionVBox/QueueHeader
@onready var _queue_list: VBoxContainer = $RootMargin/MainRow/CenterVBox/QueueSectionVBox/QueueScroll/QueueList
@onready var _queue_hint: Label = $RootMargin/MainRow/CenterVBox/QueueSectionVBox/QueueHint
@onready var roll_button: Button = $RootMargin/MainRow/CenterVBox/ButtonRow/RollButton
@onready var resolve_button: Button = $RootMargin/MainRow/CenterVBox/ButtonRow/ResolveButton

# Right panel — player
@onready var _player_header: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHeaderLabel
@onready var _player_hp_label: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHpVBox/PlayerHpRow/PlayerHpLabel
@onready var _player_block_badge: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHpVBox/PlayerHpRow/PlayerBlockBadge
@onready var _player_hp_bar: ProgressBar = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHpVBox/PlayerHpBar
@onready var _energy_label: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerEnergyRow/EnergyLabel
@onready var _regen_label: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerEnergyRow/RegenLabel
@onready var _player_status_header: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerStatusHeader
@onready var _player_status_row: HBoxContainer = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerStatusRow
@onready var _bonuses_header: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/BonusesHeader
@onready var _player_bonus_list: VBoxContainer = $RootMargin/MainRow/RightPanel/PlayerVBox/PlayerBonusList
@onready var _log_header: Label = $RootMargin/MainRow/RightPanel/PlayerVBox/LogHeader
@onready var _log_scroll: ScrollContainer = $RootMargin/MainRow/RightPanel/PlayerVBox/LogScroll
@onready var _combat_log_list: VBoxContainer = $RootMargin/MainRow/RightPanel/PlayerVBox/LogScroll/CombatLogList

var content_catalog
var dice_model = DiceModelScript.new()
var combat_state = null
var boss_phase_controller = BossPhaseControllerScript.new()
var _engine = null


func _ready() -> void:
	theme = FacetboundThemeScript.build()
	_apply_theme()
	if roll_button != null:
		roll_button.pressed.connect(_on_roll_pressed)
	if resolve_button != null:
		resolve_button.pressed.connect(_on_resolve_pressed)
	_render()


func setup(catalog, state) -> void:
	content_catalog = catalog
	combat_state = state
	if combat_state != null and (combat_state.engine_state as Dictionary).size() > 0:
		_engine = CombatEngineScript.new(content_catalog)
		_engine.load_state(combat_state.engine_state as Dictionary)
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

	var base_hp: int = maxi(int(enemy_definition.get("hp", 1)) + int(modifier_snapshot.get("enemy_hp_delta", 0)), 1)
	var enemy_state = EnemyEncounterModelScript.new({
		"enemy_id": str(enemy_definition.get("id", "")),
		"display_name": str(enemy_definition.get("name", "")),
		"hp": base_hp,
		"block": int(enemy_definition.get("starting_block", 0)),
		"intent_label": str(enemy_definition.get("intent", "Strike")),
		"intent_damage": max(int(enemy_definition.get("damage", 0)) + int(modifier_snapshot.get("enemy_damage_delta", 0)), 0),
	}).to_dictionary()
	enemy_state["max_hp"] = base_hp
	var boss_state = boss_phase_controller.initialize_enemy_state(enemy_definition)
	for key in boss_state.keys():
		enemy_state[key] = boss_state[key]

	var state = CombatStateScript.new({
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

	_engine = CombatEngineScript.new(content_catalog)
	var player_state: Dictionary = run_state.player_state as Dictionary
	var player_data := {
		"hp": int(player_state.get("hp", 30)),
		"max_hp": int(player_state.get("max_hp", player_state.get("hp", 30))),
		"energy": int(player_state.get("energy", 3)),
		"energy_regen": int(player_state.get("energy_regen", 1)),
		"statuses": (player_state.get("status_effects", []) as Array).duplicate(true),
		"dice_pool": _normalize_engine_dice(run_state.active_dice as Array),
	}
	_engine.initialize_battle(player_data, enemy_definition)
	state.engine_state = _engine.get_state()
	return state


func roll_active_dice(state) -> Dictionary:
	if _engine == null:
		return {"ok": false, "error": "missing_combat_engine"}

	_engine.start_player_turn()
	_sync_engine_state(state)
	if bool(state.engine_state.get("player_skip_turn", false)):
		state.roll_results = []
		state.state = "enemy_turn"
		state.turn_log.append("Player turn skipped.")
		return {"ok": true, "combat_state": state}

	var roll_result: Dictionary = _engine.roll_phase((state.pending_player_rolls as Array).duplicate(true))
	if not roll_result.get("ok", false):
		return roll_result

	var engine_state: Dictionary = _engine.get_state()
	var rolled_faces: Array = (engine_state.get("rolled_faces", []) as Array).duplicate(true)
	state.roll_results = _build_roll_results_from_engine(rolled_faces)
	state.pending_player_rolls = _consume_pending_rolls(state.pending_player_rolls, rolled_faces.size())
	state.state = "player_assignment"
	state.turn_log.append("Player rolled %s." % _summarize_rolls(state.roll_results))
	_sync_engine_state(state)
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


func move_die_in_order(state, die_id: String, direction: int) -> Dictionary:
	if direction != -1 and direction != 1:
		return {"ok": false, "error": "invalid_direction"}
	var rolls: Array = state.roll_results as Array
	var current_index := -1
	for index in range(rolls.size()):
		if str((rolls[index] as Dictionary).get("die_id", "")) == die_id:
			current_index = index
			break
	if current_index == -1:
		return {"ok": false, "error": "missing_die"}
	var target_index := current_index + direction
	if target_index < 0 or target_index >= rolls.size():
		return {"ok": false, "error": "out_of_bounds"}
	var swapped = rolls[current_index]
	rolls[current_index] = rolls[target_index]
	rolls[target_index] = swapped
	return {"ok": true, "combat_state": state}


func cycle_die_slot(state, die_id: String) -> Dictionary:
	var rolls: Array = state.roll_results as Array
	var current_slot_id := ""
	var found := false
	for roll in rolls:
		if str((roll as Dictionary).get("die_id", "")) == die_id:
			current_slot_id = str((roll as Dictionary).get("assigned_slot_id", ""))
			found = true
			break
	if not found:
		return {"ok": false, "error": "missing_die"}
	var slots: Array = state.action_slots as Array
	if slots.is_empty():
		return {"ok": false, "error": "no_slots"}
	var current_index := -1
	for index in range(slots.size()):
		if str((slots[index] as Dictionary).get("slot_id", "")) == current_slot_id:
			current_index = index
			break
	var next_index := (current_index + 1) % slots.size()
	var next_slot_id := str((slots[next_index] as Dictionary).get("slot_id", ""))

	# Clear the existing assignment so dice_model.assign_die_to_action does not
	# reject the re-assignment with die_already_assigned.
	for roll in rolls:
		var entry: Dictionary = roll as Dictionary
		if str(entry.get("die_id", "")) == die_id:
			entry["assigned_slot_id"] = ""
			break
	for slot in slots:
		var slot_dict: Dictionary = slot as Dictionary
		var assigned: Array = slot_dict.get("assigned_die_ids", []) as Array
		assigned.erase(die_id)
		slot_dict["assigned_die_ids"] = assigned

	var assign_result := assign_die_to_action(state, die_id, next_slot_id) as Dictionary
	if not bool(assign_result.get("ok", false)) and current_slot_id != "":
		# Per spec §10: if the next slot rejects, the cycle stays on the
		# previous slot — restore the assignment we cleared above.
		var restore_result := assign_die_to_action(state, die_id, current_slot_id) as Dictionary
		if not bool(restore_result.get("ok", false)):
			# Restoration failed too (rare — slot constraints changed mid-call).
			# Surface the original rejection so the UI can react.
			return assign_result
	return assign_result


func resolve_player_turn(state) -> Dictionary:
	if _engine == null:
		return {"ok": false, "error": "missing_combat_engine"}

	var before_state: Dictionary = _engine.get_state()
	var before_enemy: Dictionary = (before_state.get("enemy", {}) as Dictionary).duplicate(true)
	var before_player: Dictionary = (before_state.get("player", {}) as Dictionary).duplicate(true)

	var queue := _resolution_queue_from_assignments(state.roll_results, before_state)
	_engine.set_resolution_queue(queue)
	var resolution_result: Dictionary = _engine.run_resolution_loop()
	if not resolution_result.get("ok", false):
		return resolution_result
	_engine.end_player_turn()
	var battle_result: Dictionary = _engine.check_battle_end()

	_sync_engine_state(state)
	var after_engine_state: Dictionary = state.engine_state
	var after_enemy: Dictionary = (after_engine_state.get("enemy", {}) as Dictionary).duplicate(true)
	var after_player: Dictionary = (after_engine_state.get("player", {}) as Dictionary).duplicate(true)
	var damage_to_enemy := maxi(int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)), 0)
	var gained_block := maxi(int(after_player.get("block", 0)) - int(before_player.get("block", 0)), 0)

	state.turn_log.append("Player turn resolved: %d damage, %d block." % [damage_to_enemy, gained_block])
	state.roll_results = []

	match str(battle_result.get("result", "ongoing")):
		"victory":
			state.outcome = "victory"
			state.state = "complete"
		"defeat":
			state.outcome = "defeat"
			state.state = "complete"
		_:
			state.state = "enemy_turn"

	return {"ok": true, "combat_state": state}


func resolve_enemy_turn(state) -> Dictionary:
	if state.outcome == "victory":
		return {"ok": true, "combat_state": state}
	if _engine == null:
		return {"ok": false, "error": "missing_combat_engine"}

	var before_state: Dictionary = _engine.get_state()
	var before_player: Dictionary = (before_state.get("player", {}) as Dictionary).duplicate(true)
	_engine.run_enemy_turn()
	_engine.end_enemy_turn()
	var battle_result: Dictionary = _engine.check_battle_end()

	_sync_engine_state(state)
	var after_player: Dictionary = ((state.engine_state.get("player", {}) as Dictionary).duplicate(true))
	var taken_damage := maxi(int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)), 0)
	var incoming_damage := taken_damage + maxi(int(before_player.get("block", 0)) - int(after_player.get("block", 0)), 0)
	if bool(state.engine_state.get("enemy_skip_turn", false)):
		state.turn_log.append("Enemy turn skipped.")
	else:
		state.turn_log.append("Enemy turn resolved: %d incoming, %d taken." % [incoming_damage, taken_damage])

	state.roll_results = []
	state.action_slots = _reset_action_slots(state.action_slots)
	match str(battle_result.get("result", "ongoing")):
		"victory":
			state.outcome = "victory"
			state.state = "complete"
		"defeat":
			state.outcome = "defeat"
			state.state = "complete"
		_:
			state.state = "player_roll"

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

	_sync_engine_state(combat_state)
	combat_state_updated.emit(combat_state)
	_render()

	if combat_state.state == "complete":
		var encounter_result = finish_encounter(combat_state)
		combat_finished.emit(encounter_result)
		return encounter_result

	return {"ok": true, "combat_state": combat_state}


# ── UI rendering ─────────────────────────────────────────────────────────────

func _render() -> void:
	if combat_state == null or _enemy_name_label == null:
		return

	var enemy: Dictionary = combat_state.enemy_state as Dictionary
	var engine_player: Dictionary = _engine_player_state()
	var engine_enemy: Dictionary = _engine_enemy_state()

	# Center title
	_enemy_name_label.text = str(enemy.get("display_name", "Encounter"))
	_round_label.text = "Round %d" % int(combat_state.round_index)
	_state_label.text = "◇  %s  ◇" % _format_combat_state(str(combat_state.state)).to_upper()

	# Enemy stats
	var enemy_hp := int(enemy.get("hp", 0))
	var enemy_max_hp := int(enemy.get("max_hp", max(enemy_hp, 1)))
	_enemy_hp_label.text = "%d / %d" % [enemy_hp, enemy_max_hp]
	_enemy_hp_bar.max_value = max(enemy_max_hp, 1)
	_enemy_hp_bar.value = enemy_hp
	_enemy_block_badge.text = "Block %d" % int(enemy.get("block", 0))

	if bool(enemy.get("is_boss", false)):
		_boss_phase_label.visible = true
		_boss_phase_label.text = "◆ Boss: Phase %d" % int(enemy.get("phase_index", 1))
	else:
		_boss_phase_label.visible = false

	var intent_name := str(enemy.get("intent_label", "Strike"))
	var intent_dmg := int(enemy.get("intent_damage", 0))
	_intent_name_label.text = intent_name
	_intent_detail_label.text = "%d Damage" % intent_dmg if intent_dmg > 0 else ""

	var enemy_statuses: Array = (engine_enemy.get("statuses", []) as Array).duplicate(true)
	_rebuild_status_badges(_enemy_status_row, enemy_statuses)

	if str(combat_state.state) == "enemy_turn":
		_enemy_turn_label.text = "Using %s for %d damage." % [intent_name, intent_dmg]
	else:
		_enemy_turn_label.text = "If undisturbed: %s for %d damage." % [intent_name, intent_dmg]

	var skip_cond := str((combat_state.modifier_snapshot as Dictionary).get("skip_condition_label", ""))
	_skip_label.text = skip_cond if skip_cond != "" else "—"

	# Player stats
	var player_hp := int(combat_state.player_hp)
	var player_max_hp := int(engine_player.get("max_hp", max(player_hp, 1)))
	_player_hp_label.text = "%d / %d" % [player_hp, player_max_hp]
	_player_hp_bar.max_value = max(player_max_hp, 1)
	_player_hp_bar.value = player_hp
	_player_block_badge.text = "Block %d" % int(combat_state.player_block)
	_energy_label.text = "%d" % int(engine_player.get("energy", 0))
	_regen_label.text = "+%d Regen" % int(engine_player.get("energy_regen", 0))

	var player_statuses: Array = (engine_player.get("statuses", []) as Array).duplicate(true)
	_rebuild_status_badges(_player_status_row, player_statuses)

	_rebuild_bonuses()
	_rebuild_dice_cards()
	_rebuild_queue_rows()
	_refresh_combat_log()

	# Queue hint
	var roll_results: Array = combat_state.roll_results as Array
	if roll_results.is_empty():
		if str(combat_state.state) == "enemy_turn":
			_queue_hint.text = "Enemy turn pending — press Resolve to continue."
		else:
			_queue_hint.text = "Roll to populate the resolution queue."
	else:
		var assigned_count := 0
		for r in roll_results:
			if str((r as Dictionary).get("assigned_slot_id", "")) != "":
				assigned_count += 1
		var total_cost := _total_energy_cost(roll_results)
		_queue_hint.text = "%d actions  •  Cost %d ⚡" % [assigned_count, total_cost]

	# Buttons
	if roll_button != null:
		roll_button.disabled = str(combat_state.state) != "player_roll"
	if resolve_button != null:
		resolve_button.disabled = not ["player_assignment", "enemy_turn"].has(str(combat_state.state))
	_sync_button_graphics()


func _rebuild_dice_cards() -> void:
	for child in _dice_row.get_children():
		child.queue_free()

	var roll_results: Array = combat_state.roll_results as Array
	if roll_results.is_empty():
		var hint := Label.new()
		hint.text = "No dice rolled yet."
		hint.theme_type_variation = &"FacetBodyMuted"
		_dice_row.add_child(hint)
		return

	for roll in roll_results:
		_dice_row.add_child(_make_die_card(roll as Dictionary))


func _make_die_card(roll: Dictionary) -> Control:
	var family := str(roll.get("face_family", "utility"))
	var fc := _family_color(family)
	var assigned_slot_id := str(roll.get("assigned_slot_id", ""))
	var is_assigned := assigned_slot_id != ""

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(118, 195)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("10161d")
	card_style.border_color = fc if is_assigned else fc.darkened(0.4)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card_style.shadow_size = 6
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	card_style.content_margin_left = 8
	card_style.content_margin_top = 8
	card_style.content_margin_right = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var die_name := Label.new()
	die_name.text = str(roll.get("die_label", "Die")).to_upper()
	die_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_name.theme_type_variation = &"FacetMeta"
	die_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(die_name)

	var value_panel := PanelContainer.new()
	var value_style := StyleBoxFlat.new()
	value_style.bg_color = Color(fc.r * 0.22, fc.g * 0.22, fc.b * 0.22, 1.0)
	value_style.border_color = fc
	value_style.set_border_width_all(2)
	value_style.set_corner_radius_all(4)
	value_style.content_margin_left = 8
	value_style.content_margin_right = 8
	value_style.content_margin_top = 4
	value_style.content_margin_bottom = 4
	value_panel.add_theme_stylebox_override("panel", value_style)
	var value_label := Label.new()
	value_label.text = str(int(roll.get("rolled_value", 0)))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 36)
	value_label.add_theme_color_override("font_color", fc)
	value_panel.add_child(value_label)
	vbox.add_child(value_panel)

	var face_lbl := Label.new()
	face_lbl.text = str(roll.get("face_label", roll.get("face_id", ""))).capitalize()
	face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_lbl.theme_type_variation = &"FacetSectionLabel"
	vbox.add_child(face_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = _effect_label_for_roll(roll)
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_lbl.theme_type_variation = &"FacetMeta"
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(effect_lbl)

	var cost := _energy_cost_for_roll(roll)
	var cost_lbl := Label.new()
	cost_lbl.text = "%d ⚡" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.theme_type_variation = &"FacetInfo"
	vbox.add_child(cost_lbl)

	var control_row := HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 4)

	var die_id := str(roll.get("die_id", ""))
	var rolls: Array = combat_state.roll_results as Array
	var roll_index := -1
	for index in range(rolls.size()):
		if str((rolls[index] as Dictionary).get("die_id", "")) == die_id:
			roll_index = index
			break
	var is_assignment_phase := str(combat_state.state) == "player_assignment"

	var left_button := Button.new()
	left_button.text = "◀"
	left_button.custom_minimum_size = Vector2(28, 24)
	left_button.disabled = (not is_assignment_phase) or roll_index <= 0
	left_button.pressed.connect(func() -> void:
		move_die_in_order(combat_state, die_id, -1)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(left_button)

	var slot_pill := Button.new()
	if is_assigned:
		slot_pill.text = "→ %s" % _format_assigned_slot(assigned_slot_id)
	else:
		slot_pill.text = "→ Assign"
	slot_pill.flat = true
	slot_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_pill.add_theme_color_override("font_color", FacetboundThemeScript.ACCENT_GOLD)
	slot_pill.disabled = not is_assignment_phase
	slot_pill.pressed.connect(func() -> void:
		cycle_die_slot(combat_state, die_id)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(slot_pill)

	var right_button := Button.new()
	right_button.text = "▶"
	right_button.custom_minimum_size = Vector2(28, 24)
	right_button.disabled = (not is_assignment_phase) or roll_index < 0 or roll_index >= rolls.size() - 1
	right_button.pressed.connect(func() -> void:
		move_die_in_order(combat_state, die_id, 1)
		combat_state_updated.emit(combat_state)
		_render()
	)
	control_row.add_child(right_button)

	vbox.add_child(control_row)

	return card


func _rebuild_queue_rows() -> void:
	for child in _queue_list.get_children():
		child.queue_free()

	var index := 1
	for roll in (combat_state.roll_results as Array):
		var roll_data: Dictionary = roll as Dictionary
		if str(roll_data.get("assigned_slot_id", "")) == "":
			continue
		_queue_list.add_child(_make_queue_row(index, roll_data))
		index += 1


func _make_queue_row(index: int, roll: Dictionary) -> Control:
	var family := str(roll.get("face_family", "utility"))
	var fc := _family_color(family)

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color("0e1318")
	row_style.border_color = Color("252d38")
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(3)
	row_style.content_margin_left = 12
	row_style.content_margin_top = 8
	row_style.content_margin_right = 12
	row_style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var idx_lbl := Label.new()
	idx_lbl.text = str(index)
	idx_lbl.custom_minimum_size = Vector2(18, 0)
	idx_lbl.theme_type_variation = &"FacetMeta"
	hbox.add_child(idx_lbl)

	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(fc.r * 0.22, fc.g * 0.22, fc.b * 0.22)
	chip_style.border_color = fc
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(3)
	chip_style.content_margin_left = 6
	chip_style.content_margin_right = 6
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)
	var chip_lbl := Label.new()
	chip_lbl.text = str(int(roll.get("rolled_value", 0)))
	chip_lbl.add_theme_color_override("font_color", fc)
	chip_lbl.add_theme_font_size_override("font_size", 16)
	chip.add_child(chip_lbl)
	hbox.add_child(chip)

	var die_name_lbl := Label.new()
	die_name_lbl.text = str(roll.get("die_label", roll.get("die_id", "Die")))
	die_name_lbl.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(die_name_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = _effect_label_for_roll(roll)
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.theme_type_variation = &"FacetBodyMuted"
	hbox.add_child(effect_lbl)

	var cost := _energy_cost_for_roll(roll)
	var cost_lbl := Label.new()
	cost_lbl.text = "%d ⚡" % cost
	cost_lbl.theme_type_variation = &"FacetInfo"
	hbox.add_child(cost_lbl)

	return row


func _rebuild_status_badges(container: HBoxContainer, statuses: Array) -> void:
	for child in container.get_children():
		child.queue_free()

	if statuses.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "None"
		none_lbl.theme_type_variation = &"FacetMeta"
		container.add_child(none_lbl)
		return

	for status_entry in statuses:
		var status: Dictionary = status_entry as Dictionary
		container.add_child(_make_status_badge(
			str(status.get("id", "status")),
			int(status.get("stacks", 0))
		))


func _make_status_badge(status_id: String, stacks: int) -> Control:
	var status_colors := {
		"burn": Color("e05a1e"), "poison": Color("4ab34a"),
		"freeze": Color("4ab8e0"), "stun": Color("c06adb"),
		"fortify": Color("4a8ae0"), "focus": Color("e0b44a"),
		"bleed": Color("d03040"), "weakness": Color("9070d0"),
	}
	var color: Color = status_colors.get(status_id.to_lower(), Color("9ca6b2"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(38, 38)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18)
	badge_style.border_color = color
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(19)
	badge_style.content_margin_left = 4
	badge_style.content_margin_right = 4
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_style)
	var badge_lbl := Label.new()
	badge_lbl.text = _status_glyph(status_id)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_color_override("font_color", color)
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge.add_child(badge_lbl)
	vbox.add_child(badge)

	var stacks_lbl := Label.new()
	stacks_lbl.text = str(stacks)
	stacks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stacks_lbl.theme_type_variation = &"FacetMeta"
	stacks_lbl.add_theme_color_override("font_color", color)
	vbox.add_child(stacks_lbl)

	var name_lbl := Label.new()
	name_lbl.text = status_id.capitalize()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.theme_type_variation = &"FacetMeta"
	vbox.add_child(name_lbl)

	return vbox


func _rebuild_bonuses() -> void:
	for child in _player_bonus_list.get_children():
		child.queue_free()

	var snap: Dictionary = combat_state.modifier_snapshot as Dictionary
	var attack_bonus := int(snap.get("attack_bonus", 0))
	var block_bonus := int(snap.get("block_bonus", 0))

	if attack_bonus == 0 and block_bonus == 0:
		var lbl := Label.new()
		lbl.text = "—"
		lbl.theme_type_variation = &"FacetMeta"
		_player_bonus_list.add_child(lbl)
		return

	if attack_bonus != 0:
		var lbl := Label.new()
		lbl.text = "+%d Attack Bonus" % attack_bonus
		lbl.theme_type_variation = &"FacetMeta"
		_player_bonus_list.add_child(lbl)
	if block_bonus != 0:
		var lbl := Label.new()
		lbl.text = "+%d Block per Roll" % block_bonus
		lbl.theme_type_variation = &"FacetMeta"
		_player_bonus_list.add_child(lbl)


func _refresh_combat_log() -> void:
	for child in _combat_log_list.get_children():
		child.queue_free()

	var log_lines: Array = combat_state.turn_log as Array
	var recent := log_lines.slice(max(log_lines.size() - 14, 0), log_lines.size())
	for line in recent:
		var lbl := Label.new()
		lbl.text = str(line)
		lbl.theme_type_variation = &"FacetInfo"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_combat_log_list.add_child(lbl)

	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	if _log_scroll != null:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _apply_theme() -> void:
	# Section label variations
	for lbl in [_enemy_header, _player_header, _dice_header, _queue_header,
			_intent_header, _enemy_status_header, _enemy_turn_header,
			_skip_header, _player_status_header, _bonuses_header, _log_header]:
		if lbl != null:
			lbl.theme_type_variation = &"FacetSectionLabel"

	if _enemy_name_label != null:
		_enemy_name_label.theme_type_variation = &"FacetTitle"
	if _round_label != null:
		_round_label.theme_type_variation = &"FacetSubtitle"
	if _state_label != null:
		_state_label.theme_type_variation = &"FacetSectionLabel"
	if _intent_name_label != null:
		_intent_name_label.theme_type_variation = &"FacetDanger"
	if _enemy_turn_label != null:
		_enemy_turn_label.theme_type_variation = &"FacetBodyMuted"
	if _skip_label != null:
		_skip_label.theme_type_variation = &"FacetBodyMuted"
	if _queue_hint != null:
		_queue_hint.theme_type_variation = &"FacetMeta"
	if _boss_phase_label != null:
		_boss_phase_label.theme_type_variation = &"FacetSectionLabel"

	# HP icon colors
	for node_path in [
		"RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHpVBox/EnemyHpRow/EnemyHpIcon",
		"RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHpVBox/PlayerHpRow/PlayerHpIcon",
	]:
		var lbl: Label = get_node_or_null(node_path)
		if lbl != null:
			lbl.add_theme_color_override("font_color", Color("d04444"))

	for node_path in [
		"RootMargin/MainRow/LeftPanel/EnemyVBox/EnemyHpVBox/EnemyHpRow/EnemyBlockBadge",
		"RootMargin/MainRow/RightPanel/PlayerVBox/PlayerHpVBox/PlayerHpRow/PlayerBlockBadge",
	]:
		var lbl: Label = get_node_or_null(node_path)
		if lbl != null:
			lbl.add_theme_color_override("font_color", FacetboundThemeScript.ACCENT_CYAN)

	var energy_icon: Label = get_node_or_null("RootMargin/MainRow/RightPanel/PlayerVBox/PlayerEnergyRow/EnergyIcon")
	if energy_icon != null:
		energy_icon.add_theme_color_override("font_color", FacetboundThemeScript.ACCENT_CYAN)

	# Progress bars
	if _enemy_hp_bar != null:
		_style_hp_bar(_enemy_hp_bar)
	if _player_hp_bar != null:
		_style_hp_bar(_player_hp_bar)

	# Buttons
	if roll_button != null:
		roll_button.theme_type_variation = &"FacetSecondaryButton"
		roll_button.add_theme_font_size_override("font_size", 22)
	if resolve_button != null:
		resolve_button.theme_type_variation = &"FacetPrimaryButton"
		resolve_button.add_theme_font_size_override("font_size", 22)


func _style_hp_bar(bar: ProgressBar) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b83030")
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1a1f26")
	bg.border_color = Color("2a3040")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)


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
	elif combat_state.state == "enemy_turn":
		resolve_enemy_turn(combat_state)
	elif combat_state.state == "player_roll":
		run_auto_round()
		return

	combat_state_updated.emit(combat_state)
	_render()
	if combat_state.state == "complete":
		combat_finished.emit(finish_encounter(combat_state))


func _sync_button_graphics() -> void:
	if roll_button != null:
		roll_button.modulate = Color(1, 1, 1, 0.45) if roll_button.disabled else Color(1, 1, 1, 1)
	if resolve_button != null:
		resolve_button.modulate = Color(1, 1, 1, 0.45) if resolve_button.disabled else Color(1, 1, 1, 1)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _family_color(family: String) -> Color:
	match family:
		"attack": return Color("3a8acc")
		"defense": return Color("3a9a6a")
		"utility": return Color("7a4acc")
		_: return Color("9ca6b2")


func _status_glyph(status_id: String) -> String:
	match status_id.to_lower():
		"burn": return "B"
		"poison": return "P"
		"freeze": return "Fr"
		"stun": return "St"
		"fortify": return "Fo"
		"focus": return "Fc"
		"bleed": return "Bl"
		"weakness": return "W"
		_: return "?"


func _total_energy_cost(roll_results: Array) -> int:
	var total := 0
	for roll in roll_results:
		if str((roll as Dictionary).get("assigned_slot_id", "")) != "":
			total += _energy_cost_for_roll(roll as Dictionary)
	return total


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


func _format_combat_state(state: String) -> String:
	match state:
		"player_roll": return "Awaiting Roll"
		"player_assignment": return "Queue Ready"
		"enemy_turn": return "Enemy Turn"
		"complete": return "Complete"
		_: return state.capitalize()


func _format_assigned_slot(slot_id: String) -> String:
	if slot_id == "":
		return "Unassigned"
	for slot in (combat_state.action_slots as Array):
		var slot_data: Dictionary = slot
		if str(slot_data.get("slot_id", "")) == slot_id:
			return str(slot_data.get("display_name", slot_id))
	return slot_id


func _effect_label_for_roll(roll_data: Dictionary) -> String:
	var engine_state: Dictionary = combat_state.engine_state
	for rolled_face in (engine_state.get("rolled_faces", []) as Array):
		var face: Dictionary = rolled_face as Dictionary
		if str(face.get("die_id", "")) == str(roll_data.get("die_id", "")):
			return str(face.get("effect", roll_data.get("face_family", "utility"))).capitalize()
	return str(roll_data.get("face_family", "utility")).capitalize()


func _energy_cost_for_roll(roll_data: Dictionary) -> int:
	var engine_state: Dictionary = combat_state.engine_state
	for rolled_face in (engine_state.get("rolled_faces", []) as Array):
		var face: Dictionary = rolled_face as Dictionary
		if str(face.get("die_id", "")) == str(roll_data.get("die_id", "")):
			return int(face.get("energy_cost", 0))
	return 0


func _format_statuses(statuses: Array) -> String:
	if statuses.is_empty():
		return ""
	var parts: Array[String] = []
	for status_entry in statuses:
		var status: Dictionary = status_entry as Dictionary
		parts.append("%s x%d/%d" % [
			str(status.get("id", "status")).capitalize(),
			int(status.get("stacks", 0)),
			int(status.get("duration", 0)),
		])
	return ", ".join(parts)


func _engine_player_state() -> Dictionary:
	return ((combat_state.engine_state.get("player", {}) as Dictionary).duplicate(true))


func _engine_enemy_state() -> Dictionary:
	return ((combat_state.engine_state.get("enemy", {}) as Dictionary).duplicate(true))


func _normalize_engine_dice(active_dice: Array) -> Array:
	var normalized: Array = []
	for die_data in active_dice:
		var die: Dictionary = (die_data as Dictionary).duplicate(true)
		if not die.has("statuses"):
			die["statuses"] = []
		if not die.has("runes"):
			var equipped_runes: Array = (die.get("equipped_runes", []) as Array).duplicate(true)
			die["runes"] = equipped_runes.map(func(rune_data: Variant) -> Variant:
				if rune_data is Dictionary:
					return str((rune_data as Dictionary).get("rune_id", ""))
				return rune_data
			)
		if not die.has("core"):
			die["core"] = null
		if not die.has("body_id"):
			die["body_id"] = "standard_d6"
		normalized.append(die)
	return normalized


func _sync_engine_state(state) -> void:
	if _engine == null or state == null:
		return
	state.engine_state = _engine.get_state()
	var engine_state: Dictionary = state.engine_state
	var player: Dictionary = (engine_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy: Dictionary = (engine_state.get("enemy", {}) as Dictionary).duplicate(true)
	state.player_hp = int(player.get("hp", state.player_hp))
	state.player_block = int(player.get("block", state.player_block))
	state.round_index = int(engine_state.get("turn_index", state.round_index))
	if enemy.is_empty():
		return

	state.enemy_state["enemy_id"] = str(enemy.get("id", state.enemy_state.get("enemy_id", "")))
	state.enemy_state["display_name"] = str(enemy.get("display_name", state.enemy_state.get("display_name", "")))
	state.enemy_state["hp"] = int(enemy.get("hp", state.enemy_state.get("hp", 0)))
	state.enemy_state["block"] = int(enemy.get("block", state.enemy_state.get("block", 0)))
	state.enemy_state["intent_label"] = str(enemy.get("intent_label", state.enemy_state.get("intent_label", "Strike")))
	state.enemy_state["intent_damage"] = int(enemy.get("intent_damage", state.enemy_state.get("intent_damage", 0)))
	state.enemy_state["is_boss"] = bool(enemy.get("is_boss", state.enemy_state.get("is_boss", false)))
	state.enemy_state["final_boss"] = bool(enemy.get("final_boss", state.enemy_state.get("final_boss", false)))
	state.enemy_state["phase_index"] = int(enemy.get("phase_index", state.enemy_state.get("phase_index", 1))) + 1


func _build_roll_results_from_engine(rolled_faces: Array) -> Array:
	var results: Array = []
	for rolled_face in rolled_faces:
		var face: Dictionary = rolled_face as Dictionary
		results.append({
			"die_id": str(face.get("die_id", "")),
			"die_label": str(face.get("die_label", face.get("die_id", ""))),
			"rolled_value": int(face.get("rolled_value", 0)),
			"face_id": str(face.get("face_id", "")),
			"face_family": str(face.get("face_family", "utility")),
			"face_label": str(face.get("face_label", face.get("face_id", ""))),
			"assigned_slot_id": "",
		})
	return results


func _consume_pending_rolls(pending_rolls: Array, consumed_count: int) -> Array:
	var remaining := (pending_rolls as Array).duplicate(true)
	for _index in range(mini(consumed_count, remaining.size())):
		remaining.pop_front()
	return remaining


func _resolution_queue_from_assignments(roll_results: Array, engine_state: Dictionary) -> Array:
	var rolled_faces: Array = (engine_state.get("rolled_faces", []) as Array).duplicate(true)
	var queued_die_ids := PackedStringArray()
	for roll_result in roll_results:
		var roll: Dictionary = roll_result as Dictionary
		if str(roll.get("assigned_slot_id", "")) == "":
			continue
		queued_die_ids.append(str(roll.get("die_id", "")))

	var queue: Array = []
	for die_id in queued_die_ids:
		for rolled_face in rolled_faces:
			var face: Dictionary = rolled_face as Dictionary
			if str(face.get("die_id", "")) == die_id:
				queue.append(face.duplicate(true))
				break
	return queue
