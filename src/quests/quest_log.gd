class_name QuestLog
extends Node
## The player's story (Milestone 16): active and finished quests, lore pages
## read, and the chronicle of big moments. Listens to game events to move
## quest steps forward; saved with the world.
##
## Quests come from QuestBook: the main quest "The Lost Shards" (starts in every
## world) and one royal errand per kingdom (offered by its ruler).

signal changed

const LEVEL_MILESTONES := [5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100]
const LORE_CHANCE := 0.35

var world: World
## Quest id -> {"step": int, "progress": int, "settlement": String, "advance_paid": bool}
var active: Dictionary = {}
## Quest id -> day finished.
var done: Dictionary = {}
## Lore page ids in the order they were read; dynamic pages (kingdom histories) in `lore_extra`.
var lore: Array = []
var lore_extra: Dictionary = {}  # id -> [title, text]
## [{day, text}], newest last.
var chronicle: Array = []
## Titles earned from quests ("Shardbearer").
var titles: Array = []
## Shard Keepers defeated while the main quest was running.
var keepers: Array = []
var intro_seen := false
var _seen: Dictionary = {}  # chronicle once-only keys
var _rng := RandomNumberGenerator.new()
var _poll := 0.0


func _ready() -> void:
	_rng.randomize()
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.dungeon_left.connect(_on_dungeon_left)
	Events.boss_started.connect(_on_boss_started)
	Events.level_up.connect(_on_level_up)
	Events.raid_ended.connect(func(target: String, won: bool) -> void:
		if won:
			add_chronicle("Drove off a raid on %s." % target))
	Events.settlement_entered.connect(_on_settlement_entered)
	Events.title_granted.connect(func(t: String) -> void: add_chronicle("Was named %s." % t))


# --- Definitions ----------------------------------------------------------------------------

func definition(id: StringName) -> Dictionary:
	if id == QuestBook.MAIN:
		return QuestBook.main_quest()
	if String(id).begins_with("kingdom:") and world:
		var info := world.generator.settlements.find(String(id).substr(8))
		if info:
			return QuestBook.kingdom_quest(info)
	return {}


func is_active(id: StringName) -> bool:
	return active.has(id)


func is_done(id: StringName) -> bool:
	return done.has(id)


func step_index(id: StringName) -> int:
	return int((active.get(id, {}) as Dictionary).get("step", -1))


func current_step(id: StringName) -> Dictionary:
	var q := definition(id)
	var i := step_index(id)
	if q.is_empty() or i < 0 or i >= (q.steps as Array).size():
		return {}
	return q.steps[i]


# --- Lifecycle --------------------------------------------------------------------------------

## Starts a quest (no-op if running or finished).
func start(id: StringName, extra: Dictionary = {}) -> bool:
	if active.has(id) or done.has(id):
		return false
	var q := definition(id)
	if q.is_empty():
		return false
	var st := {"step": 0, "progress": 0}
	st.merge(extra)
	active[id] = st
	Events.toast.emit("New quest: %s" % q.title, UITheme.GOLD)
	_enter_step(id)
	changed.emit()
	return true


func _advance(id: StringName) -> void:
	var q := definition(id)
	var st: Dictionary = active[id]
	# Milestone 17c: the Keepers' fall teaches the way home - a Tome of Recall.
	if id == QuestBook.MAIN and String(current_step(id).get("goal", "")) == "keepers" and world and world.player:
		world.player.give_or_drop(&"tome_recall", 1)
		Events.toast.emit("The Great Shards hum together... you found a Tome: Recall", Color(0.75, 0.6, 1.0))
	st.step = int(st.step) + 1
	st.progress = 0
	if int(st.step) >= (q.steps as Array).size():
		_complete(id)
		return
	Events.toast.emit("%s: %s" % [q.title, q.steps[st.step].text], Color(1.0, 0.9, 0.6))
	Audio.play(&"notify", -4.0)
	_enter_step(id)
	changed.emit()


## Things that happen when a step begins (and steps that are already met).
func _enter_step(id: StringName) -> void:
	var step := current_step(id)
	match String(step.get("goal", "")):
		"keepers":
			for k in keepers:
				_grant_great_shard(k, true)
			_check_keepers(id)
		"collect":
			_check_collect(id)


