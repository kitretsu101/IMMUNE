class_name ScreenMode
extends Control
## Game mode selection cards.

@export var router: MenuRouter

const MODE_INFO := [
	["Human vs AI", "You command one side. The AI plays the other with the algorithm you choose.", Neon.CYAN, "1 player"],
	["AI vs AI", "Both sides play autonomously. Watch strategies clash and evolve at any speed.", Neon.PURPLE, "Observe"],
	["Human vs Human", "Two players share the screen and take turns: immune cells against bacteria.", Neon.GREEN, "2 players"],
	["Sandbox", "Control both sides freely, with no win condition. Poke at the biology.", Neon.YELLOW, "Free play"],
	["Experiment Mode", "Run batches of headless AI matches and compare algorithms and parameters.", Neon.ORANGE, "Research"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	var column := UiKit.vbox(14)
	margin.add_child(column)
	var head := UiKit.hbox(12)
	var back := UiKit.button("‹ Back")
	back.pressed.connect(router.back)
	head.add_child(back)
	head.add_child(UiKit.label("Choose a game mode", 30, Color.WHITE))
	column.add_child(head)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	column.add_child(flow)
	var delay := 0.0
	for index in MODE_INFO.size():
		var card := _card(index)
		flow.add_child(card)
		UiKit.fade_in(card, delay, Vector2(0, 14))
		delay += 0.05


func _card(index: int) -> Control:
	var info: Array = MODE_INFO[index]
	var tint: Color = info[2]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(300, 210)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := ThemeFactory.box(Color(0.045, 0.07, 0.13, 0.9), Color(tint.r, tint.g, tint.b, 0.35), 14, 1)
	var hover := ThemeFactory.box(Color(0.07, 0.11, 0.2, 0.96), tint, 14, 2, 0.5, 16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var inner := UiKit.vbox(8)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var padded := UiKit.margin(inner, 20)
	padded.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(padded)
	var chip := UiKit.chip(info[3], tint)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	inner.add_child(chip)
	inner.add_child(UiKit.label(info[0], 26, Color.WHITE))
	var text := UiKit.label(info[1], 14, Neon.TEXT_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(text)
	button.pressed.connect(func() -> void: _choose(index))
	return button


func _choose(index: int) -> void:
	Config.setup.mode = index
	Sfx.play_ui("ui_select_mode")
	router.show_screen("Experiment" if index == Sim.Mode.EXPERIMENT else "Config")
