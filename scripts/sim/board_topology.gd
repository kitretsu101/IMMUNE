class_name BoardTopology
extends RefCounted
## The 10x10 offset-row hex graph without any nodes, for headless runs and experiments.

const COLUMNS := 10
const ROWS := 10


static func positions() -> PackedVector3Array:
	var list := PackedVector3Array()
	for tile in COLUMNS * ROWS:
		var row := tile / COLUMNS
		var column := tile % COLUMNS
		list.append(Vector3(-9.5 + column * 2.0 + (1.0 if row % 2 else 0.0), 0.0, -7.7942286 + row * 1.7320508))
	return list


static func adjacency() -> Array:
	var lists: Array = []
	for tile in COLUMNS * ROWS:
		lists.append(PackedInt32Array())
	for tile in COLUMNS * ROWS:
		var row := tile / COLUMNS
		var column := tile % COLUMNS
		var diagonal := column + (1 if row % 2 else -1)
		var links: Array = []
		if column + 1 < COLUMNS:
			links.append(tile + 1)
		if row + 1 < ROWS:
			links.append(tile + COLUMNS)
			if diagonal >= 0 and diagonal < COLUMNS:
				links.append((row + 1) * COLUMNS + diagonal)
		for other in links:
			lists[tile].append(other)
			lists[other].append(tile)
	return lists