func _complete(id: StringName) -> void:
	var q := definition(id)
	var st: Dictionary = active[id]
	active.erase(id)
	done[id] = _day()
	var r: Dictionary = q.get("rewards", {})
	var p := world.player
	var lines := PackedStringArray()
	if r.has("xp"):
		p.character.grant_xp(int(r.xp), Progression.Source.QUEST)
		lines.append("%d XP" % int(r.xp))
	var coins := int(r.get("coins", 0))
	if bool(st.get("advance_paid", false)):
		coins = coins / 2  # half was paid up front
	if coins > 0:
		p.coins += coins
		Events.coins_changed.emit(p.coins)
		lines.append(Economy.format_coins(coins))
	for item_id in r.get("items", {}):
		p.give_or_drop(item_id, int(r.items[item_id]))
		var d: ItemData = ItemDB.get_item(item_id)
		lines.append(d.display_name if d else String(item_id))
	if r.has("title") and not titles.has(r.title):
		titles.append(r.title)
		lines.append("title \"%s\"" % r.title)
	if r.has("title_tier"):
		var info := world.generator.settlements.find(String(st.get("settlement", "")))
		if info:
			var rep := p.reputation
			rep.add(info, float(r.get("rep", 0.0)))
			if int(rep.titles.get(info.kingdom_id, 0)) < int(r.title_tier):
				rep.titles[info.kingdom_id] = int(r.title_tier)
				var t := rep.title_for(info.kingdom_id, info.kingdom_name)
				lines.append("title \"%s\"" % t)
				Events.title_granted.emit(t)
	Events.toast.emit("Quest complete: %s (%s)" % [q.title, ", ".join(lines)], UITheme.GOLD)
	Audio.play(&"level_up", -2.0)
	add_chronicle("Completed the quest \"%s\"." % q.title)
	if r.has("title"):
		add_chronicle("Became known as %s." % r.title)
	if id == QuestBook.MAIN and world.hud:
		world.hud.show_story("The Shards Are Whole", "The Starborn Colossus falls, and the Great Shards go quiet in your hands. " +
			"For the first time since the Shattering, no star falls that night.\n\nThe Shardlands are still wild and wide, " +
			"and many places still wait for you. But the people will tell your story now: the %s." % QuestBook.MAIN_TITLE)
	changed.emit()


# --- Progress -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or world == null or world.player == null:
		return
	_poll = 0.5
	for id in active.keys():
		var g := String(current_step(id).get("goal", ""))
		if g == "collect":
			_check_collect(id)


func _check_collect(id: StringName) -> void:
	var step := current_step(id)
	var have := world.player.inventory.count_of(step.item)
	var st: Dictionary = active[id]
	if have != int(st.progress):
		st.progress = mini(have, int(step.count))
		changed.emit()
	if have >= int(step.count):
		_advance(id)


func _check_keepers(id: StringName) -> void:
	if not active.has(id) or current_step(id).get("goal", "") != "keepers":
		return
	active[id].progress = keepers.size()
	changed.emit()
	if QuestBook.KEEPERS.all(func(k: StringName) -> bool: return keepers.has(k)):
		_advance(id)


func _on_enemy_killed(enemy: Node, enemy_id: StringName, _pos: Vector3) -> void:
	if world == null:
		return
	# Shard Keepers: credited while the main quest runs, even before step 3.
	if enemy_id in QuestBook.KEEPERS and active.has(QuestBook.MAIN) and not keepers.has(enemy_id):
		keepers.append(enemy_id)
		_grant_great_shard(enemy_id, false)
		_check_keepers(QuestBook.MAIN)
	if enemy is Enemy and (enemy as Enemy).data and (enemy as Enemy).data.category == EnemyData.Category.BOSS:
		_once("boss:%s" % enemy_id, "Defeated %s." % (enemy.display_name() if enemy.has_method("display_name") else String(enemy_id)))
	for id in active.keys():
		var step := current_step(id)
		match String(step.get("goal", "")):
			"kill_meta":
				if enemy.has_meta(step.meta):
					_advance(id)
			"kill":
				var m := enemy as Monster
				if m and not m.mdata.timid and not m.get_meta(&"killed_by_npc", false):
					active[id].progress = int(active[id].progress) + 1
					changed.emit()
					if int(active[id].progress) >= int(step.count):
						_advance(id)


func _grant_great_shard(keeper: StringName, quiet: bool) -> void:
	# One Great Shard per keeper (kept in the inventory until the altar).
	var key := "shard_given:%s" % keeper
	if _seen.has(key):
		return
	_seen[key] = true
	world.player.give_or_drop(&"great_shard", 1)
	if not quiet:
		Events.toast.emit("A Great Shard falls from the %s! (%d / 3)" % [
			LoreBook.title_of(keeper), keepers.size()], UITheme.GOLD)


