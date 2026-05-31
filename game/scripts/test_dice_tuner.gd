extends Control

const MOCK_ROLLS := [
	{"die_id": "d1", "body_id": "standard_d6",  "rolled_value": 6, "face_label": "Strike"},
	{"die_id": "d2", "body_id": "standard_d8",  "rolled_value": 8, "face_label": "Block"},
	{"die_id": "d3", "body_id": "standard_d20", "rolled_value": 14, "face_label": "Poison"},
	{"die_id": "d4", "body_id": "standard_d6",  "rolled_value": 3, "face_label": "Amplify"},
]

var _overlay_mesh: DiceRollOverlay
var _overlay_textured: DiceRollOverlay
var _strip_envelope: float = 530.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.059, 0.078)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var overlay_script = load("res://scripts/combat/dice_roll_overlay.gd")
	_overlay_mesh = overlay_script.new()
	_overlay_textured  = overlay_script.new()
	_overlay_textured.use_textured_meshes = true
	# Polished-gold-on-obsidian metal look matching the reference dice set:
	# the recolored d{N}_Numbers.png supply gold numerals + engraving filigree,
	# so push metalness up and roughness down for a wet metallic sheen.
	_overlay_textured.material_metallic = 0.55
	_overlay_textured.material_roughness = 0.45
	_overlay_textured.material_specular = 0.5
	# Readable framing defaults. The dice meshes are normalized to ~unit
	# circumradius, so die_visual_scale is roughly the on-screen die radius in
	# world units. At the current camera (Y≈11.5, pitch −67°, FOV 50) one strip
	# is 1470×265 px ≈ 20 px/world-unit, so scale 3.5 → a ~7-unit (~140 px) die:
	# big enough to read the baked numeral, small enough to fit the strip height.
	# Spacing 8 spreads the four dice across the width without overlap.
	# NOTE: the SpinBox callbacks below only fire on user change (they connect
	# after value is set), so these properties must be assigned here to take
	# effect at startup — the spinbox `val` args are kept in sync for display.
	for ov in [_overlay_mesh, _overlay_textured]:
		ov.die_visual_scale = 3.5
		ov.die_spacing = 8.0
	add_child(_overlay_mesh)
	add_child(_overlay_textured)
	_layout_strip(_strip_envelope)

	var panel := PanelContainer.new()
	panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_TOP,    0.0,  8.0)
	panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -8.0)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -(_strip_envelope + 8.0))
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	var title := Label.new()
	title.text = "Dice Roll Overlay Tuner — top strip: legacy dice-box meshes (atlas + Decal); bottom strip: OpenGameArt textured (CC0)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(title)

	_add_separator(root_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_btn(btn_row, "Roll All",   _do_roll)
	_btn(btn_row, "Re-roll d1", func(): _do_reroll("d1"))
	_btn(btn_row, "Re-roll d2", func(): _do_reroll("d2"))
	_btn(btn_row, "Re-roll d3", func(): _do_reroll("d3"))
	_btn(btn_row, "Re-roll d4", func(): _do_reroll("d4"))

	var plain_toggle := CheckButton.new()
	plain_toggle.text = "Plain material"
	plain_toggle.toggled.connect(func(pressed: bool):
		_overlay_mesh.use_plain_debug_material = pressed
		_overlay_textured.use_plain_debug_material = pressed
		_overlay_mesh.refresh_materials()
		_overlay_textured.refresh_materials())
	btn_row.add_child(plain_toggle)

	root_vbox.add_child(btn_row)

	_add_separator(root_vbox)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	root_vbox.add_child(cols)

	var cols_2 := HBoxContainer.new()
	cols_2.add_theme_constant_override("separation", 18)
	root_vbox.add_child(cols_2)

	var cam_col := _make_section(cols, "Camera")
	_spin(cam_col, "X",      -8.0,   8.0,   0.0, 0.1, func(v): _set_cam(func(c): c.position.x = v))
	_spin(cam_col, "Height",  2.0,  20.0,  11.5, 0.5, func(v): _set_cam(func(c): c.position.y = v))
	_spin(cam_col, "Z",      -4.0,   8.0,   3.4, 0.1, func(v): _set_cam(func(c): c.position.z = v))
	_spin(cam_col, "Pitch", -90.0,   0.0, -67.0, 1.0, func(v): _set_cam(func(c): c.rotation_degrees.x = v))
	_spin(cam_col, "Yaw",   -45.0,  45.0,   0.0, 1.0, func(v): _set_cam(func(c): c.rotation_degrees.y = v))
	_spin(cam_col, "Roll",  -45.0,  45.0,   0.0, 1.0, func(v): _set_cam(func(c): c.rotation_degrees.z = v))
	_spin(cam_col, "FOV",     5.0, 100.0,  50.0, 1.0, func(v): _set_cam(func(c): c.fov = v))
	_spin(cam_col, "Near",  0.005,   2.0,  0.05, 0.005, func(v): _set_cam(func(c): c.near = v))
	_spin(cam_col, "Far",    20.0, 500.0, 400.0, 5.0, func(v): _set_cam(func(c): c.far = v))

	var ortho_row := HBoxContainer.new()
	ortho_row.add_theme_constant_override("separation", 6)
	cam_col.add_child(ortho_row)
	var ortho_lbl := Label.new()
	ortho_lbl.text = "Ortho"
	ortho_lbl.custom_minimum_size.x = 64
	ortho_row.add_child(ortho_lbl)
	var ortho_btn := CheckButton.new()
	ortho_btn.toggled.connect(func(pressed: bool):
		_overlay_mesh.camera_orthographic = pressed
		_overlay_textured.camera_orthographic = pressed
		_overlay_mesh.refresh_camera()
		_overlay_textured.refresh_camera())
	ortho_row.add_child(ortho_btn)
	_spin(cam_col, "Ortho Sz", 1.0, 40.0, 12.0, 0.5, func(v):
		_overlay_mesh.camera_ortho_size = v
		_overlay_textured.camera_ortho_size = v
		_overlay_mesh.refresh_camera()
		_overlay_textured.refresh_camera())

	var anim_col := _make_section(cols, "Animation")
	_spin(anim_col, "Float H",   0.5, 10.0, 3.7,  0.1,  func(v):
		_overlay_mesh.float_height  = v
		_overlay_textured.float_height   = v)
	_spin(anim_col, "Gravity",  10.0, 400.0, 120.0, 5.0, func(v):
		_overlay_mesh.gravity = v
		_overlay_textured.gravity = v)
	_spin(anim_col, "Spin Rot",  0.5, 10.0, 5.5,  0.5,  func(v):
		_overlay_mesh.spin_rotations = v
		_overlay_textured.spin_rotations  = v)
	_spin(anim_col, "Stagger",   0.0,  0.5, 0.08, 0.01, func(v):
		_overlay_mesh.stagger_delay  = v
		_overlay_textured.stagger_delay   = v)
	_spin(anim_col, "Restitut",  0.0,  0.95, 0.55, 0.05, func(v):
		_overlay_mesh.restitution = v
		_overlay_textured.restitution = v)
	_spin(anim_col, "Ang Damp",  0.0,  1.0, 0.6,  0.05, func(v):
		_overlay_mesh.angular_damping = v
		_overlay_textured.angular_damping = v)
	_spin(anim_col, "Max Bnce",  1.0,  10.0, 4.0,  1.0,  func(v):
		_overlay_mesh.max_bounces = int(v)
		_overlay_textured.max_bounces = int(v))
	_spin(anim_col, "Settle",    0.0,  0.5, 0.1,  0.02, func(v):
		_overlay_mesh.settle_duration = v
		_overlay_textured.settle_duration = v)

	var scene_col := _make_section(cols, "Scene")
	_spin(scene_col, "Die Scale",  1.0,  20.0,  3.5, 0.5,  func(v):
		_overlay_mesh.die_visual_scale = v
		_overlay_textured.die_visual_scale  = v)
	_spin(scene_col, "Spacing",    0.5,  16.0,  8.0, 0.1,  func(v):
		_overlay_mesh.die_spacing      = v
		_overlay_textured.die_spacing       = v)
	_spin(scene_col, "Strip H",   80.0, 800.0, 530.0, 10.0, func(v):
		_layout_strip(v))

	var texture_col := _make_section(cols_2, "Texture")
	_spin(texture_col, "Light",  0.2, 2.0, 1.0,  0.05, func(v): _set_material("texture_lightness", v))
	_spin(texture_col, "Normal", 0.0, 3.0, 1.2,  0.1,  func(v): _set_material("texture_normal_scale", v))
	_spin(texture_col, "Rough",  0.0, 1.0, 0.35, 0.05, func(v): _set_material("material_roughness", v))
	_spin(texture_col, "Metal",  0.0, 1.0, 0.15, 0.05, func(v): _set_material("material_metallic", v))
	_spin(texture_col, "Spec",   0.0, 1.0, 0.6,  0.05, func(v): _set_material("material_specular", v))

	var light_col := _make_section(cols_2, "Lighting")
	_spin(light_col, "Sun",    0.0, 5.0, 1.6,  0.1,  func(v): _set_light("sun_energy", v))
	_spin(light_col, "Fill",   0.0, 3.0, 0.35, 0.05, func(v): _set_light("fill_energy", v))
	_spin(light_col, "Ambient", 0.0, 3.0, 0.9,  0.05, func(v): _set_light("ambient_energy", v))
	_spin(light_col, "Amb Lit", 0.2, 2.0, 1.0,  0.05, func(v): _set_light("ambient_lightness", v))

	_add_separator(root_vbox)

	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Press 'Roll All' to start."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(status)

	_overlay_mesh.roll_complete.connect(func(): _status("Roll complete."))


func _layout_strip(strip_h: float) -> void:
	_strip_envelope = strip_h
	var screen := get_viewport().get_visible_rect().size
	var half := strip_h / 2.0
	var top_y := screen.y - strip_h
	_overlay_mesh.set_strip_rect(Rect2(0.0, top_y,        screen.x, half))
	_overlay_textured.set_strip_rect( Rect2(0.0, top_y + half, screen.x, half))


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
	lbl.custom_minimum_size.x = 64
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = val
	spin.custom_minimum_size.x = 84
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
	var roll_seed := randi()
	_overlay_mesh.set_rng_seed(roll_seed)
	_overlay_textured.set_rng_seed(roll_seed)
	_overlay_mesh.start_roll(MOCK_ROLLS)
	_overlay_textured.start_roll(MOCK_ROLLS)
	_status("Rolling...")


func _do_reroll(die_id: String) -> void:
	var new_value := randi_range(1, 20)
	var roll_seed := randi()
	_overlay_mesh.set_rng_seed(roll_seed)
	_overlay_textured.set_rng_seed(roll_seed)
	_overlay_mesh.trigger_reroll(die_id, new_value)
	_overlay_textured.trigger_reroll(die_id, new_value)
	_status("Re-rolling %s..." % die_id)


func _set_cam(mutate: Callable) -> void:
	if _overlay_mesh.camera != null:
		mutate.call(_overlay_mesh.camera)
	if _overlay_textured.camera != null:
		mutate.call(_overlay_textured.camera)


func _set_material(prop_name: String, value: float) -> void:
	_overlay_mesh.set(prop_name, value)
	_overlay_textured.set(prop_name, value)
	_overlay_mesh.refresh_materials()
	_overlay_textured.refresh_materials()


func _set_light(prop_name: String, value: float) -> void:
	_overlay_mesh.set(prop_name, value)
	_overlay_textured.set(prop_name, value)
	_overlay_mesh.refresh_lighting()
	_overlay_textured.refresh_lighting()
