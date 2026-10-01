class_name Monster
extends Enemy
## Generic data-driven monster AI (Milestone 6).
##
## MELEE: chase, light attacks, optional heavy telegraphed attack.
## RANGED / CASTER: keep a preferred distance, aim (telegraph) and shoot
## projectiles when they have line of sight.
## BOSS: melee plus a cycle of special moves - cleave (heavy), slam (ground
## danger zone), volley (fan of projectiles), charge (dash), summon (adds) -
## and an enrage phase below `enrage_at` health. Bosses show a boss bar.
##
## Rank scaling (dungeons E..S, far-away ruins): configure() multiplies health,
## damage, level and XP per instance, so one MonsterData serves every rank.

enum AI { IDLE, WANDER, ALERT, CHASE, ATTACK, SHOOT, SLAM, VOLLEY, CHARGE_WINDUP, CHARGE, SUMMON, RECOVER, RETURN, DORMANT }

var mdata: MonsterData
var power := 1.0
var damage_mult := 1.0
var level_bonus := 0
var xp_mult := 1.0
## Guardians stay near home (ruins, towers) and dungeon monsters never leash home far.
var leash_mult := 1.0
## Bosses/guardians can start dormant and wake when the player comes close.
var wake_range := 0.0
var enraged := false
var ai: AI = AI.IDLE
var ai_time := 0.0

var _atk_cd := 0.0
var _heavy_cd := 0.0
var _shot_cd := 0.0
var _special_cd := 3.0
var _move_i := 0
var _hit_done := false
var _cur: AttackData
var _charge_dir := Vector3.ZERO
var _summons_done := 0
var _wander_target := Vector3.ZERO
var _zone: Node3D
var _shape := CapsuleShape3D.new()


func _ready() -> void:
	super._ready()
	$CollisionShape3D.shape = _shape


## Rank scaling. Call after spawn_at().
func configure(p_power: float, p_damage: float, levels: int, p_xp: float) -> void:
	power = p_power
	damage_mult = p_damage
	level_bonus = levels
	xp_mult = p_xp
	health.max_health = data.max_health * power
	health.reset_full()


func effective_level() -> int:
	return (data.level if data else 1) + level_bonus


func xp_value() -> int:
	return roundi((data.xp_reward if data else 10) * xp_mult)


func is_boss() -> bool:
	return mdata != null and mdata.style == MonsterData.Style.BOSS


func display_name() -> String:
	if is_boss() and mdata.boss_title != "":
		return mdata.boss_title
	return super.display_name()


func _on_spawned() -> void:
	mdata = data as MonsterData
	power = 1.0
	damage_mult = 1.0
	level_bonus = 0
	xp_mult = 1.0
	leash_mult = 1.0
	wake_range = 0.0
	enraged = false
	_summons_done = 0
	_move_i = 0
	(model as MonsterModel).build(mdata)
	(model as MonsterModel).reset_pose()
	var s := mdata.model_scale
	_shape.radius = 0.4 * s
	_shape.height = maxf(1.8 * s, _shape.radius * 2.0)
	$CollisionShape3D.position.y = _shape.height * 0.5
	health_bar.position.y = 2.1 * s
	_atk_cd = 0.5
	_heavy_cd = mdata.heavy_cooldown * 0.5
	_shot_cd = _rng.randf_range(0.5, mdata.projectile_cooldown)
	_special_cd = 3.0
	_set_ai(AI.IDLE, _rng.randf_range(0.5, 2.5))


## Guardians (temple bosses) wait motionless until the player comes near.
func make_dormant(range_m: float) -> void:
	wake_range = range_m
	_set_ai(AI.DORMANT)


func _set_ai(new_ai: AI, time: float = 0.0) -> void:
	ai = new_ai
	ai_time = time
	_hit_done = false
	exposed = new_ai == AI.RECOVER
	(model as MonsterModel).set_telegraph(new_ai in [AI.SLAM, AI.CHARGE_WINDUP] or (new_ai == AI.ATTACK and _cur == mdata.heavy and _cur != null))
	if new_ai == AI.CHARGE:
		collision_mask &= ~Layers.PLAYER
	else:
		collision_mask |= Layers.PLAYER
	if _zone and is_instance_valid(_zone) and new_ai != AI.SLAM:
		_zone.queue_free()
		_zone = null