func _on_dungeon_left(poi_id: String, cleared: bool) -> void:
	if not cleared or world == null:
		return
	var poi := world.exploration.pois().find(poi_id)
	if poi:
		_once("dungeon:%s" % poi_id, "Cleared the %s." % poi.title())
	for id in active.keys():
		var step := current_step(id)
		if step.get("goal", "") == "dungeon" and poi and poi.rank >= int(step.rank):
			_advance(id)


func _on_boss_started(boss: Node) -> void:
	if boss is Enemy and (boss as Enemy).data:
		var page: StringName = LoreBook.BOSS_PAGES.get((boss as Enemy).data.id, &"")
		if page != &"":
			read_lore(page)


func _on_level_up(level: int) -> void:
	if level in LEVEL_MILESTONES:
		_once("level:%d" % level, "Reached level %d." % level)


func _on_settlement_entered(sid: String) -> void:
	if world == null:
		return
	var info := world.generator.settlements.find(sid)
	if info:
		_once("visit:%s" % sid, "Arrived in %s." % info.title())


## A POI chest was opened: shard fragments (main quest) and lore pages.
func on_chest_opened(chest: LootChest) -> void:
	if chest.table in QuestBook.FRAGMENT_TABLES and current_step(QuestBook.MAIN).get("goal", "") == "collect" \
			and world.player.inventory.count_of(&"shard_fragment") < 3:
		world.player.give_or_drop(&"shard_fragment", 1)
		Events.toast.emit("You found a Shard Fragment! It hums in your hand.", UITheme.GOLD)
	if chest.table in QuestBook.FRAGMENT_TABLES and _rng.randf() < LORE_CHANCE:
		var unread := LoreBook.FINDABLE.filter(func(p: StringName) -> bool: return not lore.has(p))
		if not unread.is_empty():
			read_lore(unread[_rng.randi() % unread.size()])


# --- Talking ------------------------------------------------------------------------------

## Main quest, step 1: what a villager knows about the falling stars.
func talk_main() -> String:
	if current_step(QuestBook.MAIN).get("goal", "") != "talk":
		return ""
	read_lore(&"shattering")
	_advance(QuestBook.MAIN)
	return "The falling stars? My grandmother called them the sky's tears. Long ago a great crystal broke over this land - " + \
		"the Shattering. Its shards are everywhere: in old ruins, in the wizard towers, in the temples on the hills. " + \
		"If you want answers, find the shards. Some say they sing when they are close to each other."


## Royal errand: what the ruler says, and the state of the errand.
func kingdom_state(info: SettlementInfo) -> String:
	var id := StringName("kingdom:%s" % info.kingdom_id)
	if done.has(id):
		return "done"
	if not active.has(id):
		return "offer"
	return String(current_step(id).get("goal", ""))


func accept_kingdom(info: SettlementInfo, paid_up_front: bool) -> void:
	var id := StringName("kingdom:%s" % info.kingdom_id)
	if start(id, {"settlement": info.id, "advance_paid": paid_up_front}) and paid_up_front:
		var q := definition(id)
		var half := int(q.rewards.coins) / 2
		world.player.coins += half
		Events.coins_changed.emit(world.player.coins)
		world.player.reputation.add(info, -3.0)
		Events.toast.emit("+%s paid up front (the ruler is not impressed)" % Economy.format_coins(half), UITheme.GOLD)


## Hands over the errand's goods, or reports back. "" if nothing happened.
func kingdom_turn_in(info: SettlementInfo) -> String:
	var id := StringName("kingdom:%s" % info.kingdom_id)
	var step := current_step(id)
	match String(step.get("goal", "")):
		"deliver":
			var inv := world.player.inventory
			if inv.count_of(step.item) < int(step.count):
				return "You still need %d more. The realm can wait - a little." % (int(step.count) - inv.count_of(step.item))
			inv.remove_item(step.item, int(step.count))
			_advance(id)
			return "Good. Now the harder part: our roads are full of monsters. Make them safe."
		"return":
			_advance(id)
			return "You did everything I asked, and more. Kneel... Rise, a knight of %s!" % info.kingdom_name
	return ""


## The ruler's history of the kingdom (4f), kept in the journal.
func kingdom_history(info: SettlementInfo) -> String:
	var rivals := world.generator.settlements.near(info.world_center(), 6000.0).filter(
		func(s: SettlementInfo) -> bool: return s.is_kingdom() and s.kingdom_id != info.kingdom_id)
	var rival: String = (rivals[0] as SettlementInfo).kingdom_name if not rivals.is_empty() else "the bandit brotherhood"
	var text := LoreBook.kingdom_history(info.kingdom_name, info.seed, rival)
	var pid := StringName("kingdom:%s" % info.kingdom_id)
	lore_extra[pid] = ["History of %s" % info.kingdom_name, text]
	read_lore(pid)
	return text


