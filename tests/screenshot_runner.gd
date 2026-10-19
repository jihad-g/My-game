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
	if "--only=style" in OS.get_cmdline_user_args():
		await _style_showcase()
		get_tree().quit()
		return
	if "--only=pixelpilot" in OS.get_cmdline_user_args():
		await _pixel_pilot_showcase()
		get_tree().quit()
		return
	if "--only=newfolk" in OS.get_cmdline_user_args():
		await _new_folk_showcase()
		get_tree().quit()
		return
	if "--only=textures" in OS.get_cmdline_user_args():
		await _textures_showcase()
		get_tree().quit()
		return
	if "--only=mobs" in OS.get_cmdline_user_args():
		await _mobs_showcase()
		get_tree().quit()
		return
	if "--only=release" in OS.get_cmdline_user_args():
		await _release_showcase()
		get_tree().quit()
		return
	if "--only=perf" in OS.get_cmdline_user_args():
		await _perf_showcase()
		get_tree().quit()
		return
	if "--only=icons" in OS.get_cmdline_user_args():
		await _icons_showcase()
		get_tree().quit()
		return
	if "--only=roll" in OS.get_cmdline_user_args():
		await _roll_showcase()
		get_tree().quit()
		return
	if "--only=anims" in OS.get_cmdline_user_args():
		await _anims_showcase()
		get_tree().quit()
		return
	if "--only=feel" in OS.get_cmdline_user_args():
		await _feel_showcase()
		get_tree().quit()
		return
	if "--only=dungeon2" in OS.get_cmdline_user_args():
		await _dungeon2_showcase()
		get_tree().quit()
		return
	if "--only=storeys" in OS.get_cmdline_user_args():
		await _storeys_showcase()
		get_tree().quit()
		return
	if "--only=travel" in OS.get_cmdline_user_args():
		await _travel_showcase()
		get_tree().quit()
		return
	if "--only=seasons" in OS.get_cmdline_user_args():
		await _seasons_showcase()
		get_tree().quit()
		return
	if "--only=richworld" in OS.get_cmdline_user_args():
		await _rich_world_showcase()
		get_tree().quit()
		return
	if "--only=creative" in OS.get_cmdline_user_args():
		await _creative_showcase()
		get_tree().quit()
		return
	if "--only=elements" in OS.get_cmdline_user_args():
		await _elements_showcase()
		get_tree().quit()
		return
	if "--only=pixelworld" in OS.get_cmdline_user_args():
		await _pixel_world_showcase()
		get_tree().quit()
		return
	if "--only=tuskers" in OS.get_cmdline_user_args():
		await _tusker_showcase()
		get_tree().quit()
		return
	if "--only=pixelstyle" in OS.get_cmdline_user_args():
		await _pixel_style_showcase()
		get_tree().quit()
		return
	if "--only=smooth" in OS.get_cmdline_user_args():
		await _smooth_showcase()
		get_tree().quit()
		return
	if "--only=menu" in OS.get_cmdline_user_args():
		var m := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
		add_child(m)
		await _wait(10)
		m._select_class(&"wizard")
		await _wait(5)
		await _shot("20_main_menu")
		get_tree().quit()
		return
	if "--only=story" in OS.get_cmdline_user_args():
		await _story_showcase()
		get_tree().quit()
		return
	if "--only=wilds" in OS.get_cmdline_user_args():
		await _wilds_showcase()
		get_tree().quit()
		return
	if "--only=poses" in OS.get_cmdline_user_args():
		await _poses_showcase()
		get_tree().quit()
		return
	if "--only=book" in OS.get_cmdline_user_args():
		await _book_showcase()
		get_tree().quit()
		return
	if "--only=voxel" in OS.get_cmdline_user_args():
		await _voxel_showcase()
		get_tree().quit()
		return
	if "--only=arsenal" in OS.get_cmdline_user_args():
		await _arsenal_showcase()
		get_tree().quit()
		return
	if "--only=gear" in OS.get_cmdline_user_args():
		await _gear_showcase()
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
	if "--only=outfits" in OS.get_cmdline_user_args():
		await _outfits_showcase()
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


## Milestone 16: the intro page, the quest tracker and the journal.
func _story_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"wizard")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var frames := 0
	while world.chunk_manager.pending_count() > 0 and frames < 1500:
		await get_tree().process_frame
		frames += 1
	world.hud._help.visible = false
	world.player.health.invulnerable = true
	await _wait(30)
	await _shot("60_story_intro")
	world.hud.story.visible = false
	world.quests.talk_main()
	for page in [&"ancients", &"great_shards", &"bone_king"]:
		world.quests.read_lore(page, true)
	await _wait(40)
	await _shot("61_quest_tracker")
	world.hud.journal.toggle()
	await _wait(10)
	await _shot("62_journal")
	world.queue_free()


## Milestone 15: the new wild creatures and the three treasure spots.
func _wilds_showcase() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 9.5)
	cam.rotation_degrees = Vector3(-14, 0, 0)
	cam.fov = 50.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.6, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(40, 0.2, 20)
	ground.mesh = gm
	ground.position = Vector3(0, -0.1, -3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.6, 0.32)
	ground.material_override = mat
	root.add_child(ground)
	var ids := [&"frost_wolf", &"frost_wolf", &"sand_scorpion", &"shore_crab", &"deer", &"rabbit"]
	for i in ids.size():
		var mm := MonsterModel.new()
		root.add_child(mm)
		mm.build(load("res://data/enemies/%s.tres" % ids[i]))
		mm.position = Vector3(-6.0 + i * 2.2, 0, 1.2)
		mm.rotation.y = 0.6
	await _wait(5)
	var b: BeastModel = (root.get_child(root.get_child_count() - 6) as MonsterModel).rig
	b.play_howl(3.0)
	var x := -7.0
	for kind in [&"camp", &"shipwreck", &"buried"]:
		var site := TreasureSpots.build_site({"kind": kind, "position": Vector3(x, 0, -4.5), "key": "", "rank": 0, "yaw": 0.4})
		root.add_child(site)
		x += 6.5
	await _wait(12)
	await _shot("50_wild_creatures")
	root.queue_free()


## Milestone 14: the four starting outfits on the shared body, then the same
## body swapped into other classes' gear (Knight as an Assassin, Wizard in plate).
func _gear_showcase() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 7.2)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	cam.fov = 45.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.42, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var specs := [
		[&"knight", &"knight"], [&"barbarian", &"barbarian"], [&"assassin", &"assassin"], [&"wizard", &"wizard"],
		[&"knight", &"assassin"], [&"wizard", &"knight"], [&"barbarian", &""],
	]
	for i in specs.size():
		var body_class: StringName = specs[i][0]
		var kit_class: StringName = specs[i][1]
		var m := HumanoidModel.new()
		root.add_child(m)
		m.position = Vector3(-4.2 + i * 1.4, 0, 0)
		m.rotation.y = 0.35
		m.set_appearance(ClassRegistry.get_class_data(body_class))
		m.set_body(CharacterLook.default_for(body_class))
		if kit_class != &"":
			var eq := ClassPicker.starting_equipment(ClassRegistry.get_class_data(kit_class))
			m.set_weapon(eq.weapon_type(), eq.offhand() != null)
			m.set_outfit(eq.outfit_ids(), eq.weapon().id)
		else:
			m.set_outfit(PackedStringArray())
			m.set_weapon(&"unarmed", false)
	await _wait(10)
	await _shot("40_gear_outfits")
	root.queue_free()
	var m2 := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	add_child(m2)
	await _wait(10)
	m2._select_class(&"assassin")
	await _wait(20)
	await _shot("41_class_picker")


## Milestone 17c: ability poses, a two-handed stance and drawing a bow.
func _poses_showcase() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 8.4)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 45.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.34, 0.38, 0.48)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	# [class, weapon, pose or attack]
	var specs := [[&"barbarian", &"", &"roar"], [&"knight", &"", &"pray"], [&"wizard", &"", &"cast_up"],
		[&"assassin", &"", &"crouch"], [&"barbarian", &"iron_greatsword", &""], [&"assassin", &"recurve_bow", &"aim"],
		[&"knight", &"", &"guard"], [&"wizard", &"", &"push"]]
	var models: Array[HumanoidModel] = []
	for i in specs.size():
		var s: Array = specs[i]
		var eq := ClassPicker.starting_equipment(ClassRegistry.get_class_data(s[0]))
		if s[1] != &"":
			eq.equip(ItemDB.get_item(s[1]))
		var m := HumanoidModel.new()
		root.add_child(m)
		m.position = Vector3(-5.25 + i * 1.5, 0, 0)
		m.rotation.y = 0.7
		m.set_appearance(ClassRegistry.get_class_data(s[0]))
		m.set_body(CharacterLook.default_for(s[0]))
		m.set_outfit(eq.outfit_ids(), eq.weapon().id if eq.weapon() else &"")
		m.set_weapon(eq.weapon_type(), eq.has_shield())
		models.append(m)
	await _wait(5)
	for i in specs.size():
		var pose: StringName = specs[i][2]
		if pose == &"aim":
			models[i].play_attack(&"aim", 0.2, 0.1, 0.3, true)
		elif pose != &"":
			models[i].play_pose(pose, 3.0)
	await _wait(40)
	await _shot("80_ability_poses")
	root.queue_free()


