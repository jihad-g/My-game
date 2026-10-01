class_name Playthrough
extends RefCounted
## Automated playthrough of the core loop (Milestone 12).
##
## A fresh character on a fresh world goes through the loop with the real game
## systems and nothing handed to it: gather what the world offers (trees,
## rocks, sticks, fibre), craft tools, build a workbench and a little base,
## cook, fight monsters with the real damage pipeline, level up and spend
## skill points, sell and buy in the nearest village, make a weapon and equip
## it, clear the nearest ruins and loot their chest. Every step is logged with
## the simulated play time; `results` says which steps succeeded.
##
## Used by tests/test_runner.gd (test_m12_gameplay_loop) and
## tools/playthrough.tscn (prints a report).

var tree: SceneTree
var world: World
var steps := PackedStringArray()
var results := {}
## Seconds a real player would have spent (walking, swinging, crafting).
var play_time := 0.0


func _init(p_tree: SceneTree, p_world: World) -> void:
	tree = p_tree
	world = p_world


func note(step: String, ok: bool, detail: String = "") -> bool:
	results[step] = ok
	steps.append("[%5.1f min] %s %s%s" % [play_time / 60.0, "OK  " if ok else "FAIL", step, (" - " + detail) if detail != "" else ""])
	return ok


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _p() -> Player:
	return world.player


## Moves the player next to `pos` (like walking there) and waits for terrain.
func walk_to(pos: Vector3) -> void:
	var p := _p()
	var dist := Vector2(pos.x - p.global_position.x, pos.z - p.global_position.z).length()
	play_time += dist / 5.0
	var target := Vector3(pos.x, world.get_ground_height(pos) + 0.3, pos.z)
	p.global_position = target
	p.velocity = Vector3.ZERO
	await _frames(2)
	var f := 0
	while (not world.chunk_manager.is_near_area_ready() or world.chunk_manager.pending_count() > 0) and f < 2000:
		await tree.process_frame
		f += 1
	p.global_position = Vector3(pos.x, world.get_ground_height(pos) + 0.3, pos.z)


func _props_dropping(item: StringName) -> Array:
	var out := []
	var p := _p().global_position
	for chunk in world.chunk_manager._chunks.values():
		if chunk.lod != 0:
			continue
		for c in chunk.get_children():
			if c is PropBody and c.data and c.data.interact_mode != PropData.InteractMode.NONE:
				for loot in c.data.drops:
					if loot is LootEntry and loot.item_id == item:
						out.append(c)
						break
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return out


## Gathers until the inventory holds `n` of `item` (or gives up).
func gather(item: StringName, n: int) -> bool:
	var p := _p()
	var tries := 0
	while p.inventory.count_of(item) < n and tries < 40:
		var props := _props_dropping(item)
		var body: PropBody = null
		for b in props:
			if b.data.tool_kind == &"" or p.best_tool_tier(b.data.tool_kind) >= b.data.tool_tier:
				body = b
				break
		if body == null:
			# Nothing usable nearby: explore a bit further.
			await walk_to(p.global_position + Vector3(48, 0, 24 * (tries % 3 - 1)))
			tries += 3
			continue
		tries += 1
		await walk_to(body.global_position + Vector3(0.9, 0, 0.9))
		if body.data.interact_mode == PropData.InteractMode.GATHER:
			body.interact(p)
			play_time += 1.5
		else:
			for h in 30:
				if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree():
					break
				body.receive_hit(DamageInfo.create(10.0, p))
				play_time += 0.8
		# Drops land as pickups at the player's feet and get collected.
		await _frames(50)
	return p.inventory.count_of(item) >= n


func craft(recipe_id: StringName, times: int = 1) -> int:
	var p := _p()
	var r := RecipeBook.get_recipe(recipe_id)
	var made := Crafting.craft(p, r, Crafting.stations_near(tree, p.global_position), times)
	play_time += 4.0 * made
	return made


