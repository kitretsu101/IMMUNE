extends SceneTree
## Generates the placeholder sound set into res://assets/audio. Replace any file with a real recording
## using the same name (name_1.wav, name_2.wav ... are random variations) and the game picks it up.
## Run: godot --headless -s tools/generate_sfx.gd

const RATE := 22050
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 424242
	DirAccess.make_dir_recursive_absolute("res://assets/audio/sfx")
	DirAccess.make_dir_recursive_absolute("res://assets/audio/ambient")
	var count := 0
	for entry in catalog():
		var variants: int = entry.variants
		for v in variants:
			var buffer: PackedFloat32Array = entry.fn.call(v)
			buffer = _limit(buffer)
			var suffix := "_%d" % (v + 1) if variants > 1 else ""
			_save("res://assets/audio/sfx/%s%s.wav" % [entry.name, suffix], buffer)
			count += 1
	_save_loop("res://assets/audio/ambient/amb_calm.wav", ambient_calm())
	_save_loop("res://assets/audio/ambient/amb_dark.wav", ambient_dark())
	_save_loop("res://assets/audio/ambient/amb_lab.wav", ambient_lab())
	print("Generated ", count + 3, " files")
	quit()


func catalog() -> Array:
	var list: Array = []
	var add := func(sound_name: String, variants: int, fn: Callable) -> void:
		list.append({"name": sound_name, "variants": variants, "fn": fn})
	# UI
	add.call("ui_hover", 1, func(v: int) -> PackedFloat32Array: return _tone(520, 0.03, "sine", 0.18, 0.002, 0.02))
	add.call("ui_click", 1, func(v: int) -> PackedFloat32Array: return _mix(_noise(0.012, 0.35, 0.5), _tone(700, 0.05, "sine", 0.35, 0.002, 0.04, 0.7)))
	add.call("ui_open", 1, func(v: int) -> PackedFloat32Array: return _tone(420, 0.14, "sine", 0.35, 0.01, 0.06, 2.0))
	add.call("ui_close", 1, func(v: int) -> PackedFloat32Array: return _tone(800, 0.14, "sine", 0.3, 0.01, 0.06, 0.5))
	add.call("ui_select_mode", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(523, 0.12, "tri", 0.35, 0.005, 0.08), _tone(784, 0.18, "tri", 0.35, 0.005, 0.1), 0.09))
	add.call("ui_config", 1, func(v: int) -> PackedFloat32Array: return _tone(1100, 0.05, "sine", 0.25, 0.002, 0.04))
	add.call("ui_start", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(200, 0.45, "saw", 0.18, 0.02, 0.2, 4.0), _mix(_tone(800, 0.3, "sine", 0.25, 0.05, 0.2, 2.0), _noise(0.25, 0.1, 0.25, 0.1, 0.15), 0.1)))
	add.call("ui_pause", 1, func(v: int) -> PackedFloat32Array: return _tone(520, 0.14, "sine", 0.35, 0.005, 0.1, 0.7))
	add.call("ui_stop", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(700, 0.4, "saw", 0.2, 0.01, 0.25, 0.2), _tone(120, 0.35, "sine", 0.4, 0.01, 0.2)))
	add.call("ui_save", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(660, 0.09, "tri", 0.3, 0.003, 0.06), _tone(990, 0.16, "tri", 0.3, 0.003, 0.1), 0.08))
	add.call("ui_load", 1, func(v: int) -> PackedFloat32Array: return _arp([440, 554, 659, 880], 0.07, "tri", 0.3))
	add.call("ui_error", 1, func(v: int) -> PackedFloat32Array: return _tone(150, 0.26, "saw", 0.3, 0.005, 0.15, 0.8))
	add.call("ui_victory", 1, func(v: int) -> PackedFloat32Array: return _arp([523, 659, 784, 1047, 1319], 0.11, "tri", 0.4, 0.5))
	add.call("ui_defeat", 1, func(v: int) -> PackedFloat32Array: return _arp([392, 330, 262, 196], 0.18, "saw", 0.22, 0.45))
	# Bacteria
	add.call("bact_move", 3, func(v: int) -> PackedFloat32Array: return _mix(_lp(_noise(0.14, 0.4, 0.15, 0.03, 0.08), 0.12), _tone(110 + v * 14, 0.14, "sine", 0.28, 0.02, 0.08, 1.5, 22.0, 0.25)))
	add.call("bact_infect_try", 2, func(v: int) -> PackedFloat32Array: return _tone(240 + v * 30, 0.1, "tri", 0.35, 0.005, 0.06, 1.3, 40.0, 0.4))
	add.call("bact_infect_ok", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(85, 0.25, "sine", 0.6, 0.004, 0.16), _mix(_tone(300 + v * 40, 0.22, "saw", 0.22, 0.01, 0.12, 2.2), _lp(_noise(0.2, 0.25, 0.1, 0.02, 0.15), 0.2), 0.02), 0.0))
	add.call("bact_reproduce", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(260, 0.2, "sine", 0.4, 0.005, 0.12, 0.5), _tone(260, 0.2, "sine", 0.4, 0.005, 0.12, 1.9), 0.04))
	add.call("bact_mutation", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(400 + v * 90, 0.34, "sine", 0.3, 0.02, 0.18, 2.5, 18.0, 0.5), _tone(613, 0.3, "square", 0.1, 0.02, 0.2, 0.6, 31.0, 0.4)))
	add.call("bact_death", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(330, 0.26, "tri", 0.35, 0.004, 0.2, 0.25), _lp(_noise(0.2, 0.3, 0.3, 0.003, 0.18), 0.3)))
	add.call("bact_eat", 3, func(v: int) -> PackedFloat32Array: return _lp(_noise(0.12, 0.45, 0.08 + v * 0.03, 0.04, 0.06), 0.1))
	add.call("bact_biofilm", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(110, 0.38, "sine", 0.35, 0.08, 0.2, 1.4), _mix(_tone(165, 0.34, "sine", 0.25, 0.1, 0.2, 1.4), _tone(220, 0.3, "sine", 0.18, 0.12, 0.2, 1.4), 0.04), 0.03))
	add.call("bact_signal", 2, func(v: int) -> PackedFloat32Array: return _tone(690 + v * 60, 0.16, "sine", 0.25, 0.01, 0.1, 1.0, 14.0, 0.2))
	add.call("bact_antibiotic", 1, func(v: int) -> PackedFloat32Array: return _mix(_crackle(0.28, 0.35), _tone(900, 0.2, "sine", 0.1, 0.01, 0.15, 0.4)))
	add.call("bact_resistance", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(520, 0.36, "sine", 0.28, 0.03, 0.2, 1.5), _tone(525, 0.36, "sine", 0.28, 0.03, 0.2, 1.5)))
	# Immune
	add.call("imm_move", 3, func(v: int) -> PackedFloat32Array: return _mix(_lp(_noise(0.1, 0.25, 0.1, 0.02, 0.07), 0.1), _tone(300 + v * 25, 0.1, "sine", 0.18, 0.015, 0.06, 1.2)))
	add.call("imm_detect", 2, func(v: int) -> PackedFloat32Array: return _echo(_tone(1200 + v * 100, 0.1, "sine", 0.4, 0.003, 0.08), 0.12, 0.4))
	add.call("imm_activate", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(330, 0.3, "tri", 0.3, 0.02, 0.18, 1.6), _mix(_tone(495, 0.3, "tri", 0.25, 0.04, 0.18, 1.6), _tone(660, 0.3, "tri", 0.2, 0.06, 0.18, 1.6), 0.03), 0.0))
	add.call("imm_signal", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(900, 0.05, "sine", 0.3, 0.003, 0.03), _tone(1130, 0.06, "sine", 0.3, 0.003, 0.04), 0.07))
	add.call("imm_attack", 3, func(v: int) -> PackedFloat32Array: return _mix(_noise(0.07, 0.6, 0.4, 0.001, 0.05), _tone(150 - v * 15, 0.12, "sine", 0.6, 0.002, 0.09, 0.5)))
	add.call("imm_kill", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(1500, 0.22, "saw", 0.22, 0.003, 0.15, 0.2), _mix(_tone(1900 + v * 200, 0.12, "sine", 0.25, 0.003, 0.1), _noise(0.1, 0.25, 0.5, 0.001, 0.08), 0.0), 0.02))
	add.call("imm_miss", 2, func(v: int) -> PackedFloat32Array: return _mix(_lp(_noise(0.09, 0.3, 0.2, 0.002, 0.07), 0.15), _tone(95, 0.09, "sine", 0.3, 0.003, 0.07)))
	add.call("imm_death", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(480, 0.3, "tri", 0.3, 0.004, 0.22, 0.3), _lp(_noise(0.25, 0.2, 0.3, 0.003, 0.2), 0.2)))
	add.call("imm_memory", 1, func(v: int) -> PackedFloat32Array: return _echo(_arp([784, 1047], 0.09, "sine", 0.3), 0.14, 0.35))
	add.call("imm_clone", 2, func(v: int) -> PackedFloat32Array: return _mix(_tone(240, 0.18, "sine", 0.4, 0.004, 0.1, 2.0), _tone(480, 0.18, "sine", 0.25, 0.004, 0.1, 1.3), 0.03))
	# Environment
	add.call("env_absorb", 2, func(v: int) -> PackedFloat32Array: return _lp(_noise(0.1, 0.25, 0.07, 0.03, 0.05), 0.08))
	add.call("env_oxygen", 1, func(v: int) -> PackedFloat32Array: return _tone(140, 0.5, "sine", 0.25, 0.2, 0.25, 1.15))
	add.call("env_infect", 2, func(v: int) -> PackedFloat32Array: return _lp(_mix(_noise(0.5, 0.35, 0.1, 0.15, 0.3), _tone(70 + v * 6, 0.5, "sine", 0.3, 0.2, 0.25)), 0.08))
	add.call("env_damage", 2, func(v: int) -> PackedFloat32Array: return _crackle(0.2, 0.4))
	add.call("env_destroy", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(55, 0.5, "sine", 0.7, 0.003, 0.35, 0.5), _lp(_noise(0.5, 0.45, 0.1, 0.003, 0.4), 0.1)))
	add.call("env_chem", 2, func(v: int) -> PackedFloat32Array: return _arp([600 + v * 80, 780, 520, 690], 0.05, "sine", 0.2, 0.3))
	add.call("env_antibiotic", 1, func(v: int) -> PackedFloat32Array: return _lp(_noise(0.45, 0.3, 0.45, 0.1, 0.3), 0.4))
	add.call("env_biofilm", 1, func(v: int) -> PackedFloat32Array: return _lp(_mix(_noise(0.35, 0.25, 0.1, 0.1, 0.2), _tone(130, 0.35, "sine", 0.25, 0.1, 0.2, 1.3)), 0.1))
	# Notifications (louder, more distinct, always tonal)
	add.call("notify_mutation", 1, func(v: int) -> PackedFloat32Array: return _arp([392, 622, 988, 1568], 0.08, "square", 0.17, 0.5))
	add.call("notify_strain", 1, func(v: int) -> PackedFloat32Array: return _mix(_arp([440, 554, 880], 0.1, "tri", 0.35, 0.4), _tone(110, 0.5, "sine", 0.35, 0.02, 0.3)))
	add.call("notify_infection", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(110, 0.5, "saw", 0.28, 0.02, 0.3, 0.7), _echo(_tone(220, 0.15, "saw", 0.3, 0.005, 0.1), 0.18, 0.4)))
	add.call("notify_immune_active", 1, func(v: int) -> PackedFloat32Array: return _arp([523, 659, 784], 0.1, "tri", 0.35, 0.5))
	add.call("notify_resistance", 1, func(v: int) -> PackedFloat32Array: return _mix(_arp([300, 450, 300, 600], 0.09, "square", 0.17, 0.4), _tone(70, 0.5, "sine", 0.3, 0.01, 0.3)))
	add.call("notify_bact_collapse", 1, func(v: int) -> PackedFloat32Array: return _arp([784, 659, 523, 392, 262], 0.1, "tri", 0.3, 0.5))
	add.call("notify_immune_collapse", 1, func(v: int) -> PackedFloat32Array: return _arp([392, 311, 233, 175, 117], 0.12, "saw", 0.2, 0.5))
	add.call("notify_victory", 1, func(v: int) -> PackedFloat32Array: return _echo(_arp([523, 659, 784, 1047, 1319, 1568], 0.12, "tri", 0.4, 0.8), 0.25, 0.35))
	add.call("notify_defeat", 1, func(v: int) -> PackedFloat32Array: return _echo(_arp([392, 349, 311, 262, 196, 130], 0.17, "saw", 0.22, 0.8), 0.3, 0.35))
	add.call("pickup", 2, func(v: int) -> PackedFloat32Array: return _echo(_mix(_tone(330 + v * 40, 0.14, "sine", 0.4, 0.005, 0.1, 1.5), _tone(494 + v * 40, 0.2, "sine", 0.35, 0.005, 0.14), 0.07), 0.12, 0.3))
	add.call("memory_gain", 1, func(v: int) -> PackedFloat32Array: return _mix(_tone(262, 0.4, "sine", 0.4, 0.02, 0.25), _arp([330, 392, 523], 0.09, "sine", 0.3, 0.4), 0.0))
	add.call("amb_bubble", 3, func(v: int) -> PackedFloat32Array: return _tone(300 + v * 160 + rng.randf_range(0, 80), 0.09, "sine", 0.18, 0.004, 0.07, 1.8))
	return list


