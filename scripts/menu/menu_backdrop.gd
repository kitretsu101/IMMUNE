class_name MenuBackdrop
extends ColorRect
## Animated microscopic backdrop: shader field plus a few drifting organisms drawn in code.

@export_range(2, 30) var organisms := 12
@export_range(0.0, 2.0, 0.05) var drift_speed := 1.0

var _cells: Array = []
var _time := 0.0
var _life: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = load("res://scenes/shaders/backdrop.gdshader")
	color = Neon.BACKGROUND
	var art := TextureRect.new()
	art.texture = load("res://assets/ui/menu_bg.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1, 1, 1, 0.9)
	add_child(art)
	_life = Control.new()
	_life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life.draw.connect(_draw_life)
	add_child(_life)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for index in organisms:
		_cells.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"vel": Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.006, 0.006)),
			"phase": rng.randf() * TAU,
			"size": rng.randf_range(10.0, 34.0),
			"kind": index % 3,
		})


func _process(delta: float) -> void:
	_time += delta * drift_speed
	for cell in _cells:
		cell.pos += cell.vel * delta * drift_speed
		cell.pos.x = wrapf(cell.pos.x, -0.05, 1.05)
		cell.pos.y = wrapf(cell.pos.y, -0.05, 1.05)
	_life.queue_redraw()


func _draw_life() -> void:
	for cell in _cells:
		var center: Vector2 = Vector2(cell.pos.x * _life.size.x, cell.pos.y * _life.size.y) + Vector2(sin(_time * 0.4 + cell.phase), cos(_time * 0.3 + cell.phase)) * 12.0
		var radius: float = cell.size * (1.0 + 0.06 * sin(_time * 1.2 + cell.phase))
		var tint := Neon.IMMUNE if cell.kind == 0 else (Neon.BACTERIA if cell.kind == 1 else Neon.PURPLE)
		if cell.kind == 1:
			var angle: float = _time * 0.2 + cell.phase
			var dir := Vector2.from_angle(angle)
			for step in 5:
				var offset := dir * (step - 2) * radius * 0.45
				_life.draw_circle(center + offset, radius * 0.38, Color(tint.r, tint.g, tint.b, 0.07))
			_life.draw_line(center - dir * radius, center + dir * radius, Color(tint.r, tint.g, tint.b, 0.35), 2.0, true)
		else:
			_life.draw_circle(center, radius, Color(tint.r, tint.g, tint.b, 0.05))
			_life.draw_arc(center, radius, 0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.32), 1.6, true)
			_life.draw_arc(center, radius * 0.45, 0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.2), 1.2, true)
