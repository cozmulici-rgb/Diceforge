class_name RewardOption
extends RefCounted

var option_id: String
var grant_type: String
var content_id: String
var quantity: int


func _init(data: Dictionary = {}) -> void:
	option_id = str(data.get("option_id", ""))
	grant_type = str(data.get("grant_type", ""))
	content_id = str(data.get("content_id", ""))
	quantity = int(data.get("quantity", 1))


func to_dictionary() -> Dictionary:
	return {
		"option_id": option_id,
		"grant_type": grant_type,
		"content_id": content_id,
		"quantity": quantity,
	}
