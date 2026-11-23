class_name HumanController
extends Node
## Turns mouse and keyboard input into legal actions for whichever side a person controls.

signal mode_changed(mode: int)
signal options_changed

enum ActionMode { MOVE, INFECT, CLONE }

@export var world: WorldHost
@export var tile_board: TileBoard
@export var painter: TilePainter
@export var rounds: RoundManager
@export var clock: SimClock

var selected_id := 0
var action_mode := ActionMode.MOVE
var targets: Dictionary = {}

const KEYS := {KEY_M: "move", KEY_A: "move", KEY_C: "clone", KEY_I: "infect", KEY_B: "biofilm",
		KEY_E: "rest", KEY_W: "wait", KEY_SPACE: "end", KEY_ENTER: "end", KEY_TAB: "next", KEY_ESCAPE: "deselect"}


func _ready() -> void:
	tile_board.tile_clicked.connect(_on_tile_clicked)
	tile_board.hover_changed.connect(_on_hover)
	rounds.human_turn_started.connect(func(_side: int) -> void: _auto_select())
	rounds.human_turn_ended.connect(func() -> void: _refresh())
	rounds.actions_changed.connect(func(_l: int, _t: int) -> void: _refresh())
	world.world_rebuilt.connect(func() -> void: select(0))
	Events.state_changed.connect(_refresh)


func can_control() -> bool:
	return rounds.awaiting_human and not rounds.busy and world.state != null and not world.state.finished


func selected() -> Organism:
	return world.state.get_org(selected_id) if world.state else null


func select(id: int) -> void:
	selected_id = id
	Events.organism_selected.emit(id)
	if id > 0 and Config.pause_on_selection and clock.status == SimClock.Status.RUNNING:
		clock.set_paused(true)
	_refresh()


func set_mode(mode: int) -> void:
	action_mode = mode
	mode_changed.emit(mode)
	Sfx.play_ui("ui_click")
	_refresh()


func _auto_select() -> void:
	var current := selected()
	if current == null or current.team != world.state.side or current.acted:
		for organism in world.state.living(world.state.side):
			if not organism.acted:
				select(organism.id)
				return
		select(0)
	else:
		_refresh()


func _on_hover(tile: int) -> void:
	var id := 0
	if world.state and tile >= 0:
		id = world.state.occupant[tile]
	Events.organism_hovered.emit(id)


func _on_tile_clicked(tile: int) -> void:
	if world.state == null:
		return
	var occupant := world.state.occupant[tile]
	if can_control() and targets.has(tile):
		rounds.submit_human_action(targets[tile])
		return
	if occupant > 0:
		select(occupant)
		Sfx.play_ui("ui_click")
	elif can_control():
		Sfx.play_ui("ui_error")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if world.state and world.state.setup.mode == Sim.Mode.SANDBOX and _sandbox_key(key.keycode):
		return
	if not KEYS.has(key.keycode):
		return
	match KEYS[key.keycode]:
		"move": set_mode(ActionMode.MOVE)
		"clone": set_mode(ActionMode.CLONE)
		"infect": set_mode(ActionMode.INFECT)
		"biofilm": immediate(Sim.Kind.BIOFILM)
		"rest": immediate(Sim.Kind.REPRODUCE)
		"wait": immediate(Sim.Kind.WAIT)
		"end": rounds.end_human_turn()
		"next": cycle()
		"deselect": select(0)


func cycle() -> void:
	if world.state == null:
		return
	var list := world.state.living(world.state.side)
	if list.is_empty():
		return
	var index := -1
	for i in list.size():
		if list[i].id == selected_id:
			index = i
	select(list[(index + 1) % list.size()].id)


func immediate(kind: int) -> void:
	if not can_control():
		return
	var organism := selected()
	if organism == null or organism.team != world.state.side:
		return
	for action in LogicRules.legal_actions(world.state, organism):
		if action.kind == kind:
			rounds.submit_human_action(action)
			return
	Sfx.play_ui("ui_error")


## Which action kinds the current selection can perform; used by the action bar.
func available_kinds() -> Dictionary:
	var kinds := {}
	var organism := selected()
	if organism == null or not can_control() or organism.team != world.state.side:
		return kinds
	for action in LogicRules.legal_actions(world.state, organism):
		kinds[action.kind] = true
	return kinds


func _refresh() -> void:
	targets.clear()
	var hints := {}
	var organism := selected()
	if organism != null:
		painter.set_selected_tile(organism.tile)
	else:
		painter.set_selected_tile(-1)
	if can_control() and organism != null and organism.team == world.state.side and not organism.acted:
		for action in LogicRules.legal_actions(world.state, organism):
			match action.kind:
				Sim.Kind.MOVE:
					if action_mode == ActionMode.MOVE:
						targets[action.to] = action
						hints[action.to] = {"amount": 0.65, "color": Neon.CYAN}
				Sim.Kind.ATTACK:
					if action_mode == ActionMode.MOVE:
						targets[action.target_tile] = action
						hints[action.target_tile] = {"amount": 1.0, "color": Neon.ORANGE}
				Sim.Kind.INFECT:
					if action_mode == ActionMode.INFECT:
						targets[action.target_tile] = action
						hints[action.target_tile] = {"amount": 0.8, "color": Neon.RED}
				Sim.Kind.CLONE:
					if action_mode == ActionMode.CLONE:
						targets[action.to] = action
						hints[action.to] = {"amount": 0.8, "color": Neon.GREEN}
	painter.set_hints(hints)
	options_changed.emit()


## Sandbox helpers on the hovered tile: 1 bacterium, 2 T cell, Delete remove, 3 infect / heal, 4 biofilm, 5 nutrients.
func _sandbox_key(keycode: int) -> bool:
	var tile := tile_board.hovered_tile
	var state := world.state
	if tile < 0 or state.active[tile] == 0:
		return false
	match keycode:
		KEY_1, KEY_2:
			if state.occupant[tile] != 0:
				return true
			var team := Sim.BACTERIA if keycode == KEY_1 else Sim.IMMUNE
			var organism := WorldBuilder.new_bacterium(state, state.setup, state.rng.randi() % 4) if team == Sim.BACTERIA else WorldBuilder.new_immune(state, state.setup)
			organism.algorithm = "Human"
			state.add_organism(organism, tile)
			Events.sim_event.emit(Ev.make("sandbox_spawn", "System", "Spawned %s at %s." % [organism.label(), Ev.at(tile)], state.round, {"org": organism.id, "tile": tile, "tile2": tile, "team": team, "other": organism.id}))
			world.world_rebuilt.emit()
			world.touch()
			return true
		KEY_DELETE, KEY_BACKSPACE:
			var occupant := state.org_at(tile)
			if occupant != null:
				state.remove_organism(occupant)
				Events.sim_event.emit(Ev.make("death", "Death", "%s removed." % occupant.label(), state.round, {"org": occupant.id, "tile": tile, "team": occupant.team, "victim_team": occupant.team}))
				world.touch()
			return true
		KEY_3:
			var infected := state.tissue[tile] == Sim.Tissue.INFECTED
			state.tissue[tile] = Sim.Tissue.HEALTHY if infected else Sim.Tissue.INFECTED
			state.tissue_strain[tile] = "A-1"
			world.touch()
			return true
		KEY_4:
			state.biofilm[tile] = (state.biofilm[tile] + 1) % (Balance.MAX_BIOFILM + 1)
			world.touch()
			return true
		KEY_5:
			state.nutrients[tile] = minf(Balance.NUTRIENT_CAP, state.nutrients[tile] + 0.8)
			world.touch()
			return true
	return false
