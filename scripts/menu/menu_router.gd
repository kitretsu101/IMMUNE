class_name MenuRouter
extends Control
## Shows one menu screen at a time with a short fade, and keeps a back stack.

signal screen_changed(screen_name: String)

@export var start_screen := "Main"

var screens: Dictionary = {}
var current := ""
var _history: Array[String] = []
var _transition: Tween


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		if child.has_meta("screen") or child is Control and child.name.ends_with("Screen"):
			screens[child.name.trim_suffix("Screen")] = child
			child.visible = false
	Sfx.wire(self)
	Sfx.play_music("menu")
	show_screen(start_screen, false)


func show_screen(screen_name: String, remember := true) -> void:
	if not screens.has(screen_name) or screen_name == current:
		return
	if remember and current != "":
		_history.append(current)
	var previous: Control = screens.get(current)
	var next: Control = screens[screen_name]
	current = screen_name
	if _transition and _transition.is_valid():
		_transition.kill()
	if previous:
		previous.visible = false
	next.visible = true
	if next.has_method("on_show"):
		next.on_show()
	if Config.animations:
		next.modulate.a = 0.0
		_transition = create_tween()
		_transition.tween_property(next, "modulate:a", 1.0, 0.22)
	else:
		next.modulate.a = 1.0
	screen_changed.emit(screen_name)


func back() -> void:
	if _history.is_empty():
		return
	var target: String = _history.pop_back()
	show_screen(target, false)
	Sfx.play_ui("ui_close")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and current != "Main":
		back()
