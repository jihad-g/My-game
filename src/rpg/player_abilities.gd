class_name PlayerAbilities
extends Node
## Class abilities + the universal Magic Temperature Shield, plus the
## Barbarian's Rage resource and ability buffs.
##
## Milestone 17b (ability book): every class learns a new ability every two
## levels (AbilityBook). Active abilities go on a 6-slot bar - keys Z, X, C, T,
## V, U - that you change in the ability book (L) while resting at a bed or a
## campfire; passive abilities are always on once learned. By default the bar
## holds the three starting abilities (Z, X, C) and the Temperature Shield (T);
## newly learned actives fill empty slots by themselves.
## Tuning lives in AbilityData resources; behaviour in _ability_<effect>().

signal cooldowns_changed
signal rage_changed(value: float)
signal buffs_changed
## The ability bar changed (Milestone 17b).
signal bar_changed

## The universal Magic Temperature Shield. Loaded at run time: a preload here
## would run while the ability scripts are still compiling and give an empty resource.
static func shield_ability() -> AbilityData:
	return AbilityBook.get_ability(&"temperature_shield")
const MAX_RAGE := 100.0

var player: Player
## id -> seconds left
var cooldowns: Dictionary = {}
## buff id -> seconds left (battle_cry, berserk, poison_blade, stealth, guardian, ambush, temperature_shield)
var buffs: Dictionary = {}
var rage: float = 0.0
var _rage_idle := 0.0
## Arcane Barrier hit points (absorbs damage while the buff lasts).
var barrier: float = 0.0
var _barrier_fx: MeshInstance3D


const SLOTS := 6
const SLOT_KEYS := ["Z", "X", "C", "T", "V", "U"]
## How close a bed or campfire must be to change the bar.
const REST_RANGE := 6.0

## Ability id per bar slot (&"" = empty).
var bar: Array[StringName] = []
## Death Mark / Judgement marks: target instance id -> {"until", "mult", "stored", "kind"}.
var marks: Dictionary = {}


## Every ability of the class in learning order (starting abilities included).
func class_abilities() -> Array:
	var c := player.character.class_data
	return AbilityBook.for_class(c.id) if c else []


## The class book plus the universal Temperature Shield.
func book() -> Array:
	return class_abilities() + [shield_ability()]


func get_slot(slot: int) -> AbilityData:
	_ensure_bar()
	if slot < 0 or slot >= SLOTS or bar[slot] == &"":
		return null
	return AbilityBook.get_ability(bar[slot])


## The default bar: the class's three starting abilities, then the Temperature Shield on T.
func default_bar() -> Array[StringName]:
	var out: Array[StringName] = [&"", &"", &"", shield_ability().id, &"", &""]
	var c := player.character.class_data
	if c:
		for i in mini(3, c.abilities.size()):
			out[i] = (c.abilities[i] as AbilityData).id
	return out


func _ensure_bar() -> void:
	if bar.size() != SLOTS:
		bar = default_bar()


func reset_bar() -> void:
	bar = default_bar()
	_known_level = player.character.level
	fill_bar()
	bar_changed.emit()


## Puts learned actives that are not on the bar into empty slots. Returns how many.
func fill_bar() -> int:
	_ensure_bar()
	var n := 0
	for a in class_abilities():
		var ab := a as AbilityData
		if ab.passive or not is_unlocked(ab) or bar.has(ab.id):
			continue
		var free := bar.find(&"")
		if free < 0:
			break
		bar[free] = ab.id
		n += 1
	if n > 0:
		bar_changed.emit()
	return n


## Why the bar can't be changed right now ("" = it can): you must rest at a bed or a campfire.
func bar_lock_reason() -> String:
	if player == null or not player.is_inside_tree():
		return ""
	for g in [&"rest_spots"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).global_position.distance_to(player.global_position) <= REST_RANGE:
				return ""
	return "Rest at a bed or a campfire to change your ability bar"


## Puts a learned active ability into a slot (swapping if it is in another slot).
## `force` skips the bed/campfire rule (new characters, tests).
func assign(slot: int, id: StringName, force: bool = false) -> bool:
	_ensure_bar()
	if slot < 0 or slot >= SLOTS:
		return false
	if not force and bar_lock_reason() != "":
		Events.toast.emit(bar_lock_reason(), Color(1, 0.8, 0.5))
		return false
	if id != &"":
		var a := AbilityBook.get_ability(id)
		if a == null or a.passive or not (book().has(a)) or not is_unlocked(a):
			return false
		var other := bar.find(id)
		if other >= 0:
			bar[other] = bar[slot]
	bar[slot] = id
	bar_changed.emit()
	return true


func is_learned(a: AbilityData) -> bool:
	return a != null and book().has(a) and is_unlocked(a)


## Learned passive with this effect? Returns its power (0 if not learned).
func passive_power(effect: StringName) -> float:
	if player == null or player.character == null or player.character.class_data == null:
		return 0.0
	var t := 0.0
	for a in class_abilities():
		var ab := a as AbilityData
		if ab.passive and ab.effect == effect and player.character.level >= ab.unlock_level:
			t += ab.power
	return t


func has_passive(effect: StringName) -> bool:
	return passive_power(effect) > 0.0


var _known_level := 0


func _ready() -> void:
	Events.enemy_killed.connect(_on_kill_for_buffs)
	Events.level_up.connect(func(level: int) -> void:
		if player and player.character:
			on_level_up(level))


## Called when the character reaches `level`: announces every ability learned
## since the last level up, fills empty bar slots and applies new passives.
func on_level_up(level: int) -> PackedStringArray:
	var names := PackedStringArray()
	var c := player.character.class_data
	if c == null:
		return names
	var prev := _known_level if _known_level > 0 and _known_level < level else level - 1
	_known_level = level
	for a in class_abilities():
		var ab := a as AbilityData
		if ab.unlock_level > prev and ab.unlock_level <= level:
			names.append("%s%s" % [ab.display_name, " (passive)" if ab.passive else ""])
	fill_bar()
	if names.size() > 0:
		player.character.recalculate()
		Events.toast.emit("New ability: %s - ability book (L)" % ", ".join(names), UITheme.GOLD)
	return names


func is_unlocked(a: AbilityData) -> bool:
	if a == null:
		return false
	if a == shield_ability():
		return player.character.can_use_temperature_shield()
	return player.character.level >= a.unlock_level


func lock_reason(a: AbilityData) -> String:
	if a == shield_ability() and not is_unlocked(a):
		return "Needs Mana Control %d" % player.character.class_data.temperature_shield_requirement()
	if a and player.character.level < a.unlock_level:
		return "Unlocks at level %d" % a.unlock_level
	return ""


func cooldown_left(a: AbilityData) -> float:
	return float(cooldowns.get(a.id, 0.0))


func effective_cost(a: AbilityData) -> float:
	if a == shield_ability():
		return player.character.ability_mana_cost(player.character.class_data.temperature_shield_cost)
	if a.cost_type == AbilityData.CostType.MANA:
		return player.character.ability_mana_cost(a.cost)
	return a.cost


func has_buff(id: StringName) -> bool:
	return buffs.has(id)


func buff_time(id: StringName) -> float:
	return float(buffs.get(id, 0.0))


## Tries to use the ability in `slot`. Returns true if it fired.
func try_use(slot: int) -> bool:
	var a := get_slot(slot)
	if a == null or player.is_dead or player.frozen:
		return false
	if not is_unlocked(a):
		Events.toast.emit("%s: %s" % [a.display_name, lock_reason(a)], Color(1, 0.8, 0.5))
		return false
	if cooldown_left(a) > 0.0:
		return false
	if player.status.is_silenced():
		Events.toast.emit("You are silenced!", Color(0.85, 0.6, 1.0))
		return false
	if player.state != Player.State.NORMAL or player.is_swimming:
		return false
	var cost := effective_cost(a)
	if not _can_pay(a, cost):
		Events.toast.emit("Not enough %s" % ("mana" if a == shield_ability() else a.cost_name()), Color(1, 0.8, 0.5))
		return false
	var fn := "_ability_%s" % a.effect
	var over := a.cost_type == AbilityData.CostType.MANA and has_buff(&"overload") and a.effect != &"overload"
	_overload_now = over
	var ok: bool = has_method(fn) and call(fn, a)
	_overload_now = false
	if not ok:
		return false
	if over:
		remove_buff(&"overload")
		cost *= 2.0
	if a.animation != &"":
		player.model.play_pose(a.animation, a.anim_time)
	_pay(a, minf(cost, player.mana.current) if a.cost_type == AbilityData.CostType.MANA else cost)
	cooldowns[a.id] = a.cooldown * cooldown_mult()
	_maybe_echo(fn, a)
	cooldowns_changed.emit()
	Events.ability_used.emit(a.id)
	return true


func _can_pay(a: AbilityData, cost: float) -> bool:
	if a == shield_ability():
		return player.mana.has(cost)
	match a.cost_type:
		AbilityData.CostType.MANA:
			return player.mana.has(cost)
		AbilityData.CostType.STAMINA:
			return player.stamina.current >= cost
		AbilityData.CostType.RAGE:
			return rage >= cost
	return true


func _pay(a: AbilityData, cost: float) -> void:
	if a == shield_ability():
		player.mana.try_spend(cost)
		return
	match a.cost_type:
		AbilityData.CostType.MANA:
			player.mana.try_spend(cost)
		AbilityData.CostType.STAMINA:
			player.stamina.consume(cost, false)
		AbilityData.CostType.RAGE:
			set_rage(rage - cost)


func _process(delta: float) -> void:
	# Smoke Walker (Milestone 17c): faster inside your smoke.
	if player and player.is_inside_tree():
		var in_smoke := false
		for z in get_tree().get_nodes_in_group(&"smoke_zones"):
			if (z as Node3D).global_position.distance_to(player.global_position) < float(z.get("radius")):
				in_smoke = true
		if in_smoke != _was_in_smoke:
			_was_in_smoke = in_smoke
			_apply_buff_stats()
	if cooldowns.size() > 0:
		for id in cooldowns.keys():
			cooldowns[id] -= delta
			if cooldowns[id] <= 0.0:
				cooldowns.erase(id)
		cooldowns_changed.emit()
	var buffs_dirty := false
	for id in buffs.keys():
		buffs[id] -= delta
		if buffs[id] <= 0.0:
			buffs.erase(id)
			_on_buff_ended(id)
			buffs_dirty = true
	if buffs_dirty:
		_apply_buff_stats()
		buffs_changed.emit()
	if player and player.character.class_data and player.character.class_data.uses_rage:
		_rage_idle += delta
		if _rage_idle > 3.0 and rage > 0.0 and not has_buff(&"berserk"):
			set_rage(rage - 6.0 * delta)


func set_rage(value: float) -> void:
	rage = clampf(value, 0.0, MAX_RAGE)
	rage_changed.emit(rage)


func add_rage(amount: float) -> void:
	if player.character.class_data.uses_rage:
		_rage_idle = 0.0
		set_rage(rage + amount)


var _overload_now := false
var _light_node: OmniLight3D
var _last_ambush_ms := -100000
var _rally_ready_ms := 0
var _was_in_smoke := false


## Cooldown multiplier: Mana Control, Discipline and Quick Cast (Milestone 17c).
func cooldown_mult() -> float:
	return Skill.cooldown_mult(player.character.skill_level(Skill.MANA_CONTROL)) \
		* (1.0 - passive_power(&"discipline")) * (1.0 - passive_power(&"quick_cast"))


## Arcane Echo: a mana ability or spell may fire a second time for free.
func _maybe_echo(fn: String, a: AbilityData) -> void:
	var echo := passive_power(&"arcane_echo")
	if echo <= 0.0 or a.cost_type != AbilityData.CostType.MANA or a.duration > 5.0 or randf() >= echo:
		return
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		if not player.is_dead and has_method(fn):
			Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, false, "Echo!")
			call(fn, a))


## Optional strength of a buff (Evasion chance, Frost Armour multiplier...).
var buff_powers: Dictionary = {}


func buff_power(id: StringName, default: float = 0.0) -> float:
	return float(buff_powers.get(id, default))


## Ability reactions when an enemy hit reaches the player (Milestone 17b):
## Spear Wall stuns frontal attackers, Frost Armour chills them.
func on_hit_received(info: DamageInfo) -> void:
	var src := info.source as Node3D
	if src == null or not is_instance_valid(src) or not src.is_in_group(&"enemies"):
		return
	if has_buff(&"spear_wall") and player._is_in_front(info) and src.global_position.distance_to(player.global_position) < 4.0:
		var a := _find(&"spear_wall")
		if src.has_method("apply_status"):
			src.apply_status(&"stunned", a.power if a else 1.5, {})
		_physical_hit(src, a.damage if a else 18.0, 30.0, 5.0, "Spear Wall")
	if has_buff(&"frost_armour") and src.has_method("apply_status"):
		src.apply_status(&"chilled", 3.0, {})
	if has_buff(&"spark_shield"):
		_status(src, &"shocked", 3.0)
		var a := SpellBook.get_spell(&"spark_shield")
		if a:
			_spell_hit(src, a, _spell_damage(a), "Spark Shield")


## Blocks a hit before it lands (Milestone 17c): Divine Shield, Hold the Line,
## Aegis (attacks from outside the dome) and Cloak of Shadows (spells). Returns the label or "".
func block_hit(info: DamageInfo) -> String:
	if has_buff(&"divine_shield"):
		return "Divine Shield"
	if has_buff(&"hold_line"):
		return "Held"
	var src := info.source as Node3D
	if has_buff(&"aegis") and is_instance_valid(src) and src.global_position.distance_to(player.global_position) > 4.0:
		return "Aegis"
	if has_buff(&"cloak") and info.damage_type != &"physical" and info.damage_type != &"true":
		return "Cloaked"
	return ""


## Retribution: blocked damage hurts the attacker.
func on_blocked(info: DamageInfo, blocked: float) -> void:
	var r := passive_power(&"retribution")
	var src := info.source as Node
	if r > 0.0 and is_instance_valid(src) and src.has_method("receive_hit") and src.is_in_group(&"enemies"):
		var back := DamageInfo.create(blocked * r, player, &"true")
		back.tag = "Retribution"
		back.hit_position = (src as Node3D).global_position + Vector3(0, 1.2, 0)
		src.receive_hit(back)


func add_buff(id: StringName, duration: float) -> void:
	buffs[id] = duration
	_apply_buff_stats()
	buffs_changed.emit()


func remove_buff(id: StringName) -> void:
	if buffs.erase(id):
		_on_buff_ended(id)
		_apply_buff_stats()
		buffs_changed.emit()