# --- Synthesis primitives -----------------------------------------------------------------------

## Pulls everything above ~500 Hz down so nothing is shrill.
func _soften(freq: float) -> float:
	return freq if freq < 500.0 else minf(500.0 + (freq - 500.0) * 0.4, 820.0)


func _wave(kind: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		"square": return 1.0 if p < 0.5 else -1.0
		"tri": return 4.0 * absf(p - 0.5) - 1.0
		"saw": return 2.0 * p - 1.0
	return sin(p * TAU)


func _tone(freq: float, dur: float, kind := "sine", vol := 0.4, attack := 0.005, release := 0.05,
		sweep := 1.0, vib_hz := 0.0, vib_depth := 0.0) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var progress := t / dur
		var f := _soften(freq * lerpf(1.0, sweep, progress))
		if vib_hz > 0.0:
			f *= 1.0 + sin(t * TAU * vib_hz) * vib_depth * 0.1
		phase += f / RATE
		var envelope := minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))
		out[i] = _wave(kind, phase) * vol * envelope
	return out


func _noise(dur: float, vol := 0.3, smooth := 0.5, attack := 0.003, release := 0.05) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		var t := float(i) / RATE
		last = lerpf(last, rng.randf_range(-1.0, 1.0), clampf(smooth * 0.5, 0.01, 1.0))
		out[i] = last * vol * minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))
	return out


