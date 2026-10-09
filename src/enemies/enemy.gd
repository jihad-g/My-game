class_name Enemy
extends CharacterBody3D
## Base class for all enemies: health, poise/stagger, knockback, hit reactions,
## death, loot and pooling. Behaviour is implemented by subclasses in _think().
##
## Enemies are pooled: EnemySpawner acquires them from a NodePool, calls
## spawn_at(), and they return themselves to the pool after dying/despawning.

signal enemy_died(enemy: Enemy)

@export var data: EnemyData
@export var gravity: float = 24.0
@export var max_step_height: float = 0.6

## Spawn-slot key used for persistence of kills ("" for debug spawns).
var spawn_key: String = ""
var home_position := Vector3.ZERO
var is_dead: bool = false
var target: Node3D
var poise: float = 0.0
## Designers' "weak window": damage taken is multiplied while exposed.
var exposed: bool = false

@onready var health: HealthComponent = $Health
@onready var model: Node3D = $Model
@onready var health_bar: EnemyHealthBar = $HealthBar
@onready var status: StatusEffects = $Status

var _facing := Vector3(0, 0, 1)
var _knockback := Vector3.ZERO
var _stagger_left := 0.0
var _death_time := 0.0
var _desired_velocity := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _taunt_left := 0.0
var _env_check := 0.0
# Milestone 18b (hack and slash).
## Seconds lying on the ground after a knock-down, and getting up.
const GET_UP_TIME := 0.4
var _down_left := 0.0
var _down_tween: Tween
## When the poise last broke (bosses can only be knocked down right after).
var _poise_break_ms := -100000
## Hit-stop left.
var _freeze_left := 0.0
## Far from every player: think less often (AI level of detail).
const FAR_DISTANCE := 42.0
var _far := false
var _think_acc := 0.0
var _think_skip := 0
var _puffed := false


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.TERRAIN | Layers.PROP | Layers.PLAYER | Layers.ENEMY | Layers.BUILDING
	floor_snap_length = 0.6
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	status.health = health
	status.effect_applied.connect(_on_status_applied)
	status.effect_expired.connect(_on_status_expired)
	status.reaction.connect(func(text: String) -> void:
		Events.damage_dealt.emit(global_position + Vector3(0, 2.6, 0), 0.0, false, false, text))
	Events.target_changed.connect(_on_target_changed)
	_apply_data()


func _apply_data() -> void:
	if data == null:
		return
	health.max_health = data.max_health
	health.damage_multipliers = data.damage_multipliers
	health.reset_full()
	poise = data.max_poise


## Called by the spawner after acquiring from the pool.
func spawn_at(pos: Vector3, key: String) -> void:
	spawn_key = key
	home_position = pos
	global_position = pos
	is_dead = false
	exposed = false
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_stagger_left = 0.0
	_death_time = 0.0
	target = null
	_taunt_left = 0.0
	status.clear()
	_rng.seed = hash(key) ^ Time.get_ticks_usec()
	var a := _rng.randf() * TAU
	_facing = Vector3(sin(a), 0, cos(a))
	_apply_data()
	health.invulnerable = false
	health_bar.set_ratio(1.0)
	health_bar.hide_now()
	_on_spawned()


func on_pool_release() -> void:
	if is_instance_valid(target) and target.get("lock_target") == self:
		target.set_lock_target(null)
	target = null
	# Milestone 17b/c marks from player abilities must not follow a pooled enemy into its next life.
	for m in [&"blind_until", &"sunder", &"sunder_until", &"tamed_until", &"spirit", &"training_dummy"]:
		if has_meta(m):
			remove_meta(m)
	if not is_in_group(&"enemies"):
		add_to_group(&"enemies")
	remove_from_group(&"decoys")
	remove_from_group(&"pets")
	if model:
		model.scale = Vector3.ONE
		model.rotation.x = 0.0
	if _down_tween:
		_down_tween.kill()
	_down_left = 0.0
	_freeze_left = 0.0
	_puffed = false
	if _ice_shell and is_instance_valid(_ice_shell):
		_ice_shell.queue_free()
	_ice_shell = null


## Milestone 17c: a tamed beast (Tame Beast, Spirit Wolf) fights for the player.
func is_tamed() -> bool:
	return int(get_meta(&"tamed_until", 0)) > Time.get_ticks_msec()


func tame(seconds: float) -> void:
	set_meta(&"tamed_until", Time.get_ticks_msec() + int(seconds * 1000.0))
	remove_from_group(&"enemies")
	add_to_group(&"pets")
	target = null


