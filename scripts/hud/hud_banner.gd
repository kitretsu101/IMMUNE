class_name HudBanner
extends Control
## Large centred phase banner ("IMMUNE TURN", "ROUND 5") that flashes in and fades out.

@export var rounds: RoundManager

var _label: Label
var _sub: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.vbox(0)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = 120.0
	box.offset_bottom = 200.0
	add_child(box)
	_label = UiKit.label("", 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = UiKit.label("", 16, Neon.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_label)
	box.add_child(_sub)
	modulate.a = 0.0
	Events.side_changed.connect(_on_side)
	Events.round_changed.connect(func(number: int) -> void:
		if number > 1:
			_show("ROUND %d" % number, "", Neon.TEXT))


func _on_side(side: int) -> void:
	var state: WorldState = rounds.world.state
	if state == null:
		return
	var human := state.setup.controller_for(side) == "human"
	var name_text := "IMMUNE TURN" if side == Sim.IMMUNE else "BACTERIA TURN"
	var sub := "Your move" if human else "AI is playing"
	if state.setup.mode == Sim.Mode.HUMAN_VS_HUMAN:
		sub = "Player %d" % (1 if side == Sim.IMMUNE else 2)
	_show(name_text, sub, Neon.team_color(side))


func _show(text: String, sub: String, color: Color) -> void:
	_label.text = text
	_sub.text = sub
	_label.add_theme_color_override("font_color", color)
	if _tween and _tween.is_valid():
		_tween.kill()
	if not Config.animations:
		return
	modulate.a = 0.0
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_interval(0.7)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
