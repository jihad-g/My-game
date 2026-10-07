class_name PlayerCombat
extends Node
## Player melee combat: light combo chain, heavy attack, input buffering,
## crits and positional (backstab) bonuses.
##
## Attack timing comes from AttackData resources so each future class/weapon
## can define its own move set without code changes.
##
## Milestone 17a (Heroes' Arsenal) adds:
## - charged heavy attacks (hold the heavy button: up to +75% damage, +100% poise),
## - sprint attacks (attack out of a sprint: a long lunge),
## - plunging attacks (attack while falling: a slam on landing, stronger the higher you fell),
## - ripostes (attack within RIPOSTE_WINDOW after a perfect parry: x2.5, always a crit),
## - bows (hold to draw, release to shoot an arrow; uses the best arrows you carry),
## - weapon specials and legendary powers from ItemData.weapon_params.

signal attack_started(attack: AttackData)
signal attack_finished

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

const SPRINT_ATTACK := preload("res://data/attacks/sprint_lunge.tres")
const RIPOSTE_ATTACK := preload("res://data/attacks/riposte.tres")
const PLUNGE_ATTACK := preload("res://data/attacks/plunge.tres")
## Seconds after a perfect parry in which a light attack becomes a riposte.
const RIPOSTE_WINDOW := 1.6
const RIPOSTE_MULT := 2.5
## Charged heavy: damage and poise at full charge.
const CHARGE_DAMAGE := 0.75
const CHARGE_POISE := 1.0
const CHARGE_STAMINA_PER_SECOND := 12.0
## A full charge can be held this many seconds longer before it swings by itself.
const CHARGE_HOLD_MAX := 1.5
## Plunging attack: radius and damage per m/s of fall speed.
const PLUNGE_RADIUS := 2.8
const PLUNGE_PER_SPEED := 0.08
const PLUNGE_MIN_FALL := 4.0
## Bows.
const ARROW_SPEED := 34.0
const DEFAULT_BOW_RANGE := 30.0
const MIN_DRAW := 0.2
## Falling star (Starfall weapons).
const STAR_RADIUS := 3.2
const STAR_DAMAGE := 45.0

@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Time after an attack ends in which the next light attack continues the combo.
@export var combo_window: float = 0.5
@export var buffer_time: float = 0.35

var player: Player
var current: AttackData
var phase: Phase = Phase.NONE
var phase_time := 0.0
var combo_index := 0
var attack_direction := Vector3.FORWARD
var moveset: WeaponMoveset

## Tests: StringName kind -> bool, replaces Input for "is the button held".
var held_override: Dictionary = {}
## Seconds left in which a light attack is a riposte.
var riposte_left := 0.0
## True while falling with a plunging attack ready.
var plunging := false
## Charge of the last heavy attack (0..1) and the draw of the last shot (0..1).
var last_charge := 0.0
var last_draw := 0.0
## Hits and shots counted for "every Nth" weapon powers.
var special_counter := 0

var _buffered: StringName = &""
var _buffer_left := 0.0
var _combo_timer := 0.0
var _rng := RandomNumberGenerator.new()
## The current attack waits at the end of its windup while its button is held.
var _holding := false
var _hold_kind: StringName = &""
var _charge_time := 0.0
var _charged_announced := false
var _bonus := {}
var _is_last_of_combo := false


func _ready() -> void:
	_rng.randomize()
	Events.enemy_killed.connect(_on_enemy_killed)


## Switches to a weapon's (or the class's unarmed) moveset.
func set_moveset(p_moveset: WeaponMoveset) -> void:
	if p_moveset == null:
		return
	cancel()
	moveset = p_moveset
	light_combo = p_moveset.light_combo.duplicate()
	heavy_attack = p_moveset.heavy_attack
	combo_index = 0


func is_ranged() -> bool:
	return moveset != null and moveset.ranged


func is_attacking() -> bool:
	return phase != Phase.NONE or plunging


## True while a bow is being drawn or a heavy attack is being charged.
func is_holding() -> bool:
	return _holding


