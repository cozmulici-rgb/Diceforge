extends Control

const FacetboundThemeScript = preload("res://scripts/ui/facetbound_theme.gd")

# ---- Palette (matches design) ----
const ACCENT_BRIGHT := Color("6ebeff")
const ACCENT_DEEP := Color("2b5dcc")
const ACCENT_GLOW := Color(0.43, 0.75, 1.0, 0.35)

const LINE_COLOR := Color(0.98, 0.98, 0.98, 0.08)
const LINE_STRONG := Color(0.98, 0.98, 0.98, 0.22)
const TEXT_PRIMARY := Color("e7e3da")
const TEXT_MUTED := Color("9ca6b2")
const TEXT_DIM := Color("73808d")
const TEXT_FAINT := Color("59636d")
const GOLD := Color("c6a85a")
const HUD_LIVE := Color(0.45, 0.85, 0.55)

# Dice palette
const CRYSTAL_BG := Color("0f1a2e")
const CRYSTAL_BG_EDGE := Color("192a49")
const CRYSTAL_BORDER := Color(0.2, 0.35, 0.6, 0.55)
const CRYSTAL_PIP := Color(0.55, 0.87, 1.0)

const BONE_BG := Color("d4c190")
const BONE_BG_EDGE := Color("b8a573")
const BONE_BORDER := Color(0.55, 0.48, 0.3, 0.6)
const BONE_PIP := Color(0.09, 0.07, 0.05)

const HEAVY_BG := Color("12151a")
const HEAVY_BG_EDGE := Color("1e2329")
const HEAVY_BORDER := Color(0.32, 0.38, 0.45, 0.55)
const HEAVY_PIP := Color(0.55, 0.87, 1.0)

const FLESH_BG := Color("3a0f12")
const FLESH_BG_EDGE := Color("4e1619")
const FLESH_BORDER := Color(0.55, 0.2, 0.22, 0.6)
const FLESH_PIP := Color(1.0, 0.34, 0.4)

signal run_requested(archetype_id: String)
signal daily_void_requested(archetype_id: String)
signal continue_runs_requested()

@onready var kicker_label: Label = $ContentColumn/KickerRow/KickerLabel
@onready var kicker_line_left: ColorRect = $ContentColumn/KickerRow/KickerLineLeft
@onready var kicker_line_right: ColorRect = $ContentColumn/KickerRow/KickerLineRight
@onready var title_line1: Label = $ContentColumn/TitleLine1
@onready var title_line2: Label = $ContentColumn/TitleLine2
@onready var subtitle_label: Label = $ContentColumn/SubtitleLabel
@onready var menu_list: VBoxContainer = $ContentColumn/MenuList
@onready var archetype_options: OptionButton = $ContentColumn/ArchetypeStrip/ArchetypeOptionButton
@onready var starter_label: Label = $ContentColumn/ArchetypeStrip/StarterLabel
@onready var summary_label: Label = $ContentColumn/SummaryLabel
@onready var dice_cluster: Control = $DiceCluster
@onready var frame_corners: Control = $FrameCorners
@onready var footer_left: HBoxContainer = $FooterHUD/FooterLeft
@onready var footer_right: HBoxContainer = $FooterHUD/FooterRight
@onready var footer_center: Label = $FooterHUD/FooterCenter

const MENU_ITEMS := [
	{"id": "new-run", "label": "New Run", "hint": "Enter the Void Labyrinth", "hotkey": "↵", "accent": true, "enabled": true},
	{"id": "continue", "label": "Continue", "hint": "Resume a saved run", "hotkey": "R", "accent": false, "enabled": false},
	{"id": "archetypes", "label": "Archetypes", "hint": "Choose your Facetwalker", "hotkey": "A", "accent": false, "enabled": true},
	{"id": "forge", "label": "Eternal Forge", "hint": "Spend Echo Shards", "hotkey": "F", "accent": false, "enabled": false},
	{"id": "daily", "label": "Daily Void", "hint": "Seeded challenge run", "hotkey": "D", "accent": false, "enabled": true},
	{"id": "settings", "label": "Settings", "hint": "Audio · Video · Controls", "hotkey": "S", "accent": false, "enabled": false},
	{"id": "credits", "label": "Credits", "hint": "The Facetwalkers", "hotkey": "C", "accent": false, "enabled": false},
	{"id": "quit", "label": "Quit", "hint": "Leave the labyrinth", "hotkey": "Q", "accent": false, "enabled": true},
]

