class_name Organism
extends RefCounted
## Internal state of one bacterium or immune cell.

var id := 0
var team := Sim.BACTERIA
var antigen := 0
var strain := "A-1"
var health := 3.0
var max_health := 3.0
var infectivity := 5
var reproduction := 5
var evasion := 3
var resistance := 1
var attack := 4
var detection := 4
var move_range := 3
var energy := 2.0
var tile := -1
var generation := 0
var parent_id := 0
var born_round := 1
var mutations: Array = []
var inherited: Dictionary = {}
var effects: Dictionary = {}
var memory: Dictionary = {}
var acted := false
var alive := true
var kills := 0
var algorithm := ""
var current_action := "Idle"
var current_target := "-"
var last_decision := "-"
var last_decision_scores: Dictionary = {}
var is_dominant := false


func label() -> String:
	return "%s #%d" % [Sim.team_name(team), id]


func antigen_name() -> String:
	return Sim.ANTIGENS[antigen]


func has_effect(effect: String) -> bool:
	return effects.has(effect)


func add_effect(effect: String, turns: int, value := 1.0) -> void:
	effects[effect] = {"turns": turns, "value": value}


func effect_value(effect: String, default := 1.0) -> float:
	return float(effects[effect].value) if effects.has(effect) else default


func tick_effects() -> void:
	for effect in effects.keys():
		effects[effect].turns -= 1
		if effects[effect].turns <= 0:
			effects.erase(effect)


func trait_snapshot() -> Dictionary:
	return {"infectivity": infectivity, "reproduction": reproduction, "evasion": evasion,
			"resistance": resistance, "antigen": antigen}


func to_dict() -> Dictionary:
	var data := {}
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[property.name] = get(property.name)
	return data


static func from_dict(data: Dictionary) -> Organism:
	var organism := Organism.new()
	for key in data:
		if key in organism:
			organism.set(key, data[key])
	organism.id = int(data.get("id", 0))
	organism.team = int(data.get("team", Sim.BACTERIA))
	organism.tile = int(data.get("tile", -1))
	organism.antigen = int(data.get("antigen", 0))
	var restored := {}
	for key in organism.memory:
		restored[int(key)] = organism.memory[key]
	organism.memory = restored
	return organism
