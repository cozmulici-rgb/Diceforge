class_name Clamping
extends RefCounted


func clamp_hp(hp: int, max_hp: int) -> int:
	return clampi(hp, 0, maxi(max_hp, 0))


func clamp_block(block: int) -> int:
	return maxi(block, 0)


func clamp_energy(energy: int) -> int:
	return maxi(energy, 0)


func clamp_stacks(stacks: int) -> int:
	return maxi(stacks, 0)


func apply_damage_to_entity(entity: Dictionary, damage: int) -> Dictionary:
	var result := entity.duplicate(true)
	var block := int(result.get("block", 0))
	var hp := int(result.get("hp", 0))
	var max_hp := int(result.get("max_hp", hp))
	var absorbed := mini(clamp_block(block), maxi(damage, 0))
	var remaining := maxi(damage - absorbed, 0)
	result["block"] = clamp_block(block - absorbed)
	result["hp"] = clamp_hp(hp - remaining, max_hp)
	return result
