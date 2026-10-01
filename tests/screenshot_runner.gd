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
	if "--only=blueprint" in OS.get_cmdline_user_args():
		await _blueprint_showcase()
		get_tree().quit()
		return
	if "--only=advanced" in OS.get_cmdline_user_args():
		await _advanced_showcase()
		get_tree().quit()
		return
	if "--only=multiplayer" in OS.get_cmdline_user_args():
		await _multiplayer_showcase()
		get_tree().quit()
		return
	if "--only=polish" in OS.get_cmdline_user_args():
		await _polish_showcase()
		get_tree().quit()
		return
	if "--only=massive" in OS.get_cmdline_user_args():
		await _massive_showcase()
		get_tree().quit()
		return
	if "--only=explore" in OS.get_cmdline_user_args():
		await _explore_showcase()
		get_tree().quit()
		return
	if "--only=town" in OS.get_cmdline_user_args():
		await _town_showcase()
		get_tree().quit()
		return
	if "--only=build" in OS.get_cmdline_user_args():
		await _build_showcase()
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


## Milestone 4 showcase: a small base, build mode, crafting and chest screens.
func _build_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
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
	world.spawner.max_active = 0
	world.spawner.despawn_all()
	world.hud._help.visible = false
	world.day_night.hour = 10.0
	var o := _flat_area(world, Vector2i(floori(p.global_position.x), floori(p.global_position.z)), Vector2i(9, 10))
	var b := world.building
	await _teleport(world, Vector3(o.x + 4.5, 0, o.y + 7.0))
	# Clear the land first (like a player chopping the trees on their plot).
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is PropBody and n.data.blocks_movement:
			var q: Vector3 = n.global_position
			if q.x > o.x - 2 and q.x < o.x + 11 and q.z > o.y - 2 and q.z < o.y + 12:
				n.chunk.harvest_prop(n.prop_index, null)
	await _wait(5)
	var put := func(id: StringName, cell: Vector2i, slot: String, rot: int = 0) -> BuildPiece:
		return b.place(BuildingManager.get_piece_data(id), o + cell, slot, rot, null, false)
	# 4x4 hut: floor, walls, door, window, half roof, furniture
	for x in 4:
		for z in 4:
			put.call(&"wood_floor", Vector2i(x, z), "floor")
	for x in 4:
		put.call(&"wood_wall", Vector2i(x, 0), "edge_n")
		put.call(&"wood_door" if x == 1 else (&"wood_window" if x == 3 else &"wood_wall"), Vector2i(x, 4), "edge_n")
	for z in 4:
		put.call(&"wood_wall", Vector2i(0, z), "edge_w")
		put.call(&"wood_window" if z == 2 else &"stone_wall", Vector2i(4, z), "edge_w")
	for x in 4:
		for z in 2:
			put.call(&"thatch_roof", Vector2i(x, z), "roof")
	put.call(&"bed", Vector2i(0, 1), "object", 0)
	put.call(&"storage_chest", Vector2i(3, 0), "object", 2)
	put.call(&"table", Vector2i(2, 2), "object")
	put.call(&"chair", Vector2i(2, 3), "object", 2)
	put.call(&"torch", Vector2i(0, 3), "object")
	# Crafting yard
	put.call(&"workbench", Vector2i(6, 0), "object", 1)
	put.call(&"forge", Vector2i(6, 2), "object", 1)
	put.call(&"tailoring", Vector2i(6, 4), "object", 1)
	put.call(&"arcane_altar", Vector2i(8, 2), "object")
	put.call(&"torch", Vector2i(5, 6), "object")
	put.call(&"claim_totem", Vector2i(8, 6), "object")
	# Fence and defenses
	for x in range(-1, 9):
		put.call(&"wood_fence" if x % 4 != 0 else &"spike_wall", Vector2i(x, 8), "edge_n")
	put.call(&"spike_trap", Vector2i(2, 9), "floor")
	put.call(&"spike_trap", Vector2i(3, 9), "floor")
	var stand := Vector3(o.x + 4.5, 0, o.y + 7.0)
	await _teleport(world, stand)
	p.global_position = Vector3(stand.x, world.get_ground_height(stand) + 0.1, stand.z)
	world.camera_rig._target_distance = 17.0
	world.camera_rig._target_pitch = 52.0
	world.camera_rig.snap_to_target()
	await _wait(60)
	await _shot("40_base_overview")
	world.day_night.hour = 21.5
	await _wait(40)
	await _shot("41_base_night")
	world.day_night.hour = 10.0
	# Build mode with a ghost wall
	for id in [&"wood", &"stone", &"plank", &"rope", &"plant_fiber", &"stick", &"clay"]:
		p.inventory.add_item(id, 40)
	world.camera_rig._target_distance = 12.0
	world.build_mode.set_active(true)
	world.build_mode.select(BuildingManager.get_piece_data(&"wood_wall"))
	var ghost_at := p.global_position + Vector3(2.5, 0, 1.5)
	await _wait(30)
	get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(ghost_at))
	await _wait(10)
	await _shot("42_build_mode")
	world.build_mode.set_active(false)
	# Crafting screen next to the stations
	var yard := Vector3(o.x + 5.0, 0, o.y + 2.5)
	p.global_position = Vector3(yard.x, world.get_ground_height(yard) + 0.3, yard.z)
	p.give_item(&"copper_ore", 6)
	p.inventory.add_item(&"coal", 4)
	p.character.skills[Skill.CRAFTING] = 14
	p.character.recalculate()
	await _wait(20)
	world.hud._crafting.toggle()
	world.hud._crafting.select(RecipeBook.get_recipe(&"copper_pickaxe"))
	await _wait(10)
	await _shot("43_crafting_screen")
	world.hud._crafting.toggle()
	# Chest
	var chest: BuildPiece = b.pieces[BuildingManager.key(o + Vector2i(3, 0), "object", 0)]
	chest.storage.add_item(&"iron_ore", 12)
	chest.storage.add_item(&"leather", 5)
	chest.storage.add_item(&"smithing_manual", 1)
	chest.storage.add_item(&"hearty_stew", 3)
	p.global_position = chest.global_position + Vector3(0, 0.3, 1.2)
	await _wait(10)
	chest.interact(p)
	await _wait(10)
	await _shot("44_chest")
	world.queue_free()
	await _wait(5)


