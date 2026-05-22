class_name DiceforgeTheme
extends Node

const BG_DEEP := Color("0b0f14")
const BG_PANEL := Color("141a21")
const BG_PANEL_ALT := Color("1a222b")

const ACCENT_GOLD := Color("c6a85a")
const ACCENT_GOLD_DIM := Color("8d7440")
const ACCENT_CYAN := Color("8fd3ff")
const ACCENT_CYAN_DIM := Color("4e7c96")
const ACCENT_RED := Color("a84a3a")

const TEXT_PRIMARY := Color("e7e3da")
const TEXT_SECONDARY := Color("9ca6b2")
const TEXT_MUTED := Color("73808d")
const TEXT_DISABLED := Color("59636d")

const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)


static func build() -> Theme:
	var theme := Theme.new()
	_add_fonts(theme)
	_add_constants(theme)
	_add_panel_styles(theme)
	_add_button_styles(theme)
	_add_label_styles(theme)
	_add_line_edit_styles(theme)
	_add_option_button_styles(theme)
	_add_scroll_styles(theme)
	_add_misc(theme)
	return theme


static func _add_fonts(theme: Theme) -> void:
	var cinzel := _load_font("res://assets/fonts/Cinzel.ttf")
	var philosopher := _load_font("res://assets/fonts/Philosopher-Regular.ttf")
	var philosopher_bold := _load_font("res://assets/fonts/Philosopher-Bold.ttf")

	var body_font: Font = philosopher if philosopher else ThemeDB.fallback_font
	var display_font: Font = cinzel if cinzel else ThemeDB.fallback_font

	theme.set_default_font(body_font)
	theme.set_default_font_size(18)

	for type_name in ["Label", "Button", "LineEdit", "OptionButton", "RichTextLabel"]:
		theme.set_font("font", type_name, body_font)

	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 20)
	theme.set_font_size("font_size", "LineEdit", 18)
	theme.set_font_size("font_size", "OptionButton", 18)
	theme.set_font_size("font_size", "RichTextLabel", 18)

	theme.set_font("font", "FacetTitle", display_font)
	for label_type in ["FacetSubtitle", "FacetSectionLabel", "FacetBodyMuted", "FacetMeta", "FacetDanger", "FacetInfo"]:
		theme.set_font("font", label_type, body_font)

	theme.set_font("font", "FacetSectionLabel", philosopher_bold if philosopher_bold else body_font)

	theme.set_font_size("font_size", "FacetTitle", 40)
	theme.set_font_size("font_size", "FacetSubtitle", 18)
	theme.set_font_size("font_size", "FacetSectionLabel", 14)
	theme.set_font_size("font_size", "FacetBodyMuted", 18)
	theme.set_font_size("font_size", "FacetMeta", 16)
	theme.set_font_size("font_size", "FacetDanger", 16)
	theme.set_font_size("font_size", "FacetInfo", 16)

	theme.set_font("font", "FacetPrimaryButton", philosopher_bold if philosopher_bold else body_font)
	theme.set_font("font", "FacetSecondaryButton", body_font)
	theme.set_font("font", "FacetTertiaryButton", body_font)


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func _add_constants(theme: Theme) -> void:
	theme.set_constant("h_separation", "BoxContainer", 12)
	theme.set_constant("v_separation", "BoxContainer", 12)

	theme.set_constant("margin_left", "MarginContainer", 24)
	theme.set_constant("margin_top", "MarginContainer", 24)
	theme.set_constant("margin_right", "MarginContainer", 24)
	theme.set_constant("margin_bottom", "MarginContainer", 24)

	theme.set_constant("outline_size", "Label", 8)
	theme.set_color("font_outline_color", "Label", Color(0.03, 0.04, 0.05, 0.85))
	theme.set_color("font_shadow_color", "Label", SHADOW)
	theme.set_constant("shadow_outline_size", "Label", 2)
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)


static func _add_panel_styles(theme: Theme) -> void:
	var panel := _make_panel_style(BG_PANEL, ACCENT_GOLD_DIM, 2, 18, 18, 18, 18)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var card := _make_panel_style(Color("10161d"), ACCENT_GOLD, 2, 24, 24, 24, 24)
	theme.set_stylebox("panel", "FacetCard", card)

	var info := _make_panel_style(BG_PANEL_ALT, ACCENT_CYAN_DIM, 2, 18, 16, 18, 16)
	theme.set_stylebox("panel", "InfoPanel", info)

	var warning := _make_strip_style(Color("241915"), ACCENT_RED, 2, 14, 10, 14, 10)
	theme.set_stylebox("panel", "WarningStrip", warning)

	var recovery := _make_strip_style(Color("211c12"), ACCENT_GOLD, 2, 14, 10, 14, 10)
	theme.set_stylebox("panel", "RecoveryStrip", recovery)

	var status := _make_strip_style(Color("121a20"), ACCENT_CYAN, 2, 14, 10, 14, 10)
	theme.set_stylebox("panel", "StatusStrip", status)


