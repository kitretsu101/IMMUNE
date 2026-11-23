extends Node
## Dev helper: exercises HUD, log window, save/load, view modes and scene changes; prints any errors via the engine log.

func _ready() -> void:
	Config.setup = GameSetup.new()
	Config.setup.mode = Sim.Mode.AI_VS_AI
	Config.speed = 8.0
	var scene: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(4.0).timeout
	var window: LogWindow = scene.get_node("LogWindow")
	Events.request_log_window.emit(true)
	await get_tree().create_timer(1.5).timeout
	for mode in 6:
		Config.view_mode = mode
		Events.view_mode_changed.emit(mode)
		await get_tree().create_timer(0.3).timeout
	Config.view_mode = 0
	var persistence: SavePersistence = scene.get_node("Simulation/Persistence")
	persistence.save(1)
	await get_tree().create_timer(1.0).timeout
	persistence.load_slot(1)
	await get_tree().create_timer(2.0).timeout
	var clock: SimClock = scene.get_node("Simulation/Clock")
	clock.set_paused(true)
	await get_tree().create_timer(0.3).timeout
	clock.request_step()
	await get_tree().create_timer(2.0).timeout
	var image := window.get_texture().get_image()
	image.save_png("/tmp/claude-1000/logwin.png")
	window.get_viewport().get_texture()
	print("log window image ", image.get_size(), " entries ", GameLog.entries.size(), " decisions ", GameLog.decisions.size())
	var rounds: RoundManager = scene.get_node("Simulation/Rounds")
	rounds.stop()
	await get_tree().create_timer(0.5).timeout
	rounds.restart()
	await get_tree().create_timer(1.0).timeout
	print("UI TEST OK")
	get_tree().quit()
