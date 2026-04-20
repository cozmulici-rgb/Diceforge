extends Node2D

const RoomGraphScript = preload("res://scripts/exploration/room_graph.gd")
const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

signal session_updated(run_session)
signal encounter_started(combat_state)

@onready var ui_panel: PanelContainer = $UI/CenterContainer/PanelContainer
@onready var room_name_label: Label = $UI/CenterContainer/PanelContainer/VBoxContainer/RoomNameLabel
@onready var room_meta_label: Label = $UI/CenterContainer/PanelContainer/VBoxContainer/RoomMetaLabel
@onready var exits_header_label: Label = $UI/CenterContainer/PanelContainer/VBoxContainer/ExitsHeaderLabel
@onready var exits_container: VBoxContainer = $UI/CenterContainer/PanelContainer/VBoxContainer/ExitsContainer
@onready var encounter_button: Button = $UI/CenterContainer/PanelContainer/VBoxContainer/EncounterButton
@onready var encounter_status_label: Label = $UI/CenterContainer/PanelContainer/VBoxContainer/EncounterStatusLabel
@onready var player = $Player

var content_catalog
var game_state_coordinator
var run_session
var room_graph


func _ready() -> void:
	_apply_theme()
	encounter_button.pressed.connect(_on_encounter_pressed)

	if run_session != null:
		_build_room_graph()
		_refresh_view()


func setup(coordinator, catalog, session) -> void:
	game_state_coordinator = coordinator
	content_catalog = catalog
	run_session = session

	if is_node_ready():
		_build_room_graph()
		_refresh_view()


func _build_room_graph() -> void:
	var room_graph_data = content_catalog.load_room_graph(str(run_session.room_graph_id))
	if room_graph_data is Dictionary and room_graph_data.get("error", "") != "":
		encounter_status_label.text = "Room graph failed to load: %s" % room_graph_data.get("error", "unknown")
		return

	var graph_payload: Dictionary = room_graph_data.duplicate(true)
	graph_payload["room_states"] = run_session.room_states.duplicate(true)
	room_graph = RoomGraphScript.new(graph_payload)


func _refresh_view() -> void:
	if room_graph == null:
		return

	var current_room = room_graph.get_room(str(run_session.current_room_id))
	if current_room == null:
		return

	room_name_label.text = "%s" % current_room.display_name
	room_meta_label.text = "Floor %d tutorial room\nType: %s  |  Visits: %d  |  %s" % [
		int(run_session.floor_index),
		_format_room_type(current_room.room_type),
		current_room.visit_count,
		"Cleared" if current_room.completed else "Uncleared",
	]

	encounter_status_label.text = str(run_session.flags.get("encounter_status", "Explore the room shell and trigger the stub encounter."))
	var is_paused := str(run_session.flags.get("screen_state", "exploration")) != "exploration"
	encounter_button.disabled = current_room.encounter_id == "" or is_paused
	encounter_button.text = "Trigger Encounter"
	if current_room.encounter_id != "":
		encounter_button.text = "Trigger Encounter: %s" % current_room.encounter_id

	player.global_position = current_room.position
	_rebuild_exit_buttons(current_room.room_id)
	session_updated.emit(run_session)


func _rebuild_exit_buttons(room_id: String) -> void:
	for child in exits_container.get_children():
		child.queue_free()

	for neighbor_id in room_graph.get_neighbor_ids(room_id):
		var room_state = room_graph.get_room(neighbor_id)
		if room_state == null:
			continue

		var button := Button.new()
		button.theme_type_variation = &"FacetTertiaryButton"
		button.text = "Move to %s (%s)" % [room_state.display_name, room_state.room_type]
		button.disabled = str(run_session.flags.get("screen_state", "exploration")) != "exploration"
		button.pressed.connect(_on_move_pressed.bind(neighbor_id))
		exits_container.add_child(button)


func _on_move_pressed(room_id: String) -> void:
	var transition_result = game_state_coordinator.enter_room(room_id)
	if not transition_result.get("ok", false):
		encounter_status_label.text = "Room transition failed: %s" % transition_result.get("error", "unknown")
		return

	run_session = game_state_coordinator.current_session
	run_session.flags["encounter_status"] = "Moved into %s." % room_id
	_build_room_graph()
	_refresh_view()


func _on_encounter_pressed() -> void:
	if room_graph == null:
		return

	var current_room = room_graph.get_room(str(run_session.current_room_id))
	if current_room == null or current_room.encounter_id == "":
		encounter_status_label.text = "No encounter is available in this room."
		return

	var encounter_result = game_state_coordinator.begin_encounter(current_room.encounter_id)
	if not encounter_result.get("ok", false):
		encounter_status_label.text = "Encounter handoff failed: %s" % encounter_result.get("error", "unknown")
		return

	run_session = game_state_coordinator.current_session
	run_session.flags["encounter_status"] = "Combat active: %s" % current_room.encounter_id
	_build_room_graph()
	_refresh_view()
	encounter_started.emit(encounter_result.get("combat_state"))


func _apply_theme() -> void:
	ui_panel.theme = FacetboundThemeScript.build()
	ui_panel.theme_type_variation = &"FacetCard"
	room_name_label.theme_type_variation = &"FacetTitle"
	room_meta_label.theme_type_variation = &"FacetBodyMuted"
	exits_header_label.theme_type_variation = &"FacetSectionLabel"
	encounter_status_label.theme_type_variation = &"FacetInfo"
	encounter_button.theme_type_variation = &"FacetPrimaryButton"


func _format_room_type(room_type: String) -> String:
	match room_type:
		"start":
			return "Start"
		"encounter":
			return "Encounter"
		"boss":
			return "Boss"
		"shop":
			return "Shop"
		_:
			return room_type.capitalize()
