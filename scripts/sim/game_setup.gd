class_name GameSetup
extends RefCounted
## Everything the player configures before a match. Plain data, serialisable.

var mode := Sim.Mode.HUMAN_VS_AI
var human_side := Sim.IMMUNE
# Environment
var board_size := 10
var nutrient_level := 0.5
var oxygen := 0.8
var antibiotic := 0.0
var infection_sites := 1
var difficulty := 1
# Bacteria
var bact_pop := 2
var bact_infectivity := 5
var bact_reproduction := 5
var bact_evasion := 3
var bact_resistance := 1
var mutation_rate := 0.3
var reproduction_rate := 1.0
var bact_cap := 18
# Immune
var immune_pop := 2
var immune_attack := 4
var immune_detection := 4
var immune_range := 3
var immune_activation := 2
var immune_cap := 10
# AI
var bact_ai := Sim.Algo.HYBRID
var immune_ai := Sim.Algo.HYBRID
var search_depth := 2
var mcts_sims := 24
# Rules
var bact_actions := 3
var immune_actions := 2
var max_rounds := 80
var rng_seed := 0
var experiment_runs := 10


func to_dict() -> Dictionary:
	var data := {}
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[property.name] = get(property.name)
	return data


static func from_dict(data: Dictionary) -> GameSetup:
	var setup := GameSetup.new()
	for key in data:
		if key in setup:
			setup.set(key, data[key])
	return setup


func controller_for(team: int) -> String:
	match mode:
		Sim.Mode.HUMAN_VS_AI:
			return "human" if team == human_side else "ai"
		Sim.Mode.HUMAN_VS_HUMAN, Sim.Mode.SANDBOX:
			return "human"
	return "ai"


func algo_for(team: int) -> int:
	return bact_ai if team == Sim.BACTERIA else immune_ai
