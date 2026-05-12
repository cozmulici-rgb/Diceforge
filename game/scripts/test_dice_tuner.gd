extends Control

const MOCK_ROLLS := [
	{"die_id": "d1", "body_id": "standard_d6", "rolled_value": 5, "face_label": "Strike"},
	{"die_id": "d2", "body_id": "standard_d8", "rolled_value": 3, "face_label": "Block"},
	{"die_id": "d3", "body_id": "standard_d20", "rolled_value": 14, "face_label": "Poison"},
	{"die_id": "d4", "body_id": "standard_d6", "rolled_value": 2, "face_label": "Amplify"},
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

	# Panel fills screen above the dice strip
	var panel := PanelContainer.new()
	panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_TOP,    0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -8.0)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -(_overlay.strip_height + 8.0))
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Dice Roll Overlay Tuner"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	_add_separator(root_vbox)

	# ── Roll buttons ──────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_btn(btn_row, "Roll All",      _do_roll)
	_btn(btn_row, "Re-roll d1",    func(): _do_reroll("d1"))
	_btn(btn_row, "Re-roll d2",    func(): _do_reroll("d2"))
	_btn(btn_row, "Re-roll d3",    func(): _do_reroll("d3"))
	_btn(btn_row, "Re-roll d4",    func(): _do_reroll("d4"))
	root_vbox.add_child(btn_row)

	_add_separator(root_vbox)

	# ── Parameter columns ─────────────────────────────────────────────────────
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	root_vbox.add_child(cols)

	# Camera column
	var cam_col := _make_section(cols, "Camera")
	_spin(cam_col, "Pos X",     -10,  10,  0.0,  0.1, func(v): _set_cam(func(c): c.position.x = v))
	_spin(cam_col, "Pos Y",     -5,   15,  3.0,  0.1, func(v): _set_cam(func(c): c.position.y = v))
	_spin(cam_col, "Pos Z",      0,   20,  5.5,  0.1, func(v): _set_cam(func(c): c.position.z = v))
	_spin(cam_col, "Pitch °",  -90,    0, -28.0, 0.5, func(v): _set_cam(func(c): c.rotation_degrees.x = v))
	_spin(cam_col, "Yaw °",    -45,   45,  0.0,  0.5, func(v): _set_cam(func(c): c.rotation_degrees.y = v))
	_spin(cam_col, "FOV °",      5,  120, 25.0,  0.5, func(v): _set_cam(func(c): c.fov = v))

	# Scene / spawn column
	var scene_col := _make_section(cols, "Scene / Spawn")
	_spin(scene_col, "Die Scale",  0.5, 30.0, 5.0,   0.1, _set_die_scale)
	_spin(scene_col, "Spawn Y",    0.0, 15.0, 4.0,   0.1, func(v): _overlay.set(&"spawn_y", v))
	_spin(scene_col, "Spawn Z",   -3.0,  6.0, 1.0,   0.1, func(v): _overlay.set(&"spawn_z", v))
	_spin(scene_col, "Strip H",  80.0, 800.0, 260.0, 10.0, func(v): _overlay.resize_strip(v))

	# Physics column
	var phys_col := _make_section(cols, "Physics")
	_spin(phys_col, "Bounce",   0.0, 1.0,  0.25, 0.01, func(v): _set_physics(v, null))
	_spin(phys_col, "Friction", 0.0, 2.0,  0.75, 0.01, func(v): _set_physics(null, v))
	_spin(phys_col, "Lin Vel",  0.0, 8.0,  1.0,  0.1,  func(v): _overlay.set(&"_lin_vel_scale", v))
	_spin(phys_col, "Ang Vel",  0.0, 30.0, 12.0, 0.5,  func(v): _overlay.set(&"_ang_vel_scale", v))

	_add_separator(root_vbox)

	# Status label
	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Press 'Roll All' to start."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(status)

	_overlay.roll_complete.connect(func(): _status("Roll complete — dice settled."))


# ── Helpers ───────────────────────────────────────────────────────────────────

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
	lbl.custom_minimum_size.x = 80
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = val
	spin.custom_minimum_size.x = 90
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


# ── Actions ───────────────────────────────────────────────────────────────────

func _do_roll() -> void:
	_overlay.start_roll(MOCK_ROLLS)
	_status("Rolling…")


func _do_reroll(die_id: String) -> void:
	_overlay.trigger_reroll(die_id, randi_range(1, 20))
	_status("Re-rolling %s…" % die_id)


# ── Live setters ──────────────────────────────────────────────────────────────

func _set_cam(mutate: Callable) -> void:
	if _overlay.camera != null:
		mutate.call(_overlay.camera)


func _set_die_scale(v: float) -> void:
	_overlay.die_visual_scale = v
	for entry in _overlay._die_bodies:
		var vis: Node3D = entry.get("visual_node") as Node3D
		if vis != null and is_instance_valid(vis) and not (vis is CollisionShape3D) and not (vis is Label3D):
			vis.scale = Vector3(v, v, v)


var _bounce: float = 0.25
var _friction: float = 0.75

func _set_physics(bounce, friction) -> void:
	if bounce != null:
		_bounce = bounce
	if friction != null:
		_friction = friction
	for entry in _overlay._die_bodies:
		var rb: RigidBody3D = entry.get("rigid_body") as RigidBody3D
		if rb != null and is_instance_valid(rb):
			var mat := PhysicsMaterial.new()
			mat.bounce = _bounce
			mat.friction = _friction
			rb.physics_material_override = mat
