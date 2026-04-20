extends Control

const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

signal reward_selected(option_data: Dictionary)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var source_label: Label = $MarginContainer/VBoxContainer/SourceLabel
@onready var options_container: VBoxContainer = $MarginContainer/VBoxContainer/OptionsContainer
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel

var _reward_flow_state: Dictionary = {}


func _ready() -> void:
	_apply_theme()
	_render()


func setup(reward_flow_state: Dictionary) -> void:
	_reward_flow_state = reward_flow_state.duplicate(true)
	if is_node_ready():
		_render()


func _render() -> void:
	if title_label == null:
		return

	title_label.text = "Reward Selection"
	source_label.text = "Source: %s (%s)" % [
		str(_reward_flow_state.get("reward_source_id", "unknown")),
		str(_reward_flow_state.get("reward_type", "unknown")),
	]
	summary_label.text = "Choose one reward. Forge opens automatically if this flow allows it and spare parts exist."

	for child in options_container.get_children():
		child.queue_free()

	for option_data in _reward_flow_state.get("available_options", []):
		var option: Dictionary = option_data
		var button := Button.new()
		button.theme_type_variation = &"FacetSecondaryButton"
		button.text = "%s x%d [%s]" % [
			str(option.get("content_id", "unknown")),
			int(option.get("quantity", 1)),
			str(option.get("grant_type", "unknown")),
		]
		button.pressed.connect(_on_option_pressed.bind(option.duplicate(true)))
		options_container.add_child(button)


func _on_option_pressed(option_data: Dictionary) -> void:
	reward_selected.emit(option_data)


func _apply_theme() -> void:
	theme = FacetboundThemeScript.build()
	title_label.theme_type_variation = &"FacetTitle"
	source_label.theme_type_variation = &"FacetSubtitle"
	summary_label.theme_type_variation = &"FacetBodyMuted"
