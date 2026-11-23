class_name ExperimentRunner
extends Node
## Runs many AI-vs-AI matches with no rendering and reports aggregate results.

signal progress(done: int, total: int)
signal finished(summary: Dictionary)

var running := false
var _cancel := false


func cancel() -> void:
	_cancel = true


func run(base: GameSetup, runs: int) -> void:
	running = true
	_cancel = false
	var adjacency := BoardTopology.adjacency()
	var positions := BoardTopology.positions()
	var wins := {Sim.IMMUNE: 0, Sim.BACTERIA: 0, Sim.NONE: 0}
	var total_rounds := 0
	var peak := 0
	var mutations := 0
	var core := 0
	var latency := 0.0
	var decisions := 0
	var done := 0
	for index in runs:
		if _cancel:
			break
		var setup := GameSetup.from_dict(base.to_dict())
		setup.mode = Sim.Mode.AI_VS_AI
		setup.rng_seed = (base.rng_seed + index + 1) if base.rng_seed != 0 else 0
		var state := WorldBuilder.build(setup, adjacency, positions)
		var immune_planner := AiPlanner.new()
		var bacteria_planner := AiPlanner.new()
		while not state.finished:
			for team in [Sim.IMMUNE, Sim.BACTERIA]:
				var planner := immune_planner if team == Sim.IMMUNE else bacteria_planner
				planner.reset()
				var slots := setup.immune_actions if team == Sim.IMMUNE else setup.bact_actions
				for _slot in slots:
					var best: Decision = null
					for organism in state.living(team):
						if organism.acted:
							continue
						var decision := planner.decision_for(state, organism, setup.algo_for(team))
						if best == null or decision.chosen.score > best.chosen.score:
							best = decision
					if best == null:
						break
					latency += best.time_ms
					decisions += 1
					var origin := state.get_org(best.chosen.org).tile
					ActionExecutor.execute(state, best.chosen)
					planner.notify_executed(state, [origin, best.chosen.to, best.chosen.target_tile])
					RoundRules.check_victory(state)
					if state.finished:
						break
				if state.finished:
					break
			if state.finished:
				break
			RoundRules.end_of_round(state)
			RoundRules.check_victory(state)
			await get_tree().process_frame
		wins[state.winner] += 1
		total_rounds += state.round
		peak += state.stats.bact_peak
		mutations += state.stats.mutations
		core += state.core_infected()
		done += 1
		progress.emit(done, runs)
		await get_tree().process_frame
	running = false
	var n := maxf(1.0, done)
	var summary := {
		"runs": done, "immune_wins": wins[Sim.IMMUNE], "bacteria_wins": wins[Sim.BACTERIA], "draws": wins[Sim.NONE],
		"avg_rounds": total_rounds / n, "avg_peak_bacteria": peak / n, "avg_mutations": mutations / n,
		"avg_core_infected": core / n, "avg_latency_ms": latency / maxf(1.0, decisions),
		"bact_ai": base.bact_ai, "immune_ai": base.immune_ai, "date": Time.get_datetime_string_from_system(false, true),
	}
	finished.emit(summary)