func _player() -> Node3D:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null or p.get("is_dead") or p.get("frozen"):
		return null
	if p.has_method("is_stealthed") and p.is_stealthed() and not is_taunted() \
			and p.global_position.distance_to(global_position) > 2.2:
		return null
	return p


func _think(delta: float) -> void:
	ai_time -= delta
	_atk_cd -= delta
	_heavy_cd -= delta
	_shot_cd -= delta
	_special_cd -= delta
	_desired_velocity = Vector3.ZERO
	var player := _player()
	var to_player := Vector3.ZERO
	var dist := INF
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()
	if is_boss() and not enraged and health.get_ratio() <= mdata.enrage_at:
		enraged = true
		Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Enraged!")
		Events.camera_shake.emit(0.4)
		VFX.ring(get_parent(), global_position, 6.0, Color(1, 0.3, 0.2, 0.8), 0.6)

	match ai:
		AI.DORMANT:
			if player and dist < wake_range:
				Events.toast.emit("%s awakens!" % display_name(), Color(1, 0.6, 0.3))
				_alert(player)
		AI.IDLE:
			if player and dist < data.aggro_range:
				_alert(player)
			elif ai_time <= 0.0:
				var a := _rng.randf() * TAU
				_wander_target = home_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.5, 5.0 * leash_mult)
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
					_move_dir(to, data.walk_speed)
		AI.ALERT:
			if player:
				face_toward(to_player)
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
				if is_boss():
					Events.boss_started.emit(self)
		AI.CHASE:
			if player == null or global_position.distance_to(home_position) > data.leash_range * leash_mult \
					or dist > data.aggro_range * 3.0:
				_set_ai(AI.RETURN, 12.0)
			else:
				_combat(player, to_player, dist)
		AI.ATTACK:
			_do_attack(player, to_player, dist)
		AI.SHOOT:
			if player:
				face_toward(to_player)
			if ai_time <= 0.0:
				if player:
					_fire(player, 0.0)
				_shot_cd = mdata.projectile_cooldown * (0.65 if enraged else 1.0)
				_set_ai(AI.CHASE)
		AI.SLAM:
			if ai_time <= 0.0:
				_slam(player)
				_set_ai(AI.RECOVER, 0.7)
		AI.VOLLEY:
			if player:
				face_toward(to_player)
			if ai_time <= 0.0 and player:
				var n := mdata.volley_count + (2 if enraged else 0)
				for k in n:
					_fire(player, (k - (n - 1) * 0.5) * 0.18)
				_set_ai(AI.RECOVER, 0.6)
		AI.CHARGE_WINDUP:
			if player and ai_time > 0.25:
				face_toward(to_player)
			if ai_time <= 0.0:
				_charge_dir = get_facing()
				_set_ai(AI.CHARGE, 0.75)
		AI.CHARGE:
			_desired_velocity = _charge_dir * data.run_speed * 2.6
			velocity.x = _desired_velocity.x
			velocity.z = _desired_velocity.z
			if not _hit_done and player and dist <= 1.6 * mdata.model_scale:
				_hit_done = true
				_hit_player(player, mdata.heavy if mdata.heavy else mdata.melee, 1.3)
			if ai_time <= 0.0 or (ai_time < 0.6 and is_on_wall()):
				_set_ai(AI.RECOVER, 1.4 if is_on_wall() else 0.8)
		AI.SUMMON:
			if ai_time <= 0.0:
				_summon()
				_set_ai(AI.CHASE)
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
				if is_boss():
					Events.boss_ended.emit(self)
				_set_ai(AI.IDLE, 2.0)
			else:
				_move_dir(home, data.walk_speed * 1.6)
	(model as MonsterModel).set_locomotion(Vector2(velocity.x, velocity.z).length(), delta)


