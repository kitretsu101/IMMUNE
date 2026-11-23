class_name TutorialStage
extends RefCounted
## Builds a mid-game scenario for the tutorial: infection under way, a mutant, a hungry bacterium,
## biofilm, nutrient pickups, an activated T cell. Returns handles the tour can point at.


static func stage(state: WorldState) -> Dictionary:
	for organism in state.organisms.values():
		state.occupant[organism.tile] = 0
	state.organisms.clear()
	state.round = 6
	state.elapsed = 142.0
	state.nutrients.fill(0.0)
	var refs := {}
	var center: int = state.core[0]
	var ring := _tiles_by_distance(state, center)
	state.stats.bact_born = 9
	state.stats.bact_dead = 4
	state.stats.immune_born = 5
	state.stats.immune_dead = 1
	state.stats.eliminations = 4
	state.stats.mutations = 3
	state.stats.bact_peak = 9
	var setup := state.setup
	# T cells
	var hero := WorldBuilder.new_immune(state, setup)
	hero.algorithm = "Human"
	hero.generation = 1
	hero.kills = 2
	hero.memory[0] = 2
	hero.add_effect("Activated", 3, 1.0)
	hero.mutations = ["attack 4→5"]
	hero.attack = 5
	state.add_organism(hero, _take(state, ring, 2, 0))
	refs["tcell"] = hero.id
	var hurt := WorldBuilder.new_immune(state, setup)
	hurt.algorithm = "Human"
	hurt.health = 2.0
	hurt.generation = 2
	state.add_organism(hurt, _take(state, ring, 3, 1))
	# Bacteria
	var normal := WorldBuilder.new_bacterium(state, setup, 0)
	normal.algorithm = "Hybrid"
	normal.energy = 4.0
	state.add_organism(normal, _take(state, ring, 3, 2))
	refs["enemy"] = normal.id
	var mutant := WorldBuilder.new_bacterium(state, setup, 0)
	mutant.algorithm = "Hybrid"
	mutant.generation = 3
	mutant.evasion = 5
	mutant.reproduction = 6
	mutant.mutations = ["evasion 3→4", "evasion 4→5", "reproduction 5→6"]
	mutant.inherited = {"infectivity": 5, "reproduction": 5, "evasion": 3, "resistance": 1, "antigen": 0}
	mutant.parent_id = normal.id
	mutant.energy = 3.0
	state.add_organism(mutant, _take(state, ring, 4, 0))
	refs["mutant"] = mutant.id
	var hungry := WorldBuilder.new_bacterium(state, setup, 0)
	hungry.algorithm = "Hybrid"
	hungry.energy = 0.4
	hungry.health = 3.5
	hungry.generation = 1
	state.add_organism(hungry, _take(state, ring, 4, 1))
	refs["hungry"] = hungry.id
	var film := WorldBuilder.new_bacterium(state, setup, 1)
	film.algorithm = "Hybrid"
	film.strain = "B-2"
	film.mutations = ["antigen A→B"]
	film.generation = 2
	film.energy = 2.0
	film.add_effect("BiofilmCost", 3, Balance.REPRO_TEMP_PENALTY)
	var film_tile := _take(state, ring, 4, 2)
	state.add_organism(film, film_tile)
	state.biofilm[film_tile] = 2
	refs["biofilm"] = film.id
	# Tissue
	var infected_tile: int = mutant.tile
	for organism in state.living(Sim.BACTERIA):
		state.tissue[organism.tile] = Sim.Tissue.INFECTED
		state.tissue_strain[organism.tile] = organism.strain
		state.tissue_timer[organism.tile] = 2
	state.tissue[state.core[1]] = Sim.Tissue.INFECTED
	state.tissue_strain[state.core[1]] = "A-1"
	state.tissue_timer[state.core[1]] = 3
	refs["infected"] = state.core[1]
	var damaged: int = _take(state, ring, 2, 2)
	state.tissue[damaged] = Sim.Tissue.DAMAGED
	state.tissue_timer[damaged] = 1
	# Nutrient pickups
	var orb_tiles: Array = []
	for index in 4:
		var tile := _take(state, ring, 3 + index % 2, 3 + index)
		state.nutrients[tile] = 1.4 + 0.2 * index
		orb_tiles.append(tile)
	var lost: int = _take(state, ring, 4, 5)
	state.tissue[lost] = Sim.Tissue.DESTROYED
	var healthy: int = _take(state, ring, 2, 7)
	refs["damaged"] = damaged
	refs["destroyed"] = lost
	refs["healthy"] = healthy
	refs["filmtile"] = film_tile
	refs["orb"] = orb_tiles[0]
	refs["core"] = center
	return refs


static func _tiles_by_distance(state: WorldState, center: int) -> Dictionary:
	var by_distance := {}
	for tile in state.count:
		if state.active[tile] == 1 and not state.core.has(tile):
			var d := state.distance(center, tile)
			if not by_distance.has(d):
				by_distance[d] = []
			by_distance[d].append(tile)
	return by_distance


static func _take(state: WorldState, ring: Dictionary, distance: int, index: int) -> int:
	var list: Array = ring.get(distance, [])
	for offset in list.size():
		var tile: int = list[(index * 2 + offset) % list.size()]
		if state.occupant[tile] == 0 and state.nutrients[tile] == 0.0 and state.tissue[tile] == Sim.Tissue.HEALTHY:
			return tile
	return list[0] if not list.is_empty() else 0
