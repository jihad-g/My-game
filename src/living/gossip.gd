class_name Gossip
## What townsfolk say. Built from the real world state: undiscovered settlements
## (they then show on your map as "heard of"), cave entrances, the capital,
## trader days, regional prices and requests.

const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


## Compass direction from `from` to `to` (north = -Z, like the world map).
static func direction(from: Vector3, to: Vector3) -> String:
	var a := atan2(to.x - from.x, -(to.z - from.z))
	return DIRS[posmod(roundi(a / (PI / 4.0)), 8)]


static func distance_text(d: float) -> String:
	if d < 150.0:
		return "just %d m" % (roundi(d / 10.0) * 10)
	return "about %d m" % (roundi(d / 50.0) * 50)


static func greeting(npc: NPC, tier: int) -> String:
	var s := npc.site.info
	match npc.role:
		&"noble":
			return "Welcome to the court of %s. Speak, traveller." % s.kingdom_name if tier < 2 \
				else "Ah, our friend returns. %s is grateful for your deeds." % s.kingdom_name
		&"guard":
			return "Keep the peace in %s and we'll get along." % s.name if tier < 2 else "Good to see you. The walls are quiet today."
		&"trader":
			return "Goods from far and wide! Only here today, friend."
		&"merchant", &"royal_merchant":
			if not npc.is_open():
				return "The stall is closed. Come back after eight in the morning."
			return "Welcome, stranger. Care to look at my wares?" if tier < 2 else "Welcome back! I kept the good stock for you."
		&"blacksmith":
			if not npc.is_open():
				return "The forge is cold for today. Come back in the morning."
			return "Need steel? Or have ore to sell?" if tier < 3 else "For you, the best iron I have."
		&"farmer":
			return "Fine weather for the crops." if tier < 2 else "Oh, hello again! The harvest looks good this year."
	var lines := ["Hello there.", "Welcome to %s." % s.name, "Lovely day, isn't it?", "Mind the boars outside town."]
	if tier >= 2:
		lines = ["Hello, friend!", "Good to see you in %s again." % s.name]
	return lines[int(npc.data.seed) % lines.size()]


