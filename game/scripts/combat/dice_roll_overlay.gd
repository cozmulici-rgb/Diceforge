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
var texture_lightness: float = 1.0
var texture_normal_scale: float = 1.2
var material_roughness: float = 0.35
var material_metallic: float = 0.15
var material_specular: float = 0.6
var sun_energy: float = 1.6
var fill_energy: float = 0.35
var ambient_energy: float = 0.9
var ambient_lightness: float = 1.0

# Debug: when true, _load_visual() always returns a BoxMesh fallback,
# skipping the .glb mesh lookup. Used by test_dice_tuner for side-by-side
# render-path comparison. Leave false in production.
var force_box_fallback: bool = false

# Debug: when true, _make_dice_material() strips the diffuse texture and
# normal map, leaving only the base albedo color + roughness/metallic.
# Lets you compare raw mesh geometry without the texture confounding the eye.
# Leave false in production.
var use_plain_debug_material: bool = false

# When true, dice are loaded from assets/dice/meshes_textured/ (OpenGameArt
# CC0 pack with per-die numbered UV-mapped textures) and the rolled digit is
# placed by rotating the die so the matching face lands up — no Decal overlay.
# When false (default), keeps the legacy dice-box meshes + procedural atlas +
# Decal overlay path.
var use_textured_meshes: bool = false

var camera: Camera3D
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var world_environment: WorldEnvironment

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

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	sun_light.light_energy = sun_energy
	_viewport.add_child(sun_light)

	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20.0, -130.0, 0.0)
	fill_light.light_energy = fill_energy
	fill_light.shadow_enabled = false
	_viewport.add_child(fill_light)

	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = _ambient_color()
	env.ambient_light_energy = ambient_energy
	world_environment.environment = env
	_viewport.add_child(world_environment)


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
			"body_id":      str(entry.get("body_id", "")),
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
	var final_rotation := _landing_rotation_for_entry(entry)
	var spin_x := 360.0 * spin_rotations * _random_spin_direction()
	var spin_y := 360.0 * spin_rotations * _random_spin_direction()
	var spin_z := 360.0 * spin_rotations * _random_spin_direction()
	# Float down starts early enough to land exactly when spin ends.
	var down_start := maxf(delay + float_duration, delay + spin_duration - float_duration)
	var end_time   := delay + spin_duration

	var tw := get_tree().create_tween()
	tw.set_parallel(true)

	# Float up
	tw.tween_property(die_node, "position:y", float_height, float_duration) \
	  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(delay)

	# Spin all axes, then settle into a random face-up orientation.
	tw.tween_property(die_node, "rotation_degrees:x", final_rotation.x + spin_x, spin_duration * 0.55) \
	  .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay)
	tw.tween_property(die_node, "rotation_degrees:y", final_rotation.y + spin_y, spin_duration * 0.55) \
	  .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay)
	tw.tween_property(die_node, "rotation_degrees:z", final_rotation.z + spin_z, spin_duration * 0.55) \
	  .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay)

	tw.tween_property(die_node, "rotation_degrees", final_rotation, spin_duration * 0.45) \
	  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(delay + spin_duration * 0.55)

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

	# When using textured meshes the numerals are baked into the UV-mapped faces.
	# d6 lands deterministically via _D6_FACE_UP_DIRS so the rolled face is up;
	# other dice still land randomly and would benefit from their own tables.
	# Either way the Decal would double-stamp on top of the baked numeral, so we
	# always skip it in textured mode — bake-only is the design intent.
	if use_textured_meshes:
		return

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

	# ── Project the digit onto the die surface with a Decal ──────────────────
	# Decal projects along local -Y, painting the texture onto any geometry
	# inside its bounding box — the number appears as part of the die surface.
	var decal := Decal.new()
	decal.texture_albedo = sv.get_texture()
	var face := die_visual_scale * 0.85
	# size: XZ covers the face, Y depth spans top-face region
	decal.size = Vector3(face, die_visual_scale * 0.5, face)
	# Centre the decal just above the top face so projection hits it cleanly
	decal.position = Vector3(0.0, die_visual_scale * 0.6, 0.0)
	decal.albedo_mix = 1.0
	decal.lower_fade = 0.0
	decal.upper_fade = 0.0
	node.add_child(decal)
	decal.global_position = node.global_position + Vector3(0.0, die_visual_scale * 0.6, 0.0)
	decal.global_rotation = Vector3.ZERO
	entry["label"] = decal


