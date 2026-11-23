class_name HudEnvironmentPanel
extends PanelContainer
## Right panel: tissue and environment gauges plus the board visualisation toggles.

@export var world: WorldHost

var _meters: Dictionary = {}
var _view_buttons: Array[Button] = []
var _sandbox_box: VBoxContainer


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	custom_minimum_size = Vector2(236, 0)
	var column := UiKit.vbox(4)
	add_child(UiKit.margin(column, 10))
	column.add_child(UiKit.heading("Board view"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	var group := ButtonGroup.new()
	for index in Events.VIEW_NAMES.size():
		var button := UiKit.button(Events.VIEW_NAMES[index])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = index == Config.view_mode
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 26)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_set_view.bind(index))
		grid.add_child(button)
		_view_buttons.append(button)
	column.add_child(UiKit.spacer(0, 4))
	column.add_child(UiKit.heading("Tissue"))
	_meters["Healthy"] = UiKit.meter_row(column, "Healthy", Color("#19B7C4"))
	_meters["Infected"] = UiKit.meter_row(column, "Infected", Neon.TISSUE_INFECTED)
	_meters["Damaged"] = UiKit.meter_row(column, "Damaged", Neon.ORANGE)
	_meters["Destroyed"] = UiKit.meter_row(column, "Destroyed", Neon.GREY)
	column.add_child(UiKit.spacer(0, 4))
	column.add_child(UiKit.heading("Environment"))
	_meters["Nutrients"] = UiKit.meter_row(column, "Nutrients", Neon.YELLOW)
	_meters["Oxygen"] = UiKit.meter_row(column, "Oxygen", Neon.CYAN)
	_meters["Antibiotic"] = UiKit.meter_row(column, "Antibiotic", Neon.PURPLE)
	_meters["Core"] = UiKit.meter_row(column, "Human cells", Neon.RED)
	_sandbox_box = UiKit.vbox(4)
	column.add_child(_sandbox_box)
	_sandbox_box.add_child(UiKit.heading("Sandbox tools"))
	_sandbox_box.add_child(UiKit.label("Hover a tile, then press:\n1 bacterium · 2 T cell · Del remove\n3 infect · 4 biofilm · 5 nutrients", 12, Neon.TEXT_MUTED))
	var dose := UiKit.button("Add antibiotic dose", "", "Raises antibiotic concentration")
	dose.pressed.connect(func() -> void:
		world.state.antibiotic = minf(1.0, world.state.antibiotic + 0.25)
		world.touch())
	_sandbox_box.add_child(dose)
	var feed := UiKit.button("Feed the board", "", "Adds nutrients everywhere")
	feed.pressed.connect(func() -> void:
		for tile in world.state.count:
			world.state.nutrients[tile] = minf(Balance.NUTRIENT_CAP, world.state.nutrients[tile] + 0.5)
		world.touch())
	_sandbox_box.add_child(feed)
	Events.state_changed.connect(_refresh)
	Events.view_mode_changed.connect(func(mode: int) -> void:
		if mode < _view_buttons.size():
			_view_buttons[mode].set_pressed_no_signal(true))
	_refresh()


func _set_view(index: int) -> void:
	Config.view_mode = index
	Events.view_mode_changed.emit(index)


func _set_meter(key: String, value: float, text := "") -> void:
	var pair: Array = _meters[key]
	pair[0].value = clampf(value, 0.0, 1.0)
	pair[1].text = text if text != "" else "%d%%" % roundi(value * 100.0)


func _refresh() -> void:
	var state := world.state
	if state == null:
		return
	_sandbox_box.visible = state.setup.mode == Sim.Mode.SANDBOX
	_set_meter("Healthy", state.tissue_fraction(Sim.Tissue.HEALTHY))
	_set_meter("Infected", state.tissue_fraction(Sim.Tissue.INFECTED))
	_set_meter("Damaged", state.tissue_fraction(Sim.Tissue.DAMAGED))
	_set_meter("Destroyed", state.tissue_fraction(Sim.Tissue.DESTROYED))
	_set_meter("Nutrients", state.average_nutrient() / Balance.NUTRIENT_CAP)
	_set_meter("Oxygen", state.oxygen)
	_set_meter("Antibiotic", state.antibiotic)
	_set_meter("Core", float(state.core_infected()) / maxf(1.0, state.core.size()), "%d / %d" % [state.core_infected(), state.core.size()])
