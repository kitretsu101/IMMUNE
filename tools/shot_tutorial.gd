extends Node

func _ready() -> void:
	Config.setup = GameSetup.new()
	Config.setup.mode = Sim.Mode.HUMAN_VS_AI
	Config.setup.human_side = 1
	Config.speed = 1.0
	Config.tutorial = true

	var scene: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(scene)

	# Wait for setup and tree to initialize
	await get_tree().create_timer(1.5).timeout

	var tut: HudTutorial = scene.find_child("Tutorial", true, false)
	if tut == null:
		print("ERROR: HudTutorial not found!")
		get_tree().quit(1)
		return

	var out_dir := "res://screenshots/tutorial"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var total_steps: int = tut._steps.size()
	print("Found %d tutorial steps. Capturing..." % total_steps)

	for i in total_steps:
		tut._show_step(i)
		# Allow lerp animations to settle (card position, spotlight)
		await get_tree().create_timer(0.35).timeout
		await get_tree().process_frame
		await get_tree().process_frame

		var img := get_viewport().get_texture().get_image()
		var title: String = tut._steps[i][0]
		var slug := ""
		for c in title.to_lower():
			if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
				slug += c
			elif c == " " or c == "-":
				slug += "_"
		while "__" in slug:
			slug = slug.replace("__", "_")
		slug = slug.strip_edges()
		var file_path := "res://screenshots/tutorial/step_%02d_%s.png" % [i + 1, slug]
		var abs_path := ProjectSettings.globalize_path(file_path)
		img.save_png(abs_path)
		print("Captured: ", file_path)

	# Finish tutorial and capture the live playable board
	tut._finish()
	await get_tree().create_timer(0.5).timeout

	var human: HumanController = scene.find_child("Human", true, false)
	var world: WorldHost = scene.find_child("World", true, false)
	if human and world and world.state:
		var cells := world.state.living(world.state.side)
		if not cells.is_empty():
			human.select(cells[0].id)
			human.set_mode(HumanController.ActionMode.MOVE)
			await get_tree().create_timer(0.5).timeout
			var img_live := get_viewport().get_texture().get_image()
			var live_path := ProjectSettings.globalize_path("res://screenshots/tutorial/step_%02d_interactive_turn.png" % (total_steps + 1))
			img_live.save_png(live_path)
			print("Captured: ", live_path)

	print("ALL TUTORIAL SCREENSHOTS SAVED SUCCESSFULLY!")
	get_tree().quit(0)
