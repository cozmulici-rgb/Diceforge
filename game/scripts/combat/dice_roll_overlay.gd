class_name DiceRollOverlay
extends CanvasLayer

signal roll_complete

const SETTLE_THRESHOLD := 0.06
const SETTLE_DURATION  := 0.7
const DISPLAY_HOLD     := 1.4

var _viewport: SubViewport
var _die_bodies: Array = []
var _settle_timer := 0.0
var _settled := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 10
	_rng.randomize()
	_build_scene()
	hide()
	set_process(false)


func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vp_container := SubViewportContainer.new()
	vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	add_child(vp_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	vp_container.add_child(_viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 7.0, 9.0)
	camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.6
	_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -130.0, 0.0)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.38)
	env.ambient_light_energy = 0.9
	world_env.environment = env
	_viewport.add_child(world_env)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30.0, 0.2, 30.0)
	floor_col.shape = floor_box
	floor_col.position.y = -0.1
	floor_body.add_child(floor_col)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.06, 0.08, 0.12)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	_viewport.add_child(floor_body)


func start_roll(roll_data: Array) -> void:
	_clear_dice()
	_die_bodies.clear()
	_settled = false
	_settle_timer = 0.0

	var count := roll_data.size()
	for i in range(count):
		var entry: Dictionary = roll_data[i] as Dictionary
		var body_id := str(entry.get("body_id", "standard_d6"))
		var sides   := _sides_from_body_id(body_id)
		var x_pos   := _spread_x(i, count)
		var start   := Vector3(x_pos, 5.0 + _rng.randf_range(0.0, 1.5), _rng.randf_range(-0.5, 0.5))

		var rigid := _spawn_die(sides, start)
		_viewport.add_child(rigid)

		rigid.linear_velocity = Vector3(
			_rng.randf_range(-1.5, 1.5),
			_rng.randf_range(-0.5, 0.5),
			_rng.randf_range(-1.0, 1.0)
		)
		rigid.angular_velocity = Vector3(
			_rng.randf_range(-12.0, 12.0),
			_rng.randf_range(-12.0, 12.0),
			_rng.randf_range(-12.0, 12.0)
		)

		_die_bodies.append({
			"rigid_body":  rigid,
			"die_id":      str(entry.get("die_id", "")),
			"rolled_value": int(entry.get("rolled_value", 1)),
			"face_label":  str(entry.get("face_label", "")),
		})

	show()
	set_process(true)


func trigger_reroll(die_id: String, new_value: int) -> void:
	for entry in _die_bodies:
		if str(entry["die_id"]) != die_id:
			continue
		entry["rolled_value"] = new_value
		var rb: RigidBody3D = entry["rigid_body"] as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			break
		for child in rb.get_children():
			if child is Label3D:
				child.queue_free()
		rb.freeze = false
		rb.linear_velocity = Vector3(
			_rng.randf_range(-2.0, 2.0),
			4.0,
			_rng.randf_range(-1.0, 1.0)
		)
		rb.angular_velocity = Vector3(
			_rng.randf_range(-14.0, 14.0),
			_rng.randf_range(-14.0, 14.0),
			_rng.randf_range(-14.0, 14.0)
		)
		_settled = false
		_settle_timer = 0.0
		break


func _process(delta: float) -> void:
	if _settled:
		return

	var all_still := true
	for entry in _die_bodies:
		var rb: RigidBody3D = entry["rigid_body"] as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		if rb.linear_velocity.length() > SETTLE_THRESHOLD or rb.angular_velocity.length() > SETTLE_THRESHOLD:
			all_still = false
			break

	if all_still:
		_settle_timer += delta
		if _settle_timer >= SETTLE_DURATION:
			_on_settled()
	else:
		_settle_timer = 0.0


func _on_settled() -> void:
	_settled = true
	_freeze_all()
	_show_result_labels()
	await get_tree().create_timer(DISPLAY_HOLD).timeout
	hide()
	set_process(false)
	roll_complete.emit()


func _freeze_all() -> void:
	for entry in _die_bodies:
		var rb: RigidBody3D = entry["rigid_body"] as RigidBody3D
		if rb != null and is_instance_valid(rb):
			rb.freeze = true


func _show_result_labels() -> void:
	for entry in _die_bodies:
		var rb: RigidBody3D = entry["rigid_body"] as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		var lbl := Label3D.new()
		lbl.text = str(int(entry["rolled_value"]))
		lbl.font_size = 72
		lbl.modulate = Color(1.0, 0.88, 0.25)
		lbl.outline_size = 6
		lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = Vector3(0.0, 1.0, 0.0)
		rb.add_child(lbl)


func _clear_dice() -> void:
	for child in _viewport.get_children():
		if child is RigidBody3D:
			child.queue_free()


func _spawn_die(sides: int, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = position
	body.mass = 1.0
	body.physics_material_override = _make_physics_material()

	var col := CollisionShape3D.new()
	col.shape = _collision_shape_for(sides)
	body.add_child(col)

	var mesh_path := "res://assets/dice/meshes/d%d.glb" % sides
	if ResourceLoader.exists(mesh_path):
		var packed := load(mesh_path) as PackedScene
		if packed != null:
			var visual := packed.instantiate()
			body.add_child(visual)
			return body

	# Fallback: solid-colour box
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.9, 0.9)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.36, 0.72)
	mat.roughness = 0.4
	mat.metallic = 0.3
	mi.material_override = mat
	body.add_child(mi)
	return body


func _collision_shape_for(sides: int) -> Shape3D:
	match sides:
		4:
			# Rough tetrahedron approximation via sphere
			var s := SphereShape3D.new()
			s.radius = 0.52
			return s
		8, 10, 12:
			var s := SphereShape3D.new()
			s.radius = 0.56
			return s
		20:
			var s := SphereShape3D.new()
			s.radius = 0.60
			return s
		_:  # d6 and unknown
			var s := BoxShape3D.new()
			s.size = Vector3(0.9, 0.9, 0.9)
			return s


func _make_physics_material() -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.28
	mat.friction = 0.7
	return mat


func _spread_x(index: int, total: int) -> float:
	if total <= 1:
		return 0.0
	var span := float(total - 1) * 1.8
	return -span / 2.0 + index * 1.8


func _sides_from_body_id(body_id: String) -> int:
	var rx := RegEx.new()
	rx.compile("d(\\d+)")
	var m := rx.search(body_id)
	if m:
		return int(m.get_string(1))
	return 6
