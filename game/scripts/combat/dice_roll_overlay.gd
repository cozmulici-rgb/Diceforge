class_name DiceRollOverlay
extends CanvasLayer

signal roll_complete

# Tuneable at runtime
var strip_height: float     = 530.0
var die_visual_scale: float = 6.0
var die_spacing: float      = 2.0
var float_height: float     = 3.7
var spin_rotations: float   = 5.5    # target spin rate scale; turns per first airborne arc
var stagger_delay: float    = 0.08
# Real-dice physics tunables. Driven each frame via _process so the motion is
# a proper ballistic integration (gravity + multi-bounce decay + single-axis
# tumble), instead of a tween chain. See research notes in the PR description.
var gravity: float = 120.0              # world units / s². Cannon-es tutorial uses ~50; 120 reads as a heavier die.
var restitution: float = 0.55           # coefficient of restitution on landing (real dice ≈ 0.3–0.6).
var angular_damping: float = 0.6        # fraction of spin retained after each bounce.
var max_bounces: int = 4                # hard cap; physical dice usually rest within 2–4 bounces.
var min_bounce_height: float = 0.05     # in world units; below this we settle instead of bouncing.
var settle_duration: float = 0.1        # SLERP from current basis → face-up orientation on final landing.
var texture_lightness: float = 1.0
var texture_normal_scale: float = 1.2
var material_roughness: float = 0.35
var material_metallic: float = 0.15
var material_specular: float = 0.6
var sun_energy: float = 1.6
var fill_energy: float = 0.35
var ambient_energy: float = 0.9
var ambient_lightness: float = 1.0

# Camera lens. When orthographic is true, FOV is ignored and the camera uses
# Camera3D.PROJECTION_ORTHOGONAL with `camera_ortho_size` as the visible
# vertical extent (in world units). Useful for an icon-style top-down look
# without perspective foreshortening.
var camera_orthographic: bool = false
var camera_ortho_size: float = 12.0

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


var _pending_count: int = 0


func _ready() -> void:
	layer = 10
	_rng.randomize()
	_build_scene()
	hide()
	set_process(true)


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
	_apply_camera_projection()
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
		_pending_count += 1
		_init_die_anim(entry, 0.0, func(): _show_label(entry))
		break


# ── Animation (ballistic integration) ──────────────────────────────────────────
#
# Each die has its own physics state stored under entry["anim"]. The state is
# stepped every frame in _process(): vertical velocity is integrated against
# gravity, the die rotates around a single random angular-momentum axis, and on
# each ground contact the velocity is multiplied by `restitution` (coefficient
# of restitution) and the angular speed by `angular_damping`. After max_bounces
# (or once a predicted bounce would be too small) the die slerps from its
# current chaotic basis into a random face-up landing basis over
# settle_duration. This mirrors how a real die behaves: ballistic free-fall,
# multiple decaying bounces, and a brief settling tumble at rest.

func _begin_animation() -> void:
	var count := _die_entries.size()
	if count == 0:
		return
	_pending_count = count
	for i in range(count):
		var entry: Dictionary = _die_entries[i]
		var delay := i * stagger_delay
		_init_die_anim(entry, delay, func(): _show_label(entry))


func _init_die_anim(entry: Dictionary, delay: float, on_done: Callable) -> void:
	var die_node: Node3D = entry["node"] as Node3D
	die_node.position.y = 0.0
	# Pre-launch: give each die a random resting orientation so the strip looks
	# varied while staggered dice are still waiting their turn.
	var pre_basis := Basis.from_euler(Vector3(
		_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU
	))
	die_node.transform.basis = pre_basis
	entry["anim"] = {
		"delay": delay,
		"active": false,
		"settling": false,
		"settle_t": 0.0,
		"settle_from": pre_basis,
		"final_basis": Basis(),
		"vy": 0.0,
		"axis": Vector3.UP,
		"spin": 0.0,
		"basis": pre_basis,
		"bounce_index": 0,
		"on_done": on_done,
		"finished": false,
	}


func _kick_die(entry: Dictionary) -> void:
	var die_node: Node3D = entry["node"] as Node3D
	var anim: Dictionary = entry["anim"] as Dictionary
	# Initial upward velocity required to reach float_height under gravity:
	# v0 = sqrt(2 * g * h)  (classic kinematic, since v² = u² - 2gh and v=0 at apex)
	var v0 := sqrt(2.0 * maxf(gravity, 0.001) * maxf(float_height, 0.0))
	# Angular momentum direction: a single uniformly random unit vector. Real
	# rigid-body rotation in free fall is around one axis, not three.
	var axis := _random_unit_vector()
	# Spin rate: scale spin_rotations into rad/sec so the first arc covers
	# roughly that many full turns. Randomize ±30% so dice don't all tumble at
	# the same rate.
	var airtime := 2.0 * v0 / maxf(gravity, 0.001)
	var spin_rate := TAU * spin_rotations * _rng.randf_range(0.7, 1.3) / maxf(airtime, 0.001)
	var final_euler := _landing_rotation_for_entry(entry)
	var final_basis := Basis.from_euler(Vector3(
		deg_to_rad(final_euler.x), deg_to_rad(final_euler.y), deg_to_rad(final_euler.z)
	))
	anim["vy"] = v0
	anim["axis"] = axis
	anim["spin"] = spin_rate
	anim["basis"] = die_node.transform.basis
	anim["final_basis"] = final_basis
	anim["bounce_index"] = 0
	anim["active"] = true