## Top-left cell of a dry, fairly flat `size` area near `around`.
func _flat_area(world: World, around: Vector2i, size: Vector2i) -> Vector2i:
	var best := around + Vector2i(3, 0)
	var best_score := 1e9
	for dx in range(-24, 25, 3):
		for dz in range(-24, 25, 3):
			var o := around + Vector2i(dx, dz)
			var lo := 1e9
			var hi := -1e9
			var wet := false
			for x in range(0, size.x + 1, 2):
				for z in range(0, size.y + 1, 2):
					var q := Vector3(o.x + x + 0.5, 0, o.y + z + 0.5)
					var h := world.get_ground_height(q)
					lo = minf(lo, h)
					hi = maxf(hi, h)
					wet = wet or h < TerrainGenerator.WATER_Y + 0.5
			var score := (hi - lo) * 10.0 + Vector2(dx, dz).length() * 0.1
			if not wet and score < best_score:
				best_score = score
				best = o
	return best


## Milestone 5 showcase: villages, a kingdom, townsfolk and the new windows.
func _town_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.hud._help.visible = false
	world.day_night.hour = 10.0
	var green := [&"verdant_meadow", &"whispering_forest", &"emerald_jungle"]
	var sets := world.generator.settlements.near(p.global_position, 4000.0)
	var village: SettlementInfo = null
	var kingdom: SettlementInfo = null
	for s in sets:
		if s.is_kingdom() and kingdom == null and s.biome_id in green:
			kingdom = s
		elif not s.is_kingdom() and village == null and s.biome_id in green:
			village = s
	if village == null:
		village = sets.filter(func(x: SettlementInfo) -> bool: return not x.is_kingdom())[0]
	if kingdom == null:
		kingdom = sets.filter(func(x: SettlementInfo) -> bool: return x.is_kingdom())[0]
	# --- Village
	await _teleport(world, village.world_center() + Vector3(0.5, 0, -1.5))
	world.living.update_now(true)
	world.living.finish_sites()
	var site := world.living.site_of(village)
	await _wait(40)
	world.camera_rig._target_distance = 40.0
	world.camera_rig._target_pitch = 64.0
	await _wait(60)
	await _shot("50_village_overview")
	world.camera_rig._target_distance = 14.0
	world.camera_rig._target_pitch = 46.0
	await _wait(60)
	await _shot("51_village_plaza")
	var merchant := site.npc_by_role(&"merchant")
	p.global_position = site.to_global(merchant.position) + Vector3(0, 0.3, 0) + site.to_global(Vector3(0, 0, 0)).direction_to(site.to_global(merchant.position)) * -1.6
	await _wait(20)
	world.hud._dialogue.open(merchant)
	world.hud._dialogue._say(Gossip.lines(merchant, world.living)[0])
	await _wait(20)
	await _shot("52_dialogue")
	world.hud._dialogue.close()
	p.coins = 2350
	p.inventory.add_item(&"boar_hide", 4)
	p.inventory.add_item(&"copper_ore", 6)
	world.hud._trade.open(merchant)
	await _wait(15)
	await _shot("53_trade")
	world.hud._trade.close()
	world.hud._requests.open(site)
	await _wait(15)
	await _shot("54_notice_board")
	world.hud._requests.close()
	world.hud._map.toggle()
	await _wait(120)
	await _shot("55_map_settlements")
	world.hud._map.toggle()
	p.reputation.add(village, 34.0)
	world.hud._reputation.toggle()
	await _wait(15)
	await _shot("56_reputation")
	world.hud._reputation.toggle()
	world.day_night.hour = 21.0
	for n in site.npcs:
		n._update_activity(true)
	world.camera_rig._target_distance = 26.0
	world.camera_rig._target_pitch = 55.0
	await _wait(60)
	await _shot("57_village_night")
	# --- Kingdom
	world.day_night.hour = 11.0
	await _teleport(world, kingdom.world_center() + Vector3(0.5, 0, 6.0))
	world.living.update_now(true)
	world.living.finish_sites()
	await _wait(40)
	world.camera_rig._target_distance = 42.0
	world.camera_rig._target_pitch = 66.0
	await _wait(60)
	await _shot("58_kingdom_overview")
	var ksite := world.living.site_of(kingdom)
	var noble := ksite.npc_by_role(&"noble")
	p.global_position = ksite.to_global(noble.position + Vector3(0, 0.3, 2.2))
	world.camera_rig._target_distance = 13.0
	world.camera_rig._target_pitch = 50.0
	await _wait(60)
	world.hud._dialogue.open(noble)
	await _wait(15)
	await _shot("59_kingdom_court")
	world.hud._dialogue.close()
	world.queue_free()
	await _wait(5)


