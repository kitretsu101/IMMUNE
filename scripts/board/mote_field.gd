class_name MoteField
extends MultiMeshInstance3D
## Floating specks above tiles: nutrients (yellow) or chemical signals (purple / cyan). Medium glow tier.

enum Source { NUTRIENTS, CHEM_BACTERIA, CHEM_IMMUNE }

@export var world: WorldHost
@export var tile_board: TileBoard
@export var source := Source.NUTRIENTS
@export_range(1, 8) var per_tile := 4
@export var color := Color(1.0, 0.9, 0.25)
@export_range(0.0, 3.0, 0.05) var energy := 1.1
@export_range(0.02, 0.3, 0.005) var mote_size := 0.075
@export_range(0.0, 0.5, 0.01) var drift := 0.14
@export_range(1.0, 30.0, 0.5) var refresh_hz := 8.0
@export_range(0.0, 2.0, 0.05) var view_boost := 1.0
@export var boosted_in_view: Events.View = Events.View.NUTRIENTS

var _material := ShaderMaterial.new()
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	var quad := QuadMesh.new()
	quad.size = Vector2(mote_size, mote_size)
	_material.shader = load("res://scenes/shaders/mote.gdshader")
	_material.set_shader_parameter("mote_color", color)
	_material.set_shader_parameter("energy", energy)
	_material.set_shader_parameter("drift", drift)
	quad.material = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = tile_board.columns * tile_board.rows * per_tile
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 30.0
	for tile in tile_board.columns * tile_board.rows:
		for slot in per_tile:
			var index := tile * per_tile + slot
			var offset := Vector3(_rng.randf_range(-0.65, 0.65), 0.0, _rng.randf_range(-0.55, 0.55))
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, tile_board.positions[tile] + offset))
			multimesh.set_instance_custom_data(index, Color(_rng.randf(), 0.0, _rng.randf_range(0.5, 1.4), _rng.randf()))
	Events.settings_changed.connect(_on_settings)
	_on_settings()


func _on_settings() -> void:
	_material.set_shader_parameter("glow_scale", Config.glow_level)
	visible = Config.particles


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0 / refresh_hz or world.state == null:
		return
	_clock = 0.0
	var state := world.state
	var boost := view_boost if Config.view_mode == boosted_in_view else 1.0
	_material.set_shader_parameter("energy", energy * (1.0 + (boost - 1.0) * 0.6))
	var lift := tile_board
	for tile in tile_board.columns * tile_board.rows:
		var amount := 0.0
		if state.active[tile] == 1:
			match source:
				Source.NUTRIENTS:
					amount = state.nutrients[tile] / 1.5
				Source.CHEM_BACTERIA:
					amount = state.chem_bact[tile] / 1.4
				Source.CHEM_IMMUNE:
					amount = state.chem_immune[tile] / 1.4
		amount = clampf(amount, 0.0, 1.0) * boost
		for slot in per_tile:
			var index := tile * per_tile + slot
			var data := multimesh.get_instance_custom_data(index)
			var wanted := clampf(amount * per_tile - slot, 0.0, 1.0)
			data.g = lerpf(data.g, wanted, 0.5)
			multimesh.set_instance_custom_data(index, data)
