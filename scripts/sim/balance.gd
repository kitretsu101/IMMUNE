class_name Balance
extends RefCounted
## Every tuning number that maps a 1-10 trait to a probability lives here.

static var REPRO_COST := 3.4   # bacteria grow passively (no action), so a division costs more energy than a clone
const BIOFILM_COST := 2.0
const MAX_BIOFILM := 3
const NUTRIENT_CAP := 2.0
const REPRO_TEMP_PENALTY := 0.65
static var HIT_BASE := 0.20
static var CLONE_COST := 2.5
static var CLEANSE_ENERGY := 2.0
static var MOVE_COST := 0.25
static var UPKEEP := 0.15
static var STARVE_DAMAGE := 0.5
static var START_ENERGY := 3.0


## One combat model for both sides: attack/learning/activation against the defender's defence (evasion).
static func hit_chance(attacker: Organism, defender: Organism) -> float:
	var learned := float(attacker.memory.get(defender.antigen, 0)) * 0.5
	var activation := attacker.effect_value("Activated", 0.0)
	var p := HIT_BASE + 0.05 * (attacker.attack + learned + activation) - 0.05 * defender.evasion
	return clampf(p, 0.15, 0.95)


static func damage(attacker: Organism, defender: Organism, biofilm_level: int) -> float:
	var dealt := 1.0 + (0.5 if attacker.attack >= 6 else 0.0) + attacker.effect_value("Activated", 0.0) * 0.25
	dealt -= 0.4 * biofilm_level + (0.3 if defender.has_effect("Hardened") else 0.0)
	return maxf(0.5, dealt)


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
	var oxygen_factor := 1.0
	var p := organism.reproduction / 10.0 * state.setup.reproduction_rate * oxygen_factor
	p *= organism.effect_value("BiofilmCost", 1.0) * organism.effect_value("Resting", 1.0)
	return clampf(p, 0.05, 0.98)


static func antibiotic_damage_chance(state: WorldState, organism: Organism) -> float:
	var shield := 0.6 if state.biofilm[organism.tile] > 0 else 1.0
	return clampf(state.antibiotic * (1.0 - organism.resistance / 10.0) * shield, 0.0, 0.95)
