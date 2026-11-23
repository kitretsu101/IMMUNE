class_name WorldHost
extends Node
## Owns the WorldState for the running match and rebuilds it from a setup or a save.

signal world_rebuilt
signal world_changed

@export var tile_board: TileBoard

var state: WorldState


func new_match(setup: GameSetup) -> void:
	tile_board.set_active_size(setup.board_size)
	state = WorldBuilder.build(setup, tile_board.neighbors, tile_board.positions)
	world_rebuilt.emit()
	Events.state_changed.emit()


func restore(data: Dictionary) -> void:
	var setup := GameSetup.from_dict(data.setup)
	tile_board.set_active_size(setup.board_size)
	state = WorldBuilder.build(setup, tile_board.neighbors, tile_board.positions)
	state.load_dict(data)
	state.setup = setup
	world_rebuilt.emit()
	Events.state_changed.emit()


func serialize() -> Dictionary:
	return state.to_dict() if state else {}


## Call after any change so views and panels refresh.
func touch() -> void:
	world_changed.emit()
	Events.state_changed.emit()
	if state:
		Events.infection_level.emit(state.tissue_fraction(Sim.Tissue.INFECTED) + state.tissue_fraction(Sim.Tissue.DESTROYED) * 0.5)
