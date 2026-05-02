extends Control

const RoomGraphScript = preload("res://scripts/exploration/room_graph.gd")
const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")
const MapBackdropTexture = preload("res://assets/exploration/exports/map-backdrop-v1.png")
const MapOverlayTexture = preload("res://assets/exploration/exports/map-overlay-v1.png")

const ACCENT_BRIGHT := Color("6ebeff")
const ACCENT_SOFT := Color(0.43, 0.75, 1.0, 0.22)
const TEXT_PRIMARY := Color("e7e3da")
const TEXT_MUTED := Color("9ca6b2")
const TEXT_DIM := Color("73808d")
const TEXT_FAINT := Color("59636d")
const GOLD := Color("c6a85a")
const GOLD_SOFT := Color(0.78, 0.66, 0.35, 0.2)
const HUD_LIVE := Color(0.45, 0.85, 0.55)
const DANGER := Color("d28b7c")

const ROOM_TYPE_COLORS := {
	"start": Color(0.58, 0.9, 0.82),
	"encounter": ACCENT_BRIGHT,
	"event": Color(0.72, 0.62, 0.96),
	"shop": Color(0.66, 0.85, 0.55),
	"boss": DANGER,
}

signal session_updated(run_session)
signal encounter_started(combat_state)

@onready var sidebar_panel: PanelContainer = $MainLayout/SidebarPanel
@onready var map_shell: PanelContainer = $MainLayout/MapShell
@onready var map_frame: PanelContainer = $MainLayout/MapShell/MapMargin/MapStack/MapFrame
@onready var kicker_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/KickerRow/KickerLabel
@onready var kicker_line_left: ColorRect = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/KickerRow/KickerLineLeft
@onready var kicker_line_right: ColorRect = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/KickerRow/KickerLineRight
@onready var room_name_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/RoomNameLabel
@onready var subtitle_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/SubtitleLabel
@onready var room_meta_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/RoomMetaLabel
@onready var selected_header_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/SelectedHeaderLabel
@onready var selected_room_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/SelectedRoomLabel
@onready var selection_meta_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/SelectionMetaLabel
@onready var combat_map_header_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/CombatMapHeaderLabel
@onready var combat_map_name_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/CombatMapNameLabel
@onready var combat_map_summary_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/CombatMapSummaryLabel
@onready var primary_action_button: Button = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/PrimaryActionButton
@onready var encounter_status_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/EncounterStatusLabel
@onready var legend_header_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendHeaderLabel
@onready var legend_summary_label: Label = $MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendSummaryLabel
@onready var map_title_label: Label = $MainLayout/MapShell/MapMargin/MapStack/MapHeader/MapTitleLabel
@onready var map_hint_label: Label = $MainLayout/MapShell/MapMargin/MapStack/MapHeader/MapHintLabel
@onready var map_backdrop: TextureRect = $MainLayout/MapShell/MapMargin/MapStack/MapFrame/MapLayerRoot/MapBackdrop
@onready var map_overlay: TextureRect = $MainLayout/MapShell/MapMargin/MapStack/MapFrame/MapLayerRoot/MapOverlay
@onready var map_view = $MainLayout/MapShell/MapMargin/MapStack/MapFrame/MapLayerRoot/MapView
@onready var frame_corners: Control = $FrameCorners
@onready var footer_left: HBoxContainer = $FooterHUD/FooterLeft
@onready var footer_right: HBoxContainer = $FooterHUD/FooterRight
@onready var footer_center: Label = $FooterHUD/FooterCenter

var content_catalog
var game_state_coordinator
var run_session
var room_graph
var _selected_room_id := ""


func _ready() -> void:
	_apply_theme()
	_style_scene()
	_ensure_map_textures()
	_build_frame_corners()
	_build_footer_hud()
	_build_legend()
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	map_view.room_selected.connect(_on_map_room_selected)

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


func _apply_theme() -> void:
	theme = FacetboundThemeScript.build()
	primary_action_button.theme_type_variation = &"FacetPrimaryButton"
	sidebar_panel.theme_type_variation = &"FacetCard"
	map_shell.theme_type_variation = &"FacetCard"
	map_frame.theme_type_variation = &"InfoPanel"


