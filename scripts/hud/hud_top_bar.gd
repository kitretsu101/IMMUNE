class_name HudTopBar
extends PanelContainer
## Top bar: round, elapsed time, mode, simulation status, current phase and speed.

@export var world: WorldHost
@export var rounds: RoundManager
@export var clock: SimClock

var _round: Label
var _time: Label
var _mode: PanelContainer
var _status: PanelContainer
var _phase: Label
var _speed: PanelContainer
var _actions: Label
var _menu: IconButton
var _side := Sim.IMMUNE


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var row := UiKit.hbox(14)
	add_child(UiKit.margin(row, 4))
	var title := UiKit.label("IMMUNE", 22, Neon.CYAN)
	title.add_theme_constant_override("outline_size", 0)
	row.add_child(title)
	row.add_child(VSeparator.new())
	_round = UiKit.label("ROUND 1", 18, Color.WHITE)
	row.add_child(_round)
	_time = UiKit.label("00:00", 16, Neon.TEXT_MUTED)
	row.add_child(_time)
	row.add_child(UiKit.spacer(0, 0, true))
	_phase = UiKit.label("", 17, Neon.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(_phase)
	_actions = UiKit.label("", 15, Neon.TEXT_MUTED)
	row.add_child(_actions)
	row.add_child(UiKit.spacer(0, 0, true))
	_mode = UiKit.chip("Human vs AI", Neon.TEXT)
	row.add_child(_mode)
	_status = UiKit.chip("Running", Neon.TEXT)
	row.add_child(_status)
	_speed = UiKit.chip("1×", Neon.CYAN)
	row.add_child(_speed)
	_menu = IconButton.new()
	_menu.glyph = IconButton.Glyph.MENU
	_menu.theme_type_variation = &"FlatButton"
	_menu.tooltip_text = "Menu"
	_menu.pressed.connect(func() -> void: Events.request_menu.emit())
	row.add_child(_menu)
	Events.state_changed.connect(_refresh)
	Events.status_changed.connect(_on_status)
	Events.speed_changed.connect(func(_s: float) -> void: _refresh())
	Events.side_changed.connect(func(side: int) -> void:
		_side = side
		_refresh())
	rounds.actions_changed.connect(func(_l: int, _t: int) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	if world.state:
		_time.text = "%02d:%02d" % [int(world.state.elapsed) / 60, int(world.state.elapsed) % 60]


func _on_status(text: String) -> void:
	var color := Neon.TEXT
	if text.contains("Stopped") or text.contains("Finished"):
		color = Neon.RED
	elif text.contains("turn") or text.contains("thinking"):
		color = Neon.CYAN
	UiKit.set_chip(_status, text, color)


func _refresh() -> void:
	if world.state == null:
		return
	var state := world.state
	_round.text = "ROUND %d / %d" % [state.round, state.setup.max_rounds] if state.setup.mode != Sim.Mode.SANDBOX else "ROUND %d" % state.round
	UiKit.set_chip(_mode, Sim.MODE_NAMES[state.setup.mode], Neon.TEXT)
	var speed_text := "∞" if Config.unlimited_speed else ("%s×" % str(Config.speed))
	UiKit.set_chip(_speed, speed_text, Neon.CYAN)
	if state.finished:
		_phase.text = state.result_text
		_phase.add_theme_color_override("font_color", Neon.ORANGE)
		_actions.text = ""
		return
	var team := _side
	var controller := state.setup.controller_for(team)
	_phase.text = "%s turn · %s" % ["IMMUNE" if team == Sim.IMMUNE else "BACTERIA", "You" if controller == "human" else "AI"]
	_phase.add_theme_color_override("font_color", Neon.CYAN)
	_actions.text = "Actions %d/%d" % [rounds.ap_left, rounds.ap_total]
