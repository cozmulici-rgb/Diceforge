class_name BattleLog
extends RefCounted

var _entries: Array = []
var _step_index := 0


func record(entry_data: Dictionary) -> void:
	var entry := entry_data.duplicate(true)
	entry["step_index"] = _step_index
	_step_index += 1
	_entries.append(entry)


func get_entries() -> Array:
	return _entries.duplicate(true)


func get_entries_for_turn(turn: int) -> Array:
	var results: Array = []
	for entry in _entries:
		var item: Dictionary = entry as Dictionary
		if int(item.get("turn", -1)) == turn:
			results.append(item.duplicate(true))
	return results


func current_step_index() -> int:
	return _step_index
