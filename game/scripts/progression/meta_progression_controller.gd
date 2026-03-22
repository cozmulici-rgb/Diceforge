class_name MetaProgressionController
extends RefCounted

const UnlockRegistryScript = preload("res://scripts/progression/unlock_registry.gd")
const AchievementTrackerScript = preload("res://scripts/progression/achievement_tracker.gd")

var content_catalog
var unlock_registry
var achievement_tracker


func _init(catalog = null) -> void:
	content_catalog = catalog
	unlock_registry = UnlockRegistryScript.new(catalog)
	achievement_tracker = AchievementTrackerScript.new(catalog)


func process_run_end(outcome: Dictionary, meta_state) -> Dictionary:
	var shards_gained := _calculate_echo_shards(outcome)
	meta_state.echo_shards += shards_gained

	var achievement_ids = achievement_tracker.evaluate_achievements(outcome, meta_state)
	var new_unlock_ids = unlock_registry.apply_unlocks(meta_state, outcome)

	return {
		"echo_shards_gained": shards_gained,
		"echo_shards_total": meta_state.echo_shards,
		"new_unlock_ids": new_unlock_ids,
		"achievement_ids": achievement_ids,
		"daily_void_result": {
			"seed_id": "",
			"score": 0,
			"submission_status": "not_attempted",
		},
		"meta_state": meta_state.to_dictionary(),
	}


func spend_echo_shards(cost: int, unlock_id: String, meta_state) -> Variant:
	if meta_state.echo_shards < cost:
		return {"ok": false, "error": "insufficient_echo_shards", "unlock_id": unlock_id}
	meta_state.echo_shards -= cost
	return meta_state


func list_available_unlocks(meta_state) -> Dictionary:
	return {
		"ok": true,
		"available_unlocks": unlock_registry.list_available_unlocks(meta_state),
	}


func evaluate_achievements(run_summary: Dictionary, meta_state) -> Dictionary:
	return {
		"ok": true,
		"achievement_ids": achievement_tracker.evaluate_achievements(run_summary, meta_state),
	}


func _calculate_echo_shards(outcome: Dictionary) -> int:
	var base_shards := 5
	base_shards += int(outcome.get("floors_cleared", 0)) * 10
	if bool(outcome.get("boss_defeated", false)):
		base_shards += 15
	if str(outcome.get("outcome", "")) == "victory" and bool(outcome.get("run_complete", false)):
		base_shards += 25
	return base_shards
