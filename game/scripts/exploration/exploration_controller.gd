extends Control

const RoomGraphScript = preload("res://scripts/exploration/room_graph.gd")
const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

# ---- Palette (matches start menu) ----
const ACCENT_BRIGHT := Color("6ebeff")
const ACCENT_GLOW := Color(0.43, 0.75, 1.0, 0.35)

const LINE_COLOR := Color(0.98, 0.98, 0.98, 0.08)
const LINE_STRONG := Color(0.98, 0.98, 0.98, 0.22)
const TEXT_PRIMARY := Color("e7e3da")
const TEXT_MUTED := Color("9ca6b2")
const TEXT_DIM := Color("73808d")
const TEXT_FAINT := Color("59636d")
const GOLD := Color("c6a85a")
const HUD_LIVE := Color(0.45, 0.85, 0.55)
const DANGER := Color("d28b7c")

signal session_updated(run_session)
signal encounter_started(combat_state)

@onready var content_column: VBoxContainer = $ContentColumn
@onready var kicker_label: Label = $ContentColumn/KickerRow/KickerLabel
@onready var kicker_line_left: ColorRect = $ContentColumn/KickerRow/KickerLineLeft
@onready var kicker_line_right: ColorRect = $ContentColumn/KickerRow/KickerLineRight
@onready var title_line1: Label = $ContentColumn/TitleLine1
@onready var room_name_label: Label = $ContentColumn/RoomNameLabel
@onready var subtitle_label: Label = $ContentColumn/SubtitleLabel
@onready var room_meta_label: Label = $ContentColumn/RoomMetaLabel
@onready var exits_header_label: Label = $ContentColumn/ExitsHeaderLabel
@onready var exits_container: VBoxContainer = $ContentColumn/ExitsContainer
@onready var encounter_button: Button = $ContentColumn/EncounterStrip/EncounterButton
@onready var encounter_status_label: Label = $ContentColumn/EncounterStatusLabel
@onready var frame_corners: Control = $FrameCorners
@onready var footer_left: HBoxContainer = $FooterHUD/FooterLeft
@onready var footer_right: HBoxContainer = $FooterHUD/FooterRight
@onready var footer_center: Label = $FooterHUD/FooterCenter
@onready var player = $RoomStage/Player

var content_catalog
var game_state_coordinator
var run_session
var room_graph

var _exit_rows: Array = []


func _ready() -> void:
	_apply_theme()
	_style_title_block()
	_build_frame_corners()
	_build_footer_hud()
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


# ---- Theme / typography ----

func _apply_theme() -> void:
	theme = FacetboundThemeScript.build()
	encounter_button.theme_type_variation = &"FacetPrimaryButton"


func _style_title_block() -> void:
	kicker_label.add_theme_font_size_override("font_size", 13)
	kicker_label.add_theme_color_override("font_color", TEXT_MUTED)

	kicker_line_left.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.85)
	kicker_line_right.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.3)

	title_line1.add_theme_font_size_override("font_size", 46)
	title_line1.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	title_line1.add_theme_constant_override("outline_size", 10)
	title_line1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	room_name_label.add_theme_font_size_override("font_size", 46)
	room_name_label.add_theme_color_override("font_color", ACCENT_BRIGHT)
	room_name_label.add_theme_constant_override("outline_size", 10)
	room_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", TEXT_MUTED)

	room_meta_label.add_theme_font_size_override("font_size", 14)
	room_meta_label.add_theme_color_override("font_color", TEXT_DIM)

	exits_header_label.add_theme_font_size_override("font_size", 12)
	exits_header_label.add_theme_color_override("font_color", Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.85))

	encounter_status_label.add_theme_font_size_override("font_size", 12)
	encounter_status_label.add_theme_color_override("font_color", TEXT_DIM)


# ---- Frame corners (mirrors start menu) ----

func _build_frame_corners() -> void:
	for child in frame_corners.get_children():
		child.queue_free()
	var inset := 36.0
	var length := 20.0
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


# ---- Footer HUD ----

