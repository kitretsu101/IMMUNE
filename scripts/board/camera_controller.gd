class_name CameraController
extends Camera3D
## Orthographic board camera: right-drag pans, middle-drag orbits, wheel zooms.

const ROW_SPACING := sqrt(3.0)
const TILE_RADIUS := 2.0 / sqrt(3.0)

@export var tile_board: TileBoard
@export_range(0.5, 0.99, 0.01) var zoom_step := 0.85
@export var min_zoom := 0.28
@export var max_zoom := 1.6
@export var orbit_sensitivity := 0.006
@export_range(0.0, 90.0, 1.0, "degrees") var min_elevation_degrees := 15.0
@export_range(0.0, 90.0, 1.0, "degrees") var max_elevation_degrees := 85.0
## Extra world units kept around the board when fitting it to the window.
@export var fit_padding := 1.2

var home_transform := Transform3D.IDENTITY
var dragging := false
var rotating := false
var zoom_factor := 1.0

var safe_margins := Vector4.ZERO


func _ready() -> void:
	home_transform = global_transform
	fit()
	get_viewport().size_changed.connect(fit)
	tile_board.board_rebuilt.connect(fit)
	get_window().mouse_exited.connect(release)
	get_window().focus_exited.connect(release)


func is_manipulating() -> bool:
	return dragging or rotating


func release() -> void:
	dragging = false
	rotating = false


func set_safe_margins(left: float, top: float, right: float, bottom: float) -> void:
	safe_margins = Vector4(left, top, right, bottom)
	fit()


func fit() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var low := Vector3(INF, 0, INF)
	var high := Vector3(-INF, 0, -INF)
	for tile in tile_board.tiles:
		if tile_board.active[tile] == 1:
			var p := tile_board.positions[tile]
			low = Vector3(minf(low.x, p.x), 0, minf(low.z, p.z))
			high = Vector3(maxf(high.x, p.x), 0, maxf(high.z, p.z))
	var center := (low + high) * 0.5
	var half := (high - low) * 0.5 + Vector3(1.2, 0, 1.2)
	var extent := Vector2.ZERO
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var offset: Vector3 = corner * half
		extent.x = maxf(extent.x, absf(offset.dot(global_basis.x)))
		extent.y = maxf(extent.y, absf(offset.dot(global_basis.y)))
	var available := Vector2(
		maxf(120.0, viewport_size.x - safe_margins.x - safe_margins.z),
		maxf(120.0, viewport_size.y - safe_margins.y - safe_margins.w))
	var fitted := maxf(2.0 * extent.y * viewport_size.y / available.y, 2.0 * extent.x * viewport_size.y / available.x)
	size = fitted * zoom_factor
	var world_per_pixel := size / viewport_size.y
	h_offset = -(safe_margins.x - safe_margins.z) * 0.5 * world_per_pixel
	v_offset = (safe_margins.y - safe_margins.w) * 0.5 * world_per_pixel


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if rotating:
			orbit(event.relative)
		elif dragging:
			var previous := board_plane_point(event.position - event.relative)
			global_position += previous - board_plane_point(event.position)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				dragging = event.pressed
			MOUSE_BUTTON_MIDDLE:
				rotating = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_at(event.position, zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_at(event.position, 1.0 / zoom_step)


func board_plane_point(screen_position: Vector2) -> Vector3:
	var plane := Plane(tile_board.global_basis.y.normalized(), tile_board.global_position)
	var origin := project_ray_origin(screen_position)
	var hit: Variant = plane.intersects_ray(origin, project_ray_normal(screen_position))
	return hit if hit != null else global_position


func zoom_at(screen_position: Vector2, factor: float) -> void:
	var anchor := board_plane_point(screen_position)
	zoom_factor = clampf(zoom_factor * factor, min_zoom, max_zoom)
	fit()
	global_position += anchor - board_plane_point(screen_position)


func orbit(mouse_delta: Vector2) -> void:
	var pivot := board_plane_point(get_viewport().get_visible_rect().get_center())
	var up := tile_board.global_basis.y.normalized()
	var offset := global_position - pivot
	if offset.is_zero_approx():
		return
	var elevation := PI * 0.5 - offset.angle_to(up)
	var next_elevation := clampf(
		elevation + mouse_delta.y * orbit_sensitivity,
		deg_to_rad(min_elevation_degrees), deg_to_rad(max_elevation_degrees)
	)
	offset = offset.rotated(global_basis.x.normalized(), elevation - next_elevation)
	offset = offset.rotated(up, -mouse_delta.x * orbit_sensitivity)
	global_position = pivot + offset
	look_at(pivot, up)


func reset_view() -> void:
	global_transform = home_transform
	zoom_factor = 1.0
	fit()


func zoom_by(factor: float) -> void:
	zoom_factor = clampf(zoom_factor * factor, min_zoom, max_zoom)
	fit()