## Chasing: pick the next action for this style.
func _combat(player: Node3D, to_player: Vector3, dist: float) -> void:
	face_toward(to_player)
	var speed_mult := 1.3 if enraged else 1.0
	if is_boss() and _special_cd <= 0.0 and not mdata.boss_moves.is_empty():
		var move: StringName = StringName(mdata.boss_moves[_move_i % mdata.boss_moves.size()])
		_move_i += 1
		_special_cd = (2.6 if enraged else 4.2)
		if _start_special(move, dist):
			return
	match mdata.style:
		MonsterData.Style.RANGED, MonsterData.Style.CASTER:
			if dist <= (mdata.melee.reach if mdata.melee else 0.0) and _atk_cd <= 0.0:
				_start_attack(mdata.melee)
			elif _shot_cd <= 0.0 and dist <= mdata.preferred_max * 1.6 and _line_of_sight(player):
				_set_ai(AI.SHOOT, mdata.projectile_windup)
				(model as MonsterModel).play_attack(&"overhead", mdata.projectile_windup, 0.1, 0.3)
			elif dist < mdata.preferred_min:
				_move_dir(-to_player, data.walk_speed * speed_mult)
				face_toward(to_player)
			elif dist > mdata.preferred_max:
				_move_dir(to_player, data.run_speed * speed_mult)
			else:
				# Strafe a little so ranged foes don't stand still.
				var side := to_player.cross(Vector3.UP).normalized() * (1.0 if int(Time.get_ticks_msec() / 1500) % 2 == 0 else -1.0)
				_move_dir(side, data.walk_speed * 0.6)
				face_toward(to_player)
		_:
			if mdata.heavy and _heavy_cd <= 0.0 and dist <= mdata.heavy.reach:
				_start_attack(mdata.heavy)
			elif mdata.melee and dist <= mdata.melee.reach and _atk_cd <= 0.0:
				_start_attack(mdata.melee)
			elif dist > (mdata.melee.reach * 0.8 if mdata.melee else 1.5):
				_move_dir(to_player, data.run_speed * speed_mult)


func _start_special(move: StringName, dist: float) -> bool:
	match move:
		&"cleave":
			if mdata.heavy and dist <= mdata.heavy.reach + 1.5:
				_start_attack(mdata.heavy)
				return true
		&"slam":
			var t := 0.8 if enraged else 1.1
			_zone = VFX.danger_zone(get_parent(), global_position, mdata.slam_radius, t)
			(model as MonsterModel).play_attack(&"overhead", t, 0.1, 0.5)
			_set_ai(AI.SLAM, t)
			return true
		&"volley":
			(model as MonsterModel).play_attack(&"overhead", 0.7, 0.1, 0.3)
			_set_ai(AI.VOLLEY, 0.7)
			return true
		&"charge":
			if dist > 3.5:
				_set_ai(AI.CHARGE_WINDUP, 0.9)
				return true
		&"summon":
			var thresholds := [0.66, 0.33]
			if mdata.summon and _summons_done < thresholds.size() and health.get_ratio() <= thresholds[_summons_done]:
				_summons_done += 1
				Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Summons help!")
				(model as MonsterModel).play_attack(&"overhead", 0.8, 0.1, 0.3)
				_set_ai(AI.SUMMON, 0.8)
				return true
	return false


func _start_attack(a: AttackData) -> void:
	if a == null:
		return
	_cur = a
	var speed := 0.75 if enraged else 1.0
	_set_ai(AI.ATTACK, a.total_duration() * speed)
	(model as MonsterModel).play_attack(a.animation, a.windup * speed, a.active * speed, a.recovery * speed)
	if a == mdata.heavy:
		_heavy_cd = mdata.heavy_cooldown * (0.7 if enraged else 1.0)
	else:
		_atk_cd = a.total_duration() + 0.4


func _do_attack(player: Node3D, to_player: Vector3, dist: float) -> void:
	var a := _cur
	var speed := 0.75 if enraged else 1.0
	var after_windup := (a.active + a.recovery) * speed
	if ai_time > after_windup:
		if player:
			face_toward(to_player)  # track during the windup only
		if a.lunge_speed > 0.0:
			_desired_velocity = get_facing() * a.lunge_speed
	elif not _hit_done:
		_hit_done = true
		(model as MonsterModel).set_telegraph(false)
		if player and dist <= a.reach * maxf(1.0, mdata.model_scale * 0.8) \
				and get_facing().angle_to(to_player.normalized()) < deg_to_rad(a.arc_degrees) * 0.5:
			_hit_player(player, a, 1.0)
		if a.camera_shake > 0.0:
			Events.camera_shake.emit(a.camera_shake)
	if ai_time <= 0.0:
		_set_ai(AI.CHASE)


func _hit_player(player: Node3D, a: AttackData, extra: float) -> void:
	if a == null or not player.has_method("receive_hit"):
		return
	var info := DamageInfo.create(a.damage * damage_mult * extra, self, a.damage_type)
	var dir := player.global_position - global_position
	dir.y = 0.0
	info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
	info.knockback = info.direction * a.knockback
	info.poise_damage = a.poise_damage
	if not mdata.melee_status.is_empty():
		info.status_effects = [mdata.melee_status]
	player.receive_hit(info)