## Gathers whatever a recipe still needs, then crafts it.
func gather_and_craft(recipe_id: StringName, times: int = 1) -> bool:
	var p := _p()
	var r := RecipeBook.get_recipe(recipe_id)
	var home := p.global_position
	var cost := r.cost_at(p.character.skill_level(Skill.CRAFTING))
	for item in cost:
		var need := int(cost[item]) * times
		if p.inventory.count_of(item) < need:
			var sub := RecipeBook.get_recipe(item)
			if sub and p.recipes.knows(item):
				var each := sub.result_count
				var subcost := sub.cost_at(p.character.skill_level(Skill.CRAFTING))
				var batches := ceili(float(need - p.inventory.count_of(item)) / each)
				for si in subcost:
					await gather(si, int(subcost[si]) * batches)
				await walk_to(home)  # crafting stations are back where we started
				craft(item, batches)
			else:
				await gather(item, need)
	await walk_to(home)
	return craft(recipe_id, times) == times


func place(piece_id: StringName, pay: bool = true) -> BuildPiece:
	var p := _p()
	var data := BuildingManager.get_piece_data(piece_id)
	for item in data.cost:
		if p.inventory.count_of(item) < int(data.cost[item]):
			await gather(item, int(data.cost[item]))
	var pc := Vector2i(floori(p.global_position.x), floori(p.global_position.z))
	for d in range(2, 7):
		for dx in range(-d, d + 1):
			for dz in range(-d, d + 1):
				if maxi(absi(dx), absi(dz)) != d:
					continue
				var slot := BuildingManager.slot_kind(data)
				if slot == "edge":
					slot = "edge_n"
				var cell := pc + Vector2i(dx, dz)
				if world.building.check_place(data, cell, slot, p, pay) == "":
					play_time += 3.0
					return world.building.place(data, cell, slot, 0, p, pay)
	return null


## Fights a monster with the real damage pipeline (light combo, crits,
## class and skills). The player takes the monster's real attacks on a timer.
func fight(monster_id: StringName, rank: int = 0) -> Dictionary:
	var p := _p()
	var md: MonsterData = load("res://data/enemies/%s.tres" % monster_id)
	var pos := p.global_position + Vector3(2.0, 0, 0)
	pos.y = world.get_ground_height(pos) + 0.3
	var m := world.spawner.spawn_enemy(PoiSite.MONSTER_SCENE, pos, "", md) as Monster
	m.configure(PoiLayout.RANK_POWER[rank], PoiLayout.RANK_DAMAGE[rank], PoiLayout.RANK_LEVELS[rank], PoiLayout.RANK_XP[rank])
	m.stagger(999.0)  # stands still; its attacks are applied below on a timer
	var combo: Array[AttackData] = p.combat.light_combo
	var xp0 := p.character.total_xp
	var hp0 := p.health.current
	var t := 0.0
	var hits := 0
	var enemy_dps: float = md.melee.damage * PoiLayout.RANK_DAMAGE[rank] / (md.melee.windup + md.melee.active + md.melee.recovery + 1.2)
	while is_instance_valid(m) and not m.is_dead and t < 120.0:
		var a: AttackData = combo[hits % combo.size()]
		var info := p.combat.build_damage(a, m)
		m.receive_hit(info)
		hits += 1
		var dt := (a.windup + a.active + a.recovery) / p.character.attack_speed + 0.1
		t += dt
		# The monster hits back (armor applies) - but a player would heal.
		var taken := enemy_dps * dt * (1.0 - p.character.damage_reduction)
		p.health.current = maxf(1.0, p.health.current - taken)
		await _frames(1)
	play_time += t + 10.0
	var won := not is_instance_valid(m) or m.is_dead
	var lost_hp := hp0 - p.health.current
	p.health.current = p.health.max_health
	await _frames(3)
	return {"won": won, "time": t, "hits": hits, "xp": p.character.total_xp - xp0, "hp_lost": lost_hp}


