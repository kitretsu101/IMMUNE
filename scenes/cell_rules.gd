extends RefCounted

const IMMUNE := 1
const BACTERIA := 2
const MAX_MOVE := 4
const MAX_INFECT := 7
const NO_ACTION := Vector3i(-1, -1, 0)
const WIN_SCORE := 100000.0

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


# Only empty tiles can be crossed. An enemy tile ends the path and is captured on arrival.
func move_parents(cells: Array[Vector3i], start: int) -> Dictionary:
	var parents := {start: -1}
	var frontier := PackedInt32Array([start])
	var team := cells[start].x
	for _step in cells[start].y:
		var next := PackedInt32Array()
		for tile in frontier:
			for target in neighbors[tile]:
				if parents.has(target) or cells[target].x == team:
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
	var attacker := cells[action.x]
	for tile in neighbors[action.y]:
		if captured.size() >= attacker.z:
			break
		if cells[tile].x != 0 and cells[tile].x != attacker.x:
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


func piece_value(cell: Vector3i, tile: int) -> float:
	# Material leads the evaluation. A smaller positional bonus breaks ties toward the opponent.
	var advance := positions[tile].x + positions[tile].z
	if cell.x == BACTERIA:
		return 12.0 + cell.y * 1.4 + cell.z * 1.1 - advance * 0.09
	return 12.0 + cell.y * 1.4 + advance * 0.09


func score(cells: Array[Vector3i]) -> float:
	var result := 0.0
	for tile in cells.size():
		var cell := cells[tile]
		if cell.x == IMMUNE:
			result -= piece_value(cell, tile)
		elif cell.x == BACTERIA:
			result += piece_value(cell, tile)
	return result


func immune_reply_score(cells: Array[Vector3i], action: Vector3i, current: float, bacteria: int) -> float:
	var cell := cells[action.x]
	if action.z == 1:
		var total := 0.0
		var variants := clone_variants(cell)
		for clone in variants:
			total += piece_value(clone, action.y)
		return current - total / variants.size()
	var target := cells[action.y]
	if target.x == BACTERIA:
		if bacteria == 1:
			return -WIN_SCORE
		current -= piece_value(target, action.y)
	return current + piece_value(cell, action.x) - piece_value(cell, action.y)