## Milestone 6 showcase: ruins, tower, temple, grove, a dungeon and its boss.
func _explore_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.hud._help.visible = false
	world.day_night.hour = 10.0
	var all := world.generator.pois.near(p.global_position, 3000.0)
	var n := 60
	for kind in [PoiInfo.Kind.RUINS, PoiInfo.Kind.TOWER, PoiInfo.Kind.TEMPLE, PoiInfo.Kind.GROVE, PoiInfo.Kind.DUNGEON]:
		var poi: PoiInfo = null
		for q in all:
			if q.kind == kind:
				poi = q
				break
		if poi == null:
			continue
		await _teleport(world, poi.world_center() + Vector3(0, 0, poi.radius * 0.6 + 1.5))
		world.exploration.update_now(true)
		await _wait(30)
		world.camera_rig._target_distance = 20.0 if kind != PoiInfo.Kind.TEMPLE else 26.0
		world.camera_rig._target_pitch = 60.0
		await _wait(60)
		await _shot("%02d_poi_%s" % [n, PoiInfo.KIND_NAMES[kind].to_lower().replace(" ", "_")])
		n += 1
		if kind == PoiInfo.Kind.DUNGEON:
			world.enter_dungeon(poi)
			await _wait(40)
			world.camera_rig._target_distance = 16.0
			await _wait(40)
			await _shot("%02d_dungeon_start" % n)
			n += 1
			var d := world.dungeon
			for i in d.plan.rooms.size():
				if d.plan.rooms[i].type == DungeonPlan.Room.NORMAL:
					p.global_position = d.to_global(d.plan.room_center(i) + Vector3(0, 0.3, 3.0))
					await _wait(50)
					await _shot("%02d_dungeon_room" % n)
					n += 1
					break
			world.hud._map.toggle()
			await _wait(20)
			await _shot("%02d_dungeon_map" % n)
			n += 1
			world.hud._map.toggle()
			# Jump to the last floor's boss arena.
			while not d.plan.is_final:
				world.next_dungeon_floor()
				await _wait(20)
				d = world.dungeon
			for m in d.monsters:
				if is_instance_valid(m) and not m.is_boss() and not m.is_dead:
					m.health.current = 0.0
			p.global_position = d.to_global(d.plan.room_center(d.plan.end_room) + Vector3(0, 0.3, 4.0))
			await _wait(60)
			await _shot("%02d_dungeon_boss" % n)
			n += 1
	world.queue_free()
	await _wait(5)


func _place(world: World, id: StringName, cell: Vector2i, slot: String = "", rot: int = 0) -> BuildPiece:
	var data := BuildingManager.get_piece_data(id)
	if slot == "":
		slot = BuildingManager.slot_kind(data)
		if slot == "edge":
			slot = "edge_n"
	var why := world.building.check_place(data, cell, slot, world.player, false)
	if why != "":
		print("place %s at %s: %s" % [id, cell, why])
		return null
	return world.building.place(data, cell, slot, rot, world.player, false)


func _monster(world: World, id: StringName, pos: Vector3) -> Monster:
	pos.y = world.get_ground_height(pos) + 0.3
	return world.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", load("res://data/enemies/%s.tres" % id)) as Monster


