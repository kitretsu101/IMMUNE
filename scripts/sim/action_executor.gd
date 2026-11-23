class_name ActionExecutor
extends RefCounted
## Applies a chosen action to the world and reports what happened as events.

const MAX_ENERGY := 8.0


static func execute(state: WorldState, action: SimAction) -> Array:
	var events: Array = []
	var organism := state.get_org(action.org)
	if organism == null or not organism.alive:
		return events
	organism.acted = true
	organism.current_action = action.label()
	organism.current_target = "-"
	match action.kind:
		Sim.Kind.MOVE:
			_move(state, organism, action, events)
		Sim.Kind.ATTACK:
			_attack(state, organism, action, events)
		Sim.Kind.INFECT:
			_infect(state, organism, action, events)
		Sim.Kind.CLONE:
			_clone(state, organism, action, events)
		Sim.Kind.BIOFILM:
			_biofilm(state, organism, events)
		Sim.Kind.REPRODUCE:
			organism.add_effect("Resting", 2, 1.3)
			organism.energy = minf(MAX_ENERGY, organism.energy + 0.5)
			organism.current_target = "colony growth"
			events.append(Ev.make("rest", "Reproduction",
				"%s rests and gathers resources to reproduce." % organism.label(), state.round,
				{"org": organism.id, "tile": organism.tile, "team": organism.team}))
		_:
			events.append(Ev.make("wait", "Movement", "%s holds position." % organism.label(),
				state.round, {"org": organism.id, "tile": organism.tile, "team": organism.team}))
	return events


static func _move(state: WorldState, organism: Organism, action: SimAction, events: Array) -> void:
	var from_tile := organism.tile
	organism.current_target = Ev.at(action.to)
	state.move_organism(organism, action.to)
	if organism.team == Sim.BACTERIA:
		organism.energy = maxf(0.0, organism.energy - 0.25 * action.path.size())
	var pickup := 0.0
	if organism.team == Sim.BACTERIA and state.nutrients[action.to] >= 0.4:
		pickup = minf(1.2, state.nutrients[action.to])
		state.nutrients[action.to] -= pickup
		organism.energy = minf(MAX_ENERGY, organism.energy + pickup * 1.4)
	events.append(Ev.make("move", "Movement",
		"%s moved to %s." % [organism.label(), Ev.at(action.to)], state.round,
		{"org": organism.id, "tile": from_tile, "tile2": action.to, "path": action.path, "team": organism.team}))
	if pickup > 0.0:
		events.append(Ev.make("pickup", "Environment", "%s picked up nutrients (+%.1f energy)." % [organism.label(), pickup * 1.4],
			state.round, {"org": organism.id, "tile": action.to, "team": Sim.BACTERIA}))


static func _attack(state: WorldState, organism: Organism, action: SimAction, events: Array) -> void:
	if action.to != organism.tile and action.to >= 0:
		_move(state, organism, action, events)
	var target := state.get_org(action.target_org)
	if target == null or not target.alive or state.distance(organism.tile, target.tile) != 1:
		return
	organism.current_target = "#%d" % target.id
	var immune_attacker := organism.team == Sim.IMMUNE
	var chance := Balance.hit_chance(organism, target) if immune_attacker else Balance.bacteria_hit_chance(organism, target)
	var hit := state.rng.randf() < chance
	var base := {"org": organism.id, "other": target.id, "tile": organism.tile, "tile2": target.tile, "team": organism.team}
	if not hit:
		events.append(Ev.make("attack_miss", "Combat",
			"%s attacked %s and missed (%d%%)." % [organism.label(), target.label(), roundi(chance * 100.0)],
			state.round, base))
		return
	var damage := Balance.immune_damage(organism, target, state.biofilm[target.tile]) if immune_attacker else 1.0
	target.health -= damage
	events.append(Ev.make("attack_hit", "Combat",
		"%s hit %s for %.1f damage." % [organism.label(), target.label(), damage], state.round,
		base.merged({"damage": damage})))
	if target.health <= 0.0:
		_kill(state, organism, target, events)


