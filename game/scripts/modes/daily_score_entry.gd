class_name DailyScoreEntry
extends RefCounted

var seed_id: String
var score: int
var run_summary: Dictionary
var submission_context: String
var auth_token: String


func _init(data: Dictionary = {}) -> void:
	seed_id = str(data.get("seed_id", ""))
	score = int(data.get("score", 0))
	run_summary = (data.get("run_summary", {}) as Dictionary).duplicate(true)
	submission_context = str(data.get("submission_context", "local_only"))
	auth_token = str(data.get("auth_token", ""))


func to_dictionary() -> Dictionary:
	return {
		"seed_id": seed_id,
		"score": score,
		"run_summary": run_summary.duplicate(true),
		"submission_context": submission_context,
		"auth_token": auth_token,
	}