func _crackle(dur: float, vol: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		if rng.randf() < 0.004:
			var burst := rng.randf_range(0.4, 1.0)
			for j in mini(60, count - i):
				out[i + j] += burst * (rng.randf() * 2.0 - 1.0) * exp(-j / 12.0) * vol
	return out


func _arp(freqs: Array, step: float, kind: String, vol: float, tail := 0.3) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var at := 0.0
	for f in freqs:
		out = _mix(out, _tone(f, step + tail * 0.4, kind, vol, 0.004, step + tail * 0.3), at)
		at += step
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0.0) -> PackedFloat32Array:
	var start := int(offset * RATE)
	var length := maxi(a.size(), b.size() + start)
	var out := PackedFloat32Array()
	out.resize(length)
	for i in a.size():
		out[i] = a[i]
	for i in b.size():
		out[i + start] += b[i]
	return out


func _lp(buffer: PackedFloat32Array, coef: float) -> PackedFloat32Array:
	var out := PackedFloat32Array(buffer)
	var last := 0.0
	for i in out.size():
		last = lerpf(last, out[i], clampf(coef * 2.0, 0.01, 1.0))
		out[i] = last * 1.6
	return out


func _echo(buffer: PackedFloat32Array, delay: float, feedback: float) -> PackedFloat32Array:
	var shift := int(delay * RATE)
	var out := PackedFloat32Array()
	out.resize(buffer.size() + shift * 3)
	for i in buffer.size():
		out[i] += buffer[i]
		out[i + shift] += buffer[i] * feedback
		out[i + shift * 2] += buffer[i] * feedback * feedback
	return out