## True while the attack may still turn towards the aim (wind-up, drawing a
## bow, charging a heavy attack) - the player keeps facing the mouse.
func can_steer() -> bool:
	return phase == Phase.WINDUP and current != null and current != RIPOSTE_ATTACK


## True during late recovery, when a dodge or next attack may cancel the swing.
func can_cancel() -> bool:
	return phase == Phase.NONE or (phase == Phase.RECOVERY and current != null
		and phase_time >= current.recovery * current.cancel_ratio)


func request(kind: StringName) -> void:
	_buffered = kind
	_buffer_left = buffer_time


func cancel() -> void:
	_holding = false
	plunging = false
	if phase != Phase.NONE:
		phase = Phase.NONE
		current = null
		player.model.cancel_attack()
		attack_finished.emit()


## A perfect parry opens a riposte (Player.receive_hit).
func open_riposte() -> void:
	riposte_left = RIPOSTE_WINDOW


func physics_update(delta: float) -> void:
	riposte_left = maxf(riposte_left - delta, 0.0)
	_buffer_left -= delta
	if _buffer_left <= 0.0:
		_buffered = &""
	if phase == Phase.NONE:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_index = 0
	else:
		_advance(delta)
	if _buffered != &"" and can_cancel() and player.can_start_attack():
		var kind := _buffered
		_buffered = &""
		_start(kind)


func _held(kind: StringName) -> bool:
	if held_override.has(kind):
		return bool(held_override[kind])
	return Input.is_action_pressed(&"attack_heavy" if kind == &"heavy" else &"attack_light")


func _start(kind: StringName) -> void:
	var attack: AttackData
	_bonus = {}
	_is_last_of_combo = false
	var hold := false
	if kind == &"heavy":
		attack = heavy_attack
		combo_index = 0
		hold = moveset != null and moveset.charge_time > 0.0 and not is_ranged()
	elif kind == &"light" and riposte_left > 0.0 and not is_ranged():
		attack = RIPOSTE_ATTACK
		riposte_left = 0.0
		combo_index = 0
		_bonus = {"mult": RIPOSTE_MULT, "crit": true, "tag": "Riposte"}
	elif kind == &"sprint" and not is_ranged():
		attack = moveset.sprint_attack if moveset and moveset.sprint_attack else SPRINT_ATTACK
		combo_index = 0
	else:
		if light_combo.is_empty():
			return
		if phase == Phase.NONE and _combo_timer <= 0.0:
			combo_index = 0
		attack = light_combo[combo_index % light_combo.size()]
		_is_last_of_combo = light_combo.size() > 1 and combo_index % light_combo.size() == light_combo.size() - 1
		combo_index = (combo_index + 1) % light_combo.size()
		if is_ranged():
			if best_arrow() == &"":
				Events.toast.emit("No arrows! Make them at a workbench.", Color(1, 0.8, 0.5))
				return
			hold = true
	if attack == null:
		return
	if attack.stamina_cost > 0.0 and not player.stamina.try_consume(attack.stamina_cost, true):
		Events.toast.emit("Too exhausted!", Color(1, 0.85, 0.4))
		return
	current = attack
	phase = Phase.WINDUP
	phase_time = 0.0
	_holding = hold
	_hold_kind = &"heavy" if kind == &"heavy" else &"light"
	_charge_time = 0.0
	_charged_announced = false
	last_charge = 0.0
	attack_direction = player.get_aim_direction()
	player.face_direction(attack_direction, true)
	var speed := _speed_mult()
	player.model.play_attack(attack.animation, _windup(attack) / speed, attack.active / speed, attack.recovery / speed, hold)
	if not is_ranged():
		Audio.play(&"swing_heavy" if attack.windup > 0.35 else &"swing", -5.0)
	if _bonus.has("tag"):
		Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, false, String(_bonus.tag) + "!")
	attack_started.emit(attack)


## A bow's windup is its draw time (weapon_params draw_time).
func _windup(attack: AttackData) -> float:
	if is_ranged() and attack != heavy_attack:
		var dt := weapon_param(&"draw_time")
		return dt if dt > 0.0 else attack.windup
	return attack.windup


func _speed_mult() -> float:
	return maxf(player.stats.get_mult(Stats.ATTACK_SPEED), 0.2)


