extends Node
## Records a scripted gameplay demo with Godot's Movie Maker mode.
##
##   godot --path . --write-movie /tmp/demo.avi --fixed-fps 30 --resolution 1280x720 \
##       res://tests/video_runner.tscn
##
## Every action goes through the real game: simulated key/mouse input (InputEventAction,
## Input.action_press, mouse warps), the real HUD, building, crafting and combat code.
## A few shortcuts are labelled on screen (demo materials, debug-spawned boars, teleports).
## Loading/streaming waits are logged as "CUT <from> <to>" frame ranges so tools/make_video.sh
## can drop them.

var world: World
var _caption := Label.new()
var _caption_panel := PanelContainer.new()
var _title := ColorRect.new()
var _cut_from := -1


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_panel.offset_top = 128
	_caption_panel.add_theme_stylebox_override(&"panel", UITheme.panel_style(Color(0.05, 0.05, 0.08, 0.78), UITheme.GOLD, 2, 10))
	_caption_panel.visible = false
	layer.add_child(_caption_panel)
	_caption.add_theme_font_size_override(&"font_size", 22)
	_caption.add_theme_color_override(&"font_color", Color(1, 0.95, 0.8))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_panel.add_child(_caption)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.color = Color(0.05, 0.05, 0.09, 0.9)
	_title.visible = false
	layer.add_child(_title)
	var tl := Label.new()
	tl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override(&"font_size", 34)
	tl.add_theme_color_override(&"font_color", UITheme.GOLD)
	tl.name = "Text"
	_title.add_child(tl)
	await _run()
	print("DEMO_DONE")
	get_tree().quit()


# --- Recording helpers --------------------------------------------------------------------

func _frame() -> int:
	return Engine.get_frames_drawn()


func _cut_begin() -> void:
	_cut_from = _frame()


func _cut_end() -> void:
	print("CUT %d %d" % [_cut_from, _frame()])
	_cut_from = -1


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _say(text: String) -> void:
	print("SAY %d %s" % [_frame(), text])
	_caption.text = text
	_caption_panel.visible = text != ""


func _card(text: String, frames: int) -> void:
	(_title.get_node("Text") as Label).text = text
	_title.modulate.a = 1.0
	_title.visible = true
	await _wait(frames)
	var tw := _title.create_tween()
	tw.tween_property(_title, "modulate:a", 0.0, 0.6)
	await _wait(20)
	_title.visible = false


func _tap(action: StringName, hold: int = 3) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(hold)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(1)


func _aim(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := Vector3(pos.x, world.player.global_position.y, pos.z)
	if cam.is_position_behind(at):
		return
	get_viewport().warp_mouse(cam.unproject_position(at))


func _release_moves() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint"]:
		Input.action_release(a)


## Walks (camera-relative WASD, like a player) until within `stop` metres.
func _walk_to(target: Vector3, stop: float = 1.2, max_frames: int = 400, sprint: bool = false) -> bool:
	var p := world.player
	for i in max_frames:
		var d := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z)
		if d.length() <= stop:
			break
		d = d.normalized()
		var fwd := world.camera_rig.get_forward_flat()
		var right := world.camera_rig.get_right_flat()
		_release_moves()
		var f := d.dot(fwd)
		var r := d.dot(right)
		if f > 0.38:
			Input.action_press(&"move_forward")
		elif f < -0.38:
			Input.action_press(&"move_back")
		if r > 0.38:
			Input.action_press(&"move_right")
		elif r < -0.38:
			Input.action_press(&"move_left")
		if sprint:
			Input.action_press(&"sprint")
		_aim(target)
		await get_tree().process_frame
	_release_moves()
	var left := Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length()
	return left <= stop + 0.3


func _boot(class_id: StringName) -> void:
	_cut_begin()
	SaveManager.start_transient(GameState.DEFAULT_SEED, class_id)
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	while not world.is_ready:
		await get_tree().process_frame
	var frames := 0
	while world.chunk_manager.pending_count() > 0 and frames < 1500:
		await get_tree().process_frame
		frames += 1
	world.hud._help.visible = false
	await _wait(20)
	_cut_end()


func _teleport(pos: Vector3) -> void:
	_cut_begin()
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
	await _wait(25)
	_cut_end()


