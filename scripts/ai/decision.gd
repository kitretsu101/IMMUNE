class_name Decision
extends RefCounted
## The record of one AI decision: what was considered, what was chosen and what it cost.

var org_id := 0
var team := Sim.BACTERIA
var round_number := 0
var algorithm := ""
var chosen: SimAction
var scores: Dictionary = {}
var candidates: Array = []
var propositions := ""
var priorities: Dictionary = {}
var nodes := 0
var simulations := 0
var time_ms := 0.0
var pipeline: PackedStringArray = []


func summary() -> String:
	return "%s %.2f via %s" % [chosen.label(), scores.get(chosen.label(), 0.0), algorithm]


func to_dict() -> Dictionary:
	return {"org": org_id, "team": team, "round": round_number, "algorithm": algorithm,
			"selected": chosen.label(), "scores": scores, "propositions": propositions,
			"priorities": priorities, "nodes": nodes, "simulations": simulations,
			"time_ms": snappedf(time_ms, 0.01), "pipeline": Array(pipeline)}
