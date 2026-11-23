class_name ScreenMain
extends Control
## Main menu: title, tagline and the six entry points.

@export var router: MenuRouter

var _glow_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var column := UiKit.vbox(0)
	column.custom_minimum_size = Vector2(340, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)
	column.add_child(UiKit.label("MICROSCOPIC DEFENCE SIMULATION", 13, Neon.TEXT_MUTED))
	_glow_label = UiKit.label("IMMUNE", 84, Neon.CYAN)
	column.add_child(_glow_label)
	column.add_child(UiKit.label("T cells against bacteria on a living tissue board.\nGuard the human cells, or infect them.", 16, Neon.TEXT_MUTED))
	column.add_child(UiKit.spacer(0, 36))
	var entries := [
		["New Game", "MenuItem", func() -> void:
			router.show_screen("Mode")],
		["Tutorial", "MenuItem", func() -> void: _start_tutorial()],
		["Load Game", "MenuItem", func() -> void: router.show_screen("Load")],
		["Experiments", "MenuItem", func() -> void:
			Config.setup.mode = Sim.Mode.EXPERIMENT
			router.show_screen("Experiment")],
		["Statistics", "MenuItem", func() -> void: router.show_screen("Stats")],
		["Settings", "MenuItem", func() -> void: router.show_screen("Settings")],
		["Exit", "MenuItem", func() -> void: get_tree().quit()],
	]
	var delay := 0.0
	for entry in entries:
		var button := UiKit.button(entry[0], entry[1])
		button.custom_minimum_size = Vector2(280, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(entry[2])
		column.add_child(button)
		column.add_child(UiKit.spacer(0, 8))
		UiKit.fade_in(button, delay, Vector2(-16, 0))
		delay += 0.05
	column.add_child(UiKit.spacer(0, 0, true))
	column.add_child(UiKit.label("M Move · C Clone · Space End turn · L Log window · P Pause", 12, Neon.TEXT_DIM))


func _process(_delta: float) -> void:
	if Config.animations and _glow_label:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.2)
		_glow_label.add_theme_color_override("font_color", Neon.CYAN.lerp(Color.WHITE, pulse * 0.2))


func _start_tutorial() -> void:
	Config.tutorial = true
	var setup := GameSetup.new()
	setup.mode = Sim.Mode.HUMAN_VS_AI
	setup.human_side = Sim.IMMUNE
	setup.board_size = 8
	setup.bact_pop = 1
	setup.immune_pop = 1
	setup.mutation_rate = 0.5
	setup.bact_actions = 1
	setup.immune_actions = 2
	setup.rng_seed = 12
	setup.max_rounds = 200
	Config.setup = setup
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