func _on_buff_ended(id: StringName) -> void:
	match id:
		&"arcane_barrier":
			barrier = 0.0
			if _barrier_fx and is_instance_valid(_barrier_fx):
				_barrier_fx.queue_free()
			_barrier_fx = null
		&"stealth":
			player.model.set_ghost(false)
		&"shield_wall":
			player.model.set_blocking(player.is_blocking)
		&"bloodlust":
			buff_powers.erase(&"bloodlust_stacks")
		&"warpath":
			buff_powers.erase(&"warpath_stacks")
		&"light":
			if is_instance_valid(_light_node):
				_light_node.queue_free()
		&"tamed":
			pass
		&"temperature_shield":
			player.character.ability_insulation = 0.0
			player.character.ability_cooling = 0.0
			player.character.recalculate()
			Events.toast.emit("Temperature Shield faded", Color(0.7, 0.8, 1.0))


func _apply_buff_stats() -> void:
	var mults := {}
	if has_buff(&"berserk"):
		mults[Stats.ATTACK_SPEED] = 1.4
	if has_buff(&"guardian"):
		mults[Stats.MOVE_SPEED] = 0.6
	if has_buff(&"stealth"):
		mults[Stats.MOVE_SPEED] = 1.15
	if has_buff(&"bloodlust"):
		mults[Stats.ATTACK_SPEED] = float(mults.get(Stats.ATTACK_SPEED, 1.0)) * (1.0 + 0.1 * minf(buff_power(&"bloodlust_stacks"), 5.0))
	var ms := float(mults.get(Stats.MOVE_SPEED, 1.0))
	if has_buff(&"warpath"):
		ms *= 1.0 + passive_power(&"warpath") * buff_power(&"warpath_stacks")
	if has_buff(&"stone_skin"):
		ms *= 0.8
	if has_buff(&"hold_line"):
		ms *= 0.15
	if has_buff(&"haste_spell"):
		ms *= 1.25
	if _was_in_smoke:
		ms *= 1.0 + passive_power(&"smoke_walker")
	mults[Stats.MOVE_SPEED] = ms
	if player.equipment.weapon() and player.equipment.weapon().is_two_handed():
		mults[Stats.ATTACK_SPEED] = float(mults.get(Stats.ATTACK_SPEED, 1.0)) * (1.0 + passive_power(&"titan_grip"))
	player.stats.set_source(&"abilities", mults)


# --- Combat hooks -------------------------------------------------------------------------

## Multiplier on outgoing damage from buffs and rage.
func outgoing_mult() -> float:
	var m := 1.0
	if player.character.class_data and player.character.class_data.uses_rage:
		m *= 1.0 + 0.003 * rage  # +3% per 10 rage
	if has_buff(&"battle_cry"):
		m *= 1.25
	if has_buff(&"might"):
		m *= 1.2
	if has_buff(&"starlight"):
		m *= 1.15
	if has_buff(&"blessing"):
		m *= 1.1
	# Passives (Milestone 17b).
	if player.health.get_ratio() < 0.3:
		m *= 1.0 + passive_power(&"blood_frenzy")
	var valor := passive_power(&"valor")
	if valor > 0.0:
		var near := 0
		for e in get_tree().get_nodes_in_group(&"enemies"):
			var n := e as Node3D
			if n and not n.get("is_dead") and n.is_visible_in_tree() and n.global_position.distance_to(player.global_position) < 6.0:
				near += 1
		m *= 1.0 + valor * mini(near, 5)
	# Milestone 17c.
	if has_buff(&"tundra_howl"):
		m *= 1.0 + buff_power(&"tundra_howl", 0.15)
	if has_buff(&"holy_weapon"):
		m *= 1.15
	var honour := passive_power(&"knights_honour")
	if honour > 0.0 and _enemies_near(player.global_position, 8.0).size() == 1:
		m *= 1.0 + honour
	var night := passive_power(&"night_hunter")
	if night > 0.0 and World.instance and World.instance.day_night and World.instance.day_night.is_night():
		m *= 1.0 + night
	return m * player.status.outgoing_mult()


## Extra damage against this target from passives and marks (Opportunist, Judgement).
func target_mult(target: Node) -> float:
	var m := 1.0
	var op := passive_power(&"opportunist")
	if op > 0.0 and target.get("status") is StatusEffects:
		var st := target.get("status") as StatusEffects
		if st.has(&"stunned") or st.has(&"slowed") or st.has(&"chilled") or st.has(&"frozen"):
			m *= 1.0 + op
	if PlayerCombat.is_undead(target):
		m *= 1.0 + passive_power(&"undead_bane") + (0.5 if has_buff(&"holy_weapon") else 0.0)
	var sunder := int(target.get_meta(&"sunder", 0))
	if sunder > 0 and int(target.get_meta(&"sunder_until", 0)) > Time.get_ticks_msec():
		m *= 1.0 + 0.05 * sunder
	var mk: Dictionary = marks.get(target.get_instance_id(), {})
	if not mk.is_empty() and float(mk.until) > Time.get_ticks_msec() / 1000.0:
		m *= 1.0 + float(mk.get("mult", 0.0))
	return m


## Multiplier on incoming damage from buffs.
func incoming_mult() -> float:
	var m := 1.0
	if has_buff(&"guardian"):
		m *= 0.5
	if has_buff(&"berserk"):
		m *= 1.15
	if has_buff(&"stoneskin"):
		m *= 0.8
	if has_buff(&"blessing"):
		m *= 0.9
	if has_buff(&"frost_armour"):
		m *= buff_power(&"frost_armour", 0.8)
	if has_buff(&"reckless"):
		m *= 1.2
	# Milestone 17c.
	if rage > 50.0:
		m *= 1.0 - passive_power(&"iron_hide")
	if has_buff(&"oath"):
		m *= buff_power(&"oath", 0.85)
	if has_buff(&"banner"):
		m *= 0.85
	if has_buff(&"stone_skin"):
		m *= buff_power(&"stone_skin", 0.7)
	return m


func is_stealthed() -> bool:
	return has_buff(&"stealth")


## Called by PlayerCombat before building a hit. Returns bonus tags/mults.
func consume_attack_bonus() -> Dictionary:
	var out := {"mult": 1.0, "crit": false, "tag": ""}
	if has_buff(&"stealth"):
		out.mult = 2.0 + passive_power(&"ambush_mastery")
		out.tag = "Ambush"
		_last_ambush_ms = Time.get_ticks_msec()
		if not has_buff(&"shadow_dance"):
			remove_buff(&"stealth")
	if has_buff(&"ambush"):
		out.crit = true
		remove_buff(&"ambush")
	if has_buff(&"wrath") and buff_power(&"wrath") > 0.0:
		out.crit = true
		buff_powers[&"wrath"] = buff_power(&"wrath") - 1.0
		if buff_power(&"wrath") <= 0.0:
			remove_buff(&"wrath")
	return out


## Called after a player hit landed on an enemy.
func on_hit_dealt(target: Node, dealt: float) -> void:
	add_rage(8.0)
	_store_mark_damage(target, dealt)
	if has_buff(&"frost_rage"):
		_status(target, &"chilled", 3.0)
	if has_buff(&"fire_rage"):
		_status(target, &"burn", 3.0, {"dps": 4.0 * player.character.physical_mult, "source": player})
	if has_buff(&"paralytic"):
		_status(target, &"slowed", 3.0)
		buff_powers[&"paralytic_hits"] = buff_power(&"paralytic_hits") + 1.0
		if int(buff_power(&"paralytic_hits")) % 5 == 0:
			_status(target, &"stunned", 1.0)
	if has_buff(&"berserk") and dealt > 0.0:
		player.health.heal(dealt * 0.1)
	if has_buff(&"poison_blade") and target.has_method("apply_status"):
		var a := _find(&"poison_blade")
		target.apply_status(&"poison", a.duration if a else 5.0, {"dps": a.damage if a else 3.0, "source": player})


func on_damage_taken(dealt: float) -> void:
	add_rage(dealt * 0.8 * (1.0 + passive_power(&"rage_fuel")))
	var rally := passive_power(&"rally")
	if rally > 0.0 and player.health.get_ratio() < 0.4 and Time.get_ticks_msec() >= _rally_ready_ms:
		_rally_ready_ms = Time.get_ticks_msec() + 60000
		player.afflict(&"regen", 5.0, {"hps": player.health.max_health * rally / 100.0})
		Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, true, "Rally!")
	if has_buff(&"stealth"):
		remove_buff(&"stealth")


func _find(id: StringName) -> AbilityData:
	for a in class_abilities():
		if a.id == id:
			return a
	return null


# --- Helpers ------------------------------------------------------------------------------

func _space() -> PhysicsDirectSpaceState3D:
	return player.get_world_3d().direct_space_state


func _enemies_in(radius: float, arc: float = 360.0, origin: Vector3 = Vector3.INF, facing: Vector3 = Vector3.ZERO) -> Array[Node]:
	if origin == Vector3.INF:
		origin = player.global_position + Vector3(0, 0.9, 0)
	if facing == Vector3.ZERO:
		facing = player.get_facing()
	var found := HitQuery.query_arc(_space(), origin, facing, radius, arc, Layers.ENEMY, [player.get_rid()])
	var out: Array[Node] = []
	for n in found:
		if n.has_method("receive_hit") and not n.get("is_dead"):
			out.append(n)
	return out


func _physical_hit(target: Node, base: float, poise: float, knockback: float, tag: String = "") -> float:
	var info := player.combat.build_physical(base, target, poise, knockback)
	if tag != "":
		info.tag = tag
	var dealt = target.receive_hit(info)
	var d := float(dealt) if dealt != null else 0.0
	on_hit_dealt(target, d)
	return d


func _spell_damage(a: AbilityData) -> float:
	var m := player.character.spell_mult
	var mc := player.character.skill_level(Skill.MANA_CONTROL)
	if mc >= 75 and player.mana.current > player.mana.max_mana * 0.5:
		m *= 1.15
	if World.instance and World.instance.events:
		m *= World.instance.events.spell_mult()  # aurora
	if a.damage_type in [&"fire", &"frost", &"lightning"]:
		m *= 1.0 + passive_power(&"elemental_focus")
	if _overload_now:
		m *= 2.0
	return a.damage * m * player.stats.get_mult(Stats.ATTACK_DAMAGE) * player.status.outgoing_mult()


func _spell_hit(target: Node, a: AbilityData, amount: float, tag: String = "") -> float:
	var info := DamageInfo.create(amount, player, a.damage_type)
	var dir := (target as Node3D).global_position - player.global_position
	dir.y = 0.0
	info.direction = dir.normalized()
	info.hit_position = (target as Node3D).global_position + Vector3(0, 1.2, 0)
	info.tag = tag
	info.amount *= target_mult(target)
	var dealt = target.receive_hit(info)
	return float(dealt) if dealt != null else 0.0


func _aim_target(max_range: float) -> Node3D:
	if is_instance_valid(player.lock_target) and not player.lock_target.get("is_dead") \
			and player.lock_target.global_position.distance_to(player.global_position) <= max_range:
		return player.lock_target
	# Enemy closest to the aim direction within range.
	var aim := player.get_aim_direction()
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or not n.is_visible_in_tree() or n.get("is_dead"):
			continue
		var to := n.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > max_range or d < 0.01:
			continue
		var angle := aim.angle_to(to / d)
		if angle > deg_to_rad(40.0):
			continue
		var score := angle * 10.0 + d
		if score < best_score:
			best_score = score
			best = n
	return best


# --- Barbarian ----------------------------------------------------------------------------

## Whirlwind: two spinning hits around you. power = number of hits.
func _ability_whirlwind(a: AbilityData) -> bool:
	player.model.play_spin(0.5)
	var hits := maxi(1, int(a.power))
	for i in hits:
		get_tree().create_timer(0.05 + i * 0.25, false).timeout.connect(func() -> void:
			if player.is_dead:
				return
			VFX.ring(player.get_parent(), player.global_position, a.radius, Color(1, 0.8, 0.6, 0.6), 0.25)
			for t in _enemies_in(a.radius):
				_physical_hit(t, a.damage, 20.0, 4.0, "Whirlwind"))
	return true


## Battle Cry: damage buff for `duration`, +power rage, staggers nearby enemies.
func _ability_battle_cry(a: AbilityData) -> bool:
	add_buff(&"battle_cry", a.duration)
	add_rage(a.power)
	VFX.ring(player.get_parent(), player.global_position, a.radius, Color(1, 0.3, 0.2, 0.7), 0.4)
	Events.camera_shake.emit(0.35)
	for t in _enemies_in(a.radius):
		if t.has_method("stagger"):
			t.stagger(0.6)
	return true


## Berserk: consumes all rage (needs `cost`); lasts rage/10 s: +40% attack speed,
## 10% lifesteal, +15% damage taken.
func _ability_berserk(a: AbilityData) -> bool:
	if rage < a.cost:
		Events.toast.emit("Need %d rage" % roundi(a.cost), Color(1, 0.6, 0.4))
		return false
	add_buff(&"berserk", maxf(rage / 10.0, a.duration))
	set_rage(0.0)
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1, 0), 2.0, Color(1, 0.1, 0.1, 0.6))
	return true


# --- Knight -------------------------------------------------------------------------------

## Shield Bash: frontal hit that stuns (duration) and taunts. Weaker without a shield.
func _ability_shield_bash(a: AbilityData) -> bool:
	var has_shield := player.equipment.has_shield()
	player.model.play_attack(&"thrust", 0.05, 0.08, 0.25)
	for t in _enemies_in(a.radius, 100.0):
		_physical_hit(t, a.damage * (1.0 if has_shield else 0.6), a.power, 6.0, "Bash")
		if t.has_method("apply_status"):
			t.apply_status(&"stunned", a.duration * (1.0 if has_shield else 0.5), {})
		if t.has_method("taunt"):
			t.taunt(player, 5.0)
	return true


## Guardian Stance: halves damage taken for `duration`, slows you, taunts enemies in radius.
func _ability_guardian(a: AbilityData) -> bool:
	add_buff(&"guardian", a.duration)
	VFX.ring(player.get_parent(), player.global_position, a.radius, Color(0.5, 0.7, 1.0, 0.6), 0.5)
	for t in _enemies_in(a.radius):
		if t.has_method("taunt"):
			t.taunt(player, a.duration)
	return true


## Rallying Charge: dash `range` metres through enemies, hitting each once, and heal power% of max health.
func _ability_rallying_charge(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	player.start_ability_dash(dir, a.range, 0.35, func(hit: Node) -> void:
		_physical_hit(hit, a.damage, 40.0, 7.0, "Charge"))
	player.health.heal(player.health.max_health * a.power / 100.0)
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1, 0), 1.5, Color(1, 0.9, 0.5, 0.5))
	return true


