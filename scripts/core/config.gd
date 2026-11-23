extends Node
## Current match setup, persisted user settings, save slots and statistics.

const SETTINGS_PATH := "user://settings.cfg"
const STATS_PATH := "user://stats.json"
const SAVE_DIR := "user://saves"

var setup := GameSetup.new()
var load_pending := ""
var tutorial := false
var view_mode := Events.View.NORMAL

# Audio
var master_volume := 0.8
var sfx_volume := 0.9
var ambient_volume := 0.5
var music_volume := 0.5
var ui_volume := 0.7
var bacterial_volume := 1.0
var immune_volume := 1.0
var biological_sfx := true
var event_notifications := true
var audio_enabled := true
var sound_variation := true
var ambience_when_paused := true
# Graphics
var glow_level := 0.8
var vignette := 0.5
var particles := true
var animations := true
var fullscreen := false
var show_fps := false
# Simulation
var auto_pause := false
var pause_on_selection := false
var event_popups := true
var unlimited_speed := false
var speed := 1.0

const PERSISTED := ["master_volume", "sfx_volume", "ambient_volume", "music_volume", "ui_volume", "bacterial_volume",
	"immune_volume", "biological_sfx", "event_notifications", "audio_enabled", "sound_variation",
	"ambience_when_paused", "glow_level", "vignette", "particles", "animations", "fullscreen",
	"show_fps", "auto_pause", "pause_on_selection", "event_popups"]


func _ready() -> void:
	load_settings()
	_apply_window()


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	for key in PERSISTED:
		if file.has_section_key("settings", key):
			set(key, file.get_value("settings", key))
	if file.has_section("setup"):
		var data := {}
		for key in file.get_section_keys("setup"):
			data[key] = file.get_value("setup", key)
		setup = GameSetup.from_dict(data)


func save_settings() -> void:
	var file := ConfigFile.new()
	for key in PERSISTED:
		file.set_value("settings", key, get(key))
	for key in setup.to_dict():
		file.set_value("setup", key, setup.get(key))
	file.save(SETTINGS_PATH)
	_apply_window()
	Events.settings_changed.emit()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)


# --- Saves -------------------------------------------------------------------------------------

func save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func slot_info(slot: int) -> Dictionary:
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return {"round": data.get("round", 0), "mode": data.get("setup", {}).get("mode", 0),
			"saved": data.get("saved_at", ""), "slot": slot}


func write_save(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var file := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func read_save(slot: int) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	return data if typeof(data) == TYPE_DICTIONARY else {}


# --- Statistics --------------------------------------------------------------------------------

func load_stats() -> Array:
	if not FileAccess.file_exists(STATS_PATH):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(STATS_PATH))
	return data if typeof(data) == TYPE_ARRAY else []


func record_result(result: Dictionary) -> void:
	var all := load_stats()
	all.append(result)
	if all.size() > 500:
		all = all.slice(all.size() - 500)
	var file := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all))


func clear_stats() -> void:
	if FileAccess.file_exists(STATS_PATH):
		DirAccess.remove_absolute(STATS_PATH)
