class_name Minimax
extends RefCounted
## Alpha-beta minimax over LightState for immediate tactical threats.

const UNIT_LIMIT := 3
const CAND_LIMIT := 3


## Value of making `cand` with unit `u`, assuming the opponent replies as harmfully as possible.
static func evaluate_root(state: LightState, u: int, cand: Array, depth: int) -> Dictionary:
	var me := state.us[u]
	var after := state.copy()
	after.apply(u, cand)
	var counter := [1]
	var value := _search(after, me, Sim.other(me), depth - 1, -INF, INF, counter)
	return {"value": value, "nodes": counter[0]}


static func _search(state: LightState, me: int, mover: int, depth: int, alpha: float, beta: float, counter: Array) -> float:
	if depth <= 0:
		return state.value(me)
	var units := _active_units(state, mover)
	if units.is_empty():
		return _search(state, me, Sim.other(mover), depth - 1, alpha, beta, counter)
	var maximizing := mover == me
	var best := -INF if maximizing else INF
	for u in units:
		for cand in state.candidates(u, CAND_LIMIT):
			var child := state.copy()
			child.apply(u, cand)
			counter[0] += 1
			var value := _search(child, me, Sim.other(mover), depth - 1, alpha, beta, counter)
			if maximizing:
				best = maxf(best, value)
				alpha = maxf(alpha, best)
			else:
				best = minf(best, value)
				beta = minf(beta, best)
			if beta <= alpha:
				return best
	return best


static func _active_units(state: LightState, side: int) -> Array:
	var scored: Array = []
	for u in state.uid.size():
		if state.us[u] == side and state.uh[u] > 0.0:
			scored.append([state.nearest_unit_dist(state.ut[u], Sim.other(side)), u])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var units: Array = []
	for index in mini(UNIT_LIMIT, scored.size()):
		units.append(scored[index][1])
	return units
