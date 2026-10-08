class_name Monster
extends Enemy
## Generic data-driven monster AI (Milestone 6, extended in Milestone 7).
##
## MELEE: chase, light attacks, optional heavy telegraphed attack.
## RANGED / CASTER: keep a preferred distance, aim (telegraph) and shoot
## projectiles when they have line of sight.
## BOSS: melee plus a cycle of special moves and an enrage phase.
##
## Milestone 7 - advanced AI:
##   * group tactics: attack tokens (CombatDirector) - only two monsters swing
##     at you at once, the rest circle around you and wait for an opening
##   * steering around cliffs, walls and trees (feeler rays) + separation
##   * pack alerts, dodging your swings, fleeing when badly hurt
##   * support casters that heal, haste or shield their allies
##   * elite affixes (EliteAffixes): vampiric, frenzied, molten, glacial,
##     shielded, thorned, blinking, juggernaut, venomous
##   * boss phases (new move lists, arena hazards, invulnerable roar), boss
##     "Broken!" state when poise breaks, and new boss moves: spikes, nova,
##     beam, meteor_rain, teleport, shield (ward pylons), pull, roar, bomb
##   * raiders (RaidManager): march on an objective, smash buildings in the
##     way and fight town guards
##
## Rank scaling (dungeons E..S, far-away ruins): configure() multiplies health,
## damage, level and XP per instance, so one MonsterData serves every rank.

enum AI { IDLE, WANDER, ALERT, CHASE, ATTACK, SHOOT, SLAM, VOLLEY, CHARGE_WINDUP, CHARGE, SUMMON, RECOVER, RETURN, DORMANT,
	DODGE, FLEE, SUPPORT, SPIKES, NOVA, BEAM, TELEPORT, PULL, ROAR, PHASE, MARCH, METEOR, BOMB, SHIELD }

const MONSTER_SCENE_PATH := "res://scenes/enemies/monster.tscn"
const STEER_MASK := Layers.TERRAIN | Layers.BUILDING | Layers.PROP
const BEAM_LENGTH := 15.0

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
## Elite affixes (empty for normal monsters).
var affixes: Array[StringName] = []
## Elite shield / ward HP (absorbs damage first).
var barrier := 0.0
var barrier_max := 0.0
## Boss phase index (0 = first phase).
var phase := 0
## True while ward pylons protect the boss.
var warded := false
## Raids: where the raiders march (Vector3.INF = not a raider) and which raid they belong to.
var objective := Vector3.INF
var raid_id := ""

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
var _size := 1.0
var _slot_angle := 0.0
var _avoid_angle := 0.0
var _avoid_t := 0.0
var _blocker: Node3D
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _iframes := 0.0
var _fled := false
var _support_cd := 2.0
var _support_target: Monster
var _blink_cd := 5.0
var _barrier_idle := 0.0
var _phase_moves: Array = []
var _hazard: StringName = &""
var _hazard_cd := 4.0
var _pylons: Array[WardPylon] = []
var _ward_time := 0.0
var _beam_dir := Vector3.ZERO
var _beam_node: MeshInstance3D
var _beam_tick := 0.0
var _spike_left := 0
var _spike_t := 0.0
var _aura: Node3D
var _stuck_t := 0.0
var _detour_t := 0.0
var _detour_angle := 0.0
var _hop_cd := 0.0
## Milestone 15: buried until woken (sand scorpions).
var _burrowed := false
var _sand_t := 0.0


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


## Turns this monster into an elite (1 affix) or champion (2+). Call after configure().
func make_elite(p_affixes: Array) -> void:
	if p_affixes.is_empty():
		return
	affixes.clear()
	for a in p_affixes:
		affixes.append(StringName(a))
	var hp_mult := EliteAffixes.POWER * (1.5 if affixes.has(&"juggernaut") else 1.0)
	power *= hp_mult
	damage_mult *= EliteAffixes.DAMAGE
	level_bonus += EliteAffixes.LEVELS * affixes.size()
	xp_mult *= EliteAffixes.XP * affixes.size()
	health.max_health = data.max_health * power
	health.reset_full()
	_size = EliteAffixes.SIZE
	_apply_shape()
	if affixes.has(&"shielded"):
		barrier_max = health.max_health * 0.3
		barrier = barrier_max
	if affixes.has(&"juggernaut"):
		status.immune = Array([&"stunned", &"frozen", &"chilled", &"slowed"], TYPE_STRING_NAME, &"", null)
	set_meta(&"elite", true)
	_build_aura(EliteAffixes.color_of(affixes[0]))
	(model as MonsterModel).set_outline(EliteAffixes.color_of(affixes[0]))


func is_elite() -> bool:
	return not affixes.is_empty()


## Sends this monster on a raid: march to `target_pos` and attack what's there.
func set_raid(target_pos: Vector3, id: String) -> void:
	objective = target_pos
	raid_id = id
	home_position = target_pos
	leash_mult = 100.0
	_set_ai(AI.MARCH, 60.0)


func effective_level() -> int:
	return (data.level if data else 1) + level_bonus


func xp_value() -> int:
	return roundi((data.xp_reward if data else 10) * xp_mult)


func is_boss() -> bool:
	return mdata != null and mdata.style == MonsterData.Style.BOSS


func display_name() -> String:
	var base := mdata.boss_title if is_boss() and mdata.boss_title != "" else super.display_name()
	if affixes.is_empty():
		return base
	var pre := PackedStringArray()
	for a in affixes:
		pre.append(EliteAffixes.display(a))
	return "%s %s%s" % [" ".join(pre), base, " (Champion)" if affixes.size() > 1 else ""]


func _on_spawned() -> void:
	CombatDirector.release(self)
	mdata = data as MonsterData
	power = 1.0
	damage_mult = 1.0
	level_bonus = 0
	xp_mult = 1.0
	leash_mult = 1.0
	wake_range = 0.0
	enraged = false
	affixes.clear()
	barrier = 0.0
	barrier_max = 0.0
	phase = 0
	warded = false
	objective = Vector3.INF
	raid_id = ""
	status.immune.clear()
	_clear_pylons()
	_end_beam()
	_phase_moves = []
	_hazard = &""
	_fled = false
	_size = 1.0
	_summons_done = 0
	_move_i = 0
	_iframes = 0.0
	_blocker = null
	for meta in [&"elite", &"raid", &"event"]:
		if has_meta(meta):
			remove_meta(meta)
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	(model as MonsterModel).build(mdata)
	(model as MonsterModel).reset_pose()
	model.visible = true
	model.position.y = 0.0
	_burrowed = false
	_apply_shape()
	_slot_angle = _rng.randf() * TAU
	_atk_cd = 0.5
	_heavy_cd = mdata.heavy_cooldown * 0.5
	_shot_cd = _rng.randf_range(0.5, mdata.projectile_cooldown)
	_special_cd = 3.0
	_support_cd = _rng.randf_range(1.0, 3.0)
	_blink_cd = 5.0
	_dodge_cd = 0.0
	_set_ai(AI.IDLE, _rng.randf_range(0.5, 2.5))
	if mdata.burrow_range > 0.0:
		_burrowed = true
		model.position.y = -0.62  # only the sting tip pokes out
		make_dormant(mdata.burrow_range)