func _advance(delta: float) -> void:
	phase_time += delta * _speed_mult()
	match phase:
		Phase.WINDUP:
			var windup := _windup(current)
			if _holding:
				_update_hold(delta, windup)
				return
			if phase_time >= windup:
				_enter_active()
		Phase.ACTIVE:
			if phase_time >= current.active:
				phase = Phase.RECOVERY
				phase_time = 0.0
		Phase.RECOVERY:
			if phase_time >= current.recovery:
				phase = Phase.NONE
				current = null
				_combo_timer = combo_window
				attack_finished.emit()


## Drawing a bow or charging a heavy attack while the button is held.
func _update_hold(delta: float, windup: float) -> void:
	var held := _held(_hold_kind)
	if is_ranged():
		last_draw = clampf(phase_time / windup, 0.0, 1.0)
		if phase_time >= windup:
			phase_time = windup
			if not _charged_announced:
				_charged_announced = true
				VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1.5, 0) + attack_direction * 0.6, 0.5, Color(1, 0.95, 0.7, 0.8))
		if not held:
			_release_hold()
		return
	# Charged heavy: the windup plays out, then the swing waits while held.
	if phase_time < windup:
		if not held:
			_holding = false
			player.model.release_attack()
		return
	phase_time = windup
	var max_charge := moveset.charge_time if moveset else 0.0
	if held and _charge_time < max_charge + CHARGE_HOLD_MAX and player.stamina.current > 1.0:
		_charge_time += delta
		if _charge_time <= max_charge:
			player.stamina.consume(CHARGE_STAMINA_PER_SECOND * delta)
		last_charge = clampf(_charge_time / max_charge, 0.0, 1.0)
		if last_charge >= 1.0 and not _charged_announced:
			_charged_announced = true
			Events.damage_dealt.emit(player.global_position + Vector3(0, 2.4, 0), 0.0, false, false, "Charged!")
			VFX.burst(player.get_parent(), player.global_position + Vector3(0, 1.4, 0), 1.0, Color(1, 0.85, 0.4, 0.8))
			Audio.play(&"pickup", -6.0)
		return
	_release_hold()


func _release_hold() -> void:
	_holding = false
	player.model.release_attack()
	_enter_active()


func _enter_active() -> void:
	phase = Phase.ACTIVE
	phase_time = 0.0
	if is_ranged() and current != heavy_attack:
		_shoot_arrow()
	else:
		_perform_hit()


## Forward motion applied by the player during windup/active (commitment).
func get_lunge_velocity() -> Vector3:
	if current == null or phase == Phase.RECOVERY or _holding:
		return Vector3.ZERO
	return attack_direction * current.lunge_speed


func get_move_multiplier() -> float:
	if _holding and is_ranged():
		return 0.5
	return current.move_multiplier if current else 1.0


func _perform_hit() -> void:
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3(0, 0.9, 0)
	var targets := HitQuery.query_arc(space, origin, attack_direction, current.reach + weapon_param(&"reach"),
		current.arc_degrees, Layers.ENEMY | Layers.PROP, [player.get_rid()])
	var hit_enemy := false
	var bonus := _bonus
	var heavy := current == heavy_attack
	for t in targets:
		if not t.has_method("receive_hit"):
			continue
		var is_enemy := t.is_in_group(&"enemies")
		if is_enemy and bonus.is_empty():
			bonus = player.abilities.consume_attack_bonus()
		var info := build_damage(current, t, bonus if is_enemy else {})
		if is_enemy and heavy and float(t.get("barrier") if t.get("barrier") != null else 0.0) > 0.0:
			info.amount *= maxf(weapon_param(&"shield_break"), 1.0)
		var dealt = t.receive_hit(info)
		if is_enemy:
			hit_enemy = true
			player.abilities.on_hit_dealt(t, float(dealt) if dealt != null else 0.0)
			_after_hit(t, info, float(dealt) if dealt != null else 0.0, heavy, current)
	if hit_enemy:
		Events.camera_shake.emit(current.camera_shake * (1.0 + last_charge * 0.6))
		_count_special(targets.filter(func(t: Node) -> bool: return t.is_in_group(&"enemies")).front())
	if heavy and weapon_param(&"heavy_shockwave") > 0.0:
		_shockwave()


