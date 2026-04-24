extends Control

signal room_selected(room_id: String)

const BG_PANEL := Color(0.03, 0.05, 0.08, 0.64)
const GRID_COLOR := Color(0.43, 0.75, 1.0, 0.08)
const LINK_LOCKED := Color(0.42, 0.49, 0.56, 0.2)
const LINK_REACHABLE := Color(0.43, 0.75, 1.0, 0.55)
const LINK_CURRENT := Color(0.78, 0.66, 0.35, 0.78)
const TEXT_PRIMARY := Color(0.92, 0.94, 1.0)
const TEXT_MUTED := Color(0.51, 0.58, 0.65)

const ROOM_COLORS := {
	"start": Color(0.58, 0.9, 0.82),
	"encounter": Color(0.43, 0.75, 1.0),
	"shop": Color(0.66, 0.85, 0.55),
	"boss": Color(0.84, 0.54, 0.48),
}

const ROOM_BUTTON_SIZE := 72.0
const MAP_PADDING := Vector2(92.0, 84.0)

var room_graph
var current_room_id := ""
var highlighted_room_id := ""
var paused := false
var _room_points: Dictionary = {}
var _refresh_queued := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_queue_refresh)


func set_graph(graph, active_room_id: String, paused_state: bool) -> void:
	room_graph = graph
	current_room_id = active_room_id
	if highlighted_room_id == "":
		highlighted_room_id = active_room_id
	paused = paused_state
	_queue_refresh()


func set_highlighted_room(room_id: String) -> void:
	highlighted_room_id = room_id
	_queue_refresh()


func get_highlighted_room_id() -> String:
	return highlighted_room_id


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_map")


func _refresh_map() -> void:
	_refresh_queued = false
	_rebuild_interactives()
	queue_redraw()


func _rebuild_interactives() -> void:
	for child in get_children():
		child.queue_free()

	_room_points.clear()
	if room_graph == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for room_id in room_graph.rooms.keys():
		var room_state = room_graph.get_room(str(room_id))
		if room_state == null:
			continue
		var point := _project_room_position(room_state.position)
		_room_points[str(room_id)] = point

		var button := Button.new()
		button.name = "RoomButton_%s" % str(room_id)
		button.text = ""
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(ROOM_BUTTON_SIZE, ROOM_BUTTON_SIZE)
		button.size = Vector2(ROOM_BUTTON_SIZE, ROOM_BUTTON_SIZE)
		button.position = point - button.size / 2.0
		button.add_theme_stylebox_override("normal", _button_stylebox(Color(0, 0, 0, 0)))
		button.add_theme_stylebox_override("hover", _button_stylebox(Color(0.43, 0.75, 1.0, 0.08)))
		button.add_theme_stylebox_override("pressed", _button_stylebox(Color(0.43, 0.75, 1.0, 0.12)))
		button.add_theme_stylebox_override("focus", _button_stylebox(Color(0.43, 0.75, 1.0, 0.16)))
		button.add_theme_stylebox_override("disabled", _button_stylebox(Color(0, 0, 0, 0)))
		button.tooltip_text = str(room_state.display_name)
		button.pressed.connect(_on_room_pressed.bind(str(room_id)))
		add_child(button)

		var label := Label.new()
		label.name = "RoomLabel_%s" % str(room_id)
		label.text = str(room_state.display_name).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", _label_color_for_room(room_state))
		label.position = Vector2(point.x - 80.0, point.y + 38.0)
		label.size = Vector2(160.0, 18.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)


func _button_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(36)
	return style


func _project_room_position(world_pos: Vector2) -> Vector2:
	if room_graph == null or room_graph.rooms.is_empty():
		return size / 2.0

	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for room_id in room_graph.rooms.keys():
		var room_state = room_graph.get_room(str(room_id))
		if room_state == null:
			continue
		min_pos.x = min(min_pos.x, room_state.position.x)
		min_pos.y = min(min_pos.y, room_state.position.y)
		max_pos.x = max(max_pos.x, room_state.position.x)
		max_pos.y = max(max_pos.y, room_state.position.y)

	var usable_size := size - MAP_PADDING * 2.0
	usable_size.x = max(usable_size.x, 1.0)
	usable_size.y = max(usable_size.y, 1.0)

	var bounds_size := max_pos - min_pos
	if bounds_size.x <= 0.0:
		bounds_size.x = 1.0
	if bounds_size.y <= 0.0:
		bounds_size.y = 1.0

	var normalized := Vector2(
		(world_pos.x - min_pos.x) / bounds_size.x,
		(world_pos.y - min_pos.y) / bounds_size.y
	)
	return MAP_PADDING + Vector2(normalized.x * usable_size.x, normalized.y * usable_size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_PANEL, true)
	_draw_grid()
	_draw_links()
	_draw_rooms()


