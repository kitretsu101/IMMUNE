class_name HudToolbar
extends PanelContainer
## Always-visible simulation controls: play, pause, stop, step, restart, save, load, speed and options.

@export var world: WorldHost
@export var rounds: RoundManager
@export var clock: SimClock
@export var camera: CameraController
@export var persistence: SavePersistence

var _play: IconButton
var _pause: IconButton
var _speed_box: OptionButton
var _unlimited: CheckButton
var _options: MenuButton
var _save_slot := 1


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var row := UiKit.hbox(6)
	add_child(UiKit.margin(row, 5))
	_play = _icon(row, IconButton.Glyph.PLAY, "Play / resume", func() -> void: clock.set_paused(false))
	_pause = _icon(row, IconButton.Glyph.PAUSE, "Pause", func() -> void: clock.set_paused(true))
	_icon(row, IconButton.Glyph.STOP, "Stop the simulation", func() -> void: rounds.stop())
	_icon(row, IconButton.Glyph.STEP, "Step one full round", func() -> void: clock.request_step())
	_icon(row, IconButton.Glyph.RESTART, "Restart with the current configuration", func() -> void:
		Sfx.play_ui("ui_start")
		rounds.restart())
	row.add_child(VSeparator.new())
	_icon(row, IconButton.Glyph.SAVE, "Save simulation (slot 1)", func() -> void: persistence.save(_save_slot))
	_icon(row, IconButton.Glyph.LOAD, "Load saved simulation (slot 1)", func() -> void: persistence.load_slot(_save_slot))
	row.add_child(VSeparator.new())
	row.add_child(UiKit.label("Speed", 13, Neon.TEXT_MUTED))
	_speed_box = OptionButton.new()
	_speed_box.focus_mode = Control.FOCUS_NONE
	for value in clock.speeds:
		_speed_box.add_item("%s×" % str(value))
	_speed_box.select(clock.speeds.find(Config.speed))
	_speed_box.item_selected.connect(func(index: int) -> void: clock.set_speed(clock.speeds[index]))
	_speed_box.custom_minimum_size = Vector2(84, 34)
	row.add_child(_speed_box)
	_unlimited = CheckButton.new()
	_unlimited.text = "Unlimited"
	_unlimited.focus_mode = Control.FOCUS_NONE
	_unlimited.tooltip_text = "Headless-style speed: no waiting, no animation holds. For long experiments."
	_unlimited.toggled.connect(func(on: bool) -> void:
		Config.unlimited_speed = on
		Events.speed_changed.emit(Config.speed))
	row.add_child(_unlimited)
	row.add_child(UiKit.spacer(0, 0, true))
	_options = MenuButton.new()
	_options.text = "Options"
	_options.focus_mode = Control.FOCUS_NONE
	_options.custom_minimum_size = Vector2(90, 34)
	var popup := _options.get_popup()
	var entries := ["Auto-pause on important events", "Pause when inspecting", "Animations", "Event notifications", "Particles"]
	for index in entries.size():
		popup.add_check_item(entries[index], index)
	popup.set_item_checked(0, Config.auto_pause)
	popup.set_item_checked(1, Config.pause_on_selection)
	popup.set_item_checked(2, Config.animations)
	popup.set_item_checked(3, Config.event_popups)
	popup.set_item_checked(4, Config.particles)
	popup.hide_on_checkable_item_selection = false
	popup.id_pressed.connect(_on_option)
	row.add_child(_options)
	row.add_child(VSeparator.new())
	_icon(row, IconButton.Glyph.ZOOM_OUT, "Zoom out", func() -> void: camera.zoom_by(1.0 / 0.85))
	_icon(row, IconButton.Glyph.ZOOM_IN, "Zoom in", func() -> void: camera.zoom_by(0.85))
	_icon(row, IconButton.Glyph.TARGET, "Reset camera", func() -> void: camera.reset_view())
	row.add_child(VSeparator.new())
	var log := UiKit.button("Open log window", "AccentButton")
	log.pressed.connect(func() -> void: Events.request_log_window.emit(true))
	row.add_child(log)
	Events.status_changed.connect(func(_t: String) -> void: _refresh())
	Events.speed_changed.connect(func(_s: float) -> void: _refresh())
	_refresh()


func _icon(parent: Control, glyph: int, tip: String, action: Callable) -> IconButton:
	var button := IconButton.new()
	button.glyph = glyph
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _on_option(id: int) -> void:
	var popup := _options.get_popup()
	var checked := not popup.is_item_checked(id)
	popup.set_item_checked(id, checked)
	match id:
		0: Config.auto_pause = checked
		1: Config.pause_on_selection = checked
		2: Config.animations = checked
		3: Config.event_popups = checked
		4: Config.particles = checked
	Config.save_settings()


func _refresh() -> void:
	var running := clock.status == SimClock.Status.RUNNING
	_play.glyph_color = Neon.GREEN if clock.paused else Neon.TEXT
	_pause.glyph_color = Neon.YELLOW if clock.paused else Neon.TEXT
	var index := clock.speeds.find(Config.speed)
	if index >= 0 and _speed_box.selected != index:
		_speed_box.select(index)
	_play.queue_redraw()
	_pause.queue_redraw()
	if _unlimited.button_pressed != Config.unlimited_speed:
		_unlimited.set_pressed_no_signal(Config.unlimited_speed)
