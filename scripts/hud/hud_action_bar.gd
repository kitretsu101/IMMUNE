class_name HudActionBar
extends PanelContainer
## Action panel for a human-controlled side. Sits top-centre over the board with its own outline,
## big buttons and a legend that says what each highlight colour means.

@export var world: WorldHost
@export var rounds: RoundManager
@export var human: HumanController

var _buttons: Dictionary = {}
var _status: Label
var _end: Button
var _legend: RichTextLabel


func _ready() -> void:
	var style := ThemeFactory.box(Color(0.03, 0.04, 0.1, 0.94), Neon.ORANGE, 14, 2, 0.55, 18)
	add_theme_stylebox_override("panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 66.0
	custom_minimum_size = Vector2(900, 0)
	var column := UiKit.vbox(8)
	add_child(UiKit.margin(column, 12))
	var head := UiKit.hbox(12)
	column.add_child(head)
	_status = UiKit.label("Your turn", 20, Neon.ORANGE)
	head.add_child(_status)
	head.add_child(UiKit.spacer(0, 0, true))
	_legend = RichTextLabel.new()
	_legend.bbcode_enabled = true
	_legend.fit_content = true
	_legend.scroll_active = false
	_legend.custom_minimum_size = Vector2(520, 0)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.add_theme_font_size_override("normal_font_size", 14)
	head.add_child(_legend)
	var row := UiKit.hbox(8)
	column.add_child(row)
	_make(row, "move", "Move / Attack  [M]", HumanController.ActionMode.MOVE, true)
	_make(row, "clone", "Clone  [C]", HumanController.ActionMode.CLONE, true)
	_make(row, "infect", "Infect  [I]", HumanController.ActionMode.INFECT, true)
	_make(row, "biofilm", "Biofilm  [B]", Sim.Kind.BIOFILM, false)
	_make(row, "rest", "Reproduce  [E]", Sim.Kind.REPRODUCE, false)
	_make(row, "wait", "Wait  [W]", Sim.Kind.WAIT, false)
	_end = UiKit.button("End turn  [Space]", "AccentButton")
	_end.custom_minimum_size = Vector2(170, 46)
	_end.pressed.connect(rounds.end_human_turn)
	row.add_child(_end)
	human.options_changed.connect(_refresh)
	human.mode_changed.connect(func(_m: int) -> void: _refresh())
	Events.state_changed.connect(_refresh)
	rounds.human_turn_started.connect(func(_s: int) -> void: _refresh())
	rounds.human_turn_ended.connect(_refresh)
	_refresh()


func _make(parent: Control, key: String, text: String, payload: int, is_mode: bool) -> void:
	var button := UiKit.button(text)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 16)
	if is_mode:
		button.toggle_mode = true
		button.pressed.connect(func() -> void: human.set_mode(payload))
	else:
		button.pressed.connect(func() -> void: human.immediate(payload))
	parent.add_child(button)
	_buttons[key] = [button, payload, is_mode]


func _swatch(color: Color, text: String) -> String:
	return "[color=#%s]■[/color] %s" % [color.to_html(false), text]


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
	_status.text = "%s · actions %d / %d" % ["IMMUNE TURN" if team == Sim.IMMUNE else "BACTERIA TURN", rounds.ap_left, rounds.ap_total]
	var legend: PackedStringArray = []
	match human.action_mode:
		HumanController.ActionMode.MOVE:
			legend.append(_swatch(Neon.CYAN, "move here"))
			legend.append(_swatch(Neon.ORANGE, "attack this cell"))
		HumanController.ActionMode.CLONE:
			legend.append(_swatch(Neon.GREEN, "clone into this tile"))
		HumanController.ActionMode.INFECT:
			legend.append(_swatch(Neon.RED, "infect this tile"))
	_legend.text = "   ".join(legend) + "   [color=#%s]click a highlighted tile[/color]" % Neon.TEXT_MUTED.to_html(false)
	var enabled := {
		"move": kinds.has(Sim.Kind.MOVE) or kinds.has(Sim.Kind.ATTACK),
		"clone": kinds.has(Sim.Kind.CLONE), "infect": kinds.has(Sim.Kind.INFECT),
		"biofilm": kinds.has(Sim.Kind.BIOFILM), "rest": kinds.has(Sim.Kind.REPRODUCE), "wait": kinds.has(Sim.Kind.WAIT),
	}
	var shown := {"move": true, "wait": true, "clone": team == Sim.IMMUNE, "infect": team == Sim.BACTERIA,
		"biofilm": team == Sim.BACTERIA, "rest": team == Sim.BACTERIA}
	for key in _buttons:
		var entry: Array = _buttons[key]
		var button: Button = entry[0]
		button.visible = shown[key]
		button.disabled = not enabled[key] or rounds.busy
		if entry[2]:
			button.set_pressed_no_signal(human.action_mode == entry[1])
	_end.disabled = rounds.busy
