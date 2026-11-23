class_name SimClock
extends Node
## Play / pause / step / speed for the simulation. Other nodes ask it before moving on.

enum Status { IDLE, RUNNING, PAUSED, STOPPED, FINISHED }

@export var world: WorldHost
@export var speeds: PackedFloat32Array = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

var status := Status.IDLE
var step_pending := false
var paused := false


func _process(delta: float) -> void:
	if world.state == null or world.state.finished or paused or status != Status.RUNNING:
		return
	world.state.elapsed += delta * Config.speed
	GameLog.elapsed = world.state.elapsed


func start() -> void:
	paused = false
	step_pending = false
	_set_status(Status.RUNNING)


func set_paused(value: bool) -> void:
	if status == Status.STOPPED or status == Status.FINISHED:
		return
	paused = value
	_set_status(Status.PAUSED if value else Status.RUNNING)
	Sfx.play_ui("ui_pause" if value else "ui_click")


func toggle_pause() -> void:
	set_paused(not paused)


func request_step() -> void:
	if status == Status.STOPPED or status == Status.FINISHED:
		return
	step_pending = true
	paused = false
	_set_status(Status.RUNNING)


func finish(stopped := false) -> void:
	paused = false
	_set_status(Status.STOPPED if stopped else Status.FINISHED)


func set_speed(value: float) -> void:
	Config.speed = value
	Events.speed_changed.emit(value)


func cycle_speed(direction: int) -> void:
	var index := speeds.find(Config.speed)
	if index < 0:
		index = 2
	set_speed(speeds[clampi(index + direction, 0, speeds.size() - 1)])


## Blocks while paused. Returns false when the match was stopped meanwhile.
func checkpoint() -> bool:
	while paused and status == Status.PAUSED:
		await get_tree().process_frame
	return status == Status.RUNNING or status == Status.PAUSED


func wait(seconds: float) -> void:
	if Config.unlimited_speed or seconds <= 0.0:
		return
	var remaining := seconds
	while remaining > 0.0:
		await get_tree().process_frame
		if not paused:
			remaining -= get_process_delta_time() * Config.speed
		if status == Status.STOPPED or status == Status.FINISHED:
			return


func _set_status(next: Status) -> void:
	status = next
	Events.status_changed.emit(status_text())


func status_text() -> String:
	match status:
		Status.RUNNING: return "Running"
		Status.PAUSED: return "Paused"
		Status.STOPPED: return "Stopped"
		Status.FINISHED: return "Finished"
	return "Idle"