# Dice constellation layout. (x, y) are fractions of DiceCluster rect.
const DICE_LAYOUT := [
	{"kind": "crystal", "face": 1, "size": 180, "rot": -8.0,  "x": 0.70, "y": 0.56},
	{"kind": "crystal", "face": 5, "size": 128, "rot": 14.0,  "x": 0.58, "y": 0.32},
	{"kind": "bone",    "face": 4, "size": 100, "rot": -18.0, "x": 0.76, "y": 0.30},
	{"kind": "crystal", "face": 2, "size": 82,  "rot": 7.0,   "x": 0.88, "y": 0.38},
	{"kind": "flesh",   "face": 1, "size": 95,  "rot": -12.0, "x": 0.92, "y": 0.56},
	{"kind": "crystal", "face": 6, "size": 110, "rot": 20.0,  "x": 0.70, "y": 0.78},
	{"kind": "heavy",   "face": 3, "size": 88,  "rot": -4.0,  "x": 0.60, "y": 0.82},
	{"kind": "bone",    "face": 2, "size": 64,  "rot": 12.0,  "x": 0.52, "y": 0.64},
	{"kind": "crystal", "face": 3, "size": 62,  "rot": -16.0, "x": 0.86, "y": 0.80},
]

var _archetypes: Array = []
var _resumable_summaries: Array = []
var _recovery_message := ""
var _last_daily_void_result: Dictionary = {}
var _shards_count := 0
var _menu_rows: Array = []


func _ready() -> void:
	_apply_theme()
	_style_title_block()
	_build_dice_cluster()
	_build_frame_corners()
	_build_menu_rows()
	_build_footer_hud()
	_style_archetype_strip()
	archetype_options.item_selected.connect(_on_archetype_selected)

	if _archetypes.is_empty():
		summary_label.text = "No starter archetypes are available."
		_set_menu_row_enabled("new-run", false)
		_set_menu_row_enabled("daily", false)


func _apply_theme() -> void:
	theme = FacetboundThemeScript.build()
	archetype_options.theme_type_variation = &"FacetOptionButton"
	summary_label.theme_type_variation = &"FacetBodyMuted"


func _style_title_block() -> void:
	kicker_label.add_theme_font_size_override("font_size", 13)
	kicker_label.add_theme_color_override("font_color", TEXT_MUTED)

	kicker_line_left.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.85)
	kicker_line_right.color = Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.3)

	title_line1.add_theme_font_size_override("font_size", 56)
	title_line1.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	title_line1.add_theme_constant_override("outline_size", 10)
	title_line1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	title_line2.add_theme_font_size_override("font_size", 56)
	title_line2.add_theme_color_override("font_color", ACCENT_BRIGHT)
	title_line2.add_theme_constant_override("outline_size", 10)
	title_line2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", TEXT_MUTED)


func configure(archetypes: Array, resumable_summaries: Array = [], recovery_message: String = "", last_daily_void_result: Dictionary = {}, shards_count: int = 0) -> void:
	_archetypes = archetypes.duplicate(true)
	_resumable_summaries = resumable_summaries.duplicate(true)
	_recovery_message = recovery_message
	_last_daily_void_result = last_daily_void_result.duplicate(true)
	_shards_count = shards_count
	if not is_node_ready():
		await ready

	archetype_options.clear()
	for index in range(_archetypes.size()):
		var archetype: Dictionary = _archetypes[index]
		archetype_options.add_item(str(archetype.get("name", archetype.get("id", "Unknown"))), index)

	var has_archetypes := not _archetypes.is_empty()
	_set_menu_row_enabled("new-run", has_archetypes)
	_set_menu_row_enabled("daily", has_archetypes)
	_set_menu_row_enabled("continue", _resumable_summaries.size() > 0)

	_refresh_shards()
	_update_summary()


# ---- Dice cluster ----

func _build_dice_cluster() -> void:
	for child in dice_cluster.get_children():
		child.queue_free()
	for params in DICE_LAYOUT:
		var die := _make_die(params)
		dice_cluster.add_child(die)


