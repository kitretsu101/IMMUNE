class_name SpatialAudioBridge
extends Node
## Tells the audio director where the board and camera are so sounds pan with the action.

@export var tile_board: TileBoard
@export var camera: Camera3D


func _ready() -> void:
	Sfx.bind_board(tile_board, camera)


func _exit_tree() -> void:
	Sfx.unbind_board()
