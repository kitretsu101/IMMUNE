extends Node
## godot --headless res://tools/balance_test.tscn -- <bact_ai> <immune_ai> <runs>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var setup := GameSetup.new()
	setup.bact_ai = int(args[0]) if args.size() > 0 else 1
	setup.immune_ai = int(args[1]) if args.size() > 1 else 1
	setup.max_rounds = 60
	var runner := ExperimentRunner.new()
	add_child(runner)
	runner.finished.connect(func(summary: Dictionary) -> void:
		print("RESULT ", summary)
		get_tree().quit())
	runner.run(setup, int(args[2]) if args.size() > 2 else 20)
