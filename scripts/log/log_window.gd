class_name LogWindow
extends Window
## Detachable observability window: event log, AI decision log, performance monitor, evolution log.
## It only reads from the GameLog backend, so it can be closed, moved to another monitor, or reopened freely.

const SEVERITIES := ["info", "notable", "important", "critical"]
const MAX_RENDERED := 700

var _tabs: TabContainer
var _search: LineEdit
var _severity: OptionButton
var _category: OptionButton
var _organism: SpinBox
var _round: SpinBox
var _pause_stream: CheckButton
var _status: Label
var _events: RichTextLabel
var _decisions: RichTextLabel
var _evolution: RichTextLabel
var _perf_labels: Dictionary = {}
var _latency_chart: SparkChart
var _nodes_chart: SparkChart
var _fps_chart: SparkChart
var _perf_table: RichTextLabel
var _dirty := {"events": true, "decisions": true, "evolution": true}
var _perf_clock := 0.0
var _rebuild_clock := 0.0
var _counts: Dictionary = {}


func _ready() -> void:
	title = "IMMUNE · Observability"
	size = Vector2i(980, 660)
	min_size = Vector2i(720, 440)
	visible = false
	exclusive = false
	transient = false
	unresizable = false
	theme = ThemeFactory.get_theme()
	close_requested.connect(_close)
	var background := ColorRect.new()
	background.color = Neon.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := UiKit.vbox(8)
	margin.add_child(root)
	root.add_child(_build_toolbar())
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_events = _make_text()
	_events.name = "Event Log"
	_tabs.add_child(_events)
	_decisions = _make_text()
	_decisions.name = "AI Decision Log"
	_tabs.add_child(_decisions)
	_tabs.add_child(_build_performance())
	_evolution = _make_text()
	_evolution.name = "Evolution Log"
	_tabs.add_child(_evolution)
	_status = UiKit.label("", 13, Neon.TEXT_MUTED)
	root.add_child(_status)
	Sfx.wire(self)
	Events.request_log_window.connect(_on_request)
	GameLog.entry_added.connect(func(_e: Dictionary) -> void: _dirty.events = true; _dirty.evolution = true)
	GameLog.decision_logged.connect(func(_e: Dictionary) -> void: _dirty.decisions = true)
	GameLog.perf_logged.connect(_on_perf)
	GameLog.cleared.connect(func() -> void:
		_dirty = {"events": true, "decisions": true, "evolution": true}
		_latency_chart.clear()
		_nodes_chart.clear()
		_fps_chart.clear())


func _make_text() -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_following = true
	text.selection_enabled = true
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	return text


func _build_toolbar() -> Control:
	var panel := UiKit.panel("Inset")
	var column := UiKit.vbox(6)
	panel.add_child(UiKit.margin(column, 8))
	var first := UiKit.hbox(8)
	column.add_child(first)
	_search = LineEdit.new()
	_search.placeholder_text = "Search log text…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _mark_all())
	first.add_child(_search)
	first.add_child(UiKit.label("Severity", 13, Neon.TEXT_MUTED))
	_severity = OptionButton.new()
	for name_text in ["All", "Notable+", "Important+", "Critical"]:
		_severity.add_item(name_text)
	_severity.item_selected.connect(func(_i: int) -> void: _mark_all())
	first.add_child(_severity)
	first.add_child(UiKit.label("Category", 13, Neon.TEXT_MUTED))
	_category = OptionButton.new()
	_category.add_item("All")
	for name_text in ["Movement", "Infection", "Reproduction", "Combat", "Death", "Evolution", "Environment", "System"]:
		_category.add_item(name_text)
	_category.item_selected.connect(func(_i: int) -> void: _mark_all())
	first.add_child(_category)
	var second := UiKit.hbox(8)
	column.add_child(second)
	second.add_child(UiKit.label("Organism #", 13, Neon.TEXT_MUTED))
	_organism = SpinBox.new()
	_organism.min_value = 0
	_organism.max_value = 99999
	_organism.tooltip_text = "0 = all organisms"
	_organism.value_changed.connect(func(_v: float) -> void: _mark_all())
	second.add_child(_organism)
	second.add_child(UiKit.label("Round", 13, Neon.TEXT_MUTED))
	_round = SpinBox.new()
	_round.min_value = 0
	_round.max_value = 99999
	_round.tooltip_text = "0 = all rounds"
	_round.value_changed.connect(func(_v: float) -> void: _mark_all())
	second.add_child(_round)
	_pause_stream = CheckButton.new()
	_pause_stream.text = "Pause streaming"
	_pause_stream.focus_mode = Control.FOCUS_NONE
	_pause_stream.toggled.connect(func(on: bool) -> void:
		if not on:
			_mark_all())
	second.add_child(_pause_stream)
	second.add_child(UiKit.spacer(0, 0, true))
	var jsonl := UiKit.button("Export JSONL")
	jsonl.pressed.connect(func() -> void: _export(GameLog.export_jsonl()))
	second.add_child(jsonl)
	var csv := UiKit.button("Export CSV")
	csv.pressed.connect(func() -> void: _export(GameLog.export_csv()))
	second.add_child(csv)
	var folder := UiKit.button("Open folder")
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(GameLog.EXPORT_DIR)
		OS.shell_open(ProjectSettings.globalize_path(GameLog.EXPORT_DIR)))
	second.add_child(folder)
	return panel


