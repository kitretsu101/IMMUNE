class_name RoundRules
extends RefCounted
## End-of-round processing: feeding, tissue, antibiotics, reproduction, victory.


static func end_of_round(state: WorldState) -> Array:
	var events: Array = []
	state.stats.offspring_round = 0
	_detect_and_activate(state, events)
	_feed(state, events)
	_tissue(state, events)
	_biofilm(state)
	_reproduce(state, events)
	for id in state.organisms:
		var organism: Organism = state.organisms[id]
		organism.acted = false
		organism.tick_effects()
	var bacteria := state.count_team(Sim.BACTERIA)
	state.stats.bact_peak = maxi(state.stats.bact_peak, bacteria)
	if bacteria <= int(state.stats.bact_peak * 0.25) and state.stats.bact_peak >= 6 and not state.stats.collapse_flag:
		state.stats.collapse_flag = true
		events.append(Ev.make("pop_collapse", "Environment", "Bacterial population collapse.", state.round,
			{"sev": Ev.IMPORTANT, "team": Sim.BACTERIA}))
	elif bacteria > int(state.stats.bact_peak * 0.5):
		state.stats.collapse_flag = false
	events.append(Ev.make("round_end", "System", "Round %d complete." % state.round, state.round))
	state.round += 1
	return events


const DOMINANCE_ROUNDS := 3
const DOMINANCE_MIN_UNITS := 6


## A side that keeps a large population lead for several rounds wins. Same rule for both sides.
static func _update_dominance(state: WorldState) -> void:
	var counts := {Sim.IMMUNE: state.count_team(Sim.IMMUNE), Sim.BACTERIA: state.count_team(Sim.BACTERIA)}
	for team in counts:
		var foe: int = counts[Sim.other(team)]
		var ahead: bool = counts[team] >= DOMINANCE_MIN_UNITS and counts[team] >= foe * state.setup.dominance_ratio
		var key := "dominance_%d" % team
		state.stats[key] = (int(state.stats.get(key, 0)) + 1) if ahead else 0


static func _detect_and_activate(state: WorldState, events: Array) -> void:
	var any_active := false
	for team in [Sim.IMMUNE, Sim.BACTERIA]:
		var enemy := Sim.other(team)
		for cell in state.living(team):
			var radius: int = 1 + cell.detection / 3
			var seen: Organism = null
			for foe in state.living(enemy):
				if state.distance(cell.tile, foe.tile) <= radius:
					seen = foe
					break
			if seen != null:
				var newly: bool = not cell.has_effect("Activated")
				cell.add_effect("Activated", state.setup.immune_activation, 1.0)
				if team == Sim.IMMUNE:
					any_active = true
				if newly:
					events.append(Ev.make("antigen_detected", "Combat",
						"%s detected antigen %s." % [cell.label(), seen.antigen_name()], state.round,
						{"org": cell.id, "other": seen.id, "tile": cell.tile, "tile2": seen.tile, "team": team}))
			elif cell.has_effect("Activated") and team == Sim.IMMUNE:
				any_active = true
	if any_active and not state.stats.get("immune_active", false):
		events.append(Ev.make("immune_activation", "Combat", "Immune system activated.", state.round,
			{"sev": Ev.IMPORTANT, "team": Sim.IMMUNE}))
	state.stats["immune_active"] = any_active


