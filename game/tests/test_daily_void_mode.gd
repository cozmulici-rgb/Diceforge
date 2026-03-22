extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const MetaStateScript = preload("res://scripts/progression/meta_state.gd")
const DailyVoidModeAdapterScript = preload("res://scripts/modes/daily_void_mode_adapter.gd")
const LeaderboardGatewayScript = preload("res://scripts/integrations/leaderboard_gateway.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var meta_state = MetaStateScript.new()
	var adapter = DailyVoidModeAdapterScript.new(catalog)

	var config_a = adapter.create_daily_run_config("2026-03-22", meta_state)
	var config_b = adapter.create_daily_run_config("2026-03-22", meta_state)
	if not config_a.get("ok", false) or not config_b.get("ok", false):
		failures.append("daily void config should load successfully for a valid day")
		return failures
	if int(config_a.get("numeric_seed", 0)) != int(config_b.get("numeric_seed", 0)):
		failures.append("daily void config should be deterministic for the same calendar day")
	if JSON.stringify(config_a.get("modifier_ids", [])) != JSON.stringify(config_b.get("modifier_ids", [])):
		failures.append("daily void modifier rotation should be deterministic for the same calendar day")

	var unavailable_gateway = LeaderboardGatewayScript.new({"service_available": false})
	var unavailable_result = unavailable_gateway.submit_daily_score({"seed_id": "2026-03-22", "score": 120})
	if unavailable_result.get("error", "") != "service_unavailable":
		failures.append("leaderboard gateway should report service_unavailable when the service is absent")

	var unauthorized_gateway = LeaderboardGatewayScript.new({"service_available": true, "require_authorization": true})
	var unauthorized_result = unauthorized_gateway.submit_daily_score({"seed_id": "2026-03-22", "score": 120})
	if unauthorized_result.get("error", "") != "unauthorized":
		failures.append("leaderboard gateway should reject requests without valid authorization")

	var coordinator = GameStateCoordinatorScript.new(catalog)
	var daily_session = coordinator.create_daily_void_session("starter_facetwalker", "2026-03-22")
	if daily_session == null or daily_session is Dictionary:
		failures.append("coordinator should be able to create a daily void session")
		return failures

	if str(daily_session.mode_id) != "daily_void":
		failures.append("daily void runs should be tagged with the daily_void mode id")
	if str(daily_session.seed_id) != "2026-03-22":
		failures.append("daily void runs should persist the calendar day seed id")
	if (daily_session.modifiers as Array).is_empty():
		failures.append("daily void runs should start with a deterministic modifier bundle")
	if int((daily_session.floor_state as Dictionary).get("generation_seed", 0)) <= 101:
		failures.append("daily void floor generation should incorporate the daily seed")

	daily_session.run_complete = true
	daily_session.floor_index = 2
	daily_session.inventory["currencies"] = {"echo_shards": 18}
	var progression_result = coordinator.finalize_run({
		"outcome": "victory",
		"boss_defeated": true,
		"run_complete": true,
	})
	var daily_result: Dictionary = progression_result.get("daily_void_result", {})
	if str(daily_result.get("seed_id", "")) != "2026-03-22":
		failures.append("daily void progression should include the seeded result payload")
	if int(daily_result.get("score", 0)) <= 0:
		failures.append("daily void progression should calculate a local score")
	if str(daily_result.get("submission_status", "")) != "not_attempted":
		failures.append("local-only daily void runs should not attempt online submission")
	if (coordinator.meta_state.daily_void_history as Array).is_empty():
		failures.append("daily void completion should append to local meta-state history")

	return failures
