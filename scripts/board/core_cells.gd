class_name CoreCells
extends Node3D
## The human cells in the middle of the board. They breathe while healthy and change colour as they are infected.

@export var world: WorldHost
@export var tile_board: TileBoard
@export var cell_scene: PackedScene
@export var rim_shader: Shader
@export var healthy_color := Color("#FFC24A")
@export var infected_color := Color("#FF2D4F")
@export var destroyed_color := Color("#3A3F4A")
@export_range(0.0, 0.2, 0.005) var breathe_amount := 0.06
@export var breathe_hz := 0.55
@export_range(0.0, 0.3, 0.005) var bob_height := 0.05

var _cells: Dictionary = {}
var _materials: Dictionary = {}
var _rims: Dictionary = {}
var _blend: Dictionary = {}


func _ready() -> void:
	world.world_rebuilt.connect(rebuild)


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	_materials.clear()
	_rims.clear()
	_blend.clear()
	for tile in world.state.core:
		var cell := cell_scene.instantiate() as Node3D
		add_child(cell)
		cell.position = tile_board.positions[tile]
		cell.scale = Vector3.ONE * 0.95
		_cells[tile] = cell
		_blend[tile] = 0.0
		var mats: Array[StandardMaterial3D] = []
		var rim := ShaderMaterial.new()
		rim.shader = rim_shader
		rim.set_shader_parameter("rim_energy", 1.1)
		rim.set_shader_parameter("phase", tile * 0.9)
		for mesh in cell.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			var material := (instance.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			instance.material_override = material
			instance.material_overlay = rim
			mats.append(material)
		_materials[tile] = mats
		_rims[tile] = rim


func _process(delta: float) -> void:
	if world.state == null:
		return
	var time := Time.get_ticks_msec() / 1000.0
	for tile in _cells:
		var cell: Node3D = _cells[tile]
		var kind := world.state.tissue[tile]
		var target := 0.0
		if kind == Sim.Tissue.INFECTED:
			target = 1.0
		elif kind == Sim.Tissue.DESTROYED:
			target = 2.0
		elif kind == Sim.Tissue.DAMAGED:
			target = 0.35
		_blend[tile] = move_toward(_blend[tile], target, delta * 1.5)
		var value: float = _blend[tile]
		var tint := healthy_color.lerp(infected_color, clampf(value, 0.0, 1.0))
		tint = tint.lerp(destroyed_color, clampf(value - 1.0, 0.0, 1.0))
		var pulse := 0.5 + 0.5 * sin(time * (0.9 + value * 2.6) + tile)
		var energy := lerpf(0.3, 0.7, pulse) * (1.0 - clampf(value - 1.0, 0.0, 1.0) * 0.8)
		for material: StandardMaterial3D in _materials[tile]:
			material.albedo_color = tint
			material.emission = tint
			material.emission_energy_multiplier = energy * Config.glow_level
		var rim: ShaderMaterial = _rims[tile]
		rim.set_shader_parameter("rim_color", Vector3(tint.r, tint.g, tint.b))
		rim.set_shader_parameter("glow_scale", Config.glow_level)
		rim.set_shader_parameter("pulse_speed", 1.2 + value * 3.0)
		if Config.animations:
			var s := 0.95 * (1.0 + sin(time * TAU * breathe_hz + tile) * breathe_amount)
			cell.scale = Vector3(s, 0.95 * (1.0 - (s / 0.95 - 1.0) * 0.5), s)
			cell.position.y = tile_board.positions[tile].y + tile_board.tile_lift(tile) + 0.04 + sin(time * 0.8 + tile) * bob_height * 0.5
