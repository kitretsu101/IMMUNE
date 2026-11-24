extends Node
## Rebuilds res://scenes/game/game.tscn from code. Run: godot --headless res://tools/build_game_scene.tscn
## The scene is plain nodes; each node carries its own script and editor-exposed options.

var scene_root: Node3D


func _ready() -> void:
	scene_root = Node3D.new()
	scene_root.name = "Game"
	var env_node := _node(WorldEnvironment, "WorldEnvironment", scene_root, "res://scripts/fx/environment_fx.gd")
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.3, -0.8, -0.5), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(0.7, 0.85, 1.0)
	sun.light_energy = 0.9
	_add(scene_root, sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.006, 0.01, 0.03)
	plane.material = floor_material
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, -1.01, 0)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(scene_root, floor_mesh)

	var camera := _node(Camera3D, "Camera3D", scene_root, "res://scripts/board/camera_controller.gd")
	camera.transform = Transform3D(Basis.looking_at(Vector3(-7, -24, -18), Vector3.UP), Vector3(7, 24, 18))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.size = 30.5
	camera.far = 200.0

	var board := _node(Node3D, "Board", scene_root, "res://scripts/board/tile_board.gd")
	board.tile_scene = load("res://scenes/hex_tile.tscn")
	board.camera = camera
	camera.tile_board = board

	var simulation := Node.new()
	simulation.name = "Simulation"
	_add(scene_root, simulation)
	var world := _node(Node, "World", simulation, "res://scripts/flow/world_host.gd")
	world.tile_board = board
	var gate := _node(Node, "AnimationGate", simulation, "res://scripts/board/animation_gate.gd")
	var clock := _node(Node, "Clock", simulation, "res://scripts/flow/sim_clock.gd")
	clock.world = world
	var immune_ai := _node(Node, "ImmuneAI", simulation, "res://scripts/flow/ai_agent.gd")
	immune_ai.team = Sim.IMMUNE
	var bacteria_ai := _node(Node, "BacteriaAI", simulation, "res://scripts/flow/ai_agent.gd")
	bacteria_ai.team = Sim.BACTERIA
	var rounds := _node(Node, "Rounds", simulation, "res://scripts/flow/round_manager.gd")
	rounds.world = world
	rounds.clock = clock
	rounds.gate = gate
	rounds.immune_ai = immune_ai
	rounds.bacteria_ai = bacteria_ai
	var persistence := _node(Node, "Persistence", simulation, "res://scripts/flow/save_persistence.gd")
	persistence.world = world
	persistence.rounds = rounds

	var painter := _node(Node, "TilePainter", scene_root, "res://scripts/board/tile_painter.gd")
	painter.world = world
	painter.tile_board = board

	var human := _node(Node, "Human", simulation, "res://scripts/flow/human_controller.gd")
	human.world = world
	human.tile_board = board
	human.painter = painter
	human.rounds = rounds
	human.clock = clock
	var starter := _node(Node, "MatchStarter", simulation, "res://scripts/flow/match_starter.gd")
	starter.rounds = rounds
	starter.persistence = persistence
	starter.human = human

	var fx_holder := Node3D.new()
	fx_holder.name = "Fx"
	_add(scene_root, fx_holder)
	var orbs := _node(Node3D, "NutrientOrbs", scene_root, "res://scripts/board/nutrient_orbs.gd")
	orbs.world = world
	orbs.tile_board = board
	orbs.fx_root = fx_holder
	var dust := _node(CPUParticles3D, "AmbientDust", scene_root, "res://scripts/fx/ambient_dust.gd")

	var core := _node(Node3D, "CoreCells", scene_root, "res://scripts/board/core_cells.gd")
	core.world = world
	core.tile_board = board
	core.cell_scene = load("res://scenes/human_cell_hex.tscn")
	core.rim_shader = load("res://scenes/shaders/organism_rim.gdshader")

	var fx := fx_holder
	var organisms := _node(Node3D, "Organisms", scene_root, "res://scripts/board/organism_layer.gd")
	organisms.world = world
	organisms.tile_board = board
	organisms.gate = gate
	organisms.fx_root = fx
	organisms.t_cell_model = load("res://assets/t_cell/t_cell.gltf")
	organisms.bacteria_model = load("res://assets/bacteria/bacterium_game.gltf")
	organisms.rim_shader = load("res://scenes/shaders/organism_rim.gdshader")
	organisms.ring_shader = load("res://scenes/shaders/ring.gdshader")
	organisms.bar_shader = load("res://scenes/shaders/health_bar.gdshader")
	organisms.swim_shader = load("res://scenes/bacterium_swim.gdshader")

	var bridge := _node(Node, "AudioBridge", scene_root, "res://scripts/fx/spatial_audio_bridge.gd")
	bridge.tile_board = board
	bridge.camera = camera
	_node(CanvasLayer, "Vignette", scene_root, "res://scripts/fx/screen_vignette.gd")

	_build_hud(world, rounds, clock, human, persistence, camera)
	var log_window := _node(Window, "LogWindow", scene_root, "res://scripts/log/log_window.gd")

	var packed := PackedScene.new()
	var result := packed.pack(scene_root)
	if result != OK:
		push_error("pack failed: %d" % result)
		get_tree().quit(1)
		return
	ResourceSaver.save(packed, "res://scenes/game/game.tscn")
	print("Saved res://scenes/game/game.tscn")
	get_tree().quit()


