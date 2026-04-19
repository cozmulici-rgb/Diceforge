class_name AchievementTracker
extends RefCounted

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func evaluate_achievements(run_summary: Dictionary, meta_state) -> Array[String]:
	var unlocked_achievements: Array[String] = []
	var definitions = content_catalog.get_progression_definitions("achievement") if content_catalog != null else {}
	if not (definitions is Dictionary):
		return unlocked_achievements
	for achievement_id in definitions.keys():
		var achievement_definition: Dictionary = definitions[achievement_id]
		if (meta_state.achievement_ids as Array).has(achievement_id):
			continue
		if _matches_requirement(achievement_definition, run_summary):
			meta_state.achievement_ids.append(achievement_id)
			unlocked_achievements.append(achievement_id)
	return unlocked_achievements


func _matches_requirement(achievement_definition: Dictionary, run_summary: Dictionary) -> bool:
	var requirement := str(achievement_definition.get("requirement", ""))
	if requirement == "defeat_any_boss":
		return bool(run_summary.get("boss_defeated", false))
	if requirement == "win_run":
		return bool(run_summary.get("run_complete", false)) and str(run_summary.get("outcome", "")) == "victory"
	return false
