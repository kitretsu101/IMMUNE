class_name AnimationGate
extends Node
## Lets presentation nodes tell the turn flow "I'm still animating". The flow waits for the longest hold.

var _release_at := 0.0


func hold(seconds: float) -> void:
	if not Config.animations or Config.unlimited_speed:
		return
	_release_at = maxf(_release_at, Time.get_ticks_msec() / 1000.0 + seconds)


func remaining() -> float:
	return maxf(0.0, _release_at - Time.get_ticks_msec() / 1000.0)


func clear() -> void:
	_release_at = 0.0
