extends Control

signal run_requested(archetype_id: String)
signal daily_void_requested(archetype_id: String)
signal continue_requested(slot_id: String)

@onready var archetype_options: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/ArchetypeOptionButton
@onready var summary_label: Label = $CenterContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var start_button: Button = $CenterContainer/PanelContainer/VBoxContainer/StartRunButton
@onready var daily_void_button: Button = $CenterContainer/PanelContainer/VBoxContainer/DailyVoidButton
@onready var continue_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ContinueRunButton

var _archetypes: Array = []
var _continue_summary: Dictionary = {}
var _recovery_message := ""
var _last_daily_void_result: Dictionary = {}


func _ready() -> void:
	archetype_options.item_selected.connect(_on_archetype_selected)
	start_button.pressed.connect(_on_start_pressed)
	daily_void_button.pressed.connect(_on_daily_void_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	if _archetypes.is_empty():
		summary_label.text = "No starter archetypes are available."
		start_button.disabled = true
		daily_void_button.disabled = true
	continue_button.disabled = true


func configure(archetypes: Array, continue_summary: Dictionary = {}, recovery_message: String = "", last_daily_void_result: Dictionary = {}) -> void:
	_archetypes = archetypes.duplicate(true)
	_continue_summary = continue_summary.duplicate(true)
	_recovery_message = recovery_message
	_last_daily_void_result = last_daily_void_result.duplicate(true)
	if not is_node_ready():
		await ready

	archetype_options.clear()
	for index in range(_archetypes.size()):
		var archetype: Dictionary = _archetypes[index]
		archetype_options.add_item(str(archetype.get("name", archetype.get("id", "Unknown"))), index)

	start_button.disabled = _archetypes.is_empty()
	daily_void_button.disabled = _archetypes.is_empty()
	continue_button.disabled = _continue_summary.is_empty() or bool(_continue_summary.get("is_corrupt", false))
	_update_summary()


func _on_archetype_selected(_index: int) -> void:
	_update_summary()


func _on_start_pressed() -> void:
	var selected_archetype: Dictionary = _get_selected_archetype()
	if selected_archetype.is_empty():
		return
	run_requested.emit(str(selected_archetype.get("id", "")))


func _on_continue_pressed() -> void:
	if _continue_summary.is_empty():
		return
	continue_requested.emit(str(_continue_summary.get("slot_id", "")))


func _on_daily_void_pressed() -> void:
	var selected_archetype: Dictionary = _get_selected_archetype()
	if selected_archetype.is_empty():
		return
	daily_void_requested.emit(str(selected_archetype.get("id", "")))


func _get_selected_archetype() -> Dictionary:
	if _archetypes.is_empty():
		return {}

	var selected_index: int = archetype_options.get_selected()
	if selected_index < 0 or selected_index >= _archetypes.size():
		selected_index = 0

	return _archetypes[selected_index]


func _update_summary() -> void:
	var selected_archetype: Dictionary = _get_selected_archetype()
	if selected_archetype.is_empty():
		summary_label.text = "No starter archetypes are available."
		return

	var parts: Array[String] = []
	parts.append("Starter floor: %s | HP: %s | Dice: %d" % [
		str(selected_archetype.get("starter_floor_id", "unknown")),
		str((selected_archetype.get("player_state", {}) as Dictionary).get("hp", 0)),
		(selected_archetype.get("starter_dice", []) as Array).size(),
	])
	if not _continue_summary.is_empty():
		parts.append("Continue slot %s | Floor %d | Room %s" % [
			str(_continue_summary.get("slot_id", "")),
			int(_continue_summary.get("floor_index", 0)),
			str(_continue_summary.get("room_id", "")),
		])
	if _recovery_message != "":
		parts.append("Recovery: %s" % _recovery_message)
	if not _last_daily_void_result.is_empty():
		parts.append("Daily Void: %s | Score %d | %s" % [
			str(_last_daily_void_result.get("seed_id", "")),
			int(_last_daily_void_result.get("score", 0)),
			str(_last_daily_void_result.get("submission_status", "not_attempted")),
		])
	summary_label.text = "\n".join(parts)