func _find_body(pred: Callable, max_dist: float = 30.0) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Node3D and pred.call(n):
			var d := (n as Node3D).global_position.distance_to(world.player.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func _yaw_to(deg: float, frames: int) -> void:
	world.camera_rig._target_yaw = deg
	await _wait(frames)


# --- The demo --------------------------------------------------------------------------------

func _run() -> void:
	await _boot(&"knight")
	var p := world.player
	world.spawner.max_active = 0
	world.spawner.despawn_all()
	world.day_night.hour = 9.0
	world.camera_rig._target_distance = 15.0
	await _card("SHARDLANDS\n\ngameplay demo · v0.4.0\n\nscripted run: simulated keyboard & mouse", 75)
	_say("Knight · Whispering Forest · WASD, camera-relative")
	# Explore a little
	var start := p.global_position
	await _walk_to(start + world.camera_rig.get_forward_flat() * 6.0 + world.camera_rig.get_right_flat() * 3.0, 1.0, 110)
	await _yaw_to(world.camera_rig._target_yaw + 40.0, 40)

	# Harvest a tree
	var tree := _find_body(func(n: Node) -> bool:
		return n is PropBody and n.data.interact_mode == PropData.InteractMode.HARVEST and n.data.tool_kind == &"axe", 40.0)
	if tree:
		_say("Chop a tree (left mouse)")
		await _walk_to(tree.global_position, 1.5, 300)
		for k in 14:
			if not is_instance_valid(tree) or not tree.is_inside_tree():
				break
			_aim(tree.global_position)
			await _tap(&"attack_light")
			await _wait(16)
		await _wait(30)
	# Gather
	var bush := _find_body(func(n: Node) -> bool:
		return n is PropBody and n.data.interact_mode == PropData.InteractMode.GATHER, 30.0)
	if bush:
		_say("Gather with F: %s" % bush.data.display_name)
		await _walk_to(bush.global_position, 1.3, 300)
		await _tap(&"interact")
		await _wait(40)

	# Crafting
	_say("G: crafting screen · demo adds some materials")
	for id in [&"plant_fiber", &"stick", &"stone", &"wood", &"flint"]:
		p.give_item(id, 40)
	await _wait(30)
	await _tap(&"crafting")
	await _wait(35)
	var cp := world.hud._crafting
	cp.select(RecipeBook.get_recipe(&"rope"))
	await _wait(30)
	_say("Crafting never fails: low skill only costs more fiber (have / need)")
	cp.craft_selected(5)
	await _wait(50)
	cp.select(RecipeBook.get_recipe(&"stone_pickaxe"))
	await _wait(35)
	cp.craft_selected(1)
	await _wait(25)
	cp.select(RecipeBook.get_recipe(&"stone_hatchet"))
	await _wait(30)
	cp.craft_selected(1)
	await _wait(40)
	cp.select(RecipeBook.get_recipe(&"plank"))
	_say("Planks need a Workbench nearby")
	await _wait(55)
	await _tap(&"crafting")

	# Building
	for id in [&"wood", &"plank", &"rope", &"plant_fiber", &"stick", &"stone"]:
		p.give_item(id, 60)
	var o := _hut_origin()
	await _walk_to(Vector3(o.x + 1.5, 0, o.y + 6.0), 0.8, 300)
	world.camera_rig._target_distance = 14.0
	_say("B: build mode · the ghost is green where you can build")
	await _tap(&"build_mode")
	await _wait(20)
	var bm := world.build_mode
	var h := p.global_position.y
	bm.select(BuildingManager.get_piece_data(&"wood_floor"))
	for z in 3:
		for x in 3:
			await _click_build(Vector3(o.x + x + 0.5, h, o.y + z + 0.5), 7)
	_say("Walls snap to cell edges · doors · windows")
	bm.select(BuildingManager.get_piece_data(&"wood_wall"))
	for x in 3:
		await _click_build(Vector3(o.x + x + 0.5, h, o.y + 0.06), 7)
	for z in 3:
		await _click_build(Vector3(o.x + 0.06, h, o.y + z + 0.5), 7)
		if z != 1:
			await _click_build(Vector3(o.x + 3.06, h, o.y + z + 0.5), 7)
	bm.select(BuildingManager.get_piece_data(&"wood_window"))
	await _click_build(Vector3(o.x + 3.06, h, o.y + 1.5), 10)
	for x in 3:
		if x == 1:
			bm.select(BuildingManager.get_piece_data(&"wood_door"))
		else:
			bm.select(BuildingManager.get_piece_data(&"wood_wall"))
		await _click_build(Vector3(o.x + x + 0.5, h, o.y + 3.06), 8)
	_say("Furniture: bed (respawn + sleep), storage chest, torch")
	bm.select(BuildingManager.get_piece_data(&"bed"))
	await _click_build(Vector3(o.x + 0.5, h, o.y + 1.0), 14)
	bm.select(BuildingManager.get_piece_data(&"storage_chest"))
	await _click_build(Vector3(o.x + 2.5, h, o.y + 0.5), 14)
	bm.select(BuildingManager.get_piece_data(&"torch"))
	await _click_build(Vector3(o.x + 2.5, h, o.y + 2.5), 14)
	_say("Roofs need a wall or roof next to them")
	bm.select(BuildingManager.get_piece_data(&"thatch_roof"))
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2),
			Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 1)]:
		await _click_build(Vector3(o.x + cell.x + 0.5, h, o.y + cell.y + 0.5), 6)
	_say("Stations, spike traps and a Claim Flag (no monster spawns on your land)")
	bm.select(BuildingManager.get_piece_data(&"workbench"))
	await _click_build(Vector3(o.x + 4.5, h, o.y + 1.5), 14)
	bm.select(BuildingManager.get_piece_data(&"spike_trap"))
	for x in range(-1, 4):
		await _click_build(Vector3(o.x + x + 0.5, h, o.y + 7.5), 6)
	bm.select(BuildingManager.get_piece_data(&"claim_flag"))
	await _click_build(Vector3(o.x + 4.5, h, o.y + 4.5), 20)
	await _tap(&"build_mode")
	await _wait(10)
	_say("Inside: roofs above you hide · \"Sheltered\" warms the air")
	await _walk_to(Vector3(o.x + 1.5, 0, o.y + 4.2), 0.4, 200)
	var door: BuildPiece = world.building.pieces.get(BuildingManager.key(o + Vector2i(1, 3), "edge_n", 0))
	if door:
		_aim(door.global_position)
		await _tap(&"interact")
		await _wait(15)
	await _walk_to(Vector3(o.x + 1.5, 0, o.y + 1.5), 0.4, 200)
	await _wait(60)
	# Night & sleep
	_say("Evening: torches light the base")
	await _walk_to(Vector3(o.x + 1.5, 0, o.y + 5.0), 0.5, 200)
	await _yaw_to(world.camera_rig._target_yaw - 30.0, 1)
	for i in 90:
		world.day_night.hour = 17.5 + 4.0 * i / 90.0
		await get_tree().process_frame
	await _wait(40)
	_say("Sleep in your bed (F): skip to morning")
	await _walk_to(Vector3(o.x + 1.2, 0, o.y + 1.8), 0.4, 200)
	var bed: BuildPiece = world.building.pieces.get(BuildingManager.key(o + Vector2i(0, 1), "object", 0))
	if bed:
		_aim(bed.global_position)
		bed.interact(p)  # same call the F key makes on the targeted bed
	await _wait(60)

	# Combat
	await _walk_to(Vector3(o.x + 1.5, 0, o.y + 12.0), 0.6, 300)
	_say("Combat · debug-spawned Thornback Boars (F8)")
	var dir := world.camera_rig.get_forward_flat()
	var boars: Array[Enemy] = []
	for k in 2:
		var pos := p.global_position + dir.rotated(Vector3.UP, (k - 0.5) * 0.8) * 8.0
		pos.y = world.get_ground_height(pos) + 0.3
		boars.append(world.spawner.spawn_enemy(world.debug_enemy_scene, pos, ""))
	await _wait(20)
	await _fight(boars, 900)
	await _wait(40)

	# Part 2: wizard
	_say("")
	await _boot(&"wizard")
	p = world.player
	world.spawner.max_active = 0
	world.spawner.despawn_all()
	world.day_night.hour = 15.0
	world.camera_rig._target_distance = 14.0
	await _card("Wizard", 30)
	p.character.grant_xp(Progression.total_xp_for(6), Progression.Source.OTHER)
	_say("Level up! Skill points to spend (K)")
	await _wait(50)
	await _tap(&"character_screen")
	await _wait(20)
	p.character.spend_point(Skill.MANA_CONTROL)
	await _wait(15)
	p.character.spend_point(Skill.MANA_CONTROL)
	await _wait(40)
	await _tap(&"character_screen")
	_say("T: Magic Temperature Shield (needs Mana Control +2)")
	await _tap(&"ability_shield")
	await _wait(45)
	var open := _open_spot()
	_say("")
	await _walk_to(open, 0.8, 500)
	await _wait(10)
	_say("Frost Nova (X) freezes · Firebolt (Z) shatters frozen foes")
	dir = world.camera_rig.get_forward_flat()
	var wb: Array[Enemy] = []
	for k in 3:
		var pos := p.global_position + dir.rotated(Vector3.UP, (k - 1) * 0.5) * 7.0
		pos.y = world.get_ground_height(pos) + 0.3
		wb.append(world.spawner.spawn_enemy(world.debug_enemy_scene, pos, ""))
	await _wizard_fight(wb, 900)
	world.spawner.despawn_all()
	p.health.invulnerable = true  # the tour below is sightseeing only
	p.health.heal(p.health.max_health)

	# Biome tour
	var g := world.generator
	var origin := p.global_position
	world.camera_rig._target_distance = 22.0
	for pair in [[&"sunscorch_desert", "Sunscorch Desert · hot by day"], [&"snowy_tundra", "Snowy Tundra · frozen lakes"],
			[&"crystal_glade", "Crystal Glade · rare, magical"], [&"stonecrown_mountains", "Stonecrown Mountains"],
			[&"murk_swamp", "Murk Swamp"]]:
		var spot := _find_biome(g, origin, pair[0])
		if spot == Vector3.INF:
			continue
		_say("")
		await _teleport(spot)
		_say("Teleport · %s" % pair[1])
		var yaw := world.camera_rig._target_yaw
		var fw := world.camera_rig.get_forward_flat()
		await _walk_to(p.global_position + fw * 5.0, 0.8, 70)
		await _yaw_to(yaw + 50.0, 30)
	# Cave
	var e := g.get_cave_entrances_near(floori(origin.x) - 600, floori(origin.z) - 600, floori(origin.x) + 600, floori(origin.z) + 600)
	if not e.is_empty():
		var epos := Vector3(e[0].x + 0.5, g.get_height_blocks(e[0].x, e[0].y) * 0.5, e[0].y + 0.5)
		_say("")
		await _teleport(epos + Vector3(4, 0.5, 3))
		world.camera_rig._target_distance = 13.0
		_say("A cave entrance · F to descend into The Deeps")
		await _walk_to(epos, 1.6, 200)
		await _wait(15)
		_cut_begin()
		world.travel_to_layer(TerrainGenerator.Layer.UNDERGROUND, epos)
		await _wait(3)
		while not world.is_ready:
			await get_tree().process_frame
		await _wait(20)
		_cut_end()
		_say("The Deeps · ores, crystals, glowcaps, Forgotten Caches")
		var fw := world.camera_rig.get_forward_flat()
		await _walk_to(p.global_position + fw * 7.0, 0.8, 120)
		await _yaw_to(world.camera_rig._target_yaw + 60.0, 45)
		_say("M: world map")
		await _tap(&"world_map")
		await _wait(70)
		await _tap(&"world_map")
	_say("")
	await _card("SHARDLANDS · v0.4.0\n\nbuilding & crafting milestone", 60)


