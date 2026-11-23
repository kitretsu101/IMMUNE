class_name HudResultOverlay
extends Control
## End-of-match summary with replay, menu and log shortcuts.

@export var world: WorldHost
@export var rounds: RoundManager

var _title: Label
var _text: Label
var _stats: GridContainer
var _card: PanelContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = UiKit.panel("Card")
	_card.custom_minimum_size = Vector2(460, 0)
	center.add_child(_card)
	var column := UiKit.vbox(10)
	_card.add_child(UiKit.margin(column, 22))
	_title = UiKit.label("", 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_title)
	_text = UiKit.label("", 16, Neon.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_text)
	column.add_child(HSeparator.new())
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 24)
	column.add_child(_stats)
	column.add_child(UiKit.spacer(0, 6))
	var buttons := UiKit.hbox(8)
	column.add_child(buttons)
	var again := UiKit.button("Play again", "AccentButton")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void:
		visible = false
		Sfx.play_ui("ui_start")
		rounds.restart())
	buttons.add_child(again)
	var log := UiKit.button("View log")
	log.pressed.connect(func() -> void: Events.request_log_window.emit(true))
	buttons.add_child(log)
	var menu := UiKit.button("Main menu")
	menu.pressed.connect(func() -> void: Events.request_menu.emit())
	buttons.add_child(menu)
	var close := UiKit.button("Watch board", "FlatButton")
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)
	Events.game_over.connect(_on_game_over)
	world.world_rebuilt.connect(func() -> void: visible = false)


func _on_game_over(result: Dictionary) -> void:
	if result.get("stopped", false):
		return
	await get_tree().create_timer(1.1 if Config.animations else 0.1).timeout
	var state := world.state
	if state == null:
		return
	var winner: int = result.get("winner", 0)
	var setup := state.setup
	var title := "DRAW"
	var color := Neon.YELLOW
	if winner == Sim.NONE:
		title = "DRAW"
	elif setup.mode == Sim.Mode.HUMAN_VS_AI:
		var won := winner == setup.human_side
		title = "VICTORY" if won else "DEFEAT"
		color = Neon.GREEN if won else Neon.RED
	else:
		title = "IMMUNE WIN" if winner == Sim.IMMUNE else "BACTERIA WIN"
		color = Neon.team_color(winner)
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_text.text = result.text
	for child in _stats.get_children():
		child.queue_free()
	var rows := [["Rounds played", str(state.round - 1 if state.round > 1 else 1)], ["Simulation time", "%02d:%02d" % [int(state.elapsed) / 60, int(state.elapsed) % 60]],
		["Peak bacteria", str(state.stats.bact_peak)], ["Mutations", str(state.stats.mutations)],
		["Eliminations", str(state.stats.eliminations)], ["Human cells infected", "%d / %d" % [state.core_infected(), state.core.size()]]]
	for row in rows:
		_stats.add_child(UiKit.label(row[0], 14, Neon.TEXT_MUTED))
		_stats.add_child(UiKit.label(row[1], 14, Neon.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	visible = true
	UiKit.fade_in(_card, 0.0, Vector2(0, 14))
