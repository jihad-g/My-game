class_name CreativePanel
extends PanelContainer
## Creative mode for testing and debugging. Open it with the ` key (under Esc).
## Milestone 18c made the first version; Milestone 24 made it a full toolbox
## in six tabs:
##
## - Player: Creative mode (can't be hurt, everything full, free abilities with
##   no cooldown, free building and crafting), fast move, levels, spells,
##   recipes, coins.
## - Items: every item in the game, searchable, with quality and amount; kits;
##   any gear set given or worn at once.
## - Monsters: spawn any monster (normal, elite or training dummy), freeze or
##   clear enemies, start raids of each faction and the rare world events.
## - World: time of day, weather, air temperature, teleport to the nearest
##   town, dungeon, ruin, tower, temple, grove or any biome.
## - Dungeons: enter a test dungeon of any theme and rank, skip floors, clear
##   a floor, reset dungeon cooldowns.
## - Debug: the stats overlay, "Check the game" (SelfCheck: broken data links),
##   errors from the log, and a performance snapshot.
##
## Single player only. Achievements are switched off for the rest of the
## session once Creative mode has been used.

const ENEMY_DIR := "res://data/enemies/"
const ACCENT := Color(0.55, 1.0, 0.75)

var player: Player
var world: World
var _status := Label.new()
var _creative := CheckButton.new()
var _fast := CheckButton.new()
var _freeze := CheckButton.new()
var _tabs := TabContainer.new()
# Items tab
var _search := LineEdit.new()
var _category := OptionButton.new()
var _items := ItemList.new()
var _amount := SpinBox.new()
var _quality := OptionButton.new()
var _set_pick := OptionButton.new()
var _item_ids: Array[StringName] = []
# Monsters tab
var _monsters := ItemList.new()
var _monster_ids: Array[StringName] = []
var _spawn_kind := OptionButton.new()
var _spawn_count := SpinBox.new()
# World tab
var _biome_pick := OptionButton.new()
var _biome_ids: Array[StringName] = []
# Dungeons tab
var _theme := OptionButton.new()
var _rank := OptionButton.new()
var _dungeon_info := Label.new()
# Debug tab
var _report := TextEdit.new()
var _test_dungeons := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(900, 660)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var t := Label.new()
	t.text = "Creative Mode (testing and debugging)"
	t.add_theme_font_size_override(&"font_size", 22)
	t.add_theme_color_override(&"font_color", ACCENT)
	v.add_child(t)
	v.add_child(_small("Single player only. Achievements are off for this session once you use it."))
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_build_player()
	_build_items()
	_build_monsters()
	_build_world()
	_build_dungeons()
	_build_debug()
	_status.add_theme_font_size_override(&"font_size", 12)
	_status.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.7))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var close := Button.new()
	close.text = "Close ( ` )"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)


# --- Layout helpers -----------------------------------------------------------------

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 8)
	scroll.add_child(v)
	return v


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 12)
	l.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A short label for a row of controls (no wrapping).
func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _row(parent: Node, title: String, buttons: Array) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override(&"h_separation", 6)
	h.add_theme_constant_override(&"v_separation", 4)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 84
	h.add_child(l)
	for b in buttons:
		h.add_child(_button(b[0], b[1]))
	parent.add_child(h)


func _button(text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		if _allowed():
			action.call()
		else:
			_status.text = "Creative mode only works in single player, in a loaded world.")
	return btn


func _check(parent: Node, btn: CheckButton, text: String, on_toggle: Callable) -> void:
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggled.connect(on_toggle)
	parent.add_child(btn)


# --- Player tab -----------------------------------------------------------------------

func _build_player() -> void:
	var v := _tab("Player")
	_check(v, _creative, "Creative mode (can't be hurt, everything stays full, free and instant abilities, free building and crafting)",
		func(on: bool) -> void:
			if player and player.creative != on:
				set_creative(on))
	_check(v, _fast, "Fast move (x1.8)", func(on: bool) -> void:
		if player:
			player.creative_fast = on)
	_row(v, "Level", [["Level 10", func() -> void: _level(10)], ["Level 30", func() -> void: _level(30)],
		["Level 64", func() -> void: _level(64)], ["Level 100", func() -> void: _level(100)]])
	_row(v, "Learn", [["Every spell", _learn_spells], ["Every recipe", _learn_recipes]])
	_row(v, "Refill", [["Heal and refill", _refill], ["Reset cooldowns", _cooldowns], ["+1000 coins", _coins]])
	v.add_child(_small("Creative mode doesn't change your save: levels, items and recipes you add here stay, so use a Creative world for testing."))


