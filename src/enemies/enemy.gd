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


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.TERRAIN | Layers.PROP | Layers.PLAYER | Layers.ENEMY | Layers.BUILDING
	floor_snap_length = 0.6
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	status.health = health
	status.effect_applied.connect(_on_status_applied)
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


## True while performing a charge/rush (spikes punish it harder).
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
		if _death_time > 2.5:
			NodePool.release_or_free(self)
		return

	# No terrain collision here yet (chunk still generating): wait instead of falling through.
	var w := World.instance
	if w and w.dungeon == null and not w.chunk_manager.is_collision_ready_at(global_position):
		velocity = Vector3.ZERO
		return
	_taunt_left -= delta
	_env_check -= delta
	if _env_check <= 0.0:
		_env_check = 0.5
		if World.instance and World.instance.dungeon == null and World.instance.is_in_water(global_position):
			if status.has(&"wet"):
				status.effects[&"wet"].time = maxf(float(status.effects[&"wet"].time), 4.0)
			else:
				status.apply(&"wet", 4.0)
	if _stagger_left > 0.0 or status.is_stunned():
		_stagger_left -= delta
		_desired_velocity = Vector3.ZERO
	else:
		_think(delta)
		_desired_velocity *= status.speed_mult()

	var accel := 30.0 * delta
	velocity.x = move_toward(velocity.x, _desired_velocity.x, accel)
	velocity.z = move_toward(velocity.z, _desired_velocity.z, accel)
	velocity += _knockback
	_apply_gravity(delta)
	if is_on_floor():
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
		info.amount *= 2.0
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
		stagger(0.7)
	if info.source is Node3D and not is_dead:
		target = info.source
	_on_hit_reaction(info)
	return dealt


func apply_status(id: StringName, duration: float, params: Dictionary) -> void:
	if is_dead:
		return
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
