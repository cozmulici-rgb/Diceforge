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
	for room_state in (session.room_states as Dictionary).values():
		if room_state is Dictionary and bool(room_state.get("revealed", false)):
			revealed_count += 1
		if room_state is Dictionary and bool(room_state.get("completed", false)):
			completed_count += 1

	status_label.text = "Run %s | Archetype: %s | Room: %s | HP: %d | Rooms: %d revealed / %d completed" % [
		session.session_id,
		session.archetype_id,
		session.current_room_id,
		hp,
		revealed_count,
		completed_count,
	]


func show_error(message: String) -> void:
	status_label.text = "Startup error: %s" % message
