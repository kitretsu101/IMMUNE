class_name Balance
extends RefCounted
## Every tuning number that maps a 1-10 trait to a probability lives here.

const REPRO_COST := 2.5
const BIOFILM_COST := 2.0
const MAX_BIOFILM := 3
const NUTRIENT_CAP := 2.0
const REPRO_TEMP_PENALTY := 0.65


static func hit_chance(attacker: Organism, defender: Organism) -> float:
	var memory_bonus := float(attacker.memory.get(defender.antigen, 0)) * 0.5
	var activation := attacker.effect_value("Activated", 0.0)
	var p := 0.33 + 0.05 * (attacker.detection + memory_bonus + activation) - 0.05 * defender.evasion
	return clampf(p, 0.15, 0.95)


static func immune_damage(attacker: Organism, defender: Organism, biofilm_level: int) -> float:
	var damage := 1.0 + (0.5 if attacker.attack >= 6 else 0.0) + attacker.effect_value("Activated", 0.0) * 0.25
	damage -= 0.4 * biofilm_level + (0.3 if defender.has_effect("Hardened") else 0.0)
	return maxf(0.5, damage)


static func bacteria_hit_chance(attacker: Organism, defender: Organism) -> float:
	return clampf(0.28 + 0.05 * attacker.infectivity - 0.04 * defender.attack - defender.effect_value("Activated", 0.0) * 0.03, 0.1, 0.8)


static func infect_chance(state: WorldState, organism: Organism, tile: int) -> float:
	var immune_near := state.units_within(tile, Sim.IMMUNE, 1)
	var p := 0.3 + 0.06 * organism.infectivity - 0.06 * immune_near
	if state.tissue[tile] == Sim.Tissue.DAMAGED:
		p += 0.12
	elif state.tissue[tile] == Sim.Tissue.INFECTED and state.tissue_strain[tile] != organism.strain:
		p -= 0.12
	p += 0.1 * minf(1.0, state.nutrients[tile])
	return clampf(p, 0.08, 0.95)


static func infectable(state: WorldState, organism: Organism, tile: int) -> bool:
	var kind := state.tissue[tile]
	if kind == Sim.Tissue.DESTROYED:
		return false
	return kind != Sim.Tissue.INFECTED or state.tissue_strain[tile] != organism.strain


static func reproduce_chance(state: WorldState, organism: Organism) -> float:
	var oxygen_factor := 0.6 + 0.8 * state.oxygen
	var p := organism.reproduction / 10.0 * state.setup.reproduction_rate * oxygen_factor
	p *= organism.effect_value("BiofilmCost", 1.0) * organism.effect_value("Resting", 1.0)
	return clampf(p, 0.05, 0.98)


static func antibiotic_damage_chance(state: WorldState, organism: Organism) -> float:
	var shield := 0.6 if state.biofilm[organism.tile] > 0 else 1.0
	return clampf(state.antibiotic * (1.0 - organism.resistance / 10.0) * shield, 0.0, 0.95)
