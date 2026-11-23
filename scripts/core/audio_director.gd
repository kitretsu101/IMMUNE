extends Node
## Event-driven audio. Listens to simulation events, never polls organism state.
## Sounds are plain files in res://assets/audio; name_1.wav, name_2.wav ... are random variations.

const SFX_DIR := "res://assets/audio/sfx"
const AMBIENT_DIR := "res://assets/audio/ambient"
const VOICES := 14
enum Priority { LOW, NORMAL, HIGH, CRITICAL }

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer2D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _ambient: Dictionary = {}
var _bubble_timer := Timer.new()
var _infection := 0.0
var _board: TileBoard
var _camera: Camera3D
var _paused_game := false
var _rng := RandomNumberGenerator.new()
var _headless := false
var _music: AudioStreamPlayer
var _music_name := ""

const BUS_LAYOUT := [["SFX", "Master"], ["Ambient", "Master"], ["Music", "Master"], ["UI", "Master"], ["Notify", "Master"],
		["Bacteria", "SFX"], ["Immune", "SFX"], ["Environment", "SFX"]]

## sim event type -> [sound, bus, priority, spatial, min_interval]
const EVENT_MAP := {
	"attack_hit": ["imm_attack", "Immune", Priority.NORMAL, true, 0.05],
	"attack_miss": ["imm_miss", "Immune", Priority.LOW, true, 0.1],
	"infect_try": ["bact_infect_try", "Bacteria", Priority.NORMAL, true, 0.1],
	"infect_ok": ["bact_infect_ok", "Bacteria", Priority.HIGH, true, 0.1],
	"clone": ["imm_clone", "Immune", Priority.NORMAL, true, 0.1],
	"reproduce": ["bact_reproduce", "Bacteria", Priority.NORMAL, true, 0.12],
	"mutation": ["bact_mutation", "Bacteria", Priority.NORMAL, true, 0.2],
	"pickup": ["pickup", "Bacteria", Priority.HIGH, true, 0.08],
	"eat": ["pickup", "Bacteria", Priority.NORMAL, true, 0.15],
	"biofilm": ["bact_biofilm", "Bacteria", Priority.NORMAL, true, 0.2],
	"chem_signal": ["bact_signal", "Bacteria", Priority.LOW, false, 1.0],
	"antibiotic_hit": ["bact_antibiotic", "Bacteria", Priority.NORMAL, true, 0.2],
	"antigen_detected": ["imm_detect", "Immune", Priority.NORMAL, true, 0.3],
	"memory": ["memory_gain", "Immune", Priority.HIGH, true, 0.3],
	"tissue_spread": ["env_infect", "Environment", Priority.LOW, true, 0.4],
	"tissue_destroyed": ["env_destroy", "Environment", Priority.HIGH, true, 0.3],
	"tissue_cleansed": ["env_damage", "Environment", Priority.LOW, true, 0.3],
	"oxygen_change": ["env_oxygen", "Environment", Priority.LOW, false, 2.0],
	"immune_activation": ["notify_immune_active", "Notify", Priority.HIGH, false, 1.0],
	"infection_surge": ["notify_infection", "Notify", Priority.HIGH, false, 1.0],
	"new_strain": ["notify_strain", "Notify", Priority.HIGH, false, 1.0],
	"resistance": ["notify_resistance", "Notify", Priority.HIGH, false, 1.0],
	"pop_collapse": ["notify_bact_collapse", "Notify", Priority.HIGH, false, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()
	_setup_buses()
	_load_sounds()
	for index in VOICES:
		var player := AudioStreamPlayer2D.new()
		player.max_distance = 4000.0
		player.attenuation = 0.35
		player.panning_strength = 1.0
		add_child(player)
		_players.append(player)
	for index in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "UI"
		add_child(player)
		_ui_players.append(player)
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(_on_bubble)
	add_child(_bubble_timer)
	_start_ambience()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -80.0
	add_child(_music)
	Events.sim_event.connect(_on_sim_event)
	Events.settings_changed.connect(apply_settings)
	Events.game_over.connect(_on_game_over)
	Events.infection_level.connect(_on_infection)
	Events.status_changed.connect(_on_status)
	apply_settings()
	_bubble_timer.start(1.5)


func _setup_buses() -> void:
	for entry in BUS_LAYOUT:
		if AudioServer.get_bus_index(entry[0]) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, entry[0])
			AudioServer.set_bus_send(index, entry[1])
	var ambient_index := AudioServer.get_bus_index("Ambient")
	if AudioServer.get_bus_effect_count(ambient_index) == 0:
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 8000.0
		AudioServer.add_bus_effect(ambient_index, filter)


func _load_sounds() -> void:
	for file in DirAccess.get_files_at(SFX_DIR):
		if not file.ends_with(".wav") and not file.ends_with(".wav.import"):
			continue
		var base := file.trim_suffix(".import").trim_suffix(".wav")
		var stream_name := base
		var regex_end := base.rfind("_")
		if regex_end > 0 and base.substr(regex_end + 1).is_valid_int():
			stream_name = base.substr(0, regex_end)
		var stream := load("%s/%s.wav" % [SFX_DIR, base]) as AudioStream
		if stream == null:
			continue
		if not _sounds.has(stream_name):
			_sounds[stream_name] = []
		if not _sounds[stream_name].has(stream):
			_sounds[stream_name].append(stream)


func _start_ambience() -> void:
	for ambient_name in ["amb_calm", "amb_dark", "amb_lab"]:
		var stream := load("%s/%s.wav" % [AMBIENT_DIR, ambient_name]) as AudioStreamWAV
		if stream == null:
			continue
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Ambient"
		player.volume_db = -80.0
		add_child(player)
		if not _headless:
			player.play()
		_ambient[ambient_name] = player
	_update_ambience(0.0)


func apply_settings() -> void:
	var master := Config.master_volume if Config.audio_enabled else 0.0
	_set_bus("Master", master)
	_set_bus("SFX", Config.sfx_volume)
	_set_bus("Ambient", Config.ambient_volume)
	_set_bus("UI", Config.ui_volume)
	_set_bus("Music", Config.music_volume)
	_set_bus("Notify", Config.sfx_volume)
	_set_bus("Bacteria", Config.bacterial_volume if Config.biological_sfx else 0.0)
	_set_bus("Immune", Config.immune_volume if Config.biological_sfx else 0.0)
	_set_bus("Environment", 1.0 if Config.biological_sfx else 0.0)
	_update_ambience(_infection)


func _set_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func bind_board(board: TileBoard, camera: Camera3D) -> void:
	_board = board
	_camera = camera


func unbind_board() -> void:
	_board = null
	_camera = null


# --- Playing -----------------------------------------------------------------------------------

func has_sound(sound_name: String) -> bool:
	return _sounds.has(sound_name)


func _pick(sound_name: String) -> AudioStream:
	var list: Array = _sounds.get(sound_name, [])
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()] if Config.sound_variation else list[0]


