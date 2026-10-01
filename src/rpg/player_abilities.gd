class_name PlayerAbilities
extends Node
## Class abilities (3 per class, unlocked by level) + the universal Magic
## Temperature Shield, plus the Barbarian's Rage resource and ability buffs.
##
## Slots: 0-2 = class abilities (keys Z / X / C), 3 = Temperature Shield (T).
## Tuning lives in AbilityData resources; behaviour in _ability_<effect>().

signal cooldowns_changed
signal rage_changed(value: float)
signal buffs_changed

const SHIELD_ABILITY := preload("res://data/abilities/temperature_shield.tres")
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


func class_abilities() -> Array:
	var c := player.character.class_data
	return c.abilities if c else []


func get_slot(slot: int) -> AbilityData:
	if slot == 3:
		return SHIELD_ABILITY
	var list := class_abilities()
	return list[slot] if slot >= 0 and slot < list.size() else null


func is_unlocked(a: AbilityData) -> bool:
	if a == null:
		return false
	if a == SHIELD_ABILITY:
		return player.character.can_use_temperature_shield()
	return player.character.level >= a.unlock_level


func lock_reason(a: AbilityData) -> String:
	if a == SHIELD_ABILITY and not is_unlocked(a):
		return "Needs Mana Control %d" % player.character.class_data.temperature_shield_requirement()
	if a and player.character.level < a.unlock_level:
		return "Unlocks at level %d" % a.unlock_level
	return ""


func cooldown_left(a: AbilityData) -> float:
	return float(cooldowns.get(a.id, 0.0))


func effective_cost(a: AbilityData) -> float:
	if a == SHIELD_ABILITY:
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
		Events.toast.emit("Not enough %s" % ("mana" if a == SHIELD_ABILITY else a.cost_name()), Color(1, 0.8, 0.5))
		return false
	var fn := "_ability_%s" % a.effect
	if not has_method(fn) or not call(fn, a):
		return false
	_pay(a, cost)
	cooldowns[a.id] = a.cooldown * Skill.cooldown_mult(player.character.skill_level(Skill.MANA_CONTROL))
	cooldowns_changed.emit()
	Events.ability_used.emit(a.id)
	return true


func _can_pay(a: AbilityData, cost: float) -> bool:
	if a == SHIELD_ABILITY:
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
	if a == SHIELD_ABILITY:
		player.mana.try_spend(cost)
		return
	match a.cost_type:
		AbilityData.CostType.MANA:
			player.mana.try_spend(cost)
		AbilityData.CostType.STAMINA:
			player.stamina.consume(cost, false)
		AbilityData.CostType.RAGE:
			pass  # rage abilities consume rage themselves


func _process(delta: float) -> void:
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
	return m * player.status.outgoing_mult()


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
	return m


func is_stealthed() -> bool:
	return has_buff(&"stealth")


## Called by PlayerCombat before building a hit. Returns bonus tags/mults.
func consume_attack_bonus() -> Dictionary:
	var out := {"mult": 1.0, "crit": false, "tag": ""}
	if has_buff(&"stealth"):
		out.mult = 2.0
		out.tag = "Ambush"
		remove_buff(&"stealth")
	if has_buff(&"ambush"):
		out.crit = true
		remove_buff(&"ambush")
	return out


## Called after a player hit landed on an enemy.
func on_hit_dealt(target: Node, dealt: float) -> void:
	add_rage(8.0)
	if has_buff(&"berserk") and dealt > 0.0:
		player.health.heal(dealt * 0.1)
	if has_buff(&"poison_blade") and target.has_method("apply_status"):
		var a := _find(&"poison_blade")
		target.apply_status(&"poison", a.duration if a else 5.0, {"dps": a.damage if a else 3.0, "source": player})


func on_damage_taken(dealt: float) -> void:
	add_rage(dealt * 0.8)
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
	return a.damage * m * player.stats.get_mult(Stats.ATTACK_DAMAGE) * player.status.outgoing_mult()


func _spell_hit(target: Node, a: AbilityData, amount: float, tag: String = "") -> float:
	var info := DamageInfo.create(amount, player, a.damage_type)
	var dir := (target as Node3D).global_position - player.global_position
	dir.y = 0.0
	info.direction = dir.normalized()
	info.hit_position = (target as Node3D).global_position + Vector3(0, 1.2, 0)
	info.tag = tag
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
	var has_shield := player.equipment.offhand() != null
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
	for jump in int(a.power) + 1:
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
# Learned from tomes (SpellBook), cast from the two spell slots (Y / H). Any
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
		Events.toast.emit("Spell slot %d is empty. Learn spells from tomes (spellbook: L)" % (slot + 1), Color(0.85, 0.8, 1.0))
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
	if not has_method(fn) or not call(fn, a):
		return false
	player.mana.try_spend(effective_cost(a))
	cooldowns[a.id] = a.cooldown * Skill.cooldown_mult(player.character.skill_level(Skill.MANA_CONTROL))
	cooldowns_changed.emit()
	Events.ability_used.emit(a.id)
	return true


## Absorbs damage with the Arcane Barrier. Returns what gets through.
func absorb(amount: float) -> float:
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


# --- Save / load --------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"rage": rage, "shield": buff_time(&"temperature_shield")}


func from_save(data: Dictionary) -> void:
	set_rage(float(data.get("rage", 0.0)))
	var shield := float(data.get("shield", 0.0))
	if shield > 0.0:
		add_buff(&"temperature_shield", shield)
		player.character.ability_insulation = SHIELD_ABILITY.power
		player.character.ability_cooling = SHIELD_ABILITY.power
		player.character.recalculate()