## Milestone 17b: the ability book and the 6 + 3 bar of a level 20 Knight at a campfire.
func _book_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var frames := 0
	while world.chunk_manager.pending_count() > 0 and frames < 1500:
		await get_tree().process_frame
		frames += 1
	world.hud._help.visible = false
	world.hud.story.visible = false
	var p := world.player
	p.health.invulnerable = true
	p.character.grant_xp(Progression.total_xp_for(20) - p.character.total_xp, Progression.Source.OTHER)
	p.spells.learn(&"healing_light")
	p.spells.learn(&"blink")
	var fire := (load("res://scenes/world/campfire.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(fire)
	fire.global_position = p.global_position + Vector3(1.6, 0, 1.0)
	await _wait(20)
	p.abilities.assign(4, &"judgement")
	await _wait(10)
	await _shot("70_ability_bar")
	world.hud._spellbook.toggle()
	await _wait(10)
	await _shot("71_ability_book")
	world.queue_free()


## Milestone 17a: the new weapons in the hands of the shared body, and their icons.
## Milestone 39: every held item as a voxel model, on heroes, townsfolk and the ground.
func _voxel_showcase() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 6.2)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 45.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.122, 0.118, 0.141)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.92)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	# [class kit, main hand, off hand]
	var specs := [
		[&"knight", &"iron_sword", &"iron_kite_shield"], [&"barbarian", &"copper_waraxe", &""],
		[&"assassin", &"mithril_dirk", &""], [&"knight", &"fallen_king_greatsword", &""],
		[&"barbarian", &"frostbite_warhammer", &""], [&"assassin", &"starfall_bow", &""],
		[&"wizard", &"staff_of_the_archmage", &"stormcaller_wand"], [&"wizard", &"copper_staff", &"embers_tome"],
		[&"knight", &"mithril_halberd", &""], [&"knight", &"gilded_greatsword", &""],
		[&"assassin", &"prismheart_blade", &""], [&"wizard", &"sporecrown_staff", &""],
		[&"knight", &"starlance", &"aegis_of_dawn"], [&"knight", &"sunforged_blade", &"gilded_kite_shield"],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var eq := ClassPicker.starting_equipment(ClassRegistry.get_class_data(s[0]))
		eq.equip(ItemDB.get_item(s[1]))
		if s[2] != &"":
			eq.equip(ItemDB.get_item(s[2]))
		var m := HumanoidModel.new()
		root.add_child(m)
		@warning_ignore("integer_division")
		var row := i / 7
		m.position = Vector3(-4.2 + (i % 7) * 1.4, 0, -row * 40.0)
		m.rotation.y = 0.55
		m.set_appearance(ClassRegistry.get_class_data(s[0]))
		m.set_body(CharacterLook.default_for(s[0]))
		if eq.weapon() == null:
			push_warning("voxel showcase: no weapon for %s" % [s])
			continue
		m.set_outfit(eq.outfit_ids(), eq.weapon().id)
		m.set_weapon(eq.weapon_type(), eq.has_shield())
	# Dropped loot in front.
	var loot := [&"gilded_halberd", &"iron_sword", &"copper_waraxe", &"mithril_staff", &"wooden_buckler", &"recurve_bow", &"iron_kite_shield", &"embers_tome", &"stone_maul"]
	for i in loot.size():
		var p := Pickup.new()
		root.add_child(p)
		p.setup(loot[i], 1, Vector3(-4.4 + i * 1.1, -80.0, 0.0), -80.4, false)
		p._velocity = Vector3.ZERO  # no toss: keep the row tidy for the picture
	await _wait(60)
	await _shot("60_voxel_items_a")
	cam.position.z -= 40.0
	await _wait(5)
	await _shot("61_voxel_items_b")
	cam.position = Vector3(0, -77.6, 4.6)
	cam.rotation_degrees = Vector3(-26, 0, 0)
	await _wait(5)
	await _shot("62_voxel_loot")
	root.queue_free()
	await _wait(3)


func _arsenal_showcase() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 7.6)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 45.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.4, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	# [class kit, main hand, off hand, pose]
	var specs := [
		[&"assassin", &"starfall_bow", &"", &""], [&"knight", &"mithril_halberd", &"iron_kite_shield", &""],
		[&"barbarian", &"shardbreaker", &"", &""], [&"knight", &"fallen_king_greatsword", &"", &""],
		[&"wizard", &"mithril_staff", &"stormcaller_wand", &""], [&"wizard", &"iron_staff", &"embers_tome", &""],
		[&"barbarian", &"frostbite_warhammer", &"", &""],
	]
	var models: Array[HumanoidModel] = []
	for i in specs.size():
		var s: Array = specs[i]
		var eq := ClassPicker.starting_equipment(ClassRegistry.get_class_data(s[0]))
		eq.equip(ItemDB.get_item(s[1]))
		if s[2] != &"":
			eq.equip(ItemDB.get_item(s[2]))
		var m := HumanoidModel.new()
		root.add_child(m)
		m.position = Vector3(-4.5 + i * 1.5, 0, 0)
		m.rotation.y = 0.7
		m.set_appearance(ClassRegistry.get_class_data(s[0]))
		m.set_body(CharacterLook.default_for(s[0]))
		m.set_outfit(eq.outfit_ids(), eq.weapon().id)
		m.set_weapon(eq.weapon_type(), eq.has_shield())
		models.append(m)
	await _wait(5)
	for i in specs.size():
		if specs[i][3] != &"":
			models[i].play_attack(specs[i][3], 0.2, 0.1, 0.3, true)
	await _wait(30)
	await _shot("50_arsenal_weapons")
	root.queue_free()
	# Icon sheet: every new weapon and arrow.
	var ids := [&"wooden_shortbow", &"recurve_bow", &"mithril_longbow", &"starfall_bow", &"ash_spear", &"iron_pike",
		&"mithril_halberd", &"stone_maul", &"iron_warhammer", &"frostbite_warhammer", &"shardbreaker", &"iron_greatsword",
		&"fallen_king_greatsword", &"copper_staff", &"iron_staff", &"mithril_staff", &"apprentice_wand", &"stormcaller_wand",
		&"embers_tome", &"copper_waraxe", &"wooden_arrow", &"copper_arrow", &"fire_arrow", &"iron_arrow", &"mithril_arrow"]
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.12, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(40, 30)
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 8)
	bg.add_child(grid)
	for id in ids:
		var it: ItemData = ItemDB.get_item(id)
		var box := HBoxContainer.new()
		var tr := TextureRect.new()
		tr.texture = ItemIcons.get_icon(it)
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(tr)
		var l := Label.new()
		l.text = it.display_name
		l.custom_minimum_size = Vector2(150, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.add_theme_color_override(&"font_color", it.rarity_color())
		box.add_child(l)
		grid.add_child(box)
	await _wait(5)
	await _shot("51_arsenal_icons")


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


## Milestone 14 showcase: one body, many outfits. The four starting outfits in
## a row, then the same Knight dressed light (Assassin style) and heavy (iron).
func _outfits_showcase() -> void:
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
	world.hud._help.visible = false
	world.day_night.hour = 11.0
	world.weather.force(WeatherSystem.Kind.CLEAR, 0.0)
	world.weather.settle()
	# A meadow has open ground with few trees.
	await _teleport(world, _find_biome(world.generator, p.global_position, &"verdant_meadow"))
	p.visible = false
	var cam := world.camera_rig
	var right := cam.camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var toward := -cam.camera.global_transform.basis.z
	toward.y = 0.0
	toward = toward.normalized()
	var outfits := [
		[&"rough_handaxe", [&"horned_helm", &"padded_vest"]],
		[&"squire_sword", [&"squire_helm", &"padded_vest", &"wooden_buckler"]],
		[&"apprentice_staff", [&"wizard_hat", &"apprentice_robe"]],
		[&"rusty_dagger", [&"shadow_hood", &"leather_gloves", &"worn_boots"]],
		[&"iron_dirk", [&"shadow_hood", &"shadow_cloak", &"leather_gloves", &"soft_leather_boots"]],
		[&"iron_sword", [&"iron_helm", &"chainmail", &"iron_gauntlets", &"iron_greaves", &"iron_kite_shield"]],
		[&"starfall_blade", [&"crown_of_stars", &"mithril_plate", &"aegis_of_dawn", &"starmetal_amulet"]],
	]
	var models := []
	for i in outfits.size():
		var m := HumanoidModel.new()
		world.add_child(m)
		m.set_appearance()
		var w: ItemData = ItemDB.get_item(outfits[i][0])
		m.set_weapon(w.weapon_type, outfits[i][1].any(func(id: StringName) -> bool: return ItemDB.get_item(id).equip_slot == ItemData.EquipSlot.OFF_HAND))
		m.set_outfit(PackedStringArray(outfits[i][1].map(func(id: StringName) -> String: return String(id))), w.id)
		var pos := p.global_position + right * ((i - 3) * 1.25 + 3.0)
		pos.y = world.get_ground_height(pos)
		m.global_position = pos
		m.look_at(pos + toward, Vector3.UP)  # the model's face is +Z: face the camera
		models.append(m)
	cam._pan_offset = right * 3.0
	cam._target_distance = 11.0
	cam._target_pitch = 22.0
	await _wait(60)
	await _shot("outfits_lineup")
	cam._target_distance = 7.0
	await _wait(40)
	await _shot("outfits_closeup")


## v0.24.0: the Vibrant and Classic art styles side by side, a sunset, a pack of
## minions and the element looks of spells.
func _style_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"wizard")
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
	world.hud.visible = false  # clean pictures: no HUD, no story pop-up
	world.day_night.day_length = 1.0e9  # hold the time of day
	world.day_night.hour = 11.0
	world.weather.force(0, 1.0)
	world.camera_rig._target_distance = 16.0
	world.camera_rig._target_pitch = 50.0
	await _wait(60)
	for style in [0, 1]:
		Settings.set_value("art_style", style)
		await _wait(20)
		await _shot("style_%s_day" % ["vibrant", "classic"][style])
	Settings.set_value("art_style", 0)
	# v0.25.0: a low camera, so trees between the camera and the player use the
	# soft see-through fade.
	world.camera_rig._target_distance = 22.0
	world.camera_rig._target_pitch = 30.0
	await _wait(40)
	await _shot("style_tree_fade")
	world.camera_rig._target_distance = 16.0
	world.camera_rig._target_pitch = 50.0
	await _wait(40)
	world.day_night.hour = 17.4
	world.day_night.advance_hours(0.0)
	await _wait(20)
	await _shot("style_vibrant_sunset")
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	# A pack of minions and a few spells of different elements.
	world.camera_rig._target_distance = 12.0
	p.character.grant_xp(Progression.total_xp_for(100), Progression.Source.OTHER)
	p.set_creative(true)
	var dir := p.get_facing()
	var foes: Array[Monster] = []
	for k in 6:
		var off := dir.rotated(Vector3.UP, (k - 2.5) * 0.35) * (5.0 + (k % 2) * 1.5)
		var pos := p.global_position + off
		pos.y = world.get_ground_height(pos) + 0.3
		var m := world.spawner.spawn_enemy(load(Monster.MONSTER_SCENE_PATH), pos, "", load("res://data/enemies/skeleton_minion.tres")) as Monster
		if m:
			m.health.max_health = 50000.0
			m.health.reset_full()
			m.make_dormant(-1.0)
			m.set_meta(&"training_dummy", true)
			foes.append(m)
	await _wait(30)
	await _shot("style_minion_pack")
	if not foes.is_empty():
		p.set_lock_target(foes[2])
	for spec in [[&"flame_wave", "fire"], [&"absolute_zero", "frost"], [&"chain_lightning", "lightning"], [&"arcane_explosion", "arcane"]]:
		p.abilities.bar[0] = spec[0]
		p.abilities.try_use(0)
		await _wait(7)
		await _shot("style_spell_%s" % spec[1])
		await _wait(50)