static func _add_button_styles(theme: Theme) -> void:
	var primary_normal := _make_button_style(Color("2a2112"), ACCENT_GOLD, 3)
	var primary_hover := _make_button_style(Color("3a2d16"), Color("e0c16c"), 3)
	var primary_pressed := _make_button_style(Color("221a0d"), Color("a98b4b"), 3)
	var primary_disabled := _make_button_style(Color("1a1b1d"), Color("49505a"), 2)

	theme.set_stylebox("normal", "FacetPrimaryButton", primary_normal)
	theme.set_stylebox("hover", "FacetPrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "FacetPrimaryButton", primary_pressed)
	theme.set_stylebox("disabled", "FacetPrimaryButton", primary_disabled)
	theme.set_stylebox("focus", "FacetPrimaryButton", _make_focus_style(ACCENT_GOLD))
	theme.set_color("font_color", "FacetPrimaryButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "FacetPrimaryButton", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "FacetPrimaryButton", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "FacetPrimaryButton", TEXT_DISABLED)
	theme.set_color("font_outline_color", "FacetPrimaryButton", Color(0.0, 0.0, 0.0, 0.7))
	theme.set_constant("outline_size", "FacetPrimaryButton", 8)

	var special_normal := _make_button_style(Color("131c24"), ACCENT_CYAN, 2)
	var special_hover := _make_button_style(Color("17222b"), Color("b5e6ff"), 2)
	var special_pressed := _make_button_style(Color("10171d"), ACCENT_CYAN_DIM, 2)
	var special_disabled := _make_button_style(Color("1a1b1d"), Color("49505a"), 2)

	theme.set_stylebox("normal", "FacetSecondaryButton", special_normal)
	theme.set_stylebox("hover", "FacetSecondaryButton", special_hover)
	theme.set_stylebox("pressed", "FacetSecondaryButton", special_pressed)
	theme.set_stylebox("disabled", "FacetSecondaryButton", special_disabled)
	theme.set_stylebox("focus", "FacetSecondaryButton", _make_focus_style(ACCENT_CYAN))
	theme.set_color("font_color", "FacetSecondaryButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "FacetSecondaryButton", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "FacetSecondaryButton", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "FacetSecondaryButton", TEXT_DISABLED)

	var neutral_normal := _make_button_style(Color("1a2027"), Color("56616d"), 2)
	var neutral_hover := _make_button_style(Color("222932"), Color("7a8796"), 2)
	var neutral_pressed := _make_button_style(Color("161b21"), Color("4f5966"), 2)
	var neutral_disabled := _make_button_style(Color("17191b"), Color("42474d"), 1)

	theme.set_stylebox("normal", "FacetTertiaryButton", neutral_normal)
	theme.set_stylebox("hover", "FacetTertiaryButton", neutral_hover)
	theme.set_stylebox("pressed", "FacetTertiaryButton", neutral_pressed)
	theme.set_stylebox("disabled", "FacetTertiaryButton", neutral_disabled)
	theme.set_stylebox("focus", "FacetTertiaryButton", _make_focus_style(ACCENT_GOLD_DIM))
	theme.set_color("font_color", "FacetTertiaryButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "FacetTertiaryButton", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "FacetTertiaryButton", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "FacetTertiaryButton", TEXT_DISABLED)

	theme.set_stylebox("normal", "Button", neutral_normal)
	theme.set_stylebox("hover", "Button", neutral_hover)
	theme.set_stylebox("pressed", "Button", neutral_pressed)
	theme.set_stylebox("disabled", "Button", neutral_disabled)
	theme.set_stylebox("focus", "Button", _make_focus_style(ACCENT_GOLD_DIM))
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)


static func _add_label_styles(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT_PRIMARY)

	theme.set_color("font_color", "FacetTitle", TEXT_PRIMARY)
	theme.set_color("font_outline_color", "FacetTitle", Color(0.02, 0.02, 0.03, 0.9))
	theme.set_constant("outline_size", "FacetTitle", 12)

	theme.set_color("font_color", "FacetSubtitle", TEXT_SECONDARY)
	theme.set_color("font_color", "FacetSectionLabel", ACCENT_GOLD)
	theme.set_color("font_color", "FacetBodyMuted", TEXT_SECONDARY)
	theme.set_color("font_color", "FacetMeta", TEXT_MUTED)
	theme.set_color("font_color", "FacetDanger", Color("d28b7c"))
	theme.set_color("font_color", "FacetInfo", Color("b6e5ff"))


static func _add_line_edit_styles(theme: Theme) -> void:
	var normal := _make_input_style(Color("10161c"), Color("27313b"))
	var focus := _make_input_style(Color("111921"), Color("395365"))
	var read_only := _make_input_style(Color("171a1f"), Color("252a31"))

	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", read_only)
	theme.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	theme.set_color("font_uneditable_color", "LineEdit", TEXT_DISABLED)
	theme.set_constant("minimum_character_width", "LineEdit", 1)


static func _add_option_button_styles(theme: Theme) -> void:
	var normal := _make_button_style(Color("121920"), ACCENT_GOLD_DIM, 2)
	var hover := _make_button_style(Color("17202a"), ACCENT_GOLD, 2)
	var pressed := _make_button_style(Color("10161c"), ACCENT_GOLD_DIM, 2)

	theme.set_stylebox("normal", "FacetOptionButton", normal)
	theme.set_stylebox("hover", "FacetOptionButton", hover)
	theme.set_stylebox("pressed", "FacetOptionButton", pressed)
	theme.set_stylebox("focus", "FacetOptionButton", _make_focus_style(ACCENT_GOLD))
	theme.set_color("font_color", "FacetOptionButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "FacetOptionButton", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "FacetOptionButton", TEXT_PRIMARY)
	theme.set_font("font", "FacetOptionButton", ThemeDB.fallback_font)
	theme.set_font_size("font_size", "FacetOptionButton", 18)

	theme.set_stylebox("normal", "OptionButton", normal)
	theme.set_stylebox("hover", "OptionButton", hover)
	theme.set_stylebox("pressed", "OptionButton", pressed)
	theme.set_stylebox("focus", "OptionButton", _make_focus_style(ACCENT_GOLD))
	theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "OptionButton", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "OptionButton", TEXT_PRIMARY)


static func _add_scroll_styles(theme: Theme) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("2b333d")
	grabber.border_color = ACCENT_GOLD_DIM
	grabber.set_corner_radius_all(4)
	grabber.set_border_width_all(1)

	var grabber_hover := grabber.duplicate()
	grabber_hover.bg_color = Color("353f4a")
	grabber_hover.border_color = ACCENT_GOLD

	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color("0e1318")
	scroll.border_color = Color("1d252d")
	scroll.set_border_width_all(1)
	scroll.set_corner_radius_all(4)

	for type_name in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type_name, scroll)
		theme.set_stylebox("scroll_focus", type_name, scroll)
		theme.set_stylebox("grabber", type_name, grabber)
		theme.set_stylebox("grabber_highlight", type_name, grabber_hover)


static func _add_misc(theme: Theme) -> void:
	theme.set_color("default_color", "RichTextLabel", TEXT_PRIMARY)
	theme.set_color("font_selected_color", "RichTextLabel", TEXT_PRIMARY)
	theme.set_color("selection_color", "RichTextLabel", Color(0.25, 0.36, 0.46, 0.65))

	var tooltip := _make_panel_style(Color("10161c"), ACCENT_CYAN_DIM, 1, 12, 10, 12, 10)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)


static func _make_panel_style(bg: Color, border: Color, border_width: int, left_pad: int, top_pad: int, right_pad: int, bottom_pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.shadow_color = SHADOW
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = left_pad
	style.content_margin_top = top_pad
	style.content_margin_right = right_pad
	style.content_margin_bottom = bottom_pad
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	style.draw_center = true
	return style


static func _make_strip_style(bg: Color, border: Color, border_width: int, left_pad: int, top_pad: int, right_pad: int, bottom_pad: int) -> StyleBoxFlat:
	var style := _make_panel_style(bg, border, border_width, left_pad, top_pad, right_pad, bottom_pad)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_size = 3
	return style


static func _make_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 20
	style.content_margin_top = 14
	style.content_margin_right = 20
	style.content_margin_bottom = 14
	style.shadow_color = SHADOW
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


static func _make_focus_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.expand_margin_left = 3
	style.expand_margin_top = 3
	style.expand_margin_right = 3
	style.expand_margin_bottom = 3
	return style


static func _make_input_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style
