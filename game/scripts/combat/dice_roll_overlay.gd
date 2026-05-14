class_name DiceRollOverlay
extends CanvasLayer

signal roll_complete

# Tuneable at runtime
var strip_height: float     = 530.0
var die_visual_scale: float = 6.0
var die_spacing: float      = 2.0
var float_height: float     = 3.7
var float_duration: float   = 0.25
var spin_duration: float    = 0.3
var spin_rotations: float   = 5.5
var stagger_delay: float    = 0.08

var camera: Camera3D

var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _die_entries: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 10
	_rng.randomize()
	_build_scene()
	hide()


func _build_scene() -> void:
	var screen := get_viewport().get_visible_rect().size

	_vp_container = SubViewportContainer.new()
	_vp_container.position = Vector2(0.0, screen.y - strip_height)
	_vp_container.size     = Vector2(screen.x, strip_height)
	_vp_container.stretch  = true
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(screen.x), int(strip_height))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	_vp_container.add_child(_viewport)

	# Near top-down camera: high Y, very slight Z offset, steep pitch
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 11.5, 3.4)
	camera.rotation_degrees = Vector3(-67.0, 0.0, 0.0)
	camera.fov = 50.0
	_viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	sun.light_energy = 1.6
	_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -130.0, 0.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.28, 0.30, 0.42)
	env.ambient_light_energy = 0.9
	world_env.environment = env
	_viewport.add_child(world_env)


func start_roll(roll_data: Array) -> void:
	_clear_dice()
	_die_entries.clear()

	var count := roll_data.size()
	for i in range(count):
		var entry := roll_data[i] as Dictionary
		var sides  := _sides_from_body_id(str(entry.get("body_id", "standard_d6")))
		var x_pos  := _spread_x(i, count)

		var die_node := Node3D.new()
		die_node.position = Vector3(x_pos, 0.0, 0.0)
		_viewport.add_child(die_node)

		var visual := _load_visual(sides, str(entry.get("body_id", "")))
		visual.scale = Vector3(die_visual_scale, die_visual_scale, die_visual_scale)
		die_node.add_child(visual)

		_die_entries.append({
			"node":         die_node,
			"visual":       visual,
			"die_id":       str(entry.get("die_id", "")),
			"rolled_value": int(entry.get("rolled_value", 1)),
			"face_label":   str(entry.get("face_label", "")),
		})

	show()
	_begin_animation()


func trigger_reroll(die_id: String, new_value: int) -> void:
	for entry in _die_entries:
		if str(entry["die_id"]) != die_id:
			continue
		entry["rolled_value"] = new_value
		var e: Dictionary = entry
		_animate_single(e, 0.0, func(): _show_label(e))
		break


# ── Animation ──────────────────────────────────────────────────────────────────

func _begin_animation() -> void:
	var count := _die_entries.size()
	if count == 0:
		return
	var done := [0]
	for i in range(count):
		var entry: Dictionary = _die_entries[i]
		var delay := i * stagger_delay
		var e: Dictionary = entry
		_animate_single(e, delay, func():
			_show_label(e)
			done[0] += 1
			if done[0] >= count:
				_on_all_done()
		)


func _animate_single(entry: Dictionary, delay: float, on_done: Callable) -> void:
	var die_node: Node3D = entry["node"] as Node3D
	var spin_dir  := 1.0 if _rng.randf() > 0.5 else -1.0
	var spin_deg  := 360.0 * spin_rotations * spin_dir
	# Float down starts early enough to land exactly when spin ends.
	var down_start := maxf(delay + float_duration, delay + spin_duration - float_duration)
	var end_time   := delay + spin_duration

	var tw := get_tree().create_tween()
	tw.set_parallel(true)

	# Float up
	tw.tween_property(die_node, "position:y", float_height, float_duration) \
	  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(delay)

	# Spin Y only — vertical axis never tilts
	tw.tween_property(die_node, "rotation_degrees:y",
	                  die_node.rotation_degrees.y + spin_deg, spin_duration) \
	  .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay)

	# Float down — lands at same XZ, Y=0
	tw.tween_property(die_node, "position:y", 0.0, float_duration) \
	  .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(down_start)

	tw.tween_callback(on_done).set_delay(end_time)