# --- Wizard -------------------------------------------------------------------------------

## Firebolt: fast projectile, fire damage + burn. Shatters frozen targets (x2).
func _ability_firebolt(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	var start := player.global_position + Vector3(0, 1.0, 0)
	var flight := dir  # 3D flight direction
	var tgt := _aim_target(a.range)
	if tgt:
		# Aim at the target's body so bolts reach enemies above or below you.
		flight = (tgt.global_position + Vector3(0, 0.7, 0) - start).normalized()
		dir = Vector3(flight.x, 0, flight.z).normalized()
	player.face_direction(dir, true)
	player.model.play_attack(&"thrust", 0.05, 0.1, 0.2)
	var p := Projectile.new()
	p.velocity = flight * 22.0
	p.lifetime = a.range / 22.0
	p.exclude = [player.get_rid()]
	var amount := _spell_damage(a)
	p.on_impact = func(pos: Vector3) -> void: ignite_clouds(pos, 1.0, amount * 2.5)
	p.info_builder = func(target: Node) -> DamageInfo:
		var info := DamageInfo.create(amount, player, &"fire")
		info.direction = dir
		info.knockback = dir * 2.0
		info.status_effects = [[&"burn", a.duration, {"dps": a.power * player.character.spell_mult, "source": player}]]
		return info
	player.get_parent().add_child(p)
	p.global_position = start + dir * 0.8
	return true


## Frost Nova: frost damage around you and freezes enemies for `duration`.
func _ability_frost_nova(a: AbilityData) -> bool:
	VFX.ring(player.get_parent(), player.global_position, a.radius, Color(0.6, 0.9, 1.0, 0.8), 0.35)
	var amount := _spell_damage(a)
	for t in _enemies_in(a.radius):
		_spell_hit(t, a, amount)
		if t.has_method("apply_status"):
			t.apply_status(&"frozen", a.duration, {})
	return true


## Chain Lightning: strikes the aimed enemy, then jumps to `power` more targets
## within `radius` of each other. +50% damage against targets standing in water.
func _ability_chain_lightning(a: AbilityData) -> bool:
	var first := _aim_target(a.range)
	if first == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	var hit: Array[Node3D] = []
	var points := PackedVector3Array([player.global_position + Vector3(0, 1.4, 0)])
	var current: Node3D = first
	var amount := _spell_damage(a)
	# Stormcaller Wand and other gear (Milestone 17a) add jumps.
	for jump in int(a.power) + 1 + roundi(player.combat.weapon_param(&"chain_bonus")):
		if current == null:
			break
		hit.append(current)
		points.append(current.global_position + Vector3(0, 1.0, 0))
		# Targets standing in water are wet: lightning is conducted (x1.5, see StatusEffects).
		if World.instance != null and World.instance.is_in_water(current.global_position) and current.has_method("apply_status"):
			current.apply_status(&"wet", 4.0, {})
		_spell_hit(current, a, amount)
		if current.has_method("apply_status"):
			current.apply_status(&"shocked", 3.0, {})
		amount *= 0.8
		var next: Node3D = null
		var best := a.radius
		for e in get_tree().get_nodes_in_group(&"enemies"):
			var n := e as Node3D
			if n == null or hit.has(n) or not n.is_visible_in_tree() or n.get("is_dead"):
				continue
			var d := n.global_position.distance_to(current.global_position)
			if d < best:
				best = d
				next = n
		current = next
	VFX.bolt(player.get_parent(), points, Color(0.7, 0.85, 1.0, 1.0))
	return true


# --- Assassin -----------------------------------------------------------------------------

## Shadow Step: blink behind the target (or `range` toward the cursor); next hit crits.
func _ability_shadow_step(a: AbilityData) -> bool:
	var tgt := _aim_target(a.range)
	var dest: Vector3
	var face: Vector3
	if tgt:
		var back: Vector3 = tgt.get_facing() if tgt.has_method("get_facing") else (tgt.global_position - player.global_position).normalized()
		dest = tgt.global_position - back * 1.3
		face = back
	else:
		face = player.get_aim_direction()
		dest = player.global_position + face * a.range * 0.6
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1, 0), 1.2, Color(0.4, 0.2, 0.6, 0.7))
	if World.instance:
		dest.y = World.instance.get_ground_height(dest) + 0.2
	player.global_position = dest
	player.face_direction(face, true)
	add_buff(&"ambush", a.duration)
	VFX.burst(player.get_parent(), dest + Vector3(0, 1, 0), 1.2, Color(0.4, 0.2, 0.6, 0.7))
	return true


## Poison Blade: for `duration`, melee hits add a poison stack (damage = dps per stack).
func _ability_poison_blade(a: AbilityData) -> bool:
	add_buff(&"poison_blade", a.power)
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1, 0), 1.0, Color(0.4, 0.9, 0.3, 0.6))
	return true


## Vanish: stealth for `duration`; enemies lose track of you; next hit is an Ambush (x2).
func _ability_vanish(a: AbilityData) -> bool:
	add_buff(&"stealth", a.duration)
	player.model.set_ghost(true)
	player.set_lock_target(null)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.has_method("lose_target"):
			e.lose_target(player)
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1, 0), 1.8, Color(0.1, 0.1, 0.15, 0.7))
	return true


# --- Universal ----------------------------------------------------------------------------

## Magic Temperature Shield: `duration` seconds of +power°C cold and heat protection.
func _ability_temperature_shield(a: AbilityData) -> bool:
	add_buff(&"temperature_shield", a.duration)
	player.character.ability_insulation = a.power
	player.character.ability_cooling = a.power
	player.character.recalculate()
	VFX.ring(player.get_parent(), player.global_position, 2.5, Color(0.5, 0.8, 1.0, 0.6), 0.5)
	Events.toast.emit("Temperature Shield active (%d min)" % roundi(a.duration / 60.0), Color(0.6, 0.85, 1.0))
	return true


# --- Advanced spells (Milestone 7) -------------------------------------------------------
# Learned from tomes (SpellBook), cast from the spell slots (Y / H, N with a tome). Any
# class may cast them if its Mana Control skill is high enough; damage scales
# with spell power, so Wizards hit hardest. Elemental combos (see
# StatusEffects): Shatter (fire on frozen x2), Conducted (lightning on wet
# x1.5), Deep Freeze (chill on chilled/wet -> frozen) and Combustion (fire
# into a Miasma cloud explodes).

## Why a spell can't be cast right now ("" = it can).
func spell_block_reason(a: AbilityData) -> String:
	var mc := player.character.skill_level(Skill.MANA_CONTROL)
	if mc < a.required_mana_control:
		return "%s needs Mana Control %d (you have %d)" % [a.display_name, a.required_mana_control, mc]
	if player.status.is_silenced():
		return "You are silenced!"
	if not player.mana.has(effective_cost(a)):
		return "Not enough mana"
	return ""


func try_cast(slot: int) -> bool:
	var a := player.spells.get_slot(slot)
	if a == null:
		if slot >= player.spells.usable_slots():
			Events.toast.emit("Spell slot N needs a tome in your off hand", Color(0.85, 0.8, 1.0))
		else:
			Events.toast.emit("Spell slot %s is empty. Learn spells from tomes (ability book: L)" % SpellBook.SLOT_KEYS[slot], Color(0.85, 0.8, 1.0))
		return false
	if player.is_dead or player.frozen or cooldown_left(a) > 0.0:
		return false
	if player.state != Player.State.NORMAL or player.is_swimming:
		return false
	var why := spell_block_reason(a)
	if why != "":
		Events.toast.emit(why, Color(1, 0.8, 0.5))
		return false
	var fn := "_spell_%s" % a.effect
	var over := has_buff(&"overload")
	_overload_now = over
	var ok: bool = has_method(fn) and call(fn, a)
	_overload_now = false
	if not ok:
		return false
	if over:
		remove_buff(&"overload")
		player.mana.try_spend(minf(effective_cost(a), player.mana.current))
	player.mana.try_spend(effective_cost(a))
	if a.animation != &"":
		player.model.play_pose(a.animation, a.anim_time)
	else:
		player.model.play_cast(0.45)
	cooldowns[a.id] = a.cooldown * cooldown_mult()
	_maybe_echo(fn, a)
	cooldowns_changed.emit()
	Events.ability_used.emit(a.id)
	return true


## Absorbs damage with the Arcane Barrier (and Mana Shield). Returns what gets through.
func absorb(amount: float) -> float:
	if has_buff(&"mana_shield") and amount > 0.0:
		var paid := minf(player.mana.current, amount)
		player.mana.try_spend(paid)
		amount -= paid
		if player.mana.current <= 0.5:
			remove_buff(&"mana_shield")
	if barrier <= 0.0 or not has_buff(&"arcane_barrier"):
		return amount
	var taken := minf(barrier, amount)
	barrier -= taken
	if barrier <= 0.0:
		remove_buff(&"arcane_barrier")
		Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, true, "Barrier broken")
	return amount - taken


## Fire blasts ignite Miasma clouds they touch (Combustion).
func ignite_clouds(pos: Vector3, blast_radius: float, power: float) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group(&"poison_clouds"):
		if c is GroundHazard and (c as GroundHazard).ignite(pos, blast_radius, power):
			n += 1
	return n


## Where a targeted spell lands: lock target, aimed enemy, else the cursor (clamped to range).
func cast_point(max_range: float) -> Vector3:
	var tgt := _aim_target(max_range)
	var p := player.global_position
	var pt: Vector3
	if tgt:
		pt = tgt.global_position
	elif player.camera_rig and player.camera_rig.is_inside_tree() and not DisplayServer.get_name() == "headless":
		pt = player.camera_rig.get_mouse_world_point(p.y)
	else:
		pt = p + player.get_aim_direction() * max_range * 0.6
	var flat := Vector3(pt.x - p.x, 0, pt.z - p.z)
	if flat.length() > max_range:
		flat = flat.normalized() * max_range
	pt = p + flat
	if World.instance:
		pt.y = World.instance.get_ground_height(pt)
	return pt


func _player_hazard(pos: Vector3, a: AbilityData, radius: float, delay: float, dmg: float) -> GroundHazard:
	var h := GroundHazard.spawn(player.get_parent(), pos, radius, delay, dmg, a.damage_type, player)
	h.hurts_player = false
	h.hurts_enemies = true
	h.color = a.icon_color
	h.knockback = 2.0
	h.poise_damage = 10.0
	return h


## Blink: teleport toward the cursor (stops at walls); 0.3 s invulnerable.
func _spell_blink(a: AbilityData) -> bool:
	var from := player.global_position
	var dir := player.get_aim_direction()
	var dest := from + dir * a.range
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), Layers.TERRAIN | Layers.BUILDING | Layers.PROP)
	q.exclude = [player.get_rid()]
	var hit := _space().intersect_ray(q)
	if not hit.is_empty():
		dest = Vector3(hit.position.x, from.y, hit.position.z) - dir * 0.7
	if World.instance:
		var g := World.instance.get_ground_height(dest)
		if g > from.y + 2.5:
			return false
		dest.y = g + 0.2
	VFX.burst(player.get_parent(), from + Vector3(0, 1, 0), 1.3, Color(0.75, 0.55, 1.0, 0.7))
	player.global_position = dest
	player.health.invulnerable = true
	get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
		if player.state != Player.State.DODGING:
			player.health.invulnerable = false)
	VFX.burst(player.get_parent(), dest + Vector3(0, 1, 0), 1.3, Color(0.75, 0.55, 1.0, 0.7))
	return true


## Healing Light: heal power% of max health, cure everything harmful, regenerate.
func _spell_healing_light(a: AbilityData) -> bool:
	var hp := player.health.max_health
	player.health.heal(hp * a.power / 100.0)
	var n := player.status.cleanse()
	player.afflict(&"regen", a.duration, {"hps": hp * 0.02})
	VFX.ring(player.get_parent(), player.global_position, 2.5, Color(1.0, 0.95, 0.55, 0.8), 0.5)
	VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), 1.6, Color(1.0, 0.95, 0.6, 0.6))
	if n > 0:
		Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, true, "Cleansed")
	return true


## Miasma: poison cloud at the target point. Fire ignites it (Combustion).
func _spell_poison_cloud(a: AbilityData) -> bool:
	var h := _player_hazard(cast_point(a.range), a, a.radius, 0.2, _spell_damage(a))
	h.linger = a.duration
	h.linger_tick = 1.0
	h.linger_mult = 1.0
	h.knockback = 0.0
	h.poise_damage = 0.0
	h.status_effect = [&"poison", 3.0, {"dps": _spell_damage(a) * 0.4, "source": player}]
	h.tag = "Miasma"
	return true


## Arcane Barrier: absorbs power x spell power damage for `duration` seconds.
func _spell_arcane_barrier(a: AbilityData) -> bool:
	barrier = a.power * player.character.spell_mult
	add_buff(&"arcane_barrier", a.duration)
	if _barrier_fx == null or not is_instance_valid(_barrier_fx):
		_barrier_fx = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 16
		sm.rings = 8
		_barrier_fx.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.7, 1.0, 0.18)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_barrier_fx.material_override = mat
		_barrier_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_barrier_fx.position.y = 1.0
		player.add_child(_barrier_fx)
	VFX.ring(player.get_parent(), player.global_position, 2.0, Color(0.5, 0.7, 1.0, 0.8), 0.4)
	return true


## Arcane Missiles: `power` homing missiles spread over the enemies near the target point.
func _spell_arcane_missiles(a: AbilityData) -> bool:
	var center := cast_point(a.range)
	var targets: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n and n.is_visible_in_tree() and not n.get("is_dead") and n.global_position.distance_to(center) < 7.0 \
				and n.global_position.distance_to(player.global_position) < a.range + 4.0:
			targets.append(n)
	if targets.is_empty():
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	targets.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(center) < y.global_position.distance_to(center))
	var amount := _spell_damage(a)
	player.model.play_attack(&"thrust", 0.05, 0.1, 0.3)
	for k in int(a.power):
		var tgt: Node3D = targets[k % targets.size()]
		get_tree().create_timer(0.02 + k * 0.12, false).timeout.connect(func() -> void:
			if player.is_dead or not is_instance_valid(tgt):
				return
			var p := Projectile.new()
			var spread := (k - (a.power - 1) * 0.5) * 0.35
			var dir := (tgt.global_position - player.global_position).normalized().rotated(Vector3.UP, spread)
			dir.y = 0.25
			p.velocity = dir.normalized() * 16.0
			p.lifetime = 2.2
			p.homing_target = tgt
			p.turn_rate = 7.0
			p.color = a.icon_color
			p.exclude = [player.get_rid()]
			p.info_builder = func(_t: Node) -> DamageInfo:
				var info := DamageInfo.create(amount, player, &"arcane")
				info.knockback = dir * 1.0
				info.poise_damage = 6.0
				return info
			player.get_parent().add_child(p)
			p.global_position = player.global_position + Vector3(0, 1.4, 0) + Vector3(dir.x, 0, dir.z) * 0.6)
	return true


