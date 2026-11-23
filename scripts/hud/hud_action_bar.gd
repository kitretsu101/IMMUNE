class_name HudActionBar
extends PanelContainer
## Action buttons for a human-controlled side. Hidden while an AI plays.

@export var world: WorldHost
@export var rounds: RoundManager
@export var human: HumanController

var _buttons: Dictionary = {}
var _status: Label
var _mode_buttons: Array[Button] = []
var _end: Button


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	custom_minimum_size = Vector2(210, 150)
	var column := UiKit.vbox(6)
	add_child(UiKit.margin(column, 10))
	_status = UiKit.label("Your turn", 15, Neon.CYAN)
	column.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	_make(grid, "move", "Move/Attack [M]", HumanController.ActionMode.MOVE, true)
	_make(grid, "clone", "Clone [C]", HumanController.ActionMode.CLONE, true)
	_make(grid, "infect", "Infect [I]", HumanController.ActionMode.INFECT, true)
	_make(grid, "biofilm", "Biofilm [B]", Sim.Kind.BIOFILM, false)
	_make(grid, "rest", "Reproduce [E]", Sim.Kind.REPRODUCE, false)
	_make(grid, "wait", "Wait [W]", Sim.Kind.WAIT, false)
	_end = UiKit.button("End turn [Space]", "AccentButton")
	_end.pressed.connect(rounds.end_human_turn)
	column.add_child(_end)
	human.options_changed.connect(_refresh)
	human.mode_changed.connect(func(_m: int) -> void: _refresh())
	Events.state_changed.connect(_refresh)
	rounds.human_turn_started.connect(func(_s: int) -> void: _refresh())
	rounds.human_turn_ended.connect(_refresh)
	_refresh()


func _make(parent: Control, key: String, text: String, payload: int, is_mode: bool) -> void:
	var button := UiKit.button(text)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 13)
	if is_mode:
		button.toggle_mode = true
		button.pressed.connect(func() -> void: human.set_mode(payload))
		_mode_buttons.append(button)
	else:
		button.pressed.connect(func() -> void: human.immediate(payload))
	parent.add_child(button)
	_buttons[key] = [button, payload, is_mode]


func _refresh() -> void:
	var state := world.state
	if state == null:
		return
	var active := rounds.awaiting_human and not state.finished
	visible = active
	if not active:
		return
	var team := state.side
	var kinds := human.available_kinds()
	_status.text = "%s · actions %d/%d" % ["Immune turn" if team == Sim.IMMUNE else "Bacteria turn", rounds.ap_left, rounds.ap_total]
	_status.add_theme_color_override("font_color", Neon.team_color(team))
	var enabled := {
		"move": kinds.has(Sim.Kind.MOVE) or kinds.has(Sim.Kind.ATTACK),
		"clone": kinds.has(Sim.Kind.CLONE),
		"infect": kinds.has(Sim.Kind.INFECT),
		"biofilm": kinds.has(Sim.Kind.BIOFILM),
		"rest": kinds.has(Sim.Kind.REPRODUCE),
		"wait": kinds.has(Sim.Kind.WAIT),
	}
	var shown := {
		"move": true, "wait": true,
		"clone": team == Sim.IMMUNE, "infect": team == Sim.BACTERIA,
		"biofilm": team == Sim.BACTERIA, "rest": team == Sim.BACTERIA,
	}
	for key in _buttons:
		var entry: Array = _buttons[key]
		var button: Button = entry[0]
		button.visible = shown[key]
		button.disabled = not enabled[key] or rounds.busy
		if entry[2]:
			button.set_pressed_no_signal(human.action_mode == entry[1])
	_end.disabled = rounds.busy