func _style_scene() -> void:
	sidebar_panel.custom_minimum_size.x = 334.0

	kicker_label.add_theme_font_size_override("font_size", 12)
	kicker_label.add_theme_color_override("font_color", TEXT_MUTED)
	kicker_line_left.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.85)
	kicker_line_right.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.3)

	room_name_label.add_theme_font_size_override("font_size", 34)
	room_name_label.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	room_name_label.add_theme_constant_override("outline_size", 8)
	room_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	room_name_label.clip_text = true

	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", TEXT_MUTED)
	room_meta_label.add_theme_font_size_override("font_size", 15)
	room_meta_label.add_theme_color_override("font_color", TEXT_DIM)
	room_meta_label.clip_text = true

	selected_header_label.add_theme_font_size_override("font_size", 12)
	selected_header_label.add_theme_color_override("font_color", Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.9))
	selected_room_label.add_theme_font_size_override("font_size", 20)
	selected_room_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	selected_room_label.clip_text = true
	selection_meta_label.add_theme_font_size_override("font_size", 13)
	selection_meta_label.add_theme_color_override("font_color", TEXT_DIM)
	selection_meta_label.clip_text = true
	combat_map_header_label.add_theme_font_size_override("font_size", 12)
	combat_map_header_label.add_theme_color_override("font_color", Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.9))
	combat_map_name_label.add_theme_font_size_override("font_size", 18)
	combat_map_name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	combat_map_name_label.clip_text = true
	combat_map_summary_label.add_theme_font_size_override("font_size", 13)
	combat_map_summary_label.add_theme_color_override("font_color", TEXT_DIM)
	combat_map_summary_label.clip_text = true

	encounter_status_label.add_theme_font_size_override("font_size", 12)
	encounter_status_label.add_theme_color_override("font_color", TEXT_DIM)
	encounter_status_label.clip_text = true
	legend_header_label.add_theme_font_size_override("font_size", 12)
	legend_header_label.add_theme_color_override("font_color", Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.9))
	legend_summary_label.add_theme_font_size_override("font_size", 12)
	legend_summary_label.add_theme_color_override("font_color", TEXT_FAINT)
	legend_summary_label.clip_text = true

	map_title_label.add_theme_font_size_override("font_size", 15)
	map_title_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	map_hint_label.add_theme_font_size_override("font_size", 12)
	map_hint_label.add_theme_color_override("font_color", TEXT_MUTED)

	footer_center.add_theme_font_size_override("font_size", 12)
	footer_center.add_theme_color_override("font_color", TEXT_DIM)
	primary_action_button.clip_text = true

	var sidebar_style := _panel_stylebox(Color(0.05, 0.07, 0.1, 0.88), Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.22))
	sidebar_panel.add_theme_stylebox_override("panel", sidebar_style)
	var map_style := _panel_stylebox(Color(0.05, 0.07, 0.1, 0.42), Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.28))
	map_shell.add_theme_stylebox_override("panel", map_style)
	map_frame.add_theme_stylebox_override("panel", _panel_stylebox(Color(0.03, 0.05, 0.08, 0.18), Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.16), 1))


func _ensure_map_textures() -> void:
	map_backdrop.texture = MapBackdropTexture
	map_overlay.texture = MapOverlayTexture


func _panel_stylebox(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style


func _build_legend() -> void:
	_style_legend_chip($MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendRow/LegendStart as PanelContainer, ROOM_TYPE_COLORS["start"])
	_style_legend_chip($MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendRow/LegendFight as PanelContainer, ROOM_TYPE_COLORS["encounter"])
	_style_legend_chip($MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendRow/LegendEvent as PanelContainer, ROOM_TYPE_COLORS["event"])
	_style_legend_chip($MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendRow/LegendShop as PanelContainer, ROOM_TYPE_COLORS["shop"])
	_style_legend_chip($MainLayout/SidebarPanel/SidebarMargin/SidebarContent/LegendRow/LegendBoss as PanelContainer, ROOM_TYPE_COLORS["boss"])


func _style_legend_chip(chip: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.12)
	style.border_color = Color(color.r, color.g, color.b, 0.6)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)

	for child in chip.get_children():
		if child is Label:
			(child as Label).add_theme_font_size_override("font_size", 11)
			(child as Label).add_theme_color_override("font_color", color)


