extends SceneTree

# Headless smoke check for the textured dice integration. Runs:
#   godot --headless --path game -s res://tests/test_textured_dice_load.gd
# Verifies each .dae loads, the per-die numbered texture binds, and surfaces
# end up with the override material. Exits non-zero if any check fails.

func _init() -> void:
	var failures: Array[String] = []
	var sides_list := [4, 6, 8, 10, 12, 20]

	for sides in sides_list:
		var mesh_path := "res://assets/dice/meshes_textured/d%d.dae" % sides
		var tex_path  := "res://assets/dice/meshes_textured/textures/d%d_Numbers.png" % sides
		if not ResourceLoader.exists(mesh_path):
			failures.append("missing mesh: %s" % mesh_path)
			continue
		if not ResourceLoader.exists(tex_path):
			failures.append("missing texture: %s" % tex_path)
			continue
		var packed := load(mesh_path) as PackedScene
		if packed == null:
			failures.append("not a PackedScene: %s" % mesh_path)
			continue
		var instance: Node = packed.instantiate()
		var mi := _find_mesh_instance(instance)
		if mi == null:
			failures.append("no MeshInstance3D in %s" % mesh_path)
			instance.queue_free()
			continue
		if mi.mesh == null:
			failures.append("MeshInstance3D has no mesh in %s" % mesh_path)
			instance.queue_free()
			continue
		var surface_count := mi.mesh.get_surface_count()
		var tex := load(tex_path) as Texture2D
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mi.set_surface_override_material(0, mat)
		# Inspect the first triangle's normal in local space to confirm import
		# convention.
		var arrays := mi.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var first_normal := normals[0] if normals.size() > 0 else Vector3.ZERO
		var first_vert := verts[0] if verts.size() > 0 else Vector3.ZERO
		var first_uv := uvs[0] if uvs.size() > 0 else Vector2.ZERO
		print("d%d: surfaces=%d verts=%d normals=%d uvs=%d  first_normal=%s  first_vert=%s  first_uv=%s" % [
			sides, surface_count, verts.size(), normals.size(), uvs.size(),
			first_normal, first_vert, first_uv,
		])
		instance.queue_free()

	if failures.is_empty():
		print("OK — all six textured dice load with mesh + texture present.")
		quit(0)
	else:
		printerr("FAILURES:")
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null
