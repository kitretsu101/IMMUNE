extends Node
## Logging backend. Independent of any UI: collects events, AI decisions, performance samples and
## evolution records, and exports them. The log window and the compact log only read from here.

signal entry_added(entry: Dictionary)
signal decision_logged(entry: Dictionary)
signal perf_logged(sample: Dictionary)
signal cleared

const MAX_ENTRIES := 20000
const EXPORT_DIR := "user://logs"

var entries: Array[Dictionary] = []
var decisions: Array[Dictionary] = []
var evolution: Array[Dictionary] = []
var perf: Array[Dictionary] = []
var elapsed := 0.0
var _serial := 0


func _ready() -> void:
	Events.sim_event.connect(_on_sim_event)
	Events.decision_made.connect(_on_decision)


func clear() -> void:
	entries.clear()
	decisions.clear()
	evolution.clear()
	perf.clear()
	elapsed = 0.0
	cleared.emit()


func stamp() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]


func add(category: String, message: String, round_number: int, severity := "info", org := 0, extra := {}) -> void:
	_serial += 1
	var entry := {"id": _serial, "time": stamp(), "round": round_number, "cat": category,
			"sev": severity, "org": org, "msg": message}
	entry.merge(extra, true)
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)
	if category == "Evolution" or entry.get("type", "") == "reproduce" or entry.get("type", "") == "clone":
		evolution.append(entry)
		if evolution.size() > MAX_ENTRIES:
			evolution.pop_front()


func _on_sim_event(event: Dictionary) -> void:
	if event.type == "round_end":
		return
	add(event.cat, event.msg, event.round, event.sev, event.org, {"type": event.type, "tile": event.tile})


func _on_decision(decision: Decision) -> void:
	var data := decision.to_dict()
	data["time"] = stamp()
	data["id"] = decisions.size()
	decisions.append(data)
	if decisions.size() > 4000:
		decisions.pop_front()
	var sample := {"time": stamp(), "latency_ms": decision.time_ms, "nodes": decision.nodes,
			"sims": decision.simulations, "fps": Engine.get_frames_per_second(),
			"cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"algorithm": decision.algorithm}
	perf.append(sample)
	if perf.size() > 2000:
		perf.pop_front()
	decision_logged.emit(data)
	perf_logged.emit(sample)


func export_jsonl() -> String:
	var path := _export_path("jsonl")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	for entry in entries:
		file.store_line(JSON.stringify(entry))
	for entry in decisions:
		file.store_line(JSON.stringify({"kind": "decision", "data": entry}))
	return ProjectSettings.globalize_path(path)


func export_csv() -> String:
	var path := _export_path("csv")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_csv_line(PackedStringArray(["time", "round", "category", "severity", "organism", "message"]))
	for entry in entries:
		file.store_csv_line(PackedStringArray([entry.time, str(entry.round), entry.cat, entry.sev, str(entry.org), entry.msg]))
	return ProjectSettings.globalize_path(path)


func _export_path(extension: String) -> String:
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	return "%s/immune_log_%s.%s" % [EXPORT_DIR, Time.get_datetime_string_from_system().replace(":", "-"), extension]
