class_name AmbientDust
extends CPUParticles3D
## Slow plankton-like specks drifting over the board. Low glow, just enough to make the scene feel suspended in fluid.

@export var tint := Color(0.4, 0.8, 1.0, 0.5)
@export_range(0.0, 3.0, 0.05) var energy := 0.7
@export var board_half_extent := Vector3(11.0, 1.2, 9.0)


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/shaders/spark.gdshader")
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("glow_scale", Config.glow_level)
	material_override = material
	amount = 90
	lifetime = 14.0
	preprocess = 14.0
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = board_half_extent
	direction = Vector3(0.3, 0.2, 0.1)
	spread = 60.0
	initial_velocity_min = 0.05
	initial_velocity_max = 0.25
	gravity = Vector3.ZERO
	scale_amount_min = 0.03
	scale_amount_max = 0.09
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.add_point(0.25, tint)
	ramp.add_point(0.75, tint)
	ramp.set_color(ramp.get_point_count() - 1, Color(tint.r, tint.g, tint.b, 0.0))
	color_ramp = ramp
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Events.settings_changed.connect(_on_settings)
	_on_settings()


func _on_settings() -> void:
	visible = Config.particles
	(material_override as ShaderMaterial).set_shader_parameter("glow_scale", Config.glow_level)
