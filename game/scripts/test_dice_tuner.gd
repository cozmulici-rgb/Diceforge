extends Control

const MOCK_ROLLS := [
	{"die_id": "d1", "body_id": "standard_d6",  "rolled_value": 6, "face_label": "Strike"},
	{"die_id": "d2", "body_id": "standard_d8",  "rolled_value": 8, "face_label": "Block"},
	{"die_id": "d3", "body_id": "standard_d20", "rolled_value": 14, "face_label": "Poison"},
	{"die_id": "d4", "body_id": "standard_d6",  "rolled_value": 3, "face_label": "Amplify"},
]

var _overlay


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.059, 0.078)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var overlay_script = load("res://scripts/combat/dice_roll_overlay.gd")
	_overlay = overlay_script.new()
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_TOP,    0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -8.0)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -(_overlay.strip_height + 8.0))
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	var title := Label.new()
	title.text = "Dice Roll Overlay Tuner"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	_add_separator(root_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_btn(btn_row, "Roll All",   _do_roll)
	_btn(btn_row, "Re-roll d1", func(): _do_reroll("d1"))
	_btn(btn_row, "Re-roll d2", func(): _do_reroll("d2"))
	_btn(btn_row, "Re-roll d3", func(): _do_reroll("d3"))
	_btn(btn_row, "Re-roll d4", func(): _do_reroll("d4"))
	root_vbox.add_child(btn_row)

	_add_separator(root_vbox)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	root_vbox.add_child(cols)

	var cam_col := _make_section(cols, "Camera")
	_spin(cam_col, "Height",   2.0,  20.0,  7.0, 0.5, func(v): _set_cam(func(c): c.position.y = v))
	_spin(cam_col, "Z Offset", 0.0,   6.0,  1.5, 0.1, func(v): _set_cam(func(c): c.position.z = v))
	_spin(cam_col, "Pitch",  -90.0,   0.0, -80.0, 1.0, func(v): _set_cam(func(c): c.rotation_degrees.x = v))
	_spin(cam_col, "FOV",      5.0, 100.0,  30.0, 1.0, func(v): _set_cam(func(c): c.fov = v))

	var anim_col := _make_section(cols, "Animation")
	_spin(anim_col, "Float H",   0.5, 10.0, 2.5,  0.1,  func(v): _overlay.float_height  = v)
	_spin(anim_col, "Float Dur", 0.1,  2.0, 0.35, 0.05, func(v): _overlay.float_duration = v)
	_spin(anim_col, "Spin Dur",  0.2,  4.0, 1.0,  0.05, func(v): _overlay.spin_duration  = v)
	_spin(anim_col, "Spin Rot",  0.5, 10.0, 2.5,  0.5,  func(v): _overlay.spin_rotations = v)
	_spin(anim_col, "Stagger",   0.0,  0.5, 0.08, 0.01, func(v): _overlay.stagger_delay  = v)
	_spin(anim_col, "Hold",      0.5,  5.0, 2.0,  0.25, func(v): _overlay.display_hold   = v)

	var scene_col := _make_section(cols, "Scene")
	_spin(scene_col, "Die Scale",  1.0,  20.0, 8.0,  0.5,  func(v): _overlay.die_visual_scale = v)
	_spin(scene_col, "Spacing",    1.0,   8.0, 3.2,  0.1,  func(v): _overlay.die_spacing      = v)
	_spin(scene_col, "Strip H",   80.0, 800.0, 300.0, 10.0, func(v): _overlay.resize_strip(v))

	_add_separator(root_vbox)

	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Press 'Roll All' to start."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(status)

	_overlay.roll_complete.connect(func(): _status("Roll complete."))


func _make_section(parent: HBoxContainer, title: String) -> VBoxContainer:
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 4)
	frame.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(frame)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	frame.add_child(lbl)
	_add_separator(frame)
	return frame


func _spin(parent: VBoxContainer, label: String, mn: float, mx: float, val: float, step: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 74
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = val
	spin.custom_minimum_size.x = 88
	spin.value_changed.connect(cb)
	row.add_child(spin)


func _btn(parent: HBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 36)
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_separator(parent: Control) -> void:
	parent.add_child(HSeparator.new())


func _status(msg: String) -> void:
	var lbl: Label = find_child("StatusLabel", true, false) as Label
	if lbl:
		lbl.text = msg


func _do_roll() -> void:
	_overlay.start_roll(MOCK_ROLLS)
	_status("Rolling...")


func _do_reroll(die_id: String) -> void:
	_overlay.trigger_reroll(die_id, randi_range(1, 20))
	_status("Re-rolling %s..." % die_id)


func _set_cam(mutate: Callable) -> void:
	if _overlay.camera != null:
		mutate.call(_overlay.camera)