# --- The altar ------------------------------------------------------------------------------

## Using an Arcane Altar. Returns true if the quest used it.
func use_altar(altar: Node3D) -> bool:
	var goal := String(current_step(QuestBook.MAIN).get("goal", ""))
	if goal == "altar":
		if world.player.inventory.count_of(&"great_shard") < 3:
			Events.toast.emit("The altar is cold. It needs three Great Shards (%d / 3)." % world.player.inventory.count_of(&"great_shard"), Color(0.8, 0.8, 1.0))
			return true
		world.player.inventory.remove_item(&"great_shard", 3)
		Events.camera_shake.emit(0.6)
		VFX.ring(world, altar.global_position + Vector3(0, 0.2, 0), 8.0, Color(0.7, 0.8, 1.0, 0.9), 0.8)
		Events.toast.emit("The Great Shards join with a blinding light... and something answers from the sky!", Color(0.75, 0.85, 1.0))
		_advance(QuestBook.MAIN)
		summon_starborn(altar.global_position)
		return true
	if goal == "kill_meta":
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e.has_meta(&"quest_starborn") and not (e as Enemy).is_dead:
				Events.toast.emit("The Starborn Colossus is already here!", Color(1, 0.7, 0.5))
				return true
		summon_starborn(altar.global_position)
		return true
	return false


func summon_starborn(near: Vector3) -> Monster:
	var data := load("res://data/enemies/starborn_colossus.tres") as MonsterData
	var spot := near + Vector3(6.0, 0.5, 0)
	spot.y = world.get_ground_height(spot) + 0.5
	var m := world.spawner.spawn_enemy(load(WildSpawns.MONSTER_SCENE), spot, "", data) as Monster
	if m:
		var tier := clampi((world.player.character.level - 1) / 6, 0, 5)
		m.configure(1.0 + 0.25 * tier, 1.0 + 0.1 * tier, 2 * tier, 1.5)
		m.leash_mult = 2.0
		m.set_meta(&"quest_starborn", true)
		m._alert(world.player)
	return m


# --- Lore & chronicle -----------------------------------------------------------------------

func read_lore(page: StringName, quiet: bool = false) -> bool:
	if lore.has(page):
		return false
	lore.append(page)
	if not quiet:
		Events.toast.emit("New journal page: %s (O)" % lore_title(page), Color(0.85, 0.8, 1.0))
	changed.emit()
	return true


func lore_title(page: StringName) -> String:
	return String(lore_extra[page][0]) if lore_extra.has(page) else LoreBook.title_of(page)


func lore_text(page: StringName) -> String:
	return String(lore_extra[page][1]) if lore_extra.has(page) else LoreBook.text_of(page)


func add_chronicle(text: String) -> void:
	chronicle.append({"day": _day(), "text": text})
	changed.emit()


func _once(key: String, text: String) -> void:
	if not _seen.has(key):
		_seen[key] = true
		add_chronicle(text)


func _day() -> int:
	return world.day_night.day if world and world.day_night else 1


## The best title the player holds (quest titles first).
func best_title() -> String:
	return String(titles.back()) if not titles.is_empty() else ""


# --- Tracker --------------------------------------------------------------------------------

## What the HUD shows for the tracked quest: {title, text, target (Vector3 or INF), where}.
func tracker() -> Dictionary:
	var id: StringName = QuestBook.MAIN if active.has(QuestBook.MAIN) else (active.keys()[0] if not active.is_empty() else &"")
	if id == &"":
		return {}
	var q := definition(id)
	var step := current_step(id)
	var st: Dictionary = active[id]
	var text := String(step.text)
	match String(step.goal):
		"collect", "kill":
			text += " (%d / %d)" % [int(st.progress), int(step.count)]
		"keepers":
			text += " (%d / 3)" % keepers.size()
		"deliver":
			text += " (have %d)" % world.player.inventory.count_of(step.item)
	var target := _hint_target(id, step)
	var where := ""
	if target != Vector3.INF:
		var p := world.player.global_position
		where = "%s to the %s" % [Gossip.distance_text(Vector2(target.x - p.x, target.z - p.z).length()), Gossip.direction(p, target)]
	return {"title": q.title, "text": text, "target": target, "where": where, "step": int(st.step) + 1, "steps": (q.steps as Array).size()}


