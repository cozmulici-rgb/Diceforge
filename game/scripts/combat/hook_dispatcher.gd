class_name HookDispatcher
extends RefCounted

const PRIORITY_ORDER := ["passive", "triggered", "optional"]
const VALID_TIMING_KEYS := [
	"battle_start",
	"player_turn_start",
	"on_roll",
	"pre_resolution",
	"on_resolution",
	"player_turn_end",
	"enemy_turn_start",
	"enemy_action",
	"enemy_turn_end",
	"phase_end",
	"phase_start",
	"battle_end",
]


func collect_hooks_for_timing(hooks: Array, timing_key: String) -> Array:
	var results: Array = []
	for hook in hooks:
		var item: Dictionary = hook as Dictionary
		if str(item.get("timing", "")) == timing_key:
			results.append(item.duplicate(true))
	return results


func sort_by_priority(hooks: Array) -> Array:
	var sorted := hooks.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_index := PRIORITY_ORDER.find(str(a.get("priority", "triggered")))
		var b_index := PRIORITY_ORDER.find(str(b.get("priority", "triggered")))
		if a_index == -1:
			a_index = 1
		if b_index == -1:
			b_index = 1
		return a_index < b_index
	)
	return sorted


func collect_and_sort(hooks: Array, timing_key: String) -> Array:
	return sort_by_priority(collect_hooks_for_timing(hooks, timing_key))


func valid_timing_keys() -> Array:
	return VALID_TIMING_KEYS.duplicate()