## A nearby flat spot with no trees/rocks within 8 m (clear view for a fight).
func _open_spot() -> Vector3:
	var p := world.player
	var blockers: Array[Vector3] = []
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is PropBody and n.data.blocks_movement:
			blockers.append((n as Node3D).global_position)
	for r in range(0, 40, 3):
		for k in 16:
			var q := p.global_position + Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0)) * r
			var g0 := world.get_ground_height(q)
			var ok := not world.is_in_water(q)
			for b in blockers:
				if ok and Vector2(b.x - q.x, b.z - q.z).length() < 8.0:
					ok = false
			for d in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5), Vector3(0, 0, -8)]:
				if ok and (absf(world.get_ground_height(q + d) - g0) > 1.1 or world.is_in_water(q + d)):
					ok = false
			if ok:
				return q
	return p.global_position


func _hut_origin() -> Vector2i:
	var pc := Vector2i(floori(world.player.global_position.x), floori(world.player.global_position.z))
	var floor := BuildingManager.get_piece_data(&"wood_floor")
	var bench := BuildingManager.get_piece_data(&"workbench")
	for d in range(2, 12):
		for dx in range(-d, d + 1):
			for dz in range(-d, d + 1):
				if maxi(absi(dx), absi(dz)) != d:
					continue
				var o := pc + Vector2i(dx, dz)
				var ok := true
				var h0 := world.get_ground_height(Vector3(o.x + 0.5, 0, o.y + 0.5))
				for x in range(-1, 6):
					for z in range(0, 9):
						var c := o + Vector2i(x, z)
						var q := Vector3(c.x + 0.5, 0, c.y + 0.5)
						if absf(world.get_ground_height(q) - h0) > 0.01 \
								or world.building.check_place(bench if x == 4 else floor, c, "object" if x == 4 else "floor", null) != "":
							ok = false
							break
					if not ok:
						break
				if ok:
					return o
	return pc + Vector2i(3, -4)


