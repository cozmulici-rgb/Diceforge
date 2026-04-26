extends RefCounted

const HookDispatcherScript = preload("res://scripts/combat/hook_dispatcher.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var dispatcher = HookDispatcherScript.new()
	var hooks := [
		{
			"timing": "on_resolution",
			"priority": "triggered",
			"type": "apply_status",
		},
		{
			"timing": "on_resolution",
			"priority": "passive",
			"type": "damage_bonus",
		},
		{
			"timing": "on_roll",
			"priority": "triggered",
			"type": "apply_status",
		},
	]

	var on_resolution := dispatcher.collect_hooks_for_timing(hooks, "on_resolution")
	if on_resolution.size() != 2:
		failures.append("on_resolution filter should return 2 hooks")

	var sorted := dispatcher.sort_by_priority(on_resolution)
	if str((sorted[0] as Dictionary).get("priority", "")) != "passive":
		failures.append("passive hook should sort first")
	if not dispatcher.valid_timing_keys().has("battle_start"):
		failures.append("valid timings should include battle_start")

	return failures
