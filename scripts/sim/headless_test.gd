extends SceneTree
## Headless smoke test: godot --headless -s scripts/sim/headless_test.gd

func _initialize() -> void:
	var rows := 10
	var columns := 10
	var positions := PackedVector3Array()
	var adjacency: Array = []
	for tile in rows * columns:
		var row := tile / columns
		var col := tile % columns
		positions.append(Vector3(-9.5 + col * 2.0 + (1.0 if row % 2 else 0.0), 0.0, -7.7942286 + row * 1.7320508))
		adjacency.append(PackedInt32Array())
	for tile in rows * columns:
		var row := tile / columns
		var col := tile % columns
		var diagonal := col + (1 if row % 2 else -1)
		var links: Array = []
		if col + 1 < columns: links.append(tile + 1)
		if row + 1 < rows: links.append(tile + columns)
		if row + 1 < rows and diagonal >= 0 and diagonal < columns: links.append((row + 1) * columns + diagonal)
		for other in links:
			adjacency[tile].append(other)
			adjacency[other].append(tile)
	var results := {}
	for algo in [Sim.Algo.HYBRID, Sim.Algo.FUZZY, Sim.Algo.MINIMAX, Sim.Algo.MCTS, Sim.Algo.GREEDY]:
		var setup := GameSetup.new()
		setup.mode = Sim.Mode.AI_VS_AI
		setup.bact_ai = algo
		setup.immune_ai = algo
		setup.rng_seed = 7
		setup.max_rounds = 40
		var state := WorldBuilder.build(setup, adjacency, positions)
		var started := Time.get_ticks_msec()
		var decisions := 0
		while not state.finished:
			for team in [Sim.IMMUNE, Sim.BACTERIA]:
				var planner := AiPlanner.new()
				var slots := setup.immune_actions if team == Sim.IMMUNE else setup.bact_actions
				for _slot in slots:
					var best := planner.next_decision(state, team, setup.algo_for(team), func(_d): decisions += 1)
					if best == null:
						break
					var tiles: Array = [state.get_org(best.chosen.org).tile, best.chosen.to, best.chosen.target_tile]
					ActionExecutor.execute(state, best.chosen)
					planner.notify_executed(state, tiles)
					RoundRules.check_victory(state)
					if state.finished:
						break
				if state.finished:
					break
			if state.finished:
				break
			RoundRules.end_of_round(state)
			RoundRules.check_victory(state)
			printerr('  round ', state.round, ' b=', state.count_team(2), ' i=', state.count_team(1), ' ms=', Time.get_ticks_msec() - started)
		results[Sim.ALGO_NAMES[algo]] = "%s | rounds %d | bact %d immune %d core %d/7 | %d decisions %d ms" % [
			state.result_text, state.round, state.count_team(Sim.BACTERIA), state.count_team(Sim.IMMUNE),
			state.core_infected(), decisions, Time.get_ticks_msec() - started]
	for key in results:
		printerr(key, ": ", results[key])
	quit()
