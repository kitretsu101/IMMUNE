class_name HudTutorial
extends Control
## Guided tour that starts in the middle of a staged match. Everything except the focus is darkened,
## the focus gets a glowing coloured outline, and a panel explains it with its live parameters.

@export var world: WorldHost
@export var camera: CameraController
@export var top_bar: Control
@export var left_panel: Control
@export var right_panel: Control
@export var organism_panel: Control
@export var action_bar: Control
@export var event_log: Control
@export var toolbar: Control

var _steps: Array = []
var _index := 0
var _material := ShaderMaterial.new()
var _dim: ColorRect
var _card: PanelContainer
var _title: Label
var _body: RichTextLabel
var _state: RichTextLabel
var _state_box: PanelContainer
var _counter: Label
var _next: Button
var _back: Button
var _final := false
var _refresh_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Config.tutorial:
		visible = false
		return
	var cyan := Neon.CYAN
	_steps = [
		["Welcome - you joined mid-battle", "This is round 6 of a live match. You command the blue **T cells**; bacteria are infecting the gold **human cells**. The tour will light up each important thing on the board and show its live numbers.", null, cyan, ""],
		["The human cells", "The seven gold cells are what you protect. If **all seven turn red** (infected or destroyed) the bacteria win. One is already infected.", {"core": true}, Neon.YELLOW, "core"],
		["Your T cell", "Blue cells are yours. This one is **ACTIVE** (it spotted bacteria, so it hits harder) and has **immune memory** of antigen A from earlier kills. It can move up to its range, attack a neighbour, or clone itself; clones inherit memory and may drift one trait by -1, 0 or +1.", {"org": "tcell"}, Neon.IMMUNE, "org"],
		["Immune memory", "When a T cell **eliminates** a bacterium it remembers that bacterium's **antigen** (A, B, C or D). Memory is **specific**: it only helps against that antigen, adding **+2.5% hit chance per level** (up to level 3). Memory cells **glow gold** with a **MEMORY** tag, and clones inherit it. A bacterium that shifts antigen (a new strain) escapes the memory.", {"org": "tcell"}, Color(1.0, 0.82, 0.45), "org"],
		["A normal bacterium", "Green rods are bacteria. **Infectivity** is the chance to infect tissue, **reproduction** the chance to split at round end, **evasion** makes your attacks miss, **energy** pays for reproduction.", {"org": "enemy"}, Neon.BACTERIA, "org"],
		["A mutant", "Offspring can mutate **one trait by +-1** (or rarely change antigen). Mutations are **inherited**. Colours never change: a mutant has a **purple ring**, a **MUTANT** tag and a purple caption when it happens. Its inspector lists the mutations and its parent. This one has higher evasion, so it is harder to hit.", {"org": "mutant"}, Neon.PURPLE, "org"],
		["A hungry bacterium", "Bacteria need **energy**. Below 1 it shows **HUNGRY**; at 0 it **starves** and loses health, and it cannot reproduce (needs 2.5). Cut colonies off from nutrient pickups and infected tiles to starve them.", {"org": "hungry"}, Neon.YELLOW, "org"],
		["Biofilm and a new strain", "This bacterium invested energy in **biofilm** (magenta tile): it shields the colony but **slows reproduction** for a few rounds. Its **B-2** strain came from an **antigen shift** - T cells have no memory of it, so it is harder to hit.", {"org": "biofilm"}, Neon.BIOFILM, "org"],
		["Nutrient pickup", "Glowing orbs are **nutrients**. A bacterium that steps onto one grabs it at once and is drawn in by a trail of light (**+NUTRIENTS**); leftovers are eaten at round end. New food keeps appearing, so fights happen around it.", {"tile": "orb"}, Neon.YELLOW, "tile"],
		["Healthy tissue", "Dark teal tiles are **healthy**. Bacteria can infect them; your cells can walk across them freely.", {"tile": "healthy"}, Neon.TEAL.lightened(0.4), "tile"],
		["Damaged tissue", "Orange tiles are **damaged**: freshly cleansed or hurt. They are easier to re-infect, but **heal back to healthy after 3 rounds**.", {"tile": "damaged"}, Neon.ORANGE, "tile"],
		["Destroyed tissue", "Grey tiles are **destroyed**: infected for 8 rounds. They cannot be infected again and give no food. If a gold human cell is destroyed it counts as lost.", {"tile": "destroyed"}, Neon.GREY.lightened(0.3), "tile"],
		["Biofilm tile", "Magenta lattice marks **biofilm**. It blunts damage to the bacterium standing there (-0.4 per level) and fades once the colony leaves.", {"tile": "filmtile"}, Neon.BIOFILM, "tile"],
		["Infected tissue", "Red tiles are **infected**. They feed the colony and can spread. Left alone for 8 rounds they are **destroyed**. A T cell **standing on infected tissue cleanses it** (CLEANSED), leaving damaged tissue that heals in 3 rounds.", {"tile": "infected"}, Neon.RED, "tile"],
		["Top bar", "**Round**, elapsed time, mode, status, whose turn it is and your **actions left** this turn, and the simulation speed.", {"ui": "top"}, cyan, ""],
		["Population panel", "Living and dead bacteria, offspring this round, **dominant strain**, and your cells: **active**, dead and **eliminations**, with a population chart.", {"ui": "left"}, cyan, ""],
		["Environment panel", "Healthy / infected / damaged / destroyed tissue and the nutrient level. **Board view** buttons recolour the board (Infection, Nutrients, Immune, Evolution).", {"ui": "right"}, cyan, ""],
		["Inspector", "Click any cell to see its health, energy, traits, generation, mutations, current action and the AI's last decision.", {"ui": "organism"}, cyan, ""],
		["Your actions", "**Move/Attack [M]** (cyan tiles move, orange attack), **Clone [C]**, **Wait [W]**, **End turn [Space]**. Each cell acts once per turn.", {"ui": "actions"}, cyan, ""],
		["Event log and captions", "Captions on the board and this log tell you what happened: **INFECTED!**, **MUTATION**, **SPLIT**, damage numbers, **MISS**, **CLEANSED**, **+NUTRIENTS**.", {"ui": "log"}, cyan, ""],
		["Simulation controls", "Pause, stop, step a round, restart, save, load, speed 0.25x to 16x, unlimited mode, and the **log window** (L) with AI decisions and performance.", {"ui": "toolbar"}, cyan, ""],
		["Your turn", "Select your active T cell, press **M** and attack the nearest bacterium (orange tile). Clone when you have spare actions. Good luck!", null, cyan, ""],
	]
	_build()
	_show_step(0)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_material.shader = load("res://scenes/shaders/spotlight.gdshader")
	_dim.material = _material
	add_child(_dim)
	_card = UiKit.panel("Card")
	_card.custom_minimum_size = Vector2(500, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var column := UiKit.vbox(8)
	_card.add_child(UiKit.margin(column, 16))
	var head := UiKit.hbox(8)
	column.add_child(head)
	_counter = UiKit.label("", 12, Neon.CYAN)
	head.add_child(_counter)
	head.add_child(UiKit.spacer(0, 0, true))
	var skip := UiKit.button("Skip tutorial", "FlatButton")
	skip.pressed.connect(_finish)
	head.add_child(skip)
	_title = UiKit.label("", 24, Color.WHITE)
	column.add_child(_title)
	_body = _rich(15)
	column.add_child(_body)
	_state_box = UiKit.panel("Inset")
	column.add_child(_state_box)
	_state = _rich(14)
	_state_box.add_child(UiKit.margin(_state, 8))
	var row := UiKit.hbox(8)
	column.add_child(row)
	_back = UiKit.button("Back")
	_back.pressed.connect(func() -> void: _show_step(_index - 1))
	row.add_child(_back)
	row.add_child(UiKit.spacer(0, 0, true))
	_next = UiKit.button("Next", "AccentButton")
	_next.custom_minimum_size = Vector2(110, 0)
	_next.pressed.connect(_advance)
	row.add_child(_next)


func _rich(size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(466, 0)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("default_color", Neon.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _advance() -> void:
	if _final:
		_finish()
	else:
		_show_step(_index + 1)


func _show_step(index: int) -> void:
	_index = clampi(index, 0, _steps.size() - 1)
	var step: Array = _steps[_index]
	_final = _index == _steps.size() - 1
	_title.text = step[0]
	_body.text = _markdown(step[1])
	_counter.text = "STEP %d / %d" % [_index + 1, _steps.size()]
	_next.text = "Start playing" if _final else "Next"
	_back.disabled = _index == 0
	_material.set_shader_parameter("outline", step[3])
	var focus := _focus_ids(step[2])
	var organism_id: int = focus.get("org", 0)
	Events.organism_selected.emit(organism_id)
	_refresh_state()
	_card.reset_size()
	UiKit.fade_in(_card, 0.0)


func _markdown(text: String) -> String:
	var pieces := text.split("**")
	var out := ""
	for index in pieces.size():
		out += ("[b][color=#%s]%s[/color][/b]" % [Neon.CYAN.to_html(false), pieces[index]]) if index % 2 == 1 else pieces[index]
	return out


func _focus_ids(target: Variant) -> Dictionary:
	if typeof(target) != TYPE_DICTIONARY:
		return {}
	var refs: Dictionary = Config.tutorial_refs
	var out := {}
	if target.has("org"):
		out["org"] = int(refs.get(target.org, 0))
	if target.has("tile"):
		out["tile"] = int(refs.get(target.tile, -1))
	if target.has("core"):
		out["core"] = true
	if target.has("ui"):
		out["ui"] = _ui(target.ui)
	return out


func _ui(key: String) -> Control:
	match key:
		"top": return top_bar
		"left": return left_panel
		"right": return right_panel
		"organism": return organism_panel
		"actions": return action_bar
		"log": return event_log
		"toolbar": return toolbar
	return null


func _project(tile: int, lift := 0.4) -> Vector2:
	return camera.unproject_position(camera.tile_board.positions[tile] + Vector3.UP * lift)


## Screen rectangle of the current focus; an empty rect means "no focus".
func _focus_rect(step: Array) -> Rect2:
	var focus := _focus_ids(step[2])
	if focus.has("ui") and focus.ui != null:
		return (focus.ui as Control).get_global_rect().grow(6)
	var state := world.state
	if focus.has("org") and state:
		var organism := state.get_org(focus.org)
		if organism:
			var center := _project(organism.tile, 0.5)
			return Rect2(center - Vector2(62, 74), Vector2(124, 124))
	if focus.has("tile") and focus.tile >= 0:
		var center := _project(focus.tile, 0.3)
		return Rect2(center - Vector2(70, 50), Vector2(140, 100))
	if focus.has("core") and state:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for tile in state.core:
			var p := _project(tile, 0.2)
			low = low.min(p)
			high = high.max(p)
		return Rect2(low - Vector2(80, 60), high - low + Vector2(160, 120))
	return Rect2()


func _state_text(step: Array) -> String:
	var state := world.state
	var focus := _focus_ids(step[2])
	if state == null or focus.is_empty():
		return ""
	var dim := Neon.TEXT_MUTED.to_html(false)
	var hi := Neon.CYAN.to_html(false)
	var lines := PackedStringArray()
	if focus.has("org"):
		var o := state.get_org(focus.org)
		if o == null:
			return ""
		lines.append("[b]%s[/b]  at (%d,%d)  ·  generation %d" % [o.label(), o.tile % 10, o.tile / 10, o.generation])
		lines.append("Health [color=#%s]%.1f / %.0f[/color]" % [hi, o.health, o.max_health])
		if o.team == Sim.BACTERIA:
			lines.append("Strain [color=#%s]%s[/color] · Energy [color=#%s]%.1f[/color]%s" % [hi, o.strain, hi, o.energy, "  [color=#%s](HUNGRY)[/color]" % Neon.YELLOW.to_html(false) if o.energy < 1.0 else ""])
			lines.append("Infectivity %d · Reproduction %d · Evasion %d" % [o.infectivity, o.reproduction, o.evasion])
		else:
			lines.append("Attack %d · Detection %d · Move range %d · Kills %d" % [o.attack, o.detection, o.move_range, o.kills])
			if not o.memory.is_empty():
				for key in o.memory:
					lines.append("[color=#ffd06e]Memory: antigen %s level %d (+%.1f%% hit chance vs %s)[/color]" % [Sim.ANTIGENS[int(key)], int(o.memory[key]), int(o.memory[key]) * 2.5, Sim.ANTIGENS[int(key)]])
		lines.append("Mutations: [color=#%s]%s[/color]" % [Neon.PURPLE.to_html(false), ", ".join(PackedStringArray(o.mutations)) if not o.mutations.is_empty() else "none"])
		if o.parent_id > 0:
			lines.append("Inherited from #%d" % o.parent_id)
		if not o.effects.is_empty():
			lines.append("Effects: " + ", ".join(PackedStringArray(o.effects.keys())))
	elif focus.has("tile"):
		var tile: int = focus.tile
		lines.append("[b]Tile (%d,%d)[/b]" % [tile % 10, tile / 10])
		lines.append("Tissue: [color=#%s]%s[/color]%s" % [hi, Sim.TISSUE_NAMES[state.tissue[tile]], ("  (strain %s, %d rounds)" % [state.tissue_strain[tile], state.tissue_timer[tile]]) if state.tissue[tile] == Sim.Tissue.INFECTED else ""])
		lines.append("Nutrients: [color=#%s]%.1f / %.1f[/color]" % [Neon.YELLOW.to_html(false), state.nutrients[tile], Balance.NUTRIENT_CAP])
		lines.append("Biofilm level: %d" % state.biofilm[tile])
		if state.nutrients[tile] >= 0.4:
			lines.append("Pickup: a bacterium stepping here gains [color=#%s]+%.1f energy[/color] instantly and the orb is consumed" % [Neon.YELLOW.to_html(false), minf(1.2, state.nutrients[tile]) * 1.4])
		lines.append("Meaning: " + ["healthy - can be infected", "infected - feeds bacteria, spreads, destroyed after 8 rounds", "damaged - heals in 3 rounds", "destroyed - lost for good"][state.tissue[tile]])
	elif focus.has("core"):
		lines.append("Infected human cells: [color=#%s]%d / %d[/color]" % [Neon.RED.to_html(false), state.core_infected(), state.core.size()])
		lines.append("Bacteria win at %d / %d" % [state.core.size(), state.core.size()])
	return "\n".join(lines)


func _refresh_state() -> void:
	var text := _state_text(_steps[_index])
	_state_box.visible = text != ""
	_state.text = text


func _process(delta: float) -> void:
	if not visible:
		return
	var viewport := get_viewport_rect().size
	_material.set_shader_parameter("viewport", viewport)
	_refresh_clock += delta
	if _refresh_clock > 0.25:
		_refresh_clock = 0.0
		_refresh_state()
	var step: Array = _steps[_index]
	var rect := _focus_rect(step)
	_dim.visible = not _final
	var has_focus := rect.size != Vector2.ZERO
	if not has_focus:
		rect = Rect2(viewport * 0.5 - Vector2(1, 1), Vector2(2, 2))
	_material.set_shader_parameter("show_outline", 1.0 if has_focus else 0.0)
	var current := Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	var previous: Vector4 = _material.get_shader_parameter("spot") if _material.get_shader_parameter("spot") != null else current
	_material.set_shader_parameter("spot", previous.lerp(current, 0.22))
	var corner := 14.0
	if typeof(step[2]) == TYPE_DICTIONARY and (step[2].has("org") or step[2].has("tile")):
		corner = minf(rect.size.x, rect.size.y) * 0.5
	_material.set_shader_parameter("corner", corner)
	var card_size := _card.size
	var x := (viewport.x - card_size.x) * 0.5
	if has_focus:
		x = clampf(rect.get_center().x + (rect.size.x * 0.5 + 40.0 if rect.get_center().x < viewport.x * 0.5 else -rect.size.x * 0.5 - 40.0 - card_size.x), 20.0, viewport.x - card_size.x - 20.0) if rect.size.x < viewport.x * 0.4 else x
	var y := viewport.y - card_size.y - 90.0 if rect.get_center().y < viewport.y * 0.5 else 90.0
	if rect.size.x < viewport.x * 0.4 and has_focus:
		y = clampf(rect.get_center().y - card_size.y * 0.5, 70.0, viewport.y - card_size.y - 100.0)
	if not has_focus:
		y = (viewport.y - card_size.y) * 0.5
	if _final:
		y = viewport.y - card_size.y - 130.0
	_card.position = _card.position.lerp(Vector2(x, y), 0.25)


func _finish() -> void:
	Config.tutorial = false
	Events.organism_selected.emit(0)
	visible = false
	Sfx.play_ui("ui_start")
