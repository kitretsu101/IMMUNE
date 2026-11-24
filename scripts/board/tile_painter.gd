class_name TilePainter
extends Node
## Translates world state into tile shader parameters and eases between values so tiles never pop.

@export var world: WorldHost
@export var tile_board: TileBoard
@export_range(0.5, 20.0, 0.1) var blend_speed := 5.0
@export var healthy_tint := Color("#0C5260")
@export var core_tint := Color("#6B5410")
@export var hint_pulse_speed := 3.0

var _values: Dictionary = {}
var _hints: Dictionary = {}
var _selected := -1


func _ready() -> void:
	Events.settings_changed.connect(_refresh_glow)
	_refresh_glow()


func _refresh_glow() -> void:
	for tile in tile_board.materials:
		tile_board.materials[tile].set_shader_parameter("glow_scale", Config.glow_level)


func set_hints(hints: Dictionary) -> void:
	_hints = hints


func set_selected_tile(tile: int) -> void:
	_selected = tile


func _process(delta: float) -> void:
	var state := world.state
	if state == null:
		return
	var step := delta * blend_speed
	var view: int = Config.view_mode
	var mutation_tiles := {}
	var immune_tiles := {}
	if view == Events.View.EVOLUTION or view == Events.View.IMMUNE:
		for organism in state.organisms.values():
			if view == Events.View.EVOLUTION and organism.team == Sim.BACTERIA:
				mutation_tiles[organism.tile] = organism.mutations.size() + (1 if organism.generation > 0 else 0)
			elif view == Events.View.IMMUNE and organism.team == Sim.IMMUNE:
				var radius: int = 1 + organism.detection / 3
				for tile in state.within_tiles(4)[organism.tile]:
					if state.distance(organism.tile, tile) <= radius:
						immune_tiles[tile] = maxf(immune_tiles.get(tile, 0.0), 1.0 if organism.has_effect("Activated") else 0.45)
				immune_tiles[organism.tile] = 1.0
	for tile in state.count:
		if state.active[tile] == 0:
			continue
		var tissue := state.tissue[tile]
		var target := {
			"infection": 1.0 if tissue == Sim.Tissue.INFECTED else 0.0,
			"damage": 1.0 if tissue == Sim.Tissue.DAMAGED else 0.0,
			"destroyed": 1.0 if tissue == Sim.Tissue.DESTROYED else 0.0,
			"nutrient": clampf(state.nutrients[tile] / 1.5, 0.0, 1.0),
			"biofilm": float(state.biofilm[tile]),
			"hint": float(_hints[tile].amount) if _hints.has(tile) else 0.0,
			"selected": 1.0 if tile == _selected else 0.0,
			"overlay_amount": 0.0,
		}
		var overlay := Color.BLACK
		match view:
			Events.View.INFECTION:
				overlay = Neon.TISSUE_INFECTED
				target.overlay_amount = target.infection * (0.35 + 0.08 * state.tissue_timer[tile]) + target.damage * 0.15
			Events.View.NUTRIENTS:
				overlay = Neon.NUTRIENT
				target.overlay_amount = target.nutrient * 0.7
			Events.View.IMMUNE:
				overlay = Neon.IMMUNE
				target.overlay_amount = float(immune_tiles.get(tile, 0.0)) * 0.45
			Events.View.EVOLUTION:
				overlay = Neon.PURPLE
				target.overlay_amount = clampf(0.25 * float(mutation_tiles.get(tile, 0)), 0.0, 0.9)
		var material: ShaderMaterial = tile_board.materials[tile]
		var current: Dictionary = _values.get(tile, {})
		var tint := core_tint if state.core.has(tile) else healthy_tint
		for key in target:
			var now: float = current.get(key, 0.0)
			var next := move_toward(now, target[key], step * (2.0 if key == "hint" else 1.0))
			if absf(next - now) > 0.0005 or not current.has(key):
				current[key] = next
				material.set_shader_parameter(key, next)
		material.set_shader_parameter("overlay_color", overlay)
		material.set_shader_parameter("tissue_tint", tint)
		material.set_shader_parameter("seed", fmod(tile * 0.6180339, 1.0))
		if _hints.has(tile):
			material.set_shader_parameter("hint_color", _hints[tile].color)
		_values[tile] = current
