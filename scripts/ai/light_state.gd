class_name LightState
extends RefCounted
## A tiny copy of the world used by Minimax and MCTS. Expected-value rules, no events, cheap to clone.

const FREE := 0
const BACT_OCC := 1
const IMMUNE_OCC := 2
# Candidate layout: [kind, tile, target_unit]
const K_MOVE := 0
const K_ATTACK := 1
const K_INFECT := 2
const K_CLONE := 3
const K_BIOFILM := 4
const K_REST := 5
const K_WAIT := 6

var n := 0
var dist: PackedInt32Array
var nbr: Array
var core: PackedInt32Array
var cap_b := 14
var cap_i := 10
var ap_b := 3
var ap_i := 2
var occ := PackedByteArray()
var tissue := PackedByteArray()
var nut := PackedFloat32Array()
var bio := PackedByteArray()
var uid := PackedInt32Array()
var ut := PackedInt32Array()
var us := PackedByteArray()
var uh := PackedFloat32Array()
var ua := PackedFloat32Array()
var ud := PackedFloat32Array()
var ur := PackedInt32Array()
var ue := PackedFloat32Array()
var bonus := 0.0
var nodes := 0
var within: Array = []
var open_core_d := PackedInt32Array()
var _core_signature := -1
var infected_count := 0
var _focus_enemy := -1


static func from_world(state: WorldState) -> LightState:
	var light := LightState.new()
	light.n = state.count
	light.dist = state.dist
	light.nbr = state.neighbors
	light.core = state.core
	light.cap_b = state.setup.bact_cap
	light.cap_i = state.setup.immune_cap
	light.ap_b = state.setup.bact_actions
	light.ap_i = state.setup.immune_actions
	light.occ.resize(state.count)
	light.within = state.within_tiles(4)
	light.tissue = state.tissue.duplicate()
	light.nut = state.nutrients.duplicate()
	light.bio = state.biofilm.duplicate()
	for t in state.count:
		if state.tissue[t] == Sim.Tissue.INFECTED:
			light.infected_count += 1
	for id in state.organisms:
		var organism: Organism = state.organisms[id]
		if not organism.alive:
			continue
		var bacterium := organism.team == Sim.BACTERIA
		light._add(organism.id, organism.tile, Sim.BACTERIA if bacterium else Sim.IMMUNE, organism.health,
			organism.infectivity if bacterium else organism.attack,
			organism.evasion if bacterium else organism.detection,
			organism.move_range, organism.energy)
	return light


func _add(id: int, tile: int, side: int, hp: float, a: float, d: float, r: int, e: float) -> int:
	uid.append(id)
	ut.append(tile)
	us.append(side)
	uh.append(hp)
	ua.append(a)
	ud.append(d)
	ur.append(r)
	ue.append(e)
	occ[tile] = BACT_OCC if side == Sim.BACTERIA else IMMUNE_OCC
	return uid.size() - 1


func copy() -> LightState:
	var other := LightState.new()
	other.n = n
	other.dist = dist
	other.nbr = nbr
	other.core = core
	other.cap_b = cap_b
	other.cap_i = cap_i
	other.ap_b = ap_b
	other.ap_i = ap_i
	other.occ = occ.duplicate()
	other.tissue = tissue.duplicate()
	other.nut = nut.duplicate()
	other.bio = bio.duplicate()
	other.uid = uid.duplicate()
	other.ut = ut.duplicate()
	other.us = us.duplicate()
	other.uh = uh.duplicate()
	other.ua = ua.duplicate()
	other.ud = ud.duplicate()
	other.ur = ur.duplicate()
	other.ue = ue.duplicate()
	other.bonus = bonus
	other.infected_count = infected_count
	other.within = within
	other.open_core_d = open_core_d
	other._core_signature = _core_signature
	return other


func index_of(id: int) -> int:
	return uid.find(id)


func alive(u: int) -> bool:
	return uh[u] > 0.0


func count_side(side: int) -> int:
	var total := 0
	for u in uid.size():
		if us[u] == side and uh[u] > 0.0:
			total += 1
	return total


func d(a: int, b: int) -> int:
	return dist[a * n + b]


func nearest_unit_dist(tile: int, side: int) -> int:
	var best := 99
	for u in uid.size():
		if us[u] == side and uh[u] > 0.0:
			best = mini(best, d(tile, ut[u]))
	return best


