class_name ModifierRegistry
extends RefCounted

const ModifierEffectScript = preload("res://scripts/modifiers/modifier_effect.gd")

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func load_modifier_effects(modifier_ids: Array) -> Array:
	var effects: Array = []
	var seen_unique: Dictionary = {}
	for modifier_id in modifier_ids:
		var modifier_definition = content_catalog.load_modifier_definition(str(modifier_id))
		if modifier_definition is Dictionary and modifier_definition.get("error", "") != "":
			continue
		var effect = ModifierEffectScript.new(modifier_definition)
		if effect.stack_mode == "unique":
			if seen_unique.has(effect.id):
				continue
			seen_unique[effect.id] = true
		effects.append(effect.to_dictionary())
	return effects


func build_scope_snapshot(modifier_ids: Array, scopes: Array[String]) -> Dictionary:
	var snapshot := {
		"player_hp_bonus": 0,
		"enemy_hp_delta": 0,
		"enemy_damage_delta": 0,
		"attack_bonus": 0,
		"block_bonus": 0,
		"score_bonus": 0,
		"echo_shard_bonus": 0,
		"modifier_ids": [],
		"effect_tags": [],
	}

	for modifier_effect in load_modifier_effects(modifier_ids):
		var effect: Dictionary = modifier_effect
		var scope := str(effect.get("application_scope", ""))
		if not scopes.has(scope):
			continue
		(snapshot["modifier_ids"] as Array).append(str(effect.get("id", "")))
		for tag in effect.get("effect_tags", []):
			(snapshot["effect_tags"] as Array).append(str(tag))
		var effect_values: Dictionary = effect.get("effects", {})
		for key in ["player_hp_bonus", "enemy_hp_delta", "enemy_damage_delta", "attack_bonus", "block_bonus", "score_bonus", "echo_shard_bonus"]:
			snapshot[key] = int(snapshot.get(key, 0)) + int(effect_values.get(key, 0))
	return snapshot


func build_combat_snapshot(modifier_ids: Array) -> Dictionary:
	return build_scope_snapshot(modifier_ids, ["run", "combat"])


func build_progression_snapshot(modifier_ids: Array) -> Dictionary:
	return build_scope_snapshot(modifier_ids, ["run", "reward", "progression"])