func set_creative(on: bool) -> void:
	if not _allowed():
		_creative.set_pressed_no_signal(false)
		_status.text = "Creative mode only works in single player."
		return
	player.set_creative(on)
	_say("on - you can't be hurt, abilities, building and crafting are free" if on else "off")


func _level(n: int) -> void:
	var ch := player.character
	if ch.level >= n:
		_say("you are already level %d" % ch.level)
		return
	ch.grant_xp(Progression.total_xp_for(n) - ch.total_xp, Progression.Source.OTHER)
	_say("level %d" % ch.level)


func _learn_spells() -> void:
	var n := 0
	for id in SpellBook.sorted_ids():
		if not player.spells.knows(id):
			player.spells.learn(id)
			n += 1
	_say("learned %d spells" % n)


func _learn_recipes() -> void:
	var n := 0
	for id in RecipeBook.all():
		if player.recipes.learn(id):
			n += 1
	_say("learned %d recipes" % n)


func _refill() -> void:
	player.health.reset_full()
	player.mana.refill()
	player.stamina.refill()
	player.status.cleanse()
	_say("healed and refilled")


func _cooldowns() -> void:
	player.abilities.cooldowns.clear()
	player.abilities.cooldowns_changed.emit()
	_say("cooldowns reset")


func _coins() -> void:
	player.coins += 1000
	Events.coins_changed.emit(player.coins)
	_say("+1000 coins (%d)" % player.coins)


# --- Items tab ------------------------------------------------------------------------

func _build_items() -> void:
	var v := _tab("Items")
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	_search.placeholder_text = "Search items by name or id"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _fill_items())
	top.add_child(_search)
	_category.add_item("All")
	for c in ItemData.Category.keys():
		_category.add_item(String(c).capitalize())
	_category.item_selected.connect(func(_i: int) -> void: _fill_items())
	top.add_child(_category)
	v.add_child(top)
	_items.custom_minimum_size = Vector2(0, 250)
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.fixed_icon_size = Vector2i(24, 24)
	_items.item_activated.connect(func(_i: int) -> void:
		if _allowed():
			_give_selected())
	v.add_child(_items)
	var give := HBoxContainer.new()
	give.add_theme_constant_override(&"separation", 6)
	give.add_child(_label("Amount"))
	_amount.min_value = 1
	_amount.max_value = 999
	_amount.value = 1
	give.add_child(_amount)
	give.add_child(_label("Quality"))
	for q in ["Normal", "Fine", "Masterwork"]:
		_quality.add_item(q)
	give.add_child(_quality)
	give.add_child(_button("Give selected (or double-click)", _give_selected))
	v.add_child(give)
	_row(v, "Kits", [["Test kit (all weapon types, arrows, tome)", _give_kit], ["Materials (20 of each)", _give_materials],
		["Food and potions (5 of each)", _give_consumables]])
	var sets := HBoxContainer.new()
	sets.add_theme_constant_override(&"separation", 6)
	var sl := Label.new()
	sl.text = "Gear set"
	sl.custom_minimum_size.x = 84
	sets.add_child(sl)
	var ids := GearSets.SETS.keys()
	ids.sort()
	for s in ids:
		_set_pick.add_item(GearSets.display_name(s))
		_set_pick.set_item_metadata(_set_pick.item_count - 1, s)
	sets.add_child(_set_pick)
	sets.add_child(_button("Give the set", func() -> void: _give_set(false)))
	sets.add_child(_button("Wear the set now", func() -> void: _give_set(true)))
	v.add_child(sets)
	_fill_items()


func _fill_items() -> void:
	_items.clear()
	_item_ids.clear()
	var q := _search.text.strip_edges().to_lower()
	var cat := _category.selected - 1
	var list: Array = []
	for id in ItemDB.all_ids():
		if "@" in String(id):
			continue  # quality variants: pick a quality below instead
		var it: ItemData = ItemDB.get_item(id)
		if it == null or (cat >= 0 and it.category != cat):
			continue
		if q != "" and not (q in it.display_name.to_lower() or q in String(id)):
			continue
		list.append(it)
	list.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	for it: ItemData in list:
		var i := _items.add_item("%s  (%s)" % [it.display_name, it.id], ItemIcons.get_icon(it))
		_items.set_item_custom_fg_color(i, it.rarity_color())
		_item_ids.append(it.id)