func untame() -> void:
	if has_meta(&"tamed_until"):
		remove_meta(&"tamed_until")
	remove_from_group(&"pets")
	if not is_in_group(&"enemies"):
		add_to_group(&"enemies")


## True while performing a charge/rush (spikes punish it harder).
## Distance at which this enemy notices `t` while idle or wandering: its sight
## range scaled by the target's outfit (light armour is noticed later, heavy
## armour sooner - Milestone 14). Once a fight starts the normal range applies.
func notice_range(t: Node3D) -> float:
	var r: float = data.aggro_range if data else 10.0
	if t and t.has_method("notice_mult"):
		r *= float(t.notice_mult())
	return r


func is_charging() -> bool:
	return false


func get_facing() -> Vector3:
	return _facing


func display_name() -> String:
	return data.display_name if data else "Enemy"


# --- Virtual hooks for subclasses ----------------------------------------------------

func _on_spawned() -> void:
	pass


## Decide what to do this frame; set _desired_velocity and facing.
func _think(_delta: float) -> void:
	pass


func _on_hit_reaction(_info: DamageInfo) -> void:
	pass


func _on_staggered() -> void:
	pass


# --- Core loop --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		_death_time += delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		# Milestone 18b: the body goes up in a puff of dust.
		if _death_time > 2.3 and not _puffed:
			_puffed = true
			if is_inside_tree():
				VFX.dust(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.75, 0.72, 0.68, 0.85), 10)
				VFX.burst(get_parent(), global_position + Vector3(0, 0.6, 0), 0.9, Color(0.85, 0.82, 0.78, 0.5))
		if _death_time > 2.5:
			NodePool.release_or_free(self)
		return
	# Hit-stop (Milestone 18b): hold still for a moment.
	if _freeze_left > 0.0:
		_freeze_left -= delta
		velocity = Vector3.ZERO
		return

	# No terrain collision here yet (chunk still generating): wait instead of falling through.
	var w := World.instance
	if w and w.dungeon == null and not w.chunk_manager.is_collision_ready_at(global_position):
		velocity = Vector3.ZERO
		return
	_taunt_left -= delta
	_down_left = maxf(_down_left - delta, 0.0)
	_env_check -= delta
	if _env_check <= 0.0:
		_env_check = 0.5
		_far = _far_from_players()
		if World.instance and World.instance.dungeon == null and World.instance.is_in_water(global_position):
			if status.has(&"wet"):
				status.effects[&"wet"].time = maxf(float(status.effects[&"wet"].time), 4.0)
			else:
				status.apply(&"wet", 4.0)
	if _stagger_left > 0.0 or status.is_stunned():
		_stagger_left -= delta
		_desired_velocity = Vector3.ZERO
	elif _far and target == null and not _is_boss_enemy():
		# Milestone 18b AI level of detail: far away and idle, think every 4th frame.
		_think_acc += delta
		_think_skip = (_think_skip + 1) % 4
		if _think_skip == 0:
			_think(_think_acc)
			_think_acc = 0.0
			_desired_velocity *= status.speed_mult()
	else:
		_think(delta + _think_acc)
		_think_acc = 0.0
		_desired_velocity *= status.speed_mult()

	var accel := 30.0 * delta
	velocity.x = move_toward(velocity.x, _desired_velocity.x, accel)
	velocity.z = move_toward(velocity.z, _desired_velocity.z, accel)
	velocity += _knockback
	_apply_gravity(delta)
	# Only probe for a step when something stopped us last tick (saves physics queries).
	if is_on_floor() and is_on_wall() and _blocked_by_world():
		GroundMotion.try_step_up(self, Vector3(velocity.x, 0, velocity.z) * delta, max_step_height)
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)

	model.rotation.y = lerp_angle(model.rotation.y, atan2(_facing.x, _facing.z),
		1.0 - exp(-(data.turn_speed if data else 8.0) * delta))
	# Poise regenerates when not being hit.
	if data:
		poise = move_toward(poise, data.max_poise, data.max_poise * 0.25 * delta)
	if global_position.y < -60.0:
		NodePool.release_or_free(self)


## True when last tick's movement ran into terrain or a building (a possible
## step), not just another character.
func _blocked_by_world() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.7 and not c.get_collider() is CharacterBody3D:
			return true
	return false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = maxf(velocity.y, -0.1)
	else:
		velocity.y -= gravity * delta