func _random_spin_direction() -> float:
	return 1.0 if _rng.randf() > 0.5 else -1.0


func _random_landing_rotation() -> Vector3:
	var face_rotations := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(90.0, 0.0, 0.0),
		Vector3(180.0, 0.0, 0.0),
		Vector3(270.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 90.0),
		Vector3(0.0, 0.0, 270.0),
	]
	var rotation: Vector3 = face_rotations[_rng.randi_range(0, face_rotations.size() - 1)]
	rotation.y = float(_rng.randi_range(0, 3)) * 90.0
	return rotation


# When using textured meshes, rotate the die so the rolled face lands up.
# Tables below describe each die's local-space outward normal for face value N
# (in the imported Godot mesh's frame — Z-up DAE imports become Y-up here).
#
# Only d6 is mapped end-to-end so far; other die types fall through to random
# landing until their per-face UV→numeral table is built and verified.
const _D6_FACE_UP_DIRS := {
	1: Vector3( 0.0,  1.0,  0.0),
	2: Vector3( 1.0,  0.0,  0.0),
	3: Vector3( 0.0,  0.0,  1.0),
	4: Vector3( 0.0,  0.0, -1.0),
	5: Vector3(-1.0,  0.0,  0.0),
	6: Vector3( 0.0, -1.0,  0.0),
}


func _landing_rotation_for_entry(entry: Dictionary) -> Vector3:
	if not use_textured_meshes:
		return _random_landing_rotation()
	var sides := _sides_from_body_id(str(entry.get("body_id", "")))
	var value := int(entry.get("rolled_value", 1))
	var landing = _deterministic_landing_basis(sides, value)
	if landing == null:
		return _random_landing_rotation()
	# Compose with a random Y-spin (around world vertical) so consecutive rolls
	# don't all face the same compass direction. Spin applied AFTER landing so
	# the rolled face remains up regardless of die topology.
	var spin_y := float(_rng.randi_range(0, 3)) * 90.0
	var spin_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(spin_y), 0.0))
	var final_basis: Basis = spin_basis * (landing as Basis)
	return final_basis.get_euler() * (180.0 / PI)


func _deterministic_landing_basis(sides: int, value: int):
	# Returns a Basis aligning face `value` upward, or null if no table exists.
	if sides == 6 and _D6_FACE_UP_DIRS.has(value):
		return _basis_aligning(_D6_FACE_UP_DIRS[value], Vector3.UP)
	return null