func _draw_grid() -> void:
	for i in range(6):
		var x: float = lerp(MAP_PADDING.x, size.x - MAP_PADDING.x, float(i) / 5.0)
		draw_line(Vector2(x, MAP_PADDING.y - 26.0), Vector2(x, size.y - MAP_PADDING.y + 26.0), GRID_COLOR, 1.0)
	for i in range(5):
		var y: float = lerp(MAP_PADDING.y, size.y - MAP_PADDING.y, float(i) / 4.0)
		draw_line(Vector2(MAP_PADDING.x - 26.0, y), Vector2(size.x - MAP_PADDING.x + 26.0, y), GRID_COLOR, 1.0)


func _draw_links() -> void:
	if room_graph == null:
		return

	for room_id in room_graph.rooms.keys():
		var from_id := str(room_id)
		for neighbor_id in room_graph.get_neighbor_ids(from_id):
			if from_id >= neighbor_id:
				continue
			var from_point: Vector2 = _room_points.get(from_id, Vector2.ZERO)
			var to_point: Vector2 = _room_points.get(neighbor_id, Vector2.ZERO)
			var line_color := LINK_LOCKED
			if from_id == current_room_id or neighbor_id == current_room_id:
				line_color = LINK_REACHABLE
			if from_id == highlighted_room_id or neighbor_id == highlighted_room_id:
				line_color = line_color.lerp(LINK_CURRENT, 0.45)
			draw_line(from_point, to_point, line_color, 4.0, true)
			draw_circle((from_point + to_point) / 2.0, 4.0, Color(line_color.r, line_color.g, line_color.b, 0.7))


func _draw_rooms() -> void:
	if room_graph == null:
		return

	for room_id in room_graph.rooms.keys():
		var id := str(room_id)
		var room_state = room_graph.get_room(id)
		if room_state == null:
			continue
		var point: Vector2 = _room_points.get(id, Vector2.ZERO)
		var fill := _node_fill_color(room_state)
		var outline := _node_outline_color(room_state, id)
		var radius := 22.0
		if id == current_room_id:
			draw_circle(point, 34.0, Color(outline.r, outline.g, outline.b, 0.18))
			radius = 25.0
		elif id == highlighted_room_id:
			draw_circle(point, 30.0, Color(outline.r, outline.g, outline.b, 0.12))
			radius = 24.0

		draw_circle(point, radius, fill)
		draw_arc(point, radius + 2.0, 0.0, TAU, 48, outline, 3.0, true)
		if room_state.completed:
			draw_arc(point, radius + 9.0, -PI * 0.9, PI * 0.55, 32, Color(0.78, 0.66, 0.35, 0.85), 3.0, true)
		if id == current_room_id:
			draw_circle(point, 7.0, Color(1, 1, 1, 0.9))
		elif room_state.visit_count > 0:
			draw_circle(point, 5.0, Color(0.93, 0.91, 0.84, 0.75))


func _node_fill_color(room_state) -> Color:
	var base: Color = ROOM_COLORS.get(str(room_state.room_type), Color(0.35, 0.41, 0.48))
	if paused:
		base = base.darkened(0.25)
	if room_state.completed:
		return base.lerp(Color(0.78, 0.66, 0.35), 0.32)
	if room_state.visit_count > 0:
		return base.lerp(Color(0.88, 0.9, 0.94), 0.16)
	return base


func _node_outline_color(room_state, room_id: String) -> Color:
	if room_id == current_room_id:
		return Color(0.97, 0.82, 0.45)
	if room_id == highlighted_room_id:
		return Color(0.78, 0.88, 1.0)
	if room_state.completed:
		return Color(0.78, 0.66, 0.35, 0.9)
	return Color(1, 1, 1, 0.22)


func _label_color_for_room(room_state) -> Color:
	if room_state.completed:
		return Color(0.88, 0.84, 0.7)
	if room_state.visit_count > 0:
		return TEXT_PRIMARY
	return ROOM_COLORS.get(str(room_state.room_type), TEXT_MUTED)


func _on_room_pressed(room_id: String) -> void:
	highlighted_room_id = room_id
	queue_redraw()
	room_selected.emit(room_id)
