class_name ScreenConfig
extends Control
## Game configuration: environment, bacteria, immune cells, AI and rules.

@export var router: MenuRouter

const GAME_SCENE := "res://scenes/game/game.tscn"

var _tabs: TabContainer
var _title: Label
var _forms: Array[SetupForm] = []
var _ai_form: SetupForm
var _difficulty_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var column := UiKit.vbox(12)
	margin.add_child(column)
	var head := UiKit.hbox(12)
	column.add_child(head)
	var back := UiKit.button("‹ Back")
	back.pressed.connect(router.back)
	head.add_child(back)
	_title = UiKit.label("Game configuration", 28, Color.WHITE)
	head.add_child(_title)
	head.add_child(UiKit.spacer(0, 0, true))
	var reset := UiKit.button("Reset defaults")
	reset.pressed.connect(_reset)
	head.add_child(reset)
	var start := UiKit.button("Start simulation  ▶", "AccentButton")
	start.custom_minimum_size = Vector2(220, 42)
	start.pressed.connect(_start)
	head.add_child(start)
	var presets := UiKit.hbox(8)
	column.add_child(presets)
	presets.add_child(UiKit.label("Environmental difficulty", 14, Neon.TEXT_MUTED))
	var group := ButtonGroup.new()
	for index in 3:
		var button := UiKit.button(["Easy", "Normal", "Hard"][index])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(88, 32)
		button.pressed.connect(_apply_difficulty.bind(index))
		presets.add_child(button)
		_difficulty_buttons.append(button)
	var hint := UiKit.label("Presets adjust nutrients and bacterial strength; fine-tune below.", 13, Neon.TEXT_DIM)
	presets.add_child(hint)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_tabs()


func on_show() -> void:
	var mode: int = Config.setup.mode
	_title.text = "Configure · %s" % Sim.MODE_NAMES[mode]
	_difficulty_buttons[Config.setup.difficulty].set_pressed_no_signal(true)
	_update_visibility()
	for form in _forms:
		form.refresh()


func _tab(tab_name: String) -> SetupForm:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var form := SetupForm.new()
	form.add_theme_constant_override("separation", 4)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.bind(Config.setup)
	var pad := UiKit.margin(form, 16)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_tabs.add_child(scroll)
	_forms.append(form)
	form.changed.connect(func(_key: String) -> void: _update_visibility())
	return form