func _build_performance() -> Control:
	var root := UiKit.vbox(8)
	root.name = "Performance Monitor"
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(UiKit.margin(grid, 4))
	for key in ["Decision latency", "Search nodes", "MCTS simulations", "FPS", "CPU frame time", "Memory", "Decisions logged", "Algorithm"]:
		var card := UiKit.panel("Inset")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := UiKit.vbox(0)
		card.add_child(UiKit.margin(inner, 8))
		inner.add_child(UiKit.heading(key))
		var value := UiKit.label("-", 20, Neon.CYAN)
		inner.add_child(value)
		grid.add_child(card)
		_perf_labels[key] = value
	var charts := UiKit.hbox(10)
	root.add_child(charts)
	_latency_chart = _chart(charts, "Decision latency (ms)", Neon.CYAN)
	_nodes_chart = _chart(charts, "Search nodes", Neon.PURPLE)
	_fps_chart = _chart(charts, "FPS", Neon.GREEN)
	_perf_table = _make_text()
	_perf_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_perf_table)
	return root


func _chart(parent: Control, title_text: String, color: Color) -> SparkChart:
	var column := UiKit.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.heading(title_text))
	var chart := SparkChart.new()
	chart.line_color = color
	chart.max_points = 120
	chart.custom_minimum_size = Vector2(0, 96)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(chart)
	parent.add_child(column)
	return chart


func _on_request(show_window: bool) -> void:
	if show_window:
		popup_centered() if not visible else grab_focus()
		_mark_all()
		Sfx.play_ui("ui_open")
	else:
		_close()


func _close() -> void:
	hide()
	Sfx.play_ui("ui_close")


func _export(path: String) -> void:
	if path == "":
		_status.text = "Export failed."
		Sfx.play_ui("ui_error")
	else:
		_status.text = "Exported: " + path
		Sfx.play_ui("ui_save")


func _mark_all() -> void:
	_dirty = {"events": true, "decisions": true, "evolution": true}


func _on_perf(sample: Dictionary) -> void:
	_latency_chart.push(sample.latency_ms)
	_nodes_chart.push(sample.nodes)
	_fps_chart.push(sample.fps)


func _process(delta: float) -> void:
	if not visible:
		return
	_perf_clock += delta
	var tab := _tabs.get_current_tab_control()
	if tab != null and _counts.has(tab) and not _status.text.begins_with("Exported"):
		_status.text = _counts[tab]
	if _perf_clock > 0.5:
		_perf_clock = 0.0
		_update_performance()
	_rebuild_clock += delta
	if _rebuild_clock < 0.25 or _pause_stream.button_pressed:
		return
	_rebuild_clock = 0.0
	if _dirty.events:
		_dirty.events = false
		_render_events(_events, GameLog.entries, false)
	if _dirty.evolution:
		_dirty.evolution = false
		_render_events(_evolution, GameLog.evolution, true)
	if _dirty.decisions:
		_dirty.decisions = false
		_render_decisions()


func _passes(entry: Dictionary) -> bool:
	var needed := _severity.selected
	if needed > 0 and SEVERITIES.find(entry.sev) < needed:
		return false
	if _category.selected > 0 and entry.cat != _category.get_item_text(_category.selected):
		return false
	if int(_organism.value) > 0 and entry.org != int(_organism.value):
		return false
	if int(_round.value) > 0 and entry.round != int(_round.value):
		return false
	var query := _search.text.strip_edges().to_lower()
	return query == "" or entry.msg.to_lower().contains(query)