func _build_frame_corners() -> void:
	for child in frame_corners.get_children():
		child.free()
	var inset := 24.0
	var length := 26.0
	var weight := 2.0
	_add_corner(inset, inset, length, length, weight, weight, 0, 0)
	_add_corner(-inset - length, inset, length, length, 0, weight, weight, 0)
	_add_corner(inset, -inset - length, length, length, weight, 0, 0, weight)
	_add_corner(-inset - length, -inset - length, length, length, 0, 0, weight, weight)


func _add_corner(offset_x: float, offset_y: float, width: float, height: float, bw_left: float, bw_top: float, bw_right: float, bw_bottom: float) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if offset_x >= 0:
		panel.anchor_left = 0
		panel.anchor_right = 0
		panel.offset_left = offset_x
		panel.offset_right = offset_x + width
	else:
		panel.anchor_left = 1
		panel.anchor_right = 1
		panel.offset_left = offset_x
		panel.offset_right = offset_x + width
	if offset_y >= 0:
		panel.anchor_top = 0
		panel.anchor_bottom = 0
		panel.offset_top = offset_y
		panel.offset_bottom = offset_y + height
	else:
		panel.anchor_top = 1
		panel.anchor_bottom = 1
		panel.offset_top = offset_y
		panel.offset_bottom = offset_y + height
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = ACCENT_BRIGHT
	style.border_width_left = int(bw_left)
	style.border_width_top = int(bw_top)
	style.border_width_right = int(bw_right)
	style.border_width_bottom = int(bw_bottom)
	panel.add_theme_stylebox_override("panel", style)
	frame_corners.add_child(panel)


func _build_footer_hud() -> void:
	for child in footer_left.get_children():
		child.free()
	for child in footer_right.get_children():
		child.free()

	var floor_chip := _make_chip("◆  FLOOR  —", HUD_LIVE, Color(HUD_LIVE.r, HUD_LIVE.g, HUD_LIVE.b, 0.45))
	floor_chip.name = "FloorChip"
	footer_left.add_child(floor_chip)

	var room_chip := _make_chip("ROOM  —", TEXT_DIM, Color(1, 1, 1, 0.14))
	room_chip.name = "RoomChip"
	footer_left.add_child(room_chip)

	var state_chip := _make_chip("●  EXPLORATION", ACCENT_BRIGHT, Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.45))
	state_chip.name = "StateChip"
	footer_right.add_child(state_chip)

	var threat_chip := _make_chip("THREAT  —", GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.4))
	threat_chip.name = "ThreatChip"
	footer_right.add_child(threat_chip)


func _make_chip(text: String, color: Color, border: Color) -> PanelContainer:
	var wrap := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	wrap.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	wrap.add_child(label)
	return wrap


func _set_chip_text(node: PanelContainer, text: String) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Label:
			(child as Label).text = text
			return


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

	if _selected_room_id == "" or room_graph.get_room(_selected_room_id) == null:
		_selected_room_id = str(current_room.room_id)

	var selected_room = room_graph.get_room(_selected_room_id)
	if selected_room == null:
		selected_room = current_room
		_selected_room_id = str(current_room.room_id)

	var is_paused := str(run_session.flags.get("screen_state", "exploration")) != "exploration"

	room_name_label.text = str(current_room.display_name).to_upper()
	subtitle_label.text = "FLOOR  ·  %02d  ·  %s" % [int(run_session.floor_index), "CLEARED" if current_room.completed else "ACTIVE"]
	room_meta_label.text = _current_room_summary(current_room)
	encounter_status_label.text = str(run_session.flags.get("encounter_status", "Select a connected node to travel, or commit the current room to combat."))

	selected_room_label.text = str(selected_room.display_name).to_upper()
	selected_room_label.add_theme_color_override("font_color", _room_color(selected_room))
	selection_meta_label.text = _selected_room_summary(selected_room, current_room, is_paused)
	_refresh_combat_map_panel(selected_room)

	map_title_label.text = "FLOOR  %02d  ROUTE  MAP" % int(run_session.floor_index)
	map_hint_label.text = "%d  COMBAT  MAPS  CHARTED" % _count_combat_maps()

	map_view.set_graph(room_graph, str(current_room.room_id), is_paused)
	map_view.set_highlighted_room(_selected_room_id)

	_refresh_primary_action(current_room, selected_room, is_paused)
	_refresh_footer(current_room, selected_room, is_paused)
	session_updated.emit(run_session)