func _build_hud(world: Node, rounds: Node, clock: Node, human: Node, persistence: Node, camera: Node) -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 10
	_add(scene_root, hud)
	var layout := _node(Control, "Root", hud, "res://scripts/hud/hud_layout.gd")
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.camera = camera
	var frame := MarginContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 10)
	_add(layout, frame)
	var column := VBoxContainer.new()
	column.name = "Layout"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_add(frame, column)
	var top := _node(PanelContainer, "TopBar", column, "res://scripts/hud/hud_top_bar.gd")
	top.world = world
	top.rounds = rounds
	top.clock = clock
	var middle := HBoxContainer.new()
	middle.name = "Middle"
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(column, middle)
	var left := _node(PanelContainer, "Population", middle, "res://scripts/hud/hud_population_panel.gd")
	left.world = world
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var gap := Control.new()
	gap.name = "BoardGap"
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(middle, gap)
	var right := _node(PanelContainer, "Environment", middle, "res://scripts/hud/hud_environment_panel.gd")
	right.world = world
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var dock := VBoxContainer.new()
	dock.name = "Dock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 8)
	_add(column, dock)
	var row := HBoxContainer.new()
	row.name = "InfoRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	_add(dock, row)
	var log := _node(PanelContainer, "EventLog", row, "res://scripts/hud/hud_event_log.gd")
	log.size_flags_vertical = Control.SIZE_SHRINK_END
	var organism_panel := _node(PanelContainer, "SelectedOrganism", row, "res://scripts/hud/hud_organism_panel.gd")
	organism_panel.world = world
	organism_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	organism_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var actions := _node(PanelContainer, "Actions", layout, "res://scripts/hud/hud_action_bar.gd")
	actions.world = world
	actions.rounds = rounds
	actions.human = human
	var toolbar := _node(PanelContainer, "Toolbar", dock, "res://scripts/hud/hud_toolbar.gd")
	toolbar.world = world
	toolbar.rounds = rounds
	toolbar.clock = clock
	toolbar.camera = camera
	toolbar.persistence = persistence
	layout.top_bar = top
	layout.left_panel = left
	layout.right_panel = right
	layout.bottom_dock = dock
	layout.action_panel = actions
	var tutorial := _node(Control, "Tutorial", layout, "res://scripts/hud/hud_tutorial.gd")
	tutorial.top_bar = top
	tutorial.left_panel = left
	tutorial.right_panel = right
	tutorial.organism_panel = organism_panel
	tutorial.action_bar = actions
	tutorial.event_log = log
	tutorial.toolbar = toolbar
	tutorial.world = world
	tutorial.camera = camera
	var banner := _node(Control, "Banner", layout, "res://scripts/hud/hud_banner.gd")
	banner.rounds = rounds
	var toasts := _node(VBoxContainer, "Toasts", layout, "res://scripts/hud/hud_toasts.gd")
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-170, 230)
	toasts.size = Vector2(340, 10)
	var result := _node(Control, "Result", layout, "res://scripts/hud/hud_result_overlay.gd")
	result.world = world
	result.rounds = rounds


func _node(type: Variant, node_name: String, parent: Node, script_path: String = "") -> Node:
	var node: Node = type.new()
	node.name = node_name
	if script_path != "":
		node.set_script(load(script_path))
	_add(parent, node)
	return node


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root
