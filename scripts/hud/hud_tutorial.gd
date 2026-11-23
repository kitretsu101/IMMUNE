class_name HudTutorial
extends Control
## Guided tour. Darkens everything except the part being explained and shows a dialog about it and its parameters.

@export var top_bar: Control
@export var left_panel: Control
@export var right_panel: Control
@export var organism_panel: Control
@export var action_bar: Control
@export var event_log: Control
@export var toolbar: Control
@export var board_gap: Control

var _steps: Array = []
var _index := 0
var _material := ShaderMaterial.new()
var _dim: ColorRect
var _card: PanelContainer
var _title: Label
var _body: RichTextLabel
var _counter: Label
var _next: Button
var _back: Button
var _target: Control
var _final := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Config.tutorial:
		visible = false
		return
	_steps = [
		["Welcome to IMMUNE", "You command blue **T cells**. Gold **human cells** sit in the middle of the board. Bacteria want to infect all of them. Eliminate every bacterium to win.\n\nThis short tour darkens everything except the part being explained.", null],
		["The board", "Each hexagon is a piece of tissue. **Dark teal** is healthy, **red** is infected, **orange** is damaged, **grey** is destroyed. Yellow specks are nutrients, purple haze is chemical signalling. The gold cells in the middle are the ones you protect.", "board"],
		["Your T cells", "Cyan cells are yours. The bar above shows **health**. A T cell can move up to its **move range**, attack an adjacent bacterium, or **clone** itself into a free neighbouring tile. Clones may evolve one trait by -1, 0 or +1.", "board"],
		["The bacteria", "Green rods are bacteria. They **move** toward food and the human cells, **infect** tissue, and **reproduce at the end of every round** if fed. Offspring can **mutate**: you will see a purple caption such as MUTATION: EVASION. Colours never change, so read the captions and the inspector.", "board"],
		["How bacteria mutate", "When a bacterium reproduces at the end of a round, its offspring may **mutate exactly one trait** by +1 or -1 (infectivity, reproduction, immune evasion or resistance), or very rarely shift its **antigen** and become a **new strain**. Mutations are inherited by all later offspring, so strong traits spread through natural selection.", "board"],
		["How to spot a mutant", "Colours never change. A mutated cell gets a **purple ring** and a **MUTANT** tag above its health bar, and a purple **MUTATION: TRAIT** caption flashes when it happens. Click it: the inspector lists its mutations and who it **inherited from**. The **Evolution** board view highlights every mutant colony.", "board"],
		["Infection", "A bacterium attempts to infect tissue next to it; chance depends on its **infectivity**, nearby T cells and nutrients. Success shows **INFECTED!**, the tile turns **red** and feeds the colony. Infection spreads, and tiles infected too long are **destroyed**. Standing a T cell on infected tissue **cleanses** it. If all seven gold cells turn red, bacteria win.", "board"],
		["Nutrients and hunger", "Yellow specks are **nutrients**. Bacteria eat them at round end and turn them into **energy** (yellow bar in the inspector). Reproducing costs 2.5 energy. With energy under 1 a bacterium shows **HUNGRY**; at zero it **starves** and loses health. Starved colonies stop growing, so cut them off from food and infected tiles.", "board"],
		["Biofilm, oxygen, antibiotics", "A bacterium can spend energy on **biofilm** (magenta tile): it shields the colony from damage but **slows its reproduction**. **Oxygen** speeds reproduction up. **Antibiotic** hurts bacteria each round unless they evolve **resistance**: watch for the resistance notification.", "right"],
		["Immune activation and memory", "T cells that spot bacteria become **ACTIVE** for a few rounds and hit harder. After eliminating an antigen a T cell forms **immune memory** against it, so new strains (new antigen) are harder to hit. Clones inherit memory.", "board"],
		["Top bar", "Shows the **round**, elapsed time, game mode, simulation status, whose turn it is and how many **actions** you have left this turn. The speed chip shows the simulation speed.", "top"],
		["Population panel", "**Living / dead** bacteria, **new offspring** this round, the **dominant strain**, and your own cells: total, active (boosted after spotting bacteria), dead and **eliminations**. The chart plots both populations round by round.", "left"],
		["Environment panel", "Percentage of **healthy, infected, damaged and destroyed** tissue, plus nutrients, oxygen and antibiotic concentration. **Board view** buttons re-colour the board: Infection, Nutrients, Chemical, Immune reach, Evolution (mutations).", "right"],
		["Selected organism", "Click any cell to inspect it. **Health**, **energy** (bacteria need it to reproduce), **infectivity** (infection chance), **reproduction** (chance to split), **immune evasion** (makes your attacks miss), **resistance** (to antibiotics), **generation**, mutations and the last AI decision.", "organism"],
		["Actions", "**Move/Attack [M]**: click a cyan tile to move, an orange one to strike. **Clone [C]**: click a green tile. **Wait [W]** skips a cell. **End turn [Space]** hands over to the bacteria. Each cell acts once per turn; you have limited actions.", "actions"],
		["What just happened?", "Floating captions appear on the board: **INFECTED!** (tissue lost to bacteria), **MUTATION**, **SPLIT** (reproduction), **-1.0** (damage), **MISS**, **CLEANSED** (you healed infected tissue by standing on it). The log lists every event and important ones pop up as notifications.", "log"],
		["Simulation controls", "**Pause, stop, step one round, restart, save, load**, choose speed 0.25x-16x, or switch on **Unlimited**. **Open log window** shows AI decisions, performance and evolution in a separate window (shortcut L).", "toolbar"],
		["Your turn", "Select a T cell, press **M**, and click a bright tile near the bacteria. Attack when an enemy turns orange. Clone when you have spare actions. Protect the gold cells. Good luck!", null],
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
	_card.custom_minimum_size = Vector2(470, 0)
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
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(430, 0)
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_font_size_override("bold_font_size", 15)
	_body.add_theme_color_override("default_color", Neon.TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
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
	_target = _resolve(step[2])
	_card.reset_size()
	UiKit.fade_in(_card, 0.0)


func _markdown(text: String) -> String:
	var out := ""
	var open := false
	var pieces := text.split("**")
	out = ""
	for index in pieces.size():
		if index % 2 == 1:
			out += "[b][color=#%s]%s[/color][/b]" % [Neon.CYAN.to_html(false), pieces[index]]
		else:
			out += pieces[index]
	return out


func _resolve(key: Variant) -> Control:
	match key:
		"board": return board_gap
		"top": return top_bar
		"left": return left_panel
		"right": return right_panel
		"organism": return organism_panel
		"actions": return action_bar
		"log": return event_log
		"toolbar": return toolbar
	return null


func _process(_delta: float) -> void:
	if not visible:
		return
	var viewport := get_viewport_rect().size
	_material.set_shader_parameter("viewport", viewport)
	var rect := Rect2(viewport * 0.5, Vector2.ZERO)
	var final_step := _final
	_dim.visible = not final_step
	if _target != null and is_instance_valid(_target):
		rect = _target.get_global_rect().grow(8)
	elif not final_step:
		rect = Rect2(viewport * 0.5 - Vector2(1, 1), Vector2(2, 2))
	_material.set_shader_parameter("spot", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_size := _card.size
	var x := (viewport.x - card_size.x) * 0.5
	var y := viewport.y - card_size.y - 70.0 if rect.get_center().y < viewport.y * 0.5 else 70.0
	if _target == board_gap and _target != null:
		y = viewport.y - card_size.y - 70.0
	if final_step:
		y = 74.0
	_card.position = _card.position.lerp(Vector2(x, y), 0.25)


func _finish() -> void:
	Config.tutorial = false
	visible = false
	Sfx.play_ui("ui_start")
