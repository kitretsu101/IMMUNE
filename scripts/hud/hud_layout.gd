class_name HudLayout
extends Control
## Places the panels and tells the camera how much of the screen they cover so the board stays centred.

@export var camera: CameraController
@export var top_bar: Control
@export var left_panel: Control
@export var right_panel: Control
@export var bottom_dock: Control
@export var action_panel: Control

var _left_button: IconButton
var _right_button: IconButton

var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action_panel:
		action_panel.resized.connect(_mark)
		action_panel.visibility_changed.connect(_mark)
	for control in [top_bar, left_panel, right_panel, bottom_dock]:
		(control as Control).resized.connect(_mark)
		(control as Control).visibility_changed.connect(_mark)
	get_viewport().size_changed.connect(_mark)
	_left_button = _edge_button(IconButton.Glyph.CHEVRON_LEFT, left_panel, "Show / hide population panel")
	_right_button = _edge_button(IconButton.Glyph.CHEVRON_RIGHT, right_panel, "Show / hide environment panel")
	_mark()


func _edge_button(glyph: int, panel: Control, tip: String) -> IconButton:
	var button := IconButton.new()
	button.glyph = glyph
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(26, 44)
	button.pressed.connect(func() -> void: _toggle(panel))
	add_child(button)
	return button


func _toggle(panel: Control) -> void:
	panel.visible = not panel.visible
	Sfx.play_ui("ui_open" if panel.visible else "ui_close")


func _mark() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var viewport := get_viewport_rect().size
	var left := left_panel.get_global_rect().end.x if left_panel.visible else 0.0
	var right := viewport.x - right_panel.get_global_rect().position.x if right_panel.visible else 0.0
	var top := top_bar.get_global_rect().end.y
	if action_panel and action_panel.visible:
		top = maxf(top, action_panel.get_global_rect().end.y + 40.0)
	var bottom := viewport.y - bottom_dock.get_global_rect().position.y
	camera.set_safe_margins(left + 8.0, top + 8.0, right + 8.0, bottom + 8.0)
	var y := top + 14.0
	_left_button.position = Vector2(left + 4.0, y)
	_left_button.glyph = IconButton.Glyph.CHEVRON_LEFT if left_panel.visible else IconButton.Glyph.CHEVRON_RIGHT
	_right_button.position = Vector2(viewport.x - right - 4.0 - 26.0, y)
	_right_button.glyph = IconButton.Glyph.CHEVRON_RIGHT if right_panel.visible else IconButton.Glyph.CHEVRON_LEFT