func _apply_shape() -> void:
	var s := mdata.model_scale * _size
	model.scale = Vector3.ONE * s
	_shape.radius = 0.4 * s
	_shape.height = maxf(1.8 * s, _shape.radius * 2.0)
	$CollisionShape3D.position.y = _shape.height * 0.5
	health_bar.position.y = 2.1 * s


func _build_aura(color: Color) -> void:
	_aura = Node3D.new()
	add_child(_aura)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 20
	torus.ring_segments = 3
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.9, 0.3, 0.9) * mdata.model_scale * _size
	ring.position.y = 0.08
	_aura.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.3
	light.omni_range = 3.5
	light.position.y = 1.2
	_aura.add_child(light)


## Guardians (temple bosses) wait motionless until the player comes near.
func make_dormant(range_m: float) -> void:
	wake_range = range_m
	_set_ai(AI.DORMANT)


func _set_ai(new_ai: AI, time: float = 0.0) -> void:
	if ai == AI.ATTACK and new_ai != AI.ATTACK:
		CombatDirector.release(self)
	if ai == AI.BEAM and new_ai != AI.BEAM:
		_end_beam()
	ai = new_ai
	ai_time = time
	_hit_done = false
	exposed = new_ai == AI.RECOVER
	(model as MonsterModel).set_telegraph(new_ai in [AI.SLAM, AI.CHARGE_WINDUP, AI.NOVA, AI.ROAR, AI.PULL]
		or (new_ai == AI.ATTACK and _cur == mdata.heavy and _cur != null))
	if new_ai in [AI.CHARGE, AI.DODGE]:
		collision_mask &= ~Layers.PLAYER
	else:
		collision_mask |= Layers.PLAYER
	if _zone and is_instance_valid(_zone) and not new_ai in [AI.SLAM, AI.NOVA]:
		_zone.queue_free()
		_zone = null


# --- Targets ------------------------------------------------------------------------------

func _player() -> Node3D:
	# Milestone 17c: a tamed beast hunts the enemies near the player and stays close to them.
	if has_meta(&"tamed_until"):
		if is_tamed():
			var owner_p := get_tree().get_first_node_in_group(&"player") as Node3D
			if owner_p:
				home_position = owner_p.global_position
			var best: Node3D = null
			var bd := 14.0
			for e in get_tree().get_nodes_in_group(&"enemies"):
				var n := e as Node3D
				if n == null or n == self or n.get("is_dead") or not n.is_visible_in_tree():
					continue
				var d := n.global_position.distance_to(global_position)
				if d < bd:
					bd = d
					best = n
			return best
		untame()
	# Milestone 17b: blinded monsters (Smoke Bomb, Blind Powder) lose you; a Shadow Clone draws them.
	if int(get_meta(&"blind_until", 0)) > Time.get_ticks_msec() and not is_taunted():
		return null
	for d in get_tree().get_nodes_in_group(&"decoys"):
		if d is Node3D and (d as Node3D).global_position.distance_to(global_position) < 14.0:
			return d
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null or p.get("is_dead") or p.get("frozen"):
		return null
	if p.has_method("is_stealthed") and p.is_stealthed() and not is_taunted() \
			and p.global_position.distance_to(global_position) > 2.2:
		return null
	return p


func _is_raider() -> bool:
	return objective != Vector3.INF


## `t` is untyped on purpose: it may be a freed object (a destroyed wall).
func _alive(t) -> bool:
	if t == null or not is_instance_valid(t) or not t is Node3D:
		return false
	return (t as Node3D).is_inside_tree() and t.get("is_dead") != true \
		and (not t.has_method("can_be_attacked") or t.can_be_attacked())


## The player, or for raiders a guard/villager or a building piece in the way.
func _pick_target() -> Node3D:
	var p := _player()
	if not _is_raider():
		return p
	var pd := INF if p == null else _flat_dist(p)
	if _alive(target) and target != p and pd > data.aggro_range * 0.5 and _flat_dist(target) < data.aggro_range * 1.8:
		return target
	if p and pd < data.aggro_range:
		return p
	var best: Node3D = null
	var bd := data.aggro_range
	for n in get_tree().get_nodes_in_group(&"npcs"):
		var npc := n as Node3D
		if not _alive(npc) or not npc.is_visible_in_tree():
			continue
		var d := _flat_dist(npc)
		if d < bd:
			bd = d
			best = npc
	return best


func _flat_dist(t: Node3D) -> float:
	var d := Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
	if t is BuildPiece:
		d = maxf(0.0, d - 0.7)
	return d


