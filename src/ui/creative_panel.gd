class_name CreativePanel
extends PanelContainer
## Creative mode for testing (Milestone 18c). Open it with the ` key (under Esc).
##
## - Creative mode: you can't be hurt, health, mana, stamina, Rage and food stay
##   full, every active ability and spell can be used at once with no cost and no
##   cooldown (passives still follow your real level).
## - Fast move, level up to 30 / 64 / 100, learn every spell, a test kit of weapons.
## - Spawn a training dummy, a pack of minions, an elite or a boss; clear enemies;
##   switch day and night.
## Single player only. Achievements are switched off for the rest of the session
## once creative mode has been used.

var player: Player
var world: World
var _status := Label.new()
var _creative := CheckButton.new()
var _fast := CheckButton.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = "Creative Mode (testing)"
	t.add_theme_font_size_override(&"font_size", 22)
	t.add_theme_color_override(&"font_color", Color(0.55, 1.0, 0.75))
	v.add_child(t)
	var info := Label.new()
	info.text = "For testing: no damage, free abilities with no cooldown, quick tools.\nSingle player only. Achievements are off for this session once you use it."
	info.add_theme_font_size_override(&"font_size", 12)
	info.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(info)
	_creative.text = "Creative mode (can't be hurt, free and instant abilities)"
	_creative.toggled.connect(func(on: bool) -> void:
		if player and player.creative != on:
			set_creative(on))
	v.add_child(_creative)
	_fast.text = "Fast move (x1.8)"
	_fast.toggled.connect(func(on: bool) -> void:
		if player:
			player.creative_fast = on)
	v.add_child(_fast)
	_row(v, "Level", [["Level 30", func() -> void: _level(30)], ["Level 64", func() -> void: _level(64)],
		["Level 100", func() -> void: _level(100)]])
	_row(v, "Gear", [["Learn every spell", _learn_spells], ["Test kit (all weapon types, arrows, tome)", _give_kit],
		["Heal and refill", _refill]])
	_row(v, "Spawn", [["Training dummy", func() -> void: _spawn(&"skeleton_warrior", &"dummy")],
		["Minion pack (6)", func() -> void: _spawn(&"skeleton_minion", &"pack")],
		["Elite", func() -> void: _spawn(&"skeleton_warrior", &"elite")],
		["Boss", func() -> void: _spawn(&"bone_king", &"boss")]])
	_row(v, "World", [["Clear enemies near you", _clear], ["Day / night", _day_night], ["Reset cooldowns", _cooldowns]])
	_status.add_theme_font_size_override(&"font_size", 12)
	_status.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.7))
	v.add_child(_status)
	var close := Button.new()
	close.text = "Close ( ` )"
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)


func _row(parent: Node, title: String, buttons: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 60
	h.add_child(l)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void:
			if _allowed():
				(b[1] as Callable).call())
		h.add_child(btn)
	parent.add_child(h)


func bind(p: Player, w: World) -> void:
	player = p
	world = w


func toggle() -> void:
	visible = not visible
	if visible:
		_creative.set_pressed_no_signal(player != null and player.creative)
		_fast.set_pressed_no_signal(player != null and player.creative_fast)
		_status.text = "" if _allowed() else "Creative mode only works in single player."


func _allowed() -> bool:
	return player != null and world != null and not Net.is_online()


func _say(text: String) -> void:
	_status.text = text
	Events.toast.emit("Creative: " + text, Color(0.6, 1.0, 0.75))


func set_creative(on: bool) -> void:
	if not _allowed():
		_creative.set_pressed_no_signal(false)
		_status.text = "Creative mode only works in single player."
		return
	player.set_creative(on)
	_say("on - you can't be hurt and abilities are free" if on else "off")


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


## One of each weapon type (the strongest found), 99 arrows and the Tome of Embers.
func _give_kit() -> void:
	var best := {}
	for id in ItemDB.all_ids():
		var item: ItemData = ItemDB.get_item(id)
		if item == null or item.weapon_type == &"" or item.equip_slot != ItemData.EquipSlot.MAIN_HAND:
			continue
		var old: ItemData = best.get(item.weapon_type)
		if old == null or item.required_level > old.required_level:
			best[item.weapon_type] = item
	for wt in best:
		player.give_item((best[wt] as ItemData).id, 1)
	player.give_item(&"iron_arrow", 99)
	if ItemDB.has_item(&"embers_tome"):
		player.give_item(&"embers_tome", 1)
	_say("test kit: %d weapons, arrows and a tome" % best.size())


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


## Spawns `id` 8 m in front of you. kind: dummy (never fights, 50 000 health),
## pack (6 around the spot), elite or boss.
func _spawn(id: StringName, kind: StringName) -> void:
	var data := load("res://data/enemies/%s.tres" % id) as MonsterData
	if data == null or world.spawner == null:
		_say("can't spawn here")
		return
	world.spawner.max_active = maxi(world.spawner.max_active, 80)
	var center := player.global_position + player.get_facing() * 8.0
	var count := 6 if kind == &"pack" else 1
	var made := 0
	for i in count:
		var pos := center
		if count > 1:
			var a := TAU * i / count
			pos += Vector3(cos(a), 0, sin(a)) * 2.0
		pos.y = world.get_ground_height(pos) + 0.3
		var m := world.spawner.spawn_enemy(load(Monster.MONSTER_SCENE_PATH), pos, "", data) as Monster
		if m == null:
			continue
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
				m.make_elite([ids[randi() % ids.size()]])
		made += 1
	_say("spawned %d %s" % [made, data.display_name])


func _clear() -> void:
	var n := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Enemy
		if en and not en.is_dead and en.global_position.distance_to(player.global_position) < 40.0:
			NodePool.release_or_free(en)
			n += 1
	_say("removed %d enemies" % n)


func _day_night() -> void:
	var dn := world.day_night
	dn.advance_hours(12.0)
	_say("it is now %s" % dn.time_string())
