class_name IconButton
extends Button
## A button whose glyph is drawn with vector shapes, so it never depends on a font having the symbol.

enum Glyph { PLAY, PAUSE, STOP, STEP, RESTART, SAVE, LOAD, ZOOM_IN, ZOOM_OUT, TARGET, LOG, MENU, CLOSE, CHEVRON_LEFT, CHEVRON_RIGHT, GEAR, EXPAND }

@export var glyph := Glyph.PLAY:
	set(value):
		glyph = value
		queue_redraw()
@export var glyph_color := Neon.TEXT
@export var active_color := Neon.CYAN
@export var glyph_size := 16.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(40, 36)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var tint := glyph_color
	if disabled:
		tint = Neon.TEXT_DIM
	elif button_pressed or is_hovered():
		tint = active_color
	var c := size * 0.5
	var r := glyph_size * 0.5
	match glyph:
		Glyph.PLAY:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0), c + Vector2(-r * 0.6, r)]), tint)
		Glyph.PAUSE:
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r), Vector2(r * 0.55, r * 2)), tint)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r), Vector2(r * 0.55, r * 2)), tint)
		Glyph.STOP:
			draw_rect(Rect2(c - Vector2(r * 0.85, r * 0.85), Vector2(r * 1.7, r * 1.7)), tint)
		Glyph.STEP:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r * 0.5, 0), c + Vector2(-r, r)]), tint)
			draw_rect(Rect2(c + Vector2(r * 0.6, -r), Vector2(r * 0.4, r * 2)), tint)
		Glyph.RESTART:
			draw_arc(c, r * 0.85, deg_to_rad(-60), deg_to_rad(240), 20, tint, 2.2, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, -r * 0.95), c + Vector2(r * 0.95, -r * 0.1), c + Vector2(r * 0.15, -r * 0.35)]), tint)
		Glyph.SAVE:
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), tint, false, 2.0)
			draw_rect(Rect2(c + Vector2(-r * 0.5, -r), Vector2(r, r * 0.7)), tint)
			draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.2), Vector2(r * 1.1, r * 0.8)), tint, false, 1.6)
		Glyph.LOAD:
			draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.35), tint, 2.2, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.05), c + Vector2(r * 0.6, r * 0.05), c + Vector2(0, r * 0.7)]), tint)
			draw_line(c + Vector2(-r, r), c + Vector2(r, r), tint, 2.2)
		Glyph.ZOOM_IN, Glyph.ZOOM_OUT:
			draw_arc(c + Vector2(-r * 0.15, -r * 0.15), r * 0.7, 0, TAU, 24, tint, 2.0, true)
			draw_line(c + Vector2(r * 0.35, r * 0.35), c + Vector2(r, r), tint, 2.4, true)
			draw_line(c + Vector2(-r * 0.45, -r * 0.15), c + Vector2(r * 0.15, -r * 0.15), tint, 2.0)
			if glyph == Glyph.ZOOM_IN:
				draw_line(c + Vector2(-r * 0.15, -r * 0.45), c + Vector2(-r * 0.15, r * 0.15), tint, 2.0)
		Glyph.TARGET:
			draw_arc(c, r * 0.8, 0, TAU, 24, tint, 2.0, true)
			draw_circle(c, r * 0.22, tint)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				draw_line(c + Vector2.from_angle(angle) * r * 0.9, c + Vector2.from_angle(angle) * r * 1.2, tint, 2.0)
		Glyph.LOG:
			for i in 3:
				draw_line(c + Vector2(-r, -r * 0.7 + i * r * 0.7), c + Vector2(r * (1.0 - i * 0.25), -r * 0.7 + i * r * 0.7), tint, 2.0)
		Glyph.MENU:
			for i in 3:
				draw_line(c + Vector2(-r, -r * 0.7 + i * r * 0.7), c + Vector2(r, -r * 0.7 + i * r * 0.7), tint, 2.2)
		Glyph.CLOSE:
			draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.7), tint, 2.2, true)
			draw_line(c + Vector2(r * 0.7, -r * 0.7), c + Vector2(-r * 0.7, r * 0.7), tint, 2.2, true)
		Glyph.CHEVRON_LEFT:
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.4, -r * 0.8), c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.4, r * 0.8)]), tint, 2.4, true)
		Glyph.CHEVRON_RIGHT:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.8), c + Vector2(r * 0.4, 0), c + Vector2(-r * 0.4, r * 0.8)]), tint, 2.4, true)
		Glyph.GEAR:
			draw_arc(c, r * 0.5, 0, TAU, 16, tint, 2.0, true)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c + Vector2.from_angle(a) * r * 0.7, c + Vector2.from_angle(a) * r * 1.0, tint, 2.4)
		Glyph.EXPAND:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.3), c + Vector2(0, -r * 0.5), c + Vector2(r * 0.8, r * 0.3)]), tint, 2.4, true)