## Milestone 18d: the old land (shape 3) next to the new smooth land (shape 4)
## at the same seed - a biome border, the horizon, and chunks fading in.
func _smooth_showcase() -> void:
	var g4 := TerrainGenerator.new(GameState.DEFAULT_SEED, load("res://data/worldgen/default_worldgen.tres"), 4)
	var spawn := g4.find_spawn_column(Vector2i.ZERO)
	# A border between two land biomes near the spawn.
	var border := Vector3(spawn.x + 0.5, 0, spawn.y + 0.5)
	var found := false
	for r in range(40, 3000, 24):
		if found:
			break
		for k in maxi(8, r / 16):
			var a := TAU * k / maxi(8, r / 16)
			var q := Vector2i(spawn.x + roundi(cos(a) * r), spawn.y + roundi(sin(a) * r))
			var b1 := g4.get_biome(q.x - 20, q.y)
			var b2 := g4.get_biome(q.x + 20, q.y)
			if b1 != b2 and b1.role == BiomeData.Role.LAND and b2.role == BiomeData.Role.LAND \
					and g4.get_height_blocks(q.x, q.y) > 2:
				border = Vector3(q.x + 0.5, 0, q.y + 0.5)
				found = true
				break
	for shape in [3, 4]:
		SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
		GameState.terrain_shape = shape
		var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
		add_child(world)
		while not world.is_ready:
			await get_tree().process_frame
		var p := world.player
		p.health.invulnerable = true
		world.spawner.max_active = 0
		world.hud.visible = false
		world.day_night.day_length = 1.0e9
		world.day_night.hour = 11.0
		world.weather.force(0, 1.0)
		await _teleport(world, border)
		var frames := 0
		while world.chunk_manager.far.pending_count() > 0 and frames < 3000:
			await get_tree().process_frame
			frames += 1
		world.camera_rig._target_distance = 34.0
		world.camera_rig._target_pitch = 55.0
		world.camera_rig._target_yaw = 30.0
		await _sec(2.5)
		await _shot("m18d_border_shape%d" % shape)
		world.camera_rig._target_distance = 42.0
		world.camera_rig._target_pitch = 22.0
		await _sec(2.5)
		await _shot("m18d_horizon_shape%d" % shape)
		if shape == 4:
			# Jump ahead without the loading screen: the new chunks dither in.
			world.camera_rig._target_distance = 40.0
			world.camera_rig._target_pitch = 40.0
			await _sec(1.0)
			p.global_position += Vector3(40, 0, 0)
			p.global_position.y = world.get_ground_height(p.global_position) + 0.5
			world.camera_rig.snap_to_target()
			await _sec(0.35)
			print("fading chunks: ", world.chunk_manager.fading_count())
			await _shot("m18d_fade_in")
			var cam := get_viewport().get_camera_3d()
			for mi: MeshInstance3D in world.chunk_manager.far._landmarks.values():
				print("landmark %.0f m from camera, begin %.0f" % [mi.global_position.distance_to(cam.global_position), mi.visibility_range_begin])
		world.queue_free()
		await _wait(10)


## Style preview (not a milestone): the owner's reference models rebuilt with
## pixel-textured boxes (tests/style_preview.gd) and put in the real world,
## next to today's models for comparison.
func _pixel_style_showcase() -> void:
	var SP := preload("res://tests/style_preview.gd")
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"wizard")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(-9, 0, 2))
	var frames := 0
	while world.chunk_manager.pending_count() > 0 and frames < 1500:
		await get_tree().process_frame
		frames += 1
	await _wait(30)
	_clear_monsters(world)
	var spots := {
		"wanderer": Vector3(-6.0, 0, 0), "skeleton": Vector3(-3.0, 0, 0), "knight": Vector3(0.5, 0, -0.5),
		"centaur": Vector3(4.2, 0, -0.5), "sword": Vector3(7.4, 0, 0.6), "weapons": Vector3(0.5, 0, 4.2),
	}
	var models := {
		"wanderer": SP.wanderer(), "skeleton": SP.skeleton(), "knight": SP.knight_rider(),
		"centaur": SP.centaur(), "sword": SP.bandaged_sword(), "weapons": SP.weapons(),
	}
	for k in models:
		var at: Vector3 = c + spots[k]
		at.y = world.get_ground_height(at)
		var m: Node3D = models[k]
		world.add_child(m)
		m.global_position = at + (Vector3(0, 0.15, 0) if k == "sword" else Vector3.ZERO)
		if k == "centaur":
			m.rotation_degrees.y = -35.0
		elif k == "knight":
			m.rotation_degrees.y = 30.0
		spots[k] = at
	# Today's models for comparison: the player (wizard) and a skeleton minion.
	var old_pos := c + Vector3(-4.2, 0, 1.4)
	await _teleport(world, c + Vector3(-7.4, 0, 1.4))
	p.rotation.y = 0.0
	var minion := _monster(world, &"skeleton_minion", old_pos)
	if minion:
		minion.make_dormant(-1.0)
		minion.set_meta(&"training_dummy", true)
		minion.health.invulnerable = true
	await _wait(30)
	# Our own camera: stop the game camera and its see-through tree fade.
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.far = 600.0
	world.add_child(cam)
	cam.current = true
	var shots := [
		["pixel_lineup", c + Vector3(0.6, 1.0, 1.2), 15.5, 0.0, 18.0],
		["pixel_skeleton_vs_today", spots["skeleton"] + Vector3(-0.6, 1.0, 0.5), 4.2, 18.0, 10.0],
		["pixel_centaur", spots["centaur"] + Vector3(0, 1.5, 0), 5.2, -20.0, 10.0],
		["pixel_knight", spots["knight"] + Vector3(0, 1.6, 0), 5.4, 12.0, 8.0],
		["pixel_weapons", spots["weapons"] + Vector3(0, 1.0, 0), 5.2, 0.0, 10.0],
		["pixel_wanderer", spots["wanderer"] + Vector3(-0.6, 1.2, 0.5), 3.8, 12.0, 6.0],
		["pixel_sword", spots["sword"] + Vector3(0, 1.1, 0), 2.9, 20.0, 6.0],
	]
	for sh in shots:
		var target: Vector3 = sh[1]
		var yaw := deg_to_rad(float(sh[3]))
		var pitch := deg_to_rad(float(sh[4]))
		cam.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(sh[2])
		cam.look_at(target)
		await _wait(8)
		await _shot(sh[0])
	# Batch 2 (tests/style_preview_2.gd): one group at a time on the same spot.
	var S2 := preload("res://tests/style_preview_2.gd")
	for k in models:
		models[k].visible = false
	if minion:
		minion.visible = false
	var groups := [
		["pixel_townsfolk", [S2.witch(), S2.adventurer(), S2.cook(), S2.dwarf(), S2.old_wizard(), S2.merchant()], 1.3, 8.2],
		["pixel_copper_samurai", [S2.copper_knight(), S2.oni_samurai(), S2.ronin()], 1.6, 6.0],
		["pixel_warband", [S2.brute(1.0, 0), S2.brute(1.35, 1), S2.banner(), S2.brute(1.15, 0), S2.brute(0.8, 1)], 1.25, 7.6],
		["pixel_armour_sets", [S2.armour_set(0), S2.armour_set(1), S2.armour_set(2), S2.armour_set(3)], 1.6, 7.0],
	]
	var stage := c + Vector3(0.5, 0, 1.5)
	for g in groups:
		var nodes: Array = g[1]
		for i in nodes.size():
			var at: Vector3 = stage + Vector3((i - (nodes.size() - 1) * 0.5) * float(g[2]), 0, 0)
			at.y = world.get_ground_height(at)
			world.add_child(nodes[i])
			nodes[i].global_position = at
		if g[0] == "pixel_copper_samurai":
			var kat: Node3D = S2.red_katana()
			world.add_child(kat)
			var at2 := stage + Vector3(0.8, 0, 1.0)
			kat.global_position = Vector3(at2.x, world.get_ground_height(at2), at2.z)
			nodes.append(kat)
		var gy := world.get_ground_height(stage)
		var target := Vector3(stage.x, gy + 1.05, stage.z)
		cam.current = true
		cam.global_position = target + Vector3(0, sin(deg_to_rad(9.0)), cos(deg_to_rad(9.0))) * float(g[3])
		cam.look_at(target)
		await _wait(8)
		await _shot(g[0])
		for n in nodes:
			n.queue_free()
	for k in models:
		models[k].visible = true
	if minion:
		minion.visible = true
	# The real game camera (default distance and angle) to judge it in play.
	world.camera_rig.set_process(true)
	world.camera_rig.camera.current = true
	await _teleport(world, c + Vector3(-0.5, 0, 1.8))
	world.camera_rig._target_distance = 16.0
	world.camera_rig._target_pitch = 50.0
	world.camera_rig.snap_to_target()
	await _wait(40)
	await _shot("pixel_game_camera")
	world.camera_rig._target_distance = 9.0
	await _wait(60)
	await _shot("pixel_game_camera_close")


