class_name ContentValidator
extends RefCounted

const REQUIRED_ARCHETYPE_FIELDS := [
	"id",
	"name",
	"starter_floor_id",
	"player_state",
	"starter_dice",
]

const REQUIRED_FLOOR_FIELDS := [
	"id",
	"name",
	"room_graph_id",
	"starting_room_id",
	"boss_room_id",
]

const REQUIRED_ROOM_GRAPH_FIELDS := [
	"id",
	"name",
	"rooms",
	"links",
]

const REQUIRED_ENCOUNTER_FIELDS := [
	"id",
	"name",
	"enemy_id",
]

const REQUIRED_ENEMY_FIELDS := [
	"id",
	"name",
	"hp",
	"damage",
]

const REQUIRED_REWARD_FIELDS := [
	"id",
	"options",
]

const REQUIRED_MODIFIER_FIELDS := [
	"id",
	"name",
	"modifier_type",
	"application_scope",
	"effect_tags",
	"stack_mode",
	"effects",
]


func validate_catalog(payload: Dictionary) -> Dictionary:
	var archetypes: Dictionary = payload.get("archetypes", {})
	var floors: Dictionary = payload.get("floors", {})
	var room_graphs: Dictionary = payload.get("room_graphs", {})
	var body_definitions: Dictionary = payload.get("body_definitions", {})
	var face_definitions: Dictionary = payload.get("face_definitions", {})
	var rune_definitions: Dictionary = payload.get("rune_definitions", {})
	var encounter_definitions: Dictionary = payload.get("encounter_definitions", {})
	var enemy_definitions: Dictionary = payload.get("enemy_definitions", {})
	var reward_definitions: Dictionary = payload.get("reward_definitions", {})
	var event_definitions: Dictionary = payload.get("event_definitions", {})
	var shop_definitions: Dictionary = payload.get("shop_definitions", {})
	var unlock_definitions: Dictionary = payload.get("unlock_definitions", {})
	var achievement_definitions: Dictionary = payload.get("achievement_definitions", {})
	var curse_definitions: Dictionary = payload.get("curse_definitions", {})
	var blessing_definitions: Dictionary = payload.get("blessing_definitions", {})
	var daily_mode_definitions: Dictionary = payload.get("daily_mode_definitions", {})
	var errors: Array[String] = []
	var modifier_definitions: Dictionary = curse_definitions.duplicate(true)
	for modifier_id in blessing_definitions.keys():
		modifier_definitions[modifier_id] = blessing_definitions[modifier_id]

	for archetype_id in archetypes.keys():
		var archetype: Dictionary = archetypes[archetype_id]
		errors.append_array(_validate_required_fields(archetype, REQUIRED_ARCHETYPE_FIELDS, "archetype", archetype_id))

		var starter_floor_id := str(archetype.get("starter_floor_id", ""))
		if starter_floor_id == "" or not floors.has(starter_floor_id):
			errors.append("Archetype '%s' references missing starter floor '%s'" % [archetype_id, starter_floor_id])

		var player_state = archetype.get("player_state", {})
		if not (player_state is Dictionary) or not player_state.has("hp"):
			errors.append("Archetype '%s' must define player_state.hp" % archetype_id)

		var starter_dice = archetype.get("starter_dice", [])
		if not (starter_dice is Array) or starter_dice.is_empty():
			errors.append("Archetype '%s' must define at least one starter die" % archetype_id)
		else:
			for starter_die in starter_dice:
				if not (starter_die is Dictionary):
					errors.append("Archetype '%s' contains an invalid starter die" % archetype_id)
					continue
				var body_id := str(starter_die.get("body_id", "standard_d6"))
				if not body_definitions.has(body_id):
					errors.append("Archetype '%s' starter die references missing body '%s'" % [archetype_id, body_id])
				for face_id in starter_die.get("face_set", []):
					if not face_definitions.has(str(face_id)):
						errors.append("Archetype '%s' starter die references missing face '%s'" % [archetype_id, str(face_id)])

	for floor_id in floors.keys():
		var floor: Dictionary = floors[floor_id]
		errors.append_array(_validate_required_fields(floor, REQUIRED_FLOOR_FIELDS, "floor", floor_id))

		var room_graph_id := str(floor.get("room_graph_id", ""))
		var starting_room_id := str(floor.get("starting_room_id", ""))
		if room_graph_id == "" or not room_graphs.has(room_graph_id):
			errors.append("Floor '%s' references missing room graph '%s'" % [floor_id, room_graph_id])
			continue

		var room_graph: Dictionary = room_graphs[room_graph_id]
		var room_ids: Array[String] = []
		for room in room_graph.get("rooms", []):
			if room is Dictionary and room.has("id"):
				room_ids.append(str(room["id"]))

		if starting_room_id == "" or not room_ids.has(starting_room_id):
			errors.append("Floor '%s' start room '%s' is not present in rooms" % [floor_id, starting_room_id])
		var boss_room_id := str(floor.get("boss_room_id", ""))
		if boss_room_id == "" or not room_ids.has(boss_room_id):
			errors.append("Floor '%s' boss room '%s' is not present in rooms" % [floor_id, boss_room_id])
		var next_floor_id := str(floor.get("next_floor_id", ""))
		if next_floor_id != "" and not floors.has(next_floor_id):
			errors.append("Floor '%s' references missing next floor '%s'" % [floor_id, next_floor_id])

	for graph_id in room_graphs.keys():
		var room_graph: Dictionary = room_graphs[graph_id]
		errors.append_array(_validate_required_fields(room_graph, REQUIRED_ROOM_GRAPH_FIELDS, "room graph", graph_id))

		var room_ids: Array[String] = []
		for room in room_graph.get("rooms", []):
			if room is Dictionary and room.has("id"):
				room_ids.append(str(room["id"]))

		if room_ids.is_empty():
			errors.append("Room graph '%s' must define at least one room" % graph_id)

		for link in room_graph.get("links", []):
			if not (link is Dictionary):
				errors.append("Room graph '%s' has an invalid link entry" % graph_id)
				continue

			var from_room := str(link.get("from", ""))
			var to_room := str(link.get("to", ""))
			if not room_ids.has(from_room) or not room_ids.has(to_room):
				errors.append("Room graph '%s' has a link with unknown room ids" % graph_id)

		for room in room_graph.get("rooms", []):
			if room is Dictionary:
				var encounter_id := str(room.get("encounter_id", ""))
				if encounter_id != "" and not encounter_definitions.has(encounter_id):
					errors.append("Room graph '%s' references missing encounter '%s'" % [graph_id, encounter_id])

	for encounter_id in encounter_definitions.keys():
		var encounter_definition: Dictionary = encounter_definitions[encounter_id]
		errors.append_array(_validate_required_fields(encounter_definition, REQUIRED_ENCOUNTER_FIELDS, "encounter", encounter_id))
		var enemy_id := str(encounter_definition.get("enemy_id", ""))
		if enemy_id == "" or not enemy_definitions.has(enemy_id):
			errors.append("Encounter '%s' references missing enemy '%s'" % [encounter_id, enemy_id])
		var reward_table_id := str(encounter_definition.get("reward_table_id", ""))
		if reward_table_id != "" and not reward_definitions.has(reward_table_id):
			errors.append("Encounter '%s' references missing reward table '%s'" % [encounter_id, reward_table_id])

	for enemy_id in enemy_definitions.keys():
		var enemy_definition: Dictionary = enemy_definitions[enemy_id]
		errors.append_array(_validate_required_fields(enemy_definition, REQUIRED_ENEMY_FIELDS, "enemy", enemy_id))

	for reward_id in reward_definitions.keys():
		errors.append_array(_validate_reward_options(reward_definitions[reward_id], reward_id, "reward table", body_definitions, face_definitions, rune_definitions, modifier_definitions))

	for event_id in event_definitions.keys():
		errors.append_array(_validate_reward_options(event_definitions[event_id], event_id, "event", body_definitions, face_definitions, rune_definitions, modifier_definitions))

	for shop_id in shop_definitions.keys():
		errors.append_array(_validate_reward_options(shop_definitions[shop_id], shop_id, "shop", body_definitions, face_definitions, rune_definitions, modifier_definitions))

	for modifier_id in modifier_definitions.keys():
		var modifier_definition: Dictionary = modifier_definitions[modifier_id]
		errors.append_array(_validate_required_fields(modifier_definition, REQUIRED_MODIFIER_FIELDS, "modifier", modifier_id))
		if str(modifier_definition.get("modifier_type", "")) not in ["curse", "blessing"]:
			errors.append("Modifier '%s' has an unsupported modifier_type" % modifier_id)
		if str(modifier_definition.get("application_scope", "")) not in ["run", "combat", "reward", "exploration", "progression"]:
			errors.append("Modifier '%s' has an unsupported application_scope" % modifier_id)
		if str(modifier_definition.get("stack_mode", "")) not in ["unique", "stackable", "replace"]:
			errors.append("Modifier '%s' has an unsupported stack_mode" % modifier_id)
		if not (modifier_definition.get("effects", {}) is Dictionary):
			errors.append("Modifier '%s' must define an effects dictionary" % modifier_id)

	for daily_mode_id in daily_mode_definitions.keys():
		var daily_mode_definition: Dictionary = daily_mode_definitions[daily_mode_id]
		for archetype_id in daily_mode_definition.get("default_allowed_archetype_ids", []):
			if not archetypes.has(str(archetype_id)):
				errors.append("Daily mode '%s' references missing archetype '%s'" % [daily_mode_id, str(archetype_id)])
		for bundle in daily_mode_definition.get("modifier_rotation", []):
			if not (bundle is Dictionary):
				errors.append("Daily mode '%s' has an invalid modifier_rotation entry" % daily_mode_id)
				continue
			for modifier_id in bundle.get("modifier_ids", []):
				if not modifier_definitions.has(str(modifier_id)):
					errors.append("Daily mode '%s' references missing modifier '%s'" % [daily_mode_id, str(modifier_id)])

	for unlock_id in unlock_definitions.keys():
		var unlock_definition: Dictionary = unlock_definitions[unlock_id]
		var unlock_type := str(unlock_definition.get("unlock_type", ""))
		var target_id := str(unlock_definition.get("target_id", ""))
		if unlock_type == "archetype" and not archetypes.has(target_id):
			errors.append("Unlock '%s' references missing archetype '%s'" % [unlock_id, target_id])
		elif unlock_type == "part" and not (body_definitions.has(target_id) or face_definitions.has(target_id) or rune_definitions.has(target_id)):
			errors.append("Unlock '%s' references missing part '%s'" % [unlock_id, target_id])

	for achievement_id in achievement_definitions.keys():
		var achievement_definition: Dictionary = achievement_definitions[achievement_id]
		if str(achievement_definition.get("requirement", "")) == "":
			errors.append("Achievement '%s' must define a requirement" % achievement_id)

	if errors.is_empty():
		return {"ok": true, "errors": []}

	return {"ok": false, "errors": errors}


