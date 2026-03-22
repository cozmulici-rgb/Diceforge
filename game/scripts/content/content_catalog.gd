class_name ContentCatalog
extends RefCounted

const ARCHETYPE_DIR := "res://content/archetypes"
const FLOOR_DIR := "res://content/floors"
const ROOM_DIR := "res://content/rooms"
const DICE_DIR := "res://content/dice"
const ENCOUNTER_DIR := "res://content/encounters"
const ENEMY_DIR := "res://content/enemies"
const REWARD_DIR := "res://content/rewards"
const EVENT_DIR := "res://content/events"
const SHOP_DIR := "res://content/shops"
const PROGRESSION_DIR := "res://content/progression"
const MODIFIER_DIR := "res://content/modifiers"
const MODE_DIR := "res://content/modes"
const ContentValidatorScript = preload("res://scripts/content/content_validator.gd")

var validator
var _loaded := false
var _archetypes: Dictionary = {}
var _floors: Dictionary = {}
var _room_graphs: Dictionary = {}
var _body_definitions: Dictionary = {}
var _face_definitions: Dictionary = {}
var _rune_definitions: Dictionary = {}
var _encounter_definitions: Dictionary = {}
var _enemy_definitions: Dictionary = {}
var _reward_definitions: Dictionary = {}
var _event_definitions: Dictionary = {}
var _shop_definitions: Dictionary = {}
var _unlock_definitions: Dictionary = {}
var _achievement_definitions: Dictionary = {}
var _curse_definitions: Dictionary = {}
var _blessing_definitions: Dictionary = {}
var _daily_mode_definitions: Dictionary = {}


func _init(content_validator = null) -> void:
	validator = content_validator if content_validator != null else ContentValidatorScript.new()


