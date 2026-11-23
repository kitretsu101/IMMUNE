class_name TrailRibbon
extends MeshInstance3D
## A fading light trail that follows its parent while `emitting` is true.

@export var color := Color(0.3, 0.9, 1.0)
@export var width := 0.16
@export_range(0.05, 2.0, 0.01) var lifetime := 0.5
@export var height := 0.14
@export var energy := 1.5
@export_range(0.01, 0.5, 0.01) var spacing := 0.05

var emitting := false
var _points: Array = []   # [Vector3, age]
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/shaders/trail.gdshader")
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("glow_scale", Config.glow_level)
	material_override = material
	extra_cull_margin = 40.0


func clear() -> void:
	_points.clear()
	_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if not Config.animations or not Config.particles:
		if not _points.is_empty():
			clear()
		return
	for point in _points:
		point[1] += delta
	while not _points.is_empty() and _points[0][1] > lifetime:
		_points.pop_front()
	if emitting:
		var here: Vector3 = (get_parent() as Node3D).global_position + Vector3.UP * height
		if _points.is_empty() or here.distance_to(_points[-1][0]) > spacing:
			_points.append([here, 0.0])
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in _points.size():
		var here: Vector3 = _points[index][0]
		var ahead: Vector3 = _points[mini(index + 1, _points.size() - 1)][0]
		var behind: Vector3 = _points[maxi(index - 1, 0)][0]
		var direction := (ahead - behind).normalized()
		var side := direction.cross(Vector3.UP).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		var fade := clampf(1.0 - _points[index][1] / lifetime, 0.0, 1.0)
		var taper := fade * width * 0.5
		var tint := Color(color.r, color.g, color.b, fade * fade)
		_mesh.surface_set_color(tint)
		_mesh.surface_add_vertex(here + side * taper)
		_mesh.surface_set_color(tint)
		_mesh.surface_add_vertex(here - side * taper)
	_mesh.surface_end()