## Stuns, statuses and weapon powers after a melee hit or an arrow.
func _after_hit(t: Node, info: DamageInfo, dealt: float, heavy: bool, attack: AttackData) -> void:
	if not t.has_method("apply_status") or t.get("is_dead"):
		return
	var stun := attack.stun if attack else 0.0
	if _is_last_of_combo and not heavy:
		stun = maxf(stun, weapon_param(&"combo_stun"))
	if stun > 0.0:
		t.apply_status(&"stunned", stun, {})
	var chill := weapon_param(&"on_hit_chill")
	if chill > 0.0:
		t.apply_status(&"chilled", chill, {})
	var burn := weapon_param(&"on_hit_burn")
	if burn > 0.0:
		t.apply_status(&"burn", burn, {"dps": 4.0 * player.character.physical_mult, "source": player})
	if info.is_crit and weapon_param(&"crit_poison") > 0.0:
		t.apply_status(&"poison", 5.0, {"dps": 3.0, "source": player})
	var heal := weapon_param(&"undead_heal")
	if heal > 0.0 and dealt > 0.0 and is_undead(t):
		player.health.heal(dealt * heal)


## Weapons with "star_every": every Nth hit or shot calls down a falling star.
func _count_special(target: Node) -> void:
	var every := roundi(weapon_param(&"star_every"))
	if every <= 0 or target == null:
		return
	special_counter += 1
	if special_counter % every == 0:
		falling_star((target as Node3D).global_position)


## A star falls at `pos`: fire damage around it (Starfall weapons).
func falling_star(pos: Vector3) -> void:
	var parent := player.get_parent()
	VFX.burst(parent, pos + Vector3(0, 6, 0), 0.8, Color(1, 0.9, 0.6, 0.9))
	VFX.ring(parent, pos, STAR_RADIUS, Color(1, 0.85, 0.5, 0.8), 0.35)
	VFX.burst(parent, pos + Vector3(0, 0.5, 0), 2.2, Color(1, 0.7, 0.3, 0.8))
	Audio.play_at(&"explosion", pos, -6.0)
	Events.camera_shake.emit(0.3)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or n.get("is_dead") or not n.has_method("receive_hit"):
			continue
		if n.global_position.distance_to(pos) <= STAR_RADIUS:
			var info := DamageInfo.create(STAR_DAMAGE * player.character.physical_mult, player, &"fire")
			info.tag = "Falling Star"
			info.hit_position = n.global_position + Vector3(0, 1, 0)
			info.poise_damage = 30.0
			n.receive_hit(info)


## Shardbreaker: a heavy attack sends a shockwave along the ground in front.
func _shockwave() -> void:
	var dmg := weapon_param(&"heavy_shockwave") * player.character.physical_mult
	var start := player.global_position
	for i in 4:
		VFX.dust(player.get_parent(), start + attack_direction * (1.5 + i * 1.5), Color(0.6, 0.55, 0.5), 6)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or n.get("is_dead") or not n.has_method("receive_hit"):
			continue
		var to := n.global_position - start
		to.y = 0.0
		var along := to.dot(attack_direction)
		if along > 0.5 and along < 7.0 and (to - attack_direction * along).length() < 1.4:
			var info := DamageInfo.create(dmg, player, &"physical")
			info.tag = "Shockwave"
			info.poise_damage = 40.0
			info.direction = attack_direction
			info.knockback = attack_direction * 5.0
			info.hit_position = n.global_position + Vector3(0, 1, 0)
			n.receive_hit(info)


func _on_enemy_killed(enemy: Node, _id: StringName, _pos: Vector3) -> void:
	if player == null or player.is_dead or enemy.get_meta(&"killed_by_npc", false):
		return
	var heal := weapon_param(&"kill_heal")
	if heal > 0.0:
		player.health.heal(player.health.max_health * heal)