func _give_selected() -> void:
	var sel := _items.get_selected_items()
	if sel.is_empty():
		_say("pick an item in the list first")
		return
	var id := _item_ids[sel[0]]
	var it: ItemData = ItemDB.get_item(id)
	if _quality.selected > 0 and ItemQuality.can_have_quality(it):
		id = ItemQuality.with_quality(id, _quality.selected)
	var n := int(_amount.value)
	player.give_or_drop(id, n)
	_say("gave %d %s" % [n, ItemDB.get_item(id).display_name])


## One of each weapon type (the strongest found), 99 arrows and the Tome of Embers.
func _give_kit() -> void:
	var best := {}
	for id in ItemDB.all_ids():
		var item: ItemData = ItemDB.get_item(id)
		if item == null or "@" in String(id) or item.weapon_type == &"" or item.equip_slot != ItemData.EquipSlot.MAIN_HAND:
			continue
		var old: ItemData = best.get(item.weapon_type)
		if old == null or item.required_level > old.required_level:
			best[item.weapon_type] = item
	for wt in best:
		player.give_or_drop((best[wt] as ItemData).id, 1)
	player.give_or_drop(&"iron_arrow", 99)
	if ItemDB.has_item(&"embers_tome"):
		player.give_or_drop(&"embers_tome", 1)
	_say("test kit: %d weapons, arrows and a tome" % best.size())


func _give_by(category: int, count: int) -> int:
	var n := 0
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it and not "@" in String(id) and it.category == category:
			player.give_or_drop(id, mini(count, it.max_stack))
			n += 1
	return n


func _give_materials() -> void:
	_say("gave %d kinds of material (some may be on the ground if your bags are full)" % _give_by(ItemData.Category.MATERIAL, 20))


func _give_consumables() -> void:
	_say("gave %d kinds of food and potions" % _give_by(ItemData.Category.FOOD, 5))


func set_pieces(set_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it and not "@" in String(id) and it.set_id == set_id:
			out.append(id)
	out.sort()
	return out


## Gives every piece of the chosen set, or puts it on straight away (old gear
## goes to your bags).
func _give_set(wear: bool) -> void:
	if _set_pick.selected < 0:
		return
	var set_id: StringName = _set_pick.get_item_metadata(_set_pick.selected)
	var pieces := set_pieces(set_id)
	for id in pieces:
		if wear:
			var old := player.equipment.equip(ItemDB.get_item(id))
			var back: Array[StringName] = player.equipment.take_displaced()
			if old != &"":
				back.push_front(old)
			for b in back:
				player.give_or_drop(b, 1)
		else:
			player.give_or_drop(id, 1)
	_say("%s %s (%d pieces)" % ["wearing" if wear else "gave", GearSets.display_name(set_id), pieces.size()])


# --- Monsters tab ---------------------------------------------------------------------

func _build_monsters() -> void:
	var v := _tab("Monsters")
	var all: Array = []
	for file in ResourceLoader.list_directory(ENEMY_DIR):
		if file.ends_with(".tres"):
			var d := load(ENEMY_DIR + file) as EnemyData
			if d:
				all.append(d)
	all.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return a.level < b.level if a.level != b.level else a.display_name < b.display_name)
	_monsters.custom_minimum_size = Vector2(0, 220)
	_monsters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for d: EnemyData in all:
		var boss := d is MonsterData and (d as MonsterData).style == MonsterData.Style.BOSS
		var i := _monsters.add_item("Lv %d  %s%s  (%s)" % [d.level, d.display_name, "  [BOSS]" if boss else "", d.id])
		if boss:
			_monsters.set_item_custom_fg_color(i, UITheme.GOLD)
		_monster_ids.append(d.id)
	_monsters.item_activated.connect(func(_i: int) -> void:
		if _allowed():
			_spawn_selected())
	v.add_child(_monsters)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	for k in ["Normal", "Elite", "Training dummy"]:
		_spawn_kind.add_item(k)
	h.add_child(_spawn_kind)
	h.add_child(_label("How many"))
	_spawn_count.min_value = 1
	_spawn_count.max_value = 20
	_spawn_count.value = 1
	h.add_child(_spawn_count)
	h.add_child(_button("Spawn (or double-click)", _spawn_selected))
	v.add_child(h)
	_check(v, _freeze, "Freeze enemies (they stand still and don't attack)", func(on: bool) -> void:
		Enemy.creative_freeze = on
		_say("enemies frozen" if on else "enemies move again"))
	_row(v, "Enemies", [["Clear enemies near you", _clear], ["Kill enemies near you (with loot)", _kill_near]])
	_row(v, "Raid", [["Bandits", func() -> void: _raid(&"bandits")], ["Tuskers", func() -> void: _raid(&"tuskers")],
		["Undead", func() -> void: _raid(&"undead")], ["End the raid", _end_raid]])
	var ev: Array = []
	for id: StringName in WorldEvents.IDS:
		ev.append([String(id).capitalize(), func() -> void: _event(id)])
	ev.append(["Stop events", _stop_events])
	_row(v, "Events", ev)