func _think(delta: float) -> void:
	ai_time -= delta
	_atk_cd -= delta
	_heavy_cd -= delta
	_shot_cd -= delta
	_special_cd -= delta
	_dodge_cd -= delta
	_support_cd -= delta
	_iframes -= delta
	_desired_velocity = Vector3.ZERO
	var tgt := _pick_target()
	var to_t := Vector3.ZERO
	var dist := INF
	if tgt:
		to_t = tgt.global_position - global_position
		to_t.y = 0.0
		dist = _flat_dist(tgt)
	if is_boss() and not enraged and health.get_ratio() <= mdata.enrage_at:
		enraged = true
		Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Enraged!")
		Events.camera_shake.emit(0.4)
		VFX.ring(get_parent(), global_position, 6.0, Color(1, 0.3, 0.2, 0.8), 0.6)
	if is_boss() and ai != AI.DORMANT and ai != AI.PHASE:
		_update_phase()
	_update_affixes(delta, tgt, dist)
	_update_ward(delta)
	if _hazard != &"" and ai not in [AI.IDLE, AI.WANDER, AI.RETURN, AI.DORMANT] and tgt:
		_hazard_cd -= delta
		if _hazard_cd <= 0.0:
			_hazard_cd = 4.5 if enraged else 6.5
			_drop_hazards(tgt)

	match ai:
		AI.DORMANT:
			if _burrowed:
				# The only tell: a little sand moving now and then.
				_sand_t -= delta
				if _sand_t <= 0.0:
					_sand_t = _rng.randf_range(1.2, 2.4)
					if tgt and dist < 30.0:
						VFX.dust(get_parent(), global_position + Vector3(0, 0.1, 0), Color(0.86, 0.76, 0.52, 0.8), 4)
			if tgt and dist < wake_range:
				if not _burrowed:
					Events.toast.emit("%s awakens!" % display_name(), Color(1, 0.6, 0.3))
				_alert(tgt)
		AI.IDLE:
			if tgt and dist < notice_range(tgt):
				_alert(tgt)
			elif _is_raider() and global_position.distance_to(objective) > 8.0:
				_set_ai(AI.MARCH, 60.0)
			elif ai_time <= 0.0:
				var a := _rng.randf() * TAU
				var center := objective if _is_raider() else home_position
				_wander_target = center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.5, 5.0 * minf(leash_mult, 2.0))
				_set_ai(AI.WANDER, 6.0)
		AI.WANDER:
			if tgt and dist < notice_range(tgt):
				_alert(tgt)
			else:
				var to := _wander_target - global_position
				to.y = 0.0
				if to.length() < 0.6 or ai_time <= 0.0:
					_set_ai(AI.IDLE, _rng.randf_range(2.0, 5.0))
				else:
					_move_dir(to, data.walk_speed)
		AI.MARCH:
			_march(tgt, dist)
		AI.ALERT:
			if tgt:
				face_toward(to_t)
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
				if is_boss() and tgt and tgt.is_in_group(&"player"):
					Events.boss_started.emit(self)
		AI.CHASE:
			if tgt == null:
				if _is_raider():
					_set_ai(AI.MARCH, 60.0)
				else:
					_set_ai(AI.RETURN, 12.0)
			elif not _is_raider() and (global_position.distance_to(home_position) > data.leash_range * leash_mult \
					or dist > data.aggro_range * 3.0):
				_set_ai(AI.RETURN, 12.0)
			else:
				_combat(tgt, to_t, dist)
		AI.ATTACK:
			_do_attack(tgt, to_t, dist)
		AI.SHOOT:
			if tgt:
				face_toward(to_t)
			if ai_time <= 0.0:
				if tgt:
					_fire(tgt, 0.0)
				_shot_cd = mdata.projectile_cooldown * (0.65 if enraged else 1.0) / _speed_affix()
				_set_ai(AI.CHASE)
		AI.SLAM:
			if ai_time <= 0.0:
				_slam(mdata.slam_radius, mdata.slam_damage, 9.0)
				_set_ai(AI.RECOVER, 0.7)
		AI.NOVA:
			if ai_time <= 0.0:
				_slam(mdata.nova_radius, mdata.slam_damage * 1.2, 12.0)
				VFX.ring(get_parent(), global_position, mdata.nova_radius, Color(mdata.accent.r, mdata.accent.g, mdata.accent.b, 0.9), 0.5)
				_set_ai(AI.RECOVER, 0.9)
		AI.VOLLEY:
			if tgt:
				face_toward(to_t)
			if ai_time <= 0.0 and tgt:
				var n := mdata.volley_count + (2 if enraged else 0)
				for k in n:
					_fire(tgt, (k - (n - 1) * 0.5) * 0.18)
				_set_ai(AI.RECOVER, 0.6)
		AI.CHARGE_WINDUP:
			if tgt and ai_time > 0.25:
				face_toward(to_t)
			if ai_time <= 0.0:
				_charge_dir = get_facing()
				_set_ai(AI.CHARGE, 0.75)
		AI.CHARGE:
			_desired_velocity = _charge_dir * data.run_speed * 2.6
			velocity.x = _desired_velocity.x
			velocity.z = _desired_velocity.z
			if not _hit_done and tgt and dist <= 1.6 * mdata.model_scale:
				_hit_done = true
				_hit_target(tgt, mdata.heavy if mdata.heavy else mdata.melee, 1.3)
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
			if tgt and dist < data.aggro_range * 0.6 and global_position.distance_to(home_position) < data.leash_range * leash_mult * 0.8:
				_alert(tgt)
			elif home.length() < 1.0 or ai_time <= 0.0:
				health.reset_full()
				health_bar.set_ratio(1.0)
				health_bar.hide_now()
				if is_boss():
					Events.boss_ended.emit(self)
				_set_ai(AI.IDLE, 2.0)
			else:
				_move_dir(home, data.walk_speed * 1.6)
		AI.DODGE:
			_desired_velocity = _dodge_dir * 8.5
			if ai_time <= 0.0:
				_set_ai(AI.CHASE)
		AI.FLEE:
			if tgt:
				_move_dir(-to_t, data.run_speed * 1.15 * _speed_affix())
			if ai_time <= 0.0:
				if mdata.flee_below >= 1.0 and tgt and dist < data.aggro_range * 1.5:
					_set_ai(AI.FLEE, 3.0)
				else:
					_set_ai(AI.CHASE if tgt and mdata.flee_below < 1.0 else AI.IDLE, 1.0)
		AI.SUPPORT:
			if ai_time <= 0.0:
				_do_support()
				_set_ai(AI.CHASE)
		AI.SPIKES:
			_spike_t -= delta
			if tgt:
				face_toward(to_t)
			if _spike_t <= 0.0 and _spike_left > 0 and tgt:
				_spike_left -= 1
				_spike_t = 0.35
				var h := _hazard_at(tgt.global_position, 1.6, 0.7, mdata.slam_damage * 0.6, &"physical")
				h.style = &"spikes"
				h.status_effect = mdata.spike_status
				h.tag = "Spikes"
			if _spike_left <= 0 and _spike_t <= 0.0:
				_set_ai(AI.RECOVER, 0.6)
		AI.BEAM:
			_update_beam(delta, tgt)
			if ai_time <= 0.0:
				_set_ai(AI.RECOVER, 0.8)
		AI.TELEPORT:
			if ai_time <= 0.0:
				_teleport_behind(tgt)
				model.visible = true
				if tgt and (mdata.heavy or mdata.melee):
					_start_attack(mdata.heavy if mdata.heavy else mdata.melee)
				else:
					_set_ai(AI.CHASE)
		AI.PULL:
			var pl := _player()
			if pl and pl.has_method("set_pull") and _flat_dist(pl) < 14.0:
				var dir := global_position - pl.global_position
				dir.y = 0.0
				pl.set_pull(dir.normalized() * 4.5, 0.1)
			if ai_time <= 0.0:
				var t := 0.6
				_zone = VFX.danger_zone(get_parent(), global_position, mdata.slam_radius, t)
				(model as MonsterModel).play_attack(&"overhead", t, 0.1, 0.5)
				_set_ai(AI.SLAM, t)
		AI.ROAR:
			if ai_time <= 0.0:
				_roar()
				_set_ai(AI.RECOVER, 0.5)
		AI.PHASE:
			if ai_time <= 0.0:
				_special_cd = 0.6
				_set_ai(AI.CHASE)
		AI.METEOR:
			if ai_time <= 0.0 and tgt:
				var center := tgt.global_position
				for k in 6 + (2 if enraged else 0):
					var a := _rng.randf() * TAU
					var off := Vector3(cos(a), 0, sin(a)) * (0.0 if k == 0 else _rng.randf_range(1.5, 7.0))
					var h := _hazard_at(center + off, 2.2, 1.0 + k * 0.15, mdata.slam_damage * 0.7, &"fire")
					h.style = &"meteor"
					h.status_effect = [&"burn", 3.0, {"dps": 4.0}]
					h.tag = "Meteor"
				_set_ai(AI.RECOVER, 0.6)
		AI.BOMB:
			if ai_time <= 0.0 and tgt:
				for k in 3:
					var off := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5)) if k > 0 else Vector3.ZERO
					var h := _hazard_at(tgt.global_position + off, 2.0, 1.1 + k * 0.2, mdata.projectile_damage * 1.4, &"fire")
					h.style = &"meteor"
					h.status_effect = [&"burn", 3.0, {"dps": 3.0}]
					h.tag = "Bomb"
				_set_ai(AI.RECOVER, 0.5)
		AI.SHIELD:
			if ai_time <= 0.0:
				_raise_ward()
				_set_ai(AI.CHASE)
	(model as MonsterModel).set_locomotion(Vector2(velocity.x, velocity.z).length(), delta)


# --- Raids --------------------------------------------------------------------------------

