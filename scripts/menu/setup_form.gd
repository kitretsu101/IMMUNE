class_name SetupForm
extends VBoxContainer
## Builds labelled controls bound to properties of a GameSetup. Used by the configuration and experiment screens.

signal changed(key: String)

var setup: GameSetup
var _rows: Dictionary = {}


func bind(target: GameSetup) -> void:
	setup = target


func add_section(title: String) -> void:
	var head := UiKit.heading(title)
	head.custom_minimum_size = Vector2(0, 28)
	head.add_theme_color_override("font_color", Neon.CYAN)
	add_child(head)


func _row(label_text: String, hint: String) -> HBoxContainer:
	var row := UiKit.hbox(12)
	row.custom_minimum_size = Vector2(0, 34)
	var name_label := UiKit.label(label_text, 15, Neon.TEXT)
	name_label.custom_minimum_size = Vector2(230, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.tooltip_text = hint
	row.add_child(name_label)
	add_child(row)
	return row


func add_number(key: String, label_text: String, low: float, high: float, step := 1.0, hint := "", percent := false) -> void:
	var row := _row(label_text, hint)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(setup.get(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(220, 22)
	slider.focus_mode = Control.FOCUS_NONE
	var value_label := UiKit.label("", 15, Neon.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(64, 0)
	var show := func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value * 100.0) if percent else (str(snappedf(value, 0.01)) if step < 1.0 else str(int(value)))
	show.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		show.call(value)
		setup.set(key, int(value) if step >= 1.0 else value)
		changed.emit(key))
	row.add_child(slider)
	row.add_child(value_label)
	_rows[key] = [row, slider]


func add_choice(key: String, label_text: String, options: Array, hint := "", values: Array = []) -> void:
	var row := _row(label_text, hint)
	var box := OptionButton.new()
	box.focus_mode = Control.FOCUS_NONE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in options.size():
		box.add_item(str(options[index]), index)
	var current := int(setup.get(key))
	var selected := values.find(current) if not values.is_empty() else current
	box.select(maxi(0, selected))
	box.item_selected.connect(func(index: int) -> void:
		setup.set(key, values[index] if not values.is_empty() else index)
		Sfx.play_ui("ui_config")
		changed.emit(key))
	row.add_child(box)
	_rows[key] = [row, box, values]


func add_toggle(key: String, label_text: String, hint := "") -> void:
	var row := _row(label_text, hint)
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = bool(setup.get(key))
	check.toggled.connect(func(on: bool) -> void:
		setup.set(key, on)
		Sfx.play_ui("ui_config")
		changed.emit(key))
	row.add_child(check)
	_rows[key] = [row, check]


func set_row_visible(key: String, shown: bool) -> void:
	if _rows.has(key):
		_rows[key][0].visible = shown


## Re-reads every control from the setup (after a preset or reset).
func refresh() -> void:
	for key in _rows:
		var control: Control = _rows[key][1]
		var value = setup.get(key)
		if control is HSlider:
			control.set_value_no_signal(float(value))
			control.value_changed.emit(float(value))
		elif control is OptionButton:
			var values: Array = _rows[key][2]
			control.select(maxi(0, values.find(int(value))) if not values.is_empty() else int(value))
		elif control is CheckButton:
			control.set_pressed_no_signal(bool(value))
