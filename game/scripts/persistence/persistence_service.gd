class_name PersistenceService
extends RefCounted

const SaveSchemaScript = preload("res://scripts/persistence/save_schema.gd")
const SaveSlotSummaryScript = preload("res://scripts/persistence/save_slot_summary.gd")

var content_catalog
var save_schema
var base_path: String


func _init(catalog = null, base_path_override: String = "user://diceforge") -> void:
	content_catalog = catalog
	save_schema = SaveSchemaScript.new()
	base_path = base_path_override.trim_suffix("/")
	_ensure_directories()


func save_run_state(slot_id: String, run_state: Dictionary) -> Dictionary:
	var validation = save_schema.validate_run_state(run_state, content_catalog)
	if not validation.get("ok", false):
		return {"ok": false, "error": "invalid_run_state", "errors": validation.get("errors", [])}

	var path := _run_slot_path(slot_id)
	return _write_json(path, run_state)


func load_run_state(slot_id: String) -> Dictionary:
	var path := _run_slot_path(slot_id)
	var payload = _read_json(path)
	if not payload.get("ok", false):
		return payload
	var validation = save_schema.validate_run_state(payload.get("data", {}), content_catalog)
	if not validation.get("ok", false):
		return {"ok": false, "error": "invalid_run_state", "errors": validation.get("errors", [])}
	return {"ok": true, "data": payload.get("data", {})}


func save_meta_state(meta_state: Dictionary) -> Dictionary:
	var validation = save_schema.validate_meta_state(meta_state)
	if not validation.get("ok", false):
		return {"ok": false, "error": "invalid_meta_state", "errors": validation.get("errors", [])}
	return _write_json(_meta_state_path(), meta_state)


func load_meta_state() -> Dictionary:
	var path := _meta_state_path()
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_meta_state"}
	var payload = _read_json(path)
	if not payload.get("ok", false):
		return payload
	var validation = save_schema.validate_meta_state(payload.get("data", {}))
	if not validation.get("ok", false):
		return {"ok": false, "error": "invalid_meta_state", "errors": validation.get("errors", [])}
	return {"ok": true, "data": payload.get("data", {})}


func delete_run_state(slot_id: String) -> Dictionary:
	var path := _run_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {"ok": true}
	return {"ok": DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK}


func delete_meta_state() -> Dictionary:
	var path := _meta_state_path()
	if not FileAccess.file_exists(path):
		return {"ok": true}
	return {"ok": DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK}


func list_run_slots() -> Array:
	_ensure_directories()
	var summaries: Array = []
	var dir := DirAccess.open("%s/runs" % base_path)
	if dir == null:
		return summaries
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var slot_id := file_name.trim_suffix(".json")
			var path := _run_slot_path(slot_id)
			var read_result = _read_json(path)
			if not read_result.get("ok", false):
				summaries.append(SaveSlotSummaryScript.new({
					"slot_id": slot_id,
					"is_corrupt": true,
				}).to_dictionary())
			else:
				var data: Dictionary = read_result.get("data", {})
				summaries.append(SaveSlotSummaryScript.new({
					"slot_id": slot_id,
					"session_id": str(data.get("session_id", "")),
					"archetype_id": str(data.get("archetype_id", "")),
					"display_name": str(data.get("display_name", "")),
					"floor_index": int(data.get("floor_index", 0)),
					"room_id": str(data.get("current_room_id", "")),
					"updated_at_unix": int(data.get("updated_at_unix", Time.get_unix_time_from_system())),
					"is_corrupt": not save_schema.validate_run_state(data, content_catalog).get("ok", false),
				}).to_dictionary())
		file_name = dir.get_next()
	dir.list_dir_end()
	return summaries


func _ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/runs" % base_path))


func run_slot_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(_run_slot_path(slot_id))


func _run_slot_path(slot_id: String) -> String:
	return "%s/runs/%s.json" % [base_path, slot_id]


func _meta_state_path() -> String:
	return "%s/meta_state.json" % base_path


func _write_json(path: String, payload: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "write_failed", "path": path}
	file.store_string(JSON.stringify(payload, "\t"))
	return {"ok": true, "path": path}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_file", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "read_failed", "path": path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "invalid_json", "path": path}
	return {"ok": true, "data": parsed}