static func _feed(state: WorldState, events: Array) -> void:
	for tile in state.count:
		if state.tissue[tile] == Sim.Tissue.INFECTED:
			state.nutrients[tile] = minf(Balance.NUTRIENT_CAP, state.nutrients[tile] + 0.3)
	for organism in state.organisms.values().duplicate():
		if not organism.alive:
			continue
		var tile: int = organism.tile
		var appetite := 0.6 + (0.3 if organism.has_effect("Resting") else 0.0)
		var eaten := minf(appetite, state.nutrients[tile])
		if eaten > 0.05:
			state.nutrients[tile] -= eaten
			organism.energy = minf(ActionExecutor.MAX_ENERGY, organism.energy + eaten * 1.2)
			if eaten > 0.4 and state.rng.randf() < 0.3:
				events.append(Ev.make("eat", "Environment", "%s absorbed nutrients." % organism.label(),
					state.round, {"org": organism.id, "tile": tile, "team": organism.team}))
		organism.energy -= Balance.UPKEEP
		if organism.energy < 0.0:
			organism.energy = 0.0
			organism.health -= Balance.STARVE_DAMAGE
			if organism.health <= 0.0:
				state.remove_organism(organism)
				events.append(Ev.make("death", "Death", "%s starved." % organism.label(), state.round,
					{"org": organism.id, "tile": tile, "team": organism.team, "victim_team": organism.team, "sev": Ev.NOTABLE}))
		elif organism.energy >= 1.0 and organism.health < organism.max_health:
			organism.health = minf(organism.max_health, organism.health + organism.regen)
	for tile in state.count:
		if state.active[tile] == 1 and state.tissue[tile] != Sim.Tissue.DESTROYED:
			state.nutrients[tile] = minf(Balance.NUTRIENT_CAP, state.nutrients[tile] + 0.01 * state.setup.nutrient_level)
	if state.rng.randf() < 0.35 + state.setup.nutrient_level * 0.5:
		var spot := state.rng.randi_range(0, state.count - 1)
		if state.active[spot] == 1 and state.tissue[spot] != Sim.Tissue.DESTROYED:
			state.nutrients[spot] = state.rng.randf_range(1.2, Balance.NUTRIENT_CAP)


static func _antibiotic(state: WorldState, events: Array) -> void:
	if state.antibiotic < 0.02:
		return
	for bacterium in state.living(Sim.BACTERIA):
		if state.rng.randf() < Balance.antibiotic_damage_chance(state, bacterium):
			bacterium.health -= 1.0
			events.append(Ev.make("antibiotic_hit", "Environment",
				"%s damaged by antibiotic." % bacterium.label(), state.round,
				{"org": bacterium.id, "tile": bacterium.tile, "team": Sim.BACTERIA}))
			if bacterium.health <= 0.0:
				var tile: int = bacterium.tile
				state.remove_organism(bacterium)
				events.append(Ev.make("death", "Death", "%s killed by antibiotic." % bacterium.label(),
					state.round, {"org": bacterium.id, "tile": tile, "team": Sim.BACTERIA, "victim_team": Sim.BACTERIA, "sev": Ev.NOTABLE}))
	state.antibiotic *= 0.94


static func _tissue(state: WorldState, events: Array) -> void:
	var infected_before := state.tissue_fraction(Sim.Tissue.INFECTED)
	for tile in state.count:
		if state.active[tile] == 0:
			continue
		var occupant := state.org_at(tile)
		match state.tissue[tile]:
			Sim.Tissue.INFECTED:
				state.tissue_timer[tile] += 1
				if occupant != null and occupant.team == Sim.IMMUNE:
					state.tissue[tile] = Sim.Tissue.DAMAGED
					state.tissue_timer[tile] = 0
					occupant.energy = minf(ActionExecutor.MAX_ENERGY, occupant.energy + Balance.CLEANSE_ENERGY)
					events.append(Ev.make("tissue_cleansed", "Infection",
						"%s cleansed infection at %s." % [occupant.label(), Ev.at(tile)], state.round,
						{"org": occupant.id, "tile": tile, "team": Sim.IMMUNE}))
				elif state.tissue_timer[tile] >= 8 and (occupant == null or occupant.team != Sim.BACTERIA or state.rng.randf() < 0.3):
					state.tissue[tile] = Sim.Tissue.DESTROYED
					events.append(Ev.make("tissue_destroyed", "Infection",
						"Tissue at %s destroyed." % Ev.at(tile), state.round, {"tile": tile, "sev": Ev.NOTABLE}))
				elif occupant != null and occupant.team == Sim.BACTERIA and occupant.strain == state.tissue_strain[tile]:
					var chance := 0.05 + 0.03 * occupant.infectivity
					var options: Array = []
					for next in state.neighbors[tile]:
						if state.org_at(next) == null and Balance.infectable(state, occupant, next):
							options.append(next)
					if not options.is_empty() and state.rng.randf() < chance:
						var target: int = options[state.rng.randi() % options.size()]
						state.tissue[target] = Sim.Tissue.INFECTED
						state.tissue_strain[target] = occupant.strain
						state.tissue_timer[target] = 0
						events.append(Ev.make("tissue_spread", "Infection",
							"Infection spread to %s." % Ev.at(target), state.round,
							{"tile": tile, "tile2": target, "team": Sim.BACTERIA}))
			Sim.Tissue.DAMAGED:
				state.tissue_timer[tile] += 1
				if state.tissue_timer[tile] >= 3:
					state.tissue[tile] = Sim.Tissue.HEALTHY
					state.tissue_timer[tile] = 0
	var infected_after := state.tissue_fraction(Sim.Tissue.INFECTED)
	if floorf(infected_after * 10.0) > floorf(infected_before * 10.0):
		events.append(Ev.make("infection_surge", "Infection",
			"Significant infection expansion: %d%% of tissue infected." % roundi(infected_after * 100.0),
			state.round, {"sev": Ev.IMPORTANT, "team": Sim.BACTERIA}))


