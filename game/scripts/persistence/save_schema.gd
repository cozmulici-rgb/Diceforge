class_name SaveSchema
extends RefCounted

const RUN_SCHEMA_VERSION := 2
const META_SCHEMA_VERSION := 2

const REQUIRED_RUN_FIELDS := [
	"schema_version",
	"session_id",
	"slot_id",
	"display_name",
	"archetype_id",
	"floor_index",
	"current_room_id",
	"room_graph_id",
	"player_state",
	"active_dice",
	"inventory",
	"mode_id",
	"seed_id",
	"numeric_seed",
	"daily_void_config",
	"score_summary",
]

const REQUIRED_META_FIELDS := [
	"schema_version",
	"echo_shards",
	"unlocked_archetype_ids",
	"unlocked_part_ids",
	"unlocked_upgrade_ids",
	"achievement_ids",
	"daily_void_history",
	"last_daily_void_result",
]


func validate_run_state(payload: Dictionary, content_catalog = null) -> Dictionary:
	var errors: Array[String] = []
	errors.append_array(_validate_required_fields(payload, REQUIRED_RUN_FIELDS, "run_state"))
	if int(payload.get("schema_version", -1)) != RUN_SCHEMA_VERSION:
		errors.append("run_state schema_version is unsupported")

	if content_catalog == null:
		errors.append("content_catalog is required for run_state validation")
		return {"ok": false, "errors": errors}

	var state_validation = content_catalog.validate_saved_state(payload)
	if not state_validation.get("ok", false):
		errors.append(str(state_validation.get("error", "invalid_saved_state")))

	if errors.is_empty():
		return {"ok": true, "errors": []}
	return {"ok": false, "errors": errors}


func validate_meta_state(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	errors.append_array(_validate_required_fields(payload, REQUIRED_META_FIELDS, "meta_state"))
	if int(payload.get("schema_version", -1)) != META_SCHEMA_VERSION:
		errors.append("meta_state schema_version is unsupported")

	if errors.is_empty():
		return {"ok": true, "errors": []}
	return {"ok": false, "errors": errors}


func _validate_required_fields(payload: Dictionary, required_fields: Array, payload_name: String) -> Array[String]:
	var errors: Array[String] = []
	for required_field in required_fields:
		if not payload.has(required_field):
			errors.append("%s is missing required field '%s'" % [payload_name, str(required_field)])
	return errors
