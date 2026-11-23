class_name Evolution
extends RefCounted
## Inheritance and mutation for offspring and immune clones.

const BACTERIA_TRAITS := ["infectivity", "reproduction", "evasion", "resistance"]


## Returns {"child": Organism, "events": Array}. At most one trait mutates per offspring.
static func reproduce(state: WorldState, parent: Organism, tile: int) -> Dictionary:
	var child := Organism.new()
	child.team = Sim.BACTERIA
	child.antigen = parent.antigen
	child.strain = parent.strain
	child.max_health = parent.max_health
	child.health = parent.max_health
	child.infectivity = parent.infectivity
	child.reproduction = parent.reproduction
	child.evasion = parent.evasion
	child.resistance = parent.resistance
	child.move_range = parent.move_range
	child.energy = 1.0
	child.generation = parent.generation + 1
	child.parent_id = parent.id
	child.born_round = state.round
	child.algorithm = parent.algorithm
	child.inherited = parent.trait_snapshot()
	child.mutations = parent.mutations.duplicate()
	state.add_organism(child, tile)
	var events: Array = []
	if state.rng.randf() < state.setup.mutation_rate:
		events.append_array(_mutate(state, parent, child))
	return {"child": child, "events": events}


static func _mutate(state: WorldState, parent: Organism, child: Organism) -> Array:
	var events: Array = []
	if state.rng.randf() < 0.14:
		child.antigen = (child.antigen + 1 + state.rng.randi() % (Sim.ANTIGENS.size() - 1)) % Sim.ANTIGENS.size()
		state.strain_counters[child.antigen] = state.strain_counters[child.antigen] + 1
		child.strain = "%s-%d" % [Sim.ANTIGENS[child.antigen], state.strain_counters[child.antigen]]
		child.mutations.append("antigen %s→%s" % [parent.antigen_name(), child.antigen_name()])
		child.add_effect("Shifted", 3, 1.0)
		state.stats.mutations += 1
		events.append(Ev.make("new_strain", "Evolution",
			"New strain %s emerged from bacterium #%d (antigen shift)." % [child.strain, parent.id],
			state.round, {"org": child.id, "tile": child.tile, "sev": Ev.IMPORTANT, "team": Sim.BACTERIA}))
		return events
	var trait_name: String = BACTERIA_TRAITS[state.rng.randi() % BACTERIA_TRAITS.size()]
	var delta := 1 if state.rng.randf() < 0.55 else -1
	var before: int = child.get(trait_name)
	var after := clampi(before + delta, 0 if trait_name == "resistance" else 1, Sim.MAX_TRAIT)
	if after == before:
		return events
	child.set(trait_name, after)
	child.mutations.append("%s %d→%d" % [trait_name, before, after])
	state.stats.mutations += 1
	var major := absi(after - int(parent.inherited.get(trait_name, before))) >= 3 or after >= 8
	events.append(Ev.make("mutation", "Evolution",
		"Mutation: bacterium #%d %s %d→%d (offspring of #%d)." % [child.id, trait_name, before, after, parent.id],
		state.round, {"org": child.id, "tile": child.tile, "team": Sim.BACTERIA,
			"sev": Ev.IMPORTANT if major else Ev.NOTABLE, "trait": trait_name, "major": major}))
	if trait_name == "resistance" and after >= 5 and not state.stats.resistance_seen:
		state.stats.resistance_seen = true
		events.append(Ev.make("resistance", "Evolution",
			"Antibiotic resistance developed in strain %s." % child.strain, state.round,
			{"org": child.id, "sev": Ev.IMPORTANT, "team": Sim.BACTERIA}))
	return events


## Clonal evolution for T cells: one of attack / detection / range rolls -1, 0 or +1.
static func clone_immune(state: WorldState, parent: Organism, tile: int) -> Dictionary:
	var child := Organism.new()
	child.team = Sim.IMMUNE
	child.max_health = parent.max_health
	child.health = parent.max_health
	child.attack = parent.attack
	child.detection = parent.detection
	child.move_range = parent.move_range
	child.generation = parent.generation + 1
	child.parent_id = parent.id
	child.born_round = state.round
	child.algorithm = parent.algorithm
	child.memory = parent.memory.duplicate()
	var traits := ["attack", "detection", "move_range"]
	var trait_name: String = traits[state.rng.randi() % traits.size()]
	var delta := state.rng.randi_range(-1, 1)
	var before: int = child.get(trait_name)
	var upper := 4 if trait_name == "move_range" else Sim.MAX_TRAIT
	var after := clampi(before + delta, 1, upper)
	child.set(trait_name, after)
	if after != before:
		child.mutations.append("%s %d→%d" % [trait_name, before, after])
		state.stats.mutations += 1
	child.inherited = {"attack": parent.attack, "detection": parent.detection, "move_range": parent.move_range}
	state.add_organism(child, tile)
	var text := "T cell #%d cloned #%d" % [parent.id, child.id]
	text += " · %s %d→%d" % [trait_name, before, after] if after != before else " · traits steady"
	return {"child": child, "text": text, "changed": after != before}
