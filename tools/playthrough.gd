extends Node
## Runs the automated playthrough (tests/playthrough.gd) on a fresh world and
## prints the step log.
##
##   godot --headless --path . res://tools/playthrough.tscn [-- --class=wizard --seed=123]


func _ready() -> void:
	var class_id := &"knight"
	var seed_value := GameState.DEFAULT_SEED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			class_id = StringName(a.substr(8))
		elif a.begins_with("--seed="):
			seed_value = a.substr(7).to_int()
	SaveManager.start_transient(seed_value, class_id)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	var waited := 0
	while not world.is_ready and waited < 1500:
		await get_tree().process_frame
		waited += 1
	var bot := Playthrough.new(get_tree(), world)
	var res: Dictionary = await bot.run()
	print("\n=== Playthrough: %s, seed %d ===" % [class_id, seed_value])
	for line in bot.steps:
		print(line)
	var failed := 0
	for k in res:
		if res[k] is bool and not res[k]:
			failed += 1
	print("=== %d steps failed ===" % failed)
	get_tree().quit(1 if failed > 0 else 0)