## Art pass pilot: the real Skeleton Minion and Skeleton Warrior, now drawn
## pixel by pixel (src/art/pixel_skeleton.gd), close up and from the game camera.
func _pixel_pilot_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(0, 0, 4))
	_clear_monsters(world)
	var foes: Array[Monster] = []
	for spec in [[&"skeleton_minion", Vector3(-0.9, 0, 0)], [&"skeleton_warrior", Vector3(0.9, 0, -0.3)]]:
		var m := _monster(world, spec[0], c + spec[1])
		if m:
			m.make_dormant(-1.0)
			m.set_meta(&"training_dummy", true)
			m.health.invulnerable = true
			m.rotation.y = 0.0
			foes.append(m)
	await _wait(40)
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 35.0
	world.add_child(cam)
	cam.current = true
	var gy := world.get_ground_height(c)
	for sh in [["pixel_pilot_front", 0.0, 3.6, 8.0], ["pixel_pilot_side", 35.0, 3.4, 14.0], ["pixel_pilot_close", 10.0, 1.9, 6.0]]:
		var target := Vector3(c.x, gy + (1.25 if sh[0] == "pixel_pilot_close" else 0.85), c.z)
		if sh[0] == "pixel_pilot_close":
			target.x -= 0.9
		var yaw := deg_to_rad(float(sh[1]))
		var pitch := deg_to_rad(float(sh[3]))
		cam.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(sh[2])
		cam.look_at(target)
		await _wait(8)
		await _shot(sh[0])
	# Mid-swing, so the bones are seen moving with the normal rig.
	for m in foes:
		var mm := m.get_node_or_null("Model") as MonsterModel
		if mm == null:
			for ch in m.get_children():
				if ch is MonsterModel:
					mm = ch
		if mm:
			mm.play_attack(&"slash", 0.35, 0.15, 0.3)
	await _sec(0.4)
	cam.global_position = Vector3(c.x, gy + 0.85, c.z) + Vector3(sin(deg_to_rad(-25.0)), 0.25, cos(deg_to_rad(-25.0))) * 3.6
	cam.look_at(Vector3(c.x, gy + 0.85, c.z))
	await _wait(2)
	await _shot("pixel_pilot_attack")
	world.camera_rig.set_process(true)
	world.camera_rig.camera.current = true
	world.camera_rig._target_distance = 12.0
	await _wait(60)
	await _shot("pixel_pilot_game_camera")


## Milestone 20: the Tusker warband (src/art/pixel_tusker.gd, data/enemies/tusker_*).
func _tusker_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(0, 0, 14))
	_clear_monsters(world)
	var foes: Array[Monster] = []
	var line := [[&"tusker_grunt", 1.0, -2.1, 0.3], [&"tusker_brute", 1.3, -0.9, -0.2], [&"tusker_chief", 1.25, 0.6, -0.5],
		[&"tusker_brute", 1.1, 1.9, -0.1], [&"tusker_grunt", 0.8, 2.9, 0.3]]
	for spec in line:
		var d := (load("res://data/enemies/%s.tres" % spec[0]) as MonsterData).duplicate() as MonsterData
		d.model_scale = spec[1]
		var pos := c + Vector3(spec[2], 0, spec[3])
		pos.y = world.get_ground_height(pos) + 0.3
		var m := world.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", d) as Monster
		if m:
			m.make_dormant(-1.0)
			m.set_meta(&"training_dummy", true)
			m.health.invulnerable = true
			m.rotation.y = 0.0
			foes.append(m)
	await _wait(40)
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 35.0
	world.add_child(cam)
	cam.current = true
	var gy := world.get_ground_height(c)
	for sh in [["tuskers_warband", 0.0, 0.3, 7.6, 6.0, 1.1], ["tuskers_side", 30.0, 0.3, 6.6, 12.0, 1.1], ["tuskers_chief_close", 8.0, 0.6, 3.4, 8.0, 1.5]]:
		var target := Vector3(c.x + float(sh[2]), gy + float(sh[5]), c.z)
		var yaw := deg_to_rad(float(sh[1]))
		var pitch := deg_to_rad(float(sh[4]))
		cam.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(sh[3])
		cam.look_at(target)
		await _wait(8)
		await _shot(sh[0])
	for m in foes:
		for ch in m.get_children():
			if ch is MonsterModel:
				ch.play_attack(&"slash", 0.35, 0.15, 0.3)
	await _sec(0.4)
	await _shot("tuskers_attack")
	await _teleport(world, c + Vector3(0, 0, 3.5))
	world.camera_rig.set_process(true)
	world.camera_rig.camera.current = true
	world.camera_rig._target_distance = 12.0
	await _wait(60)
	await _shot("tuskers_game_camera")


## Milestone 21: the pixel style on every model - all monsters, animals, heroes
## and townsfolk, a row at a time, close up.
func _pixel_world_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(0, 0, 16))
	_clear_monsters(world)
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 38.0
	world.add_child(cam)
	cam.current = true
	var rows := [
		["pixel_world_undead", [&"skeleton_minion", &"skeleton_warrior", &"skeleton_archer", &"bone_king"]],
		["pixel_world_bandits", [&"bandit_recruit", &"bandit_thug", &"bandit_archer", &"bandit_hexer", &"bandit_bomber", &"bandit_brute", &"bandit_warlord"]],
		["pixel_world_magic", [&"cultist_acolyte", &"grotto_cultist", &"tower_warden", &"arcane_wisp", &"arcane_sentinel", &"temple_guardian"]],
		["pixel_world_giants", [&"arcane_colossus", &"starborn_colossus", &"tusker_chief"]],
		["pixel_world_beasts", [&"thornback_boar", &"frost_wolf", &"sand_scorpion", &"shore_crab", &"thorn_crawler", &"treasure_goblin", &"deer", &"rabbit"]],
		["pixel_world_thornmaw", [&"elder_thornmaw"]],
	]
	for row in rows:
		var ids: Array = row[1]
		var nodes: Array = []
		var width := 0.0
		for id in ids:
			var d := load("res://data/enemies/%s.tres" % id) as EnemyData
			width += 1.1 + (d.get("model_scale") if d.get("model_scale") != null else 1.0) * 0.6
		var x := -width * 0.5
		for id in ids:
			var d := load("res://data/enemies/%s.tres" % id) as EnemyData
			var sc: float = d.get("model_scale") if d.get("model_scale") != null else 1.0
			x += (1.1 + sc * 0.6) * 0.5
			var pos := c + Vector3(x, 0, 0)
			pos.y = world.get_ground_height(pos) + 0.3
			var scene: PackedScene = load(Monster.MONSTER_SCENE_PATH) if d is MonsterData else load("res://scenes/enemies/thornback_boar.tscn")
			var m := world.spawner.spawn_enemy(scene, pos, "", d) as Enemy
			if m:
				if m is Monster:
					(m as Monster).make_dormant(-1.0)
				m.set_meta(&"training_dummy", true)
				m.health.invulnerable = true
				nodes.append(m)
			x += (1.1 + sc * 0.6) * 0.5
		await _wait(20)
		for m in nodes:
			if is_instance_valid(m):
				m.look_at(m.global_position + Vector3(0, 0, 1), Vector3.UP)
				m.rotate_y(PI)
		await _wait(4)
		var gy := world.get_ground_height(c)
		var tall := 1.0 if row[0] != "pixel_world_giants" and row[0] != "pixel_world_thornmaw" else 2.0
		var target := Vector3(c.x, gy + tall, c.z)
		var dist := maxf(4.5, width * 1.05) * (1.3 if tall > 1.5 else 1.0)
		cam.global_position = target + Vector3(0, sin(deg_to_rad(10.0)), cos(deg_to_rad(10.0))) * dist
		cam.look_at(target)
		await _wait(6)
		await _shot(row[0])
		for m in nodes:
			if is_instance_valid(m):
				NodePool.release_or_free(m)
		await _wait(4)
	# Heroes in their starting and late outfits, and townsfolk.
	var outfits := [
		[&"rough_handaxe", [&"horned_helm", &"padded_vest"]],
		[&"squire_sword", [&"squire_helm", &"padded_vest", &"wooden_buckler"]],
		[&"apprentice_staff", [&"wizard_hat", &"apprentice_robe"]],
		[&"rusty_dagger", [&"shadow_hood", &"leather_gloves", &"worn_boots"]],
		[&"iron_sword", [&"iron_helm", &"chainmail", &"iron_gauntlets", &"iron_greaves", &"iron_kite_shield"]],
		[&"starfall_blade", [&"crown_of_stars", &"mithril_plate", &"aegis_of_dawn", &"starmetal_amulet"]],
	]
	var heroes: Array = []
	for i in outfits.size():
		var m := HumanoidModel.new()
		world.add_child(m)
		m.set_appearance()
		var w: ItemData = ItemDB.get_item(outfits[i][0])
		m.set_weapon(w.weapon_type, outfits[i][1].any(func(id: StringName) -> bool: return ItemDB.get_item(id).equip_slot == ItemData.EquipSlot.OFF_HAND))
		m.set_outfit(PackedStringArray(outfits[i][1].map(func(id: StringName) -> String: return String(id))), w.id)
		var pos := c + Vector3((i - 2.5) * 1.15, 0, 0)
		pos.y = world.get_ground_height(pos)
		m.global_position = pos
		heroes.append(m)
	var gy2 := world.get_ground_height(c)
	cam.global_position = Vector3(c.x, gy2 + 1.0, c.z) + Vector3(0, sin(deg_to_rad(10.0)), cos(deg_to_rad(10.0))) * 7.2
	cam.look_at(Vector3(c.x, gy2 + 1.0, c.z))
	await _wait(10)
	await _shot("pixel_world_heroes")
	for m in heroes:
		m.queue_free()
	var folk: Array = []
	var roles := [&"villager", &"farmer", &"blacksmith", &"merchant", &"guard", &"noble"]
	for i in roles.size():
		var m := HumanoidModel.new()
		world.add_child(m)
		m.set_npc_look(roles[i], 17 + i * 23, Color(0.7, 0.25, 0.2))
		var pos := c + Vector3((i - 2.5) * 1.15, 0, 0)
		pos.y = world.get_ground_height(pos)
		m.global_position = pos
		folk.append(m)
	await _wait(10)
	await _shot("pixel_world_townsfolk")
	# The normal game camera with a mixed group.
	for m in folk:
		m.queue_free()
	world.camera_rig.set_process(true)
	world.camera_rig.camera.current = true
	await _teleport(world, c + Vector3(0, 0, 3))
	for k in 6:
		var id: StringName = [&"skeleton_warrior", &"bandit_thug", &"frost_wolf", &"tusker_grunt", &"cultist_acolyte", &"thornback_boar"][k]
		var d := load("res://data/enemies/%s.tres" % id) as EnemyData
		var pos := c + Vector3((k - 2.5) * 1.8, 0, -1.0)
		pos.y = world.get_ground_height(pos) + 0.3
		var scene: PackedScene = load(Monster.MONSTER_SCENE_PATH) if d is MonsterData else load("res://scenes/enemies/thornback_boar.tscn")
		var m := world.spawner.spawn_enemy(scene, pos, "", d) as Enemy
		if m is Monster:
			(m as Monster).make_dormant(-1.0)
	world.camera_rig._target_distance = 12.0
	await _wait(60)
	await _shot("pixel_world_game_camera")


