class_name ScreenVignette
extends CanvasLayer
## Cinematic edge darkening drawn over the 3D view and under the HUD.

var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = 2
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = load("res://scenes/shaders/vignette.gdshader")
	rect.material = _material
	add_child(rect)
	Events.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	_material.set_shader_parameter("strength", Config.vignette)