func _make_die(params: Dictionary) -> Control:
	var kind: String = str(params.get("kind", "crystal"))
	var face: int = int(params.get("face", 1))
	var size_px: float = float(params.get("size", 80))
	var rot_deg: float = float(params.get("rot", 0.0))
	var ax: float = float(params.get("x", 0.5))
	var ay: float = float(params.get("y", 0.5))

	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.anchor_left = ax
	wrap.anchor_top = ay
	wrap.anchor_right = ax
	wrap.anchor_bottom = ay
	wrap.offset_left = -size_px * 0.5
	wrap.offset_top = -size_px * 0.5
	wrap.offset_right = size_px * 0.5
	wrap.offset_bottom = size_px * 0.5
	wrap.pivot_offset = Vector2(size_px * 0.5, size_px * 0.5)
	wrap.rotation = deg_to_rad(rot_deg)

	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0
	glow.anchor_top = 0
	glow.anchor_right = 1
	glow.anchor_bottom = 1
	glow.offset_left = -size_px * 0.25
	glow.offset_top = -size_px * 0.2
	glow.offset_right = size_px * 0.25
	glow.offset_bottom = size_px * 0.3
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.shadow_color = _pip_glow_color(kind)
	glow_style.shadow_size = int(size_px * 0.35)
	glow_style.corner_radius_top_left = int(size_px * 0.3)
	glow_style.corner_radius_top_right = int(size_px * 0.3)
	glow_style.corner_radius_bottom_right = int(size_px * 0.3)
	glow_style.corner_radius_bottom_left = int(size_px * 0.3)
	glow.add_theme_stylebox_override("panel", glow_style)
	wrap.add_child(glow)

	var face_panel := Panel.new()
	face_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_panel.anchor_left = 0
	face_panel.anchor_top = 0
	face_panel.anchor_right = 1
	face_panel.anchor_bottom = 1
	face_panel.add_theme_stylebox_override("panel", _die_face_stylebox(kind, size_px))
	wrap.add_child(face_panel)

	var highlight := Panel.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.anchor_left = 0
	highlight.anchor_top = 0
	highlight.anchor_right = 1
	highlight.anchor_bottom = 0.5
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(1, 1, 1, 0.04)
	hl_style.corner_radius_top_left = int(size_px * 0.12)
	hl_style.corner_radius_top_right = int(size_px * 0.12)
	highlight.add_theme_stylebox_override("panel", hl_style)
	face_panel.add_child(highlight)

	for pip_pos in _pip_positions(face):
		var pip := _make_pip(kind, size_px)
		pip.anchor_left = pip_pos.x
		pip.anchor_top = pip_pos.y
		pip.anchor_right = pip_pos.x
		pip.anchor_bottom = pip_pos.y
		var pip_half: float = size_px * 0.075
		pip.offset_left = -pip_half
		pip.offset_top = -pip_half
		pip.offset_right = pip_half
		pip.offset_bottom = pip_half
		face_panel.add_child(pip)

	return wrap


func _die_face_stylebox(kind: String, size_px: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match kind:
		"crystal":
			style.bg_color = CRYSTAL_BG
			style.border_color = CRYSTAL_BORDER
		"bone":
			style.bg_color = BONE_BG
			style.border_color = BONE_BORDER
		"heavy":
			style.bg_color = HEAVY_BG
			style.border_color = HEAVY_BORDER
		"flesh":
			style.bg_color = FLESH_BG
			style.border_color = FLESH_BORDER
		_:
			style.bg_color = CRYSTAL_BG
			style.border_color = CRYSTAL_BORDER
	style.set_border_width_all(max(1, int(size_px * 0.02)))
	var radius := int(size_px * 0.12)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = int(size_px * 0.08)
	style.shadow_offset = Vector2(0, size_px * 0.04)
	return style


func _make_pip(kind: String, size_px: float) -> Panel:
	var pip := Panel.new()
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = _pip_color(kind)
	if kind != "bone":
		style.shadow_color = _pip_glow_color(kind)
		style.shadow_size = int(size_px * 0.06)
	var r: int = max(4, int(size_px * 0.075))
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_right = r
	style.corner_radius_bottom_left = r
	pip.add_theme_stylebox_override("panel", style)
	return pip


func _pip_color(kind: String) -> Color:
	match kind:
		"bone": return BONE_PIP
		"flesh": return FLESH_PIP
		"heavy": return HEAVY_PIP
		_: return CRYSTAL_PIP


func _pip_glow_color(kind: String) -> Color:
	match kind:
		"flesh": return Color(1.0, 0.35, 0.4, 0.45)
		"bone": return Color(0, 0, 0, 0)
		_: return Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.5)