func _render_events(target: RichTextLabel, source: Array, detail: bool) -> void:
	target.clear()
	var matches: Array = []
	for index in range(source.size() - 1, -1, -1):
		if _passes(source[index]):
			matches.append(source[index])
			if matches.size() >= MAX_RENDERED:
				break
	matches.reverse()
	var round_number := -1
	for entry in matches:
		if entry.round != round_number:
			round_number = entry.round
			target.append_text("\n[color=#%s][b]ROUND %d[/b][/color]\n" % [Neon.CYAN.to_html(false), round_number])
		var tint := Neon.severity_color(entry.sev) if entry.sev != "info" else Neon.TEXT
		target.append_text("[color=#%s][%s][/color] [color=#%s][%s][/color] [color=#%s]%s[/color]\n" % [
			Neon.TEXT_DIM.to_html(false), entry.time, Neon.category_color(entry.cat).to_html(false), entry.cat, tint.to_html(false), entry.msg])
	_counts[target] = "%d of %d entries shown" % [matches.size(), source.size()]


func _render_decisions() -> void:
	_decisions.clear()
	var shown := 0
	for index in range(GameLog.decisions.size() - 1, -1, -1):
		var data: Dictionary = GameLog.decisions[index]
		if int(_organism.value) > 0 and data.org != int(_organism.value):
			continue
		if int(_round.value) > 0 and data.round != int(_round.value):
			continue
		var query := _search.text.strip_edges().to_lower()
		if query != "" and not (str(data).to_lower().contains(query)):
			continue
		shown += 1
		if shown > 80:
			break
		var team_name := "Bacterium" if data.team == Sim.BACTERIA else "T cell"
		var text := "[color=#%s][b]AGENT: %s #%d[/b][/color]   ROUND: %d   [color=#%s](%s)[/color]\n" % [
			Neon.team_color(data.team).to_html(false), team_name, data.org, data.round, Neon.TEXT_DIM.to_html(false), data.time]
		text += "[color=#%s]Algorithm: %s   (%s)[/color]\n" % [Neon.PURPLE.to_html(false), data.algorithm, " → ".join(PackedStringArray(data.pipeline))]
		text += "[color=#%s]Propositions: %s[/color]\n" % [Neon.TEXT_DIM.to_html(false), data.propositions]
		if not data.priorities.is_empty():
			var parts: PackedStringArray = []
			for key in data.priorities:
				parts.append("%s %.2f" % [key, data.priorities[key]])
			text += "Fuzzy priorities: %s\n" % ", ".join(parts)
		text += "Candidate Actions:\n"
		var kinds: Array = data.scores.keys()
		kinds.sort_custom(func(a: String, b: String) -> bool: return data.scores[a] > data.scores[b])
		for kind in kinds:
			var chosen: bool = kind == data.selected
			text += "  [color=#%s]%-10s %.2f%s[/color]\n" % [(Neon.GREEN if chosen else Neon.TEXT).to_html(false), kind, data.scores[kind], "  ◀" if chosen else ""]
		text += "[b]Selected Action: [color=#%s]%s[/color][/b]\n" % [Neon.GREEN.to_html(false), data.selected]
		text += "Search Simulations: %d   Search Nodes: %d   Decision Time: %.1f ms\n\n" % [data.simulations, data.nodes, data.time_ms]
		_decisions.append_text(text)
	if shown == 0:
		_decisions.append_text("[color=#%s]No AI decisions yet. They appear here as the AI plays.[/color]" % Neon.TEXT_DIM.to_html(false))


func _update_performance() -> void:
	var last: Dictionary = GameLog.perf[-1] if not GameLog.perf.is_empty() else {}
	_perf_labels["Decision latency"].text = "%.1f ms" % last.get("latency_ms", 0.0)
	_perf_labels["Search nodes"].text = str(last.get("nodes", 0))
	_perf_labels["MCTS simulations"].text = str(last.get("sims", 0))
	_perf_labels["FPS"].text = str(Engine.get_frames_per_second())
	_perf_labels["CPU frame time"].text = "%.1f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_perf_labels["Memory"].text = "%.0f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_perf_labels["Decisions logged"].text = str(GameLog.decisions.size())
	_perf_labels["Algorithm"].text = str(last.get("algorithm", "-"))
	_perf_table.clear()
	var start := maxi(0, GameLog.perf.size() - 14)
	for index in range(GameLog.perf.size() - 1, start - 1, -1):
		var sample: Dictionary = GameLog.perf[index]
		_perf_table.append_text("[color=#%s][%s][/color] %-10s latency %6.2f ms   nodes %5d   sims %4d   fps %3d\n" % [
			Neon.TEXT_DIM.to_html(false), sample.time, sample.algorithm, sample.latency_ms, sample.nodes, sample.sims, sample.fps])