## All things this NPC can tell you right now (you get them one by one).
static func lines(npc: NPC, manager: SettlementManager) -> Array[String]:
	var out: Array[String] = []
	var s := npc.site.info
	var here := s.world_center()
	var settlements := manager.settlements()
	# A settlement you haven't found yet.
	for o in settlements.near(here, 1600.0):
		if o.id != s.id and not manager.is_discovered(o.id):
			GameState.discovered_places["heard:%s" % o.id] = GameState.world_time
			out.append("Travellers speak of %s, %s to the %s. It's on your map now." % [o.title(), distance_text(o.distance_to(here)), direction(here, o.world_center())])
			break
	# Dungeons and other places of interest nearby.
	var pois := manager.world.generator.pois
	var told := 0
	for p in pois.near(here, 900.0):
		if p.is_hidden() or GameState.discovered_places.has("poi:%s" % p.id) or told >= 1:
			continue
		GameState.discovered_places["heard:%s" % p.id] = GameState.world_time
		var what := ""
		match p.kind:
			PoiInfo.Kind.DUNGEON:
				what = "Adventurers speak of a dungeon, the %s - rank %s, they say. It lies %s to the %s. It's on your map now." % [
					p.title().split(" (")[0], p.rank_letter(), distance_text(p.distance_to(here)), direction(here, p.world_center())]
			PoiInfo.Kind.TEMPLE:
				what = "There's an old temple %s to the %s. A stone guardian watches its altar." % [distance_text(p.distance_to(here)), direction(here, p.world_center())]
			PoiInfo.Kind.TOWER:
				what = "A wizard's tower stands %s to the %s. The warden doesn't welcome visitors." % [distance_text(p.distance_to(here)), direction(here, p.world_center())]
			_:
				what = "Old ruins lie %s to the %s. Skeletons guard them - and maybe a hidden vault." % [distance_text(p.distance_to(here)), direction(here, p.world_center())]
		out.append(what)
		told += 1
	for p in pois.near(here, 1200.0):
		if p.is_hidden() and not GameState.discovered_places.has("poi:%s" % p.id):
			out.append("My grandmother swore there's a hidden grove somewhere to the %s, where starlight orchids grow." % direction(here, p.world_center()))
			break
	# Raids and rare events (Milestone 7).
	var w := manager.world
	if w.raids:
		if w.raids.pending_town.get("id", "") == s.id:
			out.append("Bandits are gathering to attack us! Please - we need every sword we can get.")
		elif w.raids.is_plundered(s.id):
			out.append("Bandits raided us. The stores are empty - prices stay steep until the carts come back.")
		elif w.raids.defended.has(s.id):
			out.append("You drove off the raiders! %s won't forget it." % s.name)
	if w.events:
		if w.events.is_active(&"blood_moon"):
			out.append("The moon is red tonight. Stay behind walls - the dead are walking.")
		else:
			var lore := ["My grandfather said when the moon turns red, the dead walk. Build walls, and keep a bell.",
				"Saw a little green fellow with a sack of gold running through the fields. Fast as a hare!",
				"Folk say stars that fall from the sky are made of metal no smith has ever worked."]
			out.append(lore[int(npc.data.seed) % lore.size()])
	# Caves nearby.
	var gen := manager.world.generator
	var caves := gen.get_cave_entrances_near(s.center.x - 400, s.center.y - 400, s.center.x + 400, s.center.y + 400)
	if not caves.is_empty():
		var best: Vector2i = caves[0]
		for c in caves:
			if Vector2(c - s.center).length() < Vector2(best - s.center).length():
				best = c
		var cpos := Vector3(best.x, 0, best.y)
		out.append("There's a cave mouth %s to the %s. Old miners left caches down there - books and ore, they say." % [distance_text(Vector2(best - s.center).length()), direction(here, cpos)])
	# Kingdom.
	if s.kingdom_id == "":
		out.append("No crown rules %s. We look after ourselves out here." % s.name)
	elif not s.is_kingdom():
		var cap := settlements.find(s.kingdom_id)
		if cap:
			out.append("We pay our dues to the Kingdom of %s. The capital, %s, lies %s to the %s." % [s.kingdom_name, cap.name, distance_text(cap.distance_to(here)), direction(here, cap.world_center())])
	else:
		out.append("The Lord of %s holds court in the keep. Earn the kingdom's trust and you'll be recognised." % s.kingdom_name)
	# Trader
	var site := npc.site
	var day := manager.world.day_night.day
	for k in 4:
		if site.is_trader_day(day + k):
			out.append("The travelling trader is in the square today, until six." if k == 0 else
				"The travelling trader's wagon comes by every third day - next in %d day%s." % [k, "" if k == 1 else "s"])
			break
	# Market tip.
	var region: Dictionary = Economy.REGION.get(s.biome_id, {})
	var dear: Array = region.get(&"dear", [])
	if not dear.is_empty():
		var item: ItemData = ItemDB.get_item(dear[int(npc.data.seed) % dear.size()])
		if item:
			out.append("Folk here pay well for %s - it's scarce around %s." % [item.display_name, s.name])
	# Requests
	for r in manager.requests(s):
		if r.type == "hunt" and not r.done:
			out.append("Boars have been raiding the fields. There's a bounty on the notice board.")
			break
	# Climate
	match s.biome_id:
		&"snowy_tundra", &"frostpine_taiga":
			out.append("Nights here are bitter. Keep a fire going, or a roof over your head.")
		&"sunscorch_desert":
			out.append("Don't cross the dunes at noon. Cactus fruit and coconut will cool you down.")
		&"murk_swamp":
			out.append("Watch your step in the bog. Glowcaps grow in the caves below, if you're brave.")
	return out
