class_name Mcts
extends RefCounted
## Monte Carlo Tree Search over a LightState: root action, a follow-up layer, then random rollouts.

const ROLLOUT_ROUNDS := 2
const EXPLORATION := 1.1


## Returns {"values": Array[float] (mean reward per candidate, 0..1), "nodes": int, "sims": int}.
static func search(state: LightState, u: int, cands: Array, simulations: int, rng: RandomNumberGenerator) -> Dictionary:
	var me := state.us[u]
	var visits := PackedInt32Array()
	var totals := PackedFloat32Array()
	visits.resize(cands.size())
	totals.resize(cands.size())
	var second: Array = []
	for _i in cands.size():
		second.append({})
	var nodes := 1 + cands.size()
	var baseline := state.value(me)
	for sim in simulations:
		var pick := 0
		var best_ucb := -INF
		for index in cands.size():
			var ucb := INF
			if visits[index] > 0:
				ucb = totals[index] / visits[index] + EXPLORATION * sqrt(log(sim + 1.0) / visits[index])
			if ucb > best_ucb:
				best_ucb = ucb
				pick = index
		var sandbox := state.copy()
		sandbox.apply(u, cands[pick])
		sandbox.simulate_round(rng, Sim.other(me), 0.25)
		var follow := sandbox.candidates(u, 3)
		if not follow.is_empty() and sandbox.uh[u] > 0.0:
			var table: Dictionary = second[pick]
			var chosen: Array = follow[0]
			var chosen_key := ""
			var best_follow := -INF
			for option in follow:
				var key := "%d:%d" % [option[0], option[1]]
				var entry: Array = table.get(key, [0, 0.0])
				var score: float = INF if entry[0] == 0 else entry[1] / entry[0] + 0.8 * sqrt(log(sim + 2.0) / entry[0])
				if score > best_follow:
					best_follow = score
					chosen = option
					chosen_key = key
			if not table.has(chosen_key):
				table[chosen_key] = [0, 0.0]
				nodes += 1
			sandbox.apply(u, chosen)
			var reward := _rollout(sandbox, me, rng, baseline)
			table[chosen_key][0] += 1
			table[chosen_key][1] += reward
			visits[pick] += 1
			totals[pick] += reward
		else:
			visits[pick] += 1
			totals[pick] += _rollout(sandbox, me, rng, baseline)
	var values: Array = []
	for index in cands.size():
		values.append(totals[index] / visits[index] if visits[index] > 0 else 0.5)
	return {"values": values, "nodes": nodes, "sims": simulations}


static func _rollout(state: LightState, me: int, rng: RandomNumberGenerator, baseline: float) -> float:
	state.simulate_round(rng, Sim.other(me), 0.3)
	for _round in ROLLOUT_ROUNDS - 1:
		state.simulate_round(rng, me, 0.3)
	return 0.5 + 0.5 * tanh((state.value(me) - baseline) / 12.0)