func _process(delta: float) -> void:
	if _die_entries.is_empty():
		return
	for entry in _die_entries:
		_step_die(entry, delta)


func _step_die(entry: Dictionary, delta: float) -> void:
	var anim_v = entry.get("anim")
	if anim_v == null:
		return
	var anim: Dictionary = anim_v as Dictionary
	if bool(anim.get("finished", false)):
		return
	var die_node = entry.get("node")
	if die_node == null or not is_instance_valid(die_node):
		anim["finished"] = true
		return
	var node: Node3D = die_node as Node3D

	# Stagger countdown — kick the die as soon as its delay reaches zero.
	# Includes delay == 0 on the very first step (the lead die in the strip).
	if not bool(anim["active"]) and not bool(anim["settling"]):
		anim["delay"] -= delta
		if anim["delay"] <= 0.0:
			_kick_die(entry)
		else:
			return

	# Final slerp into resting face-up orientation
	if bool(anim["settling"]):
		anim["settle_t"] += delta
		var dur := maxf(settle_duration, 0.0001)
		var t: float = clampf(anim["settle_t"] / dur, 0.0, 1.0)
		# slerp() casts to Quaternion internally and requires orthonormal bases;
		# accumulated float drift from the spin can denormalize them, so re-
		# orthonormalize first to avoid "Basis must be normalized" spam.
		var from_b: Basis = (anim["settle_from"] as Basis).orthonormalized()
		var to_b: Basis = (anim["final_basis"] as Basis).orthonormalized()
		node.transform.basis = from_b.slerp(to_b, t)
		node.position.y = 0.0
		if t >= 1.0:
			anim["settling"] = false
			anim["finished"] = true
			(anim["on_done"] as Callable).call()
			_pending_count -= 1
			if _pending_count <= 0:
				_on_all_done()
		return

	if not bool(anim["active"]):
		return

	# Ballistic integration: vy -= g*dt, y += vy*dt
	anim["vy"] -= gravity * delta
	node.position.y += anim["vy"] * delta

	# Single-axis tumble around the angular-momentum direction.
	var basis: Basis = anim["basis"] as Basis
	basis = basis.rotated(anim["axis"] as Vector3, (anim["spin"] as float) * delta)
	anim["basis"] = basis
	node.transform.basis = basis

	# Ground contact
	if node.position.y <= 0.0 and anim["vy"] < 0.0:
		node.position.y = 0.0
		var rebound_v: float = -(anim["vy"] as float) * restitution
		var next_bounce_h: float = (rebound_v * rebound_v) / (2.0 * maxf(gravity, 0.001))
		var bounces: int = anim["bounce_index"] as int
		if bounces >= max_bounces or next_bounce_h < min_bounce_height:
			anim["active"] = false
			anim["settling"] = true
			anim["settle_t"] = 0.0
			anim["settle_from"] = basis
		else:
			anim["bounce_index"] = bounces + 1
			anim["vy"] = rebound_v
			anim["spin"] = (anim["spin"] as float) * angular_damping


func _random_unit_vector() -> Vector3:
	# Marsaglia-style uniform on the unit sphere.
	var theta := _rng.randf() * TAU
	var z := _rng.randf_range(-1.0, 1.0)
	var r := sqrt(maxf(1.0 - z * z, 0.0))
	return Vector3(r * cos(theta), z, r * sin(theta))


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

	# Skip the Decal in textured mode so it doesn't double-stamp the baked numeral.
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


func _landing_rotation_for_entry(_entry: Dictionary) -> Vector3:
	# Landing orientation is intentionally non-deterministic: the visual face
	# that ends up on top is independent of the gameplay rolled_value. This
	# matches a real die toss where the resting orientation is random; the
	# gameplay outcome is shown via the digit label / Decal, not the mesh face.
	return _random_landing_rotation()


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


func refresh_camera() -> void:
	if camera != null:
		_apply_camera_projection()


func _apply_camera_projection() -> void:
	if camera == null:
		return
	if camera_orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = camera_ortho_size
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


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
