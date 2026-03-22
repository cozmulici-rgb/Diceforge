class_name RewardController
extends RefCounted

const RunInventoryScript = preload("res://scripts/rewards/run_inventory.gd")
const RewardOptionScript = preload("res://scripts/rewards/reward_option.gd")

var content_catalog


func _init(catalog = null) -> void:
	content_catalog = catalog


func open_reward_flow(source: Dictionary, run_session) -> Dictionary:
	var reward_type := str(source.get("reward_type", ""))
	var reward_source_id := str(source.get("reward_source_id", ""))
	var definition = _load_source_definition(reward_type, reward_source_id)
	if _is_error_result(definition):
		return definition

	var options: Array = []
	for option_data in definition.get("options", []):
		options.append(RewardOptionScript.new(option_data).to_dictionary())

	return {
		"ok": true,
		"reward_source_id": reward_source_id,
		"reward_type": reward_type,
		"available_options": options,
		"inventory_snapshot": (run_session.inventory as Dictionary).duplicate(true),
		"can_enter_forge": bool(definition.get("can_enter_forge", false)),
	}


func apply_reward_option(run_session, option_data: Dictionary) -> Dictionary:
	var option := RewardOptionScript.new(option_data)
	var inventory := RunInventoryScript.new(run_session.inventory)

	match option.grant_type:
		"body", "face", "rune":
			inventory.add_part(option.grant_type, option.content_id, option.quantity)
		"currency":
			inventory.add_currency(option.content_id, option.quantity)
		"modifier":
			inventory.add_modifier(option.content_id, option.quantity)
		"forge_access":
			pass
		_:
			return {"ok": false, "error": "unsupported_reward_grant", "grant_type": option.grant_type}

	run_session.inventory = inventory.to_dictionary()
	run_session.modifiers = inventory.modifiers.duplicate(true)
	run_session.flags["encounter_status"] = "Reward claimed: %s" % option.option_id
	return {
		"ok": true,
		"selected_option": option.to_dictionary(),
		"inventory": run_session.inventory.duplicate(true),
	}


func _load_source_definition(reward_type: String, reward_source_id: String) -> Dictionary:
	if reward_type == "encounter":
		return content_catalog.load_reward_table(reward_source_id)
	if reward_type == "event":
		return content_catalog.load_event_definition(reward_source_id)
	if reward_type == "shop":
		return content_catalog.load_shop_definition(reward_source_id)
	return {
		"ok": false,
		"error": "unsupported_reward_type",
		"reward_type": reward_type,
	}


func _is_error_result(value: Variant) -> bool:
	return value is Dictionary and not value.get("ok", true)