## Marching on the raid objective; smash what blocks the way, then what's there.
func _march(tgt: Node3D, dist: float) -> void:
	if tgt and dist < notice_range(tgt):
		_alert(tgt)
		return
	if _alive(_blocker) and _blocker is BuildPiece:
		target = _blocker
		_blocker = null
		_set_ai(AI.CHASE)
		return
	var to := objective - global_position
	to.y = 0.0
	if to.length() < 6.0 or ai_time <= 0.0:
		var piece := _nearest_piece(14.0)
		if piece:
			target = piece
			_set_ai(AI.CHASE)
		else:
			_set_ai(AI.IDLE, 2.0)
		return
	_move_dir(to, data.run_speed * 0.85)


func _nearest_piece(r: float) -> Node3D:
	if World.instance == null or World.instance.building == null:
		return null
	var best: Node3D = null
	var bd := r
	for piece in World.instance.building.pieces_near(global_position, r):
		var d := _flat_dist(piece)
		if d < bd:
			bd = d
			best = piece
	return best


# --- Combat -------------------------------------------------------------------------------

## Chasing: pick the next action for this style.
func _combat(tgt: Node3D, to_t: Vector3, dist: float) -> void:
	face_toward(to_t)
	var speed_mult := (1.3 if enraged else 1.0) * _speed_affix()
	var silenced := status.is_silenced()
	var is_player := tgt.is_in_group(&"player")
	# Badly hurt: run away (once), then come back.
	if mdata.flee_below > 0.0 and not _fled and not is_boss() and health.get_ratio() <= mdata.flee_below:
		_fled = mdata.flee_below < 1.0
		if not mdata.timid:
			Events.damage_dealt.emit(global_position + Vector3(0, 2.4, 0), 0.0, false, false, "Flees!")
		_set_ai(AI.FLEE, 4.0)
		return
	# Sidestep your swings.
	if is_player and mdata.dodge_chance > 0.0 and _dodge_cd <= 0.0 and dist < 3.5 \
			and tgt.get("combat") != null and tgt.combat.is_attacking():
		_dodge_cd = 2.5
		if _rng.randf() < mdata.dodge_chance:
			var side := to_t.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_dodge_dir = (side - to_t.normalized() * 0.6).normalized()
			_iframes = 0.3
			Events.damage_dealt.emit(global_position + Vector3(0, 2.2, 0), 0.0, false, false, "Dodge!")
			_set_ai(AI.DODGE, 0.3)
			return
	if mdata.support != &"" and _support_cd <= 0.0 and not silenced and _try_support():
		return
	if is_boss() and _special_cd <= 0.0 and not silenced:
		var moves := _moves()
		if not moves.is_empty():
			var move: StringName = StringName(moves[_move_i % moves.size()])
			_move_i += 1
			_special_cd = (2.6 if enraged else 4.2)
			if _start_special(move, dist, tgt):
				return
	match mdata.style:
		MonsterData.Style.RANGED, MonsterData.Style.CASTER:
			if dist <= (mdata.melee.reach if mdata.melee else 0.0) and _atk_cd <= 0.0:
				_start_attack(mdata.melee)
			elif _shot_cd <= 0.0 and not silenced and dist <= mdata.preferred_max * 1.6 and _line_of_sight(tgt):
				_set_ai(AI.SHOOT, mdata.projectile_windup / _speed_affix())
				(model as MonsterModel).play_attack(&"overhead", mdata.projectile_windup / _speed_affix(), 0.1, 0.3)
			elif dist < mdata.preferred_min:
				_move_dir(-to_t, data.walk_speed * speed_mult)
				face_toward(to_t)
			elif dist > mdata.preferred_max:
				_move_dir(to_t, data.run_speed * speed_mult)
			else:
				# Strafe around the target (flanking) so ranged foes don't stand still.
				var side := to_t.cross(Vector3.UP).normalized() * (1.0 if int(Time.get_ticks_msec() / 1500 + _slot_angle * 10.0) % 2 == 0 else -1.0)
				_move_dir(side, data.walk_speed * 0.6)
				face_toward(to_t)
		_:
			var reach := mdata.melee.reach if mdata.melee else 1.5
			var need_token := is_player or tgt is NPC
			if mdata.heavy and _heavy_cd <= 0.0 and dist <= mdata.heavy.reach and (not need_token or is_boss() or CombatDirector.request(self, tgt)):
				_start_attack(mdata.heavy)
			elif mdata.melee and dist <= reach and _atk_cd <= 0.0 and (not need_token or is_boss() or CombatDirector.request(self, tgt)):
				_start_attack(mdata.melee)
			elif need_token and not is_boss() and dist < CombatDirector.RING + 2.5 \
					and CombatDirector.attackers_of(tgt) >= CombatDirector.MAX_MELEE:
				# Wait for an opening: circle the target at our slot.
				_slot_angle += get_physics_process_delta_time() * 0.35
				var spot := CombatDirector.circle_point(tgt.global_position, _slot_angle)
				var to_spot := spot - global_position
				to_spot.y = 0.0
				if to_spot.length() > 0.5:
					_move_dir(to_spot, data.walk_speed * 1.1)
				face_toward(to_t)
			elif dist > reach * 0.8:
				_move_dir(to_t, data.run_speed * speed_mult)


func _moves() -> Array:
	return _phase_moves if not _phase_moves.is_empty() else mdata.boss_moves


func _start_special(move: StringName, dist: float, tgt: Node3D) -> bool:
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
		&"nova":
			var t := 1.2 if enraged else 1.5
			_zone = VFX.danger_zone(get_parent(), global_position, mdata.nova_radius, t)
			(model as MonsterModel).play_attack(&"overhead", t, 0.1, 0.5)
			Events.damage_dealt.emit(global_position + Vector3(0, 3.2 * mdata.model_scale, 0), 0.0, false, false, "Get away!")
			_set_ai(AI.NOVA, t)
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
		&"spikes":
			_spike_left = 5 + (2 if enraged else 0)
			_spike_t = 0.3
			(model as MonsterModel).play_attack(&"overhead", 0.3, 0.1, 0.3)
			_set_ai(AI.SPIKES, 4.0)
			return true
		&"beam":
			if dist < 16.0:
				_start_beam(tgt)
				return true
		&"meteor_rain":
			(model as MonsterModel).play_attack(&"overhead", 0.8, 0.1, 0.4)
			Events.damage_dealt.emit(global_position + Vector3(0, 3.2 * mdata.model_scale, 0), 0.0, false, false, "Meteors!")
			_set_ai(AI.METEOR, 0.8)
			return true
		&"bomb":
			(model as MonsterModel).play_attack(&"overhead", 0.6, 0.1, 0.3)
			_set_ai(AI.BOMB, 0.6)
			return true
		&"teleport":
			if dist > 2.5 and tgt:
				VFX.burst(get_parent(), global_position + Vector3(0, 1.2, 0), 2.0 * mdata.model_scale, Color(mdata.accent.r, mdata.accent.g, mdata.accent.b, 0.8))
				model.visible = false
				_set_ai(AI.TELEPORT, 0.5)
				return true
		&"shield":
			if not warded and _pylons.is_empty() and health.get_ratio() < 0.9:
				Events.damage_dealt.emit(global_position + Vector3(0, 3.2 * mdata.model_scale, 0), 0.0, false, false, "Raises a ward!")
				(model as MonsterModel).play_attack(&"overhead", 1.0, 0.1, 0.4)
				_set_ai(AI.SHIELD, 1.0)
				return true
		&"pull":
			if dist < 13.0 and tgt.is_in_group(&"player"):
				Events.damage_dealt.emit(global_position + Vector3(0, 3.2 * mdata.model_scale, 0), 0.0, false, false, "Pulls you in!")
				_set_ai(AI.PULL, 1.3)
				return true
		&"roar":
			if dist < 7.0:
				(model as MonsterModel).play_attack(&"overhead", 0.6, 0.1, 0.4)
				_set_ai(AI.ROAR, 0.6)
				return true
	return false