func _spawn_selected() -> void:
	var sel := _monsters.get_selected_items()
	if sel.is_empty():
		_say("pick a monster in the list first")
		return
	var kind: StringName = [&"normal", &"elite", &"dummy"][_spawn_kind.selected]
	_spawn(_monster_ids[sel[0]], kind, int(_spawn_count.value))


## Spawns `count` of `id` 8 m in front of you. kind: normal, elite, dummy (never
## fights, 50 000 health), pack (6 around the spot) or boss.
func _spawn(id: StringName, kind: StringName, count: int = -1) -> void:
	var data := load("%s%s.tres" % [ENEMY_DIR, id]) as EnemyData
	if data == null or world.spawner == null:
		_say("can't spawn here")
		return
	if count < 0:
		count = 6 if kind == &"pack" else 1
	var monster := data is MonsterData
	var scene: PackedScene = load(Monster.MONSTER_SCENE_PATH) if monster else load("res://scenes/enemies/%s.tscn" % id)
	if scene == null:
		_say("%s has no scene" % data.display_name)
		return
	world.spawner.max_active = maxi(world.spawner.max_active, 120)
	var center := player.global_position + player.get_facing() * 8.0
	var made := 0
	for i in count:
		var pos := center
		if count > 1:
			var a := TAU * i / count
			pos += Vector3(cos(a), 0, sin(a)) * (2.0 + count * 0.15)
		pos.y = (world.dungeon.floor_y() if world.dungeon else world.get_ground_height(pos)) + 0.3
		var e := world.spawner.spawn_enemy(scene, pos, "", data if monster else null)
		if e == null:
			continue
		var m := e as Monster
		if m:
			var lvl := player.character.level
			m.configure(1.0 + lvl * 0.04, 1.0 + lvl * 0.03, maxi(0, lvl - data.level), 0.0)
			match kind:
				&"dummy":
					m.health.max_health = 50000.0
					m.health.reset_full()
					m.make_dormant(-1.0)  # never wakes: stands still and never attacks
					m.set_meta(&"training_dummy", true)
				&"elite":
					var ids := EliteAffixes.ids()
					if (m.data as MonsterData).can_be_elite:
						m.make_elite([ids[randi() % ids.size()]])
		made += 1
	_say("spawned %d %s" % [made, data.display_name])


func _near_enemies(r: float = 40.0) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Enemy
		if en and not en.is_dead and en.is_visible_in_tree() and en.global_position.distance_to(player.global_position) < r:
			out.append(en)
	return out


func _clear() -> void:
	var n := 0
	for en in _near_enemies():
		NodePool.release_or_free(en)
		n += 1
	_say("removed %d enemies" % n)


## Kills them as if you did it: XP, loot, quest and dungeon progress all count.
func _kill_near() -> void:
	var n := 0
	for en in _near_enemies():
		if slay(en):
			n += 1
	_say("killed %d enemies" % n)


## Kills `en` straight through shields, blocks and dodges, as your kill.
func slay(en: Enemy) -> bool:
	if en.is_dead:
		return false
	en.health.invulnerable = false
	en.health.apply_damage(DamageInfo.create(en.health.current + 10.0, player, &"true"))
	return en.is_dead


