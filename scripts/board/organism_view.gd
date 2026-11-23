class_name OrganismView
extends Node3D
## Visual stand-in for one organism: model, glow overlay, team ring, health bar, trail and all one-shot animations.

signal arrived

@export var idle: OrganismIdle
@export var trail: TrailRibbon
@export_group("Motion")
@export var hop_height := 0.22
@export var step_time := 0.16
@export var squash_amount := 0.18

var org_id := 0
var team := Sim.BACTERIA
var body: Node3D
var base_ring: MeshInstance3D
var select_ring: MeshInstance3D
var health_bar: MeshInstance3D
var tag_label: Label3D
var color := Color.WHITE
var phase := 0.0

var _rim_materials: Array[ShaderMaterial] = []
var _swim_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _select_material: ShaderMaterial
var _bar_material: ShaderMaterial
var _boost := 0.0
var _hovered := false
var _selected := false
var _health_frac := 1.0
var _bar_opacity := 0.0
var _motion: Tween
var _fx_tween: Tween
var facing := 0.0


func build(organism: Organism, model_scene: PackedScene, rim_shader: Shader, ring_shader: Shader,
		bar_shader: Shader, swim_shader: Shader, model_scale: float, model_yaw: float) -> void:
	org_id = organism.id
	team = organism.team
	phase = randf() * TAU
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var model := model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = model_yaw
	body.add_child(model)
	color = Neon.team_color(team)
	for surface in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := surface as MeshInstance3D
		if team == Sim.BACTERIA:
			_swim_material = ShaderMaterial.new()
			_swim_material.shader = swim_shader
			_swim_material.set_shader_parameter("phase", phase)
			mesh_instance.material_override = _swim_material
			mesh_instance.custom_aabb = AABB(Vector3(-0.15, -0.02, -0.09), Vector3(0.33, 0.16, 0.18))
		else:
			var rim := ShaderMaterial.new()
			rim.shader = rim_shader
			rim.set_shader_parameter("phase", phase)
			mesh_instance.material_overlay = rim
			_rim_materials.append(rim)
	base_ring = _make_ring(ring_shader, 0.46, 0.05)
	_ring_material = base_ring.material_override
	select_ring = _make_ring(ring_shader, 0.54, 0.06)
	_select_material = select_ring.material_override
	select_ring.visible = false
	health_bar = _make_bar(bar_shader)
	_bar_material = health_bar.material_override
	tag_label = Label3D.new()
	tag_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag_label.no_depth_test = true
	tag_label.pixel_size = 0.006
	tag_label.font_size = 34
	tag_label.outline_size = 12
	tag_label.outline_modulate = Color(0.01, 0.03, 0.1, 0.95)
	tag_label.position = Vector3(0, 1.5, 0)
	add_child(tag_label)
	if idle == null:
		idle = OrganismIdle.new()
		idle.name = "Idle"
		add_child(idle)
	idle.target = body
	idle.set_base_yaw(0.0)
	if team == Sim.IMMUNE:
		idle.breathe_amount = 0.05
		idle.breathe_hz = 0.8
		idle.bob_height = 0.03
		idle.drift_radius = 0.03
		idle.sway_radians = 0.1
	else:
		idle.breathe_amount = 0.07
		idle.breathe_hz = 1.5
		idle.bob_height = 0.02
		idle.drift_radius = 0.1
		idle.drift_hz = 0.3
		idle.sway_radians = 0.28
		idle.sway_hz = 0.35
	if trail == null:
		trail = TrailRibbon.new()
		trail.name = "Trail"
		add_child(trail)
	trail.color = color
	refresh(organism)
	_apply_color()


func _make_ring(shader: Shader, radius: float, thickness: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("phase", phase)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position.y = 0.045
	add_child(mesh)
	return mesh


func _make_bar(shader: Shader) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 0.34)
	mesh.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = Vector3(0, 1.1, 0)
	mesh.extra_cull_margin = 4.0
	add_child(mesh)
	return mesh


func _apply_color() -> void:
	_ring_material.set_shader_parameter("ring_color", Vector3(color.r, color.g, color.b))
	_ring_material.set_shader_parameter("energy", 0.9)
	_ring_material.set_shader_parameter("alpha_scale", 0.85)
	_select_material.set_shader_parameter("ring_color", Vector3(1.0, 1.0, 1.0))
	_select_material.set_shader_parameter("energy", 1.5)
	for rim in _rim_materials:
		rim.set_shader_parameter("rim_color", Vector3(color.r, color.g, color.b))
	if _swim_material:
		_swim_material.set_shader_parameter("body_color", Vector3(color.r, color.g, color.b))
	Events.settings_changed.connect(_apply_glow)
	_apply_glow()


func _apply_glow() -> void:
	var level := Config.glow_level
	for rim in _rim_materials:
		rim.set_shader_parameter("glow_scale", level)
	if _swim_material:
		_swim_material.set_shader_parameter("glow_scale", level)
	_ring_material.set_shader_parameter("glow_scale", level)
	_select_material.set_shader_parameter("glow_scale", level)
	_bar_material.set_shader_parameter("glow_scale", level)


