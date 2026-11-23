class_name ScreenExperiment
extends Control
## Experiment mode: batches of headless AI-vs-AI games with configurable algorithms and parameters.

@export var router: MenuRouter

var _runner: ExperimentRunner
var _progress: ProgressBar
var _status: Label
var _results: VBoxContainer
var _run_button: Button
var _cancel_button: Button
var _form: SetupForm


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_runner = ExperimentRunner.new()
	add_child(_runner)
	_runner.progress.connect(_on_progress)
	_runner.finished.connect(_on_finished)
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
	head.add_child(UiKit.label("Experiments", 28, Color.WHITE))
	head.add_child(UiKit.label("Headless AI vs AI batches, no rendering", 14, Neon.TEXT_MUTED))
	var body := UiKit.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left := UiKit.panel("Card")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(UiKit.margin(scroll, 12))
	_form = SetupForm.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.bind(Config.setup)
	scroll.add_child(_form)
	_form.add_section("Algorithms")
	_form.add_choice("bact_ai", "Bacterial AI", ["Hybrid (all techniques)", "Fuzzy Logic", "Minimax", "MCTS", "Greedy"])
	_form.add_choice("immune_ai", "Immune AI", ["Hybrid (all techniques)", "Fuzzy Logic", "Minimax", "MCTS", "Greedy"])
	_form.add_number("search_depth", "Minimax search depth", 1, 3)
	_form.add_number("mcts_sims", "MCTS simulations", 8, 120, 4)
	_form.add_section("Experiment")
	_form.add_number("experiment_runs", "Number of games", 1, 100, 1)
	_form.add_number("rng_seed", "Base seed (0 = random)", 0, 99999)
	_form.add_number("max_rounds", "Round limit", 20, 200, 5)
	_form.add_section("Parameters")
	_form.add_number("bact_pop", "Initial bacteria", 1, 8)
	_form.add_number("immune_pop", "Initial immune cells", 1, 8)
	_form.add_number("mutation_rate", "Mutation rate", 0.0, 1.0, 0.05, "", true)
	_form.add_number("antibiotic", "Antibiotic concentration", 0.0, 1.0, 0.05, "", true)
	_form.add_number("nutrient_level", "Nutrients", 0.0, 1.0, 0.05, "", true)
	_form.add_choice("difficulty", "Environmental difficulty", ["Easy", "Normal", "Hard"])
	var right := UiKit.vbox(10)
	right.custom_minimum_size = Vector2(400, 0)
	body.add_child(right)
	var run_row := UiKit.hbox(8)
	right.add_child(run_row)
	_run_button = UiKit.button("Run experiment  ▶", "AccentButton")
	_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_button.custom_minimum_size = Vector2(0, 44)
	_run_button.pressed.connect(_run)
	run_row.add_child(_run_button)
	_cancel_button = UiKit.button("Cancel", "DangerButton")
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_runner.cancel)
	run_row.add_child(_cancel_button)
	_progress = UiKit.bar(Neon.CYAN, 10.0)
	right.add_child(_progress)
	_status = UiKit.label("Configure the batch, then run it.", 14, Neon.TEXT_MUTED)
	right.add_child(_status)
	var panel := UiKit.panel("Card")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(panel)
	_results = UiKit.vbox(6)
	panel.add_child(UiKit.margin(_results, 14))
	_results.add_child(UiKit.heading("Results"))


func on_show() -> void:
	_form.bind(Config.setup)
	_form.refresh()


func _run() -> void:
	Config.setup.mode = Sim.Mode.EXPERIMENT
	Config.save_settings()
	_run_button.disabled = true
	_cancel_button.visible = true
	_progress.value = 0.0
	_status.text = "Running…"
	Sfx.play_ui("ui_start")
	_runner.run(Config.setup, Config.setup.experiment_runs)


func _on_progress(done: int, total: int) -> void:
	_progress.value = float(done) / total
	_status.text = "Game %d of %d" % [done, total]


func _on_finished(summary: Dictionary) -> void:
	_run_button.disabled = false
	_cancel_button.visible = false
	_status.text = "Finished %d games" % summary.runs
	Sfx.play_ui("ui_victory")
	var record := summary.duplicate()
	record["kind"] = "experiment"
	record["text"] = "Experiment · %d games" % summary.runs
	Config.record_result(record)
	for child in _results.get_children():
		if child is Label and child.theme_type_variation == &"Heading":
			continue
		child.queue_free()
	var n := maxf(1.0, summary.runs)
	var rows := [
		["Algorithms", "Bacteria %s  vs  Immune %s" % [Sim.ALGO_NAMES[summary.bact_ai], Sim.ALGO_NAMES[summary.immune_ai]]],
		["Immune wins", "%d  (%d%%)" % [summary.immune_wins, roundi(100.0 * summary.immune_wins / n)]],
		["Bacteria wins", "%d  (%d%%)" % [summary.bacteria_wins, roundi(100.0 * summary.bacteria_wins / n)]],
		["Draws", str(summary.draws)],
		["Average rounds", "%.1f" % summary.avg_rounds],
		["Peak bacteria (avg)", "%.1f" % summary.avg_peak_bacteria],
		["Mutations (avg)", "%.1f" % summary.avg_mutations],
		["Human cells infected (avg)", "%.1f" % summary.avg_core_infected],
		["Decision latency (avg)", "%.2f ms" % summary.avg_latency_ms],
	]
	for row in rows:
		var line := UiKit.hbox(8)
		var name_label := UiKit.label(row[0], 14, Neon.TEXT_MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiKit.label(row[1], 14, Neon.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		_results.add_child(line)