func _build_footer_hud() -> void:
	for child in footer_left.get_children():
		child.queue_free()
	for child in footer_right.get_children():
		child.queue_free()

	var floor_chip := _make_chip("◆  FLOOR  —", HUD_LIVE, LINE_STRONG)
	floor_chip.name = "FloorChip"
	footer_left.add_child(floor_chip)

	var room_chip := _make_chip("ROOM  —", TEXT_DIM, LINE_STRONG)
	room_chip.name = "RoomChip"
	footer_left.add_child(room_chip)

	footer_center.add_theme_font_size_override("font_size", 12)
	footer_center.add_theme_color_override("font_color", TEXT_DIM)

	var status_chip := _make_chip("●  EXPLORATION", ACCENT_BRIGHT, Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.6))
	status_chip.name = "StatusChip"
	footer_right.add_child(status_chip)

	var threat_chip := _make_chip("THREAT  —", GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
	threat_chip.name = "ThreatChip"
	footer_right.add_child(threat_chip)


func _make_chip(text: String, color: Color = TEXT_DIM, border: Color = LINE_STRONG) -> PanelContainer:
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = border
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	wrap.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrap.add_child(lbl)

	return wrap


func _set_chip_text(node: PanelContainer, text: String) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Label:
			(child as Label).text = text
			return


# ---- Build room graph ----

func _build_room_graph() -> void:
	var room_graph_data = content_catalog.load_room_graph(str(run_session.room_graph_id))
	if room_graph_data is Dictionary and room_graph_data.get("error", "") != "":
		encounter_status_label.text = "Room graph failed to load: %s" % room_graph_data.get("error", "unknown")
		return

	var graph_payload: Dictionary = room_graph_data.duplicate(true)
	graph_payload["room_states"] = run_session.room_states.duplicate(true)
	room_graph = RoomGraphScript.new(graph_payload)


# ---- View refresh ----

func _refresh_view() -> void:
	if room_graph == null:
		return

	var current_room = room_graph.get_room(str(run_session.current_room_id))
	if current_room == null:
		return

	room_name_label.text = str(current_room.display_name).to_upper()

	var cleared_state := "CLEARED" if current_room.completed else "UNCLEARED"
	subtitle_label.text = "FLOOR  ·  %02d  ·  %s" % [int(run_session.floor_index), cleared_state]

	room_meta_label.text = "%s room · visited %d time%s" % [
		_format_room_type(current_room.room_type),
		current_room.visit_count,
		"" if current_room.visit_count == 1 else "s",
	]

	encounter_status_label.text = str(run_session.flags.get("encounter_status", "Explore the room shell and trigger the stub encounter."))
	var is_paused := str(run_session.flags.get("screen_state", "exploration")) != "exploration"
	encounter_button.disabled = current_room.encounter_id == "" or is_paused
	encounter_button.text = "Trigger Encounter"
	if current_room.encounter_id != "":
		encounter_button.text = "Trigger Encounter: %s" % current_room.encounter_id

	if player != null:
		player.global_position = Vector2(920, 408)

	_rebuild_exit_rows(current_room.room_id)
	_refresh_footer(current_room)
	session_updated.emit(run_session)


func _refresh_footer(current_room) -> void:
	_set_chip_text(footer_left.get_node_or_null("FloorChip") as PanelContainer,
		"◆  FLOOR  %02d" % int(run_session.floor_index))
	_set_chip_text(footer_left.get_node_or_null("RoomChip") as PanelContainer,
		"ROOM  %s" % str(current_room.room_id).to_upper())
	var state_node := footer_right.get_node_or_null("StatusChip") as PanelContainer
	var threat_node := footer_right.get_node_or_null("ThreatChip") as PanelContainer
	var is_paused := str(run_session.flags.get("screen_state", "exploration")) != "exploration"
	_set_chip_text(state_node, "●  COMBAT" if is_paused else "●  EXPLORATION")
	var threat_label := "THREAT  —"
	if current_room.encounter_id != "":
		threat_label = "THREAT  %s" % str(current_room.encounter_id).to_upper()
	elif current_room.completed:
		threat_label = "THREAT  CLEARED"
	_set_chip_text(threat_node, threat_label)


# ---- Stylized exit rows (mirrors start menu MenuRow) ----

func _rebuild_exit_rows(room_id: String) -> void:
	for child in exits_container.get_children():
		child.queue_free()
	_exit_rows.clear()

	var neighbor_ids: Array = room_graph.get_neighbor_ids(room_id)
	var is_paused := str(run_session.flags.get("screen_state", "exploration")) != "exploration"

	if neighbor_ids.is_empty():
		var empty := Label.new()
		empty.text = "No exits available."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", TEXT_DIM)
		exits_container.add_child(empty)
		return

	for i in range(neighbor_ids.size()):
		var neighbor_id: String = str(neighbor_ids[i])
		var room_state = room_graph.get_room(neighbor_id)
		if room_state == null:
			continue
		var row := _make_exit_row(i, room_state, is_paused)
		exits_container.add_child(row)
		row.pressed.connect(_on_move_pressed.bind(neighbor_id))

	var trailing := ColorRect.new()
	trailing.color = LINE_COLOR
	trailing.custom_minimum_size = Vector2(0, 1)
	trailing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exits_container.add_child(trailing)


func _make_exit_row(index: int, room_state, disabled: bool) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 44)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled

	var accent := bool(room_state.room_type == "boss")
	button.add_theme_stylebox_override("normal", _row_stylebox(false, accent))
	button.add_theme_stylebox_override("hover", _row_stylebox(true, accent))
	button.add_theme_stylebox_override("pressed", _row_stylebox(true, accent))
	button.add_theme_stylebox_override("focus", _row_stylebox(true, accent))
	button.add_theme_stylebox_override("disabled", _row_stylebox(false, false))

	var hbox := HBoxContainer.new()
	hbox.anchor_left = 0.0
	hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 12.0
	hbox.offset_top = 4.0
	hbox.offset_right = -14.0
	hbox.offset_bottom = -4.0
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	button.add_child(hbox)

	var idx_label := Label.new()
	idx_label.text = "%02d" % (index + 1)
	idx_label.custom_minimum_size = Vector2(36, 0)
	idx_label.add_theme_font_size_override("font_size", 14)
	idx_label.add_theme_color_override("font_color", ACCENT_BRIGHT if accent else TEXT_FAINT)
	idx_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(idx_label)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var lbl := Label.new()
	lbl.text = str(room_state.display_name)
	lbl.add_theme_font_size_override("font_size", 18)
	var label_color := ACCENT_BRIGHT if accent else TEXT_PRIMARY
	if disabled:
		label_color = TEXT_FAINT
	lbl.add_theme_color_override("font_color", label_color)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	vbox.add_child(lbl)

	var hint := Label.new()
	hint.text = _format_room_type(str(room_state.room_type)).to_upper()
	if room_state.completed:
		hint.text = hint.text + "  ·  CLEARED"
	elif room_state.visit_count > 0:
		hint.text = hint.text + "  ·  VISITED"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", ACCENT_BRIGHT if accent else TEXT_DIM)
	vbox.add_child(hint)

	var chip := _make_chip(_exit_chip_label(room_state), ACCENT_BRIGHT if accent else TEXT_DIM, LINE_STRONG)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(chip)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.custom_minimum_size = Vector2(28, 0)
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", ACCENT_BRIGHT if accent else TEXT_FAINT)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(arrow)

	_exit_rows.append({"button": button, "room_id": str(room_state.room_id)})
	return button


func _row_stylebox(hovered: bool, accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = true
	style.bg_color = Color(0, 0, 0, 0)
	if hovered:
		style.bg_color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.14 if accent else 0.08)
	style.border_color = ACCENT_BRIGHT if hovered else LINE_COLOR
	style.border_width_top = 1
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _exit_chip_label(room_state) -> String:
	match str(room_state.room_type):
		"boss":
			return "BOSS"
		"encounter":
			return "FIGHT"
		"shop":
			return "SHOP"
		"start":
			return "HUB"
		_:
			return str(room_state.room_type).to_upper()


# ---- Actions ----

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
