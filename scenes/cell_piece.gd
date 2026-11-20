extends Node3D

const STEP_DURATION := 0.14


func glide(route: PackedInt32Array, positions: PackedVector3Array) -> Tween:
	var motion := create_tween()
	var previous := position
	var yaw := rotation.y
	for tile in route:
		var destination := positions[tile]
		var direction := destination - previous
		yaw += angle_difference(yaw, atan2(direction.z, -direction.x))
		motion.tween_property(self, "position", destination, STEP_DURATION).set_trans(Tween.TRANS_SINE)
		motion.parallel().tween_property(self, "rotation:y", yaw, STEP_DURATION)
		previous = destination
	return motion