## Turns toward a direction at the data turn speed (used by AI).
func face_toward(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		_facing = dir.normalized()


# --- Receiving hits ---------------------------------------------------------------------

## Resolves a hit. Returns the damage actually dealt.
func receive_hit(info: DamageInfo) -> float:
	if is_dead:
		return 0.0
	if exposed and data:
		info.amount *= data.exposed_damage_multiplier
		if info.tag == "":
			info.tag = "Exposed"
	# Spell combination: fire shatters frozen enemies.
	if info.damage_type == &"fire" and status.has(&"frozen"):
		var src = info.source
		info.amount *= 2.0 + ((src as Player).abilities.passive_power(&"shatter_mastery") if is_instance_valid(src) and src is Player else 0.0)
		info.tag = "Shatter!"
		status.remove(&"frozen")
	var inc := status.incoming(info.damage_type)
	info.amount *= float(inc[0])
	if inc[1] != "":
		info.tag = inc[1]
	info.amount = _modify_incoming(info)
	var dealt := health.apply_damage(info)
	if dealt <= 0.0 and not is_dead:
		Events.damage_dealt.emit(info.hit_position, 0.0, false, false, "Immune")
		return 0.0
	if not is_dead:
		for e in info.status_effects:
			apply_status(e[0], float(e[1]), e[2] if e.size() > 2 else {})
	_knockback += Vector3(info.knockback.x, 0, info.knockback.z)
	poise -= info.poise_damage
	if poise <= 0.0 and not is_dead:
		_poise_break_ms = Time.get_ticks_msec()
		stagger(0.7)
	elif not is_dead and _down_left <= 0.0:
		_flinch(info)
	if info.source is Node3D and not is_dead:
		target = info.source
	_on_hit_reaction(info)
	return dealt


# --- Milestone 18b: hit feel ------------------------------------------------------------------

## Hit-stop: freeze body and animation for `seconds`.
func freeze(seconds: float) -> void:
	if is_dead or seconds <= 0.0:
		return
	_freeze_left = maxf(_freeze_left, seconds)
	if model and model.has_method("freeze"):
		model.freeze(seconds)


## A short flinch away from the side the hit came from.
func _flinch(info: DamageInfo) -> void:
	if model == null or not model.has_method("play_flinch"):
		return
	var dir := info.direction
	dir.y = 0.0
	var side := 0.0
	if dir.length_squared() > 0.0001:
		# From the attacker to us, compared with our facing: a hit from our right pushes us to the left.
		side = signf(_facing.cross(-dir.normalized()).y)
	model.play_flinch(clampf(info.poise_damage / 30.0, 0.3, 1.2), side)


func _is_boss_enemy() -> bool:
	return has_method("is_boss") and call("is_boss")


## Knocks the enemy down for `seconds` (it falls, lies there and gets up). Bosses
## only fall right after their poise broke; enemies immune to stuns never fall.
## Returns true if it fell.
func knock_down(seconds: float) -> bool:
	if is_dead or seconds <= 0.0 or _down_left > 0.0 or model == null:
		return false
	if _is_boss_enemy() and Time.get_ticks_msec() - _poise_break_ms > 400:
		return false
	if status.immune.has(&"stunned"):
		return false
	_down_left = seconds + GET_UP_TIME
	stagger(seconds + GET_UP_TIME)
	if _down_tween:
		_down_tween.kill()
	_down_tween = create_tween()
	_down_tween.tween_property(model, "rotation:x", -1.35, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_down_tween.tween_interval(seconds)
	_down_tween.tween_property(model, "rotation:x", 0.0, GET_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VFX.dust(get_parent(), global_position, Color(0.7, 0.65, 0.55, 0.8), 6)
	Events.damage_dealt.emit(global_position + Vector3(0, 1.8, 0), 0.0, false, false, "Knocked down")
	return true


func is_knocked_down() -> bool:
	return _down_left > 0.0


## True when no player is within FAR_DISTANCE.
func _far_from_players() -> bool:
	for p in get_tree().get_nodes_in_group(&"player"):
		if (p as Node3D).global_position.distance_to(global_position) < FAR_DISTANCE:
			return false
	for p in get_tree().get_nodes_in_group(&"remote_players"):
		if (p as Node3D).global_position.distance_to(global_position) < FAR_DISTANCE:
			return false
	return true


func apply_status(id: StringName, duration: float, params: Dictionary) -> void:
	if is_dead:
		return
	# The player's passives (Milestone 17b): Ignite (longer burns), Venom Mastery (more poison stacks).
	var src = params.get("source")
	if is_instance_valid(src) and src is Player:
		var ab: PlayerAbilities = (src as Player).abilities
		if id == &"burn":
			duration *= 1.0 + ab.passive_power(&"ignite")
		elif id == &"poison" and ab.has_passive(&"venom_mastery"):
			params = params.duplicate()
			params["max_stacks"] = roundi(ab.passive_power(&"venom_mastery"))
	status.apply(id, duration, params)


## Forces this enemy to fight `source` for `duration` seconds (Knight taunts).
func taunt(source: Node3D, duration: float) -> void:
	if is_dead:
		return
	target = source
	_taunt_left = duration
	_on_taunted(source)


func is_taunted() -> bool:
	return _taunt_left > 0.0


## Stealth: forget about `source` if it is the current target.
func lose_target(source: Node3D) -> void:
	if target == source and not is_taunted():
		target = null
		_on_lost_target()


## Hook for subclasses (elite shields, boss phases): returns the final amount.
func _modify_incoming(info: DamageInfo) -> float:
	return info.amount


func _on_status_applied(id: StringName) -> void:
	if id != &"taunted" and id != &"wet":
		Events.damage_dealt.emit(global_position + Vector3(0, 2.2, 0), 0.0, false, false, StatusEffects.display_name(id))
	if id == &"stunned":
		stagger(status.time_left(id))
	if id == &"frozen":
		_set_ice_shell(true)


func _on_status_expired(id: StringName) -> void:
	if id == &"frozen":
		_set_ice_shell(false)


## Milestone 18c: a frozen enemy is wrapped in a shell of ice that shatters when it thaws.
var _ice_shell: MeshInstance3D


func _set_ice_shell(on: bool) -> void:
	if on and (_ice_shell == null or not is_instance_valid(_ice_shell)):
		_ice_shell = MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := 1.0
		if data is MonsterData:
			s = (data as MonsterData).model_scale
		box.size = Vector3(1.1, 2.1, 1.1) * s
		_ice_shell.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.92, 1.0, 0.38)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 1.0
		m.roughness = 0.05
		m.emission_enabled = true
		m.emission = Color(0.3, 0.55, 0.7)
		_ice_shell.material_override = m
		_ice_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ice_shell.position.y = 1.05 * s
		add_child(_ice_shell)
	elif not on and _ice_shell and is_instance_valid(_ice_shell):
		if is_inside_tree():
			FX.particles(get_parent(), global_position + Vector3(0, 1.0, 0), {"color": Color(0.85, 0.97, 1.0), "amount": 14,
				"life": 0.6, "speed": 4.0, "gravity": 12.0, "size": 0.45})
		_ice_shell.queue_free()
		_ice_shell = null


func _on_taunted(_source: Node3D) -> void:
	pass


func _on_lost_target() -> void:
	pass


func stagger(duration: float) -> void:
	_stagger_left = maxf(_stagger_left, duration)
	if data:
		poise = data.max_poise
	_on_staggered()


func _on_damaged(info: DamageInfo, dealt: float) -> void:
	health_bar.set_ratio(health.get_ratio())
	if model.has_method("flash"):
		model.flash()
	var pos := info.hit_position if info.hit_position != Vector3.ZERO else global_position + Vector3(0, 1.4, 0)
	Events.damage_dealt.emit(pos, dealt, info.is_crit, false, info.tag)


func _on_died() -> void:
	is_dead = true
	_death_time = 0.0
	health_bar.hide_now()
	if model.has_method("play_death"):
		model.play_death()
	_drop_loot()
	GameState.mark_enemy_killed(spawn_key)
	Events.enemy_killed.emit(self, data.id if data else &"", global_position)
	enemy_died.emit(self)


func _drop_loot() -> void:
	if data == null or World.instance == null:
		return
	for entry in data.loot:
		if entry is LootEntry:
			var n: int = entry.roll(_rng)
			if n > 0:
				World.instance.spawn_pickup(entry.item_id, n, global_position + Vector3(0, 1.0, 0))


func _on_target_changed(t: Node) -> void:
	health_bar.force_visible = (t == self)


## Called by the player when this enemy's attack is parried.
func on_parried() -> void:
	stagger(1.4)
	Events.damage_dealt.emit(global_position + Vector3(0, 1.8, 0), 0.0, false, false, "Stunned")
