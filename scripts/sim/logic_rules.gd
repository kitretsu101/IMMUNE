class_name LogicRules
extends RefCounted
## Propositional logic: which actions are legally possible for an organism right now.
## Each proposition is a named boolean; a legal action is a conjunction of them.


## Truth table for an organism. Used for legality and shown in the AI decision log.
static func propositions(state: WorldState, organism: Organism) -> Dictionary:
	var props := {}
	var enemy := Sim.other(organism.team)
	var reach := Pathing.bfs_reach(state, organism.tile, organism.move_range, organism.id)
	props["_reach"] = reach
	var free_tiles := 0
	for tile in reach:
		if tile != organism.tile and state.occupant[tile] == 0:
			free_tiles += 1
	props["alive"] = organism.alive
	props["can_act"] = organism.alive and not organism.acted
	props["can_move"] = free_tiles > 0
	props["enemy_adjacent"] = false
	for next in state.neighbors[organism.tile]:
		var neighbor := state.org_at(next)
		if neighbor != null and neighbor.team == enemy:
			props["enemy_adjacent"] = true
	var attacks := attack_options(state, organism, reach)
	props["_attacks"] = attacks
	props["enemy_reachable"] = not attacks.is_empty()
	if organism.team == Sim.BACTERIA:
		props["has_energy"] = organism.energy >= Balance.BIOFILM_COST
		props["infectable_target"] = not infect_targets(state, organism).is_empty()
		props["biofilm_room"] = state.biofilm[organism.tile] < Balance.MAX_BIOFILM
		props["room_to_grow"] = state.count_team(Sim.BACTERIA) < state.setup.bact_cap
	else:
		props["room_to_clone"] = state.count_team(Sim.IMMUNE) < state.setup.immune_cap \
				and organism.energy >= Balance.CLONE_COST \
				and not state.free_neighbors(organism.tile).is_empty()
	return props


static func infect_targets(state: WorldState, organism: Organism) -> Array:
	var targets: Array = []
	var candidates: Array = [organism.tile]
	candidates.append_array(state.neighbors[organism.tile])
	for tile in candidates:
		if Balance.infectable(state, organism, tile):
			var occupant := state.org_at(tile)
			if occupant == null or occupant == organism:
				targets.append(tile)
	return targets


## Attack options as [target_organism, approach_tile] pairs, best approach tile first.
static func attack_options(state: WorldState, organism: Organism, reach: Dictionary) -> Array:
	var options: Array = []
	var enemy := Sim.other(organism.team)
	var reach_limit := organism.move_range
	for target in state.living(enemy):
		var best_tile := -1
		var best_cost := 999
		if reach_limit == 0:
			if state.distance(organism.tile, target.tile) == 1:
				best_tile = organism.tile
		else:
			for tile in reach:
				if state.distance(tile, target.tile) == 1:
					var cost := state.distance(organism.tile, tile) * 2 - state.units_within(tile, enemy, 1)
					if cost < best_cost:
						best_cost = cost
						best_tile = tile
		if best_tile >= 0:
			options.append([target, best_tile])
	return options


## All legal actions for an organism. Immune clone is included once per free neighbour.
static func legal_actions(state: WorldState, organism: Organism, props := {}) -> Array:
	if props.is_empty():
		props = propositions(state, organism)
	var actions: Array = []
	if not props.can_act:
		return actions
	var reach: Dictionary = props["_reach"]
	for tile in reach:
		if tile != organism.tile and state.occupant[tile] == 0 and props.can_move:
			var move := SimAction.make(Sim.Kind.MOVE, organism.id, tile)
			move.path = Pathing.path_from_parents(reach, organism.tile, tile)
			actions.append(move)
	for pair in props["_attacks"]:
		var attack := SimAction.make(Sim.Kind.ATTACK, organism.id, pair[1])
		attack.target_org = pair[0].id
		attack.target_tile = pair[0].tile
		attack.path = Pathing.path_from_parents(reach, organism.tile, pair[1])
		actions.append(attack)
	if organism.team == Sim.BACTERIA:
		for tile in infect_targets(state, organism):
			var infect := SimAction.make(Sim.Kind.INFECT, organism.id, tile)
			infect.target_tile = tile
			actions.append(infect)
		if props.has_energy and props.biofilm_room:
			actions.append(SimAction.make(Sim.Kind.BIOFILM, organism.id, organism.tile))
		if props.room_to_grow:
			actions.append(SimAction.make(Sim.Kind.REPRODUCE, organism.id, organism.tile))
	elif props.room_to_clone:
		for tile in state.free_neighbors(organism.tile):
			actions.append(SimAction.make(Sim.Kind.CLONE, organism.id, tile))
	actions.append(SimAction.make(Sim.Kind.WAIT, organism.id, organism.tile))
	return actions


static func explain(props: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in props:
		if key.begins_with("_"):
			continue
		parts.append("%s%s" % ["" if props[key] else "¬", key])
	return " ∧ ".join(parts)