func _click_build(point: Vector3, after: int) -> void:
	_aim(point)
	await _wait(3)
	await _tap(&"attack_light", 2)
	await _wait(after)


func _alive(list: Array[Enemy]) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for b in list:
		if is_instance_valid(b) and not b.is_dead and b.visible:
			out.append(b)
	return out


func _fight(boars: Array[Enemy], max_frames: int) -> void:
	var p := world.player
	var lock_done := false
	var t := 0
	while t < max_frames:
		var alive := _alive(boars)
		if alive.is_empty():
			_say("Victory · loot flies to you · combat XP")
			break
		if p.health.current < p.health.max_health * 0.45:
			p.health.heal(p.health.max_health)  # keep the demo going
		var target: Enemy = alive[0]
		if not lock_done or p.lock_target == null or not is_instance_valid(p.lock_target) or p.lock_target.is_dead:
			p.set_lock_target(target)
			lock_done = true
		if p.lock_target is Enemy:
			target = p.lock_target as Enemy
		_aim(target.global_position)
		var boar := target as ThornbackBoar
		var d := p.global_position.distance_to(target.global_position)
		if boar and boar.ai == ThornbackBoar.AI.CHARGE and d < 5.0:
			_say("Dodge roll through the charge (Space)")
			Input.action_press(&"move_right")
			await _tap(&"dodge")
			Input.action_release(&"move_right")
			await _wait(12)
			t += 16
			continue
		if d > 2.2:
			var tp := target.global_position
			var fwd := world.camera_rig.get_forward_flat()
			var right := world.camera_rig.get_right_flat()
			var dir := (tp - p.global_position)
			dir.y = 0
			dir = dir.normalized()
			_release_moves()
			if dir.dot(fwd) > 0.38:
				Input.action_press(&"move_forward")
			elif dir.dot(fwd) < -0.38:
				Input.action_press(&"move_back")
			if dir.dot(right) > 0.38:
				Input.action_press(&"move_right")
			elif dir.dot(right) < -0.38:
				Input.action_press(&"move_left")
			await get_tree().process_frame
			t += 1
			continue
		_release_moves()
		if randi() % 5 == 0:
			_say("Heavy attack (right mouse)")
			await _tap(&"attack_heavy")
			await _wait(22)
			t += 26
		else:
			_say("Light combo (left mouse) · Tab lock-on")
			await _tap(&"attack_light")
			await _wait(9)
			t += 13
	_release_moves()


