class_name ContentCatalog
extends RefCounted

const ARCHETYPE_DIR := "res://content/archetypes"
const FLOOR_DIR := "res://content/floors"
const ROOM_DIR := "res://content/rooms"
const ContentValidatorScript = preload("res://scripts/content/content_validator.gd")

var validator
var _loaded := false
var _archetypes: Dictionary = {}
var _floors: Dictionary = {}
var _room_graphs: Dictionary = {}


func _init(content_validator = null) -> void:
	validator = content_validator if content_validator != null else ContentValidatorScript.new()


func ensure_loaded() -> Dictionary:
	if _loaded:
		return {"ok": true}

	_archetypes = _load_content_directory(ARCHETYPE_DIR)
	_floors = _load_content_directory(FLOOR_DIR)
	_room_graphs = _load_content_directory(ROOM_DIR)

	var validation: Dictionary = validator.validate_catalog({
		"archetypes": _archetypes,
		"floors": _floors,
		"room_graphs": _room_graphs,
	})

	if not validation.get("ok", false):
		return {
			"ok": false,
			"error": "content_validation_failed",
			"errors": validation.get("errors", []),
		}

	_loaded = true
	return {"ok": true}


func load_archetype(id: String) -> Variant:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _archetypes.has(id):
		return _missing_content("archetype", id)
	return (_archetypes[id] as Dictionary).duplicate(true)


func load_floor_template(id: String) -> Variant:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _floors.has(id):
		return _missing_content("floor", id)
	return (_floors[id] as Dictionary).duplicate(true)


func load_encounter(id: String) -> Dictionary:
	return _missing_content("encounter", id)


func load_room_graph(id: String) -> Variant:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _room_graphs.has(id):
		return _missing_content("room_graph", id)
	return (_room_graphs[id] as Dictionary).duplicate(true)


func load_reward_table(id: String) -> Dictionary:
	return _missing_content("reward_table", id)


func load_part_definition(id: String) -> Dictionary:
	return _missing_content("part_definition", id)


func validate_saved_state(state: Dictionary) -> Dictionary:
	var archetype_id := str(state.get("archetype_id", ""))
	if archetype_id == "":
		return {
			"ok": false,
			"error": "missing_archetype_id",
		}

	var archetype = load_archetype(archetype_id)
	if archetype is Dictionary and archetype.get("error", "") != "":
		return archetype

	return {"ok": true}


func validate_all_content() -> Dictionary:
	return ensure_loaded()


func get_all_content() -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result

	return {
		"archetypes": _archetypes.duplicate(true),
		"floors": _floors.duplicate(true),
		"room_graphs": _room_graphs.duplicate(true),
	}


func list_archetypes() -> Array:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return []

	var archetypes: Array = []
	for archetype_id in _archetypes.keys():
		archetypes.append((_archetypes[archetype_id] as Dictionary).duplicate(true))

	archetypes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", a.get("id", ""))) < str(b.get("name", b.get("id", "")))
	)

	return archetypes


func _load_content_directory(base_path: String) -> Dictionary:
	var content: Dictionary = {}
	var dir := DirAccess.open(base_path)
	if dir == null:
		return content

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := "%s/%s" % [base_path, file_name]
			var parsed: Dictionary = _load_json_file(full_path)
			if parsed.has("id"):
				content[str(parsed["id"])] = parsed
		file_name = dir.get_next()
	dir.list_dir_end()

	return content


func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var raw_text := file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return {}

	return parsed


func _missing_content(content_type: String, id: String) -> Dictionary:
	return {
		"ok": false,
		"error": "missing_content",
		"content_type": content_type,
		"id": id,
	}
