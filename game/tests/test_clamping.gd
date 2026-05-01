extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var clamping = ClampingScript.new()

	if clamping.clamp_hp(50, 30) != 30:
		failures.append("clamp_hp should cap at max_hp")
	if clamping.clamp_hp(-5, 30) != 0:
		failures.append("clamp_hp should floor at 0")
	if clamping.clamp_hp(15, 30) != 15:
		failures.append("clamp_hp should preserve valid hp")

	if clamping.clamp_block(-3) != 0:
		failures.append("clamp_block should floor at 0")
	if clamping.clamp_energy(-1) != 0:
		failures.append("clamp_energy should floor at 0")
	if clamping.clamp_stacks(-2) != 0:
		failures.append("clamp_stacks should floor at 0")

	var damaged := clamping.apply_damage_to_entity({"hp": 20, "max_hp": 30, "block": 5}, 8)
	if int(damaged.get("block", -1)) != 0:
		failures.append("damage should consume all 5 block")
	if int(damaged.get("hp", -1)) != 17:
		failures.append("remaining damage should reduce hp to 17")

	var blocked := clamping.apply_damage_to_entity({"hp": 20, "max_hp": 30, "block": 10}, 5)
	if int(blocked.get("block", -1)) != 5 or int(blocked.get("hp", -1)) != 20:
		failures.append("full block absorption should preserve hp")

	return failures