func _current_room_summary(current_room) -> String:
	var summary := "%s room. %s" % [
		_format_room_type(str(current_room.room_type)),
		str(current_room.description),
	]
	if current_room.visit_count > 0:
		summary += " Visited %d time%s." % [current_room.visit_count, "" if current_room.visit_count == 1 else "s"]
	if current_room.completed:
		summary += " This chamber is secured."
	return summary


func _selected_room_summary(selected_room, current_room, is_paused: bool) -> String:
	var parts: Array[String] = []
	parts.append(_format_room_type(str(selected_room.room_type)).to_upper())
	if str(selected_room.room_id) == str(current_room.room_id):
		parts.append("CURRENT")
	elif _is_neighbor(current_room, str(selected_room.room_id)):
		parts.append("REACHABLE")
	else:
		parts.append("LOCKED")
	if selected_room.completed:
		parts.append("CLEARED")
	elif selected_room.visit_count > 0:
		parts.append("VISITED")
	if is_paused:
		parts.append("PAUSED")
	var body := "  ·  ".join(parts)
	if str(selected_room.description) != "":
		body += "\n%s" % str(selected_room.description)
	if str(selected_room.encounter_id) != "":
		body += "\nThreat signature: %s" % str(selected_room.encounter_id).to_upper()
	return body


func _refresh_combat_map_panel(selected_room) -> void:
	if _has_combat_map(selected_room):
		combat_map_name_label.text = str(selected_room.combat_map_name).to_upper()
		var details: Array[String] = []
		if str(selected_room.combat_map_id) != "":
			details.append("Chart ID %s" % str(selected_room.combat_map_id).to_upper())
		if str(selected_room.combat_map_theme) != "":
			details.append(str(selected_room.combat_map_theme))
		if str(selected_room.combat_map_summary) != "":
			details.append(str(selected_room.combat_map_summary))
		combat_map_summary_label.text = "\n".join(details)
		return

	combat_map_name_label.text = "NO COMBAT MAP PLANNED"
	if str(selected_room.room_type) == "shop":
		combat_map_summary_label.text = "Broker node. Use this branch to reset tempo before the next hostile chamber."
	elif str(selected_room.room_type) == "event":
		combat_map_summary_label.text = "Event node. This stop changes the run state without opening a combat arena."
	else:
		combat_map_summary_label.text = "Traversal anchor. Move deeper into the route graph to lock a combat arena."


func _count_combat_maps() -> int:
	if room_graph == null:
		return 0
	var count := 0
	for room_id in room_graph.rooms.keys():
		var room_state = room_graph.get_room(str(room_id))
		if _has_combat_map(room_state):
			count += 1
	return count


func _has_combat_map(room_state) -> bool:
	if room_state == null:
		return false
	return str(room_state.combat_map_name) != ""


func _refresh_primary_action(current_room, selected_room, is_paused: bool) -> void:
	primary_action_button.disabled = false
	primary_action_button.text = "Commit Route"

	var selected_id := str(selected_room.room_id)
	var current_id := str(current_room.room_id)

	if is_paused:
		primary_action_button.disabled = true
		primary_action_button.text = "Combat In Progress"
		return

	if selected_id == current_id:
		if str(current_room.encounter_id) != "":
			primary_action_button.text = "Enter Encounter  ·  %s" % str(current_room.encounter_id).to_upper()
			return
		primary_action_button.disabled = true
		primary_action_button.text = "No Encounter In Current Room"
		return

	if str(current_room.encounter_id) != "" and not current_room.completed:
		primary_action_button.disabled = true
		primary_action_button.text = "Resolve Current Encounter First"
		return

	if _is_neighbor(current_room, selected_id):
		primary_action_button.text = "Travel To  ·  %s" % str(selected_room.display_name).to_upper()
		return

	primary_action_button.disabled = true
	primary_action_button.text = "Select A Connected Node"