## Blizzard: frost storm at the target point. Each tick chills; chilling twice freezes.
func _spell_blizzard(a: AbilityData) -> bool:
	var h := _player_hazard(cast_point(a.range), a, a.radius, 0.3, _spell_damage(a))
	h.linger = a.duration
	h.linger_tick = 0.5
	h.linger_mult = 1.0
	h.knockback = 0.0
	h.poise_damage = 4.0
	h.style = &"storm"
	h.status_effect = [&"chilled", 1.6, {}]
	h.tag = "Blizzard"
	return true


## Meteor: after `duration` s a meteor hits the target point (fire + burn). Ignites Miasma.
func _spell_meteor(a: AbilityData) -> bool:
	var dmg := _spell_damage(a)
	var h := _player_hazard(cast_point(a.range), a, a.radius, a.duration, dmg)
	h.style = &"meteor"
	h.knockback = 8.0
	h.poise_damage = 60.0
	h.status_effect = [&"burn", 4.0, {"dps": a.power * player.character.spell_mult, "source": player}]
	h.tag = "Meteor"
	h.on_blast = func(pos: Vector3) -> void: ignite_clouds(pos, a.radius, dmg * 0.6)
	player.model.play_attack(&"overhead", 0.2, 0.1, 0.4)
	return true


## Storm Call: `power` lightning strikes over `duration` s on enemies within `radius`. Shocks.
func _spell_storm_call(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var strikes := int(a.power)
	VFX.ring(player.get_parent(), player.global_position, a.radius, Color(0.75, 0.85, 1.0, 0.5), 0.6)
	for k in strikes:
		get_tree().create_timer(0.15 + k * a.duration / strikes, false).timeout.connect(func() -> void:
			if player.is_dead:
				return
			var pool: Array[Node3D] = []
			for e in get_tree().get_nodes_in_group(&"enemies"):
				var n := e as Node3D
				if n and n.is_visible_in_tree() and not n.get("is_dead") and n.global_position.distance_to(player.global_position) <= a.radius:
					pool.append(n)
			if pool.is_empty():
				return
			var t: Node3D = pool[randi() % pool.size()]
			var top := t.global_position + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1))
			VFX.bolt(player.get_parent(), PackedVector3Array([top, t.global_position + Vector3(0, 1.0, 0)]), Color(0.8, 0.85, 1.0, 1.0), 0.25)
			if World.instance and World.instance.is_in_water(t.global_position) and t.has_method("apply_status"):
				t.apply_status(&"wet", 4.0, {})
			_spell_hit(t, a, amount, "Lightning")
			if t.has_method("apply_status"):
				t.apply_status(&"shocked", 3.0, {}))
	return true


# --- Milestone 17b: shared helpers for the ability book --------------------------------------

func _parent() -> Node:
	return player.get_parent()


## Enemies in a cone in front of you (aim direction).
func _front(radius: float, arc: float) -> Array[Node]:
	var dir := player.get_aim_direction()
	player.face_direction(dir, true)
	return _enemies_in(radius, arc, Vector3.INF, dir)


## Living enemies within `radius` of `pos` (any height difference under 3 m).
func _enemies_near(pos: Vector3, radius: float) -> Array[Node]:
	var out: Array[Node] = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or n.get("is_dead") or not n.is_visible_in_tree() or not n.has_method("receive_hit"):
			continue
		var d := n.global_position - pos
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 3.0:
			out.append(n)
	return out


func _status(t: Node, id: StringName, duration: float, params: Dictionary = {}) -> void:
	if is_instance_valid(t) and t.has_method("apply_status") and not t.get("is_dead"):
		t.apply_status(id, duration, params)


## Flying projectile from the player's chest. `on_hit(t)` deals the damage.
func _shoot(dir: Vector3, speed: float, max_range: float, color: Color, on_hit: Callable, style: StringName = &"") -> Projectile:
	var p := Projectile.new()
	p.style = style
	p.color = color
	p.velocity = dir * speed
	p.lifetime = max_range / speed
	p.exclude = [player.get_rid()]
	p.mask = Layers.TERRAIN | Layers.ENEMY | Layers.PROP
	p.info_builder = func(_t: Node) -> DamageInfo:
		return DamageInfo.create(0.0, player)  # the real hit happens in on_hit
	p.on_hit = func(t: Node, _d: float) -> void:
		if is_instance_valid(t) and t.is_in_group(&"enemies"):
			on_hit.call(t)
	_parent().add_child(p)
	p.global_position = player.global_position + Vector3(0, 1.2, 0) + dir * 0.7
	return p


## Aim direction, tilted towards the aimed enemy's body (projectiles reach enemies above or below).
func _aim_flight(max_range: float) -> Vector3:
	var dir := player.get_aim_direction()
	var tgt := _aim_target(max_range)
	if tgt:
		var f := (tgt.global_position + Vector3(0, 0.8, 0) - (player.global_position + Vector3(0, 1.2, 0))).normalized()
		player.face_direction(Vector3(f.x, 0, f.z), true)
		return f
	player.face_direction(dir, true)
	return dir


func _zone(pos: Vector3, radius: float, duration: float, tick: float, color: Color, on_tick: Callable) -> AbilityZone:
	var z := AbilityZone.new()
	z.radius = radius
	z.duration = duration
	z.tick = tick
	z.color = color
	z.on_tick = on_tick
	_parent().add_child(z)
	if World.instance:
		pos.y = World.instance.get_ground_height(pos)
	z.global_position = pos
	return z


## Marks a target (Judgement, Death Mark). `kind` &"judgement" adds `mult` damage taken;
## &"death" stores the damage you deal and repeats `mult` of it when the mark ends.
func mark(t: Node, kind: StringName, duration: float, mult: float) -> void:
	marks[t.get_instance_id()] = {"until": Time.get_ticks_msec() / 1000.0 + duration, "mult": mult if kind == &"judgement" else 0.0,
		"kind": kind, "stored": 0.0, "share": mult}
	VFX.ring(_parent(), (t as Node3D).global_position, 1.2, Color(1, 0.9, 0.4, 0.8) if kind == &"judgement" else Color(0.6, 0.1, 0.6, 0.8), 0.4)
	if kind == &"death":
		var wr: WeakRef = weakref(t)
		var key := t.get_instance_id()
		get_tree().create_timer(duration, false).timeout.connect(func() -> void:
			var mk: Dictionary = marks.get(key, {})
			marks.erase(key)
			var tgt: Node = wr.get_ref()
			if mk.is_empty() or tgt == null or tgt.get("is_dead"):
				return
			var extra := float(mk.stored) * float(mk.share)
			if extra > 0.0:
				var info := DamageInfo.create(extra, player, &"true")
				info.tag = "Death Mark"
				info.hit_position = (tgt as Node3D).global_position + Vector3(0, 1.4, 0)
				tgt.receive_hit(info)
				VFX.burst(_parent(), info.hit_position, 1.4, Color(0.6, 0.1, 0.6, 0.8)))


## Death Mark bookkeeping (called from on_hit_dealt).
func _store_mark_damage(t: Node, dealt: float) -> void:
	var mk: Dictionary = marks.get(t.get_instance_id(), {})
	if not mk.is_empty() and mk.kind == &"death":
		mk.stored = float(mk.stored) + dealt


func _blind(t: Node, duration: float) -> void:
	if not is_instance_valid(t):
		return
	t.set_meta(&"blind_until", Time.get_ticks_msec() + int(duration * 1000.0))
	if t.has_method("lose_target"):
		t.lose_target(player)
	_status(t, &"weakened", duration)


func _on_kill_for_buffs(enemy: Node, _id: StringName, _pos: Vector3) -> void:
	if player == null or enemy.get_meta(&"killed_by_npc", false):
		return
	if has_buff(&"bloodlust"):
		player.health.heal(player.health.max_health * buff_power(&"bloodlust", 8.0) / 100.0)
		buff_powers[&"bloodlust_stacks"] = buff_power(&"bloodlust_stacks") + 1.0
		_apply_buff_stats()
	if has_passive(&"warpath"):
		buff_powers[&"warpath_stacks"] = minf(buff_power(&"warpath_stacks") + 1.0, 5.0)
		add_buff(&"warpath", 10.0)
	if has_passive(&"silent_kill") and Time.get_ticks_msec() - _last_ambush_ms < 600:
		add_buff(&"stealth", passive_power(&"silent_kill"))
		player.model.set_ghost(true)


# --- Barbarian (Milestone 17b) -----------------------------------------------------------------

## Cleave: wide swing in front; +power rage per enemy hit.
func _ability_cleave(a: AbilityData) -> bool:
	player.model.play_attack(&"spin", 0.08, 0.1, 0.3)
	var hit := 0
	for t in _front(a.radius, 200.0):
		_physical_hit(t, a.damage, 25.0, 4.0, "Cleave")
		hit += 1
	add_rage(a.power * hit)
	VFX.ring(_parent(), player.global_position, a.radius, Color(1, 0.6, 0.4, 0.6), 0.25)
	return true


## Leap Slam: jump towards the cursor (up to range) and slam: damage + slow around you.
func _ability_leap_slam(a: AbilityData) -> bool:
	var target := cast_point(a.range)
	var to := target - player.global_position
	to.y = 0.0
	var dist := clampf(to.length(), 1.0, a.range)
	var dir := to.normalized() if to.length() > 0.1 else player.get_facing()
	player.model.play_attack(&"plunge", 0.2, 0.1, 0.3)
	player.start_ability_dash(dir, dist, 0.35, func(_t: Node) -> void: pass)
	get_tree().create_timer(0.37, false).timeout.connect(func() -> void:
		if player.is_dead:
			return
		VFX.ring(_parent(), player.global_position, a.radius, Color(0.8, 0.6, 0.4, 0.8), 0.35)
		VFX.dust(_parent(), player.global_position, Color(0.6, 0.55, 0.5), 12)
		Events.camera_shake.emit(0.4)
		for t in _enemies_near(player.global_position, a.radius):
			_physical_hit(t, a.damage, 35.0, 6.0, "Leap Slam")
			_status(t, &"slowed", a.duration))
	return true


## Ground Stomp: stuns enemies around you.
func _ability_ground_stomp(a: AbilityData) -> bool:
	VFX.ring(_parent(), player.global_position, a.radius, Color(0.8, 0.7, 0.5, 0.8), 0.35)
	VFX.dust(_parent(), player.global_position, Color(0.6, 0.55, 0.5), 10)
	Events.camera_shake.emit(0.35)
	for t in _enemies_near(player.global_position, a.radius):
		_physical_hit(t, a.damage, 30.0, 3.0, "Stomp")
		_status(t, &"stunned", a.duration)
	return true


## Intimidating Shout: enemies around you are weakened (deal 25% less) for `duration`.
func _ability_intimidating_shout(a: AbilityData) -> bool:
	VFX.ring(_parent(), player.global_position, a.radius, Color(1, 0.3, 0.2, 0.6), 0.45)
	for t in _enemies_near(player.global_position, a.radius):
		_status(t, &"weakened", a.duration)
	return true


## Hamstring: a cut that slows the target.
func _ability_hamstring(a: AbilityData) -> bool:
	player.model.play_attack(&"slash_l", 0.06, 0.08, 0.25)
	for t in _front(a.radius, 90.0):
		_physical_hit(t, a.damage, 10.0, 1.0, "Hamstring")
		_status(t, &"slowed", a.duration)
	return true


## Reckless Swing: x power damage, but you take +20% damage for `duration`.
func _ability_reckless_swing(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.15, 0.1, 0.35)
	add_buff(&"reckless", a.duration)
	for t in _front(a.radius, 110.0):
		_physical_hit(t, a.damage * a.power, 45.0, 7.0, "Reckless")
	Events.camera_shake.emit(0.35)
	return true


## Earthshatter: a line of rocks in front of you; enemies on it are hurt and thrown off their feet.
func _ability_earthshatter(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	player.face_direction(dir, true)
	player.model.play_attack(&"overhead", 0.12, 0.1, 0.35)
	var start := player.global_position
	for i in 6:
		var p := start + dir * (1.2 + i * a.range / 6.0)
		get_tree().create_timer(0.05 * i, false).timeout.connect(func() -> void:
			VFX.debris(_parent(), p + Vector3(0, 0.3, 0), Color(0.55, 0.5, 0.45), 6, 5.0))
	Events.camera_shake.emit(0.4)
	for t in _enemies_near(start, a.range + 1.0):
		var to := (t as Node3D).global_position - start
		to.y = 0.0
		var along := to.dot(dir)
		if along > 0.3 and along < a.range + 0.8 and (to - dir * along).length() < a.radius:
			_physical_hit(t, a.damage, 60.0, 4.0, "Earthshatter")
			if t.has_method("stagger"):
				t.stagger(a.duration)
	return true


## Bloodlust: for `duration`, kills heal power% and add attack speed.
func _ability_bloodlust(a: AbilityData) -> bool:
	buff_powers[&"bloodlust"] = a.power
	buff_powers[&"bloodlust_stacks"] = 0.0
	add_buff(&"bloodlust", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.6, Color(0.9, 0.1, 0.1, 0.6))
	return true


## Savage Throw: your weapon flies out and back - two hits.
func _ability_savage_throw(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.08, 0.08, 0.3)
	_shoot(_aim_flight(a.range), 26.0, a.range, Color(0.75, 0.75, 0.8), func(t: Node) -> void:
		_physical_hit(t, a.damage, 20.0, 3.0, "Savage Throw")
		var wr: WeakRef = weakref(t)
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			var tt: Node = wr.get_ref()
			if tt and not tt.get("is_dead"):
				_physical_hit(tt, a.damage, 10.0, 2.0, "Return")), &"arrow")
	return true


## Skull Crack: big poise damage; stuns for `duration` if the enemy staggers.
func _ability_skull_crack(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.12, 0.1, 0.35)
	for t in _front(a.radius, 80.0):
		var poise_before = t.get("poise")
		_physical_hit(t, a.damage, a.power, 5.0, "Skull Crack")
		var poise_after = t.get("poise")
		if poise_before != null and poise_after != null and (float(poise_after) <= 0.0 or float(poise_after) > float(poise_before)):
			_status(t, &"stunned", a.duration)
	return true


## Unstoppable: no stagger or knockback for `duration`.
func _ability_unstoppable(a: AbilityData) -> bool:
	add_buff(&"unstoppable", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(1, 0.6, 0.2, 0.6))
	return true


