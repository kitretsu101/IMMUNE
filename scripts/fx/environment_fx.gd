class_name EnvironmentFx
extends WorldEnvironment
## Dark neon environment. Bloom is tuned so only the "high" tier (organisms, active infection, important
## events) crosses the HDR threshold; grid and tissue stay below it and glow softly through emission only.

@export var background := Color("#080B14")
@export var ambient := Color(0.35, 0.5, 0.8)
@export_range(0.0, 2.0, 0.01) var ambient_energy := 0.55
@export_group("Bloom")
## Emission above this value blooms. Keep above the grid and tissue emission.
@export_range(0.2, 3.0, 0.01) var hdr_threshold := 1.05
@export_range(0.0, 2.0, 0.01) var base_intensity := 0.55
@export_range(0.0, 2.0, 0.01) var strength := 1.0
@export_range(0.0, 1.0, 0.01) var bloom := 0.0
@export_group("Idle")
## Very slow breathing of the bloom so the scene is never frozen.
@export_range(0.0, 0.2, 0.005) var breathe_amount := 0.04
@export var breathe_hz := 0.12


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = hdr_threshold
	env.glow_hdr_scale = 1.6
	env.glow_strength = strength
	env.glow_bloom = bloom
	for level in 7:
		env.set_glow_level(level, [0.0, 0.5, 1.0, 0.8, 0.4, 0.15, 0.0][level])
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	environment = env
	Events.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	environment.glow_enabled = Config.glow_level > 0.0
	environment.glow_intensity = base_intensity * Config.glow_level


func _process(_delta: float) -> void:
	if environment and Config.animations:
		var wave := sin(Time.get_ticks_msec() / 1000.0 * TAU * breathe_hz)
		environment.glow_intensity = base_intensity * Config.glow_level * (1.0 + wave * breathe_amount)