func _clear_monsters(world: World) -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Enemy and e.visible:
			NodePool.release_or_free(e)
	for g in get_tree().get_nodes_in_group(&"ward_pylons"):
		g.queue_free()


func _sec(t: float) -> void:
	await get_tree().create_timer(t).timeout


## A dry, flat spot (size x size m) near `origin`.
func _dry_center(world: World, origin: Vector3, size: float = 30.0) -> Vector3:
	var best := origin
	var best_score := INF
	for r in range(0, 260, 12):
		for k in maxi(1, r / 6):
			var a := TAU * k / maxi(1, r / 6)
			var c := origin + Vector3(cos(a), 0, sin(a)) * r
			var lo := INF
			var hi := -INF
			var wet := false
			for x in range(-int(size / 2), int(size / 2) + 1, 5):
				for z in range(-int(size / 2), int(size / 2) + 1, 5):
					var h := world.get_ground_height(c + Vector3(x, 0, z))
					lo = minf(lo, h)
					hi = maxf(hi, h)
					wet = wet or h < TerrainGenerator.WATER_Y + 0.6
			var score := (hi - lo) * 5.0 + r * 0.02
			if not wet and score < best_score:
				best_score = score
				best = c
		if best_score < 2.0:
			break
	return best


## Direction that is "up" on screen (away from the camera), flattened.
func _screen_up(world: World) -> Vector3:
	var z := world.camera_rig.camera.global_transform.basis.z
	var f := Vector3(-z.x, 0, -z.z)
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