func _basis_aligning(from_dir: Vector3, to_dir: Vector3) -> Basis:
	from_dir = from_dir.normalized()
	to_dir = to_dir.normalized()
	if from_dir.is_equal_approx(to_dir):
		return Basis()
	if from_dir.is_equal_approx(-to_dir):
		var axis := Vector3.RIGHT if absf(from_dir.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
		return Basis(axis, PI)
	var axis2 := from_dir.cross(to_dir).normalized()
	var angle := acos(clampf(from_dir.dot(to_dir), -1.0, 1.0))
	return Basis(axis2, angle)


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
	if use_textured_meshes:
		var textured := _load_visual_textured(sides)
		if textured != null:
			return textured
	var mat := _make_dice_material(body_id)
	if not force_box_fallback:
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


func _load_visual_textured(sides: int) -> Node3D:
	# OpenGameArt CC0 dice pack: per-die .dae meshes with UV-mapped numbered
	# textures. Numerals are baked into the texture; do NOT use material_override
	# (which would clobber UVs by replacing the entire material at runtime).
	# Instead, set surface_0 material so it composites with the mesh's own UVs.
	var mesh_path := "res://assets/dice/meshes_textured/d%d.dae" % sides
	if not ResourceLoader.exists(mesh_path):
		return null
	var packed := load(mesh_path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var mat := _make_textured_material(sides)
	_apply_textured_material_recursive(instance, mat)
	return instance


func _make_textured_material(sides: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _scaled_color(Color(1.0, 1.0, 1.0), texture_lightness)
	mat.roughness = material_roughness
	mat.metallic = material_metallic
	mat.metallic_specular = material_specular

	if use_plain_debug_material:
		# Skip numeral texture so the raw mesh shape is visible.
		mat.albedo_color = _scaled_color(Color(0.7, 0.72, 0.78), texture_lightness)
		return mat

	var tex_path := "res://assets/dice/meshes_textured/textures/d%d_Numbers.png" % sides
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		# The numbered textures are 2048x2048 white-on-grey; keep filtering smooth.
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _apply_textured_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n := mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in range(n):
			mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_textured_material_recursive(child, mat)


func _make_dice_material(body_id: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _scaled_color(_base_color_for_body(body_id), texture_lightness)
	mat.roughness = material_roughness
	mat.metallic = material_metallic
	mat.metallic_specular = material_specular

	if use_plain_debug_material:
		return mat

	var use_light := body_id.contains("bone") or body_id.contains("crystal")
	var diffuse_path := "res://assets/dice/diffuse-%s.png" % ("light" if use_light else "dark")
	if ResourceLoader.exists(diffuse_path):
		mat.albedo_texture = load(diffuse_path)

	var normal_path := "res://assets/dice/normal.png"
	if ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
		mat.normal_scale = texture_normal_scale

	return mat


func _base_color_for_body(body_id: String) -> Color:
	if body_id.contains("bone"):
		return Color(0.95, 0.90, 0.78)
	if body_id.contains("crystal"):
		return Color(0.55, 0.80, 1.00)
	if body_id.contains("flesh"):
		return Color(0.85, 0.38, 0.32)
	if body_id.contains("heavy"):
		return Color(0.32, 0.32, 0.38)
	if body_id.contains("void"):
		return Color(0.22, 0.12, 0.42)
	return Color(0.55, 0.62, 0.90)


func _scaled_color(color: Color, lightness: float) -> Color:
	return Color(
		clampf(color.r * lightness, 0.0, 1.0),
		clampf(color.g * lightness, 0.0, 1.0),
		clampf(color.b * lightness, 0.0, 1.0),
		color.a
	)


func _ambient_color() -> Color:
	return _scaled_color(Color(0.28, 0.30, 0.42), ambient_lightness)


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


func set_strip_rect(rect: Rect2) -> void:
	if _vp_container == null:
		return
	_vp_container.position = rect.position
	_vp_container.size = rect.size
	if _viewport != null:
		_viewport.size = Vector2i(int(rect.size.x), int(rect.size.y))
	strip_height = rect.size.y


func refresh_materials() -> void:
	for entry in _die_entries:
		var visual: Node = entry.get("visual") as Node
		if visual == null or not is_instance_valid(visual):
			continue
		if use_textured_meshes:
			var body_id := str(entry.get("body_id", ""))
			var sides := _sides_from_body_id(body_id)
			_apply_textured_material_recursive(visual, _make_textured_material(sides))
		else:
			_apply_material_recursive(visual, _make_dice_material(str(entry.get("body_id", ""))))


func refresh_lighting() -> void:
	if sun_light != null:
		sun_light.light_energy = sun_energy
	if fill_light != null:
		fill_light.light_energy = fill_energy
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_color = _ambient_color()
		world_environment.environment.ambient_light_energy = ambient_energy


func set_rng_seed(seed: int) -> void:
	_rng.seed = seed
