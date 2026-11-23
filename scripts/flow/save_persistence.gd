class_name SavePersistence
extends Node
## Save and load of the running simulation.

@export var world: WorldHost
@export var rounds: RoundManager


func save(slot: int) -> void:
	if world.state == null:
		return
	if Config.write_save(slot, world.serialize()):
		Sfx.play_ui("ui_save")
		Events.notify.emit("Simulation saved to slot %d" % slot, "info")
	else:
		Sfx.play_ui("ui_error")
		Events.notify.emit("Could not write the save file", "critical")


func load_slot(slot: int) -> void:
	var data := Config.read_save(slot)
	if data.is_empty():
		Sfx.play_ui("ui_error")
		Events.notify.emit("No save in slot %d" % slot, "important")
		return
	load_data(data)
	Sfx.play_ui("ui_load")
	Events.notify.emit("Loaded slot %d" % slot, "info")


func load_data(data: Dictionary) -> void:
	rounds._run_id += 1
	GameLog.clear()
	Config.setup = GameSetup.from_dict(data.setup)
	world.restore(data)
	rounds.resume_loaded()