## Milestone 7 showcase: raids, elites, boss mechanics, spells, status effects, rare events.
func _advanced_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"wizard")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.spawner.despawn_all()
	world.hud._help.visible = false
	world.day_night.hour = 17.0
	world.day_night.advance_hours(0.0)
	for i in 14:
		p.character.grant_xp(p.character.xp_needed(), Progression.Source.OTHER)
	p.character.skills[Skill.MANA_CONTROL] = 70
	p.character.recalculate()
	p.mana.max_mana = 600.0
	p.mana.refill()
	world.spawner.max_active = 60
	var meadow := _find_biome(world.generator, p.global_position, &"verdant_meadow")
	await _teleport(world, _dry_center(world, meadow if meadow != Vector3.INF else p.global_position))
	var home := p.global_position
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	# --- Base raid -------------------------------------------------------------------------
	var c := Vector2i(floori(p.global_position.x), floori(p.global_position.z))
	_place(world, &"claim_totem", c + Vector2i(0, 1))
	for dx in range(-3, 4):
		_place(world, &"palisade_wall" if dx % 2 == 0 else &"wood_wall", c + Vector2i(dx, -3), "edge_n")
		_place(world, &"wood_wall", c + Vector2i(dx, 4), "edge_n")
	for dz in range(-3, 4):
		if dz != 0:
			_place(world, &"stone_wall", c + Vector2i(-3, dz), "edge_w")
			_place(world, &"wood_wall", c + Vector2i(4, dz), "edge_w")
	_place(world, &"reinforced_door", c + Vector2i(-3, 0), "edge_w")
	_place(world, &"wood_door", c + Vector2i(4, 0), "edge_w")
	_place(world, &"arrow_tower", c + Vector2i(2, -2))
	_place(world, &"arrow_tower", c + Vector2i(-2, 2))
	_place(world, &"alarm_bell", c + Vector2i(2, 2))
	_place(world, &"storage_chest", c + Vector2i(-1, -2))
	_place(world, &"torch", c + Vector2i(1, 1))
	_place(world, &"bed", c + Vector2i(-2, -1))
	var base := world.raids.find_player_base()
	print("showcase base: ", base)
	if not base.is_empty():
		world.raids.start_base_raid(base, &"bandits")
		await _wait(10)
		await _shot("70_raid_warning")
		world.raids.raid.t = 0.0
		world.camera_rig._target_distance = 26.0
		world.camera_rig._target_pitch = 58.0
		var dir: float = world.raids.raid.dir
		p.global_position = base.center + Vector3(cos(dir), 0, sin(dir)) * 6.0 + Vector3(0, 0.3, 0)
		p.face_direction(Vector3(cos(dir), 0, sin(dir)), true)
		await _sec(9.0)
		await _shot("71_raid_attack")
		for m in world.raids.alive_raiders():
			if m.global_position.distance_to(p.global_position) < 14.0:
				p.set_lock_target(m)
				break
		await _sec(4.0)
		await _shot("72_raid_siege")
		p.set_lock_target(null)
		world.raids._finish(true)
	_clear_monsters(world)
	await _wait(10)
	# --- Elites ----------------------------------------------------------------------------
	world.day_night.hour = 13.0
	world.day_night.advance_hours(0.0)
	await _teleport(world, _dry_center(world, home + Vector3(45, 0, 0), 24.0))
	var fwd := _screen_up(world)
	var affix_sets := [[&"molten", &"frenzied"], [&"glacial"], [&"vampiric"], [&"shielded", &"juggernaut"]]
	var ids := [&"bandit_brute", &"skeleton_warrior", &"bandit_thug", &"arcane_sentinel"]
	var first: Monster = null
	for k in 4:
		var m := _monster(world, ids[k], p.global_position + fwd.rotated(Vector3.UP, -0.9 + k * 0.6) * 5.0)
		if m:
			m.configure(2.0, 1.0, 4, 1.0)
			m.make_elite(affix_sets[k])
			m.stagger(30.0)
			m.face_toward(p.global_position - m.global_position)
			if first == null:
				first = m
	p.face_direction(fwd, true)
	if first:
		p.set_lock_target(first)
	world.camera_rig._target_distance = 15.0
	world.camera_rig._target_pitch = 52.0
	await _wait(90)
	await _shot("73_elites")
	p.set_lock_target(null)
	_clear_monsters(world)
	# --- Boss: ward pylons ---------------------------------------------------------------
	var boss := _monster(world, &"bone_king", p.global_position + fwd * 6.0)
	if boss:
		boss.configure(3.0, 1.0, 6, 1.0)
		boss._alert(p)
		await _wait(40)
		boss.health.current = boss.health.max_health * 0.3
		await _wait(120)
		boss._set_ai(Monster.AI.CHASE)
		boss._raise_ward()
		boss.stagger(6.0)
		world.camera_rig._target_distance = 22.0
		await _wait(60)
		await _shot("74_boss_ward")
		boss._clear_pylons()
		boss._start_special(&"spikes", 4.0, p)
		await _wait(40)
		await _shot("75_boss_spikes")
	_clear_monsters(world)
	await _wait(20)
	var guardian := _monster(world, &"temple_guardian", p.global_position + fwd * 7.0)
	if guardian:
		guardian.configure(3.0, 0.5, 6, 1.0)
		guardian._alert(p)
		await _wait(60)
		guardian._start_beam(p)
		await _sec(1.3)
		await _shot("76_boss_beam")
	_clear_monsters(world)
	await _wait(20)
	# --- Spells & status effects ---------------------------------------------------------
	var targets := []
	for k in 5:
		var side := fwd.cross(Vector3.UP)
		var m := _monster(world, &"skeleton_warrior" if k % 2 == 0 else &"thorn_crawler", p.global_position + fwd * (6.5 + (k % 2) * 1.5) + side * (-3.0 + k * 1.5))
		if m:
			m.configure(30.0, 0.2, 0, 1.0)
			m.stagger(60.0)
			targets.append(m)
	for id in SpellBook.all():
		p.spells.learn(id)
	p.face_direction(fwd, true)
	p.set_lock_target(targets[2] if targets.size() > 2 else null)
	world.camera_rig._target_distance = 17.0
	p.spells.assign(0, &"blizzard")
	p.abilities.try_cast(0)
	await _sec(1.0)
	p.set_lock_target(targets[0] if targets.size() > 0 else null)
	p.spells.assign(1, &"meteor")
	p.abilities.cooldowns.clear()
	p.abilities.try_cast(1)
	p.afflict(&"bleed", 30.0, {"dps": 0.1})
	p.afflict(&"shocked", 30.0)
	p.afflict(&"weakened", 30.0)
	await _sec(0.75)
	await _shot("77_spells_blizzard_meteor")
	await _sec(3.0)
	p.abilities.cooldowns.clear()
	p.spells.assign(0, &"storm_call")
	p.abilities.try_cast(0)
	await _sec(0.8)
	p.abilities.cooldowns.clear()
	p.spells.assign(0, &"arcane_missiles")
	p.abilities.try_cast(0)
	await _sec(0.35)
	await _shot("78_spells_storm_missiles")
	await _sec(2.0)
	p.abilities.cooldowns.clear()
	p.spells.assign(0, &"poison_cloud")
	p.abilities.try_cast(0)
	p.abilities.cooldowns.clear()
	p.spells.assign(1, &"arcane_barrier")
	p.abilities.try_cast(1)
	await _sec(1.0)
	await _shot("79_spells_miasma_barrier")
	p.set_lock_target(null)
	p.spells.assign(0, &"meteor")
	p.spells.assign(1, &"blink")
	world.hud._spellbook.toggle()
	await _wait(10)
	await _shot("80_spellbook")
	world.hud._spellbook.toggle()
	p.status.clear()
	_clear_monsters(world)
	await _wait(20)
	# --- Rare events ----------------------------------------------------------------------
	world.day_night.hour = 21.2
	world.day_night.advance_hours(0.0)
	world.events.start(&"blood_moon")
	for k in 6:
		var a := -1.2 + k * 0.5
		var m := _monster(world, [&"skeleton_warrior", &"skeleton_archer", &"thorn_crawler"][k % 3], p.global_position + fwd.rotated(Vector3.UP, a) * (7.0 + (k % 2) * 2.0))
		if m:
			m.set_meta(&"event", &"horde")
			if k == 2:
				m.make_elite([&"glacial"])
			m._alert(p)
	world.camera_rig._target_distance = 22.0
	await _sec(1.5)
	await _shot("81_blood_moon")
	world.events.stop(&"blood_moon")
	_clear_monsters(world)
	world.day_night.hour = 19.6
	world.day_night.advance_hours(0.0)
	world.events.start(&"meteor_shower")
	var crater := world.events.drop_meteor(p.global_position + fwd * 8.0)
	world.events.spawn_colossus(crater.global_position + fwd.cross(Vector3.UP) * 4.0)
	world.camera_rig._target_distance = 24.0
	await _sec(2.0)
	await _shot("82_meteor_colossus")
	world.events.stop(&"meteor_shower")
	_clear_monsters(world)
	var snow := _find_biome(world.generator, p.global_position, &"snowy_tundra")
	if snow != Vector3.INF:
		await _teleport(world, _dry_center(world, snow, 24.0))
		world.events.start(&"aurora")
		world.day_night.hour = 22.5
		world.day_night.advance_hours(0.0)
		world.camera_rig._target_distance = 30.0
		world.camera_rig._target_pitch = 32.0
		await _sec(1.5)
		await _shot("83_aurora")
		world.camera_rig._target_pitch = 55.0
		world.events.stop(&"aurora")
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	await _teleport(world, _dry_center(world, home, 24.0))
	world.events.start(&"treasure_goblin")
	var gob: Monster = world.events._goblin
	if gob:
		gob.global_position = p.global_position + _screen_up(world) * 5.0 + Vector3(0, 0.4, 0)
		gob._alert(p)
		p.set_lock_target(gob)
		world.camera_rig._target_distance = 16.0
		await _sec(0.9)
		await _shot("84_treasure_goblin")
		p.set_lock_target(null)
		world.events.stop(&"treasure_goblin")
	# --- Town defense -----------------------------------------------------------------------
	var town: SettlementInfo = null
	for st in world.generator.settlements.near(Vector3.ZERO, 3000.0):
		if not st.is_kingdom():
			town = st
			break
	if town:
		await _teleport(world, town.world_center() + Vector3(0.5, 0.4, -1.5))
		world.living.update_now(true)
		world.living.finish_sites()
		await _wait(30)
		world.raids.start_town_raid(town, 2)
		world.raids.raid.t = 0.0
		await _wait(60)
		var raiders := world.raids.alive_raiders()
		if not raiders.is_empty():
			var to: Vector3 = (raiders[0] as Node3D).global_position - town.world_center()
			to.y = 0.0
			var spot := town.world_center() + to.normalized() * (town.radius - 4.0)
			spot.y = world.get_ground_height(spot) + 0.4
			p.global_position = spot
			world.camera_rig.snap_to_target()
		world.camera_rig._target_distance = 30.0
		world.camera_rig._target_pitch = 55.0
		await _sec(9.0)
		var best: Node3D = null
		for m in world.raids.alive_raiders():
			if best == null or (m as Node3D).global_position.distance_to(town.world_center()) < best.global_position.distance_to(town.world_center()):
				best = m
		if best:
			p.global_position = best.global_position + Vector3(2.0, 0.5, 2.0)
			p.set_lock_target(best)
		await _sec(2.0)
		await _shot("85_town_raid")
		world.raids._finish(true)
	world.queue_free()
	await _wait(5)


