class_name Sim
extends RefCounted
## Shared constants and enums for the simulation core.

const NONE := 0
const IMMUNE := 1
const BACTERIA := 2

enum Tissue { HEALTHY, INFECTED, DAMAGED, DESTROYED }
enum Kind { MOVE, ATTACK, INFECT, CLONE, BIOFILM, REPRODUCE, WAIT }
enum Mode { HUMAN_VS_AI, AI_VS_AI, HUMAN_VS_HUMAN, SANDBOX, EXPERIMENT }
enum Algo { HYBRID, FUZZY, MINIMAX, MCTS, GREEDY }

const KIND_NAMES := ["MOVE", "ATTACK", "INFECT", "CLONE", "BIOFILM", "REPRODUCE", "WAIT"]
const MODE_NAMES := ["Human vs AI", "AI vs AI", "Human vs Human", "Sandbox", "Experiment"]
const ALGO_NAMES := ["Hybrid", "Fuzzy Logic", "Minimax", "MCTS", "Greedy"]
const TISSUE_NAMES := ["Healthy", "Infected", "Damaged", "Destroyed"]
const ANTIGENS := ["A", "B", "C", "D"]
const MAX_TRAIT := 10


static func team_name(team: int) -> String:
	return "T cell" if team == IMMUNE else "Bacterium"


static func other(team: int) -> int:
	return BACTERIA if team == IMMUNE else IMMUNE
