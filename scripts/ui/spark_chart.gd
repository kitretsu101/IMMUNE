class_name SparkChart
extends Control
## A tiny neon line chart. Feed it values; it scales and draws them with a soft glow.

@export var line_color := Neon.CYAN
@export var secondary_color := Neon.GREEN
@export var fill_under := true
@export var max_points := 80
@export var min_range := 4.0
@export var show_grid := true

var series_a: Array[float] = []
var series_b: Array[float] = []


func _init() -> void:
	custom_minimum_size = Vector2(120, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	series_a.clear()
	series_b.clear()
	queue_redraw()


func push(a: float, b := NAN) -> void:
	series_a.append(a)
	if series_a.size() > max_points:
		series_a.pop_front()
	if not is_nan(b):
		series_b.append(b)
		if series_b.size() > max_points:
			series_b.pop_front()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.035, 0.07, 0.6))
	if show_grid:
		for i in 1 + 3:
			var y := rect.size.y * i / 4.0
			draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(0.3, 0.5, 0.7, 0.12), 1.0)
	var top := min_range
	for value in series_a:
		top = maxf(top, value)
	for value in series_b:
		top = maxf(top, value)
	_plot(series_a, line_color, top)
	_plot(series_b, secondary_color, top)
	draw_string(ThemeDB.fallback_font, Vector2(4, 12), "%d" % int(top), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Neon.TEXT_DIM)


func _plot(series: Array[float], color: Color, top: float) -> void:
	if series.size() < 2:
		return
	var points := PackedVector2Array()
	for index in series.size():
		var x := size.x * index / float(max_points - 1)
		var y := size.y - 4.0 - (size.y - 10.0) * series[index] / top
		points.append(Vector2(x, y))
	if fill_under and color == line_color:
		var area := PackedVector2Array(points)
		area.append(Vector2(points[-1].x, size.y))
		area.append(Vector2(points[0].x, size.y))
		draw_colored_polygon(area, Color(color.r, color.g, color.b, 0.1))
	draw_polyline(points, Color(color.r, color.g, color.b, 0.25), 5.0, true)
	draw_polyline(points, color, 1.8, true)
	draw_circle(points[-1], 3.0, color)