func _on_all_done() -> void:
	roll_complete.emit()
	# Overlay stays visible; start_roll() or an explicit hide() call dismisses it.


# ── Helpers ────────────────────────────────────────────────────────────────────

func _show_label(entry: Dictionary) -> void:
	# Clean up any previous label plane + its backing viewport
	var old_plane: Node = entry.get("label") as Node
	if old_plane != null and is_instance_valid(old_plane):
		old_plane.queue_free()
	var old_sv: SubViewport = entry.get("label_sv") as SubViewport
	if old_sv != null and is_instance_valid(old_sv):
		old_sv.queue_free()

	var node: Node3D = entry["node"] as Node3D
	var value := int(entry["rolled_value"])

	# ── Render the digit into a tiny 2D viewport ──────────────────────────────
	var sv := SubViewport.new()
	sv.size = Vector2i(256, 256)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var lbl := Label.new()
	lbl.text = str(value)
	lbl.add_theme_font_size_override("font_size", 190)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(256.0, 256.0)
	sv.add_child(lbl)
	add_child(sv)
	entry["label_sv"] = sv

	# Wait two frames so the viewport flushes at least one rendered frame
	await get_tree().process_frame
	await get_tree().process_frame
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED

	if not is_instance_valid(node):
		sv.queue_free()
		return

	# ── Glue a flat plane onto the die top face using the rendered digit ───────
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = sv.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var face := die_visual_scale * 0.72
	pm.size = Vector2(face, face)
	mi.mesh = pm
	mi.material_override = mat
	# PlaneMesh faces +Y by default; sit it just above the top face
	mi.position = Vector3(0.0, die_visual_scale * 0.5, 0.0)
	node.add_child(mi)
	entry["label"] = mi


func _clear_dice() -> void:
	for entry in _die_entries:
		var node = entry.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
		var label: Node = entry.get("label") as Node
		if label != null and is_instance_valid(label):
			label.queue_free()
		var sv: SubViewport = entry.get("label_sv") as SubViewport
		if sv != null and is_instance_valid(sv):
			sv.queue_free()


func _load_visual(sides: int, body_id: String = "") -> Node3D:
	var mat := _make_dice_material(body_id)
	var mesh_path := "res://assets/dice/meshes/d%d.glb" % sides
	if ResourceLoader.exists(mesh_path):
		var packed := load(mesh_path) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			_apply_material_recursive(instance, mat)
			return instance
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.9, 0.9)
	mi.mesh = bm
	mi.material_override = mat
	return mi


func _make_dice_material(body_id: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()

	var use_light := body_id.contains("bone") or body_id.contains("crystal")
	var diffuse_path := "res://assets/dice/diffuse-%s.png" % ("light" if use_light else "dark")
	if ResourceLoader.exists(diffuse_path):
		mat.albedo_texture = load(diffuse_path)

	if body_id.contains("bone"):
		mat.albedo_color = Color(0.95, 0.90, 0.78)
	elif body_id.contains("crystal"):
		mat.albedo_color = Color(0.55, 0.80, 1.00)
	elif body_id.contains("flesh"):
		mat.albedo_color = Color(0.85, 0.38, 0.32)
	elif body_id.contains("heavy"):
		mat.albedo_color = Color(0.32, 0.32, 0.38)
	elif body_id.contains("void"):
		mat.albedo_color = Color(0.22, 0.12, 0.42)
	else:
		mat.albedo_color = Color(0.55, 0.62, 0.90)

	var normal_path := "res://assets/dice/normal.png"
	if ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
		mat.normal_scale = 1.2

	mat.roughness = 0.35
	mat.metallic = 0.15
	mat.metallic_specular = 0.6
	return mat


func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _spread_x(index: int, total: int) -> float:
	if total <= 1:
		return 0.0
	var span := float(total - 1) * die_spacing
	return -span / 2.0 + index * die_spacing


func _sides_from_body_id(body_id: String) -> int:
	var rx := RegEx.new()
	rx.compile("d(\\d+)")
	var m := rx.search(body_id)
	if m:
		return int(m.get_string(1))
	return 6


func resize_strip(new_height: float) -> void:
	strip_height = new_height
	var screen := get_viewport().get_visible_rect().size
	_vp_container.position.y = screen.y - new_height
	_vp_container.size.y = new_height
	_viewport.size.y = int(new_height)
