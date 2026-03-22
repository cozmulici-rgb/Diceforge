extends Control

signal return_to_menu_requested()

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel
@onready var details_label: Label = $MarginContainer/VBoxContainer/DetailsLabel
@onready var return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

var _progression_result: Dictionary = {}


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_render()


func configure(progression_result: Dictionary) -> void:
	_progression_result = progression_result.duplicate(true)
	if is_node_ready():
		_render()


func _render() -> void:
	if title_label == null:
		return
	title_label.text = "Run Summary"
	summary_label.text = "Echo Shards: +%d | Total: %d" % [
		int(_progression_result.get("echo_shards_gained", 0)),
		int(_progression_result.get("echo_shards_total", 0)),
	]
	details_label.text = "Unlocks: %s | Achievements: %s" % [
		", ".join(_to_string_array(_progression_result.get("new_unlock_ids", []))),
		", ".join(_to_string_array(_progression_result.get("achievement_ids", []))),
	]


func _on_return_pressed() -> void:
	return_to_menu_requested.emit()


func _to_string_array(values: Array) -> Array[String]:
	var string_values: Array[String] = []
	for value in values:
		string_values.append(str(value))
	return string_values