## A raid on your base if you have one, else on the nearest town.
func _raid(faction: StringName) -> void:
	var r := world.raids
	if r.is_active():
		_say("a raid is already on - end it first")
		return
	var base := r.find_player_base()
	if not base.is_empty():
		r.start_base_raid(base, faction)
		r.raid.t = 8.0
		_say("%s raid your base" % RaidManager.FACTION_NAMES.get(faction, faction))
		return
	var near := world.generator.settlements.near(player.global_position, 600.0)
	if near.is_empty():
		_say("no base or town within 600 m - teleport to a town first (World tab)")
		return
	r.start_town_raid(near[0], r.tier_for_level(player.character.level), faction)
	_say("%s raid %s" % [RaidManager.FACTION_NAMES.get(faction, faction), near[0].name])


func _end_raid() -> void:
	if world.raids.is_active():
		world.raids._finish(true)
		_say("raid ended (won)")
	else:
		_say("no raid is on")


func _event(id: StringName) -> void:
	if world.events.is_active(id):
		_say("%s is already on" % String(id).capitalize())
	elif world.events.start(id):
		if id == &"meteor_shower":
			world.events.drop_meteor()
		_say("%s started" % String(id).capitalize())
	else:
		_say("%s can't start here or now" % String(id).capitalize())


func _stop_events() -> void:
	var n := world.events.active.size()
	for id in world.events.active.keys():
		world.events.stop(id)
	_say("stopped %d events" % n)


# --- World tab ------------------------------------------------------------------------

func _build_world() -> void:
	var v := _tab("World")
	_row(v, "Time", [["Dawn", func() -> void: _time(6.0)], ["Noon", func() -> void: _time(12.0)],
		["Dusk", func() -> void: _time(18.5)], ["Midnight", func() -> void: _time(0.0)], ["+1 day", func() -> void: _skip_day()]])
	var w: Array = [["Natural", func() -> void: _weather(-1)]]
	for k in WeatherSystem.KIND_NAMES.size():
		w.append([WeatherSystem.KIND_NAMES[k], func() -> void: _weather(k)])
	_row(v, "Weather", w)
	# Milestone 28: seasons and weather effects.
	var sea: Array = [["Natural", func() -> void: _season(-1)]]
	for k in 4:
		sea.append([Seasons.NAMES[k], func() -> void: _season(k)])
	sea.append(["Next season", _next_season])
	_row(v, "Season", sea)
	_row(v, "Nature", [["Lightning on a tree", _lightning_tree], ["Set the nearest tree on fire", _fire_tree],
		["Ripen all crops", _ripen_crops]])
	_row(v, "Air temp", [["-10°C", func() -> void: _temp(-10.0)], ["+10°C", func() -> void: _temp(10.0)],
		["Normal", func() -> void: _temp(0.0, true)]])
	_row(v, "Go to", [["Nearest town", _go_town], ["Nearest dungeon", func() -> void: _go_poi(PoiInfo.Kind.DUNGEON)],
		["Ruins", func() -> void: _go_poi(PoiInfo.Kind.RUINS)], ["Wizard tower", func() -> void: _go_poi(PoiInfo.Kind.TOWER)],
		["Temple", func() -> void: _go_poi(PoiInfo.Kind.TEMPLE)], ["Hidden grove", func() -> void: _go_poi(PoiInfo.Kind.GROVE)],
		["500 m ahead", _go_ahead], ["World centre", func() -> void: _go(Vector3(0, 0, 0), "the world centre")]])
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override(&"separation", 6)
	var bl := Label.new()
	bl.text = "Biome"
	bl.custom_minimum_size.x = 84
	bh.add_child(bl)
	for file in ResourceLoader.list_directory("res://data/biomes/"):
		if file.ends_with(".tres"):
			var b := load("res://data/biomes/" + file) as BiomeData
			if b and b.id != &"the_deeps":
				_biome_pick.add_item(b.display_name)
				_biome_ids.append(b.id)
	bh.add_child(_biome_pick)
	bh.add_child(_button("Go to the nearest", _go_biome))
	v.add_child(bh)
	_row(v, "Save", [["Save now", func() -> void: _say("saved" if world.save_now(false) else "this world isn't saved (Quick play)")]])


func _time(target: float) -> void:
	var dn := world.day_night
	dn.advance_hours(fposmod(target - dn.hour, 24.0))
	_say("it is now %s" % dn.time_string())


func _skip_day() -> void:
	world.day_night.advance_hours(24.0)
	_say("day %d, %s" % [world.day_night.day, world.day_night.time_string()])


