class_name UiKit
extends RefCounted
## Small constructors so every panel builds its widgets the same way.


static func label(text: String, size := 15, color := Neon.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func heading(text: String) -> Label:
	var node := Label.new()
	node.text = text.to_upper()
	node.theme_type_variation = &"Heading"
	node.add_theme_font_size_override("font_size", 12)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func hbox(separation := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func vbox(separation := 6) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func spacer(width := 0.0, height := 0.0, expand := false) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(width, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, variation := "", tooltip := "") -> Button:
	var node := Button.new()
	node.text = text
	node.tooltip_text = tooltip
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if variation != "":
		node.theme_type_variation = variation
	return node


static func panel(variation := "HudPanel") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	return node


static func margin(child: Control, all := 10) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		node.add_theme_constant_override("margin_" + side, all)
	node.add_child(child)
	return node


static func bar(color: Color, height := 8.0, value := 0.0) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, height)
	node.max_value = 1.0
	node.value = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ThemeFactory.box(color, Color(0, 0, 0, 0), 4, 0, 0.0)
	fill.shadow_color = Color(color.r, color.g, color.b, 0.5)
	fill.shadow_size = 5
	node.add_theme_stylebox_override("fill", fill)
	return node


## A "name .......... value" row. Returns the value label so callers can update it.
static func stat_row(parent: Control, name_text: String, value_color := Neon.TEXT) -> Label:
	var row := hbox(6)
	var name_label := label(name_text, 14, Neon.TEXT_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := label("-", 14, value_color, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(value)
	parent.add_child(row)
	return value


## A labelled bar. Returns [bar, value_label].
static func meter_row(parent: Control, name_text: String, color: Color) -> Array:
	var row := hbox(6)
	var name_label := label(name_text, 13, Neon.TEXT_MUTED)
	name_label.custom_minimum_size = Vector2(86, 0)
	name_label.clip_text = true
	row.add_child(name_label)
	var meter := bar(color, 6.0)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	var value := label("0%", 13, color, HORIZONTAL_ALIGNMENT_RIGHT)
	value.custom_minimum_size = Vector2(46, 0)
	row.add_child(value)
	parent.add_child(row)
	return [meter, value]


static func chip(text: String, color: Color) -> PanelContainer:
	var node := PanelContainer.new()
	var style := ThemeFactory.box(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b, 0.7), 10, 1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	node.add_theme_stylebox_override("panel", style)
	var inner := label(text, 13, color)
	inner.name = "Text"
	node.add_child(inner)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func set_chip(chip_node: PanelContainer, text: String, color: Color) -> void:
	var style := ThemeFactory.box(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b, 0.7), 10, 1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip_node.add_theme_stylebox_override("panel", style)
	var inner: Label = chip_node.get_node("Text")
	inner.text = text
	inner.add_theme_color_override("font_color", color)


static func fade_in(node: CanvasItem, delay := 0.0, _offset := Vector2.ZERO) -> void:
	if not Config.animations:
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, 0.3)