func _pip_positions(face: int) -> Array:
	match face:
		1: return [Vector2(0.5, 0.5)]
		2: return [Vector2(0.28, 0.28), Vector2(0.72, 0.72)]
		3: return [Vector2(0.28, 0.28), Vector2(0.5, 0.5), Vector2(0.72, 0.72)]
		4: return [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)]
		5: return [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.5, 0.5), Vector2(0.28, 0.72), Vector2(0.72, 0.72)]
		6: return [Vector2(0.28, 0.25), Vector2(0.72, 0.25), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.28, 0.75), Vector2(0.72, 0.75)]
		_: return [Vector2(0.5, 0.5)]


# ---- Frame corners ----

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


# ---- Menu rows ----

func _build_menu_rows() -> void:
	for child in menu_list.get_children():
		child.queue_free()
	_menu_rows.clear()

	for i in range(MENU_ITEMS.size()):
		var item: Dictionary = MENU_ITEMS[i]
		var row := _make_menu_row(i, item)
		menu_list.add_child(row)

	var trailing := ColorRect.new()
	trailing.color = LINE_COLOR
	trailing.custom_minimum_size = Vector2(0, 1)
	trailing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_list.add_child(trailing)


func _make_menu_row(index: int, item: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 42)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var enabled: bool = bool(item.get("enabled", true))
	var accent: bool = bool(item.get("accent", false))
	button.disabled = not enabled

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
	lbl.text = str(item.get("label", ""))
	lbl.add_theme_font_size_override("font_size", 18)
	var label_color := ACCENT_BRIGHT if accent else TEXT_PRIMARY
	if not enabled:
		label_color = TEXT_FAINT
	lbl.add_theme_color_override("font_color", label_color)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	vbox.add_child(lbl)

	var hint := Label.new()
	var hint_text := str(item.get("hint", ""))
	if not enabled:
		hint_text = "COMING SOON"
	hint.text = hint_text.to_upper()
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", ACCENT_BRIGHT if accent else TEXT_DIM)
	vbox.add_child(hint)

	var hotkey_chip := _make_chip(str(item.get("hotkey", "")), ACCENT_BRIGHT if accent else TEXT_DIM, LINE_STRONG)
	hotkey_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(hotkey_chip)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.custom_minimum_size = Vector2(28, 0)
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", ACCENT_BRIGHT if accent else TEXT_FAINT)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(arrow)

	button.pressed.connect(_on_menu_pressed.bind(str(item.get("id", ""))))

	_menu_rows.append({
		"id": str(item.get("id", "")),
		"button": button,
		"label_node": lbl,
		"hint_node": hint,
		"idx_node": idx_label,
		"arrow_node": arrow,
		"accent": accent,
		"hint_active": str(item.get("hint", "")).to_upper(),
	})
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


func _set_menu_row_enabled(id: String, enabled: bool) -> void:
	for row_data in _menu_rows:
		if row_data.get("id", "") != id:
			continue
		var btn: Button = row_data.get("button")
		if btn:
			btn.disabled = not enabled
		var accent: bool = bool(row_data.get("accent", false))
		var label_node: Label = row_data.get("label_node")
		var hint_node: Label = row_data.get("hint_node")
		var idx_node: Label = row_data.get("idx_node")
		var arrow_node: Label = row_data.get("arrow_node")
		var label_color: Color = (ACCENT_BRIGHT if accent else TEXT_PRIMARY) if enabled else TEXT_FAINT
		var hint_color: Color = (ACCENT_BRIGHT if accent else TEXT_DIM) if enabled else TEXT_FAINT
		var idx_color: Color = (ACCENT_BRIGHT if accent else TEXT_FAINT) if enabled else TEXT_FAINT
		var arrow_color: Color = (ACCENT_BRIGHT if accent else TEXT_FAINT) if enabled else TEXT_FAINT
		if label_node:
			label_node.add_theme_color_override("font_color", label_color)
		if hint_node:
			hint_node.add_theme_color_override("font_color", hint_color)
			var active_hint: String = str(row_data.get("hint_active", ""))
			hint_node.text = active_hint if enabled else "COMING SOON"
		if idx_node:
			idx_node.add_theme_color_override("font_color", idx_color)
		if arrow_node:
			arrow_node.add_theme_color_override("font_color", arrow_color)


# ---- Archetype strip ----

func _style_archetype_strip() -> void:
	starter_label.add_theme_font_size_override("font_size", 12)
	starter_label.add_theme_color_override("font_color", Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.85))

	summary_label.add_theme_font_size_override("font_size", 12)
	summary_label.add_theme_color_override("font_color", TEXT_DIM)