func play_ui(sound_name: String) -> void:
	if _headless or not Config.audio_enabled:
		return
	var stream := _pick(sound_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_name, -1.0)) < 0.04:
		return
	_last_played[sound_name] = now
	for player in _ui_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = 0.85
			player.play()
			return


## Plays a world sound. `tile` places it on the board (stereo pan and distance), -1 for global.
func play_world(sound_name: String, bus: String, priority: int, tile := -1, min_interval := 0.05) -> void:
	if _headless or not Config.audio_enabled:
		return
	var stream := _pick(sound_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var speed := maxf(0.25, Config.speed)
	# At high speeds repetitive low-priority sounds are thinned out, important ones always play.
	var interval := min_interval * (1.0 + (speed - 1.0) * 0.5 if priority <= Priority.NORMAL else 1.0)
	if priority == Priority.LOW and speed >= 4.0 and _rng.randf() < 0.7:
		return
	if now - float(_last_played.get(sound_name, -1.0)) < interval:
		return
	_last_played[sound_name] = now
	var voice := _free_voice(priority)
	if voice == null:
		return
	voice.stream = stream
	voice.bus = bus
	voice.pitch_scale = 0.82 * ((1.0 + _rng.randf_range(-0.05, 0.05)) * (1.0 + minf(0.12, (speed - 1.0) * 0.015)) if Config.sound_variation else 1.0)
	voice.volume_db = 0.0 if priority >= Priority.HIGH else -3.0
	voice.set_meta("priority", priority)
	voice.global_position = _screen_position(tile)
	voice.play()


func _free_voice(priority: int) -> AudioStreamPlayer2D:
	var weakest: AudioStreamPlayer2D = null
	for player in _players:
		if not player.playing:
			return player
		if weakest == null or int(player.get_meta("priority", 0)) < int(weakest.get_meta("priority", 0)):
			weakest = player
	if weakest != null and int(weakest.get_meta("priority", 0)) < priority:
		return weakest
	return null


func _screen_position(tile: int) -> Vector2:
	var center := get_viewport().get_visible_rect().size * 0.5
	if tile < 0 or _board == null or _camera == null or not is_instance_valid(_camera):
		return center
	return _camera.unproject_position(_board.positions[tile])


# --- Event mapping -----------------------------------------------------------------------------

func _on_sim_event(event: Dictionary) -> void:
	if _headless:
		return
	var kind: String = event.type
	match kind:
		"move":
			if Config.biological_sfx:
				var is_immune: bool = event.team == Sim.IMMUNE
				play_world("imm_move" if is_immune else "bact_move", "Immune" if is_immune else "Bacteria",
					Priority.LOW, event.tile2, 0.08)
			return
		"death":
			if not Config.biological_sfx:
				return
			if event.get("victim_team", 0) == Sim.IMMUNE:
				play_world("imm_death", "Immune", Priority.HIGH, event.tile, 0.1)
			else:
				if event.team == Sim.IMMUNE or event.get("other", 0) > 0:
					play_world("imm_kill", "Immune", Priority.HIGH, event.tile, 0.1)
				play_world("bact_death", "Bacteria", Priority.NORMAL, event.tile, 0.1)
			return
		"mutation":
			if event.get("major", false) and Config.event_notifications:
				play_world("notify_mutation", "Notify", Priority.HIGH, -1, 0.8)
			elif Config.biological_sfx:
				play_world("bact_mutation", "Bacteria", Priority.NORMAL, event.tile, 0.2)
			return
	if not EVENT_MAP.has(kind):
		return
	var entry: Array = EVENT_MAP[kind].duplicate()
	if kind == "pickup" and event.team == Sim.IMMUNE:
		entry[1] = "Immune"
	var is_notify: bool = entry[1] == "Notify"
	if is_notify and not Config.event_notifications:
		return
	if not is_notify and not Config.biological_sfx:
		return
	play_world(entry[0], entry[1], entry[2], event.tile2 if kind in ["infect_ok", "infect_try", "tissue_spread"] and event.tile2 >= 0 else event.tile, entry[4])


func _on_game_over(result: Dictionary) -> void:
	if result.get("stopped", false):
		play_ui("ui_stop")
		return
	var setup := Config.setup
	var winner: int = result.get("winner", 0)
	var victory := winner == Sim.IMMUNE
	if setup.mode == Sim.Mode.HUMAN_VS_AI:
		victory = winner == setup.human_side
	if winner == 0:
		play_ui("ui_stop")
	elif Config.event_notifications:
		play_world("notify_victory" if victory else "notify_defeat", "Notify", Priority.CRITICAL, -1, 0.0)
	else:
		play_ui("ui_victory" if victory else "ui_defeat")


func _on_status(text: String) -> void:
	_paused_game = text == "Paused"
	_update_ambience(_infection)


func _on_infection(level: float) -> void:
	_infection = level
	_update_ambience(level)


func _update_ambience(infection: float) -> void:
	var quiet := _paused_game and not Config.ambience_when_paused
	var calm: AudioStreamPlayer = _ambient.get("amb_calm")
	var dark: AudioStreamPlayer = _ambient.get("amb_dark")
	var lab: AudioStreamPlayer = _ambient.get("amb_lab")
	var dark_amount := clampf(infection * 1.8, 0.0, 1.0)
	if calm:
		calm.volume_db = -80.0 if quiet else lerpf(-9.0, -19.0, dark_amount)
	if dark:
		dark.volume_db = -80.0 if quiet else lerpf(-40.0, -11.0, dark_amount)
	if lab:
		lab.volume_db = -80.0 if quiet else -24.0


func _on_bubble() -> void:
	if Config.audio_enabled and not (_paused_game and not Config.ambience_when_paused) and not _headless:
		var stream := _pick("amb_bubble")
		if stream and Config.ambient_volume > 0.01:
			var player := _ui_players[3]
			if not player.playing:
				player.stream = stream
				player.bus = "Ambient"
				player.pitch_scale = _rng.randf_range(0.6, 0.95)
				player.play()
	_bubble_timer.start(_rng.randf_range(0.8, 3.2) * (1.0 + (1.0 - clampf(_infection * 2.0, 0.0, 1.0)) * 0.5))


## Connects hover / click sounds to every button under `root`, including ones added later.
func wire(root: Node) -> void:
	_wire_node(root)
	root.child_entered_tree.connect(_wire_tree_added)


func _wire_tree_added(node: Node) -> void:
	_wire_node(node)


func _wire_node(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sfx_wired"):
		node.set_meta("sfx_wired", true)
		node.mouse_entered.connect(play_ui.bind("ui_hover"))
		node.pressed.connect(play_ui.bind("ui_click"))
	elif node is HSlider and not node.has_meta("sfx_wired"):
		node.set_meta("sfx_wired", true)
		node.drag_ended.connect(func(_changed: bool) -> void: play_ui("ui_config"))
	for child in node.get_children():
		_wire_node(child)
		if child is Container or child is Control:
			if not child.has_meta("sfx_root"):
				child.set_meta("sfx_root", true)
				child.child_entered_tree.connect(_wire_tree_added)


## Plays "menu" or "game" music, fading between tracks. Files live in res://assets/audio/music.
func play_music(track: String) -> void:
	if _headless or track == _music_name:
		return
	_music_name = track
	var stream := load("res://assets/audio/music/%s.wav" % track) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -60.0, 0.8)
	tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = -60.0
		_music.play())
	tween.tween_property(_music, "volume_db", -6.0, 1.5)