## Milestone 8 showcase: blueprint screen, placement preview, construction site, finished building.
func _blueprint_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.spawner.despawn_all()
	world.hud._help.visible = false
	for i in 9:
		p.character.grant_xp(p.character.xp_needed(), Progression.Source.OTHER)
	var meadow := _find_biome(world.generator, p.global_position, &"verdant_meadow")
	await _teleport(world, _dry_center(world, meadow if meadow != Vector3.INF else p.global_position, 30.0))
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	var cottage: Blueprint = BlueprintLibrary.builtin().filter(func(b: Blueprint) -> bool: return b.name == "Stone Cottage")[0]
	var hut: Blueprint = BlueprintLibrary.builtin().filter(func(b: Blueprint) -> bool: return b.name == "Starter Hut")[0]
	# Give some materials so the bill shows a mix of "have" and "missing".
	for item in cottage.total_cost():
		p.inventory.add_item(item, int(cottage.total_cost()[item]) / 2)
	world.hud._blueprints.toggle()
	world.hud._blueprints.select(cottage)
	await _sec(0.5)
	await _shot("90_blueprint_screen")
	world.hud._blueprints.toggle()
	var up := _screen_up(world)
	var pc := Vector2i(floori(p.global_position.x + up.x * 6.0), floori(p.global_position.z + up.z * 6.0))
	world.camera_rig._target_distance = 24.0
	world.camera_rig._target_pitch = 58.0
	world.blueprints.placer.begin(cottage)
	world.blueprints.placer.set_process(false)
	world.blueprints.placer.move_to(pc)
	await _sec(1.0)
	await _shot("91_blueprint_preview")
	var site := world.blueprints.placer.confirm()
	await _sec(0.6)
	await _shot("92_construction_site")
	p.inventory.clear()
	for item in cottage.total_cost():
		p.inventory.add_item(item, int(cottage.total_cost()[item]))
	site.auto = true
	var t := 0.0
	while site.pending_count() > site.total * 0.45 and t < 60.0:
		await _sec(0.5)
		t += 0.5
	await _shot("93_auto_building")
	while world.blueprints.sites.has(site) and t < 120.0:
		await _sec(0.5)
		t += 0.5
	# A second design next to it, then the finished pair.
	for item in hut.total_cost():
		p.inventory.add_item(item, int(hut.total_cost()[item]))
	var side := up.cross(Vector3.UP)
	var hut_anchor := pc + Vector2i(roundi(side.x * 9.0), roundi(side.z * 9.0))
	var site2 := world.blueprints.start(hut, hut_anchor, 1, true)
	while site2 and world.blueprints.sites.has(site2) and t < 180.0:
		await _sec(0.5)
		t += 0.5
	world.camera_rig._target_distance = 30.0
	await _sec(1.0)
	await _shot("94_blueprints_built")
	world.queue_free()
	await _wait(5)