func _start_attack(a: AttackData) -> void:
	if a == null:
		return
	_cur = a
	var speed := (0.75 if enraged else 1.0) / _speed_affix()
	_set_ai(AI.ATTACK, a.total_duration() * speed)
	(model as MonsterModel).play_attack(a.animation, a.windup * speed, a.active * speed, a.recovery * speed)
	# Milestone 18b: every heavy attack shows the same red ground warning that fills up before it hits.
	if a == mdata.heavy and a.windup * speed >= 0.25:
		var reach := a.reach * maxf(1.0, mdata.model_scale * 0.8)
		_zone = VFX.danger_zone(get_parent(), global_position + get_facing() * reach * 0.5, reach * 0.65, a.windup * speed)
	if a == mdata.heavy:
		_heavy_cd = mdata.heavy_cooldown * (0.7 if enraged else 1.0)
	else:
		_atk_cd = a.total_duration() + 0.4


func _do_attack(tgt: Node3D, to_t: Vector3, dist: float) -> void:
	var a := _cur
	var speed := (0.75 if enraged else 1.0) / _speed_affix()
	var after_windup := (a.active + a.recovery) * speed
	if ai_time > after_windup:
		if tgt:
			face_toward(to_t)  # track during the windup only
		if a.lunge_speed > 0.0:
			_desired_velocity = get_facing() * a.lunge_speed
	elif not _hit_done:
		_hit_done = true
		(model as MonsterModel).set_telegraph(false)
		if tgt and dist <= a.reach * maxf(1.0, mdata.model_scale * 0.8) \
				and (tgt is BuildPiece or get_facing().angle_to(to_t.normalized()) < deg_to_rad(a.arc_degrees) * 0.5):
			_hit_target(tgt, a, 1.0)
		if a.camera_shake > 0.0:
			Events.camera_shake.emit(a.camera_shake)
	if ai_time <= 0.0:
		_set_ai(AI.CHASE)


## Statuses this monster's melee applies (data + affixes).
func _melee_statuses() -> Array:
	var out := []
	if not mdata.melee_status.is_empty():
		out.append(mdata.melee_status)
	if affixes.has(&"molten"):
		out.append([&"burn", 3.0, {"dps": 4.0 * damage_mult}])
	if affixes.has(&"glacial"):
		out.append([&"chilled", 2.5, {}])
	if affixes.has(&"venomous"):
		out.append([&"poison", 5.0, {"dps": 3.0 * damage_mult}])
	return out


func _hit_target(t: Node3D, a: AttackData, extra: float) -> void:
	if a == null or t == null or not t.has_method("receive_hit"):
		return
	var amount := a.damage * damage_mult * extra * status.outgoing_mult()
	if t is BuildPiece:
		amount *= mdata.siege_mult
	var info := DamageInfo.create(amount, self, a.damage_type)
	var dir := t.global_position - global_position
	dir.y = 0.0
	info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
	info.knockback = info.direction * a.knockback
	info.poise_damage = a.poise_damage
	info.status_effects = _melee_statuses()
	t.receive_hit(info)
	if affixes.has(&"vampiric") and not t is BuildPiece:
		health.heal(amount * 0.3)
		health_bar.set_ratio(health.get_ratio())


## Area hit around the monster (slam, nova). Raiders also hurt townsfolk and buildings.
func _slam(radius: float, dmg: float, kb: float) -> void:
	Events.camera_shake.emit(0.45)
	VFX.ring(get_parent(), global_position, radius, Color(1, 0.5, 0.2, 0.9), 0.4)
	for t in GroundHazard.targets_in_radius(get_tree(), global_position, radius, true, false, _is_raider()):
		var info := DamageInfo.create(dmg * damage_mult * status.outgoing_mult() * (mdata.siege_mult if t is BuildPiece else 1.0), self, &"physical")
		var dir: Vector3 = (t as Node3D).global_position - global_position
		dir.y = 0.0
		info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
		info.knockback = info.direction * kb
		info.poise_damage = 40.0
		if not mdata.spike_status.is_empty():
			info.status_effects = [mdata.spike_status]
		t.receive_hit(info)


func _roar() -> void:
	Events.camera_shake.emit(0.5)
	VFX.ring(get_parent(), global_position, 6.5, Color(1, 0.9, 0.6, 0.8), 0.5)
	for t in GroundHazard.targets_in_radius(get_tree(), global_position, 6.5, true, false, _is_raider()):
		if t is BuildPiece:
			continue
		var info := DamageInfo.create(6.0 * damage_mult, self, &"physical")
		var dir: Vector3 = (t as Node3D).global_position - global_position
		dir.y = 0.0
		info.direction = dir.normalized() if dir.length() > 0.01 else get_facing()
		info.knockback = info.direction * 10.0
		info.poise_damage = 50.0
		info.status_effects = [[&"stunned", 1.0, {}], [&"weakened", 6.0, {}]]
		t.receive_hit(info)


func _hazard_at(pos: Vector3, r: float, delay: float, dmg: float, type: StringName) -> GroundHazard:
	if World.instance:
		pos.y = World.instance.get_ground_height(pos)
	var h := GroundHazard.spawn(get_parent(), pos, r, delay, dmg * damage_mult, type, self)
	h.hurts_town = _is_raider()
	h.building_mult = mdata.siege_mult
	return h


## Phase hazards rain down around the target.
func _drop_hazards(tgt: Node3D) -> void:
	for k in 3:
		var a := _rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * (0.0 if k == 0 else _rng.randf_range(2.0, 6.0))
		match _hazard:
			&"falling_rocks":
				var h := _hazard_at(tgt.global_position + off, 1.8, 1.4, 22.0, &"physical")
				h.style = &"meteor"
				h.color = Color(0.55, 0.5, 0.45)
				h.tag = "Rockfall"
			&"fire_rain":
				var h := _hazard_at(tgt.global_position + off, 2.0, 1.3, 18.0, &"fire")
				h.style = &"meteor"
				h.status_effect = [&"burn", 3.0, {"dps": 4.0}]
				h.tag = "Fire rain"
			&"poison_pools":
				var h := _hazard_at(tgt.global_position + off, 2.2, 1.2, 8.0, &"poison")
				h.linger = 5.0
				h.status_effect = [&"poison", 4.0, {"dps": 3.0}]
				h.tag = "Poison"
			&"frost_shards":
				var h := _hazard_at(tgt.global_position + off, 2.0, 1.3, 16.0, &"frost")
				h.style = &"spikes"
				h.status_effect = [&"chilled", 3.0, {}]
				h.tag = "Frost"


# --- Boss phases, ward, beam, teleport --------------------------------------------------------