## Milestone 23: the eight elemental armour sets, worn in full.
func _elements_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(0, 0, 16))
	_clear_monsters(world)
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 38.0
	world.add_child(cam)
	cam.current = true
	var weapons := [&"sunforged_blade", &"staff_of_the_archmage", &"shadowfang", &"iron_pike", &"apprentice_staff", &"iron_warhammer", &"mithril_waraxe", &"recurve_bow"]
	var groups := [GearSets.ELEMENTAL.slice(0, 4), GearSets.ELEMENTAL.slice(4, 8)]
	for gi in 2:
		var models: Array = []
		for i in 4:
			var set_id: StringName = groups[gi][i]
			var ids := PackedStringArray()
			for id in LootTables.elemental_pieces():
				if ItemDB.get_item(id).set_id == set_id:
					ids.append(String(id))
			var m := HumanoidModel.new()
			world.add_child(m)
			m.set_appearance()
			var w: ItemData = ItemDB.get_item(weapons[gi * 4 + i])
			m.set_weapon(w.weapon_type, false)
			m.set_outfit(ids, w.id)
			var pos := c + Vector3((i - 1.5) * 1.35, 0, 0)
			pos.y = world.get_ground_height(pos)
			m.global_position = pos
			models.append(m)
		var gy := world.get_ground_height(c)
		var target := Vector3(c.x, gy + 1.1, c.z)
		cam.global_position = target + Vector3(0, sin(deg_to_rad(8.0)), cos(deg_to_rad(8.0))) * 6.4
		cam.look_at(target)
		await _wait(12)
		await _shot("elements_%d" % (gi + 1))
		for m in models:
			m.queue_free()
		await _wait(3)


## Milestone 24: the Creative panel's tabs.
func _creative_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	_clear_monsters(world)
	var panel := world.hud.creative
	panel.set_creative(true)
	panel.toggle()
	panel._search.text = "sun"
	panel._fill_items()
	for tab in [0, 1, 2, 3, 4, 5]:
		panel._tabs.current_tab = tab
		if tab == 2:
			panel._monsters.select(panel._monster_ids.find(&"tusker_chief"))
		if tab == 5:
			panel._self_check()
		await _wait(8)
		await _shot("creative_%d" % (tab + 1))
	p.creative = false


## Milestone 26: the new ground textures and ground cover, seen from above like a diorama.
func _rich_world_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var n := 0
	# Close-up: one of each new ground-cover prop in a row.
	var flat := _dry_center(world, p.global_position, 14.0)
	await _teleport(world, flat + Vector3(0, 0, 8))
	_clear_monsters(world)
	var hidden: Array = []
	for ch in world.chunk_manager.get_children():
		for c in ch.get_children():
			if (c is MultiMeshInstance3D or c is PropBody) and c.visible:
				c.visible = false
				hidden.append(c)
	var ids := [&"flower_bush", &"fern", &"wildflowers_white", &"wildflowers_orange", &"pebbles", &"mossy_boulder", &"fallen_log", &"tree_stump", &"old_gravestone", &"rock"]
	var holders: Array = []
	for i in ids.size():
		var mi := MeshInstance3D.new()
		mi.mesh = world.props.get_mesh(ids[i])
		world.add_child(mi)
		var q := flat + Vector3((i % 5 - 2) * 2.6, 0, (i / 5) * 3.2 - 1.6)
		q.y = world.get_ground_height(q)
		mi.global_position = q
		holders.append(mi)
	var tgt := Vector3(flat.x, world.get_ground_height(flat) + 0.4, flat.z)
	cam.global_position = tgt + Vector3(0, 5.5, 10.5)
	cam.look_at(tgt)
	await _wait(20)
	await _shot("richworld_0_props")
	for h in holders:
		h.queue_free()
	for c in hidden:
		if is_instance_valid(c):
			c.visible = true
	for biome in [&"verdant_meadow", &"whispering_forest", &"emerald_jungle", &"frostpine_taiga"]:
		var spot := _find_biome(world.generator, p.global_position, biome)
		if spot == Vector3.INF:
			print("no ", biome)
			continue
		await _teleport(world, spot)
		_clear_monsters(world)
		var g := world.get_ground_height(spot)
		for view in 2:
			var yaw := deg_to_rad(35.0 + view * 120.0)
			var dist := 16.0 if view == 0 else 26.0
			var pitch := deg_to_rad(42.0)
			var target := Vector3(spot.x, g + 0.5, spot.z)
			cam.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
			cam.look_at(target)
			await _wait(20)
			n += 1
			await _shot("richworld_%d_%s" % [n, biome])



## Milestone 30: a two-storey house with stairs, a balcony and a ladder.
## Milestone 34: restyled sand, snow and cave stone, stairs and path tiles, water ripples.
func _textures_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	p.creative = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	var g := world.generator
	var origin := p.global_position
	var n := 1
	for id in [&"sandy_beach", &"snowy_tundra"]:
		var q := _find_biome(g, origin, id)
		if q == Vector3.INF:
			continue
		await _teleport(world, q)
		_clear_monsters(world)
		world.camera_rig._target_distance = 9.0
		world.camera_rig._target_pitch = 50.0
		await _wait(60)
		await _shot("textures_%d_%s" % [n, id])
		n += 1
	# Paths and stairs on flat meadow ground.
	var flat := _dry_center(world, origin, 14.0)
	await _teleport(world, flat)
	_clear_monsters(world)
	world.hud.creative._demo_paths()
	p.global_position += Vector3(5.5, 0, 1.0)
	world.camera_rig._target_distance = 10.0
	world.camera_rig._target_pitch = 55.0
	await _wait(60)
	await _shot("textures_%d_paths_stairs" % n)
	n += 1
	# Water ripples at a shore.
	var shore := Vector3.INF
	for r in range(20, 1500, 20):
		for k in 24:
			var q := origin + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * r
			if g.get_height_at(q) < TerrainGenerator.WATER_Y - 2.0 and g.get_height_at(q + Vector3(6, 0, 0)) > TerrainGenerator.WATER_Y:
				shore = q + Vector3(6, 0, 0)
				break
		if shore != Vector3.INF:
			break
	if shore != Vector3.INF:
		await _teleport(world, shore)
		world.camera_rig._target_distance = 8.0
		world.camera_rig._target_pitch = 60.0
		await _wait(60)
		await _shot("textures_%d_water" % n)
		n += 1
	# Cave stone.
	var e := g.get_cave_entrances_near(floori(origin.x) - 600, floori(origin.z) - 600, floori(origin.x) + 600, floori(origin.z) + 600)
	if not e.is_empty():
		var epos := Vector3(e[0].x + 0.5, g.get_height_blocks(e[0].x, e[0].y) * 0.5, e[0].y + 0.5)
		await _teleport(world, epos + Vector3(3, 0.5, 2))
		world.travel_to_layer(TerrainGenerator.Layer.UNDERGROUND, epos)
		while not world.is_ready:
			await get_tree().process_frame
		world.camera_rig._target_distance = 10.0
		await _wait(80)
		await _shot("textures_%d_cave" % n)
	world.queue_free()
	await _wait(5)


## Milestone 33: the new creatures side by side (the mimic once asleep, once awake).
func _mobs_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var flat := _dry_center(world, p.global_position, 16.0)
	for k in 24:
		var q := _dry_center(world, p.global_position + Vector3(cos(k * 1.7), 0, sin(k * 1.7)) * (120.0 + k * 40.0), 16.0)
		if world.generator.pois.near(q, 40.0).is_empty() and world.generator.settlements.near(q, 120.0).is_empty():
			flat = q
			break
	await _teleport(world, flat + Vector3(-16, 0, -8))
	_clear_monsters(world)
	var y := world.get_ground_height(flat)
	var lineup := [[&"bone_dragon", Vector3(-4.5, 0, -3.5)], [&"shadow_serpent", Vector3(1.5, 0, -4.0)], [&"top_hat_bear", Vector3(5.5, 0, -4.0)],
		[&"door_mimic", Vector3(-6.5, 0, 1.5)], [&"door_mimic", Vector3(-4.0, 0, 1.5)], [&"ghost_cat", Vector3(-0.5, 0, 1.5)],
		[&"diver_zombie", Vector3(2.5, 0, 1.0)], [&"turkey", Vector3(5.5, 0, 1.5)],
		[&"cupcake_critter", Vector3(-2.5, 0, 5.0)], [&"berry_jelly", Vector3(0.5, 0, 5.0)], [&"cupcake_critter", Vector3(3.0, 0, 5.2)]]
	var asleep := true
	for e in lineup:
		var data := load("res://data/enemies/%s.tres" % e[0]) as MonsterData
		var mm := MonsterModel.new()
		world.add_child(mm)
		mm.build(data)
		mm.global_position = Vector3(flat.x, y, flat.z) + e[1]
		mm.rotation.y = 0.35
		var sleeping: bool = e[0] == &"door_mimic" and asleep
		if e[0] == &"door_mimic":
			mm.set_awake(not asleep)
			if not asleep:
				mm.play_attack(&"bite", 3.0, 0.2, 0.5)
			asleep = false
		var l := Label3D.new()
		l.text = data.display_name + (" (asleep)" if sleeping else "")
		l.font_size = 56
		l.outline_size = 12
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(l)
		l.global_position = mm.global_position + Vector3(0, 0.25 + 2.2 * minf(data.model_scale, 1.4), 0)
	var cam := Camera3D.new()
	cam.fov = 46.0
	world.add_child(cam)
	cam.current = true
	var centre := Vector3(flat.x, y + 0.8, flat.z + 0.5)
	cam.global_position = centre + Vector3(0, 10, 13.5)
	cam.look_at(centre)
	await _wait(70)
	await _shot("mobs_1_lineup")
	world.queue_free()
	await _wait(5)