func _build_tabs() -> void:
	var env := _tab("Environment")
	env.add_section("Board and resources")
	env.add_number("board_size", "Board dimensions (N × N)", 6, 10, 1, "Playable area. The board is always centred.")
	env.add_number("nutrient_level", "Initial nutrient distribution", 0.0, 1.0, 0.05, "How much food lies on the board at the start.", true)
	env.add_section("Infection")
	env.add_number("infection_sites", "Initial infection locations", 1, 4, 1, "How many corners bacteria start from.")
	env.add_choice("difficulty", "Environmental difficulty", ["Easy", "Normal", "Hard"], "Easy weakens bacteria, Hard strengthens them.")
	var bact := _tab("Bacteria")
	bact.add_section("Population")
	bact.add_number("bact_pop", "Initial bacterial population", 1, 8, 1)
	bact.add_number("bact_cap", "Population limit", 4, 30, 1, "Reproduction stops at this population.")
	bact.add_section("Characteristics (1–10)")
	bact.add_number("bact_infectivity", "Infectivity", 1, 10, 1, "Chance to infect tissue.")
	bact.add_number("bact_reproduction", "Reproduction efficiency", 1, 10, 1, "Chance to reproduce each round when fed.")
	bact.add_number("bact_evasion", "Immune evasion", 1, 10, 1, "Reduces the chance immune cells hit.")
	bact.add_section("Evolution")
	bact.add_number("mutation_rate", "Mutation rate", 0.0, 1.0, 0.05, "Chance that offspring mutate one trait.", true)
	bact.add_number("reproduction_rate", "Reproduction rate multiplier", 0.5, 2.0, 0.05)
	var immune := _tab("Immune")
	immune.add_section("Population")
	immune.add_number("immune_pop", "Initial immune-cell population", 1, 8, 1)
	immune.add_number("immune_cap", "Population limit", 4, 20, 1)
	immune.add_section("Characteristics")
	immune.add_number("immune_attack", "Attack strength (1–10)", 1, 10, 1)
	immune.add_number("immune_detection", "Detection capability (1–10)", 1, 10, 1, "Higher detection spots bacteria from farther away and hits more often.")
	immune.add_number("immune_range", "Movement range", 1, 4, 1)
	immune.add_section("Activation")
	immune.add_number("immune_activation", "Activation duration (rounds)", 1, 5, 1, "How long a detecting cell stays boosted.")
	_ai_form = _tab("AI")
	_ai_form.add_section("Who plays")
	_ai_form.add_choice("human_side", "You play as", ["Immune cells (T cells)", "Bacteria"], "", [Sim.IMMUNE, Sim.BACTERIA])
	_ai_form.add_section("Algorithms")
	_ai_form.add_choice("bact_ai", "Bacterial AI", ["Hybrid (all techniques)", "Fuzzy Logic", "Minimax", "MCTS", "Greedy"])
	_ai_form.add_choice("immune_ai", "Immune AI", ["Hybrid (all techniques)", "Fuzzy Logic", "Minimax", "MCTS", "Greedy"])
	_ai_form.add_section("Advanced")
	_ai_form.add_number("search_depth", "Minimax search depth", 1, 3, 1, "Plies searched. 3 is slow.")
	_ai_form.add_number("mcts_sims", "MCTS simulations per decision", 8, 200, 4)
	var rules := _tab("Rules")
	rules.add_section("Turns")
	rules.add_number("immune_actions", "Immune actions per turn", 1, 4, 1)
	rules.add_number("bact_actions", "Bacterial actions per turn", 1, 5, 1)
	rules.add_number("max_rounds", "Round limit (draw after)", 20, 300, 5)
	rules.add_section("Reproducibility")
	rules.add_number("rng_seed", "Random seed (0 = random)", 0, 99999, 1)


func _update_visibility() -> void:
	var mode: int = Config.setup.mode
	_ai_form.set_row_visible("human_side", mode == Sim.Mode.HUMAN_VS_AI)
	var human_bacteria := mode == Sim.Mode.HUMAN_VS_AI and Config.setup.human_side == Sim.BACTERIA
	var human_immune := mode == Sim.Mode.HUMAN_VS_AI and Config.setup.human_side == Sim.IMMUNE
	var both_human := mode == Sim.Mode.HUMAN_VS_HUMAN or mode == Sim.Mode.SANDBOX
	_ai_form.set_row_visible("bact_ai", not human_bacteria and not both_human)
	_ai_form.set_row_visible("immune_ai", not human_immune and not both_human)


func _apply_difficulty(index: int) -> void:
	var setup := Config.setup
	setup.difficulty = index
	match index:
		0:
			setup.nutrient_level = 0.35
			setup.mutation_rate = 0.2
			setup.bact_pop = 2
		1:
			setup.nutrient_level = 0.5
			setup.mutation_rate = 0.3
			setup.bact_pop = 2
		2:
			setup.nutrient_level = 0.7
			setup.mutation_rate = 0.4
			setup.bact_pop = 3
	for form in _forms:
		form.refresh()
	Sfx.play_ui("ui_config")


func _reset() -> void:
	var mode: int = Config.setup.mode
	Config.setup = GameSetup.new()
	Config.setup.mode = mode
	for form in _forms:
		form.bind(Config.setup)
		form.refresh()
	_difficulty_buttons[1].set_pressed_no_signal(true)
	Sfx.play_ui("ui_config")


func _start() -> void:
	Config.save_settings()
	Sfx.play_ui("ui_start")
	get_tree().change_scene_to_file(GAME_SCENE)
