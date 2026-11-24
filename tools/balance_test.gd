extends Node
## godot --headless res://tools/balance_test.tscn -- <bact_ai> <immune_ai> <runs> [setup_field=value ...]
## Example: ... -- 1 1 40 bact_pop=4 immune_actions=1

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var setup := GameSetup.new()
	setup.bact_ai = int(args[0]) if args.size() > 0 else 1
	setup.immune_ai = int(args[1]) if args.size() > 1 else 1
	setup.max_rounds = 60
	for index in range(3, args.size()):
		var pair: PackedStringArray = args[index].split("=")
		if pair.size() == 2 and pair[0].begins_with("Balance."):
			_set_balance(pair[0].trim_prefix("Balance."), float(pair[1]))
			continue
		if pair.size() != 2 or not pair[0] in setup:
			push_error("bad override: " + args[index])
			continue
		var current: Variant = setup.get(pair[0])
		setup.set(pair[0], float(pair[1]) if typeof(current) == TYPE_FLOAT else int(pair[1]))
	var runner := ExperimentRunner.new()
	add_child(runner)
	runner.finished.connect(func(summary: Dictionary) -> void:
		print("RESULT ", summary)
		get_tree().quit())
	runner.run(setup, int(args[2]) if args.size() > 2 else 20)


func _set_balance(key: String, value: float) -> void:
	match key:
		"REPRO_COST": Balance.REPRO_COST = value
		"CLONE_COST": Balance.CLONE_COST = value
		"CLEANSE_ENERGY": Balance.CLEANSE_ENERGY = value
		"HIT_BASE": Balance.HIT_BASE = value
		"MOVE_COST": Balance.MOVE_COST = value
		"UPKEEP": Balance.UPKEEP = value
		"STARVE_DAMAGE": Balance.STARVE_DAMAGE = value
		"START_ENERGY": Balance.START_ENERGY = value
		_: push_error("unknown Balance key: " + key)
