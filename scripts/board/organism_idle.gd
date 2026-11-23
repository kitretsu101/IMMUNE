class_name OrganismIdle
extends Node
## Constant small motion so living things never sit perfectly still: breathing, bobbing, drifting, swaying.

@export var target: Node3D
@export_group("Breathing")
@export_range(0.0, 0.3, 0.005) var breathe_amount := 0.05
@export var breathe_hz := 0.9
@export_group("Bobbing")
@export_range(0.0, 0.2, 0.002) var bob_height := 0.025
@export var bob_hz := 0.6
@export_group("Drifting")
@export_range(0.0, 0.4, 0.005) var drift_radius := 0.0
@export var drift_hz := 0.25
@export_group("Swaying")
@export_range(0.0, 1.0, 0.01) var sway_radians := 0.12
@export var sway_hz := 0.2
@export_range(0.0, 3.0, 0.01) var spin_speed := 0.0

var phase := 0.0
var intensity := 1.0
var _time := 0.0
var _base_rotation_y := 0.0


func _ready() -> void:
	phase = randf() * TAU
	_time = randf() * 10.0
	if target:
		_base_rotation_y = target.rotation.y


func _process(delta: float) -> void:
	if target == null:
		return
	if not Config.animations:
		target.position = Vector3.ZERO
		target.scale = Vector3.ONE
		return
	_time += delta
	var t := _time
	var breath := 1.0 + sin(t * TAU * breathe_hz + phase) * breathe_amount * intensity
	var squash := 1.0 - (breath - 1.0) * 0.6
	target.scale = Vector3(breath, squash, breath)
	var y := (0.5 + 0.5 * sin(t * TAU * bob_hz + phase * 1.3)) * bob_height * intensity
	target.position = Vector3(
		sin(t * TAU * drift_hz + phase) * drift_radius,
		y,
		cos(t * TAU * drift_hz * 0.77 + phase) * drift_radius)
	target.rotation.y = _base_rotation_y + sin(t * TAU * sway_hz + phase) * sway_radians + t * spin_speed * 0.0
	if spin_speed != 0.0:
		_base_rotation_y += spin_speed * delta * 0.1


func set_base_yaw(yaw: float) -> void:
	_base_rotation_y = yaw