func open_core_dist(tile: int) -> int:
	var signature := 0
	for c in core:
		if tissue[c] != Sim.Tissue.INFECTED and tissue[c] != Sim.Tissue.DESTROYED:
			signature = signature * 3 + 1 + c
	if signature != _core_signature or open_core_d.size() != n:
		_core_signature = signature
		open_core_d = PackedInt32Array()
		open_core_d.resize(n)
		for t in n:
			var best := 99
			for c in core:
				if tissue[c] != Sim.Tissue.INFECTED and tissue[c] != Sim.Tissue.DESTROYED:
					best = mini(best, d(t, c))
			open_core_d[t] = best
	return open_core_d[tile]


func core_infected() -> int:
	var total := 0
	for c in core:
		if tissue[c] == Sim.Tissue.INFECTED or tissue[c] == Sim.Tissue.DESTROYED:
			total += 1
	return total


## Bacteria-perspective score. Flip the sign for the immune side.
func raw_value() -> float:
	var v := bonus + core_infected() * 14.0
	v += infected_count * 0.5
	for u in uid.size():
		if uh[u] <= 0.0:
			continue
		if us[u] == Sim.BACTERIA:
			v += uh[u] * 2.0 + minf(ue[u], 6.0) * 0.25 - minf(open_core_dist(ut[u]), 12) * 0.35
		else:
			v -= uh[u] * 2.2
			v += minf(nearest_unit_dist(ut[u], Sim.BACTERIA), 6) * 0.25
	return v


func value(side: int) -> float:
	var v := raw_value()
	return v if side == Sim.BACTERIA else -v


func reach(u: int) -> Array:
	var tiles: Array = []
	var start := ut[u]
	var limit := ur[u]
	var list: PackedInt32Array = within[start]
	for tile in list:
		if occ[tile] == FREE and dist[start * n + tile] <= limit:
			tiles.append(tile)
	return tiles


func _tile_goal(u: int, tile: int) -> float:
	if us[u] == Sim.BACTERIA:
		var s := nut[tile] * 0.5 - minf(open_core_dist(tile), 12) * 0.3
		for next in nbr[tile]:
			if occ[next] == IMMUNE_OCC:
				s -= 0.9
		return s
	var near := 12.0
	if _focus_enemy >= 0:
		near = minf(d(tile, _focus_enemy), 12)
	return -near * 0.4 + (0.5 if tissue[tile] == Sim.Tissue.INFECTED else 0.0)


func candidates(u: int, limit := 4) -> Array:
	var list: Array = []
	if uh[u] <= 0.0:
		return list
	var own := ut[u]
	var tiles := reach(u)
	_focus_enemy = -1
	if us[u] == Sim.IMMUNE:
		var best_d := 99
		for other in uid.size():
			if us[other] == Sim.BACTERIA and uh[other] > 0.0 and d(own, ut[other]) < best_d:
				best_d = d(own, ut[other])
				_focus_enemy = ut[other]
	if us[u] == Sim.BACTERIA:
		var scored: Array = []
		for tile in tiles:
			scored.append([_tile_goal(u, tile), tile])
		scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for index in mini(limit, scored.size()):
			list.append([K_MOVE, scored[index][1], -1])
		var spots: Array = [own]
		spots.append_array(nbr[own])
		var infect_best := -1
		var infect_score := -INF
		for tile in spots:
			if tissue[tile] == Sim.Tissue.INFECTED or tissue[tile] == Sim.Tissue.DESTROYED:
				continue
			if occ[tile] != FREE and tile != own:
				continue
			var s := 5.0 - minf(open_core_dist(tile), 6) + (3.0 if core.has(tile) else 0.0)
			if s > infect_score:
				infect_score = s
				infect_best = tile
		if infect_best >= 0:
			list.append([K_INFECT, infect_best, -1])
		for other in uid.size():
			if us[other] == Sim.IMMUNE and uh[other] > 0.0 and d(own, ut[other]) == 1:
				list.append([K_ATTACK, own, other])
		if ue[u] >= 2.0 and bio[own] < Balance.MAX_BIOFILM:
			list.append([K_BIOFILM, own, -1])
		list.append([K_REST, own, -1])
	else:
		for other in uid.size():
			if us[other] != Sim.BACTERIA or uh[other] <= 0.0:
				continue
			var approach := -1
			var best_cost := 99
			if d(own, ut[other]) == 1:
				approach = own
				best_cost = 0
			for tile in tiles:
				if d(tile, ut[other]) == 1 and d(own, tile) < best_cost:
					best_cost = d(own, tile)
					approach = tile
			if approach >= 0:
				list.append([K_ATTACK, approach, other])
		var scored: Array = []
		for tile in tiles:
			scored.append([_tile_goal(u, tile), tile])
		scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for index in mini(limit - 1, scored.size()):
			list.append([K_MOVE, scored[index][1], -1])
		if count_side(Sim.IMMUNE) < cap_i:
			for next in nbr[own]:
				if occ[next] == FREE:
					list.append([K_CLONE, next, -1])
					break
	list.append([K_WAIT, own, -1])
	return list


