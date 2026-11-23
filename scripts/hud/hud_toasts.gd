class_name HudToasts
extends VBoxContainer
## Stack of short notifications for important biological events.

const MAX_TOASTS := 4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	Events.sim_event.connect(_on_event)
	Events.notify.connect(func(text: String, severity: String) -> void:
		if severity != "info":
			_toast(text, severity))


func _on_event(event: Dictionary) -> void:
	if not Config.event_popups:
		return
	if event.sev == Ev.IMPORTANT or event.sev == Ev.CRITICAL or event.type in ["infect_ok", "mutation", "tissue_destroyed"]:
		_toast(event.msg, event.sev)


func _toast(text: String, severity: String) -> void:
	while get_child_count() >= MAX_TOASTS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var color := Neon.severity_color(severity)
	var card := PanelContainer.new()
	var style := ThemeFactory.box(Color(0.04, 0.07, 0.13, 0.92), Color(color.r, color.g, color.b, 0.8), 10, 1, 0.3, 10)
	style.border_width_left = 4
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiKit.label(text, 14, Neon.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(320, 0)
	card.add_child(label)
	add_child(card)
	if Config.animations:
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.2)
		tween.tween_interval(3.8)
		tween.tween_property(card, "modulate:a", 0.0, 0.6)
		tween.tween_callback(card.queue_free)
	else:
		get_tree().create_timer(4.0).timeout.connect(card.queue_free)
