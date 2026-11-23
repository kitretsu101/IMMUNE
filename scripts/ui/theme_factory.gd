class_name ThemeFactory
extends RefCounted
## Builds the dark neon Theme in code so the colour system stays in Neon.

static var _cached: Theme


static func get_theme() -> Theme:
	if _cached == null:
		_cached = _build()
	return _cached


static func box(fill: Color, border: Color, radius := 8, border_width := 1, glow := 0.0, glow_size := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if glow > 0.0:
		style.shadow_color = Color(border.r, border.g, border.b, glow)
		style.shadow_size = glow_size
	style.anti_aliasing = true
	return style


static func _build() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Rajdhani", "Exo 2", "Inter", "Segoe UI", "Noto Sans", "DejaVu Sans", "Sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 0.0
	theme.default_font = font
	theme.default_font_size = 16
	for type in ["Label", "RichTextLabel", "Button", "CheckBox", "CheckButton", "LineEdit", "OptionButton", "TabContainer", "SpinBox"]:
		theme.set_color("font_color", type, Neon.TEXT)
	theme.set_color("font_color", "Label", Neon.TEXT)
	theme.set_color("default_color", "RichTextLabel", Neon.TEXT)
	_buttons(theme)
	_containers(theme)
	_inputs(theme)
	_tabs(theme)
	_bars(theme)
	theme.set_stylebox("panel", "PopupMenu", box(Neon.PANEL_SOLID, Neon.BORDER_STRONG, 8))
	theme.set_stylebox("hover", "PopupMenu", box(Color(0.1, 0.25, 0.35, 0.9), Color(0, 0, 0, 0), 4))
	theme.set_color("font_color", "PopupMenu", Neon.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Neon.CYAN)
	theme.set_stylebox("panel", "TooltipPanel", box(Neon.PANEL_SOLID, Neon.BORDER_STRONG, 6))
	theme.set_color("font_color", "TooltipLabel", Neon.TEXT)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme


static func _buttons(theme: Theme) -> void:
	var normal := box(Color(0.03, 0.055, 0.13, 0.92), Color(0.45, 0.55, 0.8, 0.35), 8)
	var hover := box(Color(0.07, 0.16, 0.26, 0.96), Neon.CYAN, 8, 1, 0.45, 10)
	var pressed := box(Color(0.1, 0.3, 0.42, 1.0), Neon.CYAN, 8, 2, 0.6, 12)
	var disabled := box(Color(0.04, 0.06, 0.11, 0.6), Color(0.2, 0.25, 0.35, 0.4), 8)
	var focus := box(Color(0, 0, 0, 0), Neon.PURPLE, 8, 2, 0.5, 6)
	for type in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, Neon.TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Neon.CYAN)
		theme.set_color("font_hover_pressed_color", type, Neon.CYAN)
		theme.set_color("font_disabled_color", type, Neon.TEXT_DIM)
	var accent := box(Color(0.04, 0.2, 0.3, 0.95), Neon.CYAN, 8, 1, 0.35, 10)
	var accent_hover := box(Color(0.08, 0.38, 0.5, 1.0), Color.WHITE, 8, 1, 0.7, 14)
	theme.set_type_variation("AccentButton", "Button")
	theme.set_stylebox("normal", "AccentButton", accent)
	theme.set_stylebox("hover", "AccentButton", accent_hover)
	theme.set_stylebox("pressed", "AccentButton", pressed)
	theme.set_color("font_color", "AccentButton", Color.WHITE)
	var danger := box(Color(0.25, 0.05, 0.1, 0.92), Neon.RED, 8, 1, 0.3, 8)
	var danger_hover := box(Color(0.38, 0.07, 0.14, 1.0), Color(1, 0.6, 0.65), 8, 1, 0.6, 12)
	theme.set_type_variation("DangerButton", "Button")
	theme.set_stylebox("normal", "DangerButton", danger)
	theme.set_stylebox("hover", "DangerButton", danger_hover)
	theme.set_color("font_color", "DangerButton", Color("#FFB0BC"))
	var flat := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6)
	theme.set_type_variation("FlatButton", "Button")
	theme.set_stylebox("normal", "FlatButton", flat)
	theme.set_stylebox("hover", "FlatButton", box(Color(0.1, 0.2, 0.3, 0.6), Color(0, 0, 0, 0), 6))
	theme.set_stylebox("pressed", "FlatButton", box(Color(0.1, 0.3, 0.4, 0.8), Color(0, 0, 0, 0), 6))
	theme.set_type_variation("MenuItem", "Button")
	theme.set_stylebox("normal", "MenuItem", flat)
	theme.set_stylebox("hover", "MenuItem", box(Color(0.1, 0.8, 1.0, 0.06), Neon.CYAN, 6, 1, 0.55, 14))
	theme.set_stylebox("pressed", "MenuItem", box(Color(0.1, 0.8, 1.0, 0.14), Neon.CYAN, 6, 1, 0.7, 14))
	theme.set_stylebox("focus", "MenuItem", flat)
	theme.set_color("font_color", "MenuItem", Neon.TEXT)
	theme.set_color("font_hover_color", "MenuItem", Color.WHITE)
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, flat)
		theme.set_stylebox("hover", type, flat)
		theme.set_stylebox("pressed", type, flat)
		theme.set_stylebox("focus", type, flat)
		theme.set_color("font_hover_color", type, Neon.CYAN)
		theme.set_color("font_pressed_color", type, Neon.CYAN)
		theme.set_color("font_hover_pressed_color", type, Neon.CYAN)