func _limit(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.001
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	var gain := 0.85 / peak if peak > 0.85 else 1.0
	var out := PackedFloat32Array(buffer)
	var fade := mini(200, out.size() / 4)
	for i in out.size():
		out[i] *= gain
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	return out


func _save(path: String, buffer: PackedFloat32Array) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32000.0))
	stream.data = bytes
	stream.save_to_wav(path)


func _save_loop(path: String, buffer: PackedFloat32Array) -> void:
	_save(path, buffer)


# --- Ambience (seamless loops: whole-cycle frequencies plus crossfaded tails) ------------------------

func _loop_buffer(seconds: float, builder: Callable) -> PackedFloat32Array:
	var length := int(seconds * RATE)
	var fade := int(0.4 * RATE)
	var raw: PackedFloat32Array = builder.call(length + fade)
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[i] * w + raw[length + i] * (1.0 - w)
	return out


func ambient_calm() -> PackedFloat32Array:
	return _loop_buffer(8.0, func(n: int) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(n)
		var low := 0.0
		for i in n:
			var t := float(i) / RATE
			var drone := sin(t * TAU * 55.0) * 0.5 + sin(t * TAU * 82.0) * 0.28 + sin(t * TAU * 110.0 + sin(t * TAU * 0.25)) * 0.12
			low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.05)
			var fluid := low * (0.5 + 0.5 * sin(t * TAU * 0.5)) * 0.5
			out[i] = (drone * 0.22 + fluid * 0.25) * (0.8 + 0.2 * sin(t * TAU * 0.125))
		return out)


func ambient_dark() -> PackedFloat32Array:
	return _loop_buffer(8.0, func(n: int) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(n)
		var low := 0.0
		for i in n:
			var t := float(i) / RATE
			var drone := sin(t * TAU * 41.0) * 0.5 + sin(t * TAU * 58.0) * 0.4 + sin(t * TAU * 87.0 + sin(t * TAU * 0.5) * 2.0) * 0.18
			low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.03)
			var tremolo := 0.7 + 0.3 * sin(t * TAU * 1.0)
			out[i] = (drone * 0.3 + low * 0.35) * tremolo
		return out)


func ambient_lab() -> PackedFloat32Array:
	return _loop_buffer(4.0, func(n: int) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			var hum := sin(t * TAU * 120.0) * 0.5 + sin(t * TAU * 240.0) * 0.18
			var shimmer := sin(t * TAU * 440.0) * 0.02 * (0.5 + 0.5 * sin(t * TAU * 0.5))
			out[i] = (hum * 0.07 + shimmer)
		return out)
