class_name HudEventLog
extends PanelContainer
## Compact in-game event log. Expands upward, filters by category, links to the full log window.

const CATEGORIES := ["Movement", "Infection", "Reproduction", "Combat", "Death", "Evolution", "Environment"]

var _text: RichTextLabel
var _filters: Dictionary = {}
var _last_round := -1
var _expanded := false
var _expand_button: IconButton
var _lines := 0


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	custom_minimum_size = Vector2(300, 150)
	var column := UiKit.vbox(4)
	add_child(UiKit.margin(column, 10))
	var head := UiKit.hbox(4)
	head.add_child(UiKit.heading("Event log"))
	head.add_child(UiKit.spacer(0, 0, true))
	_expand_button = IconButton.new()
	_expand_button.glyph = IconButton.Glyph.EXPAND
	_expand_button.theme_type_variation = &"FlatButton"
	_expand_button.custom_minimum_size = Vector2(30, 24)
	_expand_button.tooltip_text = "Expand / collapse"
	_expand_button.pressed.connect(_toggle_expand)
	head.add_child(_expand_button)
	column.add_child(head)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 3)
	chips.add_theme_constant_override("v_separation", 3)
	column.add_child(chips)
	for category in CATEGORIES:
		var button := UiKit.button(category.substr(0, 4), "FlatButton", "Show / hide %s events" % category)
		button.toggle_mode = true
		button.button_pressed = true
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", Neon.category_color(category))
		button.add_theme_color_override("font_pressed_color", Neon.category_color(category))
		button.custom_minimum_size = Vector2(0, 20)
		button.toggled.connect(func(_on: bool) -> void: rebuild())
		chips.add_child(button)
		_filters[category] = button
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_text)
	GameLog.entry_added.connect(_on_entry)
	GameLog.cleared.connect(func() -> void:
		_text.clear()
		_last_round = -1
		_lines = 0)
	rebuild()


func _toggle_expand() -> void:
	_expanded = not _expanded
	custom_minimum_size.y = 300 if _expanded else 150
	size.y = 0
	Sfx.play_ui("ui_open" if _expanded else "ui_close")
	var parent := get_parent()
	if parent is Control:
		(parent as Control).reset_size()


func _visible_entry(entry: Dictionary) -> bool:
	var category: String = entry.cat
	if _filters.has(category) and not _filters[category].button_pressed:
		return false
	return category != "System" or entry.sev != "info"


func _format(entry: Dictionary) -> String:
	var color := Neon.severity_color(entry.sev) if entry.sev != "info" else Neon.TEXT
	var tag := Neon.category_color(entry.cat)
	return "[color=#%s]%s[/color] [color=#%s]●[/color] [color=#%s]%s[/color]\n" % [
		Neon.TEXT_DIM.to_html(false), entry.time, tag.to_html(false), color.to_html(false), entry.msg]


func rebuild() -> void:
	_text.clear()
	_last_round = -1
	_lines = 0
	var start := maxi(0, GameLog.entries.size() - 120)
	for index in range(start, GameLog.entries.size()):
		_append(GameLog.entries[index])


func _on_entry(entry: Dictionary) -> void:
	_append(entry)


func _append(entry: Dictionary) -> void:
	if not _visible_entry(entry):
		return
	if entry.round != _last_round:
		_last_round = entry.round
		_text.append_text("[color=#%s][b]ROUND %d[/b][/color]\n" % [Neon.CYAN.to_html(false), entry.round])
		_lines += 1
	_text.append_text(_format(entry))
	_lines += 1
	if _lines > 400:
		rebuild()