static func _kill(state: WorldState, killer: Organism, victim: Organism, events: Array) -> void:
	killer.kills += 1
	var tile := victim.tile
	state.remove_organism(victim)
	var is_bacterium := victim.team == Sim.BACTERIA
	if is_bacterium:
		state.stats.eliminations += 1
		killer.memory[victim.antigen] = mini(3, int(killer.memory.get(victim.antigen, 0)) + 1)
		events.append(Ev.make("memory", "Combat",
			"%s formed immune memory against antigen %s." % [killer.label(), victim.antigen_name()],
			state.round, {"org": killer.id, "tile": killer.tile, "team": Sim.IMMUNE, "antigen": victim.antigen, "level": killer.memory[victim.antigen]}))
	events.append(Ev.make("death", "Death", "%s eliminated by %s." % [victim.label(), killer.label()],
		state.round, {"org": victim.id, "other": killer.id, "tile": tile, "team": victim.team,
			"victim_team": victim.team, "sev": Ev.NOTABLE}))


static func _infect(state: WorldState, organism: Organism, action: SimAction, events: Array) -> void:
	var tile := action.target_tile
	organism.current_target = "tissue " + Ev.at(tile)
	var chance := Balance.infect_chance(state, organism, tile)
	var base := {"org": organism.id, "tile": organism.tile, "tile2": tile, "team": Sim.BACTERIA}
	events.append(Ev.make("infect_try", "Infection",
		"%s attempts infection at %s (%d%%)." % [organism.label(), Ev.at(tile), roundi(chance * 100.0)],
		state.round, base))
	if state.rng.randf() < chance:
		var was_rival := state.tissue[tile] == Sim.Tissue.INFECTED
		state.tissue[tile] = Sim.Tissue.INFECTED
		state.tissue_strain[tile] = organism.strain
		state.tissue_timer[tile] = 0
		organism.energy = minf(MAX_ENERGY, organism.energy + 2.0)
		var core_hit := state.core.has(tile)
		events.append(Ev.make("infect_ok", "Infection",
			"%s infected %s%s." % [organism.label(), "core tissue " if core_hit else "tissue ", Ev.at(tile)]
				if not was_rival else "%s took over rival-infected tissue %s." % [organism.label(), Ev.at(tile)],
			state.round, base.merged({"sev": Ev.NOTABLE, "core": core_hit})))
	else:
		organism.energy = maxf(0.0, organism.energy - 0.3)
		events.append(Ev.make("infect_fail", "Infection",
			"%s failed to infect %s." % [organism.label(), Ev.at(tile)], state.round, base))


static func _clone(state: WorldState, organism: Organism, action: SimAction, events: Array) -> void:
	var result := Evolution.clone_immune(state, organism, action.to)
	organism.current_target = Ev.at(action.to)
	events.append(Ev.make("clone", "Reproduction", result.text, state.round,
		{"org": organism.id, "other": result.child.id, "tile": organism.tile, "tile2": action.to,
		"team": Sim.IMMUNE, "sev": Ev.NOTABLE if result.changed else Ev.INFO}))


static func _biofilm(state: WorldState, organism: Organism, events: Array) -> void:
	organism.energy -= Balance.BIOFILM_COST
	state.biofilm[organism.tile] = mini(Balance.MAX_BIOFILM, state.biofilm[organism.tile] + 1)
	organism.add_effect("BiofilmCost", 3, Balance.REPRO_TEMP_PENALTY)
	organism.current_target = "biofilm"
	events.append(Ev.make("biofilm", "Environment",
		"%s invested in biofilm at %s (level %d) — reproduction slowed." % [
			organism.label(), Ev.at(organism.tile), state.biofilm[organism.tile]],
		state.round, {"org": organism.id, "tile": organism.tile, "team": Sim.BACTERIA}))
