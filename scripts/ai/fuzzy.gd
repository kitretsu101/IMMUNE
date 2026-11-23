class_name Fuzzy
extends RefCounted
## Fuzzy logic: turns situation readings into growth / survival / infection (or defend / hunt / expand) priorities.


static func low(x: float) -> float:
	return clampf(1.0 - x * 2.0, 0.0, 1.0)


static func mid(x: float) -> float:
	return clampf(1.0 - absf(x - 0.5) * 2.0, 0.0, 1.0)


static func high(x: float) -> float:
	return clampf(x * 2.0 - 1.0, 0.0, 1.0)


static func _blend(rules: Array, fallback: float) -> float:
	var total := 0.0
	var weight := 0.0
	for rule in rules:
		total += rule[0] * rule[1]
		weight += rule[0]
	return total / weight if weight > 0.001 else fallback


## Inputs are all 0..1. Returns {"growth", "survival", "infection"}.
static func bacterium_priorities(health: float, energy: float, threat: float, nutrient: float,
		opportunity: float, antibiotic: float, crowd: float) -> Dictionary:
	var growth := _blend([
		[minf(high(energy), low(threat)), 0.95],
		[minf(mid(energy), high(nutrient)), 0.65],
		[minf(mid(energy), low(threat)), 0.5],
		[low(energy), 0.15],
		[high(crowd), 0.1],
		[high(threat), 0.2],
	], 0.35)
	var survival := _blend([
		[high(threat), 0.95],
		[low(health), 0.9],
		[high(antibiotic), 0.7],
		[mid(threat), 0.5],
		[minf(low(threat), high(health)), 0.1],
	], 0.2)
	var infection := _blend([
		[minf(high(opportunity), low(threat)), 0.95],
		[minf(high(opportunity), mid(threat)), 0.7],
		[mid(opportunity), 0.45],
		[low(opportunity), 0.15],
		[high(threat), 0.15],
	], 0.3)
	return {"growth": growth, "survival": survival, "infection": infection}


## Immune priorities: defend (guard the core), hunt (seek bacteria), expand (clone).
static func immune_priorities(health: float, core_threat: float, enemy_near: float, army_gap: float) -> Dictionary:
	var defend := _blend([
		[high(core_threat), 0.95],
		[mid(core_threat), 0.6],
		[low(core_threat), 0.2],
	], 0.4)
	var hunt := _blend([
		[minf(high(enemy_near), high(health)), 0.95],
		[minf(mid(enemy_near), high(health)), 0.7],
		[low(health), 0.2],
		[low(enemy_near), 0.4],
	], 0.5)
	var expand := _blend([
		[high(army_gap), 0.95],
		[mid(army_gap), 0.55],
		[low(army_gap), 0.15],
	], 0.4)
	return {"defend": defend, "hunt": hunt, "expand": expand}
