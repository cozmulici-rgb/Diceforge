class_name DailyVoidModeAdapter
extends RefCounted

const DailyScoreEntryScript = preload("res://scripts/modes/daily_score_entry.gd")
const LeaderboardGatewayScript = preload("res://scripts/integrations/leaderboard_gateway.gd")

var content_catalog
var leaderboard_gateway


func _init(catalog = null, gateway = null) -> void:
	content_catalog = catalog
	leaderboard_gateway = gateway if gateway != null else LeaderboardGatewayScript.new()


func create_daily_run_config(calendar_day: String, meta_state) -> Dictionary:
	var mode_definition = content_catalog.load_daily_mode_config("daily_void")
	if mode_definition is Dictionary and mode_definition.get("error", "") != "":
		return mode_definition

	var ordinal := _day_ordinal(calendar_day)
	var rotations: Array = (mode_definition.get("modifier_rotation", []) as Array).duplicate(true)
	var bundle: Dictionary = {}
	if not rotations.is_empty():
		bundle = rotations[ordinal % rotations.size()]

	var allowed_archetype_ids: Array = []
	for archetype_id in mode_definition.get("default_allowed_archetype_ids", []):
		var archetype_key := str(archetype_id)
		if (meta_state.unlocked_archetype_ids as Array).has(archetype_key):
			allowed_archetype_ids.append(archetype_key)
	if allowed_archetype_ids.is_empty():
		allowed_archetype_ids = (mode_definition.get("default_allowed_archetype_ids", []) as Array).duplicate(true)

	return {
		"ok": true,
		"id": "daily_void",
		"calendar_day": calendar_day,
		"seed_id": calendar_day,
		"numeric_seed": int(mode_definition.get("seed_salt", 0)) + ordinal,
		"modifier_ids": (bundle.get("modifier_ids", []) as Array).duplicate(true),
		"modifier_bundle_id": str(bundle.get("id", "")),
		"scoring_rule_id": str(mode_definition.get("scoring_rule_id", "daily_void_score_v1")),
		"allowed_archetype_ids": allowed_archetype_ids,
		"submission_context": str(mode_definition.get("submission_context", "local_only")),
		"auth_token": str(mode_definition.get("auth_token", "")),
	}


func create_daily_run_session(config: Dictionary, archetype_id: String) -> Dictionary:
	if not (config.get("allowed_archetype_ids", []) as Array).has(archetype_id):
		return {"ok": false, "error": "archetype_not_allowed", "archetype_id": archetype_id}

	return {
		"ok": true,
		"session_overrides": {
			"session_id_suffix": str(config.get("seed_id", "")),
			"mode_id": "daily_void",
			"seed_id": str(config.get("seed_id", "")),
			"numeric_seed": int(config.get("numeric_seed", 0)),
			"daily_void_config": config.duplicate(true),
			"modifiers": (config.get("modifier_ids", []) as Array).duplicate(true),
			"flags": {
				"run_mode": "daily_void",
			},
		},
	}


func finalize_daily_result(run_state, progression_result: Dictionary) -> Dictionary:
	if str(run_state.mode_id) != "daily_void":
		return progression_result

	var result := progression_result.duplicate(true)
	var score := _calculate_score(run_state, progression_result)
	var submission_status := "not_attempted"
	var config: Dictionary = run_state.daily_void_config
	var entry = DailyScoreEntryScript.new({
		"seed_id": str(run_state.seed_id),
		"score": score,
		"run_summary": run_state.score_summary.duplicate(true),
		"submission_context": str(config.get("submission_context", "local_only")),
		"auth_token": str(config.get("auth_token", "")),
	}).to_dictionary()

	if str(entry.get("submission_context", "local_only")) == "online_attempt":
		var submit_result = leaderboard_gateway.submit_daily_score(entry)
		submission_status = str(submit_result.get("submission_status", submit_result.get("error", "unavailable")))
	else:
		submission_status = "not_attempted"

	var daily_result := {
		"seed_id": str(run_state.seed_id),
		"score": score,
		"submission_status": submission_status,
	}
	result["daily_void_result"] = daily_result

	var meta_state: Dictionary = (result.get("meta_state", {}) as Dictionary).duplicate(true)
	var history: Array = (meta_state.get("daily_void_history", []) as Array).duplicate(true)
	history.append({
		"seed_id": str(daily_result.get("seed_id", "")),
		"score": int(daily_result.get("score", 0)),
		"submission_status": str(daily_result.get("submission_status", "not_attempted")),
		"archetype_id": str(run_state.archetype_id),
	})
	meta_state["daily_void_history"] = history
	meta_state["last_daily_void_result"] = daily_result.duplicate(true)
	result["meta_state"] = meta_state
	return result


func _calculate_score(run_state, progression_result: Dictionary) -> int:
	var score := int(run_state.floor_index) * 100
	score += int((run_state.inventory.get("currencies", {}) as Dictionary).get("echo_shards", 0))
	score += int((run_state.score_summary.get("bosses_defeated", 0))) * 75
	score += int((run_state.score_summary.get("modifier_count", 0))) * 20
	score += int((run_state.score_summary.get("score_bonus", 0)))
	if bool(run_state.run_complete):
		score += 125
	return score


func _day_ordinal(calendar_day: String) -> int:
	var digits := calendar_day.replace("-", "")
	if digits.is_valid_int():
		return int(digits)
	return calendar_day.hash()
