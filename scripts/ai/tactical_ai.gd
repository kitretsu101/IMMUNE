class_name TacticalAI
extends RefCounted
## Combined decision architecture. Pipeline for the Hybrid algorithm:
##   propositional logic -> BFS reach -> A* routes -> fuzzy priorities -> minimax -> MCTS.

const SHORTLIST := 4
const FINALISTS := 3


static func decide(state: WorldState, organism: Organism, algo: int) -> Decision:
	var started := Time.get_ticks_usec()
	var decision := Decision.new()
	decision.org_id = organism.id
	decision.team = organism.team
	decision.round_number = state.round
	decision.algorithm = Sim.ALGO_NAMES[algo]
	var props := LogicRules.propositions(state, organism)
	decision.propositions = LogicRules.explain(props)
	decision.pipeline.append("logic")
	var legal := LogicRules.legal_actions(state, organism, props)
	decision.pipeline.append("BFS reach")
	if legal.size() <= 1:
		decision.chosen = legal[0] if legal.size() == 1 else SimAction.make(Sim.Kind.WAIT, organism.id, organism.tile)
		decision.scores = {decision.chosen.label(): 0.5}
		decision.time_ms = (Time.get_ticks_usec() - started) / 1000.0
		return decision
	var context := _context(state, organism)
	if algo != Sim.Algo.GREEDY:
		_add_astar_candidate(state, organism, legal, context)
		decision.pipeline.append("A*")
	decision.priorities = context.priorities
	decision.pipeline.append("fuzzy")
	var rows: Array = []
	for action in legal:
		var fuzzy := _fuzzy_score(state, organism, action, context)
		rows.append({"action": action, "fuzzy": fuzzy, "minimax": null, "mcts": null,
				"final": fuzzy + state.rng.randf() * 0.02})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fuzzy > b.fuzzy)
	if algo in [Sim.Algo.MINIMAX, Sim.Algo.MCTS, Sim.Algo.HYBRID]:
		_search_stage(state, organism, algo, rows, decision)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.final > b.final)
	decision.chosen = rows[0].action
	decision.chosen.score = rows[0].final
	for row in rows:
		var label: String = row.action.label()
		var value := _squash(row.final)
		if value > decision.scores.get(label, -1.0):
			decision.scores[label] = value
	decision.candidates = rows.slice(0, 8)
	decision.time_ms = (Time.get_ticks_usec() - started) / 1000.0
	return decision


static func _squash(x: float) -> float:
	return 1.0 / (1.0 + exp(-3.0 * (x - 0.5)))


static func _search_stage(state: WorldState, organism: Organism, algo: int, rows: Array, decision: Decision) -> void:
	var light := LightState.from_world(state)
	var unit := light.index_of(organism.id)
	if unit < 0:
		return
	var depth := state.setup.search_depth
	var sims := state.setup.mcts_sims
	var shortlist := rows.slice(0, SHORTLIST if algo != Sim.Algo.MCTS else SHORTLIST + 2)
	var minimax_weight := 0.0
	var mcts_weight := 0.0
	var fuzzy_weight := 1.0
	if algo == Sim.Algo.MINIMAX or algo == Sim.Algo.HYBRID:
		decision.pipeline.append("minimax d%d" % depth)
		var values: Array = []
		for row in shortlist:
			var result := Minimax.evaluate_root(light, unit, _to_light(light, row.action), depth)
			row.minimax = result.value
			values.append(result.value)
			decision.nodes += result.nodes
		_normalise(shortlist, "minimax")
	if algo == Sim.Algo.MCTS or algo == Sim.Algo.HYBRID:
		decision.pipeline.append("MCTS x%d" % sims)
		var finalists := shortlist
		if algo == Sim.Algo.HYBRID:
			for row in shortlist:
				row.final = 0.5 * row.fuzzy + 0.5 * (row.minimax if row.minimax != null else 0.5)
			finalists = shortlist.duplicate()
			finalists.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.final > b.final)
			finalists = finalists.slice(0, FINALISTS)
		var cands: Array = []
		for row in finalists:
			cands.append(_to_light(light, row.action))
		var result := Mcts.search(light, unit, cands, sims, state.rng)
		for index in finalists.size():
			finalists[index].mcts = result.values[index]
		decision.nodes += result.nodes
		decision.simulations = result.sims
	var fuzzy_norm := _normalised_values(shortlist, "fuzzy")
	for index in shortlist.size():
		var row: Dictionary = shortlist[index]
		var total: float = fuzzy_norm[index] * 0.3
		var weight := 0.3
		if row.minimax != null:
			total += row.minimax * 0.7
			weight += 0.7
		if row.mcts != null:
			total += row.mcts * (0.9 if algo == Sim.Algo.MCTS else 0.6)
			weight += 0.9 if algo == Sim.Algo.MCTS else 0.6
		row.final = total / weight + state.rng.randf() * 0.01
	for row in rows:
		if not shortlist.has(row):
			row.final = minf(row.fuzzy, 0.2) - 0.2