func _refresh_footer(current_room, selected_room, is_paused: bool) -> void:
	_set_chip_text(footer_left.get_node_or_null("FloorChip") as PanelContainer, "◆  FLOOR  %02d" % int(run_session.floor_index))
	_set_chip_text(footer_left.get_node_or_null("RoomChip") as PanelContainer, "ROOM  %s" % str(current_room.room_id).to_upper())
	_set_chip_text(footer_right.get_node_or_null("StateChip") as PanelContainer, "●  COMBAT" if is_paused else "●  EXPLORATION")

	var threat_label := "THREAT  LOW"
	if str(current_room.encounter_id) != "":
		threat_label = "THREAT  %s" % str(current_room.encounter_id).to_upper()
	elif current_room.completed:
		threat_label = "THREAT  CLEARED"
	_set_chip_text(footer_right.get_node_or_null("ThreatChip") as PanelContainer, threat_label)

	if str(selected_room.room_id) == str(current_room.room_id):
		footer_center.text = "Hold position and enter combat, or inspect the route map for your next branch."
	elif _is_neighbor(current_room, str(selected_room.room_id)):
		footer_center.text = "Route target locked: %s." % str(selected_room.display_name)
	else:
		footer_center.text = "Only connected nodes can be traversed from the current room."


func _room_color(room_state) -> Color:
	return ROOM_TYPE_COLORS.get(str(room_state.room_type), TEXT_PRIMARY)


func _is_neighbor(current_room, room_id: String) -> bool:
	return room_graph.get_neighbor_ids(str(current_room.room_id)).has(room_id)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if not primary_action_button.disabled:
			get_viewport().set_input_as_handled()
			_on_primary_action_pressed()


func _on_map_room_selected(room_id: String) -> void:
	_selected_room_id = room_id
	_refresh_view()


func _on_primary_action_pressed() -> void:
	if room_graph == null:
		return

	var current_room = room_graph.get_room(str(run_session.current_room_id))
	var selected_room = room_graph.get_room(_selected_room_id)
	if current_room == null or selected_room == null:
		return

	if str(selected_room.room_id) == str(current_room.room_id):
		_begin_selected_encounter(current_room)
		return

	if _is_neighbor(current_room, str(selected_room.room_id)):
		_move_to_selected_room(str(selected_room.room_id))


func _move_to_selected_room(room_id: String) -> void:
	var transition_result = game_state_coordinator.enter_room(room_id)
	if not transition_result.get("ok", false):
		encounter_status_label.text = "Room transition failed: %s" % transition_result.get("error", "unknown")
		return

	run_session = game_state_coordinator.current_session
	run_session.flags["encounter_status"] = "Route advanced into %s." % room_id
	_selected_room_id = room_id
	_build_room_graph()
	_refresh_view()


func _begin_selected_encounter(current_room) -> void:
	if str(current_room.encounter_id) == "":
		encounter_status_label.text = "No encounter is available in this room."
		return

	var encounter_result = game_state_coordinator.begin_encounter(current_room.encounter_id)
	if not encounter_result.get("ok", false):
		encounter_status_label.text = "Encounter handoff failed: %s" % encounter_result.get("error", "unknown")
		return

	run_session = game_state_coordinator.current_session
	run_session.flags["encounter_status"] = "Combat active: %s" % str(current_room.encounter_id)
	_build_room_graph()
	_refresh_view()
	encounter_started.emit(encounter_result.get("combat_state"))


func _format_room_type(room_type: String) -> String:
	match room_type:
		"start":
			return "Anchor"
		"encounter":
			return "Hostile"
		"event":
			return "Event"
		"boss":
			return "Boss"
		"shop":
			return "Broker"
		_:
			return room_type.capitalize()
