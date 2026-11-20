extends Node3D

const Rules := preload("res://scenes/cell_rules.gd")
const CellPiece := preload("res://scenes/cell_piece.gd")
const T_CELL_MODEL := preload("res://assets/t_cell/t_cell.gltf")
const BACTERIA_MODEL := preload("res://assets/bacteria/bacterium_game.gltf")
const HUMAN_CELL_MODEL := preload("res://scenes/human_cell_hex.tscn")
const SWIM_SHADER := preload("res://scenes/bacterium_swim.gdshader")
const COLUMNS := 10
const ROWS := 10
const PIECE_COUNT := COLUMNS * ROWS
const HUMAN_CELL_TILES := [34, 35, 44, 45, 46, 54, 55]
const ROW_SPACING := sqrt(3.0)
const TILE_RADIUS := 2.0 / sqrt(3.0)
const ZOOM_STEP := 0.85
const MIN_ZOOM := 0.28
const MAX_ZOOM := 1.6
const ORBIT_SENSITIVITY := 0.006
const MIN_ELEVATION := PI / 12.0
const MAX_ELEVATION := PI * 17.0 / 36.0
const AI_FRAME_BUDGET_USEC := 3500

var rules: Rules
var cells: Array[Vector3i] = []
var pieces: Dictionary = {}
var human_targets: Dictionary = {}
var turn := Rules.IMMUNE
var match_serial := 0
var moving := false
var passed_last_turn := false
var selected := -1
var cloning := false
var team_counts := ""
var mouse_position := Vector2(-1.0, -1.0)
var pending_click := Vector2(-1.0, -1.0)
var camera_dragging := false
var camera_rotating := false
var camera_zoom := 1.0
var swim_material := ShaderMaterial.new()

@onready var camera: Camera3D = $Camera3D
@onready var base_camera_size := camera.size
@onready var ai_timer: Timer = $AITimer
@onready var hover_ring: MeshInstance3D = $HoverRing
@onready var team_marker: MeshInstance3D = $TeamMarker
@onready var piece_layer: Node3D = $Pieces
@onready var target_layer: Node3D = $Targets
@onready var match_status: Label = $Interface/MatchPanel/MatchInfo/Status
@onready var match_goal: Label = $Interface/MatchPanel/MatchInfo/Goal
@onready var activity: Label = $Interface/MatchPanel/MatchInfo/Activity
@onready var move_button: Button = $Interface/MatchPanel/MatchInfo/Actions/Move
@onready var clone_button: Button = $Interface/MatchPanel/MatchInfo/Actions/Clone
@onready var immune_color := marker_material(Color("#44d8ff"))
@onready var bacteria_color := marker_material(Color("#ff649b"))
@onready var human_cell_color := marker_material(Color("#ffcc60"))
@onready var clone_color := marker_material(Color("#80efac"))
@onready var move_color := marker_material(Color("#8dc5e8"))
@onready var capture_color := marker_material(Color("#ff9c71"))


func _ready() -> void:
	build_board()
	swim_material.shader = SWIM_SHADER
	ai_timer.timeout.connect(take_ai_turn)
	move_button.pressed.connect(set_clone_mode.bind(false))
	clone_button.pressed.connect(set_clone_mode.bind(true))
	reset_match()
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)
	get_window().mouse_exited.connect(clear_hover)
	get_window().focus_exited.connect(clear_hover)


func build_board() -> void:
	var graph := AStar3D.new()
	for tile in $Tiles.get_children():
		if tile.has_meta("tile_id"):
			graph.add_point(int(tile.get_meta("tile_id")), to_local(tile.global_position))

	var neighbors: Array[PackedInt64Array] = []
	var positions := PackedVector3Array()
	for tile in PIECE_COUNT:
		var row := floori(float(tile) / COLUMNS)
		var column := tile % COLUMNS
		if graph.has_point(tile):
			var diagonal := column + (1 if row % 2 else -1)
			if column + 1 < COLUMNS and graph.has_point(tile + 1):
				graph.connect_points(tile, tile + 1)
			if row + 1 < ROWS and graph.has_point(tile + COLUMNS):
				graph.connect_points(tile, tile + COLUMNS)
			var across := (row + 1) * COLUMNS + diagonal
			if row + 1 < ROWS and diagonal >= 0 and diagonal < COLUMNS and graph.has_point(across):
				graph.connect_points(tile, across)
		neighbors.append(PackedInt64Array())
		positions.append(Vector3.ZERO)
	for tile in graph.get_point_ids():
		neighbors[tile] = graph.get_point_connections(tile)
		neighbors[tile].sort()
		positions[tile] = graph.get_point_position(tile)
	rules = Rules.new(neighbors, positions)