func _weather(k: int) -> void:
	var ws := world.weather
	if ws == null:
		return
	if k < 0:
		ws.forced_kind = -1
		ws._retarget(true)
		_say("weather is natural again")
	else:
		ws.force(k, 1.0)
		ws.settle()
		_say("weather: %s" % WeatherSystem.KIND_NAMES[k])


func _season(k: int) -> void:
	Seasons.forced = k
	if world.weather:
		world.weather._retarget(true)
	_say("season: %s" % ("natural (%s)" % Seasons.season_name(Seasons.season_of(world.day_night.day)) if k < 0 else Seasons.NAMES[k]))


## Skips whole days to the first day of the next season.
func _next_season() -> void:
	Seasons.forced = -1
	var dn := world.day_night
	var days := Seasons.DAYS_PER_SEASON - Seasons.day_in_season(dn.day) + 1
	dn.advance_hours(24.0 * days)
	GameState.world_time += days * dn.day_length
	if world.weather:
		world.weather._retarget(true)
	_say("%s, day %d" % [Seasons.season_name(Seasons.season_of(dn.day)), dn.day])


func _lightning_tree() -> void:
	if world.weather == null or world.weather.strike_tree(player.global_position) == null:
		_say("no tree within 70 m")
		return
	_say("lightning struck a tree")


func _fire_tree() -> void:
	var trees := TreeFire.trees_near(world, player.global_position, 40.0)
	var best: PropBody = null
	for t in trees:
		if best == null or t.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = t
	if best == null or TreeFire.ignite(best) == null:
		_say("no tree within 40 m (or too many fires)")
		return
	_say("a tree %.0f m away is burning" % best.global_position.distance_to(player.global_position))


func _ripen_crops() -> void:
	var n := 0
	for plot in get_tree().get_nodes_in_group(&"farm_plots"):
		if plot.crop != &"":
			plot.growth = 1.0
			plot.grow_t = GameState.world_time
			plot.update_crop_visual()
			n += 1
	_say("%d crops are ripe" % n)


func _temp(delta: float, reset: bool = false) -> void:
	world.debug_temperature_offset = 0.0 if reset else world.debug_temperature_offset + delta
	_say("air temperature offset %+d°C" % roundi(world.debug_temperature_offset))


func _go(to: Vector3, what: String) -> void:
	if world.layer != TerrainGenerator.Layer.SURFACE and world.dungeon == null:
		_say("go back up to the surface first")
		return
	var lim := TerrainGenerator.WORLD_LIMIT_M - 64.0
	to.x = clampf(to.x, -lim, lim)
	to.z = clampf(to.z, -lim, lim)
	if world.teleport_to(to):
		_say("travelling to %s (%d, %d)" % [what, roundi(to.x), roundi(to.z)])
		visible = false
	else:
		_say("can't travel right now")


func _go_town() -> void:
	var near := world.generator.settlements.near(player.global_position, 3000.0)
	if near.is_empty():
		_say("no town within 3 km")
		return
	var s := near[0]
	if s.distance_to(player.global_position) < s.radius:
		if near.size() < 2:
			_say("you are in %s, and no other town is within 3 km" % s.name)
			return
		s = near[1]
	_go(Vector3(s.center.x, 0, s.center.y + s.radius * 0.6), s.name)


func _go_poi(kind: int) -> void:
	for p in world.exploration.pois().near(player.global_position, 4000.0):
		if p.kind == kind and p.distance_to(player.global_position) > 30.0:
			_go(Vector3(p.center.x, 0, p.center.y + 14.0), p.title())
			return
	_say("no %s within 4 km" % PoiInfo.KIND_NAMES[kind])


func _go_ahead() -> void:
	_go(player.global_position + player.get_facing() * 500.0, "500 m ahead")


## Searches outwards in rings (every 48 m, up to 4 km) for the chosen biome.
func _go_biome() -> void:
	if _biome_pick.selected < 0:
		return
	var want := _biome_ids[_biome_pick.selected]
	var p := player.global_position
	if world.current_biome and world.current_biome.id == want:
		_say("you are already there")
		return
	var step := 48.0
	for ring in range(1, 84):
		var r := ring * step
		var n := maxi(8, int(TAU * r / step))
		for i in n:
			var a := TAU * i / n
			var q := p + Vector3(cos(a), 0, sin(a)) * r
			var b := world.generator.get_biome(floori(q.x), floori(q.z))
			if b and b.id == want:
				_go(q, b.display_name)
				return
	_say("no %s within 4 km" % _biome_pick.get_item_text(_biome_pick.selected))