## Second Wind: heal power% of max health over `duration` (costs rage).
func _ability_second_wind(a: AbilityData) -> bool:
	player.afflict(&"regen", a.duration, {"hps": player.health.max_health * a.power / 100.0 / a.duration})
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(0.4, 1, 0.5, 0.6))
	return true


# --- Knight (Milestone 17b) ---------------------------------------------------------------------

## Shield Wall: block every frontal hit for `duration`.
func _ability_shield_wall(a: AbilityData) -> bool:
	add_buff(&"shield_wall", a.duration)
	player.model.set_blocking(true)
	VFX.ring(_parent(), player.global_position, 1.6, Color(0.6, 0.75, 1.0, 0.7), 0.4)
	return true


## Lunge: dash `range` m forward, hitting enemies in the way.
func _ability_lunge(a: AbilityData) -> bool:
	player.model.play_attack(&"thrust", 0.04, 0.1, 0.25)
	player.start_ability_dash(player.get_aim_direction(), a.range, 0.2, func(hit: Node) -> void:
		_physical_hit(hit, a.damage, 25.0, 4.0, "Lunge"))
	return true


## Judgement: holy strike that marks the target (+power damage taken for `duration`).
func _ability_judgement(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.12, 0.1, 0.3)
	var hit := false
	for t in _front(a.radius, 90.0):
		var info := player.combat.build_physical(a.damage, t, 25.0, 4.0, 0.0, &"holy")
		info.tag = "Judgement"
		var dealt = t.receive_hit(info)
		on_hit_dealt(t, float(dealt) if dealt != null else 0.0)
		mark(t, &"judgement", a.duration, a.power)
		hit = true
	if not hit:
		Events.toast.emit("No enemy in front of you", Color(1, 0.8, 0.5))
	return hit


## Taunting Shout: every enemy within radius attacks you for `duration`.
func _ability_taunting_shout(a: AbilityData) -> bool:
	VFX.ring(_parent(), player.global_position, a.radius, Color(1, 0.6, 0.3, 0.6), 0.5)
	for t in _enemies_near(player.global_position, a.radius):
		if t.has_method("taunt"):
			t.taunt(player, a.duration)
		_status(t, &"taunted", a.duration)
	return true


## Shield Throw: hits up to `power` enemies in a chain (`radius` between jumps).
func _ability_shield_throw(a: AbilityData) -> bool:
	var first := _aim_target(a.range)
	if first == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	var hit: Array[Node3D] = []
	var points := PackedVector3Array([player.global_position + Vector3(0, 1.2, 0)])
	var cur: Node3D = first
	for i in int(a.power):
		if cur == null:
			break
		hit.append(cur)
		points.append(cur.global_position + Vector3(0, 1.0, 0))
		_physical_hit(cur, a.damage * (1.0 - 0.15 * i), 20.0, 3.0, "Shield Throw")
		var nxt: Node3D = null
		var best := a.radius
		for n in _enemies_near(cur.global_position, a.radius):
			var d := (n as Node3D).global_position.distance_to(cur.global_position)
			if not hit.has(n) and d < best:
				best = d
				nxt = n
		cur = nxt
	points.append(player.global_position + Vector3(0, 1.2, 0))
	VFX.bolt(_parent(), points, Color(0.75, 0.8, 0.95, 0.9), 0.35)
	return true


## Holy Light: heal power% (friends nearby heal too in co-op - NOT IMPLEMENTED until M18).
func _ability_holy_light(a: AbilityData) -> bool:
	player.health.heal(player.health.max_health * a.power / 100.0)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1.2, 0), 2.0, Color(1, 0.95, 0.6, 0.7))
	VFX.ring(_parent(), player.global_position, a.radius, Color(1, 0.95, 0.6, 0.5), 0.5)
	return true


## Spear Wall: for `duration`, frontal attackers are stunned (power s) and take damage.
func _ability_spear_wall(a: AbilityData) -> bool:
	add_buff(&"spear_wall", a.duration)
	player.model.play_attack(&"thrust", 0.05, 0.1, 0.3)
	VFX.ring(_parent(), player.global_position + player.get_facing() * 1.2, 1.2, Color(0.8, 0.8, 0.9, 0.7), 0.4)
	return true


## Consecrate: holy ground around you; undead take double.
func _ability_consecrate(a: AbilityData) -> bool:
	var dmg := a.damage * player.character.physical_mult
	_zone(player.global_position, a.radius, a.duration, 1.0, Color(1, 0.95, 0.55), func(ts: Array[Node]) -> void:
		for t in ts:
			var info := DamageInfo.create(dmg * (2.0 if PlayerCombat.is_undead(t) else 1.0), player, &"holy")
			info.tag = "Consecrate"
			info.hit_position = (t as Node3D).global_position + Vector3(0, 1, 0)
			t.receive_hit(info))
	return true


## Pommel Strike: quick hit that stuns for `duration`.
func _ability_pommel_strike(a: AbilityData) -> bool:
	player.model.play_attack(&"thrust", 0.04, 0.08, 0.2)
	var hit := false
	for t in _front(a.radius, 80.0):
		_physical_hit(t, a.damage, 20.0, 2.0, "Pommel")
		_status(t, &"stunned", a.duration)
		hit = true
	return hit or true


## Charge of the Order: long charge that knocks everyone in the way down.
func _ability_charge_of_the_order(a: AbilityData) -> bool:
	player.start_ability_dash(player.get_aim_direction(), a.range, 0.6, func(hit: Node) -> void:
		_physical_hit(hit, a.damage, 60.0, 8.0, "Charge")
		if hit.has_method("stagger"):
			hit.stagger(a.duration))
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(1, 0.9, 0.5, 0.6))
	return true


# --- Wizard (Milestone 17b) ---------------------------------------------------------------------

## Arcane Orb: slow orb that explodes on impact (radius).
func _ability_arcane_orb(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var p := _shoot(_aim_flight(a.range), 11.0, a.range, Color(0.75, 0.45, 1.0), func(_t: Node) -> void: pass)
	p.on_impact = func(pos: Vector3) -> void:
		VFX.burst(_parent(), pos, a.radius, Color(0.75, 0.45, 1.0, 0.7))
		for t in _enemies_near(pos, a.radius):
			_spell_hit(t, a, amount, "Arcane Orb")
	return true


## Flame Wave: a cone of fire; burns.
func _ability_flame_wave(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var dir := player.get_aim_direction()
	for i in 4:
		VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0) + dir * (1.5 + i * 1.3), 0.6 + i * 0.3, Color(1, 0.5, 0.15, 0.7))
	for t in _front(a.radius, 70.0):
		_spell_hit(t, a, amount, "Flame Wave")
		_status(t, &"burn", a.duration, {"dps": a.power * player.character.spell_mult, "source": player})
	ignite_clouds(player.global_position + dir * a.radius * 0.5, a.radius * 0.6, amount * 2.0)
	return true


## Ice Lance: frost shard; x2 on chilled or frozen enemies.
func _ability_ice_lance(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	_shoot(_aim_flight(a.range), 28.0, a.range, Color(0.6, 0.9, 1.0), func(t: Node) -> void:
		var st = t.get("status")
		var cold: bool = st is StatusEffects and ((st as StatusEffects).has(&"chilled") or (st as StatusEffects).has(&"frozen"))
		_spell_hit(t, a, amount * (2.0 if cold else 1.0), "Shattering Lance" if cold else "Ice Lance")
		_status(t, &"chilled", 3.0))
	return true


## Time Warp: enemies in the circle are slowed for `duration`.
func _ability_time_warp(a: AbilityData) -> bool:
	_zone(cast_point(a.range), a.radius, a.duration, 0.4, Color(0.75, 0.55, 1.0), func(ts: Array[Node]) -> void:
		for t in ts:
			_status(t, &"slowed", 0.6)
			_status(t, &"chilled", 0.6))
	return true


## Spark: fast, weak lightning bolt that shocks.
func _ability_spark(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	_shoot(_aim_flight(a.range), 40.0, a.range, Color(0.8, 0.85, 1.0), func(t: Node) -> void:
		_spell_hit(t, a, amount, "Spark")
		_status(t, &"shocked", 2.0))
	return true


## Fire Wall: a line of burning patches across the aim for `duration`.
func _ability_fire_wall(a: AbilityData) -> bool:
	var dmg := _spell_damage(a)
	var center := cast_point(12.0)
	var dir := player.get_aim_direction()
	var side := Vector3(-dir.z, 0, dir.x)
	for i in 5:
		var pos := center + side * (i - 2) * (a.range / 5.0)
		_zone(pos, a.radius, a.duration, 0.5, Color(1, 0.45, 0.1), func(ts: Array[Node]) -> void:
			for t in ts:
				_spell_hit(t, a, dmg * 0.25, "Fire Wall")
				_status(t, &"burn", 3.0, {"dps": dmg * 0.15, "source": player}))
	return true


## Frost Armour: 20% less damage taken; attackers are chilled.
func _ability_frost_armour(a: AbilityData) -> bool:
	buff_powers[&"frost_armour"] = a.power
	add_buff(&"frost_armour", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.6, Color(0.6, 0.9, 1.0, 0.6))
	return true


## Mana Shield: damage takes mana instead of health for `duration`.
func _ability_mana_shield(a: AbilityData) -> bool:
	add_buff(&"mana_shield", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.6, Color(0.5, 0.6, 1.0, 0.6))
	return true


## Static Field: lightning ground that shocks and hurts enemies on it.
func _ability_static_field(a: AbilityData) -> bool:
	var dmg := _spell_damage(a)
	_zone(cast_point(a.range), a.radius, a.duration, 0.5, Color(0.8, 0.85, 1.0), func(ts: Array[Node]) -> void:
		for t in ts:
			_spell_hit(t, a, dmg * 0.3, "Static")
			_status(t, &"shocked", 1.0))
	return true


## Polymorph: the target becomes a harmless chicken for `duration` (not bosses).
func _ability_polymorph(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	if t.has_method("is_boss") and t.is_boss():
		Events.toast.emit("Bosses can't be polymorphed", Color(1, 0.8, 0.5))
		return false
	_status(t, &"stunned", a.duration)
	if t.has_method("lose_target"):
		t.lose_target(player)
	var model = t.get("model")
	if model is Node3D:
		var m := model as Node3D
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector3(0.35, 0.35, 0.35), 0.15)
		tw.tween_interval(a.duration)
		tw.tween_property(m, "scale", Vector3.ONE, 0.15)
	VFX.burst(_parent(), t.global_position + Vector3(0, 0.8, 0), 1.2, Color(1, 0.95, 0.8, 0.8))
	Events.damage_dealt.emit(t.global_position + Vector3(0, 1.6, 0), 0.0, false, false, "Cluck!")
	return true


## Ice Wall: a wall of ice (power m wide) at the cursor that blocks the way for `duration`.
func _ability_ice_wall(a: AbilityData) -> bool:
	var pos := cast_point(a.range)
	if World.instance:
		pos.y = World.instance.get_ground_height(pos)
	var dir := player.get_aim_direction()
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.BUILDING
	wall.collision_mask = 0
	wall.add_to_group(&"ice_walls")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(a.power, 2.2, 0.7)
	shape.shape = box
	shape.position.y = 1.1
	wall.add_child(shape)
	var b := BlockMesh.new()
	b.box(Vector3(0, 1.1, 0), Vector3(a.power, 2.2, 0.7), Color(0.65, 0.88, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.mesh.surface_set_material(0, Materials.vertex_color())
	mi.transparency = 0.25
	wall.add_child(mi)
	_parent().add_child(wall)
	wall.global_position = pos
	wall.rotation.y = atan2(dir.x, dir.z)
	VFX.burst(_parent(), pos + Vector3(0, 1, 0), 2.0, Color(0.7, 0.9, 1.0, 0.7))
	get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
		if is_instance_valid(wall):
			VFX.debris(wall.get_parent(), wall.global_position + Vector3(0, 1, 0), Color(0.7, 0.9, 1.0), 10, 4.0)
			wall.queue_free())
	return true


## Ball Lightning: a slow ball that zaps enemies within radius as it flies.
func _ability_ball_lightning(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var p := _shoot(_aim_flight(a.range), 7.0, a.range, Color(0.8, 0.85, 1.0), func(t: Node) -> void:
		_spell_hit(t, a, amount * 2.0, "Ball Lightning"))
	var wr: WeakRef = weakref(p)
	for i in int(a.range / 7.0 / 0.4):
		get_tree().create_timer(0.2 + i * 0.4, false).timeout.connect(func() -> void:
			var pp := wr.get_ref() as Node3D
			if pp == null or not pp.is_inside_tree():
				return
			for t in _enemies_near(pp.global_position, a.radius):
				VFX.bolt(_parent(), PackedVector3Array([pp.global_position, (t as Node3D).global_position + Vector3(0, 1, 0)]), Color(0.8, 0.85, 1.0, 1.0), 0.15)
				_spell_hit(t, a, amount * 0.5, "Zap")
				_status(t, &"shocked", 1.5))
	return true


# --- Assassin (Milestone 17b) -------------------------------------------------------------------

## Smoke Bomb: enemies in the cloud lose you and are weakened.
func _ability_smoke_bomb(a: AbilityData) -> bool:
	VFX.burst(_parent(), player.global_position + Vector3(0, 0.8, 0), a.radius, Color(0.3, 0.3, 0.32, 0.7), 0.6)
	player.set_lock_target(null)
	var smoke := _zone(player.global_position, a.radius, a.duration, 0.5, Color(0.35, 0.35, 0.38), func(ts: Array[Node]) -> void:
		for t in ts:
			_blind(t, 1.0))
	smoke.add_to_group(&"smoke_zones")
	for t in _enemies_near(player.global_position, a.radius):
		_blind(t, a.duration)
	return true


## Death Mark: after `duration`, the target takes `power` of the damage you dealt it again.
func _ability_death_mark(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	mark(t, &"death", a.duration, a.power)
	Events.damage_dealt.emit(t.global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Marked")
	return true


## Throwing Knives: `power` knives in a fan.
func _ability_throwing_knives(a: AbilityData) -> bool:
	var dir := _aim_flight(a.range)
	player.model.play_attack(&"thrust", 0.04, 0.08, 0.2)
	var n := int(a.power)
	for i in n:
		var ang := (i - (n - 1) / 2.0) * 0.18
		_shoot(dir.rotated(Vector3.UP, ang), 30.0, a.range, Color(0.75, 0.75, 0.8), func(t: Node) -> void:
			_physical_hit(t, a.damage, 6.0, 1.0, "Knife"), &"arrow")
	return true


## Garrote: bleed and silence; x1.5 bleed from behind.
func _ability_garrote(a: AbilityData) -> bool:
	player.model.play_attack(&"thrust", 0.05, 0.08, 0.25)
	var hit := false
	for t in _front(a.radius, 80.0):
		var behind := t.has_method("get_facing") and (t.get_facing() as Vector3).dot(((t as Node3D).global_position - player.global_position).normalized()) > 0.4
		_physical_hit(t, a.damage, 8.0, 0.5, "Garrote")
		for k in (3 if behind else 2):
			_status(t, &"bleed", 6.0, {"dps": a.power, "source": player})
		_status(t, &"silenced", a.duration)
		hit = true
	return hit or true


## Caltrops: spikes at the cursor that slow and bleed enemies on them.
func _ability_caltrops(a: AbilityData) -> bool:
	_zone(cast_point(a.range), a.radius, a.duration, 0.5, Color(0.55, 0.55, 0.6), func(ts: Array[Node]) -> void:
		for t in ts:
			_status(t, &"slowed", 0.8)
			_status(t, &"bleed", 3.0, {"dps": a.damage, "source": player}))
	return true


## Evasion: dodge `power` of all hits for `duration`.
func _ability_evasion(a: AbilityData) -> bool:
	buff_powers[&"evasion"] = a.power
	add_buff(&"evasion", a.duration)
	player.model.set_ghost(true)
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		if not has_buff(&"stealth"):
			player.model.set_ghost(false))
	return true


## Fan of Knives: knives in every direction.
func _ability_fan_of_knives(a: AbilityData) -> bool:
	player.model.play_spin(0.35)
	for k in 12:
		var d := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0))
		VFX.bolt(_parent(), PackedVector3Array([player.global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0) + d * a.radius]), Color(0.8, 0.8, 0.85, 0.9), 0.15)
	for t in _enemies_near(player.global_position, a.radius):
		_physical_hit(t, a.damage, 8.0, 2.0, "Fan of Knives")
	return true


## Grappling Hook: pull yourself up to `range` m towards the cursor.
func _ability_grappling_hook(a: AbilityData) -> bool:
	var target := cast_point(a.range)
	var to := target - player.global_position
	to.y = 0.0
	if to.length() < 1.5:
		return false
	var dist := minf(to.length(), a.range)
	VFX.bolt(_parent(), PackedVector3Array([player.global_position + Vector3(0, 1.2, 0), target + Vector3(0, 0.5, 0)]), Color(0.5, 0.4, 0.3, 1.0), 0.3)
	player.start_ability_dash(to.normalized(), dist, 0.3, func(_t: Node) -> void: pass)
	return true


## Blind Powder: enemies in front lose you and are weakened for `duration`.
func _ability_blind_powder(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0) + dir * 1.5, 1.4, Color(0.85, 0.8, 0.6, 0.7))
	for t in _front(a.radius, 100.0):
		_blind(t, a.duration)
	return true


## Shadow Clone: a copy of you that enemies near it attack for `duration`.
func _ability_shadow_clone(a: AbilityData) -> bool:
	var decoy := Node3D.new()
	decoy.add_to_group(&"decoys")
	var m := HumanoidModel.new()
	decoy.add_child(m)
	m.set_appearance(player.character.class_data)
	m.set_body(player.look)
	var w := player.equipment.weapon()
	m.set_outfit(player.equipment.outfit_ids(), w.id if w else &"")
	m.set_weapon(player.equipment.weapon_type(), player.equipment.has_shield())
	_parent().add_child(decoy)
	decoy.global_position = player.global_position
	m.rotation.y = player.model.rotation.y
	m.set_ghost(true)
	for t in _enemies_near(player.global_position, a.radius):
		if t.has_method("lose_target"):
			t.lose_target(player)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(0.2, 0.15, 0.3, 0.7))
	get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
		if is_instance_valid(decoy):
			VFX.burst(decoy.get_parent(), decoy.global_position + Vector3(0, 1, 0), 1.2, Color(0.2, 0.15, 0.3, 0.7))
			decoy.queue_free())
	return true


