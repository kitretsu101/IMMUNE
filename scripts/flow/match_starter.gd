class_name MatchStarter
extends Node
## Starts the configured match when the game scene opens, and handles leaving back to the menu.

@export var rounds: RoundManager
@export var persistence: SavePersistence
@export var human: HumanController

const MENU := "res://scenes/menu/main_menu.tscn"


func _ready() -> void:
	Events.request_menu.connect(go_to_menu)
	Sfx.play_music("game")
	await get_tree().process_frame
	if Config.load_pending != "":
		var slot := int(Config.load_pending)
		Config.load_pending = ""
		persistence.load_slot(slot)
	else:
		rounds.start_match(Config.setup)
		if Config.tutorial:
			Config.tutorial_refs = TutorialStage.stage(rounds.world.state)
			rounds.world.world_rebuilt.emit()
			rounds.world.touch()
		Sfx.play_ui("ui_start")


func go_to_menu() -> void:
	Sfx.play_ui("ui_close")
	rounds.stop()
	Config.save_settings()
	get_tree().change_scene_to_file(MENU)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_L:
			Events.request_log_window.emit(true)
		KEY_P:
			rounds.clock.toggle_pause()
		KEY_PERIOD:
			rounds.clock.request_step()
		KEY_BRACKETRIGHT:
			rounds.clock.cycle_speed(1)
		KEY_BRACKETLEFT:
			rounds.clock.cycle_speed(-1)