func _slam(player: Node3D) -> void:
	Events.camera_shake.emit(0.45)
	VFX.ring(get_parent(), global_position, mdata.slam_radius, Color(1, 0.5, 0.2, 0.9), 0.4)
	if player == null or not player.has_method("receive_hit"):
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d <= mdata.slam_radius:
		var info := DamageInfo.create(mdata.slam_damage * damage_mult, self, &"physical")
		var dir := player.global_position - global_position
		dir.y = 0.0
		info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
		info.knockback = info.direction * 9.0
		info.poise_damage = 40.0
		player.receive_hit(info)


func _fire(player: Node3D, spread: float) -> void:
	var p := Projectile.new()
	var origin := global_position + Vector3(0, 1.3 * mdata.model_scale, 0) + get_facing() * 0.6
	var aim := player.global_position + Vector3(0, 1.0, 0)
	var pv: Vector3 = player.get("velocity") if player.get("velocity") != null else Vector3.ZERO
	aim += Vector3(pv.x, 0, pv.z) * clampf(origin.distance_to(aim) / mdata.projectile_speed, 0.0, 0.6) * 0.5
	var dir := (aim - origin).normalized().rotated(Vector3.UP, spread)
	p.velocity = dir * mdata.projectile_speed
	p.lifetime = 2.5
	p.color = mdata.projectile_color
	p.mask = Layers.TERRAIN | Layers.PLAYER | Layers.BUILDING
	p.exclude = [get_rid()]
	var dmg := mdata.projectile_damage * damage_mult
	var dtype := mdata.projectile_type
	var st := mdata.projectile_status
	var src := self
	p.info_builder = func(_t: Node) -> DamageInfo:
		var info := DamageInfo.create(dmg, src if is_instance_valid(src) else null, dtype)
		info.direction = dir
		info.knockback = dir * 2.0
		info.poise_damage = 8.0
		if not st.is_empty():
			info.status_effects = [st]
		return info
	get_parent().add_child(p)
	p.global_position = origin


func _summon() -> void:
	if mdata.summon == null or World.instance == null:
		return
	var scene := load("res://scenes/enemies/monster.tscn") as PackedScene
	for k in mdata.summon_count + (1 if enraged else 0):
		var a := TAU * k / maxf(1.0, mdata.summon_count)
		var pos := global_position + Vector3(cos(a), 0.3, sin(a)) * 2.5
		var m := World.instance.spawner.spawn_enemy(scene, pos, "", mdata.summon) as Monster
		if m:
			m.configure(power * 0.35, damage_mult, level_bonus, xp_mult * 0.3)
			m.leash_mult = 3.0
			var pl := _player()
			if pl:
				m._alert(pl)
		VFX.burst(get_parent(), pos + Vector3(0, 1, 0), 1.2, Color(0.8, 0.4, 1.0, 0.8))


func _line_of_sight(player: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.3, 0)
	var to := player.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.TERRAIN | Layers.BUILDING)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _move_dir(dir: Vector3, speed: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	face_toward(dir)
	_desired_velocity = dir.normalized() * speed


func _alert(player: Node3D) -> void:
	target = player
	(model as MonsterModel).show_alert()
	_set_ai(AI.ALERT, 0.5)


func _on_hit_reaction(info: DamageInfo) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN, AI.DORMANT] and info.source is Node3D:
		_alert(info.source)


func is_charging() -> bool:
	return ai == AI.CHARGE


func _on_taunted(source: Node3D) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN, AI.ALERT, AI.DORMANT]:
		target = source
		_set_ai(AI.CHASE)


func _on_lost_target() -> void:
	if ai in [AI.CHASE, AI.ALERT]:
		_set_ai(AI.RETURN, 12.0)


func _on_staggered() -> void:
	if ai != AI.DORMANT:
		_set_ai(AI.CHASE)
		_atk_cd = 0.6


func on_parried() -> void:
	_set_ai(AI.RECOVER, 1.5 if not is_boss() else 0.9)
	Events.damage_dealt.emit(global_position + Vector3(0, 2.2 * mdata.model_scale, 0), 0.0, false, false, "Stunned")


func _on_died() -> void:
	if is_boss():
		Events.boss_ended.emit(self)
	super._on_died()


func _physics_process(delta: float) -> void:
	if ai == AI.DORMANT and not is_dead:
		_apply_gravity(delta)
		move_and_slide()
		_think(delta)
		return
	super._physics_process(delta)