func _validate_required_fields(content: Dictionary, fields: Array, content_type: String, content_id: String) -> Array[String]:
	var errors: Array[String] = []
	for field_name in fields:
		if not content.has(field_name):
			errors.append("%s '%s' is missing required field '%s'" % [content_type.capitalize(), content_id, field_name])
	return errors


func _validate_reward_options(definition: Dictionary, definition_id: String, definition_type: String, body_definitions: Dictionary, face_definitions: Dictionary, rune_definitions: Dictionary, modifier_definitions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(_validate_required_fields(definition, REQUIRED_REWARD_FIELDS, definition_type, definition_id))
	for option in definition.get("options", []):
		if not (option is Dictionary):
			errors.append("%s '%s' has an invalid reward option entry" % [definition_type.capitalize(), definition_id])
			continue
		var grant_type := str(option.get("grant_type", ""))
		var content_id := str(option.get("content_id", ""))
		if grant_type == "body" and not body_definitions.has(content_id):
			errors.append("%s '%s' references missing body '%s'" % [definition_type.capitalize(), definition_id, content_id])
		elif grant_type == "face" and not face_definitions.has(content_id):
			errors.append("%s '%s' references missing face '%s'" % [definition_type.capitalize(), definition_id, content_id])
		elif grant_type == "rune" and not rune_definitions.has(content_id):
			errors.append("%s '%s' references missing rune '%s'" % [definition_type.capitalize(), definition_id, content_id])
		elif grant_type == "modifier" and not modifier_definitions.has(content_id):
			errors.append("%s '%s' references missing modifier '%s'" % [definition_type.capitalize(), definition_id, content_id])
		elif grant_type in ["currency", "forge_access"]:
			continue
		elif grant_type == "":
			errors.append("%s '%s' has a reward option with a missing grant_type" % [definition_type.capitalize(), definition_id])
	return errors