func _update_phase() -> void:
	if mdata.phases.is_empty() or phase >= mdata.phases.size():
		return
	var ph: Dictionary = mdata.phases[phase]
	if health.get_ratio() > float(ph.get("at", 0.0)):
		return
	phase += 1
	_phase_moves = ph.get("moves", [])
	_move_i = 0
	_hazard = StringName(ph.get("hazard", &""))
	_hazard_cd = 3.0
	var text: String = ph.get("text", "%s grows stronger!" % display_name())
	Events.toast.emit(text, Color(1, 0.55, 0.35))
	Events.damage_dealt.emit(global_position + Vector3(0, 3.4 * mdata.model_scale, 0), 0.0, false, false, "Phase %d" % (phase + 1))
	Events.camera_shake.emit(0.5)
	VFX.ring(get_parent(), global_position, 8.0, Color(mdata.accent.r, mdata.accent.g, mdata.accent.b, 0.9), 0.7)
	(model as MonsterModel).play_attack(&"overhead", 0.8, 0.2, 0.6)
	_set_ai(AI.PHASE, 1.6)


func _raise_ward() -> void:
	_clear_pylons()
	warded = true
	_ward_time = 25.0
	var n := maxi(1, mdata.shield_pylons)
	for k in n:
		var a := TAU * k / n + _rng.randf() * 0.4
		var pos := home_position + Vector3(cos(a), 0, sin(a)) * 6.5
		if World.instance:
			pos.y = World.instance.get_ground_height(pos)
		var p := WardPylon.new()
		p.max_health = 50.0 + 25.0 * power
		p.health = p.max_health
		p.color = mdata.accent
		p.boss = self
		get_parent().add_child(p)
		p.global_position = pos
		p.destroyed.connect(_on_pylon_destroyed)
		_pylons.append(p)
	Events.toast.emit("%s is warded! Destroy the %d pylons." % [display_name(), n], Color(0.8, 0.6, 1.0))


func _on_pylon_destroyed(p: WardPylon) -> void:
	_pylons.erase(p)
	if _pylons.is_empty() and warded:
		warded = false
		Events.toast.emit("The ward shatters!", Color(1, 0.85, 0.4))
		Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Ward broken!")
		_set_ai(AI.RECOVER, 3.0)


func _update_ward(delta: float) -> void:
	if not warded:
		return
	_ward_time -= delta
	if _ward_time <= 0.0:
		# Too slow: the ward drains into the boss and heals it.
		_clear_pylons()
		warded = false
		health.heal(health.max_health * 0.1)
		health_bar.set_ratio(health.get_ratio())
		Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Ward absorbed!")


func _clear_pylons() -> void:
	for p in _pylons:
		if is_instance_valid(p):
			if p.destroyed.is_connected(_on_pylon_destroyed):
				p.destroyed.disconnect(_on_pylon_destroyed)
			p.queue_free()
	_pylons.clear()
	warded = false


func _start_beam(tgt: Node3D) -> void:
	var to := tgt.global_position - global_position
	to.y = 0.0
	_beam_dir = to.normalized() if to.length() > 0.1 else get_facing()
	_beam_tick = 0.3
	_end_beam()
	_beam_node = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.5, 1.0)
	_beam_node.mesh = bm
	var mat := StandardMaterial3D.new()
	var c := mdata.projectile_color
	mat.albedo_color = Color(c.r, c.g, c.b, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_node.material_override = mat
	_beam_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_beam_node)
	(model as MonsterModel).set_telegraph(true)
	Events.damage_dealt.emit(global_position + Vector3(0, 3.2 * mdata.model_scale, 0), 0.0, false, false, "Beam!")
	_set_ai(AI.BEAM, 3.0)


func _update_beam(delta: float, tgt: Node3D) -> void:
	if _beam_node == null or not is_instance_valid(_beam_node):
		return
	var warmup := ai_time > 2.4  # first 0.6 s: thin aiming line, no damage
	if tgt and not warmup:
		var to := tgt.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			var want := to.normalized()
			var ang := _beam_dir.signed_angle_to(want, Vector3.UP)
			var step := deg_to_rad(38.0 if not enraged else 55.0) * delta
			_beam_dir = _beam_dir.rotated(Vector3.UP, clampf(ang, -step, step))
	face_toward(_beam_dir)
	var origin := global_position + Vector3(0, 1.2 * mdata.model_scale, 0)
	_beam_node.global_position = origin + _beam_dir * BEAM_LENGTH * 0.5
	_beam_node.look_at(origin + _beam_dir * BEAM_LENGTH, Vector3.UP)
	_beam_node.scale = Vector3(0.35 if warmup else 1.0, 0.35 if warmup else 1.0, BEAM_LENGTH)
	var c := mdata.projectile_color
	(_beam_node.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.3 if warmup else 0.75)
	if warmup:
		return
	_beam_tick -= delta
	if _beam_tick > 0.0:
		return
	_beam_tick = 0.25
	for t in GroundHazard.targets_in_radius(get_tree(), global_position, BEAM_LENGTH, true, false, _is_raider()):
		var v: Vector3 = (t as Node3D).global_position - global_position
		v.y = 0.0
		var along := v.dot(_beam_dir)
		if along < 0.0 or along > BEAM_LENGTH or (v - _beam_dir * along).length() > 1.0:
			continue
		var info := DamageInfo.create(mdata.beam_damage * damage_mult * status.outgoing_mult(), self, mdata.projectile_type)
		info.direction = _beam_dir
		info.poise_damage = 6.0
		info.tag = "Beam"
		if not mdata.projectile_status.is_empty():
			info.status_effects = [mdata.projectile_status]
		t.receive_hit(info)


func _end_beam() -> void:
	if _beam_node and is_instance_valid(_beam_node):
		_beam_node.queue_free()
	_beam_node = null


func _teleport_behind(tgt: Node3D) -> void:
	if tgt == null:
		return
	var back: Vector3 = tgt.get_facing() if tgt.has_method("get_facing") else Vector3.FORWARD
	var pos := tgt.global_position - back * (1.8 + _shape.radius)
	if World.instance:
		pos.y = World.instance.get_ground_height(pos) + 0.2
	global_position = pos
	var to := tgt.global_position - pos
	to.y = 0.0
	face_toward(to)
	_facing = to.normalized() if to.length() > 0.01 else _facing
	VFX.burst(get_parent(), pos + Vector3(0, 1.2, 0), 2.0 * mdata.model_scale * _size, Color(mdata.accent.r, mdata.accent.g, mdata.accent.b, 0.8))


# --- Elites -------------------------------------------------------------------------------

func _speed_affix() -> float:
	return 1.35 if affixes.has(&"frenzied") else 1.0


func _update_affixes(delta: float, tgt: Node3D, dist: float) -> void:
	if affixes.is_empty():
		return
	if barrier_max > 0.0 and barrier < barrier_max:
		_barrier_idle += delta
		if _barrier_idle > 8.0:
			barrier = barrier_max
			_barrier_idle = 0.0
			Events.damage_dealt.emit(global_position + Vector3(0, 2.6, 0), 0.0, false, false, "Shield restored")
	if affixes.has(&"blinking") and tgt and ai == AI.CHASE:
		_blink_cd -= delta
		if _blink_cd <= 0.0 and dist > 3.0 and dist < 15.0:
			_blink_cd = 7.0
			VFX.burst(get_parent(), global_position + Vector3(0, 1.2, 0), 1.6, Color(0.75, 0.45, 1.0, 0.8))
			_teleport_behind(tgt)
			_atk_cd = 0.0