func reset_match() -> void:
	match_serial += 1
	ai_timer.stop()
	moving = false
	passed_last_turn = false
	pending_click = Vector2(-1.0, -1.0)
	selected = -1
	cloning = false
	clear_layer(piece_layer)
	pieces.clear()
	cells.resize(PIECE_COUNT)
	cells.fill(Vector3i.ZERO)
	cells[0] = rules.starting_cell(Rules.IMMUNE)
	cells[PIECE_COUNT - 1] = rules.starting_cell(Rules.BACTERIA)
	spawn_piece(0)
	spawn_piece(PIECE_COUNT - 1)
	for tile in HUMAN_CELL_TILES:
		cells[tile] = Vector3i(Rules.HUMAN, 0, 0)
		spawn_piece(tile)
	activity.text = "Protect the gold human cells and eliminate the bacteria."
	start_human_turn()


func marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


func spawn_piece(tile: int) -> void:
	var team := cells[tile].x
	var model_scene: PackedScene
	var color: StandardMaterial3D
	match team:
		Rules.IMMUNE:
			model_scene = T_CELL_MODEL
			color = immune_color
		Rules.BACTERIA:
			model_scene = BACTERIA_MODEL
			color = bacteria_color
		Rules.HUMAN:
			model_scene = HUMAN_CELL_MODEL
			color = human_cell_color
	var piece := CellPiece.new()
	var model := model_scene.instantiate() as Node3D
	if team == Rules.BACTERIA:
		model.scale = Vector3.ONE * 5.6
		for surface in model.find_children("*", "MeshInstance3D", true, false):
			surface.material_override = swim_material
			surface.custom_aabb = AABB(Vector3(-0.15, -0.02, -0.09), Vector3(0.33, 0.16, 0.18))
	var marker := team_marker.duplicate() as MeshInstance3D
	marker.position.y = 0.023
	marker.scale = Vector3(0.86, 1.0, 0.86)
	marker.material_override = color
	marker.show()
	piece.add_child(marker)
	piece.add_child(model)
	piece.position = rules.positions[tile]
	if team != Rules.HUMAN:
		piece.rotation.y = 2.45 if team == Rules.IMMUNE else -0.68
	piece_layer.add_child(piece)
	pieces[tile] = piece


