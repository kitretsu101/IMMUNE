extends Node
var seen := 0
var info := ""

func _ready() -> void:
	Config.setup = GameSetup.new()
	Config.setup.mode = Sim.Mode.AI_VS_AI
	Config.setup.bact_ai = Sim.Algo.FUZZY
	Config.setup.immune_ai = Sim.Algo.FUZZY
	Config.speed = 16.0
	var scene: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(scene)
	Events.sim_event.connect(func(e: Dictionary) -> void:
		if e.type == "memory":
			seen += 1
			if info == "":
				info = e.msg)
	var world: WorldHost = scene.get_node("Simulation/World")
	var layer: OrganismLayer = scene.get_node("Organisms")
	for i in 600:
		await get_tree().create_timer(0.1).timeout
		if seen > 0 and i % 5 == 0:
			break
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-1000/mem.png")
	var pos := Vector2.ZERO
	for o in world.state.living(Sim.IMMUNE):
		if not o.memory.is_empty():
			var cam: Camera3D = scene.get_node("Camera3D")
			pos = cam.unproject_position(scene.get_node("Board").positions[o.tile])
	print("memcell at ", pos)
	print("memory events: ", seen, " ", info)
	for o in world.state.living(Sim.IMMUNE):
		var v: OrganismView = layer.views.get(o.id)
		print("T cell ", o.id, " memory=", o.memory, " tag='", v.tag_label.text if v else "no view", "' _memory=", v._memory if v else "-")
	get_tree().quit()