func ensure_loaded() -> Dictionary:
	if _loaded:
		return {"ok": true}

	_archetypes = _load_content_directory(ARCHETYPE_DIR)
	_floors = _load_content_directory(FLOOR_DIR)
	_room_graphs = _load_content_directory(ROOM_DIR)
	_body_definitions = _load_named_definitions("%s/bodies.json" % DICE_DIR)
	_face_definitions = _load_named_definitions("%s/faces.json" % DICE_DIR)
	_rune_definitions = _load_named_definitions("%s/runes.json" % DICE_DIR)
	_encounter_definitions = _load_named_definitions_directory(ENCOUNTER_DIR)
	_enemy_definitions = _load_named_definitions_directory(ENEMY_DIR)
	_reward_definitions = _load_named_definitions_directory(REWARD_DIR)
	_event_definitions = _load_named_definitions_directory(EVENT_DIR)
	_shop_definitions = _load_named_definitions_directory(SHOP_DIR)
	_unlock_definitions = _load_named_definitions("%s/unlocks.json" % PROGRESSION_DIR)
	_achievement_definitions = _load_named_definitions("%s/achievements.json" % PROGRESSION_DIR)
	_curse_definitions = _load_named_definitions("%s/curses.json" % MODIFIER_DIR)
	_blessing_definitions = _load_named_definitions("%s/blessings.json" % MODIFIER_DIR)
	_daily_mode_definitions = _load_named_definitions("%s/daily_void.json" % MODE_DIR)

	var validation: Dictionary = validator.validate_catalog({
		"archetypes": _archetypes,
		"floors": _floors,
		"room_graphs": _room_graphs,
		"body_definitions": _body_definitions,
		"face_definitions": _face_definitions,
		"rune_definitions": _rune_definitions,
		"encounter_definitions": _encounter_definitions,
		"enemy_definitions": _enemy_definitions,
		"reward_definitions": _reward_definitions,
		"event_definitions": _event_definitions,
		"shop_definitions": _shop_definitions,
		"unlock_definitions": _unlock_definitions,
		"achievement_definitions": _achievement_definitions,
		"curse_definitions": _curse_definitions,
		"blessing_definitions": _blessing_definitions,
		"daily_mode_definitions": _daily_mode_definitions,
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
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _encounter_definitions.has(id):
		return _missing_content("encounter", id)
	return (_encounter_definitions[id] as Dictionary).duplicate(true)


func load_room_graph(id: String) -> Variant:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _room_graphs.has(id):
		return _missing_content("room_graph", id)
	return (_room_graphs[id] as Dictionary).duplicate(true)


func load_reward_table(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _reward_definitions.has(id):
		return _missing_content("reward_table", id)
	return (_reward_definitions[id] as Dictionary).duplicate(true)


func load_event_definition(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _event_definitions.has(id):
		return _missing_content("event", id)
	return (_event_definitions[id] as Dictionary).duplicate(true)


func load_shop_definition(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _shop_definitions.has(id):
		return _missing_content("shop", id)
	return (_shop_definitions[id] as Dictionary).duplicate(true)


func load_part_definition(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if _body_definitions.has(id):
		return (_body_definitions[id] as Dictionary).duplicate(true)
	if _face_definitions.has(id):
		return (_face_definitions[id] as Dictionary).duplicate(true)
	if _rune_definitions.has(id):
		return (_rune_definitions[id] as Dictionary).duplicate(true)
	return _missing_content("part_definition", id)


func load_enemy_definition(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _enemy_definitions.has(id):
		return _missing_content("enemy", id)
	return (_enemy_definitions[id] as Dictionary).duplicate(true)


func load_modifier_definition(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if _curse_definitions.has(id):
		return (_curse_definitions[id] as Dictionary).duplicate(true)
	if _blessing_definitions.has(id):
		return (_blessing_definitions[id] as Dictionary).duplicate(true)
	return _missing_content("modifier", id)


func load_daily_mode_config(id: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return load_result
	if not _daily_mode_definitions.has(id):
		return _missing_content("daily_mode", id)
	return (_daily_mode_definitions[id] as Dictionary).duplicate(true)


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
	for modifier_id in state.get("modifiers", []):
		var modifier_definition = load_modifier_definition(str(modifier_id))
		if modifier_definition is Dictionary and modifier_definition.get("error", "") != "":
			return modifier_definition

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
		"body_definitions": _body_definitions.duplicate(true),
		"face_definitions": _face_definitions.duplicate(true),
		"rune_definitions": _rune_definitions.duplicate(true),
		"encounter_definitions": _encounter_definitions.duplicate(true),
		"enemy_definitions": _enemy_definitions.duplicate(true),
		"reward_definitions": _reward_definitions.duplicate(true),
		"event_definitions": _event_definitions.duplicate(true),
		"shop_definitions": _shop_definitions.duplicate(true),
		"unlock_definitions": _unlock_definitions.duplicate(true),
		"achievement_definitions": _achievement_definitions.duplicate(true),
		"curse_definitions": _curse_definitions.duplicate(true),
		"blessing_definitions": _blessing_definitions.duplicate(true),
		"daily_mode_definitions": _daily_mode_definitions.duplicate(true),
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


func get_part_definitions(part_type: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return {}

	if part_type == "body":
		return _body_definitions.duplicate(true)
	if part_type == "face":
		return _face_definitions.duplicate(true)
	if part_type == "rune":
		return _rune_definitions.duplicate(true)
	return {}


func get_progression_definitions(definition_type: String) -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return {}
	if definition_type == "unlock":
		return _unlock_definitions.duplicate(true)
	if definition_type == "achievement":
		return _achievement_definitions.duplicate(true)
	return {}


func get_modifier_definitions() -> Dictionary:
	var load_result := ensure_loaded()
	if not load_result.get("ok", false):
		return {}
	var definitions := _curse_definitions.duplicate(true)
	for modifier_id in _blessing_definitions.keys():
		definitions[modifier_id] = (_blessing_definitions[modifier_id] as Dictionary).duplicate(true)
	return definitions


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


func _load_named_definitions(path: String) -> Dictionary:
	var parsed: Dictionary = _load_json_file(path)
	var definitions: Dictionary = {}
	for definition in parsed.get("definitions", []):
		if definition is Dictionary and definition.has("id"):
			definitions[str(definition.get("id", ""))] = (definition as Dictionary).duplicate(true)
	return definitions


func _load_named_definitions_directory(base_path: String) -> Dictionary:
	var definitions: Dictionary = {}
	var dir := DirAccess.open(base_path)
	if dir == null:
		return definitions

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "%s/%s" % [base_path, file_name]
			var loaded_definitions := _load_named_definitions(path)
			for definition_id in loaded_definitions.keys():
				definitions[definition_id] = (loaded_definitions[definition_id] as Dictionary).duplicate(true)
		file_name = dir.get_next()
	dir.list_dir_end()
	return definitions


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