func refresh(organism: Organism) -> void:
	_health_frac = clampf(organism.health / organism.max_health, 0.0, 1.0)
	_bar_material.set_shader_parameter("fill", _health_frac)
	var bar_color := Neon.GREEN.lerp(Neon.RED, 1.0 - _health_frac) if _health_frac < 0.99 else Neon.GREEN
	_bar_material.set_shader_parameter("fill_color", Vector3(bar_color.r, bar_color.g, bar_color.b))
	var new_color := Neon.team_color(team)
	if new_color != color:
		color = new_color
		trail.color = color
		_apply_color_only()
	var tags: PackedStringArray = []
	var tag_color := Neon.TEXT
	if not organism.mutations.is_empty():
		tags.append("MUTANT")
		tag_color = Neon.PURPLE
	if organism.team == Sim.BACTERIA and organism.energy < 1.0:
		tags.append("HUNGRY")
		tag_color = Neon.YELLOW
	if organism.has_effect("BiofilmCost"):
		tags.append("BIOFILM")
	if organism.has_effect("Activated"):
		tags.append("ACTIVE")
	tag_label.text = " · ".join(tags)
	tag_label.modulate = tag_color
	var ring_tint := Neon.PURPLE if not organism.mutations.is_empty() else color
	_ring_material.set_shader_parameter("ring_color", Vector3(ring_tint.r, ring_tint.g, ring_tint.b))
	var activated := organism.has_effect("Activated")
	var target_boost := 0.3 if activated else 0.0
	_set_boost(target_boost + (0.35 if _selected else 0.0) + (0.2 if _hovered else 0.0))


func _apply_color_only() -> void:
	for rim in _rim_materials:
		rim.set_shader_parameter("rim_color", Vector3(color.r, color.g, color.b))
	if _swim_material:
		_swim_material.set_shader_parameter("body_color", Vector3(color.r, color.g, color.b))
	pass


func _set_boost(value: float) -> void:
	_boost = value
	for rim in _rim_materials:
		rim.set_shader_parameter("boost", value)
	if _swim_material:
		_swim_material.set_shader_parameter("boost", value)


func set_selected(on: bool) -> void:
	_selected = on
	select_ring.visible = on
	_set_boost(_boost + (0.3 if on else -0.3))


func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	_set_boost(maxf(0.0, _boost + (0.2 if on else -0.2)))
	if Config.animations:
		var tween := create_tween()
		tween.tween_property(body, "scale", Vector3.ONE * (1.1 if on else 1.0), 0.15).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	var want := 1.0
	_bar_opacity = move_toward(_bar_opacity, want, delta * 5.0)
	_bar_material.set_shader_parameter("opacity", _bar_opacity)
	health_bar.visible = _bar_opacity > 0.01
	if _selected and Config.animations:
		select_ring.rotation.y += delta * 0.8


## Smooth hop along the tile positions. Returns the animation length in seconds.
func glide(points: Array, speed_scale := 1.0) -> float:
	if points.is_empty():
		return 0.0
	if not Config.animations:
		position = points[-1]
		return 0.0
	if _motion and _motion.is_valid():
		_motion.kill()
	trail.emitting = true
	_motion = create_tween()
	_motion.set_speed_scale(maxf(0.1, speed_scale))
	# Anticipation squash.
	_motion.tween_property(body, "scale", Vector3(1.0 + squash_amount, 1.0 - squash_amount, 1.0 + squash_amount), 0.06)
	var total := 0.06
	var current := position
	for point in points:
		var destination: Vector3 = point
		var heading := destination - current
		if heading.length() > 0.01:
			facing = facing + angle_difference(facing, atan2(heading.z, -heading.x))
			_motion.tween_property(self, "rotation:y", facing, step_time * 0.7).set_trans(Tween.TRANS_SINE)
			_motion.parallel().tween_method(_hop.bind(current, destination), 0.0, 1.0, step_time).set_trans(Tween.TRANS_SINE)
			total += step_time
		current = destination
	_motion.tween_callback(_land)
	total += 0.12
	_motion.tween_property(body, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_callback(func() -> void: trail.emitting = false)
	return total / maxf(0.1, speed_scale)


func _hop(t: float, from_pos: Vector3, to_pos: Vector3) -> void:
	position = from_pos.lerp(to_pos, t)
	position.y += sin(t * PI) * hop_height


func _land() -> void:
	arrived.emit()


func place(world_position: Vector3) -> void:
	position = world_position


func face(yaw: float) -> void:
	facing = yaw
	rotation.y = yaw


func is_moving() -> bool:
	return _motion != null and _motion.is_valid() and _motion.is_running()


func lunge(toward: Vector3, speed_scale := 1.0) -> float:
	if not Config.animations:
		return 0.0
	var direction := (toward - position)
	direction.y = 0.0
	var offset := direction.normalized() * 0.45
	var tween := create_tween()
	tween.set_speed_scale(maxf(0.1, speed_scale))
	tween.tween_property(body, "position", offset + Vector3(0, 0.1, 0), 0.09).set_ease(Tween.EASE_IN)
	tween.tween_property(body, "position", Vector3.ZERO, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return 0.25 / maxf(0.1, speed_scale)


func flash(flash_color: Color, strength := 1.2) -> void:
	if not Config.animations:
		return
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.tween_method(_set_boost, strength, _boost if _boost < 0.9 else 0.3, 0.35)
	for rim in _rim_materials:
		rim.set_shader_parameter("rim_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	if _swim_material:
		_swim_material.set_shader_parameter("body_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	_fx_tween.tween_callback(_apply_color_only)


func shake(strength := 0.12) -> void:
	if not Config.animations:
		return
	var tween := create_tween()
	for i in 4:
		tween.tween_property(self, "position:x", position.x + (strength if i % 2 == 0 else -strength) * (1.0 - i * 0.2), 0.035)
	tween.tween_property(self, "position:x", position.x, 0.04)


func appear(from_position: Vector3, target_position: Vector3) -> float:
	position = from_position
	if not Config.animations:
		position = target_position
		return 0.0
	body.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return 0.45


func die() -> float:
	if not Config.animations:
		queue_free()
		return 0.0
	health_bar.visible = false
	set_process(false)
	idle.set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_boost, 1.5, 0.0, 0.4)
	tween.tween_property(body, "scale", Vector3(1.3, 0.05, 1.3), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
	return 0.4