# --- Dungeons tab ---------------------------------------------------------------------

func _build_dungeons() -> void:
	var v := _tab("Dungeons")
	v.add_child(_small("Enter a test dungeon right where you stand. Its loot and first-clear rewards are real."))
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	for tn in PoiInfo.THEME_NAMES:
		_theme.add_item(tn)
	h.add_child(_theme)
	for r in PoiInfo.RANKS:
		_rank.add_item("Rank " + r)
	h.add_child(_rank)
	h.add_child(_button("Enter test dungeon", _enter_test_dungeon))
	v.add_child(h)
	_row(v, "Inside", [["Next floor", _next_floor], ["Kill this floor (with loot)", _kill_floor],
		["Go to the last room (stairs or boss)", _go_stairs], ["Leave the dungeon", _leave_dungeon]])
	_row(v, "Reset", [["Reset dungeon cooldowns", _reset_dungeons]])
	_dungeon_info.add_theme_font_size_override(&"font_size", 13)
	v.add_child(_dungeon_info)


func _enter_test_dungeon() -> void:
	if world.dungeon:
		_say("you are already in a dungeon")
		return
	if world.layer != TerrainGenerator.Layer.SURFACE:
		_say("dungeons start from the surface")
		return
	_test_dungeons += 1
	var poi := PoiInfo.new()
	poi.kind = PoiInfo.Kind.DUNGEON
	poi.rank = _rank.selected
	poi.theme = _theme.selected
	poi.seed = randi()
	poi.id = "creative_dungeon_%d_%d" % [Time.get_ticks_msec(), _test_dungeons]
	poi.center = Vector2i(int(player.global_position.x), int(player.global_position.z))
	if world.enter_dungeon(poi):
		_say("entered a rank %s %s" % [PoiInfo.RANKS[poi.rank], PoiInfo.THEME_NAMES[poi.theme]])
		visible = false
	else:
		_say("can't enter a dungeon right now")


func _next_floor() -> void:
	var d := world.dungeon
	if d == null:
		_say("you aren't in a dungeon")
	elif d.floor_index + 1 >= d.plan.floor_count:
		_say("this is the last floor")
	else:
		world.next_dungeon_floor()


func _kill_floor() -> void:
	var d := world.dungeon
	if d == null:
		_say("you aren't in a dungeon")
		return
	var n := 0
	for m in d.monsters.duplicate():
		if is_instance_valid(m) and slay(m):
			n += 1
	_say("killed %d monsters on this floor" % n)


## Moves you next to the last room (stairs down, or the boss).
func _go_stairs() -> void:
	var d := world.dungeon
	if d == null:
		_say("you aren't in a dungeon")
		return
	var c := d.to_global(d.plan.room_center(d.plan.end_room) + Vector3(1.5, 0, 1.5))
	c.y = d.floor_y() + 0.3
	player.global_position = c
	player.velocity = Vector3.ZERO
	world.camera_rig.snap_to_target()
	_say("moved to the last room")


func _leave_dungeon() -> void:
	if world.dungeon:
		world.exit_dungeon()
		_say("left the dungeon (loot on the floor was picked up)")
	else:
		_say("you aren't in a dungeon")


func _reset_dungeons() -> void:
	var st := world.exploration.state
	var n := 0
	for k: String in st.keys():
		if k.begins_with("dungeon:"):
			st.erase(k)
			n += 1
	_say("reset %d dungeons: they can be entered again" % n)


func _update_dungeon_info() -> void:
	var d := world.dungeon if world else null
	if d == null:
		_dungeon_info.text = "Not in a dungeon."
		return
	_dungeon_info.text = "%s · rank %s · floor %d of %d · %d monsters left%s" % [d.poi.title(), d.poi.rank_letter(),
		d.floor_index + 1, d.plan.floor_count, d.alive_count(), " · cleared" if d.cleared else ""]


# --- Debug tab ------------------------------------------------------------------------