## Milestone 9 showcase: horizon terrain, streaming stats, the far reaches of the world.
func _massive_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.hud._help.visible = false
	world.day_night.hour = 10.0
	var spots := [["70_horizon_spawn", p.global_position]]
	# A mountain top with a view, and a spot far out towards the world's edge.
	var gen := world.generator
	var best := Vector2i.ZERO
	var best_h := -999
	for k in 400:
		var c := Vector2i(roundi(cos(k * 0.37) * k * 6.0), roundi(sin(k * 0.37) * k * 6.0))
		var h := gen.get_height_blocks(c.x, c.y)
		if h > best_h and h < 90:
			best_h = h
			best = c
	spots.append(["71_horizon_mountain", Vector3(best.x + 0.5, 0, best.y + 0.5)])
	var edge := float(TerrainGenerator.WORLD_EDGE_START_M) - 300.0
	var land := gen.find_spawn_column(Vector2i(int(edge), int(edge)), [], 1500)
	spots.append(["72_far_reaches", Vector3(land.x + 0.5, 0, land.y + 0.5)])
	spots.append(["73_world_edge", Vector3(TerrainGenerator.WORLD_EDGE_START_M + 420.0, 0, land.y + 0.5)])
	for spot in spots:
		await _teleport(world, spot[1])
		var frames := 0
		while world.chunk_manager.far.pending_count() > 0 and frames < 3000:
			await get_tree().process_frame
			frames += 1
		world.camera_rig._target_distance = 42.0
		world.camera_rig._target_pitch = 25.0
		world.camera_rig._target_yaw = 90.0 if spot[0] == "73_world_edge" else 45.0
		await _sec(3.0)
		await _shot(spot[0])
	world.camera_rig._target_pitch = 52.0
	world.camera_rig._target_distance = 24.0
	world.hud._debug.visible = true
	await _sec(2.0)
	await _shot("74_streaming_debug")


