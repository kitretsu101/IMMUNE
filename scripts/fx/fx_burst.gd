class_name FxBurst
extends RefCounted
## One-shot particle bursts and expanding rings. Everything frees itself.

static var _spark_shader: Shader
static var _ring_shader: Shader
static var _quad: QuadMesh


static func _shader(path: String) -> Shader:
	return load(path) as Shader


static func burst(parent: Node, position: Vector3, color: Color, amount := 14, speed := 1.8,
		life := 0.6, size := 0.1, energy := 1.7, gravity := Vector3(0, -1.2, 0)) -> void:
	if not Config.particles or not Config.animations or not parent.is_inside_tree():
		return
	if _spark_shader == null:
		_spark_shader = _shader("res://scenes/shaders/spark.gdshader")
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var particles := CPUParticles3D.new()
	var material := ShaderMaterial.new()
	material.shader = _spark_shader
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("glow_scale", Config.glow_level)
	particles.mesh = _quad
	particles.material_override = material
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = gravity
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size * 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.15))
	particles.scale_amount_curve = shrink
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.global_position = position
	particles.finished.connect(particles.queue_free)


## An expanding flat ring (pings, spawn pulses, clone flashes).
static func ring(parent: Node, position: Vector3, color: Color, end_radius := 1.0, life := 0.6,
		energy := 1.4, start_radius := 0.15) -> void:
	if not Config.animations or not parent.is_inside_tree():
		return
	if _ring_shader == null:
		_ring_shader = _shader("res://scenes/shaders/ring.gdshader")
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _ring_shader
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("radius", 0.45)
	material.set_shader_parameter("thickness", 0.06)
	material.set_shader_parameter("pulse_amount", 0.0)
	material.set_shader_parameter("glow_scale", Config.glow_level)
	material.set_shader_parameter("alpha_scale", 1.0)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = position + Vector3.UP * 0.06
	mesh.scale = Vector3.ONE * start_radius
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * end_radius, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "shader_parameter/alpha_scale", 0.0, life)
	tween.chain().tween_callback(mesh.queue_free)


## Short rising caption above an event so players can read what just happened.
static func float_text(parent: Node, position: Vector3, text: String, color: Color, size := 46) -> void:
	if not Config.animations or not parent.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.008
	label.font_size = size
	label.outline_size = 14
	label.modulate = color
	label.outline_modulate = Color(0.01, 0.03, 0.1, 0.95)
	parent.add_child(label)
	label.global_position = position + Vector3.UP * 1.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y + 2.0, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.chain().tween_callback(label.queue_free)