## Milestone 32: a contact sheet of monster animations - idle, wind-up, strike, hurt, death.
func _anims_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	# A flat spot with no dungeon, ruin or village in the picture.
	var flat := _dry_center(world, p.global_position, 16.0)
	for k in 24:
		var q := _dry_center(world, p.global_position + Vector3(cos(k * 1.7), 0, sin(k * 1.7)) * (120.0 + k * 40.0), 16.0)
		if world.generator.pois.near(q, 40.0).is_empty() and world.generator.settlements.near(q, 120.0).is_empty():
			flat = q
			break
	await _teleport(world, flat + Vector3(-14, 0, -6))
	_clear_monsters(world)
	var rows := [&"frost_wolf", &"cave_spider", &"sand_scorpion", &"ember_phoenix", &"skeleton_warrior"]
	var cols := ["Idle", "Wind-up", "Strike", "Hurt", "Death"]
	var models: Array = []  # [row][col] -> MonsterModel
	var y := world.get_ground_height(flat)
	for r in rows.size():
		var line: Array = []
		var data := load("res://data/enemies/%s.tres" % rows[r]) as MonsterData
		for c in cols.size():
			var mm := MonsterModel.new()
			world.add_child(mm)
			mm.build(data)
			mm.scale = Vector3.ONE * minf(data.model_scale, 1.1)
			mm.global_position = Vector3(flat.x - 6.0 + c * 3.0, y, flat.z - 6.0 + r * 3.0)
			mm.rotation.y = 0.5
			line.append(mm)
		models.append(line)
		var name_l := Label3D.new()
		name_l.text = data.display_name
		name_l.font_size = 64
		name_l.outline_size = 12
		name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(name_l)
		name_l.global_position = Vector3(flat.x - 9.2, y + 0.8, flat.z - 6.0 + r * 3.0)
	for c in cols.size():
		var l := Label3D.new()
		l.text = cols[c]
		l.font_size = 72
		l.outline_size = 14
		l.modulate = Color(1, 0.9, 0.55)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(l)
		l.global_position = Vector3(flat.x - 6.0 + c * 3.0, y + 2.9, flat.z - 8.0)
	var cam := Camera3D.new()
	cam.fov = 44.0
	world.add_child(cam)
	cam.current = true
	var centre := Vector3(flat.x - 1.5, y + 0.6, flat.z)
	cam.global_position = centre + Vector3(0, 14, 14)
	cam.look_at(centre)
	await _wait(30)
	# Play everything on a game-time clock, then stop time at T for the picture.
	const T := 1.6
	var t := 0.0
	var started := [false, false, false, false]
	while t < T:
		if not started[0] and t >= T - 1.2:
			started[0] = true
			for line in models:
				line[1].play_attack(&"overhead", 2.0, 0.2, 0.5)
				line[1].set_telegraph(true)
				line[4].play_death()
		if not started[1] and t >= T - 0.4:
			started[1] = true
			for line in models:
				line[2].play_attack(&"slash", 0.2, 0.8, 0.5)
		if not started[2] and t >= T - 0.06:
			started[2] = true
			for line in models:
				line[3].flash()
				line[3].play_flinch(1.2, 1.0)
		if not started[3] and t >= T - 0.18:
			started[3] = true
			for line in models:
				line[2].hit_frame()
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 0.0
	await _wait(3)
	await _shot("anims_1_sheet")
	Engine.time_scale = 1.0
	world.queue_free()
	await _wait(5)


## Milestone 36: a 40-monster fight and the Creative frame-time report.
func _perf_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	_clear_monsters(world)
	world.hud.story.visible = false
	var panel := world.hud.creative
	panel.set_creative(true)
	await panel._spawn_crowd()
	await _wait(90)
	await _shot("perf_1_crowd")
	panel.toggle()
	panel._tabs.current_tab = 5
	await _wait(10)
	# Like the stress tool: CPU frame time (this machine draws with a slow software
	# renderer), measured once the panel has settled.
	RenderingServer.render_loop_enabled = false
	await _wait(10)
	await panel._measure_frames()
	RenderingServer.render_loop_enabled = true
	await _wait(5)
	await _shot("perf_2_report")
	world.queue_free()
	await _wait(5)


## Milestone 35: the new hand-drawn icons, as the game shows them.
func _icons_showcase() -> void:
	var groups := [
		["New items (M35)", CreativePanel.M35_ITEMS],
		["Monster drops and materials", [&"dragon_bone", &"serpent_scale", &"mimic_tooth", &"ectoplasm", &"pearl", &"turkey_feather",
			&"sugar", &"honeycomb", &"spider_silk", &"ember_feather", &"hedgehog_quill", &"candle_wax", &"acorn", &"blossom_petal"]],
		["Elemental and M27 gear", [&"sunflare_helm", &"sunflare_plate", &"amethyst_crown", &"amethyst_robe", &"wraithbone_mask",
			&"wraithbone_coat", &"sporecap_hat", &"sporecap_vest", &"dawnbloom_crown", &"dawnbloom_mantle", &"stoneheart_helm",
			&"stoneheart_plate", &"stormcopper_helm", &"stormcopper_plate", &"brassworks_tophat", &"brassworks_coat",
			&"paladin_helm", &"paladin_plate", &"pilgrim_hood", &"pilgrim_robe", &"explorer_hood", &"explorer_pack",
			&"gilded_greatsword", &"gilded_kite_shield", &"prismheart_blade", &"sporecrown_staff", &"starlance"]],
		["Travel and dungeons", [&"dungeon_key", &"delvers_mark", &"riding_saddle", &"leather_saddle", &"rowboat", &"war_banner_scrap"]],
	]
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UITheme.panel_style())
	panel.position = Vector2(30, 24)
	panel.size = Vector2(get_viewport().get_visible_rect().size) - Vector2(60, 48)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	panel.add_child(v)
	for g in groups:
		var title := Label.new()
		title.text = g[0]
		title.add_theme_color_override(&"font_color", UITheme.GOLD)
		title.add_theme_font_size_override(&"font_size", 20)
		v.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 14
		grid.add_theme_constant_override(&"h_separation", 6)
		grid.add_theme_constant_override(&"v_separation", 4)
		v.add_child(grid)
		for id in g[1]:
			if not ItemDB.has_item(id):
				continue
			var it: ItemData = ItemDB.get_item(id)
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(102, 0)
			var tr := TextureRect.new()
			tr.texture = ItemIcons.get_icon(it)
			tr.custom_minimum_size = Vector2(56, 56)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cell.add_child(tr)
			var l := Label.new()
			l.text = it.display_name
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override(&"font_size", 11)
			l.add_theme_color_override(&"font_color", it.rarity_color())
			cell.add_child(l)
			grid.add_child(cell)
	await _wait(10)
	await _shot("icons_1_sheet")


## v0.42.1: the dodge roll, seen from the side at seven moments.
func _roll_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 11.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var flat := _dry_center(world, p.global_position, 16.0)
	for k in 24:
		var q := _dry_center(world, p.global_position + Vector3(cos(k * 1.7), 0, sin(k * 1.7)) * (120.0 + k * 40.0), 16.0)
		if world.generator.pois.near(q, 40.0).is_empty() and world.generator.settlements.near(q, 120.0).is_empty():
			flat = q
			break
	await _teleport(world, flat + Vector3(0, 0, -12))
	_clear_monsters(world)
	# A plain stone stage high above the trees, so nothing hides the poses.
	var y := world.get_ground_height(flat) + 40.0
	var stage := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(22, 0.4, 6)
	stage.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.45, 0.42, 0.38)
	stage.material_override = sm
	world.add_child(stage)
	stage.global_position = Vector3(flat.x, y - 0.2, flat.z)
	const STEPS := [0.0, 0.08, 0.16, 0.22, 0.28, 0.34, 0.42]
	for i in STEPS.size():
		var m := HumanoidModel.new()
		world.add_child(m)
		m.global_position = Vector3(flat.x - 7.2 + i * 2.4, y, flat.z)
		m.rotation.y = PI * 0.5  # rolling to the right of the picture
		await _wait(2)
		m.set_process(false)
		m.play_dodge(0.42)
		var t := 0.0
		while t < float(STEPS[i]) - 0.0001:
			m._process(1.0 / 60.0)
			t += 1.0 / 60.0
		if t == 0.0:
			m._process(0.0001)
		var l := Label3D.new()
		l.text = "%.2f s" % float(STEPS[i])
		l.font_size = 56
		l.outline_size = 12
		l.modulate = Color(1, 0.9, 0.55)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(l)
		l.global_position = Vector3(flat.x - 7.2 + i * 2.4, y + 2.6, flat.z)
	var cam := Camera3D.new()
	cam.fov = 38.0
	world.add_child(cam)
	cam.current = true
	var centre := Vector3(flat.x, y + 0.9, flat.z)
	cam.global_position = centre + Vector3(0, 2.0, 21)
	cam.look_at(centre)
	await _wait(20)
	await _shot("roll_1_side")
	world.queue_free()
	await _wait(5)