## Milestone 10 showcase: sky through the day, weather, biome effects, animation, VFX, UI.
func _polish_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.hud._help.visible = false
	var g := world.generator
	var cam := world.camera_rig
	var forest := _find_biome(g, p.global_position, &"whispering_forest")
	await _teleport(world, forest)
	cam._target_distance = 26.0
	cam._target_pitch = 32.0
	for spec in [["80_dawn", 6.4], ["81_noon", 12.5], ["82_dusk", 18.3], ["83_night_fireflies", 22.5]]:
		world.day_night.hour = spec[1]
		world.weather.force(WeatherSystem.Kind.CLEAR)
		await _sec(2.5)
		await _shot(spec[0])
	world.day_night.hour = 11.0
	for spec in [["84_rain", WeatherSystem.Kind.RAIN], ["85_storm", WeatherSystem.Kind.STORM], ["86_fog", WeatherSystem.Kind.FOG]]:
		world.weather.force(spec[1])
		await _sec(3.0)
		if spec[1] == WeatherSystem.Kind.STORM:
			world.weather.strike()
			await _sec(0.15)
		await _shot(spec[0])
	await _teleport(world, _find_biome(g, p.global_position, &"snowy_tundra"))
	world.weather.force(WeatherSystem.Kind.SNOW)
	await _sec(3.0)
	await _shot("87_snow")
	await _teleport(world, _find_biome(g, p.global_position, &"sunscorch_desert"))
	world.weather.force(WeatherSystem.Kind.SANDSTORM)
	await _sec(3.0)
	await _shot("88_sandstorm")
	await _teleport(world, _find_biome(g, p.global_position, &"murk_swamp"))
	world.weather.force(WeatherSystem.Kind.CLEAR)
	world.day_night.hour = 20.5
	await _sec(3.0)
	await _shot("89_swamp_mist")
	world.day_night.hour = 10.0
	await _teleport(world, _find_biome(g, p.global_position, &"crystal_glade"))
	await _sec(3.0)
	await _shot("90_crystal_sparkles")
	# UI: icons, settings, combat feel.
	await _teleport(world, forest)
	world.weather.force(WeatherSystem.Kind.CLEAR)
	for id in [&"iron_sword", &"copper_pickaxe", &"healing_draught", &"bread", &"iron_ingot", &"moonpetal", &"tome_blink",
			&"chainmail", &"crystal_ring", &"raw_meat", &"gemstone", &"wood", &"plank", &"scroll_shadowfang"]:
		p.inventory.add_item(id, 3 if id in [&"bread", &"iron_ingot", &"wood", &"plank"] else 1)
	cam._target_distance = 16.0
	cam._target_pitch = 45.0
	world.hud._toggle_inventory()
	await _sec(1.5)
	await _shot("91_inventory_icons")
	world.hud._toggle_inventory()
	world.hud.set_paused(true)
	world.hud._settings.visible = true
	world.hud._pause_box.visible = false
	await _sec(1.0)
	await _shot("92_settings")
	world.hud._settings.visible = false
	world.hud._pause_box.visible = true
	world.hud.set_paused(false)
	cam._target_distance = 9.0
	cam._target_pitch = 35.0
	await _sec(1.0)
	p.model.set_weapon(&"sword", false)
	p.model.play_attack(&"slash", 0.08, 0.3, 0.2)
	await _sec(0.2)
	VFX.sparks(world, p.global_position + Vector3(0.8, 1.2, 0.8), Color(1.0, 0.8, 0.4), 16)
	await _shot("93_swing_trail")
	await _sec(1.0)
	p.health.invulnerable = false
	p.health.current = p.health.max_health * 0.12
	p.model.play_cast(1.5)
	VFX.motes(world, p.global_position + Vector3(0, 1, 0), Color(0.5, 1.0, 0.6), 24, 0.7)
	await _sec(0.5)
	await _shot("94_low_health_cast")
	p.health.current = p.health.max_health


## Milestone 11 showcase: a host with a guest (headless second process) in the same world.
func _multiplayer_showcase() -> void:
	SaveManager.start_transient(31337, &"knight")
	Net.player_name = "Hosty"
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	world.hud._help.visible = false
	world.day_night.hour = 11.0
	var port := 24700 + randi() % 200
	Net.host(port)
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/net_client_runner.tscn", "--", "--connect=127.0.0.1:%d" % port, "--out=user://net_shot.json"])
	while Net.server.peers.is_empty() or not Net.server.peers.values()[0].ready:
		await get_tree().process_frame
	var ps = Net.server.peers.values()[0]
	Net.server.give(ps, &"wood", 20)
	world.camera_rig._target_distance = 12.0
	world.camera_rig._target_pitch = 40.0
	var hcell := Vector2i(floori(world.player.global_position.x) - 2, floori(world.player.global_position.z) + 2)
	world.building.place(BuildingManager.get_piece_data(&"wood_floor"), hcell, "floor", 0, world.player, false)
	world.building.place(BuildingManager.get_piece_data(&"wood_wall"), hcell, "edge_n", 0, world.player, false)
	await _sec(5.0)
	await _shot("95_coop_guest")
	Net.say("Welcome to the Shardlands!")
	await _sec(5.0)
	world.hud.mp_hud._input.visible = true
	await _sec(1.0)
	await _shot("96_coop_chat")
	world.hud.mp_hud._input.visible = false
	while OS.is_process_running(pid):
		await get_tree().process_frame
	Net.leave()