## Shields, wards, i-frames and thorns. Returns the damage that gets through.
func _modify_incoming(info: DamageInfo) -> float:
	var amount := info.amount
	if ai == AI.PHASE or warded:
		info.tag = "Warded" if warded else "Invulnerable"
		return 0.0
	if _iframes > 0.0:
		info.tag = "Dodged"
		return 0.0
	if affixes.has(&"juggernaut"):
		info.knockback = Vector3.ZERO
		info.poise_damage = 0.0
	if affixes.has(&"thorned") and info.damage_type == &"physical" and info.source is Player \
			and (info.source as Node3D).global_position.distance_to(global_position) < 4.0:
		var back := DamageInfo.create(amount * 0.25, self, &"physical")
		back.tag = "Thorns"
		back.direction = ((info.source as Node3D).global_position - global_position).normalized()
		(info.source as Player).receive_hit(back)
	if barrier > 0.0:
		_barrier_idle = 0.0
		var absorbed := minf(barrier, amount)
		barrier -= absorbed
		amount -= absorbed
		if barrier <= 0.0:
			Events.damage_dealt.emit(global_position + Vector3(0, 2.6, 0), 0.0, false, false, "Shield broken!")
		elif amount <= 0.0:
			info.tag = "Shield"
	return amount


# --- Support casters ------------------------------------------------------------------------

func _try_support() -> bool:
	var best: Monster = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var m := e as Monster
		if m == null or m.is_dead or not m.is_visible_in_tree() or m.global_position.distance_to(global_position) > 12.0:
			continue
		match mdata.support:
			&"heal":
				var r := m.health.get_ratio()
				if r < 0.75 and r < best_score:
					best_score = r
					best = m
			&"haste":
				if m != self and not m.status.has(&"haste") and m.ai in [AI.CHASE, AI.ATTACK]:
					best = m
					break
			&"ward":
				if m != self and m.barrier <= 0.0 and m.ai in [AI.CHASE, AI.ATTACK]:
					best = m
					break
	if best == null:
		_support_cd = 1.5
		return false
	_support_target = best
	(model as MonsterModel).play_attack(&"overhead", 0.8, 0.1, 0.3)
	_set_ai(AI.SUPPORT, 0.8)
	return true


func _do_support() -> void:
	_support_cd = mdata.support_cooldown
	var m := _support_target
	_support_target = null
	if m == null or not is_instance_valid(m) or m.is_dead:
		return
	var pos := m.global_position + Vector3(0, 1.2, 0)
	match mdata.support:
		&"heal":
			var amount := mdata.support_power * power
			m.health.heal(amount)
			m.health_bar.set_ratio(m.health.get_ratio())
			VFX.burst(get_parent(), pos, 1.6, Color(0.4, 1.0, 0.5, 0.7))
			Events.damage_dealt.emit(pos + Vector3(0, 1.0, 0), 0.0, false, false, "Healed +%d" % roundi(amount))
		&"haste":
			for e in get_tree().get_nodes_in_group(&"enemies"):
				var o := e as Monster
				if o and not o.is_dead and o.global_position.distance_to(m.global_position) < 6.0:
					o.status.apply(&"haste", 8.0)
			VFX.ring(get_parent(), m.global_position, 6.0, Color(1.0, 0.9, 0.4, 0.7), 0.4)
		&"ward":
			m.barrier = maxf(m.barrier, mdata.support_power * power)
			VFX.burst(get_parent(), pos, 1.8, Color(0.45, 0.65, 1.0, 0.6))
			Events.damage_dealt.emit(pos + Vector3(0, 1.0, 0), 0.0, false, false, "Warded")


# --- Projectiles, summons, movement -----------------------------------------------------------

func _fire(tgt: Node3D, spread: float) -> void:
	var p := Projectile.new()
	p.launch_sound = &"bow"
	var origin := global_position + Vector3(0, 1.3 * mdata.model_scale, 0) + get_facing() * 0.6
	var aim := tgt.global_position + Vector3(0, 1.0, 0)
	var pv: Vector3 = tgt.get("velocity") if tgt.get("velocity") != null else Vector3.ZERO
	aim += Vector3(pv.x, 0, pv.z) * clampf(origin.distance_to(aim) / mdata.projectile_speed, 0.0, 0.6) * 0.5
	var dir := (aim - origin).normalized().rotated(Vector3.UP, spread)
	p.velocity = dir * mdata.projectile_speed
	p.lifetime = 2.5
	p.color = mdata.projectile_color
	p.mask = Layers.TERRAIN | Layers.PLAYER | Layers.BUILDING | (Layers.NPC if _is_raider() else 0)
	p.exclude = [get_rid()]
	var dmg := mdata.projectile_damage * damage_mult * status.outgoing_mult()
	var dtype := mdata.projectile_type
	var st := mdata.projectile_status
	# Weak: the shooter may die (and be freed) before the projectile lands.
	var src: WeakRef = weakref(self)
	var siege := mdata.siege_mult
	p.info_builder = func(t: Node) -> DamageInfo:
		var info := DamageInfo.create(dmg * (siege if t is BuildPiece else 1.0), src.get_ref() as Node, dtype)
		info.direction = dir
		info.knockback = dir * 2.0
		info.poise_damage = 8.0
		if not st.is_empty():
			info.status_effects = [st]
		return info
	if mdata.projectile_explode_radius > 0.0:
		var r := mdata.projectile_explode_radius
		var raid := _is_raider()
		p.on_impact = func(pos: Vector3) -> void:
			var parent := p.get_parent()
			if parent == null:
				return
			var h := GroundHazard.spawn(parent, pos, r, 0.05, dmg * 0.6, dtype, src.get_ref() as Node)
			h.hurts_town = raid
			h.building_mult = siege
			h.tag = "Blast"
	get_parent().add_child(p)
	p.global_position = origin


func _summon() -> void:
	if mdata.summon == null or World.instance == null:
		return
	var scene := load(MONSTER_SCENE_PATH) as PackedScene
	for k in mdata.summon_count + (1 if enraged else 0):
		var a := TAU * k / maxf(1.0, mdata.summon_count)
		var pos := global_position + Vector3(cos(a), 0.3, sin(a)) * 2.5
		var m := World.instance.spawner.spawn_enemy(scene, pos, "", mdata.summon) as Monster
		if m:
			m.configure(power * 0.35, damage_mult, level_bonus, xp_mult * 0.3)
			m.leash_mult = 3.0
			if _is_raider():
				m.set_raid(objective, raid_id)
				m.set_meta(&"raid", raid_id)
			var pl := _player()
			if pl:
				m._alert(pl)
		VFX.burst(get_parent(), pos + Vector3(0, 1, 0), 1.2, Color(0.8, 0.4, 1.0, 0.8))


