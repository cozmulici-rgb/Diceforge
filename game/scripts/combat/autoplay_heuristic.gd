class_name AutoplayHeuristic
extends RefCounted

const EFFECT_PRIORITY := {
	"reroll": 0,
	"amplify": 1,
	"utility": 2,
	"heal": 2,
	"block": 3,
	"damage": 4,
	"burn": 5,
	"poison": 5,
	"freeze": 5,
}


func build_queue(rolled_faces: Array) -> Array:
	var sortable := rolled_faces.duplicate(true)
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(EFFECT_PRIORITY.get(str(a.get("effect", "utility")), 6))
		var b_priority := int(EFFECT_PRIORITY.get(str(b.get("effect", "utility")), 6))
		if a_priority == b_priority:
			return str(a.get("die_id", "")) < str(b.get("die_id", ""))
		return a_priority < b_priority
	)
	return sortable
