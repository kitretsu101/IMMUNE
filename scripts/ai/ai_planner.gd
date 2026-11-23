class_name AiPlanner
extends RefCounted
## Picks the next (organism, action) for one side. Decisions are cached per organism and only
## recomputed when something changed near them, so a round costs about one decision per organism.

var cache: Dictionary = {}
var stale_radius := 3


func reset() -> void:
	cache.clear()


## Returns the best Decision among organisms that have not acted yet, or null if none can act.
func next_decision(state: WorldState, team: int, algo: int, on_decision := Callable()) -> Decision:
	var best: Decision = null
	for organism in state.living(team):
		if organism.acted:
			continue
		var decision: Decision = cache.get(organism.id)
		if decision == null or not _still_valid(state, organism, decision):
			decision = TacticalAI.decide(state, organism, algo)
			cache[organism.id] = decision
			if on_decision.is_valid():
				on_decision.call(decision)
		if best == null or decision.chosen.score > best.chosen.score:
			best = decision
	return best


func notify_executed(state: WorldState, changed_tiles: Array) -> void:
	for id in cache.keys():
		var organism := state.get_org(id)
		var decision: Decision = cache[id]
		if organism == null:
			cache.erase(id)
			continue
		for tile in changed_tiles:
			if state.distance(organism.tile, tile) <= stale_radius:
				cache.erase(id)
				break


func _still_valid(state: WorldState, organism: Organism, decision: Decision) -> bool:
	return decision.round_number == state.round and decision.chosen.org == organism.id


func decision_for(state: WorldState, organism: Organism, algo: int) -> Decision:
	var decision: Decision = cache.get(organism.id)
	if decision == null or not _still_valid(state, organism, decision):
		decision = TacticalAI.decide(state, organism, algo)
		cache[organism.id] = decision
	return decision
