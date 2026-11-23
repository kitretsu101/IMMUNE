extends Node
## Dev helper: plays a human-controlled match with random legal actions to smoke-test the flow.
## godot --headless res://tools/play_test.tscn -- <mode> <human_side> <max_frames>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Config.setup = GameSetup.new()
	Config.setup.mode = int(args[0]) if args.size() > 0 else 0
	Config.setup.human_side = int(args[1]) if args.size() > 1 else 1
	Config.setup.max_rounds = 12
	Config.animations = false
	Config.unlimited_speed = true
	Config.speed = 16.0
	var frames_left := int(args[2]) if args.size() > 2 else 4000
	var scene: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: WorldHost = scene.get_node("Simulation/World")
	var rounds: RoundManager = scene.get_node("Simulation/Rounds")
	var human: HumanController = scene.get_node("Simulation/Human")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var submitted := 0
	while frames_left > 0:
		frames_left -= 1
		await get_tree().process_frame
		var state := world.state
		if state == null or state.finished:
			if state and state.finished:
				break
			continue
		if rounds.awaiting_human and not rounds.busy:
			var candidates: Array = []
			for organism in state.living(state.side):
				if not organism.acted:
					candidates.append(organism)
			if candidates.is_empty() or rng.randf() < 0.1:
				rounds.end_human_turn()
				continue
			var organism: Organism = candidates[rng.randi() % candidates.size()]
			human.select(organism.id)
			var actions := LogicRules.legal_actions(state, organism)
			var action: SimAction = actions[rng.randi() % actions.size()]
			rounds.submit_human_action(action)
			submitted += 1
	var state := world.state
	print("RESULT finished=%s round=%d text=%s submitted=%d bact=%d immune=%d log=%d decisions=%d" % [
		state.finished, state.round, state.result_text, submitted, state.count_team(2), state.count_team(1),
		GameLog.entries.size(), GameLog.decisions.size()])
	get_tree().quit()
