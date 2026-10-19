extends Node
## Records a ~2 minute gameplay trailer with Godot's Movie Maker (fixed 30 fps, so a slow
## computer still gives a smooth video):
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
##       --write-movie build/trailer/raw.avi --fixed-fps 30 res://tests/trailer_runner.tscn
##   tools/make_trailer.sh            (cuts the clips, adds fades and music -> build/trailer/)
##
## Loading and set-up frames are recorded too; every usable shot is printed as
## "TRAILER_CLIP <name> <first frame> <last frame>" and the editing script keeps only those.

const FPS := 30.0

var world: World
var cam: Camera3D
var _frame := 0
var _clip := ""
var _clip_at := 0
var _layer: CanvasLayer
var _cap: Label
var _sub: Label
var _cap_tw: Tween
var _meadow := Vector3.INF


func _process(_delta: float) -> void:
	_frame += 1


func _ready() -> void:
	Settings.values["tutorial_hints"] = false
	Settings.values["damage_numbers"] = true
	CrashHandler.crashed_last_time = false
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, true)  # the editing script adds the music
	_make_overlay()
	await _wait(2)
	await _title(&"title", "", 7.0)
	await _knight_world()
	await _class_fight(&"barbarian", "The Barbarian", "Rage, whirlwinds and earthquakes",
		[&"whirlwind", &"thunder_clap", &"earthquake", &"leap_slam"])
	await _wizard_world()
	await _class_fight(&"assassin", "The Assassin", "Poison, shadows and a hundred knives",
		[&"fan_of_knives", &"shadow_step", &"blade_dance", &"rain_of_arrows"])
	await _title(&"end", "Play now on Windows", 8.0)
	print("TRAILER_DONE ", _frame)
	get_tree().quit()


# --- Shots ----------------------------------------------------------------------------------

## The title screen (moving pixel landscape and our logo), with a line under it.
func _title(id: StringName, line: String, seconds: float) -> void:
	var m := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	add_child(m)
	_hide_menu_buttons(m)
	await _wait(20)
	_in(String(id))
	if line != "":
		_caption(line, "Shardlands  ·  v%s" % ProjectSettings.get_setting("application/config/version"), seconds - 1.0)
	await _hold(seconds)
	_out()
	m.queue_free()
	await _wait(3)


func _hide_menu_buttons(n: Node) -> void:
	for c in n.get_children():
		if c is Button or c is Label and (c as Label).text.begins_with("v"):
			(c as Control).visible = false
		_hide_menu_buttons(c)