static func _containers(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", box(Neon.PANEL, Neon.BORDER, 12, 1, 0.12, 14))
	theme.set_stylebox("panel", "Panel", box(Neon.PANEL, Neon.BORDER, 12))
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", box(Neon.PANEL, Neon.BORDER, 12, 1, 0.14, 16))
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", box(Neon.PANEL_RAISED, Neon.BORDER, 14, 1, 0.1, 12))
	theme.set_type_variation("Inset", "PanelContainer")
	theme.set_stylebox("panel", "Inset", box(Color(0.02, 0.035, 0.07, 0.8), Color(0.2, 0.35, 0.5, 0.35), 8))
	theme.set_type_variation("Heading", "Label")
	theme.set_font_size("font_size", "Heading", 13)
	theme.set_color("font_color", "Heading", Neon.TEXT_MUTED)
	theme.set_type_variation("Title", "Label")
	theme.set_font_size("font_size", "Title", 28)
	theme.set_color("font_color", "Title", Color.WHITE)
	theme.set_type_variation("Muted", "Label")
	theme.set_color("font_color", "Muted", Neon.TEXT_MUTED)
	theme.set_color("font_color", "ScrollContainer", Neon.TEXT)


static func _inputs(theme: Theme) -> void:
	var field := box(Color(0.02, 0.04, 0.09, 0.95), Color(0.2, 0.4, 0.6, 0.6), 6)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", box(Color(0.02, 0.05, 0.1, 1.0), Neon.CYAN, 6, 1, 0.4, 8))
	theme.set_color("caret_color", "LineEdit", Neon.CYAN)
	theme.set_color("selection_color", "LineEdit", Color(0.2, 0.5, 0.8, 0.5))
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.1, 0.16, 0.28, 1.0)
	slider.set_corner_radius_all(4)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	var filled := StyleBoxFlat.new()
	filled.bg_color = Neon.CYAN
	filled.set_corner_radius_all(4)
	filled.shadow_color = Color(Neon.CYAN, 0.4)
	filled.shadow_size = 5
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := _circle_icon(9, Neon.TEXT)
	var knob_hot := _circle_icon(11, Color.WHITE)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", knob_hot)
	theme.set_icon("grabber_disabled", "HSlider", knob)
	theme.set_constant("center_grabber", "HSlider", 1)


static func _circle_icon(radius: int, color: Color) -> Texture2D:
	var size := radius * 2 + 4
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(radius + 0.5 - d, 0.0, 1.0)
			var halo := clampf(1.0 - (d - radius) / 2.0, 0.0, 1.0) * 0.25 if d > radius else 0.0
			image.set_pixel(x, y, Color(color.r, color.g, color.b, maxf(alpha, halo)))
	return ImageTexture.create_from_image(image)


static func _tabs(theme: Theme) -> void:
	theme.set_stylebox("panel", "TabContainer", box(Color(0.03, 0.05, 0.1, 0.7), Neon.BORDER, 10))
	theme.set_stylebox("tab_selected", "TabContainer", box(Color(0.07, 0.2, 0.3, 0.95), Neon.CYAN, 8, 1, 0.3, 8))
	theme.set_stylebox("tab_unselected", "TabContainer", box(Color(0.04, 0.07, 0.13, 0.9), Color(0.2, 0.3, 0.45, 0.5), 8))
	theme.set_stylebox("tab_hovered", "TabContainer", box(Color(0.06, 0.12, 0.2, 0.95), Neon.PURPLE, 8, 1, 0.3, 6))
	theme.set_stylebox("tab_focus", "TabContainer", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8))
	theme.set_color("font_selected_color", "TabContainer", Neon.CYAN)
	theme.set_color("font_unselected_color", "TabContainer", Neon.TEXT_MUTED)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)


static func _bars(theme: Theme) -> void:
	var back := box(Color(0.03, 0.05, 0.1, 0.9), Color(0.2, 0.3, 0.45, 0.4), 4)
	back.content_margin_top = 0
	back.content_margin_bottom = 0
	var fill := box(Neon.CYAN, Color(0, 0, 0, 0), 4, 0, 0.0)
	theme.set_stylebox("background", "ProgressBar", back)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", Neon.TEXT)
	var scroll_back := StyleBoxFlat.new()
	scroll_back.bg_color = Color(0.03, 0.05, 0.1, 0.5)
	scroll_back.set_corner_radius_all(4)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.25, 0.5, 0.7, 0.7)
	grab.set_corner_radius_all(4)
	var grab_hot := StyleBoxFlat.new()
	grab_hot.bg_color = Neon.CYAN
	grab_hot.set_corner_radius_all(4)
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, scroll_back)
		theme.set_stylebox("grabber", type, grab)
		theme.set_stylebox("grabber_highlight", type, grab_hot)
		theme.set_stylebox("grabber_pressed", type, grab_hot)
