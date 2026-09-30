class_name ThornbackBoar
extends Enemy
## Thornback Boar - territorial wildlife.
##
## Behaviour:
##   IDLE/WANDER around its home until the player comes close.
##   ALERT: "!" telegraph, then CHASE.
##   BITE at close range (fast, light damage).
##   CHARGE at mid range: long red-glow windup (scrapes the ground), then a
##   straight high-damage dash. Dodge sideways or parry it!
##   RECOVER after a charge: panting and EXPOSED (takes +50% damage). Hitting a
##   wall during the charge stuns it longer - use terrain and trees.
##   RETURN home and heal when leashed or the player escapes.

enum AI { IDLE, WANDER, ALERT, CHASE, BITE, CHARGE_WINDUP, CHARGE, RECOVER, RETURN }

## AttackData ids looked up in EnemyData.attacks.
const BITE_ID := &"boar_bite"
const CHARGE_ID := &"boar_charge"

@export var bite_range: float = 1.9
@export var bite_cooldown: float = 1.2
@export var charge_min_range: float = 4.5
@export var charge_max_range: float = 12.0
@export var charge_cooldown: float = 5.5
@export var charge_windup: float = 0.85
@export var charge_speed: float = 13.0
@export var charge_duration: float = 0.8
@export var charge_hit_radius: float = 1.3
@export var recover_time: float = 1.2
@export var wall_stun_time: float = 2.0

var ai: AI = AI.IDLE
var ai_time := 0.0
var _wander_target := Vector3.ZERO
var _bite_cd := 0.0
var _charge_cd := 0.0
var _charge_dir := Vector3.ZERO
var _attack_hit := false


func _on_spawned() -> void:
	(model as BoarModel).reset_pose()
	_set_ai(AI.IDLE, _rng.randf_range(0.5, 3.0))
	_bite_cd = 0.0
	_charge_cd = _rng.randf_range(1.0, 3.0)


func _set_ai(new_ai: AI, time: float = 0.0) -> void:
	ai = new_ai
	ai_time = time
	_attack_hit = false
	exposed = (new_ai == AI.RECOVER)
	# While charging, pass through the player (the hit is resolved by distance),
	# so only real obstacles count as "slammed into a wall".
	if new_ai == AI.CHARGE:
		collision_mask &= ~Layers.PLAYER
	else:
		collision_mask |= Layers.PLAYER
	var m := model as BoarModel
	m.set_telegraph(new_ai == AI.CHARGE_WINDUP)
	m.set_exposed(exposed)


func _player() -> Node3D:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null or p.get("is_dead") or p.get("frozen"):
		return null
	# Stealthed players are only noticed up close (unless we're taunted).
	if p.has_method("is_stealthed") and p.is_stealthed() and not is_taunted() \
			and p.global_position.distance_to(global_position) > 2.2:
		return null
	return p