static func _normalised_values(rows: Array, key: String) -> Array:
	var low := INF
	var high := -INF
	for row in rows:
		low = minf(low, row[key])
		high = maxf(high, row[key])
	var out: Array = []
	for row in rows:
		out.append(0.5 if high - low < 0.0001 else (row[key] - low) / (high - low))
	return out


static func _normalise(rows: Array, key: String) -> void:
	var values := _normalised_values(rows, key)
	for index in rows.size():
		rows[index][key] = values[index]


static func _to_light(light: LightState, action: SimAction) -> Array:
	match action.kind:
		Sim.Kind.MOVE:
			return [LightState.K_MOVE, action.to, -1]
		Sim.Kind.ATTACK:
			return [LightState.K_ATTACK, action.to, light.index_of(action.target_org)]
		Sim.Kind.INFECT:
			return [LightState.K_INFECT, action.target_tile, -1]
		Sim.Kind.CLONE:
			return [LightState.K_CLONE, action.to, -1]
		Sim.Kind.BIOFILM:
			return [LightState.K_BIOFILM, action.to, -1]
		Sim.Kind.REPRODUCE:
			return [LightState.K_REST, action.to, -1]
	return [LightState.K_WAIT, action.to, -1]


# --- Fuzzy evaluation -----------------------------------------------------------------------

static func _context(state: WorldState, organism: Organism) -> Dictionary:
	var enemy := Sim.other(organism.team)
	var enemy_dist := state.team_dist(enemy)
	var danger := PackedFloat32Array()
	danger.resize(state.count)
	for tile in state.count:
		var d := enemy_dist[tile]
		danger[tile] = 2.5 if d <= 1 else (1.0 if d == 2 else 0.0)
	var context := {"danger": danger, "enemy_dist": enemy_dist, "open_core": state.open_core_dist()}
	var nearest_enemy := enemy_dist[organism.tile]
	context["nearest_enemy"] = nearest_enemy
	if organism.team == Sim.BACTERIA:
		var threat := clampf(1.0 - (nearest_enemy - 1.0) / 4.0, 0.0, 1.0)
		var best_open := 0.0
		for tile in LogicRules.infect_targets(state, organism):
			var value := Balance.infect_chance(state, organism, tile) * (1.5 if state.core.has(tile) else 0.7)
			best_open = maxf(best_open, value)
		var near_nutrient := state.nutrients[organism.tile]
		for next in state.neighbors[organism.tile]:
			near_nutrient = maxf(near_nutrient, state.nutrients[next])
		context["priorities"] = Fuzzy.bacterium_priorities(
			organism.health / organism.max_health, clampf(organism.energy / 6.0, 0.0, 1.0), threat,
			clampf(near_nutrient / 1.5, 0.0, 1.0), clampf(best_open, 0.0, 1.0), state.antibiotic,
			float(state.count_team(Sim.BACTERIA)) / state.setup.bact_cap)
		context["threat"] = threat
		context["open_core_now"] = state.open_core_dist()[organism.tile]
	else:
		var core_gap := 99
		var core_prox := state.core_prox()
		for bacterium in state.living(Sim.BACTERIA):
			core_gap = mini(core_gap, core_prox[bacterium.tile])
		var core_threat := clampf(1.0 - core_gap / 5.0, 0.0, 1.0)
		var enemy_near := clampf(1.0 - (nearest_enemy - 1.0) / 6.0, 0.0, 1.0)
		var gap := clampf((state.count_team(Sim.BACTERIA) - state.count_team(Sim.IMMUNE) + 2.0) / 6.0, 0.0, 1.0)
		context["priorities"] = Fuzzy.immune_priorities(organism.health / organism.max_health, core_threat, enemy_near, gap)
	return context


static func _open_core_dist(state: WorldState, tile: int) -> int:
	var best := 99
	for core_tile in state.core:
		if state.tissue[core_tile] != Sim.Tissue.INFECTED and state.tissue[core_tile] != Sim.Tissue.DESTROYED:
			best = mini(best, state.distance(tile, core_tile))
	return best


static func _core_proximity(state: WorldState, tile: int) -> float:
	return clampf(1.0 - state.core_prox()[tile] / 6.0, 0.0, 1.0)


static func _fuzzy_score(state: WorldState, organism: Organism, action: SimAction, context: Dictionary) -> float:
	var prio: Dictionary = context.priorities
	var danger: PackedFloat32Array = context.danger
	if organism.team == Sim.BACTERIA:
		return _score_bacterium(state, organism, action, context, prio, danger)
	return _score_immune(state, organism, action, context, prio, danger)


