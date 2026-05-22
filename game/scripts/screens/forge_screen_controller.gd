extends Control

const DiceforgeThemeScript = preload("res://scripts/ui/diceforge_theme.gd")

signal forge_complete()

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel
@onready var dice_label: Label = $MarginContainer/VBoxContainer/InfoRow/DicePanel/DiceBox/DiceLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InfoRow/InventoryPanel/InventoryBox/InventoryLabel
@onready var mutation_container: VBoxContainer = $MarginContainer/VBoxContainer/MutationPanel/MutationBox/MutationContainer
@onready var preview_label: Label = $MarginContainer/VBoxContainer/PreviewPanel/PreviewBox/PreviewLabel
@onready var apply_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ApplyButton
@onready var done_button: Button = $MarginContainer/VBoxContainer/ButtonRow/DoneButton

var _coordinator
var _forge_state: Dictionary = {}
var _selected_mutation: Dictionary = {}


func _ready() -> void:
	_apply_theme()
	apply_button.pressed.connect(_on_apply_pressed)
	done_button.pressed.connect(_on_done_pressed)
	_render()


func setup(coordinator, forge_state: Dictionary) -> void:
	_coordinator = coordinator
	_forge_state = forge_state.duplicate(true)
	if is_node_ready():
		_render()


func _render() -> void:
	if title_label == null or _coordinator == null:
		return

	title_label.text = "Forge"
	summary_label.text = "Choose one mutation to preview, then apply it or return to the run."
	_refresh_labels()
	preview_label.text = "Select a mutation to preview it."
	apply_button.disabled = true

	for child in mutation_container.get_children():
		child.queue_free()

	for mutation in _build_candidate_mutations():
		var button := Button.new()
		button.theme_type_variation = &"FacetTertiaryButton"
		button.text = _describe_mutation(mutation)
		button.pressed.connect(_on_mutation_pressed.bind(mutation))
		mutation_container.add_child(button)


func _refresh_labels() -> void:
	var die_summaries: Array[String] = []
	for die_build in _coordinator.current_session.active_dice:
		var die: Dictionary = die_build
		var face_labels: Array[String] = []
		for face_id in die.get("face_set", []):
			face_labels.append(str(face_id))
		die_summaries.append("%s [%s]\n%s" % [
			str(die.get("id", "")),
			str(die.get("body_id", "standard_d6")),
			", ".join(face_labels),
		])
	dice_label.text = "\n\n".join(die_summaries)

	var inventory: Dictionary = _coordinator.current_session.inventory
	inventory_label.text = "Bodies: %s\nFaces: %s\nRunes: %s" % [
		_format_inventory_group(inventory.get("bodies", [])),
		_format_inventory_group(inventory.get("faces", [])),
		_format_inventory_group(inventory.get("runes", [])),
	]


func _build_candidate_mutations() -> Array:
	var mutations: Array = []
	var active_dice: Array = _coordinator.current_session.active_dice
	if active_dice.is_empty():
		return mutations

	var first_die: Dictionary = active_dice[0]
	for body_id in _coordinator.current_session.inventory.get("bodies", []):
		mutations.append({
			"target_die_id": str(first_die.get("id", "")),
			"operation": "swap_body",
			"part_id": str(body_id),
			"slot_id": "",
		})
	for face_id in _coordinator.current_session.inventory.get("faces", []):
		mutations.append({
			"target_die_id": str(first_die.get("id", "")),
			"operation": "replace_face",
			"part_id": str(face_id),
			"slot_id": "face_0",
		})
	for rune_id in _coordinator.current_session.inventory.get("runes", []):
		mutations.append({
			"target_die_id": str(first_die.get("id", "")),
			"operation": "socket_rune",
			"part_id": str(rune_id),
			"slot_id": "core",
		})
	return mutations


func _describe_mutation(mutation: Dictionary) -> String:
	var operation := str(mutation.get("operation", ""))
	var part_id := str(mutation.get("part_id", ""))
	var target_die_id := str(mutation.get("target_die_id", ""))
	var slot_id := str(mutation.get("slot_id", ""))
	match operation:
		"swap_body":
			return "Swap body on %s to %s" % [target_die_id, part_id]
		"replace_face":
			return "Replace %s on %s with %s" % [slot_id, target_die_id, part_id]
		"socket_rune":
			return "Socket %s into %s (%s)" % [part_id, target_die_id, slot_id]
		_:
			return "%s %s on %s (%s)" % [operation, part_id, target_die_id, slot_id]


func _on_mutation_pressed(mutation: Dictionary) -> void:
	var preview = _coordinator.preview_forge_mutation(mutation)
	_selected_mutation = {}
	if not preview.get("ok", false):
		preview_label.text = "Rejected: %s" % str(preview.get("error", "unknown"))
		apply_button.disabled = true
		return

	_selected_mutation = mutation.duplicate(true)
	var preview_die: Dictionary = preview.get("die_build", {})
	var preview_faces: Array[String] = []
	for face_id in preview_die.get("face_set", []):
		preview_faces.append(str(face_id))
	preview_label.text = "Preview: %s -> [%s] %s" % [
		str(preview_die.get("id", "")),
		str(preview_die.get("body_id", "")),
		", ".join(preview_faces),
	]
	apply_button.disabled = false


func _on_apply_pressed() -> void:
	if _selected_mutation.is_empty():
		return

	var apply_result = _coordinator.apply_forge_mutation(_selected_mutation)
	if not apply_result.get("ok", false):
		preview_label.text = "Apply failed: %s" % str(apply_result.get("error", "unknown"))
		return

	_refresh_labels()
	preview_label.text = "Applied: %s" % _describe_mutation(_selected_mutation)
	_selected_mutation = {}
	apply_button.disabled = true


func _on_done_pressed() -> void:
	forge_complete.emit()


func _to_string_array(values: Array) -> Array[String]:
	var string_values: Array[String] = []
	for value in values:
		string_values.append(str(value))
	return string_values


func _apply_theme() -> void:
	theme = DiceforgeThemeScript.build()
	title_label.theme_type_variation = &"FacetTitle"
	summary_label.theme_type_variation = &"FacetSubtitle"
	dice_label.theme_type_variation = &"FacetBodyMuted"
	inventory_label.theme_type_variation = &"FacetBodyMuted"
	preview_label.theme_type_variation = &"FacetInfo"
	apply_button.theme_type_variation = &"FacetPrimaryButton"
	done_button.theme_type_variation = &"FacetTertiaryButton"


func _format_inventory_group(values: Array) -> String:
	var items := _to_string_array(values)
	if items.is_empty():
		return "None"
	return ", ".join(items)
