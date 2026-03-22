extends Control

signal forge_complete()

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var dice_label: Label = $MarginContainer/VBoxContainer/DiceLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var mutation_container: VBoxContainer = $MarginContainer/VBoxContainer/MutationContainer
@onready var preview_label: Label = $MarginContainer/VBoxContainer/PreviewLabel
@onready var apply_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ApplyButton
@onready var done_button: Button = $MarginContainer/VBoxContainer/ButtonRow/DoneButton

var _coordinator
var _forge_state: Dictionary = {}
var _selected_mutation: Dictionary = {}


func _ready() -> void:
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
	_refresh_labels()
	preview_label.text = "Select a mutation to preview it."
	apply_button.disabled = true

	for child in mutation_container.get_children():
		child.queue_free()

	for mutation in _build_candidate_mutations():
		var button := Button.new()
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
		die_summaries.append("%s[%s]: %s" % [
			str(die.get("id", "")),
			str(die.get("body_id", "standard_d6")),
			", ".join(face_labels),
		])
	dice_label.text = "Active Dice: %s" % " | ".join(die_summaries)

	var inventory: Dictionary = _coordinator.current_session.inventory
	inventory_label.text = "Spares B/F/R: %s / %s / %s" % [
		", ".join(_to_string_array(inventory.get("bodies", []))),
		", ".join(_to_string_array(inventory.get("faces", []))),
		", ".join(_to_string_array(inventory.get("runes", []))),
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
	return "%s %s on %s (%s)" % [
		str(mutation.get("operation", "")),
		str(mutation.get("part_id", "")),
		str(mutation.get("target_die_id", "")),
		str(mutation.get("slot_id", "")),
	]


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
