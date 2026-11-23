extends Node
## Rebuilds res://scenes/menu/main_menu.tscn. Run: godot --headless res://tools/build_menu_scene.tscn

var scene_root: Control


func _ready() -> void:
	scene_root = Control.new()
	scene_root.name = "MainMenu"
	scene_root.set_script(load("res://scripts/menu/menu_router.gd"))
	scene_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_script(load("res://scripts/menu/menu_backdrop.gd"))
	_add(scene_root, backdrop)
	for entry in [["MainScreen", "screen_main"], ["ModeScreen", "screen_mode"], ["ConfigScreen", "screen_config"],
			["LoadScreen", "screen_load"], ["ExperimentScreen", "screen_experiment"], ["StatsScreen", "screen_stats"],
			["SettingsScreen", "screen_settings"]]:
		var screen := Control.new()
		screen.name = entry[0]
		screen.set_script(load("res://scripts/menu/%s.gd" % entry[1]))
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.router = scene_root
		_add(scene_root, screen)
	var packed := PackedScene.new()
	packed.pack(scene_root)
	ResourceSaver.save(packed, "res://scenes/menu/main_menu.tscn")
	print("Saved res://scenes/menu/main_menu.tscn")
	get_tree().quit()


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root