## Twin Fangs: `power` quick hits on the enemies in front.
func _ability_twin_fangs(a: AbilityData) -> bool:
	for i in int(a.power):
		get_tree().create_timer(0.02 + i * 0.1, false).timeout.connect(func() -> void:
			if player.is_dead:
				return
			player.model.play_attack(&"slash_r" if i % 2 == 0 else &"slash_l", 0.02, 0.04, 0.06)
			for t in _enemies_in(a.radius, 90.0):
				_physical_hit(t, a.damage, 4.0, 0.5, "Twin Fangs"))
	return true


# --- Milestone 17c: helpers ----------------------------------------------------------------------

## A short hit sequence: `count` hits `gap` seconds apart, each calling `fn(i)`.
func _sequence(count: int, gap: float, fn: Callable) -> void:
	for i in count:
		get_tree().create_timer(0.02 + i * gap, false).timeout.connect(func() -> void:
			if not player.is_dead:
				fn.call(i))


## Enemies on a line from `start` along `dir` (length, half width).
func _on_line(start: Vector3, dir: Vector3, length: float, width: float) -> Array[Node]:
	var out: Array[Node] = []
	for t in _enemies_near(start, length + 1.0):
		var to := (t as Node3D).global_position - start
		to.y = 0.0
		var along := to.dot(dir)
		if along > 0.0 and along < length + 0.5 and (to - dir * along).length() < width:
			out.append(t)
	return out


## The best arrow in the bag is used up; false if there is none or no bow in hand.
func _use_arrow() -> bool:
	if not player.combat.is_ranged():
		Events.toast.emit("You need a bow", Color(1, 0.8, 0.5))
		return false
	var id := player.combat.best_arrow()
	if id == &"":
		Events.toast.emit("No arrows!", Color(1, 0.8, 0.5))
		return false
	if player.inventory.remote:
		Net.client.request("ammo", [String(id)])
	else:
		player.inventory.remove_item(id, 1)
	return true


## A wall that blocks the way (Ice Wall, Earth Wall).
func _wall(pos: Vector3, dir: Vector3, width: float, color: Color, duration: float, transparent: bool) -> StaticBody3D:
	if World.instance:
		pos.y = World.instance.get_ground_height(pos)
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.BUILDING
	wall.collision_mask = 0
	wall.add_to_group(&"ice_walls")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 2.2, 0.7)
	shape.shape = box
	shape.position.y = 1.1
	wall.add_child(shape)
	var b := BlockMesh.new()
	b.box(Vector3(0, 1.1, 0), Vector3(width, 2.2, 0.7), color)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.mesh.surface_set_material(0, Materials.vertex_color())
	if transparent:
		mi.transparency = 0.25
	wall.add_child(mi)
	_parent().add_child(wall)
	wall.global_position = pos
	wall.rotation.y = atan2(dir.x, dir.z)
	VFX.burst(_parent(), pos + Vector3(0, 1, 0), 2.0, Color(color.r, color.g, color.b, 0.7))
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if is_instance_valid(wall):
			VFX.debris(wall.get_parent(), wall.global_position + Vector3(0, 1, 0), color, 10, 4.0)
			wall.queue_free())
	return wall


## Copies of you that draw monsters (Shadow Clone, Mirror Image).
func _decoy(pos: Vector3, duration: float) -> Node3D:
	var decoy := Node3D.new()
	decoy.add_to_group(&"decoys")
	var m := HumanoidModel.new()
	decoy.add_child(m)
	m.set_appearance(player.character.class_data)
	m.set_body(player.look)
	var w := player.equipment.weapon()
	m.set_outfit(player.equipment.outfit_ids(), w.id if w else &"")
	m.set_weapon(player.equipment.weapon_type(), player.equipment.has_shield())
	_parent().add_child(decoy)
	decoy.global_position = pos
	m.rotation.y = player.model.rotation.y
	m.set_ghost(true)
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if is_instance_valid(decoy):
			VFX.burst(decoy.get_parent(), decoy.global_position + Vector3(0, 1, 0), 1.2, Color(0.4, 0.3, 0.6, 0.7))
			decoy.queue_free())
	return decoy


## Spawns a monster that fights for you for `seconds` (Spirit Wolf).
func _summon_pet(id: StringName, pos: Vector3, seconds: float) -> Monster:
	var w := World.instance
	if w == null or w.spawner == null:
		return null
	if w:
		pos.y = w.get_ground_height(pos) + 0.3
	var m := w.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", load("res://data/enemies/%s.tres" % id)) as Monster
	if m == null:
		return null
	var lvl := player.character.level
	m.configure(1.0 + lvl * 0.04, 1.0 + lvl * 0.03, maxi(1, lvl), 0)
	m.tame(seconds)
	m.set_meta(&"spirit", true)
	(m.model as Node3D).scale = Vector3.ONE
	for c in m.model.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).transparency = 0.45
	var wr: WeakRef = weakref(m)
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		var mm := wr.get_ref() as Monster
		if mm and not mm.is_dead and mm.has_meta(&"spirit"):
			VFX.burst(mm.get_parent(), mm.global_position + Vector3(0, 1, 0), 1.4, Color(0.6, 0.8, 1.0, 0.7))
			NodePool.release_or_free(mm))
	return m


# --- Barbarian (Milestone 17c) -------------------------------------------------------------------