func _hint_target(id: StringName, step: Dictionary) -> Vector3:
	var p := world.player.global_position
	match String(step.get("hint", "")):
		"village":
			var near := world.generator.settlements.near(p, 3000.0)
			return near[0].world_center() if not near.is_empty() else Vector3.INF
		"giver":
			var info := world.generator.settlements.find(String(active[id].get("settlement", "")))
			return info.world_center() if info else Vector3.INF
		"poi":
			return _nearest_poi(p, [PoiInfo.Kind.RUINS, PoiInfo.Kind.TOWER, PoiInfo.Kind.TEMPLE], -1)
		"dungeon":
			if step.goal == "keepers":
				for k in QuestBook.KEEPERS:
					if not keepers.has(k):
						return _nearest_poi(p, [PoiInfo.Kind.DUNGEON], QuestBook.KEEPER_THEME[k])
			return _nearest_poi(p, [PoiInfo.Kind.DUNGEON], -1)
		"altar":
			var best := Vector3.INF
			for s in get_tree().get_nodes_in_group(&"crafting_stations"):
				if s.get_meta(&"station_id", &"") == &"arcane" and (s as Node3D).global_position.distance_to(p) < best.distance_to(p):
					best = (s as Node3D).global_position
			return best
		"boss":
			for e in get_tree().get_nodes_in_group(&"enemies"):
				if e.has_meta(&"quest_starborn") and not (e as Enemy).is_dead:
					return (e as Node3D).global_position
	return Vector3.INF


func _nearest_poi(p: Vector3, kinds: Array, theme: int) -> Vector3:
	var pois := world.exploration.pois()
	var c := Vector2i(floori(p.x / Exploration.CELL), floori(p.z / Exploration.CELL))
	var best := Vector3.INF
	var best_d := INF
	for r in 14:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var poi := pois.get_cell(c + Vector2i(dx, dz))
				if poi == null or not poi.kind in kinds or (theme >= 0 and poi.theme != theme):
					continue
				var d := Vector2(poi.center.x - p.x, poi.center.y - p.z).length()
				if d < best_d:
					best_d = d
					best = Vector3(poi.center.x, poi.height * TerrainGenerator.BLOCK_HEIGHT, poi.center.y)
		if best_d < (r - 1) * Exploration.CELL:
			break
	return best


# --- Save -----------------------------------------------------------------------------------

func to_save() -> Dictionary:
	var a := {}
	for id in active:
		a[String(id)] = (active[id] as Dictionary).duplicate()
	var d := {}
	for id in done:
		d[String(id)] = done[id]
	return {"active": a, "done": d, "lore": lore.map(func(x: StringName) -> String: return String(x)),
		"lore_extra": lore_extra.duplicate(true), "chronicle": chronicle.duplicate(true), "titles": titles.duplicate(),
		"keepers": keepers.map(func(x: StringName) -> String: return String(x)), "intro_seen": intro_seen, "seen": _seen.duplicate()}


func from_save(data: Dictionary) -> void:
	active.clear()
	done.clear()
	for id in data.get("active", {}):
		active[StringName(id)] = (data.active[id] as Dictionary).duplicate()
	for id in data.get("done", {}):
		done[StringName(id)] = int(data.done[id])
	lore = (data.get("lore", []) as Array).map(func(x) -> StringName: return StringName(String(x)))
	lore_extra.clear()
	for k in data.get("lore_extra", {}):
		lore_extra[StringName(k)] = data.lore_extra[k]
	chronicle = (data.get("chronicle", []) as Array).duplicate(true)
	titles = (data.get("titles", []) as Array).duplicate()
	keepers = (data.get("keepers", []) as Array).map(func(x) -> StringName: return StringName(String(x)))
	intro_seen = bool(data.get("intro_seen", false))
	_seen = (data.get("seen", {}) as Dictionary).duplicate()
	changed.emit()


## New worlds (and worlds from before Milestone 16) begin the main quest.
func begin_story() -> void:
	if not active.has(QuestBook.MAIN) and not done.has(QuestBook.MAIN):
		start(QuestBook.MAIN)
	if not intro_seen and world.hud:
		intro_seen = true
		var c := world.player.character.class_data
		world.hud.show_story("The Shardlands", "Long ago a great crystal fell from the stars and shattered over this land. " +
			"Its shards woke the magic of the world - and the monsters with it.\n\n%s\n\n" % (c.backstory if c and c.backstory != "" else "") +
			"Tonight another star falls. Find a village and ask about it. (Your quests are in the journal: O)")
		add_chronicle("Arrived in the Shardlands as a %s." % (c.display_name if c else "traveller"))
