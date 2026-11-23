extends SceneTree
## Generates two original ambient loops (CC0, no samples used) into res://assets/audio/music.
## Run: godot --headless -s tools/generate_music.gd

const RATE := 22050
const MIDI := {"A2": 45, "D2": 38, "F2": 41, "C3": 48, "G2": 43, "Bb2": 46}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio/music")
	# Each chord: root MIDI note, minor/major third, fifth, 7th offset. Bars last 4 seconds.
	_render("res://assets/audio/music/menu.wav", [[57, 3, 7], [53, 4, 7], [48, 4, 7], [55, 4, 7], [57, 3, 7], [53, 4, 7], [52, 3, 7], [55, 4, 7]], 0.5, false)
	_render("res://assets/audio/music/game.wav", [[50, 3, 7], [46, 4, 7], [53, 4, 7], [48, 4, 7], [50, 3, 7], [46, 4, 7], [45, 3, 7], [48, 4, 7]], 0.42, true)
	quit()


func _hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _render(path: String, chords: Array, volume: float, pulse: bool) -> void:
	var bar := 4.0
	var total := int(chords.size() * bar * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	for index in chords.size():
		var chord: Array = chords[index]
		var start := int(index * bar * RATE)
		var notes := [chord[0], chord[0] + chord[1], chord[0] + chord[2]]
		# Pad: soft detuned sines with a slow swell, wrapping past the end back to the start.
		for note in notes:
			for detune in [-0.004, 0.004]:
				_add_tone(buffer, start, _hz(note - 12) * (1.0 + detune), bar + 1.2, 0.045, 1.4, 1.6, 0.0)
		# Bell arpeggio.
		for step in 8:
			var note: int = notes[(step * 3 + (1 if pulse else 0)) % 3] + (12 if step % 4 == 3 else 0)
			var at := start + int(step * bar / 8.0 * RATE)
			_add_tone(buffer, at, _hz(note), 1.6, 0.05, 0.01, 1.4, 3.0)
		if pulse:
			for beat in 4:
				var at := start + int(beat * bar / 4.0 * RATE)
				_add_tone(buffer, at, _hz(chord[0] - 24), 0.9, 0.12, 0.01, 0.8, 5.0)
	var peak := 0.001
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clampf(buffer[i] / peak * volume, -1.0, 1.0) * 32000.0))
	stream.data = bytes
	stream.save_to_wav(path)
	print("wrote ", path)


func _add_tone(buffer: PackedFloat32Array, start: int, freq: float, length: float, vol: float, attack: float, release: float, decay: float) -> void:
	var count := int(length * RATE)
	var total := buffer.size()
	for i in count:
		var t := float(i) / RATE
		var env := minf(1.0, t / maxf(attack, 0.001)) * minf(1.0, (length - t) / maxf(release, 0.001))
		if decay > 0.0:
			env *= exp(-t * decay)
		var sample := sin(TAU * freq * t) * 0.8 + sin(TAU * freq * 2.0 * t) * 0.15
		buffer[(start + i) % total] += sample * env * vol
