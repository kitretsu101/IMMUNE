class_name SimAction
extends RefCounted
## One thing an organism can do on its turn.

var kind := Sim.Kind.WAIT
var org := 0
var to := -1
var target_org := 0
var target_tile := -1
var path := PackedInt32Array()
var score := 0.0
var detail := ""


static func make(action_kind: int, organism_id: int, destination := -1) -> SimAction:
	var action := SimAction.new()
	action.kind = action_kind
	action.org = organism_id
	action.to = destination
	return action


func label() -> String:
	return Sim.KIND_NAMES[kind]


func describe() -> String:
	var text := label()
	if to >= 0 and kind in [Sim.Kind.MOVE, Sim.Kind.ATTACK, Sim.Kind.CLONE]:
		text += " → tile %d" % to
	if target_org > 0:
		text += " (target #%d)" % target_org
	elif target_tile >= 0 and kind == Sim.Kind.INFECT:
		text += " tile %d" % target_tile
	return text
