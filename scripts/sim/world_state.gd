class_name WorldState
extends RefCounted
## All mutable simulation data for one match. No nodes, no rendering.

var setup: GameSetup
var count := 0
var neighbors: Array = []          # Array[PackedInt32Array]
var positions := PackedVector3Array()
var active := PackedByteArray()
var dist := PackedInt32Array()
var core := PackedInt32Array()
var occupant := PackedInt32Array()
var organisms: Dictionary = {}
var next_id := 1
var tissue := PackedByteArray()
var tissue_timer := PackedInt32Array()
var tissue_strain := PackedStringArray()
var nutrients := PackedFloat32Array()
var biofilm := PackedByteArray()
var oxygen := 0.8
var antibiotic := 0.0
var round := 1
var side := Sim.IMMUNE
var elapsed := 0.0
var finished := false
var winner := Sim.NONE
var result_text := ""
var rng := RandomNumberGenerator.new()
var strain_counters := {0: 1, 1: 1, 2: 1, 3: 1}
var stats := {
	"bact_born": 0, "bact_dead": 0, "immune_born": 0, "immune_dead": 0,
	"eliminations": 0, "offspring_round": 0, "bact_peak": 0, "mutations": 0,
	"collapse_flag": false, "resistance_seen": false,
}


func build_graph(adjacency: Array, tile_positions: PackedVector3Array, active_tiles: PackedByteArray) -> void:
	count = tile_positions.size()
	positions = tile_positions
	active = active_tiles
	neighbors = []
	for tile in count:
		var list := PackedInt32Array()
		if active[tile] == 1:
			for other in adjacency[tile]:
				if active[other] == 1:
					list.append(other)
		neighbors.append(list)
	occupant.resize(count)
	occupant.fill(0)
	tissue.resize(count)
	tissue.fill(Sim.Tissue.HEALTHY)
	tissue_timer.resize(count)
	tissue_timer.fill(0)
	tissue_strain.resize(count)
	nutrients.resize(count)
	nutrients.fill(0.0)
	biofilm.resize(count)
	biofilm.fill(0)
	_compute_distances()


func _compute_distances() -> void:
	dist.resize(count * count)
	dist.fill(9999)
	for start in count:
		if active[start] == 0:
			continue
		dist[start * count + start] = 0
		var queue := PackedInt32Array([start])
		var head := 0
		while head < queue.size():
			var tile := queue[head]
			head += 1
			for next in neighbors[tile]:
				if dist[start * count + next] == 9999:
					dist[start * count + next] = dist[start * count + tile] + 1
					queue.append(next)


var _within_cache: Array = []
var _core_prox := PackedInt32Array()
var _open_core := PackedInt32Array()
var _open_sig := -1


## Distance from each tile to the nearest core tile.
func core_prox() -> PackedInt32Array:
	if _core_prox.size() != count:
		_core_prox.resize(count)
		for tile in count:
			var best := 99
			for core_tile in core:
				best = mini(best, distance(tile, core_tile))
			_core_prox[tile] = best
	return _core_prox


## Distance from each tile to the nearest core tile that is not yet infected.
func open_core_dist() -> PackedInt32Array:
	var signature := 0
	for core_tile in core:
		if tissue[core_tile] != Sim.Tissue.INFECTED and tissue[core_tile] != Sim.Tissue.DESTROYED:
			signature = signature * 3 + 1 + core_tile
	if signature != _open_sig or _open_core.size() != count:
		_open_sig = signature
		_open_core.resize(count)
		for tile in count:
			var best := 99
			for core_tile in core:
				if tissue[core_tile] != Sim.Tissue.INFECTED and tissue[core_tile] != Sim.Tissue.DESTROYED:
					best = mini(best, distance(tile, core_tile))
			_open_core[tile] = best
	return _open_core