## Milestone 31: fog of war, the mini-map, a lever puzzle and the locked gate.
func _dungeon2_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.hud._help.visible = false
	var poi := PoiInfo.new()
	poi.kind = PoiInfo.Kind.DUNGEON
	poi.rank = 3
	poi.theme = PoiInfo.DungeonTheme.CRYPT
	poi.id = "shot_dungeon"
	poi.center = Vector2i(int(p.global_position.x), int(p.global_position.z))
	# A seed whose floor has a lever puzzle and a Keeper.
	for sd in range(1, 400):
		poi.seed = sd
		var pl := DungeonPlan.generate(poi, 0)
		if pl.keeper_room >= 0 and DungeonPlan.Puzzle.LEVERS in pl.puzzles.values():
			break
	world.enter_dungeon(poi)
	await _wait(40)
	var d := world.dungeon
	for m in d.monsters:
		if is_instance_valid(m) and m != d.keeper:
			m.set_physics_process(false)
	world.hud.story.visible = false
	world.camera_rig._target_distance = 24.0
	world.camera_rig._target_pitch = 70.0
	await _wait(60)
	await _shot("dungeon2_1_fog")
	# Walk through a few rooms: the map fills in.
	var order: Array = []
	for i in d.plan.rooms.size():
		if i != d.plan.start_room and d.plan.rooms[i].type != DungeonPlan.Room.SECRET:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return d.plan.room_center(a).distance_to(d.plan.room_center(d.plan.start_room)) < d.plan.room_center(b).distance_to(d.plan.room_center(d.plan.start_room)))
	for i in order.slice(0, 3):
		p.global_position = d.to_global(d.plan.room_center(i) + Vector3(0, 0.3, 0))
		await _wait(20)
	world.camera_rig._target_distance = 30.0
	await _wait(40)
	await _shot("dungeon2_2_map_fills")
	# The lever puzzle: three levers with runes, the chest in its cage.
	for room in d.puzzles:
		if d.puzzles[room].kind == DungeonPlan.Puzzle.LEVERS:
			p.global_position = d.to_global(d.plan.room_center(room) + Vector3(0, 0.3, 3.5))
			p.face_direction(Vector3(0, 0, -1), true)
			world.camera_rig._target_distance = 12.0
			world.camera_rig._target_pitch = 62.0
			await _wait(60)
			await _shot("dungeon2_3_levers")
			break
	# The locked gate in front of the last room, the Keeper close by.
	if not d.gates.is_empty():
		var g: DungeonGate = d.gates[0]
		var away := (g.position - d.plan.room_center(d.plan.end_room))
		away.y = 0.0
		p.global_position = d.to_global(g.position + away.normalized() * 3.0 + Vector3(0, 0.3, 0))
		p.face_direction(-away.normalized(), true)
		if d.keeper and is_instance_valid(d.keeper):
			d.keeper.global_position = d.to_global(g.position + away.normalized() * 5.0 + Vector3(1.5, 0.3, 0))
			d.keeper.set_physics_process(false)
		world.camera_rig._target_distance = 12.0
		world.camera_rig._target_pitch = 62.0
		await _wait(60)
		await _shot("dungeon2_4_gate")
	world.queue_free()
	await _wait(5)


func _storeys_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 15.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 42.0
	world.add_child(cam)
	cam.current = true
	var flat := _dry_center(world, p.global_position, 14.0)
	await _teleport(world, flat + Vector3(-8, 0, 8))
	_clear_monsters(world)
	var c := Vector2i(floori(flat.x) - 2, floori(flat.z) - 2)
	world.building.build_demo_house(c)
	world.building.set_process(false)  # keep the roof on for the pictures
	await _wait(10)
	var centre := Vector3(c.x + 3.0, world.building._base(c) + 2.6, c.y + 3.0)
	cam.global_position = centre + Vector3(11, 8, 13)
	cam.look_at(centre)
	await _wait(20)
	await _shot("storeys_1_house")
	# The hero on the balcony, a skeleton coming up the stairs.
	p.global_position = Vector3(c.x + 2.5, world.building.storey_y(Vector2i(c.x + 2, c.y + 4), 1) + 0.2, c.y + 4.5)
	p.face_direction(Vector3(0, 0, 1), true)
	var data := load("res://data/enemies/skeleton_warrior.tres") as EnemyData
	world.spawner.max_active = 3
	var m := world.spawner.spawn_enemy(load(Monster.MONSTER_SCENE_PATH), Vector3(c.x + 5.5, world.building._base(c) + 1.7, c.y + 2.6), "", data)
	if m:
		m.set_physics_process(false)
		m.model.rotation.y = 0.0
	cam.global_position = centre + Vector3(9, 3, 11)
	cam.look_at(centre + Vector3(1.5, 0, 1.5))
	await _wait(20)
	await _shot("storeys_2_balcony")
	# Inside: the roof lifts away over you, the upper room with bed and chest.
	for k in world.building.pieces:
		var bp: BuildPiece = world.building.pieces[k]
		if BuildingManager.base_slot(bp.slot) == "roof":
			bp.visible = false
	cam.global_position = centre + Vector3(2, 9, 6)
	cam.look_at(centre + Vector3(0, 0, -0.5))
	await _wait(10)
	await _shot("storeys_3_upstairs")


## Milestone 29: a horse herd, riding with a saddle, a waystone and a rowboat.
func _travel_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var tm := world.travel
	# 1: a wild herd.
	var herds := tm.herds_near(p.global_position, 3000.0)
	if not herds.is_empty():
		await _teleport(world, herds[0][1] + Vector3(6, 0, 6))
		_clear_monsters(world)
		tm.update_now()
		await _wait(30)
		var c: Vector3 = herds[0][1]
		c.y = world.get_ground_height(c) + 1.0
		cam.global_position = c + Vector3(7, 5, 9)
		cam.look_at(c)
		await _wait(5)
		await _shot("travel_1_herd")
		# 2: riding a saddled horse.
		var horse: Horse = null
		for h in get_tree().get_nodes_in_group(&"horses"):
			horse = h
		if horse:
			horse.make_tame()
			p.inventory.add_item(&"leather_saddle", 1)
			horse.put_saddle(p, &"leather_saddle")
			# A clearing without trees for the riding picture.
			var spot := p.global_position
			for r in range(4, 80, 4):
				var found := false
				for k in 12:
					var q: Vector3 = herds[0][1] + Vector3(cos(TAU * k / 12.0), 0, sin(TAU * k / 12.0)) * r
					q.y = world.get_ground_height(q)
					if TreeFire.trees_near(world, q, 6.0).is_empty() and q.y > TerrainGenerator.WATER_Y + 0.5:
						spot = q
						found = true
						break
				if found:
					break
			p.global_position = spot + Vector3(0, 0.3, 0)
			horse.global_position = spot
			await _wait(5)
			horse.mount(p)
			p.face_direction(Vector3(1, 0, 0.3), true)
			for i in 20:
				horse.follow_rider(p.global_position, p.model.rotation.y, 6.0, 0.05)
				await get_tree().process_frame
			var hp := p.global_position + Vector3(0, 1.4, 0)
			cam.global_position = hp + Vector3(-2.0, 2.8, 6.5)
			cam.look_at(hp)
			await _wait(5)
			await _shot("travel_2_riding")
			p.stop_riding(false, true)
	# 3: a waystone in a village.
	var towns := world.living.settlements().near(p.global_position, 4000.0)
	if not towns.is_empty():
		await _teleport(world, towns[0].world_center() + Vector3(6, 0, 2))
		_clear_monsters(world)
		tm.update_now()
		var ws := tm.waystone("s:" + towns[0].id)
		if ws:
			ws.interact(p)
			var q := ws.global_position + Vector3(0, 1.3, 0)
			cam.global_position = q + Vector3(4, 2.5, 5)
			cam.look_at(q)
			await _wait(25)
			await _shot("travel_3_waystone")
	# 4: rowing a boat.
	var water := Vector3.INF
	for r in range(20, 2000, 20):
		for k in 24:
			var q := p.global_position + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * r
			if world.generator.get_height_at(q) < TerrainGenerator.WATER_Y - 4.0:
				water = q
				break
		if water != Vector3.INF:
			break
	if water != Vector3.INF:
		await _teleport(world, water)
		var boat := Boat.launch(world, water)
		if boat:
			boat.board(p)
			p.face_direction(Vector3(1, 0, 0), true)
			for i in 10:
				boat.follow_rider(p.global_position, p.model.rotation.y, 0.0, 0.05)
				await get_tree().process_frame
			var bq := boat.global_position + Vector3(0, 0.8, 0)
			cam.global_position = bq + Vector3(-3, 3.5, 5.5)
			cam.look_at(bq)
			await _wait(20)
			await _shot("travel_4_boat")


## Milestone 28: one forest view in each season, a burning tree, and rain on a farm.
func _seasons_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	cam.current = true
	var spot := _find_biome(world.generator, p.global_position, &"whispering_forest")
	if spot == Vector3.INF:
		spot = p.global_position
	await _teleport(world, spot)
	_clear_monsters(world)
	var g := world.get_ground_height(spot)
	var target := Vector3(spot.x, g + 1.0, spot.z)
	cam.global_position = target + Vector3(14, 13, 18)
	cam.look_at(target)
	for k in 4:
		Seasons.forced = k
		world.weather.force(WeatherSystem.Kind.SNOW if k == 3 else WeatherSystem.Kind.CLEAR, 0.6)
		world.weather.settle()
		await _wait(25)
		await _shot("seasons_%d_%s" % [k + 1, String(Seasons.IDS[k])])
	# A tree struck by lightning, in autumn.
	Seasons.forced = Seasons.Season.AUTUMN
	world.weather.force(WeatherSystem.Kind.CLOUDY, 1.0)
	world.weather.settle()
	world.day_night.hour = 17.2
	world.day_night.advance_hours(0.0)
	var trees := TreeFire.trees_near(world, target, 25.0)
	if not trees.is_empty():
		var f := TreeFire.ignite(trees[0])
		if f:
			f.age = 6.0
			cam.global_position = f.global_position + Vector3(9, 9, 12)
			cam.look_at(f.global_position + Vector3(0, 2.5, 0))
	await _wait(25)
	await _shot("seasons_5_tree_fire")
	Seasons.forced = -1