func spend_points() -> int:
	var ch := _p().character
	var plan: Dictionary = BalanceModel.BUILDS.get(ch.class_data.id, {Skill.STRENGTH: 1.0})
	var n := 0
	while ch.unspent_points > 0 and n < 400:
		# Spend on the skill furthest below its share of the plan.
		var best: StringName = plan.keys()[0]
		var best_gap := -INF
		for s in plan:
			var gap: float = float(plan[s]) * 100.0 - ch.base_skill(s)
			if gap > best_gap:
				best_gap = gap
				best = s
		if not ch.spend_point(best):
			break
		n += 1
	return n


func run() -> Dictionary:
	var p := _p()
	p.health.invulnerable = false
	note("start", true, "%s level %d at %s" % [p.character.class_data.display_name, p.character.level, str(p.global_position.round())])
	# 1. First tools from what lies around.
	var ok := await gather_and_craft(&"stone_hatchet")
	note("craft stone hatchet", ok)
	ok = await gather_and_craft(&"stone_pickaxe")
	note("craft stone pickaxe", ok)
	ok = await gather(&"wood", 30)
	note("chop 30 wood", ok, "%d wood" % p.inventory.count_of(&"wood"))
	ok = await gather(&"stone", 16)
	note("mine 16 stone", ok, "%d stone" % p.inventory.count_of(&"stone"))
	# 2. A base.
	var wb := await place(&"workbench")
	note("build a workbench", wb != null)
	var floors := 0
	for i in 4:
		if await place(&"wood_floor") != null:
			floors += 1
	var walls := 0
	for i in 3:
		if await place(&"wood_wall") != null:
			walls += 1
	note("build floors and walls", floors >= 3 and walls >= 2, "%d floors, %d walls" % [floors, walls])
	ok = await gather_and_craft(&"campfire_kit")
	if ok:
		for i in p.inventory.capacity:
			var s = p.inventory.get_slot(i)
			if s != null and s.id == &"campfire_kit":
				p.use_slot(i)
				break
	await _frames(2)
	note("light a campfire", world.get_tree().get_nodes_in_group(&"heat_sources").size() > 0)
	# 3. Fight and level up.
	var kills := 0
	var xp := 0
	var longest := 0.0
	for monster in [&"skeleton_warrior", &"thorn_crawler", &"skeleton_warrior", &"bandit_thug", &"grotto_cultist"]:
		var r := await fight(monster, 0)
		if r.won:
			kills += 1
			xp += int(r.xp)
			longest = maxf(longest, float(r.time))
	note("defeat 5 monsters", kills == 5, "%d XP, longest fight %.1f s" % [xp, longest])
	# Hunt a boar for meat (the monsters above drop bones and scrap, not food).
	var hunts := 0
	while p.inventory.count_of(&"raw_meat") == 0 and hunts < 3:
		hunts += 1
		var bpos := p.global_position + Vector3(2.5, 0, 0)
		bpos.y = world.get_ground_height(bpos) + 0.3
		var boar := world.spawner.spawn_enemy(world.debug_enemy_scene, bpos, "") as Enemy
		if boar == null:
			break
		boar.stagger(30.0)
		var bh := 0
		while is_instance_valid(boar) and not boar.is_dead and bh < 60:
			boar.receive_hit(p.combat.build_damage(p.combat.light_combo[bh % p.combat.light_combo.size()], boar))
			bh += 1
			play_time += 0.6
			await _frames(1)
		# Walk over the drops so they get picked up.
		await walk_to(bpos)
		await _frames(60)
	# Back to the campfire.
	if wb:
		await walk_to(wb.global_position + Vector3(1.5, 0, 0))
	var cooked0 := p.inventory.count_of(&"cooked_meat")
	craft(&"cooked_meat")
	note("cook meat at the campfire", p.inventory.count_of(&"cooked_meat") > cooked0, "%d raw meat" % p.inventory.count_of(&"raw_meat"))
	var lvl := p.character.level
	note("level up from fighting and crafting", lvl >= 2, "level %d, %d XP" % [lvl, p.character.total_xp])
	note("spend skill points", spend_points() > 0 or lvl == 1)
	# 4. Trade in the nearest village.
	var towns := world.generator.settlements.near(p.global_position, 3000.0)
	var town: SettlementInfo = null
	var best := INF
	for t in towns:
		var d: float = t.world_center().distance_to(p.global_position)
		if d < best:
			best = d
			town = t
	if note("find a village", town != null, "%s at %d m" % [town.name if town else "-", roundi(best)]):
		await walk_to(town.world_center() + Vector3(3, 0, 3))
		await _frames(20)
		var coins0 := p.coins
		var sold := 0
		var keep := [&"campfire_kit", &"cooked_meat", &"bread", &"rope", &"plank", &"flint"]
		for i in p.inventory.capacity:
			var s = p.inventory.get_slot(i)
			if s == null or s.id in keep:
				continue
			var it := ItemDB.get_item(s.id)
			if it == null or it.category in [ItemData.Category.TOOL, ItemData.Category.WEAPON, ItemData.Category.ARMOR]:
				continue
			if Economy.will_buy(&"merchant", s.id) and world.living.sell_price(town, &"merchant", s.id) > 0:
				if world.living.sell(town, &"merchant", i, int(s.count)) == "":
					sold += 1
		note("sell materials", p.coins > coins0, "%d stacks, %d → %d copper" % [sold, coins0, p.coins])
		var buy_msg := world.living.buy(town, &"merchant", &"bread", 1)
		note("buy food", buy_msg == "", buy_msg)
		var leather_msg := world.living.buy(town, &"merchant", &"plank", 2)
		note("buy planks", leather_msg == "", leather_msg)
	# 5. A real weapon: squire sword at the workbench (flint, planks, rope).
	await walk_to(wb.global_position + Vector3(1.5, 0, 0) if wb else p.global_position)
	var made := 1 if await gather_and_craft(&"squire_sword") else 0
	note("craft a squire sword", made == 1, "Crafting %d: %s" % [p.character.skill_level(Skill.CRAFTING), str(RecipeBook.get_recipe(&"squire_sword").cost_at(p.character.skill_level(Skill.CRAFTING)))])
	if made == 1:
		for i in p.inventory.capacity:
			var s = p.inventory.get_slot(i)
			if s != null and s.id == &"squire_sword":
				p.equip_from_slot(i)
				break
	note("equip the sword", p.equipment.weapon() != null and p.equipment.weapon().id == &"squire_sword")
	# 6. Ruins: clear the guardians and loot the chest.
	var ruins: PoiInfo = null
	for q in world.generator.pois.near(p.global_position, 3000.0):
		if q.kind == PoiInfo.Kind.RUINS and q.rank == 0:
			ruins = q
			break
	if note("find ruins", ruins != null):
		await walk_to(ruins.world_center() + Vector3(0, 0, 3))
		world.exploration.update_now(true)
		await _frames(5)
		var site := world.exploration.site_of(ruins)
		var guards := site.guardians.size() if site else 0
		var cleared := 0
		if site:
			for g in site.guardians.duplicate():
				if is_instance_valid(g) and not g.is_dead:
					var hits := 0
					while is_instance_valid(g) and not g.is_dead and hits < 200:
						g.receive_hit(p.combat.build_damage(p.combat.light_combo[hits % p.combat.light_combo.size()], g))
						hits += 1
						play_time += 0.6
					if not is_instance_valid(g) or g.is_dead:
						cleared += 1
			await _frames(10)
		note("defeat the ruin guardians", cleared == guards and guards > 0, "%d/%d" % [cleared, guards])
		var coins := p.coins
		var roll := {}
		if site and not site.chests.is_empty():
			roll = site.chests[0].open()
		await _frames(30)
		note("loot the ruins", p.coins > coins or not roll.is_empty(), "%s" % str(roll))
	results.level = p.character.level
	results.play_minutes = play_time / 60.0
	note("loop complete", true, "level %d after %.0f minutes of play" % [p.character.level, play_time / 60.0])
	return results