func _line_of_sight(tgt: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.3, 0)
	var to := tgt.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.TERRAIN | Layers.BUILDING)
	q.exclude = [get_rid()]
	if tgt is CollisionObject3D:
		q.exclude.append((tgt as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Moves in `dir`, steering around obstacles (feeler rays every 0.2 s) and
## away from crowding monsters. Raiders remember a building in the way.
func _move_dir(dir: Vector3, speed: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var dt := get_physics_process_delta_time()
	_avoid_t -= dt
	if _avoid_t <= 0.0:
		_avoid_t = 0.2
		_avoid_angle = _choose_heading(dir)
	# Stuck (pushing into terrain without moving): hop up ledges, then detour sideways.
	_hop_cd -= dt
	var moving := Vector2(velocity.x, velocity.z).length() > speed * 0.25
	_stuck_t = 0.0 if moving else _stuck_t + dt
	if _stuck_t > 0.25 and is_on_floor() and is_on_wall() and _hop_cd <= 0.0 and not mdata.flying:
		velocity.y = 7.5
		_hop_cd = 0.9
	if _stuck_t > 1.2 and _detour_t <= 0.0:
		_detour_t = 1.6
		_detour_angle = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(1.2, 1.9)
		_stuck_t = 0.0
	var heading := _avoid_angle
	if _detour_t > 0.0:
		_detour_t -= dt
		heading = _detour_angle
	var d := dir.rotated(Vector3.UP, heading)
	face_toward(d)
	var push := CombatDirector.separation(self) if ai != AI.CHARGE else Vector3.ZERO
	_desired_velocity = (d + push * 0.8).normalized() * speed


func _choose_heading(dir: Vector3) -> float:
	if not is_inside_tree():
		return 0.0
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.9 * minf(mdata.model_scale, 1.5), 0)
	var reach := 1.4 + _shape.radius
	for a in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var to := from + dir.rotated(Vector3.UP, a) * reach
		var q := PhysicsRayQueryParameters3D.create(from, to, STEER_MASK)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return a
		if a == 0.0 and _is_raider() and hit.collider is BuildPiece:
			_blocker = hit.collider
			return 0.0
	return 0.0


func _alert(tgt: Node3D) -> void:
	target = tgt
	if _burrowed:
		_unburrow()
	if mdata.timid:
		# Peaceful animals bolt instead of fighting.
		_set_ai(AI.FLEE, 3.0)
		return
	(model as MonsterModel).show_alert()
	_set_ai(AI.ALERT, 0.5)
	if is_elite() and tgt.is_in_group(&"player"):
		_elite_roar()
	if mdata.howls and tgt.is_in_group(&"player"):
		_howl()
	# Pack alert: idle allies nearby join in.
	if mdata.pack_alert > 0.0 and tgt.is_in_group(&"player"):
		for e in get_tree().get_nodes_in_group(&"enemies"):
			var m := e as Monster
			if m and m != self and not m.is_dead and m.ai in [AI.IDLE, AI.WANDER] \
					and m.global_position.distance_to(global_position) < mdata.pack_alert:
				m.target = tgt
				(m.model as MonsterModel).show_alert()
				m._set_ai(AI.ALERT, 0.3 + m._rng.randf() * 0.4)


## Milestone 18b: an elite roars when it sees you (and it lasts the alert pause).
func _elite_roar() -> void:
	var rig = (model as MonsterModel).rig
	if rig is HumanoidModel:
		(rig as HumanoidModel).play_pose(&"roar", 0.6)
	VFX.ring(get_parent(), global_position, 3.0 * mdata.model_scale, EliteAffixes.color_of(affixes[0]), 0.4)
	Audio.play_at(&"monster_growl", global_position, 0.0, 0.1)
	Events.damage_dealt.emit(global_position + Vector3(0, 2.4 * mdata.model_scale, 0), 0.0, false, false, "Roars!")
	ai_time = maxf(ai_time, 0.6)


## Bursts out of the sand (sand scorpions).
func _unburrow() -> void:
	_burrowed = false
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VFX.dust(get_parent(), global_position + Vector3(0, 0.2, 0), Color(0.86, 0.76, 0.52, 0.9), 14)
	Audio.play_at(&"rock_break", global_position, -6.0)


## Wolf howl: the head goes back, and the rest of the pack comes running.
func _howl() -> void:
	var rig = (model as MonsterModel).rig
	if rig and rig.has_method("play_howl"):
		rig.play_howl()
	Events.damage_dealt.emit(global_position + Vector3(0, 1.8, 0), 0.0, false, false, "Howl!")
	Audio.play_at(&"monster_growl", global_position, -2.0, 0.25, 60.0)


func _on_hit_reaction(info: DamageInfo) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN, AI.DORMANT, AI.MARCH] and info.source is Node3D and _alive(info.source):
		_alert(info.source)


func is_charging() -> bool:
	return ai == AI.CHARGE


func _on_taunted(source: Node3D) -> void:
	if ai in [AI.IDLE, AI.WANDER, AI.RETURN, AI.ALERT, AI.DORMANT, AI.MARCH, AI.FLEE]:
		target = source
		_set_ai(AI.CHASE)


func _on_lost_target() -> void:
	if ai in [AI.CHASE, AI.ALERT]:
		_set_ai(AI.MARCH if _is_raider() else AI.RETURN, 12.0)


func _on_staggered() -> void:
	if ai == AI.DORMANT:
		return
	if is_boss() and ai not in [AI.PHASE, AI.RECOVER]:
		# Poise broken: the boss is "Broken!" and exposed for a moment.
		Events.damage_dealt.emit(global_position + Vector3(0, 3.0 * mdata.model_scale, 0), 0.0, false, false, "Broken!")
		_set_ai(AI.RECOVER, 2.2)
		return
	_set_ai(AI.CHASE)
	_atk_cd = 0.6


func on_parried() -> void:
	_set_ai(AI.RECOVER, 1.5 if not is_boss() else 0.9)
	Events.damage_dealt.emit(global_position + Vector3(0, 2.2 * mdata.model_scale, 0), 0.0, false, false, "Stunned")


func on_pool_release() -> void:
	if is_boss() and not is_dead:
		Events.boss_ended.emit(self)
	CombatDirector.release(self)
	_clear_pylons()
	_end_beam()
	super.on_pool_release()


func _on_died() -> void:
	CombatDirector.release(self)
	_clear_pylons()
	_end_beam()
	if is_boss():
		Events.boss_ended.emit(self)
	if is_elite():
		_elite_death()
	super._on_died()


func _elite_death() -> void:
	var parent := get_parent()
	if affixes.has(&"molten"):
		var h := GroundHazard.spawn(parent, global_position, 3.5, 1.2, 28.0 * damage_mult, &"fire", null)
		h.status_effect = [&"burn", 3.0, {"dps": 4.0}]
		h.tag = "Eruption"
	if affixes.has(&"glacial"):
		var h := GroundHazard.spawn(parent, global_position, 4.0, 1.2, 14.0 * damage_mult, &"frost", null)
		h.status_effect = [&"chilled", 4.0, {}]
		h.tag = "Frost burst"
	# Elite loot: an extra roll on the elite table (rank from the level bonus).
	if World.instance:
		var rank := clampi(level_bonus / 4, 0, 5)
		LootTables.give(LootTables.roll(&"elite", rank, _rng), global_position)


func _physics_process(delta: float) -> void:
	if ai == AI.DORMANT and not is_dead:
		_apply_gravity(delta)
		move_and_slide()
		_think(delta)
		return
	super._physics_process(delta)