static func _biofilm(state: WorldState) -> void:
	for tile in state.count:
		if state.biofilm[tile] > 0 and state.org_at(tile) == null and state.rng.randf() < 0.2:
			state.biofilm[tile] -= 1


static func _reproduce(state: WorldState, events: Array) -> void:
	for parent in state.living(Sim.BACTERIA):
		if state.count_team(Sim.BACTERIA) >= state.setup.bact_cap:
			break
		if parent.energy < Balance.REPRO_COST or parent.health < 1.0:
			continue
		var free := state.free_neighbors(parent.tile)
		if free.is_empty() or state.rng.randf() > Balance.reproduce_chance(state, parent):
			continue
		var best_tile: int = free[0]
		var best_score := -INF
		for tile in free:
			var s: float = state.nutrients[tile] + (0.5 if state.tissue[tile] == Sim.Tissue.INFECTED else 0.0) + state.rng.randf() * 0.4
			if s > best_score:
				best_score = s
				best_tile = tile
		parent.energy -= Balance.REPRO_COST
		var result := Evolution.reproduce(state, parent, best_tile)
		state.stats.offspring_round += 1
		events.append(Ev.make("reproduce", "Reproduction",
			"Bacterium #%d reproduced (gen %d) → #%d at %s." % [parent.id, result.child.generation, result.child.id, Ev.at(best_tile)],
			state.round, {"org": parent.id, "other": result.child.id, "tile": parent.tile, "tile2": best_tile,
				"team": Sim.BACTERIA, "sev": Ev.NOTABLE}))
		events.append_array(result.events)


static func _environment(state: WorldState, events: Array) -> void:
	var infected := state.tissue_fraction(Sim.Tissue.INFECTED)
	var target := state.setup.oxygen * (1.0 - 0.5 * infected)
	var before := state.oxygen
	state.oxygen += (target - state.oxygen) * 0.2
	if absf(state.oxygen - state.stats.get("oxygen_reported", before)) > 0.08:
		state.stats["oxygen_reported"] = state.oxygen
		events.append(Ev.make("oxygen_change", "Environment", "Oxygen level now %d%%." % roundi(state.oxygen * 100.0), state.round))


## Sets state.finished / winner and returns the game-over event, or an empty dictionary.
static func check_victory(state: WorldState) -> Dictionary:
	if state.finished or state.setup.mode == Sim.Mode.SANDBOX:
		return {}
	var text := ""
	var winner := Sim.NONE
	if state.count_team(Sim.BACTERIA) == 0:
		winner = Sim.IMMUNE
		text = "Immune victory · all bacteria eliminated"
	elif state.count_team(Sim.IMMUNE) == 0:
		winner = Sim.BACTERIA
		text = "Bacterial victory · immune cells wiped out"
	elif state.setup.core_win and state.core_infected() >= state.core.size():
		winner = Sim.BACTERIA
		text = "Bacterial victory · all human cells infected"
	elif state.round > state.setup.max_rounds:
		var immune_units := state.count_team(Sim.IMMUNE)
		var bacteria_units := state.count_team(Sim.BACTERIA)
		if immune_units > bacteria_units:
			winner = Sim.IMMUNE
			text = "Immune victory · more cells at the round limit"
		elif bacteria_units > immune_units:
			winner = Sim.BACTERIA
			text = "Bacterial victory · more cells at the round limit"
		else:
			text = "Draw · round limit reached"
	else:
		return {}
	state.finished = true
	state.winner = winner
	state.result_text = text
	return Ev.make("game_over", "System", text, state.round,
		{"sev": Ev.CRITICAL, "winner": winner, "team": winner})