## Sum of a weapon_params value over the main-hand and off-hand items.
func weapon_param(key: StringName) -> float:
	var t := 0.0
	if player == null:
		return t
	for item in [player.equipment.weapon(), player.equipment.offhand()]:
		if item:
			t += float((item as ItemData).weapon_params.get(key, 0.0))
	return t


static func is_undead(t: Node) -> bool:
	var d = t.get("data")
	return d is EnemyData and String((d as EnemyData).id) in ["skeleton_warrior", "skeleton_archer", "bone_king"]


# --- Plunging attack ----------------------------------------------------------------------

## Attack while falling: the slam happens when you land (Player calls land_plunge).
func start_plunge() -> void:
	if plunging or phase != Phase.NONE:
		return
	plunging = true
	_bonus = {}
	player.model.play_attack(&"plunge", 0.15, 0.08, 0.35, true)
	Audio.play(&"swing_heavy", -5.0)


## Landing after a plunge: hits every enemy around you. Damage grows with the fall.
func land_plunge(fall_speed: float) -> int:
	if not plunging:
		return 0
	plunging = false
	player.model.release_attack()
	var parent := player.get_parent()
	var pos := player.global_position
	VFX.ring(parent, pos, PLUNGE_RADIUS, Color(1, 0.9, 0.7, 0.8), 0.3)
	VFX.dust(parent, pos, Color(0.6, 0.55, 0.5), 14)
	Events.camera_shake.emit(0.45)
	Audio.play(&"swing_heavy", -2.0)
	var mult := 1.0 + maxf(fall_speed - PLUNGE_MIN_FALL, 0.0) * PLUNGE_PER_SPEED
	var hits := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or n.get("is_dead") or not n.has_method("receive_hit") or not n.is_visible_in_tree():
			continue
		if n.global_position.distance_to(pos) > PLUNGE_RADIUS + 0.5:
			continue
		var info := build_damage(PLUNGE_ATTACK, n, {"mult": mult, "tag": "Plunge"})
		var dealt = n.receive_hit(info)
		player.abilities.on_hit_dealt(n, float(dealt) if dealt != null else 0.0)
		hits += 1
	return hits


# --- Bows ------------------------------------------------------------------------------------

## The best arrow in the inventory (highest arrow_damage), or &"" if none.
func best_arrow() -> StringName:
	var best: StringName = &""
	var best_dmg := -1.0
	for s in player.inventory.slots:
		if s == null:
			continue
		var it: ItemData = ItemDB.get_item(s.id)
		if it and it.is_arrow() and float(it.weapon_params.arrow_damage) > best_dmg:
			best_dmg = float(it.weapon_params.arrow_damage)
			best = it.id
	return best


func _shoot_arrow() -> void:
	var arrow_id := best_arrow()
	var arrow: ItemData = ItemDB.get_item(arrow_id) if arrow_id != &"" else null
	if arrow == null:
		return
	if player.inventory.remote:
		Net.client.request("ammo", [String(arrow_id)])
	else:
		player.inventory.remove_item(arrow_id, 1)
	var draw := clampf(last_draw, MIN_DRAW, 1.0)
	var range_m := weapon_param(&"range")
	if range_m <= 0.0:
		range_m = DEFAULT_BOW_RANGE
	var speed := ARROW_SPEED * (0.55 + 0.45 * draw)
	var start := player.global_position + Vector3(0, 1.4, 0) + attack_direction * 0.6
	var flight := attack_direction
	var tgt: Node3D = player.abilities._aim_target(range_m)
	if tgt:
		flight = (tgt.global_position + Vector3(0, 0.9, 0) - start).normalized()
	var attack := current
	var full := draw >= 0.99
	var crit_bonus := weapon_param(&"full_draw_crit") if full else 0.0
	var arrow_dmg := float(arrow.weapon_params.get(&"arrow_damage", 0.0))
	var burn := float(arrow.weapon_params.get(&"arrow_burn", 0.0))
	var dmg_mult := 0.35 + 0.65 * draw
	var p := Projectile.new()
	p.style = &"arrow"
	p.color = arrow.icon_color
	p.launch_sound = &"bow"
	p.velocity = flight * speed
	p.lifetime = range_m / speed
	p.exclude = [player.get_rid()]
	p.mask = Layers.TERRAIN | Layers.ENEMY | Layers.PROP
	p.info_builder = func(t: Node) -> DamageInfo:
		var info := build_physical((attack.damage + arrow_dmg) * dmg_mult, t, attack.poise_damage * dmg_mult,
			attack.knockback * dmg_mult, attack.crit_chance_bonus + crit_bonus, &"physical", {})
		if burn > 0.0:
			info.status_effects = [[&"burn", burn, {"dps": 4.0, "source": player}]]
		if full and info.tag == "":
			info.tag = "Full draw"
		return info
	p.on_hit = func(t: Node, dealt: float) -> void:
		if is_instance_valid(t) and t.is_in_group(&"enemies"):
			player.abilities.on_hit_dealt(t, dealt)
			_after_hit(t, DamageInfo.create(dealt, player), dealt, false, null)
			_count_special(t)
	player.get_parent().add_child(p)
	p.global_position = start