func apply(u: int, cand: Array) -> void:
	nodes += 1
	var kind: int = cand[0]
	var tile: int = cand[1]
	var side := us[u]
	match kind:
		K_MOVE:
			occ[ut[u]] = FREE
			if side == Sim.BACTERIA:
				ue[u] = maxf(0.0, ue[u] - 0.25 * d(ut[u], tile))
			ut[u] = tile
			occ[tile] = BACT_OCC if side == Sim.BACTERIA else IMMUNE_OCC
		K_ATTACK:
			var target: int = cand[2]
			if tile != ut[u]:
				occ[ut[u]] = FREE
				ut[u] = tile
				occ[tile] = BACT_OCC if side == Sim.BACTERIA else IMMUNE_OCC
			if uh[target] <= 0.0:
				return
			var p: float
			var damage: float
			if side == Sim.IMMUNE:
				p = clampf(0.33 + 0.05 * ud[u] - 0.05 * ud[target], 0.15, 0.95)
				damage = maxf(0.5, 1.0 + (0.5 if ua[u] >= 6.0 else 0.0) - 0.4 * bio[ut[target]])
			else:
				p = clampf(0.28 + 0.05 * ua[u] - 0.04 * ua[target], 0.1, 0.8)
				damage = 1.0
			uh[target] -= p * damage
			if uh[target] <= 0.25:
				uh[target] = 0.0
				occ[ut[target]] = FREE
		K_INFECT:
			var p := clampf(0.3 + 0.06 * ua[u] + 0.1 * minf(1.0, nut[tile]) - 0.1 * _adjacent(tile, Sim.IMMUNE), 0.08, 0.95)
			var worth := 14.0 if core.has(tile) else 2.0
			if p >= 0.45:
				if tissue[tile] != Sim.Tissue.INFECTED:
					infected_count += 1
				tissue[tile] = Sim.Tissue.INFECTED
				ue[u] = minf(8.0, ue[u] + 2.0)
			else:
				bonus += p * worth
		K_CLONE:
			_add(-1, tile, Sim.IMMUNE, 4.0, ua[u], ud[u], ur[u], 0.0)
		K_BIOFILM:
			bio[tile] = mini(Balance.MAX_BIOFILM, bio[tile] + 1)
			ue[u] -= 2.0
			bonus += 0.6
		K_REST:
			ue[u] += 0.5


func _adjacent(tile: int, side: int) -> int:
	var total := 0
	for next in nbr[tile]:
		if occ[next] == (BACT_OCC if side == Sim.BACTERIA else IMMUNE_OCC):
			total += 1
	return total