func _think(delta: float) -> void:
	ai_time -= delta
	_bite_cd -= delta
	_charge_cd -= delta
	_desired_velocity = Vector3.ZERO
	var player := _player()
	var to_player := Vector3.ZERO
	var dist := INF
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	match ai:
		AI.IDLE:
			if player and dist < data.aggro_range:
				_alert(player)
			elif ai_time <= 0.0:
				var a := _rng.randf() * TAU
				_wander_target = home_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 7.0)
				_set_ai(AI.WANDER, 6.0)
		AI.WANDER:
			if player and dist < data.aggro_range:
				_alert(player)
			else:
				var to := _wander_target - global_position
				to.y = 0.0
				if to.length() < 0.6 or ai_time <= 0.0:
					_set_ai(AI.IDLE, _rng.randf_range(2.0, 5.0))
				else:
					_move_toward_dir(to, data.walk_speed)
		AI.ALERT:
			if player:
				face_toward(to_player)
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
		AI.CHASE:
			if player == null or global_position.distance_to(home_position) > data.leash_range \
					or dist > data.aggro_range * 2.5:
				_set_ai(AI.RETURN, 12.0)
			elif dist <= bite_range and _bite_cd <= 0.0:
				_start_bite()
			elif dist >= charge_min_range and dist <= charge_max_range and _charge_cd <= 0.0:
				_set_ai(AI.CHARGE_WINDUP, charge_windup)
			else:
				face_toward(to_player)
				if dist > bite_range * 0.8:
					_move_toward_dir(to_player, data.run_speed)
		AI.BITE:
			var bite := data.get_attack(BITE_ID)
			if player and ai_time > bite.active + bite.recovery:
				face_toward(to_player)  # tracks during windup only
			if not _attack_hit and ai_time <= bite.active + bite.recovery:
				_attack_hit = true
				if player and dist <= bite.reach and get_facing().angle_to(to_player.normalized()) < deg_to_rad(bite.arc_degrees) * 0.5:
					_hit_player(player, bite)
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
		AI.CHARGE_WINDUP:
			# Tracks the player until the last moment, then commits.
			if player and ai_time > 0.2:
				face_toward(to_player)
			if ai_time <= 0.0:
				_charge_dir = get_facing()
				_set_ai(AI.CHARGE, charge_duration)
		AI.CHARGE:
			_desired_velocity = _charge_dir * charge_speed
			velocity.x = _desired_velocity.x
			velocity.z = _desired_velocity.z
			if not _attack_hit and player and dist <= charge_hit_radius:
				_attack_hit = true
				_hit_player(player, data.get_attack(CHARGE_ID))
			if ai_time < charge_duration - 0.15 and is_on_wall():
				# Slammed into a wall/tree: stunned and exposed for longer.
				Events.camera_shake.emit(0.25)
				Events.damage_dealt.emit(global_position + Vector3(0, 1.8, 0), 0.0, false, false, "Dazed")
				_desired_velocity = Vector3.ZERO
				_set_ai(AI.RECOVER, wall_stun_time)
				_charge_cd = charge_cooldown
			elif ai_time <= 0.0:
				_set_ai(AI.RECOVER, recover_time)
				_charge_cd = charge_cooldown
		AI.RECOVER:
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
		AI.RETURN:
			var home := home_position - global_position
			home.y = 0.0
			if home.length() < 1.0 or ai_time <= 0.0:
				health.reset_full()
				health_bar.set_ratio(1.0)
				health_bar.hide_now()
				_set_ai(AI.IDLE, 2.0)
			else:
				_move_toward_dir(home, data.walk_speed * 1.6)
	(model as BoarModel).set_locomotion(Vector2(velocity.x, velocity.z).length(), delta)


func _move_toward_dir(dir: Vector3, speed: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	face_toward(dir)
	_desired_velocity = dir.normalized() * speed


func _alert(player: Node3D) -> void:
	target = player
	(model as BoarModel).show_alert()
	_set_ai(AI.ALERT, 0.55)


func _start_bite() -> void:
	var bite := data.get_attack(BITE_ID)
	_set_ai(AI.BITE, bite.total_duration())
	_bite_cd = bite_cooldown
	(model as BoarModel).play_bite()


func _hit_player(player: Node3D, attack: AttackData) -> void:
	if attack == null or not player.has_method("receive_hit"):
		return
	var info := DamageInfo.create(attack.damage, self, attack.damage_type)
	var dir := player.global_position - global_position
	dir.y = 0.0
	info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
	info.knockback = info.direction * attack.knockback
	info.poise_damage = attack.poise_damage
	player.receive_hit(info)


func _on_hit_reaction(info: DamageInfo) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN]:
		if info.source is Node3D:
			_alert(info.source)


func is_charging() -> bool:
	return ai == AI.CHARGE


func _on_taunted(source: Node3D) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN, AI.ALERT]:
		target = source
		_set_ai(AI.CHASE)


func _on_lost_target() -> void:
	if ai in [AI.CHASE, AI.ALERT, AI.CHARGE_WINDUP]:
		_set_ai(AI.RETURN, 12.0)


func _on_staggered() -> void:
	_set_ai(AI.CHASE)
	_bite_cd = 0.6


func on_parried() -> void:
	# A parried charge leaves the boar dazed and exposed.
	_set_ai(AI.RECOVER, 1.6)
	_charge_cd = charge_cooldown
	Events.damage_dealt.emit(global_position + Vector3(0, 1.8, 0), 0.0, false, false, "Stunned")