func _wizard_fight(boars: Array[Enemy], max_frames: int) -> void:
	var p := world.player
	var t := 0
	var nova_done := false
	await _wait(10)
	while t < max_frames:
		var alive := _alive(boars)
		if alive.is_empty():
			_say("All three boars down")
			await _wait(40)
			break
		if p.health.current < p.health.max_health * 0.45:
			p.health.heal(p.health.max_health)
		p.mana.refill()
		var target: Enemy = alive[0]
		var nearest := 1e9
		for b in alive:
			nearest = minf(nearest, b.global_position.distance_to(p.global_position))
		if not nova_done and nearest < 3.2:
			await _tap(&"ability_2")
			nova_done = true
			await _wait(12)
			t += 16
			continue
		p.set_lock_target(target)
		_aim(target.global_position)
		if nova_done or nearest > 5.5:
			await _tap(&"ability_1")
			await _wait(20)
			t += 24
			if p.abilities.cooldown_left(p.abilities.get_slot(1)) < 0.05 and nearest < 3.0:
				nova_done = false
		else:
			await _wait(4)
			t += 4


func _find_biome(g: TerrainGenerator, origin: Vector3, id: StringName) -> Vector3:
	for r in range(40, 6000, 40):
		var steps := maxi(8, r / 20)
		for k in steps:
			var a := TAU * k / steps
			var q := origin + Vector3(cos(a), 0, sin(a)) * r
			if g.get_biome_at(q).id != id:
				continue
			var ok := true
			for d: Vector3 in [Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(0, 0, 12), Vector3(0, 0, -12)]:
				if g.get_biome_at(q + d).id != id:
					ok = false
			if ok and g.get_height_at(q) > 0.0:
				return q
	return Vector3.INF
