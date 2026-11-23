class_name NutrientOrbs
extends Node3D
## A handful of glowing nutrient pickups on the board. Each orb bobs, spins, pulses and sheds sparkles,
## pops in when food appears and bursts when it is eaten.

@export var world: WorldHost
@export var tile_board: TileBoard
@export var fx_root: Node3D
@export_range(0.1, 0.6, 0.01) var orb_radius := 0.27
@export_range(0.2, 3.0, 0.05) var orb_energy := 2.0
@export_range(1, 24) var max_orbs := 10
@export_range(0.3, 2.0, 0.05) var min_nutrient := 0.9
@export_range(0.0, 0.3, 0.005) var bob_height := 0.09
@export var spin_speed := 1.2

var _orbs: Dictionary = {}   # tile -> Node3D
var _clock := 0.0
var _sphere: SphereMesh
var _material: ShaderMaterial


func _ready() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = orb_radius
	_sphere.height = orb_radius * 2.0
	_sphere.radial_segments = 18
	_sphere.rings = 9
	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/shaders/orb.gdshader")
	_material.set_shader_parameter("energy", orb_energy)
	_sphere.material = _material
	Events.settings_changed.connect(func() -> void: _material.set_shader_parameter("glow_scale", Config.glow_level))
	_material.set_shader_parameter("glow_scale", Config.glow_level)
	world.world_rebuilt.connect(_clear)


func _clear() -> void:
	for orb in _orbs.values():
		orb.queue_free()
	_orbs.clear()


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for tile in _orbs:
		var orb: Node3D = _orbs[tile]
		var base: Vector3 = tile_board.positions[tile]
		var wave := sin(time * 1.8 + tile)
		orb.position = base + Vector3(0, 0.55 + wave * bob_height + tile_board.tile_lift(tile), 0)
		orb.rotation.y += delta * spin_speed
		if Config.animations:
			var pulse := 1.0 + 0.08 * sin(time * 3.1 + tile * 0.7)
			var body := orb.get_node("Body") as Node3D
			if body.scale.x > 0.95:
				body.scale = Vector3.ONE * pulse
			for child in body.get_children():
				if child.has_meta("orbit"):
					var angle := time * 2.4 + float(child.get_meta("orbit")) * PI
					child.position = Vector3(cos(angle), sin(angle * 0.7) * 0.4, sin(angle)) * orb_radius * 1.7
	_clock += delta
	if _clock < 0.25 or world.state == null:
		return
	_clock = 0.0
	_sync()


func _sync() -> void:
	var state := world.state
	var ranked: Array = []
	for tile in state.count:
		if state.active[tile] == 1 and state.nutrients[tile] >= min_nutrient:
			ranked.append([state.nutrients[tile], tile])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var wanted := {}
	for index in mini(max_orbs, ranked.size()):
		wanted[ranked[index][1]] = true
	for tile in _orbs.keys():
		if not wanted.has(tile):
			_remove(tile)
	for tile in wanted:
		if not _orbs.has(tile):
			_spawn(tile)


func _spawn(tile: int) -> void:
	var orb := Node3D.new()
	orb.position = tile_board.positions[tile] + Vector3.UP * 0.55
	var body := Node3D.new()
	body.name = "Body"
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	# Two small satellites orbiting the orb.
	for index in 2:
		var moon := MeshInstance3D.new()
		var small := SphereMesh.new()
		small.radius = orb_radius * 0.22
		small.height = orb_radius * 0.44
		small.radial_segments = 8
		small.rings = 4
		small.material = _material
		moon.mesh = small
		moon.position = Vector3(orb_radius * 1.7, 0.0, 0.0).rotated(Vector3.UP, index * PI)
		moon.set_meta("orbit", index)
		body.add_child(moon)
	orb.add_child(body)
	orb.add_child(_sparkles())
	add_child(orb)
	_orbs[tile] = orb
	if Config.animations:
		body.scale = Vector3.ONE * 0.1
		var tween := body.create_tween()
		tween.tween_property(body, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		FxBurst.ring(fx_root if fx_root else self, tile_board.positions[tile], Neon.YELLOW, 1.0, 0.7)


func _sparkles() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/shaders/spark.gdshader")
	material.set_shader_parameter("energy", 1.6)
	material.set_shader_parameter("glow_scale", Config.glow_level)
	particles.material_override = material
	particles.amount = 14
	particles.lifetime = 1.6
	particles.preprocess = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = orb_radius * 1.1
	particles.direction = Vector3.UP
	particles.spread = 40.0
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.45
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	ramp.set_color(1, Color(1.0, 0.8, 0.2, 0.0))
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visible = Config.particles
	return particles


func _remove(tile: int) -> void:
	var orb: Node3D = _orbs[tile]
	_orbs.erase(tile)
	FxBurst.burst(fx_root if fx_root else self, orb.global_position, Neon.YELLOW, 16, 1.6, 0.7, 0.1)
	if not Config.animations:
		orb.queue_free()
		return
	var tween := orb.create_tween()
	tween.tween_property(orb.get_node("Body"), "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(orb.queue_free)
