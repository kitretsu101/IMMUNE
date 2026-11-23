class_name ScreenStats
extends Control
## Past results and aggregates.

@export var router: MenuRouter

var _summary: HBoxContainer
var _table: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)
	var column := UiKit.vbox(14)
	margin.add_child(column)
	var head := UiKit.hbox(12)
	var back := UiKit.button("‹ Back")
	back.pressed.connect(router.back)
	head.add_child(back)
	head.add_child(UiKit.label("Statistics", 30, Color.WHITE))
	head.add_child(UiKit.spacer(0, 0, true))
	var clear := UiKit.button("Clear history", "DangerButton")
	clear.pressed.connect(func() -> void:
		Config.clear_stats()
		on_show())
	head.add_child(clear)
	column.add_child(head)
	_summary = UiKit.hbox(12)
	column.add_child(_summary)
	var panel := UiKit.panel("Card")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	_table = RichTextLabel.new()
	_table.bbcode_enabled = true
	_table.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(UiKit.margin(_table, 14))


func on_show() -> void:
	var all := Config.load_stats()
	for child in _summary.get_children():
		child.queue_free()
	var games := all.filter(func(r: Dictionary) -> bool: return r.get("kind", "match") == "match")
	var immune := 0
	var bacteria := 0
	var rounds := 0
	for game in games:
		if game.winner == Sim.IMMUNE:
			immune += 1
		elif game.winner == Sim.BACTERIA:
			bacteria += 1
		rounds += int(game.round)
	_stat("Matches played", str(games.size()), Neon.CYAN)
	_stat("Immune wins", str(immune), Neon.IMMUNE)
	_stat("Bacteria wins", str(bacteria), Neon.BACTERIA)
	_stat("Draws", str(games.size() - immune - bacteria), Neon.YELLOW)
	_stat("Avg rounds", "%.1f" % (float(rounds) / maxf(1.0, games.size())), Neon.PURPLE)
	_table.clear()
	if all.is_empty():
		_table.append_text("[color=#%s]No results yet. Finish a match or run an experiment and it will appear here.[/color]" % Neon.TEXT_DIM.to_html(false))
		return
	for index in range(all.size() - 1, maxi(-1, all.size() - 41), -1):
		var entry: Dictionary = all[index]
		if entry.get("kind", "match") == "experiment":
			_table.append_text("[color=#%s]%s[/color]  [color=#%s]EXPERIMENT[/color]  %s vs %s · %d games · immune %d / bacteria %d / draw %d · avg %.1f rounds\n" % [
				Neon.TEXT_DIM.to_html(false), entry.date, Neon.ORANGE.to_html(false), Sim.ALGO_NAMES[int(entry.bact_ai)], Sim.ALGO_NAMES[int(entry.immune_ai)],
				int(entry.runs), int(entry.immune_wins), int(entry.bacteria_wins), int(entry.draws), entry.avg_rounds])
		else:
			var tint := Neon.team_color(int(entry.winner)) if int(entry.winner) > 0 else Neon.YELLOW
			_table.append_text("[color=#%s]%s[/color]  [color=#%s]%s[/color]  %s · %d rounds · peak bacteria %d · %d mutations\n" % [
				Neon.TEXT_DIM.to_html(false), entry.date, tint.to_html(false), Sim.MODE_NAMES[int(entry.mode)], entry.text,
				int(entry.round), int(entry.bact_peak), int(entry.mutations)])


func _stat(title: String, value: String, color: Color) -> void:
	var card := UiKit.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UiKit.vbox(0)
	card.add_child(UiKit.margin(column, 12))
	column.add_child(UiKit.heading(title))
	column.add_child(UiKit.label(value, 28, color))
	_summary.add_child(card)