# --- Damage ------------------------------------------------------------------------------------

## Damage for a moveset attack (weapon, skills, class, buffs, crits, backstab).
func build_damage(attack: AttackData, target: Node, bonus: Dictionary = {}) -> DamageInfo:
	var poise := attack.poise_damage
	var heavy := attack == heavy_attack
	if heavy and player.character.skill_level(Skill.STRENGTH) >= 25:
		poise *= 1.5
	var charge := last_charge if heavy else 0.0
	poise *= 1.0 + CHARGE_POISE * charge
	var b := bonus
	if charge > 0.0:
		b = bonus.duplicate()
		b["mult"] = float(bonus.get("mult", 1.0)) * (1.0 + CHARGE_DAMAGE * charge)
		if charge >= 1.0 and not b.has("tag"):
			b["tag"] = "Charged"
	var info := build_physical(attack.damage, target, poise, attack.knockback,
		attack.crit_chance_bonus, attack.damage_type, b)
	if heavy and player.character.skill_level(Skill.STRENGTH) >= 75:
		info.poise_damage = maxf(info.poise_damage, 999.0)
	return info


## Shared physical damage pipeline (also used by abilities).
func build_physical(base: float, target: Node, poise: float, knockback: float,
		crit_bonus: float = 0.0, damage_type: StringName = &"physical", bonus: Dictionary = {}) -> DamageInfo:
	var ch := player.character
	var weapon := player.equipment.weapon()
	var weapon_type := player.equipment.weapon_type()
	var amount := (base + (float(weapon.stat_bonuses.get(&"damage_bonus", 0.0)) if weapon else 0.0))
	amount *= ch.physical_mult * ch.weapon_mult(weapon_type) * player.abilities.outgoing_mult()
	amount *= player.stats.get_mult(Stats.ATTACK_DAMAGE) * _rng.randf_range(0.92, 1.08)
	amount *= float(bonus.get("mult", 1.0)) * player.abilities.target_mult(target)
	var info := DamageInfo.create(amount, player, damage_type)
	var strength := ch.skill_level(Skill.STRENGTH)
	info.poise_damage = poise * Skill.poise_mult(strength, ch.eff(Skill.STRENGTH))
	var to_target := (target as Node3D).global_position - player.global_position
	to_target.y = 0.0
	info.direction = to_target.normalized() if to_target.length() > 0.01 else attack_direction
	info.knockback = info.direction * knockback * Skill.poise_mult(strength, ch.eff(Skill.STRENGTH))
	info.hit_position = (target as Node3D).global_position + Vector3(0, 1.0, 0)
	info.tag = String(bonus.get("tag", ""))
	# Positioning matters: hitting an enemy from behind deals bonus damage.
	if target.has_method("get_facing"):
		var target_facing: Vector3 = target.get_facing()
		if target_facing.dot(info.direction) > 0.5:
			info.amount *= ch.backstab_mult
			info.tag = "Backstab" if info.tag == "" else info.tag + " Backstab"
	if bonus.get("crit", false) or _rng.randf() < ch.crit_chance + crit_bonus:
		info.is_crit = true
		info.amount *= ch.crit_mult
	return info
