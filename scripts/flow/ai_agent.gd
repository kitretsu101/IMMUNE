class_name AiAgent
extends Node
## One side's artificial player. Hosts the decision pipeline for its team and its own decision cache.

@export var team := Sim.BACTERIA
## -1 uses the algorithm chosen in the game setup.
@export_enum("From setup:-1", "Hybrid:0", "Fuzzy Logic:1", "Minimax:2", "MCTS:3", "Greedy:4") var algorithm_override := -1
@export_range(1, 40) var budget_ms := 10

var planner := AiPlanner.new()


func reset() -> void:
	planner.reset()


func algorithm(state: WorldState) -> int:
	return algorithm_override if algorithm_override >= 0 else state.setup.algo_for(team)


## Best (organism, action) for this side right now, or null when nothing can act.
func choose(state: WorldState) -> Decision:
	var algo := algorithm(state)
	var best: Decision = null
	var slice_start := Time.get_ticks_msec()
	for organism in state.living(team):
		if organism.acted:
			continue
		var decision := planner.decision_for(state, organism, algo)
		if best == null or decision.chosen.score > best.chosen.score:
			best = decision
		if Time.get_ticks_msec() - slice_start > budget_ms and not Config.unlimited_speed:
			await get_tree().process_frame
			slice_start = Time.get_ticks_msec()
	return best


func executed(state: WorldState, tiles: Array) -> void:
	planner.notify_executed(state, tiles)