## Distance from each tile to the nearest living organism of a team.
func team_dist(team: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(count)
	result.fill(99)
	for id in organisms:
		var organism: Organism = organisms[id]
		if organism.team == team and organism.alive:
			var base := organism.tile * count
			for tile in count:
				var d := dist[base + tile]
				if d < result[tile]:
					result[tile] = d
	return result


## For every tile, the active tiles within `radius` steps sorted by distance (excluding the tile itself).
func within_tiles(radius: int) -> Array:
	if _within_cache.size() == count and not _within_cache.is_empty():
		return _within_cache
	_within_cache = []
	for tile in count:
		var list := PackedInt32Array()
		if active[tile] == 1:
			for other in count:
				if other != tile and active[other] == 1 and dist[tile * count + other] <= radius:
					list.append(other)
		_within_cache.append(list)
	return _within_cache


func distance(from_tile: int, to_tile: int) -> int:
	return dist[from_tile * count + to_tile]


func org_at(tile: int) -> Organism:
	var id := occupant[tile]
	return organisms.get(id) if id > 0 else null


func get_org(id: int) -> Organism:
	return organisms.get(id)


func living(team: int) -> Array:
	var list: Array = []
	for id in organisms:
		var organism: Organism = organisms[id]
		if organism.team == team and organism.alive:
			list.append(organism)
	list.sort_custom(func(a: Organism, b: Organism) -> bool: return a.id < b.id)
	return list


func count_team(team: int) -> int:
	var total := 0
	for id in organisms:
		var organism: Organism = organisms[id]
		if organism.team == team and organism.alive:
			total += 1
	return total


func add_organism(organism: Organism, tile: int) -> void:
	organism.id = next_id
	next_id += 1
	organism.tile = tile
	organisms[organism.id] = organism
	occupant[tile] = organism.id
	if organism.team == Sim.BACTERIA:
		stats.bact_born += 1
		stats.bact_peak = maxi(stats.bact_peak, count_team(Sim.BACTERIA))
	else:
		stats.immune_born += 1


func remove_organism(organism: Organism) -> void:
	organism.alive = false
	if occupant[organism.tile] == organism.id:
		occupant[organism.tile] = 0
	organisms.erase(organism.id)
	if organism.team == Sim.BACTERIA:
		stats.bact_dead += 1
	else:
		stats.immune_dead += 1


func move_organism(organism: Organism, tile: int) -> void:
	if occupant[organism.tile] == organism.id:
		occupant[organism.tile] = 0
	organism.tile = tile
	occupant[tile] = organism.id


func free_neighbors(tile: int) -> Array:
	var list: Array = []
	for next in neighbors[tile]:
		if occupant[next] == 0:
			list.append(next)
	return list


func nearest_distance(tile: int, team: int) -> int:
	var best := 99
	for id in organisms:
		var organism: Organism = organisms[id]
		if organism.team == team and organism.alive:
			best = mini(best, distance(tile, organism.tile))
	return best


func units_within(tile: int, team: int, radius: int) -> int:
	var total := 0
	for id in organisms:
		var organism: Organism = organisms[id]
		if organism.team == team and organism.alive and distance(tile, organism.tile) <= radius:
			total += 1
	return total


func core_infected() -> int:
	var total := 0
	for tile in core:
		if tissue[tile] == Sim.Tissue.INFECTED or tissue[tile] == Sim.Tissue.DESTROYED:
			total += 1
	return total


func tissue_fraction(kind: int) -> float:
	var total := 0
	var matching := 0
	for tile in count:
		if active[tile] == 1:
			total += 1
			if tissue[tile] == kind:
				matching += 1
	return float(matching) / maxf(1.0, total)


func average_nutrient() -> float:
	var total := 0.0
	var tiles := 0
	for tile in count:
		if active[tile] == 1:
			total += nutrients[tile]
			tiles += 1
	return total / maxf(1.0, tiles)


func strain_counts() -> Dictionary:
	var counts := {}
	for organism in living(Sim.BACTERIA):
		counts[organism.strain] = int(counts.get(organism.strain, 0)) + 1
	return counts


func dominant_strain() -> String:
	var best := "-"
	var best_count := 0
	var counts := strain_counts()
	for strain in counts:
		if counts[strain] > best_count:
			best_count = counts[strain]
			best = strain
	return best


func to_dict() -> Dictionary:
	var organism_list: Array = []
	for id in organisms:
		organism_list.append(organisms[id].to_dict())
	return {
		"setup": setup.to_dict(), "organisms": organism_list, "next_id": next_id,
		"tissue": Array(tissue), "tissue_timer": Array(tissue_timer), "tissue_strain": Array(tissue_strain),
		"nutrients": Array(nutrients),
		"biofilm": Array(biofilm), "oxygen": oxygen, "antibiotic": antibiotic, "round": round,
		"side": side, "elapsed": elapsed, "finished": finished, "winner": winner,
		"result_text": result_text, "strain_counters": strain_counters, "stats": stats, "core": Array(core),
	}


func load_dict(data: Dictionary) -> void:
	organisms.clear()
	occupant.fill(0)
	for entry in data.organisms:
		var organism := Organism.from_dict(entry)
		organisms[organism.id] = organism
		occupant[organism.tile] = organism.id
	next_id = int(data.next_id)
	tissue = PackedByteArray(data.tissue)
	tissue_timer = PackedInt32Array(data.tissue_timer)
	tissue_strain = PackedStringArray(data.tissue_strain)
	nutrients = PackedFloat32Array(data.nutrients)
	biofilm = PackedByteArray(data.biofilm)
	core = PackedInt32Array(data.core)
	oxygen = float(data.oxygen)
	antibiotic = float(data.antibiotic)
	round = int(data.round)
	side = int(data.side)
	elapsed = float(data.elapsed)
	finished = bool(data.finished)
	winner = int(data.winner)
	result_text = str(data.result_text)
	strain_counters = {}
	for key in data.strain_counters:
		strain_counters[int(key)] = int(data.strain_counters[key])
	stats = data.stats
