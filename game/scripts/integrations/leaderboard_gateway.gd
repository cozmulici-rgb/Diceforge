class_name LeaderboardGateway
extends RefCounted

var service_available := false
var require_authorization := true


func _init(config: Dictionary = {}) -> void:
	service_available = bool(config.get("service_available", false))
	require_authorization = bool(config.get("require_authorization", true))


func submit_daily_score(entry: Dictionary) -> Dictionary:
	if not service_available:
		return {"ok": false, "error": "service_unavailable", "submission_status": "unavailable"}
	if require_authorization and str(entry.get("auth_token", "")) == "":
		return {"ok": false, "error": "unauthorized", "submission_status": "unauthorized"}
	return {
		"ok": true,
		"submission_status": "submitted",
		"rank": 17,
		"seed_id": str(entry.get("seed_id", "")),
	}


func fetch_daily_leaderboard(seed_id: String) -> Dictionary:
	if not service_available:
		return {"ok": false, "error": "service_unavailable"}
	return {
		"ok": true,
		"seed_id": seed_id,
		"entries": [],
	}