func clear_layer(layer: Node3D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func start_human_turn() -> void:
	turn = Rules.IMMUNE
	var options := rules.actions(cells, Rules.IMMUNE)
	if options.is_empty():
		pass_turn("T cells")
		return
	if selected < 0 or cells[selected].x != Rules.IMMUNE:
		selected = options[0].x
	update_interface()


func start_bacteria_turn() -> void:
	turn = Rules.BACTERIA
	update_interface()
	ai_timer.start()


func pass_turn(team_name: String) -> void:
	activity.text = "%s have no legal action." % team_name
	if passed_last_turn:
		turn = 0
		update_interface()
		match_status.text = "Draw · Neither side can act"
		return
	passed_last_turn = true
	if turn == Rules.IMMUNE:
		start_bacteria_turn()
	else:
		start_human_turn()


func set_clone_mode(enabled: bool) -> void:
	if turn != Rules.IMMUNE or moving:
		return
	cloning = enabled
	update_interface()


func update_interface() -> void:
	clear_layer(target_layer)
	human_targets.clear()
	hover_ring.hide()
	var can_act := turn == Rules.IMMUNE and not moving
	move_button.disabled = not can_act
	clone_button.disabled = not can_act
	move_button.set_pressed_no_signal(not cloning)
	clone_button.set_pressed_no_signal(cloning)
	team_counts = "Human cells %d/%d  ·  T cells %d  ·  Bacteria %d" % [
		count_team(Rules.HUMAN), HUMAN_CELL_TILES.size(), count_team(Rules.IMMUNE), count_team(Rules.BACTERIA)
	]
	match_goal.text = team_counts
	if moving:
		match_status.text = "T cell moving…" if turn == Rules.IMMUNE else "Bacterium moving…"
	elif turn == Rules.BACTERIA:
		match_status.text = "Bacteria turn · Choosing an action…"
	elif can_act and selected < 0:
		match_status.text = "Your turn · Select a T cell"
	elif can_act:
		var instruction := "Clone onto a green hex" if cloning else "Move or capture on a highlighted hex"
		match_status.text = "Range %d · %s" % [cells[selected].y, instruction]
		add_target_marker(selected, immune_color, 1.0)
		for action in rules.cell_actions(cells, selected):
			if (action.z == 1) != cloning:
				continue
			human_targets[action.y] = action
			var color := move_color
			if cloning:
				color = clone_color
			elif cells[action.y].x == Rules.BACTERIA:
				color = capture_color
			add_target_marker(action.y, color, 0.74)


func add_target_marker(tile: int, color: StandardMaterial3D, size: float) -> void:
	var marker := team_marker.duplicate() as MeshInstance3D
	marker.position = rules.positions[tile] + Vector3.UP * 0.012
	marker.scale = Vector3(size, 1.0, size)
	marker.material_override = color
	marker.show()
	target_layer.add_child(marker)


func count_team(team: int) -> int:
	var count := 0
	for cell in cells:
		if cell.x == team:
			count += 1
	return count


# Two-ply minimax, weighting each random clone outcome before comparing actions.
# Yield between reply batches to keep camera and input responsive on fuller boards.
func take_ai_turn() -> void:
	var serial := match_serial
	var bacteria := count_team(Rules.BACTERIA)
	var humans := count_team(Rules.HUMAN)
	var options := rules.actions(cells, Rules.BACTERIA)
	if options.is_empty():
		pass_turn("Bacteria")
		return
	var best := Rules.NO_ACTION
	var best_score := -INF
	var deadline := Time.get_ticks_usec() + AI_FRAME_BUDGET_USEC
	var distances := rules.infection_distances(cells)
	for action in options:
		var infecting := cells[action.y].x == Rules.HUMAN
		if infecting and rules.captured_tiles(cells, action).size() == humans:
			play_action(action)
			return
		var variants: Array[Vector3i] = [Vector3i.ZERO]
		if action.z == 1:
			variants = rules.clone_variants(cells[action.x])
		var total := 0.0
		for clone in variants:
			var reply_board := cells.duplicate()
			rules.apply(reply_board, action, clone)
			var replies := rules.actions(reply_board, Rules.IMMUNE)
			var reply_distances := rules.infection_distances(reply_board) if infecting else distances
			var nearest := rules.nearest_bacteria(reply_board, reply_distances)
			var next_score := rules.score(reply_board, reply_distances, nearest)
			if replies.is_empty():
				total += next_score
			else:
				var worst_reply := INF
				for reply in replies:
					var score := rules.immune_reply_score(
						reply_board, reply, next_score, bacteria + action.z, reply_distances, nearest
					)
					worst_reply = minf(worst_reply, score)
					if worst_reply == -Rules.WIN_SCORE or (action.z == 0 and worst_reply <= best_score):
						break
					if Time.get_ticks_usec() >= deadline:
						await get_tree().process_frame
						if serial != match_serial:
							return
						deadline = Time.get_ticks_usec() + AI_FRAME_BUDGET_USEC
				total += worst_reply
			if Time.get_ticks_usec() >= deadline:
				await get_tree().process_frame
				if serial != match_serial:
					return
				deadline = Time.get_ticks_usec() + AI_FRAME_BUDGET_USEC
		var score := total / variants.size()
		if score > best_score:
			best_score = score
			best = action
	play_action(best)


func play_action(action: Vector3i) -> void:
	passed_last_turn = false
	if action.z == 1:
		var parent := cells[action.x]
		var clone: Vector3i = rules.clone_variants(parent).pick_random()
		rules.apply(cells, action, clone)
		spawn_piece(action.y)
		var team := "T cell" if turn == Rules.IMMUNE else "Bacterium"
		var evolution := "range %d → %d" % [parent.y, clone.y]
		if parent.z != clone.z:
			evolution = "infectibility %d → %d" % [parent.z, clone.z]
		elif parent.y == clone.y:
			evolution = "traits steady"
		activity.text = "%s cloned · Clonal evolution · %s" % [team, evolution]
		finish_turn()
		return
	moving = true
	update_interface()
	var piece: CellPiece = pieces[action.x]
	var path := rules.move_path(cells, action)
	piece.glide(path, rules.positions).finished.connect(finish_move.bind(action, match_serial, path.size()))


func finish_move(action: Vector3i, serial: int, distance: int) -> void:
	if serial != match_serial:
		return
	var infecting := cells[action.y].x == Rules.HUMAN
	var captured := rules.captured_tiles(cells, action)
	for tile in captured:
		pieces[tile].queue_free()
		pieces.erase(tile)
	rules.apply(cells, action, Vector3i.ZERO)
	pieces[action.y] = pieces[action.x]
	pieces.erase(action.x)
	if turn == Rules.IMMUNE:
		selected = action.y
	moving = false
	var team := "T cell" if turn == Rules.IMMUNE else "Bacterium"
	activity.text = "%s moved %d hexes." % [team, distance]
	if infecting:
		activity.text = "Bacterium infected %d human cell(s)." % captured.size()
	elif not captured.is_empty():
		activity.text = "%s consumed %d opposing cell(s)." % [team, captured.size()]
	finish_turn()


func finish_turn() -> void:
	var goal := Rules.BACTERIA if turn == Rules.IMMUNE else Rules.HUMAN
	if count_team(goal) == 0:
		var result := "You win! · Bacteria eliminated" if turn == Rules.IMMUNE else "Bacteria win · All human cells infected"
		turn = 0
		update_interface()
		match_status.text = result + " · Press R to restart"
	elif turn == Rules.IMMUNE:
		start_bacteria_turn()
	else:
		start_human_turn()


func fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var board_radius := Vector2(COLUMNS + 0.5, (ROWS - 1) * ROW_SPACING * 0.5 + TILE_RADIUS).length()
	camera.size = maxf(base_camera_size, 2.0 * (board_radius + 1.2) / viewport_size.aspect()) * camera_zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				reset_match()
			KEY_M:
				set_clone_mode(false)
			KEY_C:
				set_clone_mode(true)
	if not event is InputEventMouse:
		return
	mouse_position = event.position
	if event is InputEventMouseMotion:
		if camera_rotating:
			orbit_camera(event.relative)
		elif camera_dragging:
			var previous := board_plane_point(event.position - event.relative)
			camera.global_position += previous - board_plane_point(event.position)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				camera_dragging = event.pressed
			MOUSE_BUTTON_MIDDLE:
				camera_rotating = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_at(event.position, ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_at(event.position, 1.0 / ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
				if event.pressed and turn == Rules.IMMUNE and not moving and not (camera_dragging or camera_rotating):
					pending_click = event.position


func board_plane_point(screen_position: Vector2) -> Vector3:
	var plane := Plane(global_basis.y.normalized(), global_position)
	var origin := camera.project_ray_origin(screen_position)
	var hit: Variant = plane.intersects_ray(origin, camera.project_ray_normal(screen_position))
	return hit if hit != null else camera.global_position


func zoom_at(screen_position: Vector2, factor: float) -> void:
	var anchor := board_plane_point(screen_position)
	camera_zoom = clampf(camera_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	fit_camera()
	camera.global_position += anchor - board_plane_point(screen_position)


func orbit_camera(mouse_delta: Vector2) -> void:
	var pivot := board_plane_point(get_viewport().get_visible_rect().get_center())
	var up := global_basis.y.normalized()
	var offset := camera.global_position - pivot
	if offset.is_zero_approx():
		return
	var elevation := PI * 0.5 - offset.angle_to(up)
	var next_elevation := clampf(elevation + mouse_delta.y * ORBIT_SENSITIVITY, MIN_ELEVATION, MAX_ELEVATION)
	offset = offset.rotated(camera.global_basis.x.normalized(), elevation - next_elevation)
	offset = offset.rotated(up, -mouse_delta.x * ORBIT_SENSITIVITY)
	camera.global_position = pivot + offset
	camera.look_at(pivot, up)


func clear_hover() -> void:
	mouse_position = Vector2(-1.0, -1.0)
	camera_dragging = false
	camera_rotating = false


func _physics_process(_delta: float) -> void:
	if pending_click.x >= 0.0:
		var clicked := pick_tile(pending_click)
		pending_click = Vector2(-1.0, -1.0)
		if clicked >= 0 and turn == Rules.IMMUNE and not moving:
			if cells[clicked].x == Rules.IMMUNE:
				selected = clicked
				update_interface()
			elif human_targets.has(clicked):
				play_action(human_targets[clicked])

	var hovered := -1 if camera_dragging or camera_rotating else pick_tile(mouse_position)
	hover_ring.visible = human_targets.has(hovered)
	if hover_ring.visible:
		hover_ring.position = rules.positions[hovered] + Vector3.UP * 0.018
	var details := team_counts
	if turn == Rules.IMMUNE and not moving and hovered >= 0 and cells[hovered].x == Rules.BACTERIA:
		details += "  ·  Range %d, infectibility %d" % [cells[hovered].y, cells[hovered].z]
	if match_goal.text != details:
		match_goal.text = details


func pick_tile(screen_position: Vector2) -> int:
	if not get_viewport().get_visible_rect().has_point(screen_position):
		return -1
	var start := camera.project_ray_origin(screen_position)
	var end := start + camera.project_ray_normal(screen_position) * camera.far
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return -1 if hit.is_empty() else int(hit.collider.get_meta("tile_id", -1))