static func _score_bacterium(state: WorldState, organism: Organism, action: SimAction, context: Dictionary,
		prio: Dictionary, danger: PackedFloat32Array) -> float:
	var growth: float = prio.growth
	var survival: float = prio.survival
	var infection: float = prio.infection
	match action.kind:
		Sim.Kind.MOVE:
			var tile := action.to
			var s := growth * (state.nutrients[tile] / 2.0 + 0.06 * state.chem_bact[tile])
			s += infection * 0.3 * (context.open_core_now - context.open_core[tile]) / 2.0
			s -= (0.15 + 0.3 * survival) * danger[tile]
			s += survival * 0.2 * state.biofilm[tile]
			s += 0.18 if action.detail == "A*" else 0.0
			return s - 0.04
		Sim.Kind.INFECT:
			var p := Balance.infect_chance(state, organism, action.target_tile)
			var worth := 0.6 + (1.0 if state.core.has(action.target_tile) else 0.0)
			return infection * p * worth + 0.15 * growth * p - 0.2 * survival * context.threat * (1.0 - p)
		Sim.Kind.ATTACK:
			var target := state.get_org(action.target_org)
			return 0.15 + survival * Balance.hit_chance(organism, target) * 0.9 - (1.0 - organism.health / organism.max_health) * 0.2
		Sim.Kind.BIOFILM:
			return survival * 0.7 * maxf(context.threat, state.antibiotic) - growth * 0.35 + 0.05
		Sim.Kind.REPRODUCE:
			return growth * clampf(organism.energy / 3.0, 0.0, 1.0) * (0.9 if organism.energy >= Balance.REPRO_COST else 0.45)
	return 0.05 - survival * 0.1


static func _score_immune(state: WorldState, organism: Organism, action: SimAction, context: Dictionary,
		prio: Dictionary, danger: PackedFloat32Array) -> float:
	var defend: float = prio.defend
	var hunt: float = prio.hunt
	var expand: float = prio.expand
	match action.kind:
		Sim.Kind.ATTACK:
			var target := state.get_org(action.target_org)
			var p := Balance.hit_chance(organism, target)
			var damage := Balance.damage(organism, target, state.biofilm[target.tile])
			var kill := 0.5 if target.health <= damage else 0.0
			var proximity := _core_proximity(state, target.tile)
			return hunt * (p * (0.9 + kill) + 0.3 * proximity) + 0.15 * defend * proximity
		Sim.Kind.MOVE:
			var tile := action.to
			var now: int = context.nearest_enemy
			var after: int = context.enemy_dist[tile]
			var s := hunt * 0.28 * (now - after)
			if state.tissue[tile] == Sim.Tissue.INFECTED and state.org_at(tile) == null:
				s += 0.3 + 0.2 * defend
			s += defend * 0.25 * (_core_proximity(state, tile) - _core_proximity(state, organism.tile))
			s -= 0.05 * danger[tile]
			return s - 0.04
		Sim.Kind.CLONE:
			return expand * 0.7 + 0.05
	return 0.04


## Adds a MOVE candidate that follows an A* route toward the strategic goal (or tags an existing one).
static func _add_astar_candidate(state: WorldState, organism: Organism, legal: Array, context: Dictionary) -> void:
	var goal := -1
	var best := 9999
	if organism.team == Sim.BACTERIA:
		if organism.energy < 2.0:
			var richest := -1.0
			for tile in state.count:
				if state.active[tile] == 1 and state.nutrients[tile] - 0.15 * state.distance(organism.tile, tile) > richest:
					richest = state.nutrients[tile] - 0.15 * state.distance(organism.tile, tile)
					goal = tile
		else:
			for tile in state.core:
				if state.tissue[tile] != Sim.Tissue.INFECTED and state.tissue[tile] != Sim.Tissue.DESTROYED:
					var d := state.distance(organism.tile, tile)
					if d < best:
						best = d
						goal = tile
	else:
		for bacterium in state.living(Sim.BACTERIA):
			var d := state.distance(organism.tile, bacterium.tile)
			if d < best:
				best = d
				goal = bacterium.tile
		if goal < 0:
			for tile in state.count:
				if state.tissue[tile] == Sim.Tissue.INFECTED and state.distance(organism.tile, tile) < best:
					best = state.distance(organism.tile, tile)
					goal = tile
	if goal < 0 or goal == organism.tile:
		return
	var route := Pathing.astar(state, organism.tile, goal, context.danger)
	if route.is_empty():
		return
	var reachable := {}
	for action in legal:
		if action.kind == Sim.Kind.MOVE:
			reachable[action.to] = action
	var step_target := -1
	for step in route.size():
		if reachable.has(route[step]):
			step_target = route[step]
	if step_target >= 0:
		reachable[step_target].detail = "A*"
