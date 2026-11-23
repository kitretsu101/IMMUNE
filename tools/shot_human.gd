extends Node
## Dev helper: Human vs AI screenshot with a selected organism and highlighted targets.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Config.setup = GameSetup.new()
	Config.setup.mode = Sim.Mode.HUMAN_VS_AI
	Config.setup.human_side = int(args[0]) if args.size() > 0 else 1
	Config.speed = 4.0
	Config.tutorial = args.size() > 2 and args[2] == "tut"
	var scene: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	var human: HumanController = scene.get_node("Simulation/Human")
	var world: WorldHost = scene.get_node("Simulation/World")
	var first := world.state.living(world.state.side)
	if not first.is_empty():
		human.select(first[0].id)
	if args.size() > 1 and args[1] == "clone":
		human.set_mode(HumanController.ActionMode.CLONE)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-1000/human.png")
	print("targets ", human.targets.size(), " sel ", human.selected_id, " mode ", human.action_mode, " can ", human.can_control())
	print("saved")
	get_tree().quit()
