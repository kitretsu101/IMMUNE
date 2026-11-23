class_name Pathing
extends RefCounted
## BFS reachability and A* routing on the hex tile graph.


## Tiles reachable within `steps`. Returns tile -> parent (start has parent -1).
## Occupied tiles cannot be entered, which is why this also answers "can I walk there".
static func bfs_reach(state: WorldState, start: int, steps: int, ignore_org := 0) -> Dictionary:
	var parents := {start: -1}
	var depth := {start: 0}
	var queue := [start]
	var head := 0
	while head < queue.size():
		var tile: int = queue[head]
		head += 1
		if depth[tile] >= steps:
			continue
		for next in state.neighbors[tile]:
			if parents.has(next):
				continue
			var occupant := state.occupant[next]
			if occupant != 0 and occupant != ignore_org:
				continue
			parents[next] = tile
			depth[next] = depth[tile] + 1
			queue.append(next)
	return parents


static func path_from_parents(parents: Dictionary, start: int, goal: int) -> PackedInt32Array:
	var route := PackedInt32Array()
	var tile := goal
	while tile != start and parents.has(tile):
		route.append(tile)
		tile = parents[tile]
	route.reverse()
	return route


## A* from `from_tile` to `to_tile` over free tiles. `danger` adds extra cost per tile.
## The goal tile itself may be occupied. Returns tiles after the start; empty when unreachable.
static func astar(state: WorldState, from_tile: int, to_tile: int, danger := PackedFloat32Array()) -> PackedInt32Array:
	if from_tile == to_tile:
		return PackedInt32Array()
	var open := [from_tile]
	var g := {from_tile: 0.0}
	var came := {}
	var closed := {}
	var goal_pos := state.positions[to_tile]
	while not open.is_empty():
		var best_index := 0
		var best_f := INF
		for index in open.size():
			var tile: int = open[index]
			var f: float = g[tile] + state.positions[tile].distance_to(goal_pos) * 0.5
			if f < best_f:
				best_f = f
				best_index = index
		var current: int = open[best_index]
		open.remove_at(best_index)
		if current == to_tile:
			var route := PackedInt32Array()
			var tile := current
			while tile != from_tile:
				route.append(tile)
				tile = came[tile]
			route.reverse()
			return route
		closed[current] = true
		for next in state.neighbors[current]:
			if closed.has(next):
				continue
			if state.occupant[next] != 0 and next != to_tile:
				continue
			var step := 1.0 + (danger[next] if danger.size() > next else 0.0)
			var cost: float = g[current] + step
			if not g.has(next) or cost < g[next]:
				g[next] = cost
				came[next] = current
				if not open.has(next):
					open.append(next)
	return PackedInt32Array()


## Per-tile danger from enemy presence, used as an A* cost layer.
static func danger_map(state: WorldState, team: int) -> PackedFloat32Array:
	var danger := PackedFloat32Array()
	danger.resize(state.count)
	var enemy := Sim.other(team)
	for organism in state.living(enemy):
		for tile in state.count:
			if state.active[tile] == 1:
				var d := state.distance(organism.tile, tile)
				if d <= 2:
					danger[tile] += 2.5 if d <= 1 else 1.0
	return danger
