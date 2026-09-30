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
	if "--only=menu" in OS.get_cmdline_user_args():
		var m := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
		add_child(m)
		await _wait(10)
		m._select_class(&"wizard")
		await _wait(5)
		await _shot("20_main_menu")
		get_tree().quit()
		return
	if "--only=rpg" in OS.get_cmdline_user_args():
		await _rpg_showcase()
		get_tree().quit()
		return
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
	world.day_night.advance_hours(10.0)
	p.health.invulnerable = true
	await _biome_tour(world)
	world.queue_free()
	await _wait(5)
	var menu := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _wait(10)
	await _shot("20_main_menu")
	get_tree().quit()


func _biome_tour(world: World) -> void:
	var g := world.generator
	var p := world.player
	var origin := p.global_position
	world.camera_rig._target_distance = 26.0
	world.camera_rig._target_pitch = 50.0
	var n := 10
	for id in [&"sunscorch_desert", &"snowy_tundra", &"emerald_jungle", &"murk_swamp", &"stonecrown_mountains",
			&"crystal_glade", &"sandy_beach", &"frostpine_taiga", &"whispering_forest"]:
		var spot := _find_biome(g, origin, id)
		if spot == Vector3.INF:
			print("biome not found near spawn: ", id)
			continue
		await _teleport(world, spot)
		await _shot("%02d_biome_%s" % [n, id])
		n += 1
	# Swimming
	for r in range(20, 2000, 20):
		var found := false
		for k in 24:
			var q := origin + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * r
			if g.get_height_at(q) < -2.0 and not g.get_biome_at(q).frozen_water:
				await _teleport(world, Vector3(q.x, TerrainGenerator.WATER_Y - 1.0, q.z))
				await _wait(60)
				await _shot("%02d_swimming" % n)
				n += 1
				found = true
				break
		if found:
			break
	# Map
	world.hud._map.toggle()
	await _wait(90)
	await _shot("%02d_world_map" % n)
	n += 1
	world.hud._map.toggle()
	# Cave
	var e := g.get_cave_entrances_near(floori(origin.x) - 600, floori(origin.z) - 600, floori(origin.x) + 600, floori(origin.z) + 600)
	if not e.is_empty():
		var epos := Vector3(e[0].x + 0.5, g.get_height_blocks(e[0].x, e[0].y) * 0.5, e[0].y + 0.5)
		await _teleport(world, epos + Vector3(3, 0.5, 2))
		world.camera_rig._target_distance = 14.0
		await _wait(40)
		await _shot("%02d_cave_entrance" % n)
		n += 1
		world.travel_to_layer(TerrainGenerator.Layer.UNDERGROUND, epos)
		while not world.is_ready:
			await get_tree().process_frame
		await _wait(60)
		await _shot("%02d_cave_inside" % n)
		n += 1
		world.camera_rig._target_distance = 30.0
		await _wait(40)
		await _shot("%02d_cave_overview" % n)
		n += 1
		world.hud._map.toggle()
		await _wait(90)
		await _shot("%02d_cave_map" % n)
		world.hud._map.toggle()


func _find_biome(g: TerrainGenerator, origin: Vector3, id: StringName) -> Vector3:
	for r in range(40, 6000, 40):
		var steps := maxi(8, r / 20)
		for k in steps:
			var a := TAU * k / steps
			var q := origin + Vector3(cos(a), 0, sin(a)) * r
			var b := g.get_biome_at(q)
			if b.id != id:
				continue
			# Want the biome all around the camera view.
			var ok := true
			for d: Vector3 in [Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(0, 0, 12), Vector3(0, 0, -12)]:
				if g.get_biome_at(q + d).id != id:
					ok = false
			if ok and g.get_height_at(q) > 0.0:
				return q
	return Vector3.INF


func _teleport(world: World, pos: Vector3) -> void:
	var p := world.player
	pos.y = maxf(pos.y, world.get_ground_height(pos) + 0.5)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	world.camera_rig.snap_to_target()
	await _wait(2)
	var frames := 0
	while (not world.chunk_manager.is_near_area_ready() or world.chunk_manager.pending_count() > 0) and frames < 2500:
		await get_tree().process_frame
		frames += 1
	var g := world.get_ground_height(p.global_position)
	if p.global_position.y < g:
		p.global_position.y = g + 0.3
	await _wait(40)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	img.save_png(path)
	print("saved ", path)


## Milestone 3 showcase: every class, its abilities, and the character screen.
func _rpg_showcase() -> void:
	for cid in [&"barbarian", &"knight", &"wizard", &"assassin"]:
		SaveManager.start_transient(GameState.DEFAULT_SEED, cid)
		var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
		add_child(world)
		while not world.is_ready:
			await get_tree().process_frame
		var frames := 0
		while world.chunk_manager.pending_count() > 0 and frames < 1500:
			await get_tree().process_frame
			frames += 1
		var p := world.player
		p.health.invulnerable = true
		world.hud._help.visible = false
		world.camera_rig._target_distance = 11.0
		world.camera_rig._target_pitch = 48.0
		p.character.grant_xp(Progression.total_xp_for(16), Progression.Source.OTHER)
		await _wait(30)
		var dir := p.get_facing()
		var boars: Array[Enemy] = []
		for k in 3:
			var off := dir.rotated(Vector3.UP, (k - 1) * 0.6) * (2.2 if cid == &"barbarian" else 4.5)
			var pos := p.global_position + off
			pos.y = world.get_ground_height(pos) + 0.3
			var b := world.spawner.spawn_enemy(world.debug_enemy_scene, pos, "")
			b.stagger(6.0)
			boars.append(b)
		p.set_lock_target(boars[1])
		await _wait(25)
		match cid:
			&"barbarian":
				p.abilities.set_rage(70.0)
				p.abilities.try_use(0)
				await _wait(12)
			&"knight":
				p.abilities.try_use(0)
				await _wait(6)
			&"wizard":
				p.abilities.try_use(1)
				await _wait(4)
				p.abilities.try_use(0)
				await _wait(5)
			&"assassin":
				p.abilities.try_use(1)
				p.abilities.try_use(2)
				await _wait(10)
		await _shot("30_class_%s" % cid)
		if cid == &"knight":
			var ev := InputEventAction.new()
			ev.action = &"character_screen"
			ev.pressed = true
			Input.parse_input_event(ev)
			await _wait(10)
			await _shot("31_character_screen")
			Input.parse_input_event(ev)
		world.queue_free()
		await _wait(5)
