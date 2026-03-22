extends Control

signal run_requested(archetype_id: String)

@onready var archetype_options: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/ArchetypeOptionButton
@onready var summary_label: Label = $CenterContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var start_button: Button = $CenterContainer/PanelContainer/VBoxContainer/StartRunButton

var _archetypes: Array = []


func _ready() -> void:
	archetype_options.item_selected.connect(_on_archetype_selected)
	start_button.pressed.connect(_on_start_pressed)

	if _archetypes.is_empty():
		summary_label.text = "No starter archetypes are available."
		start_button.disabled = true


func configure(archetypes: Array) -> void:
	_archetypes = archetypes.duplicate(true)
	if not is_node_ready():
		await ready

	archetype_options.clear()
	for index in range(_archetypes.size()):
		var archetype: Dictionary = _archetypes[index]
		archetype_options.add_item(str(archetype.get("name", archetype.get("id", "Unknown"))), index)

	start_button.disabled = _archetypes.is_empty()
	_update_summary()


func _on_archetype_selected(_index: int) -> void:
	_update_summary()


func _on_start_pressed() -> void:
	var selected_archetype: Dictionary = _get_selected_archetype()
	if selected_archetype.is_empty():
		return
	run_requested.emit(str(selected_archetype.get("id", "")))


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

	summary_label.text = "Starter floor: %s | HP: %s | Dice: %d" % [
		str(selected_archetype.get("starter_floor_id", "unknown")),
		str((selected_archetype.get("player_state", {}) as Dictionary).get("hp", 0)),
		(selected_archetype.get("starter_dice", []) as Array).size(),
	]
