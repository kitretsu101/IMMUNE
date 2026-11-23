class_name OrganismLayer
extends Node3D
## Keeps one OrganismView per living organism and turns simulation events into motion and particles.

@export var world: WorldHost
@export var tile_board: TileBoard
@export var gate: AnimationGate
@export var fx_root: Node3D
@export_group("Models")
@export var t_cell_model: PackedScene
@export var bacteria_model: PackedScene
@export_group("Shaders")
@export var rim_shader: Shader
@export var ring_shader: Shader
@export var bar_shader: Shader
@export var swim_shader: Shader
@export_group("Placement")
@export var immune_scale := 1.0
@export var bacteria_scale := 5.6
@export_range(-3.2, 3.2, 0.01) var immune_yaw := 2.45
@export_range(-3.2, 3.2, 0.01) var bacteria_yaw := -0.68

var views: Dictionary = {}
var selected_id := 0
var hovered_id := 0


func _ready() -> void:
	world.world_rebuilt.connect(rebuild)
	Events.sim_event.connect(_on_event)
	Events.state_changed.connect(_refresh)
	Events.organism_selected.connect(_on_selected)
	Events.organism_hovered.connect(_on_hovered)


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	views.clear()
	selected_id = 0
	hovered_id = 0
	for organism in world.state.organisms.values():
		_make_view(organism, tile_board.positions[organism.tile])


func _make_view(organism: Organism, at: Vector3) -> OrganismView:
	var view := OrganismView.new()
	view.name = "%s_%d" % ["TCell" if organism.team == Sim.IMMUNE else "Bacterium", organism.id]
	add_child(view)
	var scene := t_cell_model if organism.team == Sim.IMMUNE else bacteria_model
	var scale_value := immune_scale if organism.team == Sim.IMMUNE else bacteria_scale
	view.build(organism, scene, rim_shader, ring_shader, bar_shader, swim_shader, scale_value, 0.0)
	view.place(at)
	view.face(immune_yaw if organism.team == Sim.IMMUNE else bacteria_yaw)
	views[organism.id] = view
	return view


func _refresh() -> void:
	if world.state == null:
		return
	for id in views.keys():
		var organism := world.state.get_org(id)
		if organism == null:
			continue
		views[id].refresh(organism)


func _on_selected(id: int) -> void:
	if views.has(selected_id):
		views[selected_id].set_selected(false)
	selected_id = id
	if views.has(id):
		views[id].set_selected(true)


func _on_hovered(id: int) -> void:
	if hovered_id != id and views.has(hovered_id):
		views[hovered_id].set_hovered(false)
	hovered_id = id
	if views.has(id):
		views[id].set_hovered(true)


func _process(_delta: float) -> void:
	if world.state == null:
		return
	for id in views:
		var view: OrganismView = views[id]
		var organism := world.state.get_org(id)
		if organism == null or view.is_moving():
			continue
		var target := tile_board.positions[organism.tile]
		target.y += tile_board.tile_lift(organism.tile)
		if view.position.distance_to(target) > 0.02 and not view.is_moving():
			view.position = view.position.lerp(target, 0.35)
		else:
			view.position.y = target.y


func _tile_pos(tile: int) -> Vector3:
	return tile_board.positions[tile] + Vector3.UP * 0.2


func _caption(event: Dictionary) -> void:
	var tile: int = event.tile2 if event.tile2 >= 0 else event.tile
	if tile < 0:
		return
	var at := tile_board.positions[tile]
	match event.type:
		"pickup", "eat": FxBurst.float_text(fx_root, at, "+NUTRIENTS" if event.team == Sim.BACTERIA else "+HEAL", Neon.YELLOW if event.team == Sim.BACTERIA else Neon.GREEN, 36)
		"infect_ok": FxBurst.float_text(fx_root, at, "INFECTED!", Neon.RED)
		"infect_fail": FxBurst.float_text(fx_root, at, "resisted", Neon.TEXT_MUTED, 34)
		"mutation": FxBurst.float_text(fx_root, tile_board.positions[event.tile], "MUTATION: %s" % str(event.get("trait", "")).to_upper(), Neon.PURPLE)
		"new_strain": FxBurst.float_text(fx_root, tile_board.positions[event.tile], "NEW STRAIN", Neon.PURPLE)
		"reproduce": FxBurst.float_text(fx_root, at, "SPLIT", Neon.GREEN, 38)
		"clone": FxBurst.float_text(fx_root, at, "CLONE", Neon.CYAN, 38)
		"attack_hit": FxBurst.float_text(fx_root, at, "-%.1f" % float(event.get("damage", 1.0)), Neon.ORANGE, 42)
		"attack_miss": FxBurst.float_text(fx_root, at, "MISS", Neon.TEXT_MUTED, 34)
		"death": FxBurst.float_text(fx_root, at, "ELIMINATED", Neon.MAGENTA, 38)
		"tissue_cleansed": FxBurst.float_text(fx_root, at, "CLEANSED", Neon.CYAN, 38)
		"biofilm": FxBurst.float_text(fx_root, at, "BIOFILM", Neon.BIOFILM, 38)
		"tissue_destroyed": FxBurst.float_text(fx_root, at, "TISSUE LOST", Neon.GREY, 38)