func _ability_avalanche(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	player.face_direction(dir, true)
	_sequence(3, 0.3, func(i: int) -> void:
		player.global_position += dir * 1.2
		player.model.play_attack(&"overhead", 0.08, 0.08, 0.12)
		var c := player.global_position + dir * 1.5
		VFX.ring(_parent(), c, a.radius, Color(0.8, 0.7, 0.5, 0.8), 0.25)
		VFX.dust(_parent(), c, Color(0.6, 0.55, 0.5), 8)
		Events.camera_shake.emit(0.3)
		for t in _enemies_near(c, a.radius):
			_physical_hit(t, a.damage * (1.0 + 0.25 * i), 35.0, 5.0, "Avalanche"))
	return true


func _ability_tundra_howl(a: AbilityData) -> bool:
	buff_powers[&"tundra_howl"] = a.power
	add_buff(&"tundra_howl", a.duration)
	add_rage(20.0)
	VFX.ring(_parent(), player.global_position, 6.0, Color(0.7, 0.85, 1.0, 0.6), 0.5)
	return true


func _ability_rampage(a: AbilityData) -> bool:
	player.start_ability_dash(player.get_aim_direction(), a.range, 0.9, func(hit: Node) -> void:
		_physical_hit(hit, a.damage, 60.0, 9.0, "Rampage")
		if hit.has_method("stagger"):
			hit.stagger(a.duration))
	return true


func _ability_execute(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.1, 0.1, 0.3)
	var targets := _front(a.radius, 80.0)
	for t in targets:
		var low := float(t.health.get_ratio()) < 0.25 if t.get("health") else false
		_physical_hit(t, a.damage * (a.power if low else 1.0), 40.0, 4.0, "Execute" if low else "")
		if t.get("is_dead"):
			add_rage(a.cost)
	return true


func _ability_earthquake(a: AbilityData) -> bool:
	var dmg := a.damage * player.character.physical_mult
	_zone(player.global_position, a.radius, a.duration, 0.5, Color(0.6, 0.5, 0.35), func(ts: Array[Node]) -> void:
		Events.camera_shake.emit(0.15)
		for t in ts:
			var info := DamageInfo.create(dmg, player, &"physical")
			info.tag = "Quake"
			info.poise_damage = 12.0
			info.hit_position = (t as Node3D).global_position + Vector3(0, 1, 0)
			t.receive_hit(info)
			_status(t, &"slowed", 0.8))
	return true


func _ability_berserkers_wrath(a: AbilityData) -> bool:
	buff_powers[&"wrath"] = a.power
	add_buff(&"wrath", 20.0)
	return true


func _ability_chain_hook(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	VFX.bolt(_parent(), PackedVector3Array([player.global_position + Vector3(0, 1.2, 0), t.global_position + Vector3(0, 1, 0)]), Color(0.6, 0.6, 0.65, 1.0), 0.3)
	var to := t.global_position - player.global_position
	to.y = 0.0
	if to.length() > 1.8 and not (t.has_method("is_boss") and t.is_boss()):
		var dest := player.global_position + to.normalized() * 1.6
		if World.instance:
			dest.y = World.instance.get_ground_height(dest) + 0.2
		var tw := t.create_tween()
		tw.tween_property(t, "global_position", dest, 0.2)
	_physical_hit(t, a.damage, 20.0, 0.0, "Hooked")
	_status(t, &"stunned", a.duration)
	return true


func _ability_frost_rage(a: AbilityData) -> bool:
	add_buff(&"frost_rage", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.3, Color(0.6, 0.9, 1.0, 0.6))
	return true


func _ability_fire_rage(a: AbilityData) -> bool:
	add_buff(&"fire_rage", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.3, Color(1, 0.5, 0.2, 0.6))
	return true


func _ability_shatter_strike(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.1, 0.1, 0.3)
	for t in _front(a.radius, 80.0):
		var st = t.get("status")
		var cold: bool = st is StatusEffects and ((st as StatusEffects).has(&"frozen") or (st as StatusEffects).has(&"chilled"))
		_physical_hit(t, a.damage * (a.power if cold else 1.0), 40.0, 5.0, "Shatter!" if cold else "")
		if cold:
			(st as StatusEffects).remove(&"frozen")
			VFX.debris(_parent(), (t as Node3D).global_position + Vector3(0, 1, 0), Color(0.7, 0.9, 1.0), 10, 5.0)
	return true


func _ability_undying_rage(a: AbilityData) -> bool:
	add_buff(&"undying", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.8, Color(1, 0.15, 0.1, 0.7))
	return true


func _ability_primal_roar(a: AbilityData) -> bool:
	VFX.ring(_parent(), player.global_position, a.radius, Color(1, 0.4, 0.2, 0.7), 0.5)
	Events.camera_shake.emit(0.3)
	for t in _enemies_near(player.global_position, a.radius):
		var m := t as Monster
		if m and not m.is_boss():
			m._set_ai(Monster.AI.FLEE, a.duration)
		_status(t, &"weakened", a.duration)
	return true


func _ability_crushing_blow(a: AbilityData) -> bool:
	player.model.play_attack(&"overhead", 0.15, 0.1, 0.35)
	for t in _front(a.radius, 90.0):
		_physical_hit(t, a.damage, a.power, 6.0, "Crushing Blow")
	Events.camera_shake.emit(0.4)
	return true


# --- Knight (Milestone 17c) ----------------------------------------------------------------------

func _ability_oath_of_protection(a: AbilityData) -> bool:
	buff_powers[&"oath"] = a.power
	add_buff(&"oath", a.duration)
	VFX.ring(_parent(), player.global_position, 1.8, Color(0.6, 0.75, 1.0, 0.7), 0.5)
	return true


func _ability_smite(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	VFX.bolt(_parent(), PackedVector3Array([t.global_position + Vector3(0, 14, 0), t.global_position + Vector3(0, 1, 0)]), Color(1, 0.95, 0.6, 1.0), 0.3)
	var info := player.combat.build_physical(a.damage, t, 30.0, 2.0, 0.0, &"holy")
	info.tag = "Smite"
	var dealt = t.receive_hit(info)
	on_hit_dealt(t, float(dealt) if dealt != null else 0.0)
	_status(t, &"stunned", 0.5)
	return true


func _ability_shield_combo(a: AbilityData) -> bool:
	_sequence(3, 0.18, func(i: int) -> void:
		player.model.play_attack(&"thrust", 0.04, 0.06, 0.08)
		for t in _enemies_in(a.radius, 100.0):
			_physical_hit(t, a.damage * (1.5 if i == 2 else 1.0), 25.0, 10.0 if i == 2 else 1.5, "Shield"))
	return true


func _ability_banner_of_the_realm(a: AbilityData) -> bool:
	var pos := player.global_position
	var pole := Node3D.new()
	var b := BlockMesh.new()
	b.box(Vector3(0, 1.2, 0), Vector3(0.08, 2.4, 0.08), Color(0.45, 0.3, 0.18))
	b.box(Vector3(0.3, 2.0, 0), Vector3(0.6, 0.7, 0.04), Color(0.25, 0.4, 0.85))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.mesh.surface_set_material(0, Materials.vertex_color())
	pole.add_child(mi)
	_parent().add_child(pole)
	pole.global_position = pos
	var z := _zone(pos, a.radius, a.duration, 1.0, Color(0.3, 0.45, 0.9), func(_ts: Array[Node]) -> void:
		if player.global_position.distance_to(pos) <= a.radius:
			add_buff(&"banner", 1.2)
			player.health.heal(player.health.max_health * 0.01))
	z.tree_exited.connect(func() -> void:
		if is_instance_valid(pole):
			pole.queue_free())
	return true


func _ability_divine_shield(a: AbilityData) -> bool:
	add_buff(&"divine_shield", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 2.0, Color(1, 0.95, 0.6, 0.7))
	return true


func _ability_sweeping_blade(a: AbilityData) -> bool:
	player.model.play_spin(0.4)
	VFX.ring(_parent(), player.global_position, a.radius, Color(0.9, 0.9, 1.0, 0.7), 0.3)
	for t in _enemies_near(player.global_position, a.radius):
		_physical_hit(t, a.damage, 30.0, 9.0, "Sweep")
	return true


func _ability_holy_weapon(a: AbilityData) -> bool:
	add_buff(&"holy_weapon", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1.4, 0), 1.2, Color(1, 0.95, 0.6, 0.8))
	return true


func _ability_hold_the_line(a: AbilityData) -> bool:
	add_buff(&"hold_line", a.duration)
	VFX.ring(_parent(), player.global_position, 1.8, Color(0.6, 0.75, 1.0, 0.8), 0.6)
	return true


func _ability_hammer_of_justice(a: AbilityData) -> bool:
	_shoot(_aim_flight(a.range), 24.0, a.range, Color(1, 0.95, 0.6), func(t: Node) -> void:
		var info := player.combat.build_physical(a.damage, t, 40.0, 3.0, 0.0, &"holy")
		info.tag = "Justice"
		t.receive_hit(info)
		_status(t, &"stunned", a.duration))
	return true


func _ability_aegis(a: AbilityData) -> bool:
	add_buff(&"aegis", a.duration)
	_zone(player.global_position, a.radius, a.duration, 0.6, Color(1, 0.95, 0.6), func(_ts: Array[Node]) -> void: pass).follow = player
	return true


func _ability_crusader_strike(a: AbilityData) -> bool:
	player.model.play_attack(&"slash_r", 0.08, 0.1, 0.25)
	var total := 0.0
	for t in _front(a.radius, 100.0):
		total += _physical_hit(t, a.damage, 25.0, 4.0, "Crusader")
	if total > 0.0:
		player.health.heal(total * a.power)
	return true


# --- Wizard (Milestone 17c) ----------------------------------------------------------------------

func _ability_flame_pillar(a: AbilityData) -> bool:
	var pos := cast_point(a.range)
	var amount := _spell_damage(a)
	for i in 5:
		VFX.burst(_parent(), pos + Vector3(0, 0.5 + i * 0.7, 0), 1.2 - i * 0.12, Color(1, 0.5 - i * 0.05, 0.15, 0.8))
	for t in _enemies_near(pos, a.radius):
		_spell_hit(t, a, amount, "Flame Pillar")
		_status(t, &"burn", 3.0, {"dps": amount * 0.1, "source": player})
		if t.has_method("stagger"):
			t.stagger(a.duration)
	ignite_clouds(pos, a.radius, amount * 2.0)
	return true


func _ability_glacial_spike(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	_shoot(_aim_flight(a.range), 20.0, a.range, Color(0.6, 0.9, 1.0), func(t: Node) -> void:
		_spell_hit(t, a, amount, "Glacial Spike")
		_status(t, &"frozen", a.duration))
	return true


func _ability_mana_siphon(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	var dealt := _spell_hit(t, a, _spell_damage(a), "Siphon")
	VFX.bolt(_parent(), PackedVector3Array([t.global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1.2, 0)]), Color(0.5, 0.5, 1.0, 1.0), 0.4)
	player.mana.restore(maxf(dealt, a.damage) * a.power)
	player.health.heal(maxf(dealt, a.damage) * 0.3)
	return true


func _ability_elemental_weakness(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	mark(t, &"judgement", a.duration, a.power)
	Events.damage_dealt.emit(t.global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Weakened")
	return true


func _ability_comet_shower(a: AbilityData) -> bool:
	var center := cast_point(a.range)
	var amount := _spell_damage(a)
	for i in int(a.power):
		var off := Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		var h := _player_hazard(center + off, a, a.radius, 0.5 + i * 0.15, amount)
		h.style = &"meteor"
		h.status_effect = [&"burn", 3.0, {"dps": amount * 0.08, "source": player}]
	return true


func _ability_frozen_orb(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var p := _shoot(_aim_flight(a.range), 8.0, a.range, Color(0.6, 0.9, 1.0), func(t: Node) -> void:
		_spell_hit(t, a, amount * 2.0, "Frozen Orb"))
	var wr: WeakRef = weakref(p)
	for i in int(a.range / 8.0 / 0.35):
		get_tree().create_timer(0.15 + i * 0.35, false).timeout.connect(func() -> void:
			var pp := wr.get_ref() as Node3D
			if pp == null or not pp.is_inside_tree():
				return
			for t in _enemies_near(pp.global_position, a.radius):
				VFX.bolt(_parent(), PackedVector3Array([pp.global_position, (t as Node3D).global_position + Vector3(0, 1, 0)]), Color(0.7, 0.9, 1.0, 1.0), 0.15)
				_spell_hit(t, a, amount, "Ice Shard")
				_status(t, &"chilled", 2.0))
	return true


func _ability_lightning_rod(a: AbilityData) -> bool:
	var pos := cast_point(a.range)
	var amount := _spell_damage(a)
	var rod := MeshInstance3D.new()
	var b := BlockMesh.new()
	b.box(Vector3(0, 1.0, 0), Vector3(0.12, 2.0, 0.12), Color(0.6, 0.6, 0.7))
	b.box(Vector3(0, 2.1, 0), Vector3(0.25, 0.25, 0.25), Color(0.8, 0.85, 1.0))
	rod.mesh = b.commit()
	rod.mesh.surface_set_material(0, Materials.vertex_color_emissive())
	var z := _zone(pos, a.radius, a.duration, 1.0, Color(0.8, 0.85, 1.0), func(ts: Array[Node]) -> void:
		for t in ts:
			VFX.bolt(_parent(), PackedVector3Array([rod.global_position + Vector3(0, 2.1, 0), (t as Node3D).global_position + Vector3(0, 1, 0)]), Color(0.8, 0.85, 1.0, 1.0), 0.2)
			_spell_hit(t, a, amount, "Lightning Rod")
			_status(t, &"shocked", 2.0))
	z.add_child(rod)
	return true


func _ability_phoenix_flame(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	player.face_direction(dir, true)
	var start := player.global_position
	var amount := _spell_damage(a)
	_sequence(8, 0.06, func(i: int) -> void:
		VFX.burst(_parent(), start + Vector3(0, 1.2, 0) + dir * (1.5 + i * a.range / 8.0), 1.0, Color(1, 0.55, 0.15, 0.85)))
	for t in _on_line(start, dir, a.range, a.radius):
		_spell_hit(t, a, amount, "Phoenix")
		_status(t, &"burn", a.duration, {"dps": a.power * player.character.spell_mult, "source": player})
	ignite_clouds(start + dir * a.range * 0.5, a.range * 0.5, amount * 2.0)
	return true


func _ability_absolute_zero(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	VFX.ring(_parent(), player.global_position, a.radius, Color(0.6, 0.9, 1.0, 0.9), 0.5)
	for t in _enemies_near(player.global_position, a.radius):
		_spell_hit(t, a, amount, "Absolute Zero")
		_status(t, &"frozen", a.duration)
	return true


func _ability_overload(a: AbilityData) -> bool:
	add_buff(&"overload", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1.2, 0), 1.4, Color(0.75, 0.45, 1.0, 0.8))
	return true


func _ability_mirror_image(a: AbilityData) -> bool:
	var side := Vector3(-player.get_facing().z, 0, player.get_facing().x)
	for i in int(a.power):
		_decoy(player.global_position + side * (2.0 if i == 0 else -2.0), a.duration)
	for t in _enemies_near(player.global_position, a.radius):
		if t.has_method("lose_target"):
			t.lose_target(player)
	return true


func _ability_fire_tornado(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	var amount := _spell_damage(a)
	var z := _zone(player.global_position + dir * 1.5, a.radius, a.duration, 0.4, Color(1, 0.45, 0.1), func(ts: Array[Node]) -> void:
		for t in ts:
			_spell_hit(t, a, amount * 0.5, "Fire Tornado")
			_status(t, &"burn", 3.0, {"dps": amount * 0.1, "source": player}))
	z.velocity = dir * (a.range / a.duration)
	return true


func _ability_arcane_explosion(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), a.radius, Color(0.75, 0.45, 1.0, 0.7))
	for t in _enemies_near(player.global_position, a.radius):
		var info := DamageInfo.create(amount * target_mult(t), player, &"arcane")
		var to := (t as Node3D).global_position - player.global_position
		to.y = 0.0
		info.direction = to.normalized()
		info.knockback = info.direction * 10.0
		info.poise_damage = 30.0
		info.tag = "Arcane Explosion"
		info.hit_position = (t as Node3D).global_position + Vector3(0, 1, 0)
		t.receive_hit(info)
	return true


# --- Assassin (Milestone 17c) --------------------------------------------------------------------

func _ability_paralytic_poison(a: AbilityData) -> bool:
	buff_powers[&"paralytic_hits"] = 0.0
	add_buff(&"paralytic", a.duration)
	return true


func _ability_rapid_shot(a: AbilityData) -> bool:
	if not player.combat.is_ranged() or player.combat.best_arrow() == &"":
		_use_arrow()  # explains why
		return false
	var dir := _aim_flight(a.range)
	_sequence(int(a.power), 0.1, func(_i: int) -> void:
		if not _use_arrow():
			return
		player.model.play_attack(&"aim", 0.04, 0.04, 0.05)
		_shoot(dir.rotated(Vector3.UP, randf_range(-0.05, 0.05)), 36.0, a.range, Color(0.75, 0.75, 0.8), func(t: Node) -> void:
			_physical_hit(t, a.damage + float(player.equipment.weapon().stat_bonuses.get(&"damage_bonus", 0.0)) * 0.3, 6.0, 1.0, "Rapid Shot"), &"arrow"))
	return true


func _ability_shadow_dance(a: AbilityData) -> bool:
	add_buff(&"shadow_dance", a.duration)
	add_buff(&"stealth", a.duration)
	player.model.set_ghost(true)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.has_method("lose_target"):
			e.lose_target(player)
	return true


func _ability_kidney_shot(a: AbilityData) -> bool:
	player.model.play_attack(&"thrust", 0.05, 0.08, 0.2)
	for t in _front(a.radius, 80.0):
		var behind := t.has_method("get_facing") and (t.get_facing() as Vector3).dot(((t as Node3D).global_position - player.global_position).normalized()) > 0.4
		_physical_hit(t, a.damage, 20.0, 1.0, "Kidney Shot")
		_status(t, &"stunned", a.duration if behind else a.duration * 0.5)
	return true


func _ability_explosive_trap(a: AbilityData) -> bool:
	var dmg := a.damage * player.character.physical_mult
	var z: AbilityZone = null
	z = _zone(player.global_position, 1.6, a.duration, 0.15, Color(1, 0.4, 0.1), func(ts: Array[Node]) -> void:
		if ts.is_empty() or not is_instance_valid(z) or z.is_queued_for_deletion():
			return
		var c := z.global_position
		VFX.burst(_parent(), c + Vector3(0, 0.6, 0), a.radius, Color(1, 0.5, 0.15, 0.85))
		Audio.play_at(&"explosion", c, -4.0)
		for t in _enemies_near(c, a.radius):
			var info := DamageInfo.create(dmg * target_mult(t), player, &"fire")
			info.tag = "Trap!"
			info.poise_damage = 40.0
			info.hit_position = (t as Node3D).global_position + Vector3(0, 1, 0)
			t.receive_hit(info)
		z.queue_free())
	return true


func _ability_assassinate(a: AbilityData) -> bool:
	player.model.play_attack(&"thrust", 0.08, 0.1, 0.3)
	var hidden := has_buff(&"stealth")
	for t in _front(a.radius, 80.0):
		var boss: bool = t.has_method("is_boss") and t.is_boss()
		var low := float(t.health.get_ratio()) < 0.3 if t.get("health") else false
		if hidden and low and not boss:
			var info := DamageInfo.create(99999.0, player, &"true")
			info.tag = "Assassinated"
			info.hit_position = (t as Node3D).global_position + Vector3(0, 1.4, 0)
			t.receive_hit(info)
		else:
			_physical_hit(t, a.damage * a.power, 30.0, 2.0, "Assassinate")
	return true


func _ability_toxic_burst(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	var st := t.get("status") as StatusEffects
	var extra := 0.0
	if st and st.has(&"poison"):
		extra = float(st.effects[&"poison"].dps) * st.stacks(&"poison") * st.time_left(&"poison")
		st.remove(&"poison")
	var info := DamageInfo.create((a.damage + extra) * target_mult(t), player, &"poison")
	info.tag = "Toxic Burst"
	info.hit_position = t.global_position + Vector3(0, 1.2, 0)
	t.receive_hit(info)
	VFX.burst(_parent(), info.hit_position, 1.4, Color(0.5, 0.9, 0.3, 0.8))
	return true


func _ability_blade_chain(a: AbilityData) -> bool:
	var targets := _enemies_near(player.global_position, a.radius)
	if targets.is_empty():
		Events.toast.emit("No enemies near you", Color(1, 0.8, 0.5))
		return false
	targets.sort_custom(func(x: Node, y: Node) -> bool:
		return (x as Node3D).global_position.distance_to(player.global_position) < (y as Node3D).global_position.distance_to(player.global_position))
	var list := targets.slice(0, int(a.power))
	_sequence(list.size(), 0.12, func(i: int) -> void:
		var t := list[i] as Node3D
		if not is_instance_valid(t) or t.get("is_dead"):
			return
		var from := player.global_position
		var dest: Vector3 = t.global_position - (t.get_facing() as Vector3) * 1.0 if t.has_method("get_facing") else t.global_position
		dest.y = t.global_position.y + 0.1
		VFX.bolt(_parent(), PackedVector3Array([from + Vector3(0, 1, 0), dest + Vector3(0, 1, 0)]), Color(0.4, 0.3, 0.6, 1.0), 0.15)
		player.global_position = dest
		player.face_direction(t.global_position - dest, true)
		player.model.play_attack(&"slash_r", 0.02, 0.05, 0.05)
		_physical_hit(t, a.damage, 15.0, 1.0, "Blade Chain"))
	return true


func _ability_cloak_of_shadows(a: AbilityData) -> bool:
	player.status.cleanse()
	add_buff(&"cloak", a.duration)
	player.model.set_ghost(true)
	get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
		if not has_buff(&"stealth"):
			player.model.set_ghost(false))
	return true


func _ability_hemorrhage(a: AbilityData) -> bool:
	player.model.play_attack(&"slash_l", 0.06, 0.08, 0.25)
	for t in _front(a.radius, 80.0):
		var st = t.get("status")
		var poisoned: bool = st is StatusEffects and (st as StatusEffects).has(&"poison")
		_physical_hit(t, a.damage * (2.0 if poisoned else 1.0), 10.0, 1.0, "Hemorrhage")
		for k in 4:
			_status(t, &"bleed", 8.0, {"dps": a.power * (2.0 if poisoned else 1.0), "source": player})
	return true


func _ability_sniper_shot(a: AbilityData) -> bool:
	if not _use_arrow():
		return false
	player.model.play_attack(&"aim", 0.3, 0.05, 0.2)
	var dmg := a.damage + float(player.equipment.weapon().stat_bonuses.get(&"damage_bonus", 0.0))
	_shoot(_aim_flight(a.range), 60.0, a.range, Color(0.9, 0.9, 0.95), func(t: Node) -> void:
		var info := player.combat.build_physical(dmg, t, 30.0, 3.0, 0.0, &"physical", {"crit": true, "tag": "Sniper Shot"})
		var dealt = t.receive_hit(info)
		on_hit_dealt(t, float(dealt) if dealt != null else 0.0), &"arrow")
	return true


# --- Shared spells (Milestone 17c) ----------------------------------------------------------------

func _spell_light(a: AbilityData) -> bool:
	if is_instance_valid(_light_node):
		_light_node.queue_free()
	_light_node = OmniLight3D.new()
	_light_node.light_color = Color(1, 0.92, 0.7)
	_light_node.light_energy = 1.6
	_light_node.omni_range = 12.0
	_light_node.position = Vector3(0.6, 2.6, 0.4)
	player.add_child(_light_node)
	add_buff(&"light", a.duration)
	return true


func _spell_haste(a: AbilityData) -> bool:
	add_buff(&"haste_spell", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 0.5, 0), 1.0, Color(1, 0.9, 0.4, 0.6))
	return true


func _spell_gust(a: AbilityData) -> bool:
	var dir := player.get_aim_direction()
	for i in 4:
		VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0) + dir * (1.5 + i * 1.2), 0.8, Color(0.85, 0.95, 1.0, 0.5))
	for t in _front(a.radius, 90.0):
		var info := DamageInfo.create(_spell_damage(a) * target_mult(t), player, &"physical")
		info.direction = dir
		info.knockback = dir * 14.0
		info.poise_damage = 25.0
		info.tag = "Gust"
		info.hit_position = (t as Node3D).global_position + Vector3(0, 1, 0)
		t.receive_hit(info)
		var st = t.get("status")
		if st is StatusEffects:
			(st as StatusEffects).remove(&"burn")
	player.status.remove(&"burn")
	# Gust into Miasma spreads the cloud.
	for c in get_tree().get_nodes_in_group(&"poison_clouds"):
		var h := c as GroundHazard
		if h and h.global_position.distance_to(player.global_position + dir * a.radius * 0.5) < a.radius:
			h.radius *= 1.5
			h.global_position += dir * 2.0
	return true


func _spell_root_snare(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	_status(t, &"stunned", a.duration)
	VFX.debris(_parent(), t.global_position + Vector3(0, 0.3, 0), Color(0.35, 0.6, 0.25), 10, 2.0)
	Events.damage_dealt.emit(t.global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Rooted")
	return true


func _spell_stone_skin(a: AbilityData) -> bool:
	buff_powers[&"stone_skin"] = a.power
	add_buff(&"stone_skin", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(0.65, 0.6, 0.55, 0.7))
	return true


func _spell_rejuvenate(a: AbilityData) -> bool:
	player.afflict(&"regen", a.duration, {"hps": player.health.max_health * a.power / 100.0 / a.duration})
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.4, Color(0.4, 1, 0.5, 0.6))
	return true


func _spell_feather_fall(a: AbilityData) -> bool:
	add_buff(&"feather_fall", a.duration)
	return true


func _spell_frost_path(a: AbilityData) -> bool:
	var w := World.instance
	if w == null:
		return false
	var dir := player.get_aim_direction()
	var made := 0
	for i in int(a.range):
		var pos := player.global_position + dir * (1.0 + i)
		if not w.is_in_water(Vector3(pos.x, TerrainGenerator.WATER_Y - 0.3, pos.z)):
			continue
		var ice := StaticBody3D.new()
		ice.collision_layer = Layers.TERRAIN
		ice.collision_mask = 0
		ice.add_to_group(&"ice_paths")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 0.3, 1.6)
		cs.shape = box
		ice.add_child(cs)
		var b := BlockMesh.new()
		b.box(Vector3.ZERO, Vector3(1.6, 0.3, 1.6), Color(0.75, 0.92, 1.0))
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit()
		mi.mesh.surface_set_material(0, Materials.vertex_color())
		ice.add_child(mi)
		_parent().add_child(ice)
		ice.global_position = Vector3(pos.x, TerrainGenerator.WATER_Y + 0.05, pos.z)
		made += 1
		get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
			if is_instance_valid(ice):
				ice.queue_free())
	if made == 0:
		Events.toast.emit("No water in front of you", Color(1, 0.8, 0.5))
		return false
	return true


func _spell_earth_spike(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	VFX.debris(_parent(), t.global_position + Vector3(0, 0.5, 0), Color(0.6, 0.5, 0.4), 12, 6.0)
	_spell_hit(t, a, _spell_damage(a), "Earth Spike")
	if t.has_method("stagger"):
		t.stagger(a.duration)
	return true


func _spell_spark_shield(a: AbilityData) -> bool:
	add_buff(&"spark_shield", a.duration)
	VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.5, Color(0.8, 0.85, 1.0, 0.7))
	return true


func _spell_detect_treasure(a: AbilityData) -> bool:
	var n := 0
	for c in get_tree().get_nodes_in_group(&"loot_chests"):
		var chest := c as Node3D
		if chest == null or chest.get("opened") or chest.global_position.distance_to(player.global_position) > a.radius:
			continue
		var beam := MeshInstance3D.new()
		var b := BlockMesh.new()
		b.box(Vector3(0, 6, 0), Vector3(0.25, 12, 0.25), Color(1, 0.85, 0.3))
		beam.mesh = b.commit()
		beam.mesh.surface_set_material(0, Materials.vertex_color_emissive())
		beam.transparency = 0.4
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.add_to_group(&"treasure_beams")
		chest.add_child(beam)
		n += 1
		get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
			if is_instance_valid(beam):
				beam.queue_free())
	Events.toast.emit("%d treasure%s nearby" % [n, "" if n == 1 else "s"] if n > 0 else "No treasure nearby", Color(1, 0.85, 0.3))
	return true


func _spell_tame_beast(a: AbilityData) -> bool:
	var t := _aim_target(a.range) as Monster
	if t == null:
		Events.toast.emit("No animal in range", Color(1, 0.8, 0.5))
		return false
	if t.is_boss() or t.mdata.style == MonsterData.Style.RANGED or not (t.mdata.look in [&"wolf", &"boar", &"deer", &"rabbit", &"frost_wolf", &"crab"] or String(t.mdata.id) in ["frost_wolf", "deer", "rabbit", "shore_crab", "thornback_boar"]):
		Events.toast.emit("Only wild animals can be tamed", Color(1, 0.8, 0.5))
		return false
	t.tame(a.duration)
	t.status.cleanse()
	VFX.burst(_parent(), t.global_position + Vector3(0, 1, 0), 1.4, Color(0.6, 0.85, 0.4, 0.8))
	Events.damage_dealt.emit(t.global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Tamed!")
	return true


func _spell_summon_spirit_wolf(a: AbilityData) -> bool:
	var m := _summon_pet(&"frost_wolf", player.global_position + player.get_facing() * 1.5, a.duration)
	if m == null:
		return false
	m.add_to_group(&"decoys")
	VFX.burst(_parent(), m.global_position + Vector3(0, 1, 0), 1.6, Color(0.6, 0.8, 1.0, 0.8))
	return true


func _spell_fire_ring(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	_zone(player.global_position, a.radius, a.duration, 0.5, Color(1, 0.45, 0.1), func(ts: Array[Node]) -> void:
		for t in ts:
			_spell_hit(t, a, amount * 0.35, "Fire Ring")
			_status(t, &"burn", 2.0, {"dps": amount * 0.1, "source": player})).follow = player
	return true


func _spell_lightning_dash(a: AbilityData) -> bool:
	var amount := _spell_damage(a)
	var from := player.global_position
	player.start_ability_dash(player.get_aim_direction(), a.range, 0.22, func(hit: Node) -> void:
		_spell_hit(hit, a, amount, "Lightning Dash")
		_status(hit, &"shocked", 3.0))
	VFX.bolt(_parent(), PackedVector3Array([from + Vector3(0, 1, 0), from + player.get_aim_direction() * a.range + Vector3(0, 1, 0)]), Color(0.8, 0.85, 1.0, 1.0), 0.3)
	return true


func _spell_drain_life(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	var amount := _spell_damage(a)
	var wr: WeakRef = weakref(t)
	_sequence(int(a.duration / 0.5), 0.5, func(_i: int) -> void:
		var tt := wr.get_ref() as Node3D
		if tt == null or tt.get("is_dead") or tt.global_position.distance_to(player.global_position) > a.range + 2.0:
			return
		VFX.bolt(_parent(), PackedVector3Array([tt.global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1.2, 0)]), Color(0.7, 0.2, 0.4, 1.0), 0.3)
		var dealt := _spell_hit(tt, a, amount, "Drain")
		player.health.heal(maxf(dealt, amount) * a.power))
	return true


func _spell_earth_wall(a: AbilityData) -> bool:
	_wall(cast_point(a.range), player.get_aim_direction(), a.power, Color(0.55, 0.48, 0.38), a.duration, false)
	return true


func _spell_silence(a: AbilityData) -> bool:
	var t := _aim_target(a.range)
	if t == null:
		Events.toast.emit("No target in range", Color(1, 0.8, 0.5))
		return false
	_status(t, &"silenced", a.duration)
	Events.damage_dealt.emit(t.global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Silenced")
	return true


func _spell_recall(a: AbilityData) -> bool:
	var start := player.global_position
	Events.toast.emit("Recalling home... stay still", Color(0.75, 0.6, 1.0))
	get_tree().create_timer(a.duration, false).timeout.connect(func() -> void:
		if player.is_dead or player.global_position.distance_to(start) > 1.5:
			Events.toast.emit("Recall interrupted", Color(1, 0.7, 0.5))
			return
		var home := player.spawn_point if player.spawn_point != Vector3.ZERO else start
		VFX.burst(_parent(), player.global_position + Vector3(0, 1, 0), 1.6, Color(0.75, 0.6, 1.0, 0.8))
		player.global_position = home + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		VFX.burst(_parent(), home + Vector3(0, 1, 0), 1.6, Color(0.75, 0.6, 1.0, 0.8))
		Events.toast.emit("You are home", Color(0.75, 0.6, 1.0)))
	return true


func _spell_shardfall(a: AbilityData) -> bool:
	var pos := cast_point(a.range)
	var h := _player_hazard(pos, a, a.radius, 1.0, _spell_damage(a))
	h.style = &"meteor"
	h.status_effect = [&"burn", 4.0, {"dps": _spell_damage(a) * 0.05, "source": player}]
	get_tree().create_timer(1.05, false).timeout.connect(func() -> void:
		if World.instance:
			World.instance.spawn_pickup(&"crystal_shard", randi_range(1, 2), pos + Vector3(0, 1, 0)))
	return true


# --- Save / load --------------------------------------------------------------------------

func to_save() -> Dictionary:
	_ensure_bar()
	return {"rage": rage, "shield": buff_time(&"temperature_shield"), "bar": bar.map(func(x: StringName) -> String: return String(x))}


func from_save(data: Dictionary) -> void:
	set_rage(float(data.get("rage", 0.0)))
	var saved: Array = data.get("bar", [])
	if saved.size() == SLOTS:
		bar.clear()
		for x in saved:
			var id := StringName(String(x))
			bar.append(id if id == &"" or AbilityBook.get_ability(id) != null else &"")
	else:
		bar = default_bar()  # saves from before Milestone 17b
	_known_level = player.character.level
	fill_bar()
	bar_changed.emit()
	var shield := float(data.get("shield", 0.0))
	if shield > 0.0:
		add_buff(&"temperature_shield", shield)
		player.character.ability_insulation = shield_ability().power
		player.character.ability_cooling = shield_ability().power
		player.character.recalculate()
