class_name TileBoard
extends Node3D
## Builds the hex tile grid, exposes the adjacency graph, and handles hover bob and mouse picking.

signal hover_changed(tile: int)
signal tile_clicked(tile: int)
signal tile_right_clicked(tile: int)
signal board_rebuilt

@export var tile_scene: PackedScene
@export var columns := 10
@export var rows := 10
@export var camera: CameraController
@export_group("Layout")
@export var tile_scale := 0.985
@export var origin := Vector3(-9.5, 0.0, -7.7942286)
@export var column_spacing := 2.0
@export var row_spacing := 1.7320508
@export_group("Hover")
## How far (world units) the hovered tile bobs up.
@export_range(0.0, 1.0, 0.01, "or_greater") var bob_height := 0.18
@export var bob_hz := 1.4
@export var hover_speed := 7.0
## Share of the bob that neighbouring tiles of the hovered tile follow.
@export_range(0.0, 1.0, 0.01) var neighbor_ripple := 0.22
@export_group("Idle")
## Slow wave of lift running across the whole board so it never sits dead still.
@export_range(0.0, 0.2, 0.005) var idle_wave_height := 0.025
@export var idle_wave_speed := 0.55

var neighbors: Array[PackedInt32Array] = []
var positions := PackedVector3Array()
var active := PackedByteArray()
var hovered_tile := -1
var active_size := 10
var tiles: Dictionary = {}
var materials: Dictionary = {}
var enabled := true

var _base_y: Dictionary = {}
var _hover: Dictionary = {}
var _mouse := Vector2(-1.0, -1.0)
var _pending_click := Vector2(-1.0, -1.0)
var _pending_right := Vector2(-1.0, -1.0)


func _ready() -> void:
	_build_tiles()
	get_window().mouse_exited.connect(_clear_mouse)
	get_window().focus_exited.connect(_clear_mouse)


func _build_tiles() -> void:
	for tile in columns * rows:
		var row := tile / columns
		var column := tile % columns
		var node := tile_scene.instantiate() as StaticBody3D
		node.name = "Hex_%02d_%02d" % [column, row]
		node.set_meta("tile_id", tile)
		var x := origin.x + column * column_spacing + (column_spacing * 0.5 if row % 2 else 0.0)
		node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * tile_scale), Vector3(x, 0.0, origin.z + row * row_spacing))
		add_child(node)
		tiles[tile] = node
		_base_y[tile] = 0.0
		_hover[tile] = 0.0
		positions.append(node.position)
		var mesh := node.get_node("Model/hex_grass") as MeshInstance3D
		var material := mesh.material_override.duplicate() as ShaderMaterial
		mesh.material_override = material
		materials[tile] = material
	_build_adjacency()
	set_active_size(active_size)


func _build_adjacency() -> void:
	var lists: Array = []
	for tile in columns * rows:
		lists.append([])
	for tile in columns * rows:
		var row := tile / columns
		var column := tile % columns
		var diagonal := column + (1 if row % 2 else -1)
		if column + 1 < columns:
			_link(lists, tile, tile + 1)
		if row + 1 < rows:
			_link(lists, tile, tile + columns)
			if diagonal >= 0 and diagonal < columns:
				_link(lists, tile, (row + 1) * columns + diagonal)
	neighbors.clear()
	for list in lists:
		list.sort()
		neighbors.append(PackedInt32Array(list))


func _link(lists: Array, a: int, b: int) -> void:
	lists[a].append(b)
	lists[b].append(a)


## Shrinks the playable area to a centred square. Tiles outside it are hidden and unpickable.
func set_active_size(size: int) -> void:
	active_size = clampi(size, 4, columns)
	var offset := (columns - active_size) / 2
	active = PackedByteArray()
	active.resize(columns * rows)
	for tile in columns * rows:
		var row := tile / columns - offset
		var column := tile % columns - offset
		var inside := row >= 0 and row < active_size and column >= 0 and column < active_size
		active[tile] = 1 if inside else 0
		var node: StaticBody3D = tiles[tile]
		node.visible = inside
		node.collision_layer = 1 if inside else 0
	board_rebuilt.emit()


func tile_lift(id: int) -> float:
	return tiles[id].position.y - _base_y[id] if tiles.has(id) else 0.0


func tile_center() -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for tile in tiles:
		if active[tile] == 1:
			total += positions[tile]
			count += 1
	return total / maxf(1.0, count)


func pick_tile(screen_position: Vector2) -> int:
	if not enabled or camera == null or not get_viewport().get_visible_rect().has_point(screen_position):
		return -1
	var start := camera.project_ray_origin(screen_position)
	var end := start + camera.project_ray_normal(screen_position) * camera.far
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return -1 if hit.is_empty() else int(hit.collider.get_meta("tile_id", -1))


func _clear_mouse() -> void:
	_mouse = Vector2(-1.0, -1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	_mouse = event.position
	if event is InputEventMouseButton and event.pressed and not camera.is_manipulating():
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pending_click = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_pending_right = event.position


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var wave := 0.5 + 0.5 * sin(time * TAU * bob_hz)
	var ripple_ids := {}
	if hovered_tile >= 0:
		for next in neighbors[hovered_tile]:
			ripple_ids[next] = true
	var animate := Config.animations
	for id in tiles:
		if active[id] == 0:
			continue
		var target := 1.0 if id == hovered_tile else (neighbor_ripple if ripple_ids.has(id) else 0.0)
		var amount: float = _hover[id]
		amount = move_toward(amount, target, delta * hover_speed)
		_hover[id] = amount
		var idle := 0.0
		if animate:
			var p := positions[id]
			idle = idle_wave_height * (0.5 + 0.5 * sin(time * idle_wave_speed * TAU - (p.x * 0.28 + p.z * 0.4)))
		var tile: Node3D = tiles[id]
		tile.position.y = _base_y[id] + idle + amount * bob_height * (0.55 + 0.45 * wave if id == hovered_tile else 0.6)
		var material: ShaderMaterial = materials[id]
		material.set_shader_parameter("hover", clampf(amount, 0.0, 1.0) * (0.85 + 0.15 * wave if id == hovered_tile else 0.5))


func _physics_process(_delta: float) -> void:
	if _pending_click.x >= 0.0:
		var clicked := pick_tile(_pending_click)
		_pending_click = Vector2(-1.0, -1.0)
		if clicked >= 0:
			tile_clicked.emit(clicked)
	if _pending_right.x >= 0.0:
		var right := pick_tile(_pending_right)
		_pending_right = Vector2(-1.0, -1.0)
		if right >= 0:
			tile_right_clicked.emit(right)
	var hovered := -1 if camera.is_manipulating() else pick_tile(_mouse)
	if hovered != hovered_tile:
		hovered_tile = hovered
		hover_changed.emit(hovered)