func _on_archetype_selected(_index: int) -> void:
	_update_summary()


# ---- Footer HUD ----

func _build_footer_hud() -> void:
	for child in footer_left.get_children():
		child.queue_free()
	for child in footer_right.get_children():
		child.queue_free()

	var version_chip := _make_chip("●  v0.4.2  ·  BRITTLE CROWN", HUD_LIVE, LINE_STRONG)
	footer_left.add_child(version_chip)

	var build_chip := _make_chip("BUILD 20260420", TEXT_DIM, LINE_STRONG)
	footer_left.add_child(build_chip)

	footer_center.add_theme_font_size_override("font_size", 12)
	footer_center.add_theme_color_override("font_color", TEXT_DIM)

	var shards_chip := _make_chip("◆  0  ECHO SHARDS", GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
	shards_chip.name = "ShardsChip"
	footer_right.add_child(shards_chip)

	var tweaks_chip := _make_chip("⚙  TWEAKS", ACCENT_BRIGHT, Color(ACCENT_BRIGHT.r, ACCENT_BRIGHT.g, ACCENT_BRIGHT.b, 0.6))
	tweaks_chip.name = "TweaksChip"
	footer_right.add_child(tweaks_chip)


func _first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
	return null


func _refresh_shards() -> void:
	var chip := footer_right.get_node_or_null("ShardsChip") as PanelContainer
	if chip == null:
		return
	var lbl := _first_label(chip)
	if lbl == null:
		return
	lbl.text = "◆  %s  ECHO SHARDS" % _format_shards(_shards_count)


func _format_shards(value: int) -> String:
	var s := str(value)
	if value < 1000:
		return s
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


# ---- Menu actions ----

func _on_menu_pressed(id: String) -> void:
	match id:
		"new-run":
			_trigger_run()
		"continue":
			continue_runs_requested.emit()
		"archetypes":
			archetype_options.grab_focus()
			if _archetypes.size() > 1:
				archetype_options.show_popup()
		"daily":
			_trigger_daily_void()
		"quit":
			get_tree().quit()
		_:
			pass


func _trigger_run() -> void:
	var selected := _get_selected_archetype()
	if selected.is_empty():
		return
	run_requested.emit(str(selected.get("id", "")))


func _trigger_daily_void() -> void:
	var selected := _get_selected_archetype()
	if selected.is_empty():
		return
	daily_void_requested.emit(str(selected.get("id", "")))


func _get_selected_archetype() -> Dictionary:
	if _archetypes.is_empty():
		return {}
	var selected_index: int = archetype_options.get_selected()
	if selected_index < 0 or selected_index >= _archetypes.size():
		selected_index = 0
	return _archetypes[selected_index]


func _update_summary() -> void:
	var selected := _get_selected_archetype()
	if selected.is_empty():
		summary_label.text = "No starter archetypes are available."
		return

	var parts: Array[String] = []
	parts.append("Starter floor: %s  |  HP: %s  |  Dice: %d" % [
		str(selected.get("starter_floor_id", "unknown")),
		str((selected.get("player_state", {}) as Dictionary).get("hp", 0)),
		(selected.get("starter_dice", []) as Array).size(),
	])
	if _resumable_summaries.size() > 0:
		parts.append("%d saved run(s) available — open Continue to resume." % _resumable_summaries.size())
	if _recovery_message != "":
		parts.append("Recovery: %s" % _recovery_message)
	if not _last_daily_void_result.is_empty():
		parts.append("Daily Void: %s · Score %d · %s" % [
			str(_last_daily_void_result.get("seed_id", "")),
			int(_last_daily_void_result.get("score", 0)),
			str(_last_daily_void_result.get("submission_status", "not_attempted")),
		])
	summary_label.text = "\n".join(parts)


# ---- Hotkeys ----

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		return
	var key_to_id := {
		KEY_ENTER: "new-run",
		KEY_KP_ENTER: "new-run",
		KEY_R: "continue",
		KEY_A: "archetypes",
		KEY_F: "forge",
		KEY_D: "daily",
		KEY_S: "settings",
		KEY_C: "credits",
		KEY_Q: "quit",
	}
	if not key_to_id.has(key_event.keycode):
		return
	var id: String = key_to_id[key_event.keycode]
	for row_data in _menu_rows:
		if row_data.get("id", "") == id:
			var btn: Button = row_data.get("button")
			if btn and not btn.disabled:
				get_viewport().set_input_as_handled()
				_on_menu_pressed(id)
			return
