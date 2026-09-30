class_name PlayerCombat
extends Node
## Player melee combat: light combo chain, heavy attack, input buffering,
## crits and positional (backstab) bonuses.
##
## Attack timing comes from AttackData resources so each future class/weapon
## can define its own move set without code changes.

signal attack_started(attack: AttackData)
signal attack_finished

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

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

var _buffered: StringName = &""
var _buffer_left := 0.0
var _combo_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Switches to a weapon's (or the class's unarmed) moveset.
func set_moveset(moveset: WeaponMoveset) -> void:
	if moveset == null:
		return
	cancel()
	light_combo = moveset.light_combo.duplicate()
	heavy_attack = moveset.heavy_attack
	combo_index = 0


func is_attacking() -> bool:
	return phase != Phase.NONE


## True during late recovery, when a dodge or next attack may cancel the swing.
func can_cancel() -> bool:
	return phase == Phase.NONE or (phase == Phase.RECOVERY and current != null
		and phase_time >= current.recovery * current.cancel_ratio)


func request(kind: StringName) -> void:
	_buffered = kind
	_buffer_left = buffer_time


func cancel() -> void:
	if phase != Phase.NONE:
		phase = Phase.NONE
		current = null
		player.model.cancel_attack()
		attack_finished.emit()


func physics_update(delta: float) -> void:
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


func _start(kind: StringName) -> void:
	var attack: AttackData
	if kind == &"heavy":
		attack = heavy_attack
		combo_index = 0
	else:
		if light_combo.is_empty():
			return
		if phase == Phase.NONE and _combo_timer <= 0.0:
			combo_index = 0
		attack = light_combo[combo_index % light_combo.size()]
		combo_index = (combo_index + 1) % light_combo.size()
	if attack == null:
		return
	if attack.stamina_cost > 0.0 and not player.stamina.try_consume(attack.stamina_cost, true):
		Events.toast.emit("Too exhausted!", Color(1, 0.85, 0.4))
		return
	current = attack
	phase = Phase.WINDUP
	phase_time = 0.0
	attack_direction = player.get_aim_direction()
	player.face_direction(attack_direction, true)
	var speed := _speed_mult()
	player.model.play_attack(attack.animation, attack.windup / speed, attack.active / speed, attack.recovery / speed)
	attack_started.emit(attack)


func _speed_mult() -> float:
	return maxf(player.stats.get_mult(Stats.ATTACK_SPEED), 0.2)


func _advance(delta: float) -> void:
	phase_time += delta * _speed_mult()
	match phase:
		Phase.WINDUP:
			if phase_time >= current.windup:
				phase = Phase.ACTIVE
				phase_time = 0.0
				_perform_hit()
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


## Forward motion applied by the player during windup/active (commitment).
func get_lunge_velocity() -> Vector3:
	if current == null or phase == Phase.RECOVERY:
		return Vector3.ZERO
	return attack_direction * current.lunge_speed


func get_move_multiplier() -> float:
	return current.move_multiplier if current else 1.0


func _perform_hit() -> void:
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3(0, 0.9, 0)
	var targets := HitQuery.query_arc(space, origin, attack_direction, current.reach,
		current.arc_degrees, Layers.ENEMY | Layers.PROP, [player.get_rid()])
	var hit_enemy := false
	var bonus := {}
	for t in targets:
		if not t.has_method("receive_hit"):
			continue
		var is_enemy := t.is_in_group(&"enemies")
		if is_enemy and bonus.is_empty():
			bonus = player.abilities.consume_attack_bonus()
		var info := build_damage(current, t, bonus if is_enemy else {})
		var dealt = t.receive_hit(info)
		if is_enemy:
			hit_enemy = true
			player.abilities.on_hit_dealt(t, float(dealt) if dealt != null else 0.0)
	if hit_enemy:
		Events.camera_shake.emit(current.camera_shake)


## Damage for a moveset attack (weapon, skills, class, buffs, crits, backstab).
func build_damage(attack: AttackData, target: Node, bonus: Dictionary = {}) -> DamageInfo:
	var poise := attack.poise_damage
	if attack == heavy_attack and player.character.skill_level(Skill.STRENGTH) >= 25:
		poise *= 1.5
	var info := build_physical(attack.damage, target, poise, attack.knockback,
		attack.crit_chance_bonus, attack.damage_type, bonus)
	if attack == heavy_attack and player.character.skill_level(Skill.STRENGTH) >= 75:
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
	amount *= float(bonus.get("mult", 1.0))
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
