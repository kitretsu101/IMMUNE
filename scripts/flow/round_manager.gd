class_name RoundManager
extends Node
## Runs the match: round -> immune turn -> bacteria turn -> end-of-round. Human sides wait for input,
## AI sides ask their AiAgent. Everything the world does is reported through Events.sim_event.

signal human_turn_started(side: int)
signal human_turn_ended
signal actions_changed(left: int, total: int)

@export var world: WorldHost
@export var clock: SimClock
@export var gate: AnimationGate
@export var immune_ai: AiAgent
@export var bacteria_ai: AiAgent
@export_range(0.0, 1.0, 0.01) var action_pause := 0.14
@export_range(0.0, 1.0, 0.01) var round_pause := 0.25

var awaiting_human := false
var ap_left := 0
var ap_total := 0
var busy := false
var _run_id := 0
var _human_done := false


func start_match(setup: GameSetup) -> void:
	_run_id += 1
	GameLog.clear()
	world.new_match(setup)
	immune_ai.reset()
	bacteria_ai.reset()
	_begin()


func resume_loaded() -> void:
	_run_id += 1
	immune_ai.reset()
	bacteria_ai.reset()
	_begin()


func restart() -> void:
	start_match(Config.setup)


func stop() -> void:
	if world.state == null or world.state.finished:
		return
	_run_id += 1
	awaiting_human = false
	busy = false
	world.state.finished = true
	world.state.result_text = "Simulation stopped"
	clock.finish(true)
	human_turn_ended.emit()
	Events.game_over.emit({"stopped": true, "text": "Simulation stopped", "winner": 0, "round": world.state.round})


func _begin() -> void:
	clock.start()
	Events.round_changed.emit(world.state.round)
	Events.notify.emit("Round %d" % world.state.round, "info")
	_loop(_run_id)


func _alive(id: int) -> bool:
	return id == _run_id and world.state != null and not world.state.finished


func _loop(id: int) -> void:
	var state := world.state
	if state.side != Sim.BACTERIA:
		await _side_turn(Sim.IMMUNE, id)
	while _alive(id):
		if not _alive(id):
			return
		await _side_turn(Sim.BACTERIA, id)
		if not _alive(id):
			return
		await _end_of_round(id)
		if not _alive(id):
			return
		await _side_turn(Sim.IMMUNE, id)


func _side_turn(team: int, id: int) -> void:
	var state := world.state
	state.side = team
	Events.side_changed.emit(team)
	ap_total = state.setup.immune_actions if team == Sim.IMMUNE else state.setup.bact_actions
	ap_left = ap_total
	actions_changed.emit(ap_left, ap_total)
	if not await clock.checkpoint() or not _alive(id):
		return
	if state.setup.controller_for(team) == "human":
		await _human_turn(team, id)
	else:
		await _ai_turn(team, id)


func _ai_turn(team: int, id: int) -> void:
	var agent := immune_ai if team == Sim.IMMUNE else bacteria_ai
	while ap_left > 0 and _alive(id):
		if not await clock.checkpoint() or not _alive(id):
			return
		Events.status_changed.emit("%s AI thinking…" % Sim.team_name(team))
		var decision := await agent.choose(world.state)
		if not _alive(id):
			return
		Events.status_changed.emit(clock.status_text())
		if decision == null:
			break
		await _perform(decision.chosen, decision, agent)
		if not _alive(id):
			return
		await clock.wait(action_pause)


func _human_turn(team: int, id: int) -> void:
	awaiting_human = true
	_human_done = false
	human_turn_started.emit(team)
	Events.status_changed.emit("%s turn" % Sim.team_name(team))
	while not _human_done and _alive(id):
		await get_tree().process_frame
	awaiting_human = false
	human_turn_ended.emit()


## Called by HumanController. Runs the action, then ends the turn when the budget is spent.
func submit_human_action(action: SimAction) -> void:
	if not awaiting_human or busy:
		return
	var id := _run_id
	busy = true
	await _perform(action, null, null)
	busy = false
	if id != _run_id or world.state.finished:
		return
	if ap_left <= 0 or not _any_legal(world.state.side):
		_human_done = true


func end_human_turn() -> void:
	if awaiting_human and not busy:
		_human_done = true


func _any_legal(team: int) -> bool:
	for organism in world.state.living(team):
		if organism.acted:
			continue
		for action in LogicRules.legal_actions(world.state, organism):
			if action.kind != Sim.Kind.WAIT:
				return true
	return false


func _perform(action: SimAction, decision: Decision, agent: AiAgent) -> void:
	var state := world.state
	var organism := state.get_org(action.org)
	if organism == null:
		return
	var tiles: Array = [organism.tile, action.to, action.target_tile]
	if decision != null:
		organism.last_decision = decision.summary()
		organism.last_decision_scores = decision.scores
		Events.decision_made.emit(decision)
	var events := ActionExecutor.execute(state, action)
	ap_left -= 1
	actions_changed.emit(ap_left, ap_total)
	for event in events:
		_publish(event)
	world.touch()
	if agent != null:
		agent.executed(state, tiles)
	await _wait_gate()
	var over := RoundRules.check_victory(state)
	if not over.is_empty():
		_finish(over)


func _publish(event: Dictionary) -> void:
	state_stamp(event)
	Events.sim_event.emit(event)
	if Config.auto_pause and (event.sev == Ev.IMPORTANT or event.sev == Ev.CRITICAL or event.type == "death"):
		clock.set_paused(true)


func state_stamp(_event: Dictionary) -> void:
	pass


func _wait_gate() -> void:
	while gate.remaining() > 0.0:
		await get_tree().process_frame
		if world.state == null or world.state.finished:
			return


func _end_of_round(id: int) -> void:
	var state := world.state
	if not await clock.checkpoint() or not _alive(id):
		return
	var events := RoundRules.end_of_round(state)
	for event in events:
		_publish(event)
		if event.sev != Ev.INFO or event.type in ["reproduce", "death"]:
			world.touch()
			await _wait_gate()
			await clock.wait(0.08)
	world.touch()
	await _wait_gate()
	Events.round_changed.emit(state.round)
	Events.notify.emit("Round %d" % state.round, "info")
	var over := RoundRules.check_victory(state)
	if not over.is_empty():
		_finish(over)
		return
	if clock.step_pending:
		clock.step_pending = false
		clock.set_paused(true)
	await clock.wait(round_pause)


func _finish(over: Dictionary) -> void:
	var state := world.state
	_publish(over)
	_run_id += 1
	awaiting_human = false
	busy = false
	clock.finish(false)
	human_turn_ended.emit()
	var result := {"stopped": false, "text": state.result_text, "winner": state.winner, "round": state.round,
			"mode": state.setup.mode, "bact_ai": state.setup.bact_ai, "immune_ai": state.setup.immune_ai,
			"bact_peak": state.stats.bact_peak, "mutations": state.stats.mutations,
			"eliminations": state.stats.eliminations, "date": Time.get_datetime_string_from_system(false, true),
			"human_side": state.setup.human_side, "core_infected": state.core_infected(),
			"elapsed": snappedf(state.elapsed, 0.1)}
	Config.record_result(result)
	Events.game_over.emit(result)