## Milestone 27: the new mobs and the new gear.
func _new_folk_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.hud.visible = false
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.5
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	var c := _dry_center(world, p.global_position, 26.0)
	await _teleport(world, c + Vector3(0, 0, 18))
	_clear_monsters(world)
	for ch in world.chunk_manager.get_children():
		for n in ch.get_children():
			if n is MultiMeshInstance3D or n is PropBody:
				n.visible = false
	world.camera_rig.set_process(false)
	Materials.set_camera_fade(0.0)
	var cam := Camera3D.new()
	cam.fov = 36.0
	world.add_child(cam)
	cam.current = true
	var groups := [
		[&"bumblebee", &"hedgehog", &"acorn_sprout", &"frost_fox", &"blossom_stag"],
		[&"cave_spider", &"hexpaw", &"candle_skull", &"pumpkin_creeper", &"ember_phoenix"],
	]
	var made: Array = []
	for gi in groups.size():
		for m in made:
			m.queue_free()
		made.clear()
		var ids: Array = groups[gi]
		for i in ids.size():
			var data := load("res://data/enemies/%s.tres" % ids[i]) as MonsterData
			var mm := MonsterModel.new()
			world.add_child(mm)
			mm.build(data)
			var pos := c + Vector3((i - 2) * 1.9, 0, 0)
			pos.y = world.get_ground_height(pos)
			mm.global_position = pos
			mm.rotation.y = 0.35
			made.append(mm)
		var gy := world.get_ground_height(c)
		var target := Vector3(c.x, gy + 0.8, c.z)
		cam.global_position = target + Vector3(0, 2.6, 8.6)
		cam.look_at(target)
		for f in 20:
			for mm in made:
				(mm as MonsterModel).set_locomotion(0.0, 1.0 / 60.0)
			await get_tree().process_frame
		await _shot("newfolk_mobs_%d" % (gi + 1))
	for m in made:
		m.queue_free()
	made.clear()
	# Heroes in the new gear.
	var outfits := [
		[["explorer_hood", "explorer_pack", "explorer_gloves", "explorer_boots"], &"sporecrown_staff", false],
		[["paladin_helm", "paladin_plate", "paladin_gauntlets", "paladin_greaves", "gilded_kite_shield"], &"prismheart_blade", true],
		[["paladin_helm", "paladin_plate", "paladin_gauntlets", "paladin_greaves"], &"gilded_greatsword", false],
		[["pilgrim_hood", "pilgrim_robe"], &"starlance", false],
		[["paladin_helm", "paladin_plate", "paladin_gauntlets", "paladin_greaves"], &"gilded_halberd", false],
	]
	for i in outfits.size():
		var o: Array = outfits[i]
		var h := HumanoidModel.new()
		world.add_child(h)
		h.set_appearance()
		var w: ItemData = ItemDB.get_item(o[1])
		h.set_weapon(w.weapon_type, o[2])
		h.set_outfit(PackedStringArray(o[0]), w.id)
		var pos := c + Vector3((i - 2) * 1.35, 0, 0)
		pos.y = world.get_ground_height(pos)
		h.global_position = pos
		h.rotation.y = 0.3 if i != 0 else PI * 0.85  # the explorer shows the pack
		made.append(h)
	var gy2 := world.get_ground_height(c)
	var t2 := Vector3(c.x, gy2 + 1.0, c.z)
	cam.global_position = t2 + Vector3(0, 1.0, 7.4)
	cam.look_at(t2)
	await _wait(15)
	await _shot("newfolk_gear")


## Milestone 37: release polish - the new title screen, the "First steps"
## tutorial in a village full of townsfolk, and the graphics settings.
func _release_showcase() -> void:
	CrashHandler.crashed_last_time = false  # an earlier test run may have been stopped
	var m := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	add_child(m)
	await _wait(90)
	await _shot("m37_1_title_screen")
	m.queue_free()
	await _wait(5)
	var saved_profile := Tutorial.profile_path
	Tutorial.profile_path = "user://shot_profile_m37.cfg"
	DirAccess.remove_absolute(Tutorial.profile_path)
	Tutorial.reset_progress()
	Settings.values["tutorial_hints"] = true
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	world.day_night.day_length = 1.0e9
	world.day_night.hour = 10.0
	world.day_night.advance_hours(0.0)
	world.weather.force(0, 1.0)
	world.weather.settle()
	_clear_monsters(world)
	world.hud.story.visible = false
	var green := [&"verdant_meadow", &"whispering_forest", &"emerald_jungle"]
	var village: SettlementInfo = null
	for st in world.generator.settlements.near(p.global_position, 4000.0):
		if not st.is_kingdom() and (village == null or (st.biome_id in green and not village.biome_id in green)):
			village = st
	await _teleport(world, village.world_center() + Vector3(0.5, 0, -1.5))
	world.living.update_now(true)
	world.living.finish_sites()
	await _wait(30)
	# The checklist two steps in (the other hints already seen, so only the checklist shows).
	for st in Tutorial.STEPS:
		if not Tutorial._covered_by_first_steps(st.id):
			Tutorial.done[st.id] = true
	Tutorial.start_first_steps()
	Tutorial.fs_done[&"fs_move"] = true
	Tutorial.fs_done[&"fs_gather"] = true
	Tutorial.first_steps_changed.emit()
	# Townsfolk out and about around the player, a few walking past.
	var site := world.living.site_of(village)
	if site:
		var c := site.to_local(p.global_position)
		var k := 0
		for n in site.npcs:
			if k >= 6:
				break
			n.visible = true
			n.asleep = false
			n._think = 999.0
			var a := TAU * k / 6.0
			n.position = c + Vector3(cos(a), 0, sin(a)) * 3.2
			n.position.y = c.y - 0.4
			n._path = PackedVector3Array([c - Vector3(cos(a), 0, sin(a)) * 3.2 + Vector3(0, -0.4, 0)]) if k % 2 == 0 else PackedVector3Array()
			n._path_i = 0
			n._reset_progress()
			k += 1
	world.camera_rig._target_distance = 18.0
	world.camera_rig._target_pitch = 52.0
	await _wait(75)
	await _shot("m37_2_first_steps_village")
	# Graphics settings: quality preset, field of view, anti-aliasing.
	var sp: SettingsPanel = world.hud._settings
	world.hud._pause.visible = true  # the settings panel lives on the pause screen
	world.hud._pause_box.visible = false
	sp.visible = true
	for i in sp.tabs.get_tab_count():
		if sp.tabs.get_tab_title(i).begins_with("Display"):
			sp.tabs.current_tab = i
	await _wait(20)
	await _shot("m37_3_graphics_settings")
	sp.visible = false
	world.hud._pause.visible = false
	world.queue_free()
	await _wait(5)
	DirAccess.remove_absolute(Tutorial.profile_path)
	Tutorial.profile_path = saved_profile
	Tutorial.load_progress()


## Milestone 38: the reference clip's feel - dungeon camera, a hit, the blasts, a death poof.
func _feel_showcase() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 40
	world.hud._help.visible = false
	var poi := PoiInfo.new()
	poi.kind = PoiInfo.Kind.DUNGEON
	poi.rank = 1
	poi.theme = PoiInfo.DungeonTheme.CRYPT
	poi.id = "shot_feel"
	poi.seed = 7
	poi.center = Vector2i(int(p.global_position.x), int(p.global_position.z))
	world.enter_dungeon(poi)
	await _wait(40)
	var d := world.dungeon
	for m in d.monsters:
		if is_instance_valid(m):
			m.queue_free()
	world.hud.story.visible = false
	await _wait(90)
	await _shot("feel_1_dungeon_camera")
	var aim := p.get_aim_direction()
	var pos := p.global_position + aim * 1.7
	pos.y = world.get_ground_height(pos) + 0.3
	var md := (load("res://data/enemies/bandit_thug.tres") as MonsterData).duplicate() as MonsterData
	md.dodge_chance = 0.0  # a clean hit for the picture
	var m := world.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", md) as Monster
	m.configure(PoiLayout.RANK_POWER[0], PoiLayout.RANK_DAMAGE[0], PoiLayout.RANK_LEVELS[0], PoiLayout.RANK_XP[0])
	m.health.max_health = 50000.0
	m.health.current = 50000.0
	await _wait(20)
	m.set_physics_process(false)
	m.global_position = pos
	Engine.time_scale = 0.02
	p.combat.request(&"light")
	for i in 600:
		await get_tree().process_frame
		if p.combat.phase == PlayerCombat.Phase.ACTIVE:
			break
	await _wait_game(CombatFeel.sec(1.0))
	await _shot("feel_2_hit_pop_flash")
	await _wait_game(CombatFeel.sec(6.0))
	await _shot("feel_2b_number_pops_out")
	Engine.time_scale = 1.0
	await _wait(30)
	# The middle of the room, so the blasts are not inside a wall.
	var fwd := d.to_global(d.plan.room_center(d.plan.start_room))
	fwd.y = p.global_position.y
	if fwd.distance_to(p.global_position) < 3.0:
		fwd = p.global_position + aim * 3.5
	# Effects are drawn frozen at an exact frame (this software renderer is too slow to catch them live).
	for f in [3.0, 7.0, 16.0]:
		BlastFX.preview_time = CombatFeel.sec(f)
		BlastFX.fire_blast(d, fwd, 3.25)
		await _wait(2)
		await _shot("feel_3_fire_blast_f%d" % int(f))
		await _wait_real(2.2)
	for f in [1.0, 4.0, 20.0]:
		BlastFX.preview_time = CombatFeel.sec(f)
		BlastFX.magic_burst(d, fwd, 4.2, &"arcane")
		await _wait(2)
		await _shot("feel_5_magic_f%d" % int(f))
		await _wait_real(2.2)
	var side := aim.cross(Vector3.UP).normalized()
	BlastFX.preview_time = CombatFeel.sec(6.0)
	BlastFX.poison_cloud(d, fwd + side * 3.0, 2.3, 3.0)
	BlastFX.fire_pillar(d, fwd - side * 3.0)
	BlastFX.preview_time = CombatFeel.sec(2.0)
	BlastFX.beam(d, p.global_position + Vector3(0, 1.2, 0), fwd + Vector3(0, 1.0, 0))
	await _wait(2)
	await _shot("feel_7_poison_pillar_beam")
	BlastFX.preview_time = -1.0
	await _wait_real(2.2)
	m.set_physics_process(true)
	m.health.current = 0.1
	m.receive_hit(DamageInfo.create(99.0, p, &"true"))
	await _wait_game(0.45)
	await _shot("feel_8_death_tip")
	await _wait_game(Enemy.DEATH_POOF - 0.45 + CombatFeel.sec(3.0))
	await _shot("feel_9_death_poof")
	Engine.time_scale = 1.0
	world.queue_free()
	await _wait(5)


## Waits `seconds` of real time.
func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Waits until `seconds` of game time have passed (works with Engine.time_scale).
func _wait_game(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()

