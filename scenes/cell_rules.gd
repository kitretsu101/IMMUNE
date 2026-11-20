extends RefCounted

const IMMUNE := 1
const BACTERIA := 2
const HUMAN := 3
const MAX_MOVE := 4
const MAX_INFECT := 7
const NO_ACTION := Vector3i(-1, -1, 0)
const WIN_SCORE := 100000.0
const INFECTION_VALUE := 250.0
const APPROACH_VALUE := 20.0

var neighbors: Array[PackedInt64Array]
var positions: PackedVector3Array


func _init(connections: Array[PackedInt64Array], tile_positions: PackedVector3Array) -> void:
	neighbors = connections
	positions = tile_positions


func starting_cell(team: int) -> Vector3i:
	return Vector3i(team, 3 + randi_range(-1, 1), 2 + randi_range(-1, 1) if team == BACTERIA else 1)


func clone_variants(parent: Vector3i) -> Array[Vector3i]:
	var variants: Array[Vector3i] = []
	for change in [-1, 0, 1]:
		variants.append(Vector3i(parent.x, clampi(parent.y + change, 1, MAX_MOVE), parent.z))
		if parent.x == BACTERIA:
			variants.append(Vector3i(parent.x, parent.y, clampi(parent.z + change, 1, MAX_INFECT)))
	return variants


func actions(cells: Array[Vector3i], team: int) -> Array[Vector3i]:
	var options: Array[Vector3i] = []
	for tile in cells.size():
		if cells[tile].x == team:
			options.append_array(cell_actions(cells, tile))
	return options


func cell_actions(cells: Array[Vector3i], tile: int) -> Array[Vector3i]:
	var options: Array[Vector3i] = []
	for target in move_parents(cells, tile):
		if target != tile:
			options.append(Vector3i(tile, target, 0))
	for target in neighbors[tile]:
		if cells[target] == Vector3i.ZERO:
			options.append(Vector3i(tile, target, 1))
	return options


# Only empty tiles can be crossed. Human cells block T cells and can be infected by bacteria.
func move_parents(cells: Array[Vector3i], start: int) -> Dictionary:
	var parents := {start: -1}
	var frontier := PackedInt32Array([start])
	var team := cells[start].x
	for _step in cells[start].y:
		var next := PackedInt32Array()
		for tile in frontier:
			for target in neighbors[tile]:
				var occupant := cells[target].x
				if parents.has(target) or occupant == team or (team == IMMUNE and occupant == HUMAN):
					continue
				parents[target] = tile
				if cells[target] == Vector3i.ZERO:
					next.append(target)
		if next.is_empty():
			break
		frontier = next
	return parents


func move_path(cells: Array[Vector3i], action: Vector3i) -> PackedInt32Array:
	var parents := move_parents(cells, action.x)
	var route := PackedInt32Array()
	var tile := action.y
	while tile != action.x:
		route.append(tile)
		tile = parents[tile]
	route.reverse()
	return route


func captured_tiles(cells: Array[Vector3i], action: Vector3i) -> PackedInt32Array:
	var captured := PackedInt32Array()
	if action.z == 1 or cells[action.y] == Vector3i.ZERO:
		return captured
	captured.append(action.y)
	if cells[action.y].x != HUMAN:
		return captured
	var attacker := cells[action.x]
	for tile in neighbors[action.y]:
		if captured.size() >= attacker.z:
			break
		if cells[tile].x == HUMAN:
			captured.append(tile)
	return captured


func apply(cells: Array[Vector3i], action: Vector3i, clone: Vector3i) -> void:
	if action.z == 1:
		cells[action.y] = clone
		return
	for tile in captured_tiles(cells, action):
		cells[tile] = Vector3i.ZERO
	cells[action.y] = cells[action.x]
	cells[action.x] = Vector3i.ZERO


func infection_distances(cells: Array[Vector3i]) -> PackedInt32Array:
	var distances := PackedInt32Array()
	distances.resize(cells.size())
	distances.fill(cells.size())
	var frontier := PackedInt32Array()
	for tile in cells.size():
		if cells[tile].x == HUMAN:
			distances[tile] = 0
			frontier.append(tile)
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		for neighbor in neighbors[tile]:
			if distances[neighbor] == cells.size():
				distances[neighbor] = distances[tile] + 1
				frontier.append(neighbor)
		index += 1
	return distances


func nearest_bacteria(cells: Array[Vector3i], distances: PackedInt32Array) -> Vector2i:
	var nearest := Vector2i(cells.size(), cells.size())
	for tile in cells.size():
		if cells[tile].x != BACTERIA:
			continue
		var distance := distances[tile]
		if distance < nearest.x:
			nearest = Vector2i(distance, nearest.x)
		elif distance < nearest.y:
			nearest.y = distance
	return nearest


func piece_value(cell: Vector3i, tile: int, distances: PackedInt32Array) -> float:
	if cell.x == BACTERIA:
		var pressure := maxf(0.0, 12.0 - distances[tile] * 2.0)
		return 8.0 + cell.y * 0.8 + cell.z * 0.7 + pressure
	return 12.0 + cell.y * 1.4 + (positions[tile].x + positions[tile].z) * 0.09


func score(cells: Array[Vector3i], distances: PackedInt32Array, nearest: Vector2i) -> float:
	var result := -nearest.x * APPROACH_VALUE
	for tile in cells.size():
		var cell := cells[tile]
		if cell.x == IMMUNE:
			result -= piece_value(cell, tile, distances)
		elif cell.x == BACTERIA:
			result += piece_value(cell, tile, distances)
		elif cell.x == HUMAN:
			result -= INFECTION_VALUE
	return result


func immune_reply_score(
	cells: Array[Vector3i], action: Vector3i, current: float, bacteria: int,
	distances: PackedInt32Array, nearest: Vector2i
) -> float:
	var cell := cells[action.x]
	if action.z == 1:
		var total := 0.0
		var variants := clone_variants(cell)
		for clone in variants:
			total += piece_value(clone, action.y, distances)
		return current - total / variants.size()
	var target := cells[action.y]
	if target.x == BACTERIA:
		if bacteria == 1:
			return -WIN_SCORE
		current -= piece_value(target, action.y, distances)
		if distances[action.y] == nearest.x:
			current -= (nearest.y - nearest.x) * APPROACH_VALUE
	return current + piece_value(cell, action.x, distances) - piece_value(cell, action.y, distances)