func _on_event(event: Dictionary) -> void:
	_caption(event)
	var speed := maxf(0.25, Config.speed)
	match event.type:
		"move":
			var view: OrganismView = views.get(event.org)
			if view == null:
				return
			var points: Array = []
			for tile in event.path:
				points.append(tile_board.positions[tile])
			gate.hold(view.glide(points, speed))
		"attack_hit", "attack_miss":
			var attacker: OrganismView = views.get(event.org)
			var target: OrganismView = views.get(event.other)
			if attacker == null or target == null:
				return
			var tint := Neon.team_color(event.team) if event.team == Sim.IMMUNE else attacker.color
			gate.hold(attacker.lunge(target.position, speed) + 0.15)
			var hit: bool = event.type == "attack_hit"
			get_tree().create_timer(0.09 / speed).timeout.connect(func() -> void:
				if is_instance_valid(target):
					if hit:
						target.shake()
						target.flash(Color.WHITE, 1.4)
						FxBurst.burst(fx_root, target.position + Vector3.UP * 0.3, tint, 12, 2.0, 0.45, 0.09)
					else:
						FxBurst.burst(fx_root, target.position + Vector3.UP * 0.3, Neon.TEXT_MUTED, 4, 0.8, 0.3, 0.06))
		"death":
			var view: OrganismView = views.get(event.org)
			if view != null:
				views.erase(event.org)
				FxBurst.burst(fx_root, view.position + Vector3.UP * 0.2, view.color, 22, 2.4, 0.7, 0.1)
				FxBurst.ring(fx_root, view.position, view.color, 1.1, 0.5)
				gate.hold(view.die() + 0.1)
		"clone", "reproduce":
			var organism := world.state.get_org(event.other)
			if organism == null or views.has(organism.id):
				return
			var origin := tile_board.positions[event.tile]
			var view := _make_view(organism, origin)
			view.face(views[event.org].facing if views.has(event.org) else 0.0)
			gate.hold(view.appear(origin, tile_board.positions[event.tile2]))
			var tint := view.color
			FxBurst.ring(fx_root, tile_board.positions[event.tile2], tint, 1.0, 0.55)
			FxBurst.burst(fx_root, tile_board.positions[event.tile2] + Vector3.UP * 0.2, tint, 14, 1.6, 0.5, 0.09)
		"infect_ok":
			FxBurst.burst(fx_root, tile_board.positions[event.tile2] + Vector3.UP * 0.15, Neon.TISSUE_INFECTED, 20, 1.8, 0.8, 0.1)
			FxBurst.ring(fx_root, tile_board.positions[event.tile2], Neon.TISSUE_INFECTED, 1.2, 0.7)
			gate.hold(0.2)
		"infect_try":
			if views.has(event.org):
				views[event.org].flash(Neon.TISSUE_INFECTED, 0.9)
		"infect_fail":
			FxBurst.burst(fx_root, tile_board.positions[event.tile2] + Vector3.UP * 0.15, Neon.TEXT_MUTED, 6, 0.8, 0.4, 0.06)
		"biofilm":
			FxBurst.ring(fx_root, tile_board.positions[event.tile], Neon.BIOFILM, 1.2, 0.8)
			FxBurst.burst(fx_root, tile_board.positions[event.tile] + Vector3.UP * 0.2, Neon.BIOFILM, 14, 1.0, 0.8, 0.09)
			gate.hold(0.2)
		"rest":
			if views.has(event.org):
				views[event.org].flash(Neon.GREEN, 0.7)
		"mutation", "new_strain":
			var view: OrganismView = views.get(event.org)
			var at := tile_board.positions[event.tile]
			FxBurst.burst(fx_root, at + Vector3.UP * 0.3, Neon.PURPLE, 18, 1.8, 0.9, 0.1)
			FxBurst.ring(fx_root, at, Neon.PURPLE, 1.3, 0.8)
			if view != null:
				view.flash(Neon.PURPLE, 1.6)
		"antibiotic_hit":
			if views.has(event.org):
				views[event.org].flash(Neon.YELLOW, 1.2)
				FxBurst.burst(fx_root, views[event.org].position + Vector3.UP * 0.2, Neon.YELLOW, 8, 1.2, 0.5, 0.07)
		"memory":
			if views.has(event.org):
				var gold := Color(1.0, 0.82, 0.45)
				views[event.org].flash(gold, 1.8)
				FxBurst.ring(fx_root, views[event.org].position, gold, 2.2, 1.0, 1.8)
				FxBurst.burst(fx_root, views[event.org].position + Vector3.UP * 0.4, gold, 26, 2.0, 1.0, 0.1)
				FxBurst.float_text(fx_root, views[event.org].position, "MEMORY: ANTIGEN %s" % Sim.ANTIGENS[int(event.get("antigen", 0))], gold, 42)
		"antigen_detected":
			if views.has(event.org):
				FxBurst.ring(fx_root, views[event.org].position, Neon.CYAN, 1.8, 0.8, 1.2)
		"pickup", "eat":
			FxBurst.burst(fx_root, tile_board.positions[event.tile] + Vector3.UP * 0.3, Neon.YELLOW, 10, 1.2, 0.6, 0.08)
		"tissue_cleansed":
			FxBurst.burst(fx_root, tile_board.positions[event.tile] + Vector3.UP * 0.2, Neon.CYAN, 14, 1.4, 0.7, 0.08)
		"tissue_destroyed":
			FxBurst.burst(fx_root, tile_board.positions[event.tile] + Vector3.UP * 0.1, Neon.GREY, 20, 1.6, 0.9, 0.1)
		"tissue_spread":
			FxBurst.burst(fx_root, tile_board.positions[event.tile2] + Vector3.UP * 0.1, Neon.TISSUE_INFECTED, 8, 1.0, 0.6, 0.07)