func _knight_world() -> void:
	world = await _boot(&"knight")
	var p := world.player
	# --- Walking out into the meadow (game camera).
	var start := _dry_center(world, p.global_position, 30.0)
	_meadow = start
	await _teleport(start)
	world.camera_rig._target_distance = 16.0
	world.camera_rig._target_pitch = 48.0
	await _wait(30)
	_in("explore")
	_caption("A world made of blocks", "Explore it your way", 5.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _hold(3.0)
	Input.action_press(&"move_right")
	await _hold(2.5)
	Input.action_release(&"move_right")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_out()
	# --- Biomes (slow orbits).
	var g := world.generator
	var origin := p.global_position
	var first := true
	for id: StringName in [&"sunscorch_desert", &"snowy_tundra", &"emerald_jungle", &"crystal_glade"]:
		var spot := _find_biome(g, origin, id)
		if spot == Vector3.INF:
			continue
		await _teleport(spot)
		_clear_monsters()
		var c := spot
		c.y = world.get_ground_height(c) + 1.0
		_use_cam(true)
		_orbit_step(c, 22.0, 11.0, 0.0)
		await _wait(10)
		_in("biome_" + String(id))
		if first:
			_caption("Deserts, snow, jungles and crystal glades", "", 3.2)
			first = false
		await _orbit(c, 22.0, 11.0, 0.2, 0.75, 3.4)
		_out()
		_use_cam(false)
	# --- A village by day and by night.
	var sets := world.generator.settlements.near(p.global_position, 4000.0)
	var village: SettlementInfo = null
	for s in sets:
		if not s.is_kingdom():
			village = s
			break
	if village:
		await _teleport(village.world_center() + Vector3(0.5, 0, -1.5))
		world.living.update_now(true)
		world.living.finish_sites()
		_clear_monsters()
		await _wait(40)
		var vc := village.world_center()
		vc.y = world.get_ground_height(vc) + 1.0
		_use_cam(true)
		_orbit_step(vc, 30.0, 18.0, 0.4)
		await _wait(5)
		_in("village")
		_caption("Living towns", "Trade, quests and townsfolk with their own day", 4.5)
		await _orbit(vc, 30.0, 18.0, 0.4, 1.0, 5.5)
		_out()
		world.day_night.hour = 21.5
		world.day_night.advance_hours(0.0)
		var site := world.living.site_of(village)
		if site:
			for n in site.npcs:
				n._update_activity(true)
		await _wait(30)
		_orbit_step(vc, 26.0, 14.0, 1.6)
		await _wait(5)
		_in("village_night")
		await _orbit(vc, 26.0, 14.0, 1.6, 2.0, 3.5)
		_out()
		world.day_night.hour = 10.5
		world.day_night.advance_hours(0.0)
		_use_cam(false)
	# --- The Knight fights.
	await _fight_here("The Knight", "Shield, sword and holy light", [&"shield_bash", &"consecrate", &"judgement", &"pillar_of_light"])
	# --- Riding a horse.
	await _ride()
	# --- A thunderstorm.
	var sc := _dry_center(world, p.global_position, 20.0)
	await _teleport(sc)
	world.weather.force(WeatherSystem.Kind.STORM, 1.0)
	world.weather.settle()
	world.day_night.hour = 17.5
	world.day_night.advance_hours(0.0)
	await _wait(60)
	var cc := p.global_position + Vector3(0, 1.0, 0)
	_use_cam(true)
	_orbit_step(cc, 16.0, 8.0, 2.2)
	await _wait(5)
	_in("storm")
	_caption("Weather and seasons that matter", "", 3.5)
	await _orbit(cc, 16.0, 8.0, 2.2, 2.6, 4.0)
	_out()
	_use_cam(false)
	world.weather.force(WeatherSystem.Kind.CLEAR, 1.0)
	world.weather.settle()
	await _end_world()


func _wizard_world() -> void:
	world = await _boot(&"wizard")
	await _fight_here("The Wizard", "Fire, frost, lightning and the stars",
		[&"firebolt", &"flame_pillar", &"chain_lightning", &"comet_shower", &"arcane_explosion"])
	# --- A dungeon with the dungeon camera, then its boss.
	var p := world.player
	var poi := PoiInfo.new()
	poi.kind = PoiInfo.Kind.DUNGEON
	poi.rank = 2
	poi.theme = PoiInfo.DungeonTheme.CRYPT
	poi.id = "trailer_dungeon"
	poi.seed = 11
	poi.center = Vector2i(int(p.global_position.x), int(p.global_position.z))
	if world.enter_dungeon(poi):
		await _wait(60)
		var d := world.dungeon
		for m in d.monsters:
			if is_instance_valid(m) and m != d.boss:
				m.queue_free()
		world.hud.visible = false
		await _wait(60)
		var aim := p.get_aim_direction()
		var foes: Array[Monster] = []
		for i in 5:
			var off := aim.rotated(Vector3.UP, (i - 2) * 0.45) * (4.5 + (i % 2) * 1.5)
			var m := _monster(&"skeleton_minion" if i % 2 == 0 else &"skeleton_warrior", p.global_position + off)
			if m:
				m.health.max_health = 70.0
				m.health.current = 70.0
				foes.append(m)
		await _wait(10)
		_calm(foes)
		await _wait(10)
		_in("dungeon")
		_caption("Dungeons", "Traps, puzzles, treasure", 4.0)
		await _cast_at(&"frost_nova", foes)
		await _hold(0.6)
		await _cast_at(&"arcane_explosion", foes)
		await _hold(0.8)
		await _combo(4, foes)
		await _cast_at(&"flame_pillar", foes)
		await _hold(0.8)
		await _cast_at(&"comet_shower", foes)
		await _hold(1.6)
		_out()
		# The boss.
		if is_instance_valid(d.boss):
			var br := d.to_global(d.plan.room_center(d.plan.end_room))
			var bp := d.boss.global_position
			var side := (br - bp)
			side.y = 0.0
			if side.length() < 0.5:
				side = Vector3(0, 0, 1)
			p.global_position = bp + side.normalized() * 6.0 + Vector3(0, 0.3, 0)
			p.velocity = Vector3.ZERO
			world.camera_rig.snap_to_target()
			p.face_direction((bp - p.global_position).normalized(), true)
			# The boss really fights back: the hero takes the hits (lots of health, no "Dodged" tags).
			p.health.invulnerable = false
			p.health.max_health = 1.0e6
			p.health.current = 1.0e6
			await _wait(90)
			_in("boss")
			_caption("And bosses", "", 3.0)
			var bf: Array[Monster] = [d.boss]
			for k in 3:
				await _cast_at(&"firebolt", bf)
				await _hold(0.5)
			await _cast_at(&"flame_pillar", bf)
			await _hold(0.7)
			await _cast_at(&"chain_lightning", bf)
			await _hold(1.2)
			_out()
		world.exit_dungeon()
		await _wait(10)
	await _end_world()


## One class: boot its world, then the same fight scene.
func _class_fight(cid: StringName, title: String, line: String, spells: Array) -> void:
	world = await _boot(cid)
	await _fight_here(title, line, spells)
	await _end_world()


## A fight in a clearing: a pack of monsters, a few combos and the class's spells.
func _fight_here(title: String, line: String, spells: Array) -> void:
	var p := world.player
	# An open meadow (the knight comes back to where the walk started, away from towns).
	var spot := _meadow if _meadow != Vector3.INF else _dry_center(world, p.global_position, 26.0)
	_meadow = Vector3.INF
	await _teleport(spot)
	_clear_monsters()
	world.camera_rig._target_distance = 15.0
	world.camera_rig._target_pitch = 50.0
	var aim := p.get_aim_direction()
	var foes: Array[Monster] = []
	var ids: Array[StringName] = [&"skeleton_warrior", &"bandit_thug", &"skeleton_minion", &"bandit_recruit", &"skeleton_minion", &"bandit_brute"]
	for i in ids.size():
		var off := aim.rotated(Vector3.UP, (i - 2.5) * 0.4) * (3.2 + (i % 3) * 1.6)
		var m := _monster(ids[i], p.global_position + off)
		if m:
			m.health.max_health = 90.0
			m.health.current = 90.0
			foes.append(m)
	await _wait(10)
	_calm(foes)
	await _wait(20)
	_in("fight_" + title.to_lower().replace(" ", "_"))
	_caption(title, line, 3.5)
	await _combo(4, foes)
	for s in spells:
		await _cast_at(StringName(s), foes)
		await _hold(0.85)
		await _combo(2, foes)
	await _hold(0.6)
	_out()
	_clear_monsters()


func _ride() -> void:
	var p := world.player
	var tm := world.travel
	var herds := tm.herds_near(p.global_position, 3000.0)
	if herds.is_empty():
		return
	await _teleport(herds[0][1] + Vector3(6, 0, 6))
	_clear_monsters()
	tm.update_now()
	await _wait(30)
	var horse: Horse = null
	for h in get_tree().get_nodes_in_group(&"horses"):
		horse = h
	if horse == null:
		return
	horse.make_tame()
	p.inventory.add_item(&"leather_saddle", 1)
	horse.put_saddle(p, &"leather_saddle")
	horse.global_position = p.global_position
	await _wait(5)
	horse.mount(p)
	world.camera_rig._target_distance = 18.0
	await _wait(30)
	_in("ride")
	_caption("Ride, sail and travel", "Horses, boats and waystones", 3.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _hold(2.5)
	Input.action_press(&"move_left")
	await _hold(1.8)
	Input.action_release(&"move_left")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_out()
	p.stop_riding(false, true)


# --- Fighting helpers -----------------------------------------------------------------------

func _alive(foes: Array[Monster]) -> Monster:
	var p := world.player
	var best: Monster = null
	var bd := INF
	for m in foes:
		if is_instance_valid(m) and m.visible and not m.is_dead:
			var dd := m.global_position.distance_to(p.global_position)
			if dd < bd:
				bd = dd
				best = m
	return best


## Foes stand dazed (they would only swing at the hero, who can't be hurt here).
func _calm(foes: Array[Monster]) -> void:
	for m in foes:
		if is_instance_valid(m):
			m.stagger(40.0)


func _aim_at(t: Node3D) -> void:
	var p := world.player
	if t == null:
		return
	p.set_lock_target(t)
	var dir := t.global_position - p.global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		p.face_direction(dir.normalized(), true)
	var c := get_viewport().get_camera_3d()
	if c:
		get_viewport().warp_mouse(c.unproject_position(t.global_position))


## Light attacks at the nearest foe; walks up to it first if it is far.
func _combo(n: int, foes: Array[Monster]) -> void:
	var p := world.player
	for i in n:
		var t := _alive(foes)
		if t and t.global_position.distance_to(p.global_position) > 2.4:
			# Close in quickly (a short dash toward it).
			var dir := (t.global_position - p.global_position)
			dir.y = 0.0
			var tw := create_tween()
			tw.tween_property(p, "global_position", p.global_position + dir.normalized() * (dir.length() - 1.8), 0.25)
			await _hold(0.27)
		_aim_at(t)
		p.state = Player.State.NORMAL
		p.combat.request(&"light")
		await _hold(0.34)


func _cast_at(id: StringName, foes: Array[Monster]) -> void:
	var p := world.player
	var a := AbilityBook.get_ability(id)
	if a == null:
		print("trailer: no ability ", id)
		return
	_aim_at(_alive(foes))
	p.combat.cancel()
	p.state = Player.State.NORMAL
	p.abilities.bar[0] = id
	p.abilities.cooldowns.clear()
	p.mana.refill()
	p.stamina.refill()
	p.abilities.set_rage(100.0)
	if not p.abilities.try_use(0):
		print("trailer: could not cast ", id)


# --- World helpers --------------------------------------------------------------------------

func _boot(cid: StringName) -> World:
	SaveManager.start_transient(GameState.DEFAULT_SEED, cid)
	var w := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(w)
	while not w.is_ready:
		await get_tree().process_frame
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, true)  # the editing script adds the music
	var p := w.player
	p.health.invulnerable = true
	p.character.grant_xp(Progression.total_xp_for(60), Progression.Source.OTHER)
	w.spawner.max_active = 0
	w.hud.visible = false
	w.day_night.day_length = 1.0e9
	w.day_night.hour = 10.5
	w.day_night.advance_hours(0.0)
	w.weather.force(WeatherSystem.Kind.CLEAR, 1.0)
	w.weather.settle()
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 640.0
	w.add_child(cam)
	await _wait(10)
	return w


func _end_world() -> void:
	_use_cam(false)
	world.queue_free()
	world = null
	await _wait(5)


func _use_cam(on: bool) -> void:
	world.camera_rig.set_process(not on)
	if on:
		cam.current = true
		Materials.set_camera_fade(0.0)
	else:
		world.camera_rig.camera.current = true
		world.camera_rig.snap_to_target()


func _orbit_step(c: Vector3, radius: float, height: float, a: float) -> void:
	cam.global_position = c + Vector3(cos(a) * radius, height, sin(a) * radius)
	cam.look_at(c)


func _orbit(c: Vector3, radius: float, height: float, a0: float, a1: float, seconds: float) -> void:
	var n := int(seconds * FPS)
	for i in n:
		var k := float(i) / float(maxi(n - 1, 1))
		k = k * k * (3.0 - 2.0 * k) * 0.6 + k * 0.4
		_orbit_step(c, radius, height, lerpf(a0, a1, k))
		await get_tree().process_frame


func _monster(id: StringName, pos: Vector3) -> Monster:
	pos.y = world.get_ground_height(pos) + 0.3
	var data := load("res://data/enemies/%s.tres" % id) as MonsterData
	if data == null:
		return null
	return world.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", data) as Monster


func _clear_monsters() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Enemy and e.visible:
			NodePool.release_or_free(e)


func _teleport(pos: Vector3) -> void:
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
	await _wait(30)


func _find_biome(g: TerrainGenerator, origin: Vector3, id: StringName) -> Vector3:
	for r in range(40, 6000, 40):
		var steps := maxi(8, r / 20)
		for k in steps:
			var a := TAU * k / steps
			var q := origin + Vector3(cos(a), 0, sin(a)) * r
			if g.get_biome_at(q).id != id:
				continue
			var ok := true
			for d: Vector3 in [Vector3(16, 0, 0), Vector3(-16, 0, 0), Vector3(0, 0, 16), Vector3(0, 0, -16)]:
				if g.get_biome_at(q + d).id != id:
					ok = false
			if ok and g.get_height_at(q) > 0.0:
				return q
	return Vector3.INF


func _dry_center(w: World, origin: Vector3, size: float) -> Vector3:
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
					var h := w.get_ground_height(c + Vector3(x, 0, z))
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


# --- Clips, captions, timing ---------------------------------------------------------------------

func _in(clip_name: String) -> void:
	_clip = clip_name
	_clip_at = _frame


func _out() -> void:
	if _clip != "":
		print("TRAILER_CLIP %s %d %d" % [_clip, _clip_at, _frame])
	_clip = ""
	_caption_off()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	await _wait(int(round(seconds * FPS)))


func _make_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	var font: Font = load("res://assets/fonts/DejaVuSans.ttf")
	_cap = Label.new()
	_sub = Label.new()
	for l: Label in [_cap, _sub]:
		l.add_theme_font_override(&"font", font)
		l.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
		l.add_theme_color_override(&"font_outline_color", Color(0.05, 0.04, 0.06))
		l.modulate.a = 0.0
		_layer.add_child(l)
	_cap.add_theme_font_size_override(&"font_size", 52)
	_cap.add_theme_constant_override(&"outline_size", 14)
	_sub.add_theme_font_size_override(&"font_size", 26)
	_sub.add_theme_constant_override(&"outline_size", 9)
	_sub.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.5))
	_cap.position = Vector2(64, 520)
	_sub.position = Vector2(68, 590)


func _caption(text: String, sub: String, seconds: float) -> void:
	_cap.text = text
	_sub.text = sub
	if _cap_tw and _cap_tw.is_valid():
		_cap_tw.kill()
	_cap_tw = create_tween()
	_cap_tw.set_parallel(true)
	for l: Label in [_cap, _sub]:
		l.modulate.a = 0.0
		_cap_tw.tween_property(l, "modulate:a", 1.0, 0.35)
	_cap.position.x = 40.0
	_cap_tw.tween_property(_cap, "position:x", 64.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_cap_tw.chain().tween_interval(maxf(seconds - 0.7, 0.2))
	_cap_tw.chain().tween_property(_cap, "modulate:a", 0.0, 0.35)
	_cap_tw.parallel().tween_property(_sub, "modulate:a", 0.0, 0.35)


func _caption_off() -> void:
	if _cap_tw and _cap_tw.is_valid():
		_cap_tw.kill()
	_cap.modulate.a = 0.0
	_sub.modulate.a = 0.0
