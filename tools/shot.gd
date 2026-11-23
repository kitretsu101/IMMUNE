extends Node
## Dev helper: loads a scene, waits, saves a screenshot and quits.
## godot res://tools/shot.tscn -- <scene> <seconds> <png> [mode] [speed]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/game/game.tscn"
	var seconds := float(args[1]) if args.size() > 1 else 4.0
	var out := args[2] if args.size() > 2 else "/tmp/shot.png"
	if args.size() > 3:
		Config.setup.mode = int(args[3])
	if args.size() > 4:
		Config.speed = float(args[4])
	var packed: PackedScene = load(scene_path)
	var instance := packed.instantiate()
	add_child(instance)
	if args.size() > 5 and instance is MenuRouter:
		await get_tree().process_frame
		for name in args[5].split(","):
			(instance as MenuRouter).show_screen(name)
	await get_tree().create_timer(seconds).timeout
	var cam := get_tree().root.find_child("Camera3D", true, false) as CameraController
	if cam:
		print("camera size ", cam.size, " h ", cam.h_offset, " v ", cam.v_offset, " margins ", cam.safe_margins, " zoom ", cam.zoom_factor, " vp ", cam.get_viewport().get_visible_rect().size)
	if cam:
		var b := cam.tile_board
		print("t0 ", cam.unproject_position(b.positions[0]), " t99 ", cam.unproject_position(b.positions[99]), " t9 ", cam.unproject_position(b.positions[9]), " t90 ", cam.unproject_position(b.positions[90]), " keep ", cam.keep_aspect, " proj ", cam.projection)
	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	print("saved ", out, " ", image.get_size())
	get_tree().quit()
