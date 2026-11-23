class_name WorldBuilder
extends RefCounted
## Creates the starting position for a match from a GameSetup.

const GRID_COLUMNS := 10


static func tile_id(setup: GameSetup, col: int, row: int) -> int:
	var offset := (GRID_COLUMNS - setup.board_size) / 2
	return (row + offset) * GRID_COLUMNS + col + offset


static func active_mask(setup: GameSetup) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(GRID_COLUMNS * GRID_COLUMNS)
	var offset := (GRID_COLUMNS - setup.board_size) / 2
	for row in setup.board_size:
		for col in setup.board_size:
			mask[(row + offset) * GRID_COLUMNS + col + offset] = 1
	return mask


static func build(setup: GameSetup, adjacency: Array, positions: PackedVector3Array) -> WorldState:
	var state := WorldState.new()
	state.setup = setup
	if setup.rng_seed != 0:
		state.rng.seed = setup.rng_seed
	else:
		state.rng.randomize()
	state.build_graph(adjacency, positions, active_mask(setup))
	state.oxygen = setup.oxygen
	state.antibiotic = setup.antibiotic
	var size := setup.board_size
	var middle := size / 2
	var center := tile_id(setup, middle, middle)
	state.core = PackedInt32Array([center])
	state.core.append_array(state.neighbors[center])
	for tile in state.count:
		if state.active[tile] == 1:
			var noise := state.rng.randf()
			state.nutrients[tile] = clampf(setup.nutrient_level * 1.4 * noise + setup.nutrient_level * 0.4, 0.0, Balance.NUTRIENT_CAP)
	_place_immune(state, setup)
	_place_bacteria(state, setup)
	return state


static func _place_immune(state: WorldState, setup: GameSetup) -> void:
	var size := setup.board_size
	var anchor := tile_id(setup, 1, 1)
	for index in setup.immune_pop:
		var tile := _free_near(state, anchor)
		if tile < 0:
			break
		state.add_organism(new_immune(state, setup), tile)
		state.organisms[state.occupant[tile]].algorithm = algorithm_label(setup, Sim.IMMUNE)
	for tile in state.core:
		state.nutrients[tile] = 0.0
	if size < 4:
		return


static func _place_bacteria(state: WorldState, setup: GameSetup) -> void:
	var size := setup.board_size
	var sites: Array[int] = [
		tile_id(setup, size - 2, size - 2), tile_id(setup, size - 2, 1),
		tile_id(setup, 1, size - 2), tile_id(setup, size / 2, size - 1),
	]
	var placed := 0
	var index := 0
	while placed < setup.bact_pop and index < 40:
		var site := sites[index % clampi(setup.infection_sites, 1, sites.size())]
		var tile := _free_near(state, site)
		if tile < 0:
			break
		var bacterium := new_bacterium(state, setup, index % clampi(setup.infection_sites, 1, 4))
		state.add_organism(bacterium, tile)
		bacterium.algorithm = algorithm_label(setup, Sim.BACTERIA)
		state.tissue[tile] = Sim.Tissue.INFECTED
		state.tissue_strain[tile] = bacterium.strain
		placed += 1
		index += 1


static func _free_near(state: WorldState, anchor: int) -> int:
	var queue := [anchor]
	var seen := {anchor: true}
	var head := 0
	while head < queue.size():
		var tile: int = queue[head]
		head += 1
		if state.active[tile] == 1 and state.occupant[tile] == 0 and not state.core.has(tile):
			return tile
		for next in state.neighbors[tile]:
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return -1


static func algorithm_label(setup: GameSetup, team: int) -> String:
	return "Human" if setup.controller_for(team) == "human" else Sim.ALGO_NAMES[setup.algo_for(team)]


static func new_immune(state: WorldState, setup: GameSetup) -> Organism:
	var cell := Organism.new()
	cell.team = Sim.IMMUNE
	cell.max_health = 4.0
	cell.health = 4.0
	cell.attack = setup.immune_attack
	cell.detection = setup.immune_detection
	cell.move_range = setup.immune_range
	cell.energy = 0.0
	cell.born_round = state.round
	return cell


static func new_bacterium(state: WorldState, setup: GameSetup, antigen: int) -> Organism:
	var bonus := setup.difficulty - 1
	var bacterium := Organism.new()
	bacterium.team = Sim.BACTERIA
	bacterium.antigen = antigen % Sim.ANTIGENS.size()
	bacterium.strain = "%s-%d" % [Sim.ANTIGENS[bacterium.antigen], state.strain_counters[bacterium.antigen]]
	bacterium.max_health = 5.0
	bacterium.health = 5.0
	bacterium.infectivity = clampi(setup.bact_infectivity + bonus, 1, Sim.MAX_TRAIT)
	bacterium.reproduction = clampi(setup.bact_reproduction + bonus, 1, Sim.MAX_TRAIT)
	bacterium.evasion = clampi(setup.bact_evasion + bonus, 1, Sim.MAX_TRAIT)
	bacterium.resistance = clampi(setup.bact_resistance, 0, Sim.MAX_TRAIT)
	bacterium.move_range = 2
	bacterium.energy = 3.0
	bacterium.born_round = state.round
	bacterium.inherited = bacterium.trait_snapshot()
	return bacterium
