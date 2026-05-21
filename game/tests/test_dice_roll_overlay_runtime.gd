extends SceneTree

# Unit-style smoke check: instantiate DiceRollOverlay (without entering tree),
# verify _landing_rotation_for_entry returns a valid flat-face orientation
# (some face of the unit cube ends up aligned with world UP, though *which*
# face is intentionally random — rolled_value no longer determines it), and
# verify _load_visual_textured returns a valid Node3D with a MeshInstance3D
# + override material.

const OverlayScript := preload("res://scripts/combat/dice_roll_overlay.gd")


func _init() -> void:
	var overlay := OverlayScript.new()

	var fails: Array[String] = []

	# --- d6 random landing always rests on some face ---
	# Apply the returned rotation and verify at least one of the 6 face
	# directions ends up approximately at world +Y (i.e. the die isn't tilted
	# on an edge or vertex). The specific face is random and unrelated to
	# rolled_value.
	for value in [1, 2, 3, 4, 5, 6]:
		var entry := {"body_id": "standard_d6", "rolled_value": value, "die_id": "test"}
		overlay.use_textured_meshes = true
		overlay.set_rng_seed(value)
		var euler: Vector3 = overlay._landing_rotation_for_entry(entry)
		var basis := Basis.from_euler(Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z)))
		var best := -2.0
		for face_local in overlay._D6_FACE_UP_DIRS.values():
			var dot: float = (basis * (face_local as Vector3)).dot(Vector3.UP)
			if dot > best:
				best = dot
		print("d6 trial value=%d euler=%s best_face_dot_up=%f" % [value, euler, best])
		if best < 0.99:
			fails.append("d6 trial %d did not land on a flat face (best dot=%f)" % [value, best])

	# --- consecutive trials produce different orientations (non-determinism) ---
	overlay.set_rng_seed(42)
	var seen := {}
	for i in range(20):
		var entry := {"body_id": "standard_d6", "rolled_value": 1, "die_id": "t"}
		var euler: Vector3 = overlay._landing_rotation_for_entry(entry)
		var key := "%d,%d,%d" % [int(round(euler.x)), int(round(euler.y)), int(round(euler.z))]
		seen[key] = true
	if seen.size() < 3:
		fails.append("expected varied landing orientations across trials, got %d unique" % seen.size())

	# --- non-d6 returns a finite rotation without crashing ---
	for sides in [4, 8, 10, 12, 20]:
		var entry := {"body_id": "standard_d%d" % sides, "rolled_value": 1, "die_id": "t"}
		overlay.use_textured_meshes = true
		var euler: Vector3 = overlay._landing_rotation_for_entry(entry)
		if not is_finite(euler.x):
			fails.append("d%d landing produced non-finite euler" % sides)

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
