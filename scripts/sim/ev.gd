class_name Ev
extends RefCounted
## Builds simulation event dictionaries. Events are the only thing the presentation layer consumes.

const INFO := "info"
const NOTABLE := "notable"
const IMPORTANT := "important"
const CRITICAL := "critical"


static func make(type: String, category: String, message: String, round_number: int, extra := {}) -> Dictionary:
	var event := {"type": type, "cat": category, "msg": message, "round": round_number,
			"sev": INFO, "org": 0, "other": 0, "tile": -1, "tile2": -1, "team": 0}
	event.merge(extra, true)
	return event


static func at(tile: int) -> String:
	return "(%d,%d)" % [tile % 10, tile / 10]
