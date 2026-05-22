class_name ContinueRunsDialog
extends AcceptDialog

const DiceforgeThemeScript = preload("res://scripts/ui/diceforge_theme.gd")

signal resume_requested(slot_id: String)
signal rename_requested(slot_id: String, new_name: String)
signal delete_requested(slot_id: String)

const TEXT_PRIMARY := Color("e7e3da")
const TEXT_DIM := Color("73808d")
const ACCENT_BRIGHT := Color("6ebeff")
const ERROR_COLOR := Color("d97070")

var _list_container: VBoxContainer
var _empty_label: Label
var _summaries: Array = []
var _editing_slot_id: String = ""


func _init() -> void:
	title = "Continue Run"
	min_size = Vector2(560, 420)
	dialog_hide_on_ok = true
	get_ok_button().text = "Close"


func _ready() -> void:
	theme = DiceforgeThemeScript.build()
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)

	_empty_label = Label.new()
	_empty_label.text = "No saved runs."
	_empty_label.add_theme_color_override("font_color", TEXT_DIM)
	_empty_label.visible = false
	root.add_child(_empty_label)


func configure(summaries: Array) -> void:
	_summaries = summaries.duplicate(true)
	_editing_slot_id = ""
	_rebuild()


func _rebuild() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	if _summaries.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for entry in _summaries:
		_list_container.add_child(_make_row(entry as Dictionary))


func _make_row(summary: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var slot_id: String = str(summary.get("slot_id", ""))
	var is_corrupt: bool = bool(summary.get("is_corrupt", false))
	var display_name: String = str(summary.get("display_name", ""))
	if display_name == "":
		display_name = slot_id
	var archetype: String = str(summary.get("archetype_id", ""))
	var floor_index: int = int(summary.get("floor_index", 0))
	var room_id: String = str(summary.get("room_id", ""))
	var updated_unix: int = int(summary.get("updated_at_unix", 0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	if _editing_slot_id == slot_id and not is_corrupt:
		var line_edit := LineEdit.new()
		line_edit.text = display_name
		line_edit.placeholder_text = "Run name"
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.text_submitted.connect(func(value: String):
			_editing_slot_id = ""
			rename_requested.emit(slot_id, value))
		line_edit.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
					_editing_slot_id = ""
					line_edit.get_viewport().set_input_as_handled()
					_rebuild())
		info.add_child(line_edit)
		line_edit.grab_focus.call_deferred()
	else:
		var name_label := Label.new()
		name_label.text = display_name
		name_label.add_theme_color_override("font_color", ERROR_COLOR if is_corrupt else TEXT_PRIMARY)
		info.add_child(name_label)

	var detail_text: String = ""
	if is_corrupt:
		detail_text = "Save data is corrupt."
	else:
		detail_text = "%s · Floor %d · Room %s · %s" % [
			archetype if archetype != "" else "unknown archetype",
			floor_index,
			room_id if room_id != "" else "?",
			_format_relative_time(updated_unix),
		]
	var detail_label := Label.new()
	detail_label.text = detail_text
	detail_label.add_theme_color_override("font_color", TEXT_DIM)
	info.add_child(detail_label)

	if not is_corrupt:
		var resume_btn := Button.new()
		resume_btn.text = "Resume"
		resume_btn.pressed.connect(func():
			hide()
			resume_requested.emit(slot_id))
		hbox.add_child(resume_btn)

		var rename_btn := Button.new()
		rename_btn.text = "Rename"
		rename_btn.pressed.connect(func():
			_editing_slot_id = slot_id
			_rebuild())
		hbox.add_child(rename_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func():
		_confirm_delete(slot_id, display_name))
	hbox.add_child(delete_btn)

	return row


func _confirm_delete(slot_id: String, name_for_message: String) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete save?"
	confirm.dialog_text = "Delete \"%s\"? This cannot be undone." % name_for_message
	add_child(confirm)
	confirm.confirmed.connect(func():
		delete_requested.emit(slot_id)
		confirm.queue_free())
	confirm.canceled.connect(func():
		confirm.queue_free())
	confirm.popup_centered()


func _format_relative_time(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "unknown time"
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = max(0, now - unix_seconds)
	if delta < 60:
		return "just now"
	if delta < 3600:
		return "%d minutes ago" % int(delta / 60.0)
	if delta < 86400:
		return "%d hours ago" % int(delta / 3600.0)
	return "%d days ago" % int(delta / 86400.0)
