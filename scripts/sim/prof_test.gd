extends SceneTree

func _initialize() -> void:
	var positions := PackedVector3Array()
	var adjacency: Array = []
	for tile in 100:
		var row := tile / 10
		var col := tile % 10
		positions.append(Vector3(-9.5 + col * 2.0 + (1.0 if row % 2 else 0.0), 0.0, -7.79 + row * 1.732))
		adjacency.append(PackedInt32Array())
	for tile in 100:
		var row := tile / 10
		var col := tile % 10
		var diagonal := col + (1 if row % 2 else -1)
		var links: Array = []
		if col + 1 < 10: links.append(tile + 1)
		if row + 1 < 10: links.append(tile + 10)
		if row + 1 < 10 and diagonal >= 0 and diagonal < 10: links.append((row + 1) * 10 + diagonal)
		for other in links:
			adjacency[tile].append(other)
			adjacency[other].append(tile)
	var setup := GameSetup.new()
	setup.rng_seed = 7
	var state := WorldBuilder.build(setup, adjacency, positions)
	# grow population artificially
	for i in 14:
		var tile := state.rng.randi_range(0, 99)
		if state.occupant[tile] == 0 and not state.core.has(tile):
			var b := WorldBuilder.new_bacterium(state, setup, 0)
			state.add_organism(b, tile)
	for i in 8:
		var tile := state.rng.randi_range(0, 99)
		if state.occupant[tile] == 0 and not state.core.has(tile):
			state.add_organism(WorldBuilder.new_immune(state, setup), tile)
	var t := Time.get_ticks_usec()
	var n := 0
	for algo in [0, 1, 2, 3, 4]:
		t = Time.get_ticks_usec()
		n = 0
		for team in [1, 2]:
			for o in state.living(team):
				TacticalAI.decide(state, o, algo)
				n += 1
		printerr("algo ", algo, " decisions ", n, " avg ms ", (Time.get_ticks_usec() - t) / 1000.0 / n)
	t = Time.get_ticks_usec()
	for i in 20:
		RoundRules.end_of_round(state)
	printerr("end_of_round avg ms ", (Time.get_ticks_usec() - t) / 1000.0 / 20)
	t = Time.get_ticks_usec()
	for i in 200:
		state.living(1)
	printerr("living avg us ", (Time.get_ticks_usec() - t) / 200.0)
	quit()
