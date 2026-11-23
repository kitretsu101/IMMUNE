class_name HudPopulationPanel
extends PanelContainer
## Left panel: bacterial and immune population statistics with a live population chart.

@export var world: WorldHost

var _values: Dictionary = {}
var _chart: SparkChart
var _last_round := 0


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	custom_minimum_size = Vector2(236, 0)
	var column := UiKit.vbox(3)
	add_child(UiKit.margin(column, 10))
	var head := UiKit.label("BACTERIA", 14, Neon.BACTERIA)
	column.add_child(head)
	for key in ["Total", "Living", "Dead", "New offspring", "Dominant strain"]:
		_values[key] = UiKit.stat_row(column, key, Neon.BACTERIA if key == "Living" else Neon.TEXT)
	column.add_child(UiKit.spacer(0, 6))
	column.add_child(UiKit.label("IMMUNE", 14, Neon.IMMUNE))
	for key in ["Total cells", "Active", "Dead cells", "Eliminations"]:
		_values[key] = UiKit.stat_row(column, key, Neon.IMMUNE if key == "Active" else Neon.TEXT)
	column.add_child(UiKit.spacer(0, 6))
	column.add_child(UiKit.heading("Population over rounds"))
	_chart = SparkChart.new()
	_chart.line_color = Neon.BACTERIA
	_chart.secondary_color = Neon.IMMUNE
	_chart.custom_minimum_size = Vector2(0, 64)
	column.add_child(_chart)
	Events.state_changed.connect(_refresh)
	Events.round_changed.connect(_on_round)
	world.world_rebuilt.connect(func() -> void:
		_chart.clear()
		_last_round = 0)
	_refresh()


func _on_round(round_number: int) -> void:
	if world.state and round_number != _last_round:
		_last_round = round_number
		_chart.push(world.state.count_team(Sim.BACTERIA), world.state.count_team(Sim.IMMUNE))


func _refresh() -> void:
	var state := world.state
	if state == null:
		return
	if _chart.series_a.is_empty():
		_chart.push(state.count_team(Sim.BACTERIA), state.count_team(Sim.IMMUNE))
	var living := state.count_team(Sim.BACTERIA)
	_values["Total"].text = str(state.stats.bact_born)
	_values["Living"].text = str(living)
	_values["Dead"].text = str(state.stats.bact_dead)
	_values["New offspring"].text = str(state.stats.offspring_round)
	_values["Dominant strain"].text = state.dominant_strain() if living > 0 else "-"
	var active := 0
	for cell in state.living(Sim.IMMUNE):
		if cell.has_effect("Activated"):
			active += 1
	_values["Total cells"].text = str(state.stats.immune_born)
	_values["Active"].text = "%d / %d" % [active, state.count_team(Sim.IMMUNE)]
	_values["Dead cells"].text = str(state.stats.immune_dead)
	_values["Eliminations"].text = str(state.stats.eliminations)