## Cheap rollout policy: look at a handful of options rather than scoring every tile.
func policy_action(u: int, rng: RandomNumberGenerator, epsilon: float) -> Array:
	var own := ut[u]
	var side := us[u]
	if rng.randf() < epsilon:
		var spots: Array = nbr[own]
		if not spots.is_empty():
			var spot: int = spots[rng.randi() % spots.size()]
			if occ[spot] == FREE:
				return [K_MOVE, spot, -1]
		return [K_WAIT, own, -1]
	var enemy_side := Sim.other(side)
	var focus := -1
	var focus_d := 99
	for other in uid.size():
		if us[other] == enemy_side and uh[other] > 0.0:
			var dd := d(own, ut[other])
			if dd < focus_d:
				focus_d = dd
				focus = other
	if side == Sim.IMMUNE:
		if focus < 0:
			return [K_WAIT, own, -1]
		if focus_d == 1:
			return [K_ATTACK, own, focus]
		if focus_d <= ur[u] + 1:
			for tile in nbr[ut[focus]]:
				if occ[tile] == FREE and d(own, tile) <= ur[u]:
					return [K_ATTACK, tile, focus]
		if count_side(Sim.IMMUNE) < cap_i and rng.randf() < 0.3:
			for next in nbr[own]:
				if occ[next] == FREE:
					return [K_CLONE, next, -1]
		return _step_toward(u, ut[focus] if focus >= 0 else own, rng)
	if focus >= 0 and focus_d == 1 and uh[u] < 2.0 and rng.randf() < 0.5:
		return [K_ATTACK, own, focus]
	if tissue[own] != Sim.Tissue.INFECTED and tissue[own] != Sim.Tissue.DESTROYED and rng.randf() < 0.7:
		return [K_INFECT, own, -1]
	for next in nbr[own]:
		if core.has(next) and tissue[next] != Sim.Tissue.INFECTED and tissue[next] != Sim.Tissue.DESTROYED and rng.randf() < 0.7:
			return [K_INFECT, next, -1]
	if ue[u] >= 2.5 and rng.randf() < 0.4:
		return [K_REST, own, -1]
	var goal := own
	var goal_d := open_core_dist(own)
	for core_tile in core:
		if tissue[core_tile] != Sim.Tissue.INFECTED and tissue[core_tile] != Sim.Tissue.DESTROYED and d(own, core_tile) <= goal_d:
			goal = core_tile
			goal_d = d(own, core_tile)
	return _step_toward(u, goal, rng)


func _step_toward(u: int, goal: int, rng: RandomNumberGenerator) -> Array:
	var own := ut[u]
	var best := own
	var best_d := d(own, goal)
	var list: PackedInt32Array = within[own]
	var tries := 0
	for index in mini(list.size(), 40):
		var tile := list[rng.randi() % list.size()]
		tries += 1
		if occ[tile] == FREE and d(own, tile) <= ur[u]:
			var dd := d(tile, goal)
			if dd < best_d:
				best_d = dd
				best = tile
	if best == own:
		return [K_WAIT, own, -1]
	return [K_MOVE, best, -1]


func _quick_score(u: int, cand: Array) -> float:
	var kind: int = cand[0]
	var tile: int = cand[1]
	match kind:
		K_ATTACK:
			return 6.0 - (0.0 if us[u] == Sim.IMMUNE else 2.0)
		K_INFECT:
			return 5.0 + (3.0 if core.has(tile) else 0.0)
		K_MOVE:
			return 2.0 + _tile_goal(u, tile) * 0.3
		K_CLONE:
			return 3.0 if count_side(Sim.IMMUNE) < 4 else 1.0
		K_REST:
			return 1.5 if ue[u] >= 2.5 else 0.5
		K_BIOFILM:
			return 1.0
	return 0.0


## One full round of expected-value play for both sides, then growth.
func simulate_round(rng: RandomNumberGenerator, first: int, epsilon: float) -> void:
	var order := [first, Sim.other(first)]
	for side in order:
		var units: Array = []
		for u in uid.size():
			if us[u] == side and uh[u] > 0.0:
				units.append(u)
		units.shuffle()
		var allowed := ap_b if side == Sim.BACTERIA else ap_i
		for index in mini(allowed, units.size()):
			var u: int = units[index]
			if uh[u] > 0.0:
				apply(u, policy_action(u, rng, epsilon))
	for u in uid.size():
		if us[u] == Sim.BACTERIA and uh[u] > 0.0:
			ue[u] = minf(8.0, ue[u] + minf(0.6, nut[ut[u]]) * 1.2 - 0.25)
			nut[ut[u]] = maxf(0.0, nut[ut[u]] - 0.6)
			if ue[u] >= Balance.REPRO_COST and count_side(Sim.BACTERIA) < cap_b and rng.randf() < 0.6:
				for next in nbr[ut[u]]:
					if occ[next] == FREE:
						ue[u] -= Balance.REPRO_COST
						_add(-1, next, Sim.BACTERIA, 5.0, ua[u], ud[u], ur[u], 1.0)
						bonus += 0.4
						break
		if us[u] == Sim.BACTERIA and uh[u] > 0.0 and tissue[ut[u]] == Sim.Tissue.INFECTED:
			nut[ut[u]] = minf(2.0, nut[ut[u]] + 0.3)
