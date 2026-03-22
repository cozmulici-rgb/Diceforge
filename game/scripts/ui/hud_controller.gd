class_name HUDController
extends CanvasLayer

@onready var status_label: Label = $MarginContainer/StatusLabel


func show_status(session) -> void:
	if session == null:
		status_label.text = "No active run"
		return

	var hp := int((session.player_state as Dictionary).get("hp", 0))
	var revealed_count := 0
	var completed_count := 0
	var action_slot_names: Array[String] = []
	var inventory = session.inventory as Dictionary
	for room_state in (session.room_states as Dictionary).values():
		if room_state is Dictionary and bool(room_state.get("revealed", false)):
			revealed_count += 1
		if room_state is Dictionary and bool(room_state.get("completed", false)):
			completed_count += 1
	for slot in (session.action_slots as Array):
		if slot is Dictionary:
			action_slot_names.append(str(slot.get("display_name", slot.get("slot_id", "slot"))))

	status_label.text = "Run %s | Archetype: %s | Room: %s | HP: %d | Rooms: %d/%d | Slots: %s" % [
		session.session_id,
		session.archetype_id,
		session.current_room_id,
		hp,
		revealed_count,
		completed_count,
		", ".join(action_slot_names),
	]
	status_label.text += " | Inventory B/F/R: %d/%d/%d | Shards: %d | State: %s" % [
		(inventory.get("bodies", []) as Array).size(),
		(inventory.get("faces", []) as Array).size(),
		(inventory.get("runes", []) as Array).size(),
		int((inventory.get("currencies", {}) as Dictionary).get("echo_shards", 0)),
		str(session.flags.get("screen_state", "exploration")),
	]


func show_error(message: String) -> void:
	status_label.text = "Startup error: %s" % message
