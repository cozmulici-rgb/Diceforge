extends SceneTree

# Unit-style smoke check: instantiate DiceRollOverlay (without entering tree),
# verify the deterministic d6 landing rotation produces a sensible Basis for
# each face value, and verify _load_visual_textured returns a valid Node3D
# with a MeshInstance3D + override material.

const OverlayScript := preload("res://scripts/combat/dice_roll_overlay.gd")


func _init() -> void:
	var overlay := OverlayScript.new()

	# --- d6 deterministic landing ---
	# Apply each rotation to the face-up direction and verify the result
	# is approximately +Y world.
	var fails: Array[String] = []
	for value in [1, 2, 3, 4, 5, 6]:
		var entry := {"body_id": "standard_d6", "rolled_value": value, "die_id": "test"}
		overlay.use_textured_meshes = true
		overlay.set_rng_seed(value)  # deterministic Y spin
		var euler: Vector3 = overlay._landing_rotation_for_entry(entry)
		var basis := Basis.from_euler(Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z)))
		var face_local: Vector3 = overlay._D6_FACE_UP_DIRS[value]
		var face_world: Vector3 = basis * face_local
		var dot := face_world.dot(Vector3.UP)
		print("d6 value=%d euler=%s face_world=%s dot_up=%f" % [value, euler, face_world, dot])
		if dot < 0.99:
			fails.append("d6 value=%d does not land face-up (dot=%f)" % [value, dot])

	# --- non-d6 falls back to random rotation without crashing ---
	for sides in [4, 8, 10, 12, 20]:
		var entry := {"body_id": "standard_d%d" % sides, "rolled_value": 1, "die_id": "t"}
		overlay.use_textured_meshes = true
		var euler: Vector3 = overlay._landing_rotation_for_entry(entry)
		if not is_finite(euler.x):
			fails.append("d%d random fallback produced non-finite euler" % sides)

	# --- textured loader returns valid scene per die ---
	for sides in [4, 6, 8, 10, 12, 20]:
		var v: Node3D = overlay._load_visual_textured(sides)
		if v == null:
			fails.append("d%d loader returned null" % sides)
			continue
		var mi := _find_mi(v)
		if mi == null:
			fails.append("d%d has no MeshInstance3D" % sides)
		elif mi.get_surface_override_material(0) == null:
			fails.append("d%d surface override material not set" % sides)
		v.queue_free()

	if fails.is_empty():
		print("OK — all assertions pass.")
		quit(0)
	else:
		printerr("FAILURES:")
		for f in fails:
			printerr("  - ", f)
		quit(1)


func _find_mi(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mi(child)
		if found != null:
			return found
	return null
