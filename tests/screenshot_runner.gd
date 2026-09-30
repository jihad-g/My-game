extends Node
## Captures gameplay screenshots for visual checks (needs a real renderer).
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tests/screenshot_runner.tscn -- --out=tests/output
##
## Saves several PNGs: default view, zoomed, rotated, combat, inventory, night.

var _out_dir := "res://tests/output"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	GameState.reset(GameState.DEFAULT_SEED)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	# Let LOD rings finish streaming.
	var frames := 0
	while world.chunk_manager.pending_count() > 0 and frames < 1500:
		await get_tree().process_frame
		frames += 1
	await _wait(30)
	await _shot("01_default")

	world.camera_rig._target_distance = 9.0
	world.camera_rig._target_pitch = 40.0
	await _wait(60)
	await _shot("02_zoomed_in")

	world.camera_rig._target_distance = 40.0
	world.camera_rig._target_pitch = 60.0
	world.camera_rig._target_yaw += 120.0
	await _wait(80)
	await _shot("03_zoomed_out_rotated")

	# Combat: spawn a boar and let it wind up a charge.
	world.camera_rig._target_distance = 14.0
	world.camera_rig._target_pitch = 50.0
	await _wait(40)
	var p := world.player
	var boar := world.spawner.spawn_enemy(world.debug_enemy_scene,
		p.global_position + Vector3(6, 0, 3) + Vector3(0, world.get_ground_height(p.global_position + Vector3(6, 0, 3)) - p.global_position.y + 0.3, 0), "")
	p.set_lock_target(boar)
	p.health.invulnerable = true
	boar.target = p
	boar._set_ai(ThornbackBoar.AI.CHARGE_WINDUP, 5.0)
	await _wait(20)
	await _shot("04a_boar_charge_telegraph")
	boar._set_ai(ThornbackBoar.AI.CHASE)
	await _wait(40)
	p.combat.request(&"light")
	await _wait(8)
	await _shot("04_combat")
	var kit := -1
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"campfire_kit":
			kit = i
	if kit >= 0:
		boar.global_position += Vector3(0, -500, 0)  # clear the stage
		p.face_direction(Vector3(1, 0, 1), true)
		world.place_object(load("res://scenes/world/campfire.tscn"), p.global_position + Vector3(2.0, 0, 1.0))
	await _wait(30)
	var ev := InputEventAction.new()
	ev.action = &"inventory"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(10)
	await _shot("05_inventory_campfire")
	Input.parse_input_event(ev)
	world.day_night.advance_hours(14.0)
	await _wait(20)
	await _shot("06_night")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	img.save_png(path)
	print("saved ", path)