func _build_debug() -> void:
	var v := _tab("Debug")
	_row(v, "Show", [["Stats overlay on / off (F3)", _toggle_overlay], ["Performance snapshot", _perf]])
	_row(v, "Check", [["Check the game (data links)", _self_check], ["Errors in the log", _log_errors]])
	_row(v, "Monsters", [["Show monster paths on / off", _toggle_paths], ["Pathfinding on / off", _toggle_nav],
		["Pathfinding stats", _nav_stats]])
	_report.editable = false
	_report.custom_minimum_size = Vector2(0, 300)
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_report.placeholder_text = "Results show here."
	v.add_child(_report)


## Milestone 25: draws each monster's path (green: reaches you, orange: can't).
func _toggle_paths() -> void:
	NavGrid.debug_draw = not NavGrid.debug_draw
	_say("monster paths %s" % ("shown" if NavGrid.debug_draw else "hidden"))


func _toggle_nav() -> void:
	NavGrid.enabled = not NavGrid.enabled
	_say("pathfinding %s" % ("on" if NavGrid.enabled else "off (old straight-line steering)"))


func _nav_stats() -> void:
	var st := NavGrid.stats
	_report.text = "Pathfinding: %d searches (%d reached, %d partial), %.2f ms average, %d cells searched on average, %d tiles built." % [
		st.searches, st.reached, st.partial, float(st.ms) / maxf(1.0, st.searches), int(st.nodes) / maxi(1, int(st.searches)), st.tiles_built]
	_say("pathfinding stats")


func _toggle_overlay() -> void:
	if world and world.hud:
		world.hud.toggle_debug_overlay()
		_say("stats overlay switched")


func _self_check() -> void:
	var c := SelfCheck.run()
	var path := c.save_report()
	_report.text = c.report() + ("\n\nSaved to %s" % path if path != "" else "")
	_say("check done: %d problems, %d notes" % [c.errors.size(), c.warnings.size()])


func _log_errors() -> void:
	var lines := SelfCheck.log_problems(40)
	_report.text = "No errors or warnings in this session's log." if lines.is_empty() else "\n".join(lines)
	_say("%d error and warning lines in the log" % lines.size())


func perf_text() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d · frame %.1f ms · physics %.1f ms" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("Draw calls %d · objects drawn %d · primitives %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	lines.append("Memory %.0f MB · video %.0f MB" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	lines.append("Nodes %d · objects %d · orphan nodes %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	lines.append("Pixel art: %d atlas pages, %d painted part meshes" % [PixelAuto.page_count(), PixelAuto.cached_count()])
	if world:
		var s := world.chunk_manager.get_debug_stats()
		lines.append("Chunks %d loaded · %d pending · cache %.1f MB" % [s.loaded, s.pending, s.cache_mb])
		lines.append("Enemies %d (in the world) · pickups %d" % [get_tree().get_nodes_in_group(&"enemies").size(),
			world.pickup_pool.active_count()])
		lines.append("Weather %s · %s, day %d · %s%s · monster sight x%.2f" % [world.weather.kind_name() if world.weather else "-",
			world.day_night.time_string(), world.day_night.day, Seasons.season_name(Seasons.season_of(world.day_night.day)),
			" (forced)" if Seasons.forced >= 0 else "", Enemy.weather_sight])
		var p := player.global_position
		lines.append("Position %.1f, %.1f, %.1f · biome %s · %s" % [p.x, p.y, p.z,
			world.current_biome.display_name if world.current_biome else "-",
			"in a dungeon" if world.dungeon else ("underground" if world.layer == 1 else "surface")])
	return "\n".join(lines)


func _perf() -> void:
	_report.text = perf_text()
	_say("performance snapshot taken")


# --- Common ---------------------------------------------------------------------------

func bind(p: Player, w: World) -> void:
	player = p
	world = w


func toggle() -> void:
	visible = not visible
	if visible:
		_creative.set_pressed_no_signal(player != null and player.creative)
		_fast.set_pressed_no_signal(player != null and player.creative_fast)
		_freeze.set_pressed_no_signal(Enemy.creative_freeze)
		_update_dungeon_info()
		_status.text = "" if _allowed() else "Creative mode only works in single player."


func _process(_delta: float) -> void:
	if visible and _tabs.current_tab == 4:
		_update_dungeon_info()


func _allowed() -> bool:
	return player != null and world != null and not Net.is_online()


func _say(text: String) -> void:
	_status.text = text
	Events.toast.emit("Creative: " + text, ACCENT)
