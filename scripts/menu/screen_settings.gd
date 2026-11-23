class_name ScreenSettings
extends Control
## Audio, graphics and simulation preferences. Changes apply immediately.

@export var router: MenuRouter


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var column := UiKit.vbox(12)
	margin.add_child(column)
	var head := UiKit.hbox(12)
	column.add_child(head)
	var back := UiKit.button("‹ Back")
	back.pressed.connect(func() -> void:
		Config.save_settings()
		router.back())
	head.add_child(back)
	head.add_child(UiKit.label("Settings", 30, Color.WHITE))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var audio := _tab(tabs, "Audio")
	_section(audio, "Volume")
	_slider(audio, "Master volume", "master_volume")
	_slider(audio, "SFX volume", "sfx_volume")
	_slider(audio, "Music volume", "music_volume")
	_slider(audio, "Ambient volume", "ambient_volume")
	_slider(audio, "UI volume", "ui_volume")
	_slider(audio, "Bacterial sounds", "bacterial_volume")
	_slider(audio, "Immune sounds", "immune_volume")
	_section(audio, "Behaviour")
	_toggle(audio, "Audio on (off mutes everything)", "audio_enabled")
	_toggle(audio, "Biological SFX (bacteria and immune cells)", "biological_sfx")
	_toggle(audio, "Important event notifications", "event_notifications")
	_toggle(audio, "Sound variation (randomised pitch and takes)", "sound_variation")
	_toggle(audio, "Keep ambience playing while paused", "ambience_when_paused")
	var graphics := _tab(tabs, "Graphics")
	_section(graphics, "Look")
	_slider(graphics, "Glow / bloom intensity", "glow_level", 0.0, 1.6)
	_slider(graphics, "Vignette", "vignette", 0.0, 1.0)
	_toggle(graphics, "Particles and light trails", "particles")
	_toggle(graphics, "Animations and idle motion", "animations")
	_toggle(graphics, "Fullscreen", "fullscreen")
	var sim := _tab(tabs, "Simulation")
	_section(sim, "Helpers")
	_toggle(sim, "Auto-pause on important events", "auto_pause")
	_toggle(sim, "Pause when inspecting an organism", "pause_on_selection")
	_toggle(sim, "Show event notifications on screen", "event_popups")


func _tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := UiKit.margin(box, 18)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	tabs.add_child(scroll)
	return box


func _section(parent: Control, title: String) -> void:
	var head := UiKit.heading(title)
	head.add_theme_color_override("font_color", Neon.CYAN)
	parent.add_child(head)


func _slider(parent: Control, label_text: String, key: String, low := 0.0, high := 1.0) -> void:
	var row := UiKit.hbox(12)
	row.custom_minimum_size = Vector2(0, 34)
	var name_label := UiKit.label(label_text, 15)
	name_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = float(Config.get(key))
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(260, 22)
	row.add_child(slider)
	var value_label := UiKit.label("%d%%" % roundi(slider.value * 100.0), 15, Neon.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		Config.set(key, value)
		value_label.text = "%d%%" % roundi(value * 100.0)
		Events.settings_changed.emit())
	parent.add_child(row)


func _toggle(parent: Control, label_text: String, key: String) -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = bool(Config.get(key))
	check.toggled.connect(func(on: bool) -> void:
		Config.set(key, on)
		Config.save_settings())
	parent.add_child(check)
