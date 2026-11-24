class_name HudOrganismPanel
extends PanelContainer
## Bottom panel: everything about the clicked organism. Follows hover when nothing is selected.

@export var world: WorldHost

var _selected := 0
var _hovered := 0
var _title: Label
var _subtitle: Label
var _empty: Label
var _body: GridContainer
var _bars: Dictionary = {}
var _fields: Dictionary = {}
var _tags: HBoxContainer
var _swatch: ColorRect


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	custom_minimum_size = Vector2(500, 0)
	var root := UiKit.vbox(6)
	add_child(UiKit.margin(root, 10))
	var head := UiKit.hbox(8)
	root.add_child(head)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(6, 30)
	head.add_child(_swatch)
	var titles := UiKit.vbox(0)
	_title = UiKit.label("No organism selected", 18, Color.WHITE)
	_subtitle = UiKit.label("", 13, Neon.TEXT_MUTED)
	titles.add_child(_title)
	titles.add_child(_subtitle)
	head.add_child(titles)
	head.add_child(UiKit.spacer(0, 0, true))
	_tags = UiKit.hbox(4)
	head.add_child(_tags)
	_empty = UiKit.label("Click a bacterium or immune cell on the board to inspect it.", 14, Neon.TEXT_DIM)
	root.add_child(_empty)
	_body = GridContainer.new()
	_body.columns = 3
	_body.add_theme_constant_override("h_separation", 18)
	_body.add_theme_constant_override("v_separation", 2)
	root.add_child(_body)
	_add_bar("Health", Neon.GREEN)
	_add_bar("Energy", Neon.YELLOW)
	for key in ["Position", "Generation", "Antigen", "Infectivity", "Reproduction", "Immune evasion", "Memory", "Attack", "Detection", "Move range", "Action", "Target", "AI algorithm", "Mutations", "Last decision", "Inherited from"]:
		var cell := UiKit.hbox(6)
		cell.add_child(UiKit.label(key, 13, Neon.TEXT_MUTED))
		var value := UiKit.label("-", 13, Neon.TEXT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(value)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(150, 0)
		_body.add_child(cell)
		_fields[key] = [cell, value]
	Events.organism_selected.connect(func(id: int) -> void:
		_selected = id
		_refresh())
	Events.organism_hovered.connect(func(id: int) -> void:
		_hovered = id
		if _selected == 0:
			_refresh())
	Events.state_changed.connect(_refresh)
	_refresh()


func _add_bar(key: String, color: Color) -> void:
	var box := UiKit.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(150, 0)
	var head := UiKit.hbox(4)
	head.add_child(UiKit.label(key, 13, Neon.TEXT_MUTED))
	var value := UiKit.label("", 13, color, HORIZONTAL_ALIGNMENT_RIGHT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(value)
	box.add_child(head)
	var meter := UiKit.bar(color, 6.0)
	box.add_child(meter)
	_body.add_child(box)
	_bars[key] = [box, meter, value]


func _refresh() -> void:
	var state := world.state
	var id := _selected if _selected > 0 else _hovered
	var organism: Organism = state.get_org(id) if state and id > 0 else null
	_empty.visible = organism == null
	_body.visible = organism != null
	_swatch.visible = organism != null
	for child in _tags.get_children():
		child.queue_free()
	if organism == null:
		_title.text = "No organism selected"
		_subtitle.text = ""
		return
	var bacterium := organism.team == Sim.BACTERIA
	var tint := Neon.team_color(organism.team)
	_swatch.color = tint
	_title.text = "%s #%d%s" % ["Bacterium" if bacterium else "T cell", organism.id, "" if _selected > 0 else "  (hover)"]
	_subtitle.text = ("Strain %s · antigen %s · generation %d" % [organism.strain, organism.antigen_name(), organism.generation]) if bacterium \
			else "Immune cell · generation %d" % organism.generation
	for effect in organism.effects:
		_tags.add_child(UiKit.chip(effect, Neon.PURPLE if effect == "Shifted" else (Neon.CYAN if effect == "Activated" else Neon.MAGENTA)))
	_bars["Health"][2].text = "%.1f / %.0f" % [organism.health, organism.max_health]
	_bars["Health"][1].value = organism.health / organism.max_health
	_bars["Energy"][0].visible = true
	_bars["Energy"][1].value = organism.energy / ActionExecutor.MAX_ENERGY
	if bacterium:
		_bars["Energy"][2].text = "%.1f  (split: 3.4)" % organism.energy if organism.energy < Balance.REPRO_COST else "%.1f" % organism.energy
	else:
		_bars["Energy"][2].text = "%.1f  (clone: 2.5)" % organism.energy if organism.energy < Balance.CLONE_COST else "%.1f" % organism.energy
	var col := organism.tile % 10
	var row := organism.tile / 10
	_put("Position", "(%d, %d)" % [col, row])
	_put("Generation", str(organism.generation), true)
	_put("Antigen", "%s · %s" % [organism.antigen_name(), organism.strain], bacterium)
	_put("Infectivity", "%d / 10" % organism.infectivity, bacterium)
	_put("Reproduction", "%d / 10" % organism.reproduction, bacterium)
	_put("Immune evasion", "%d / 10" % organism.evasion, bacterium)
	var memory_text := "none"
	if not organism.memory.is_empty():
		var parts: PackedStringArray = []
		for key in organism.memory:
			parts.append("%s ×%d" % [Sim.ANTIGENS[int(key)], int(organism.memory[key])])
		memory_text = ", ".join(parts)
	_put("Memory", memory_text, not bacterium)
	_put("Attack", "%d / 10" % organism.attack, not bacterium)
	_put("Detection", "%d / 10" % organism.detection, not bacterium)
	_put("Move range", str(organism.move_range), true)
	_put("Action", organism.current_action, true)
	_put("Target", organism.current_target, true)
	_put("AI algorithm", organism.algorithm if organism.algorithm != "" else "-", true)
	_put("Mutations", ", ".join(PackedStringArray(organism.mutations)) if not organism.mutations.is_empty() else "none", true)
	_put("Last decision", organism.last_decision, true)
	_put("Inherited from", ("#%d" % organism.parent_id) if organism.parent_id > 0 else "founder", true)


func _put(key: String, value: String, visible_row := true) -> void:
	var pair: Array = _fields[key]
	pair[0].visible = visible_row
	pair[1].text = value
	pair[1].tooltip_text = value
