class_name Player
extends CharacterBody3D
## The player character: movement, dodge, block, interaction, survival hooks.
##
## Architecture: the Player is a thin coordinator. Stats and survival live in
## child components (HealthComponent, StaminaComponent, HungerComponent,
## TemperatureComponent, StatBlock), melee in PlayerCombat, visuals in
## HumanoidModel. Future class/skill systems plug in by writing StatBlock
## sources and swapping AttackData sets.

signal interact_target_changed(target: Node)
signal died
signal respawned

enum State { NORMAL, DODGING, STAGGERED, DEAD, DASHING }

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 40.0
@export var turn_speed: float = 16.0
@export var gravity: float = 24.0
@export var max_step_height: float = 0.6
## Movement multiplier while wading through water.
@export var water_speed_multiplier: float = 0.65
## Movement multiplier while swimming in deep water.
@export var swim_speed_multiplier: float = 0.55
@export var swim_cost_per_second: float = 3.0
## Swimming body height below the water surface (feet position).
@export var swim_depth: float = 1.05

@export_group("Stamina costs")
@export var sprint_cost_per_second: float = 14.0
@export var dodge_cost: float = 22.0

@export_group("Dodge")
@export var dodge_speed: float = 12.0
@export var dodge_duration: float = 0.42
## I-frame window inside the dodge (seconds from start).
@export var dodge_iframe_start: float = 0.04
@export var dodge_iframe_end: float = 0.32
@export var dodge_cooldown: float = 0.15

@export_group("Block")
@export var block_move_multiplier: float = 0.45
## Fraction of frontal damage negated while blocking.
@export var block_reduction: float = 0.7
@export var block_arc_degrees: float = 140.0
## Stamina lost per point of damage blocked.
@export var block_stamina_per_damage: float = 1.1
## Blocking within this window after raising the guard is a perfect parry.
@export var parry_window: float = 0.2

@export_group("Interaction")
@export var interact_range: float = 2.4

var inventory := Inventory.new(24)
var equipment := Equipment.new()
var recipes := RecipeBook.new()
## Advanced spells learned from tomes (Milestone 7).
var spells := SpellBook.new()
## Money in copper (Milestone 5).
var coins: int = 0
## Body chosen at character creation: {skin, hair, style, beard} (CharacterLook).
var look: Dictionary = {}
## Status effects (burn, poison, bleed, chill, shock, wet, buffs...): the
## shared StatusEffects component (Milestone 7). Created in _ready().
var status: StatusEffects
## Active status effects: id -> {time, stacks, dps, source} (read-only view).
var afflictions: Dictionary:
	get:
		return status.effects if status else {}
var reputation := Reputation.new()
var state: State = State.NORMAL
var is_dead: bool = false
var is_blocking: bool = false
## Frozen while the world around the spawn point is still generating.
var frozen: bool = true
var camera_rig: CameraRig
var lock_target: Node3D
var spawn_point := Vector3.ZERO

@onready var stats: StatBlock = $Stats
@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var hunger: HungerComponent = $Hunger
@onready var temperature: TemperatureComponent = $Temperature
@onready var combat: PlayerCombat = $Combat
@onready var character: CharacterStats = $Character
@onready var mana: ManaComponent = $Mana
@onready var abilities: PlayerAbilities = $Abilities
@onready var model: HumanoidModel = $Model
@onready var interact_area: Area3D = $InteractArea

var _facing := Vector3(0, 0, 1)
var _dodge_time := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_cooldown_left := 0.0
var _stagger_left := 0.0
var _block_time := 0.0
var _knockback := Vector3.ZERO
var _interact_target: Node = null
var _want_light := false
var _want_heavy := false
var _in_water := false
## True while in water too deep to stand in.
var is_swimming := false
## Fastest fall speed of the current jump/fall (landing effects).
var _fall_speed := 0.0
var _moving_fast := false
var _lantern: OmniLight3D
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_left := 0.0
var _dash_on_hit: Callable
var _dash_hit: Array[Node] = []
## Boss "pull" moves drag the player (velocity added while _pull_left > 0).
var _pull := Vector3.ZERO
var _pull_left := 0.0


func _ready() -> void:
	add_to_group(&"player")
	model.footstep.connect(_on_footstep)
	combat.player = self
	abilities.player = self
	character.equipment = equipment
	equipment.changed.connect(_on_equipment_changed)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	stamina.exhausted.connect(_on_exhausted)
	interact_area.collision_mask = Layers.INTERACTABLE | Layers.PICKUP
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	status = StatusEffects.new()
	status.name = "Status"
	status.health = health
	add_child(status)
	status.effect_applied.connect(_on_status_applied)
	status.effect_expired.connect(_on_status_expired)
	status.reaction.connect(func(text: String) -> void:
		Events.damage_dealt.emit(global_position + Vector3(0, 2.5, 0), 0.0, false, true, text))


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or frozen:
		if is_dead and event.is_action_pressed(&"respawn"):
			respawn()
		return
	if World.instance and ((World.instance.build_mode and World.instance.build_mode.active)
			or (World.instance.blueprints and World.instance.blueprints.placer.active)):
		if event.is_action_pressed(&"attack_light") or event.is_action_pressed(&"attack_heavy"):
			return  # clicks belong to build mode
	if event.is_action_pressed(&"attack_light"):
		_want_light = true
	elif event.is_action_pressed(&"attack_heavy"):
		_want_heavy = true
	elif event.is_action_pressed(&"interact"):
		_try_interact()
	elif event.is_action_pressed(&"target_lock"):
		cycle_lock_target()
	elif event.is_action_pressed(&"ability_1"):
		abilities.try_use(0)
	elif event.is_action_pressed(&"ability_2"):
		abilities.try_use(1)
	elif event.is_action_pressed(&"ability_3"):
		abilities.try_use(2)
	elif event.is_action_pressed(&"ability_shield"):
		abilities.try_use(3)
	elif event.is_action_pressed(&"spell_1"):
		abilities.try_cast(0)
	elif event.is_action_pressed(&"spell_2"):
		abilities.try_cast(1)
	else:
		for i in InputSetup.HOTBAR_ACTIONS.size():
			if event.is_action_pressed(InputSetup.HOTBAR_ACTIONS[i]):
				use_slot(i)
				break


# --- Main loop --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	_dodge_cooldown_left -= delta
	hunger.activity_multiplier = 1.0
	_update_water()

	if state == State.DEAD:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return

	_update_lock_target()
	var input := _get_move_input()

	match state:
		State.NORMAL:
			_update_blocking(delta)
			if is_swimming:
				_want_light = false
				_want_heavy = false
				combat.cancel()
				_move_swimming(input, delta)
			elif Input.is_action_just_pressed(&"dodge") and _dodge_cooldown_left <= 0.0 and combat.can_cancel():
				_start_dodge(input)
			else:
				_consume_attack_requests()
				_move_normal(input, delta)
		State.DODGING:
			_move_dodge(delta)
		State.DASHING:
			_move_dash(delta)
		State.STAGGERED:
			_stagger_left -= delta
			velocity.x = move_toward(velocity.x, 0.0, acceleration * 0.5 * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * 0.5 * delta)
			if _stagger_left <= 0.0:
				state = State.NORMAL

	combat.physics_update(delta)

	# Knockback decays quickly and stacks on top of controlled movement.
	var pull := Vector3.ZERO
	if _pull_left > 0.0:
		_pull_left -= delta
		pull = _pull
	velocity += _knockback + pull
	if is_swimming:
		# Buoyancy: float with the head above the surface.
		var float_y := TerrainGenerator.WATER_Y - swim_depth
		velocity.y = (float_y - global_position.y) * 4.0
	else:
		_apply_gravity(delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z) * delta
	if is_on_floor():
		GroundMotion.try_step_up(self, horizontal, max_step_height)
	elif is_swimming:
		# Climb out onto the bank.
		GroundMotion.try_step_up(self, horizontal, swim_depth + 0.9)
	move_and_slide()
	velocity -= _knockback + pull
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)

	_update_facing(delta)
	_update_interact_target()
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	model.set_locomotion(planar_speed / walk_speed * 0.8, delta)
	_update_air(planar_speed)

	# Safety net: fell through the world (e.g. terrain not yet loaded).
	if velocity.y < -30.0:
		_rescue_to_surface()


## Jump/fall pose, and a landing squash + dust + thud after a real fall.
func _update_air(planar_speed: float) -> void:
	var airborne := not is_on_floor() and not is_swimming and state != State.DODGING
	model.set_air_state(airborne and _fall_speed > 2.5, is_swimming)
	if airborne:
		_fall_speed = maxf(_fall_speed, -velocity.y)
		return
	if _fall_speed > 6.0 and not is_swimming:
		var s := clampf((_fall_speed - 6.0) / 10.0, 0.2, 1.0)
		model.play_land(s)
		VFX.dust(get_parent(), global_position, _dust_color(), int(4 + s * 8))
		Audio.play(StringName("step_" + footstep_surface()), -2.0, 0.05)
	_fall_speed = 0.0
	_moving_fast = planar_speed > walk_speed * 1.15


## What the ground under the player sounds like.
func footstep_surface() -> String:
	var w := World.instance
	if w == null:
		return "grass"
	if w.dungeon or w.layer == TerrainGenerator.Layer.UNDERGROUND:
		return "stone"
	var p := global_position
	if w.building and w.building.pieces.has(BuildingManager.key(Vector2i(floori(p.x), floori(p.z)), "floor", w.layer)):
		return "wood"
	var b: StringName = w.current_biome.id if w.current_biome else &""
	match b:
		&"sunscorch_desert", &"sandy_beach":
			return "sand"
		&"snowy_tundra", &"frostpine_taiga":
			return "snow"
		&"stonecrown_mountains":
			return "snow" if p.y > 26.0 else "stone"
	if w.living and w.living.current:
		return "stone"  # town streets
	return "grass"


func _dust_color() -> Color:
	match footstep_surface():
		"sand":
			return Color(0.9, 0.78, 0.55, 0.8)
		"snow":
			return Color(1, 1, 1, 0.9)
		"stone":
			return Color(0.6, 0.6, 0.62, 0.7)
	return Color(0.6, 0.5, 0.35, 0.7)


func _on_footstep(_left: bool) -> void:
	if is_dead or is_swimming:
		return
	if _in_water:
		Audio.play_at(&"swim", global_position, -16.0, 0.15, 20.0, 150)
		return
	Audio.play_at(StringName("step_" + footstep_surface()), global_position, -9.0 if _moving_fast else -13.0, 0.12, 22.0, 120)
	if _moving_fast:
		VFX.dust(get_parent(), global_position, _dust_color(), 2)


func _update_water() -> void:
	var w := World.instance
	_in_water = w != null and w.is_in_water(global_position)
	if _in_water and not is_dead:
		refresh_status(&"wet", 6.0)
	var was_swimming := is_swimming
	is_swimming = _in_water and global_position.y < TerrainGenerator.WATER_Y - 0.6 and w.is_deep_water(global_position)
	if is_swimming and not was_swimming:
		is_blocking = false
		model.set_blocking(false)
		Audio.play_at(&"splash", global_position, -4.0)
		VFX.splash(get_parent(), global_position + Vector3(0, 0.6, 0), 18)


func _move_swimming(input: Vector3, delta: float) -> void:
	var speed := walk_speed * swim_speed_multiplier * stats.get_mult(Stats.MOVE_SPEED)
	if input != Vector3.ZERO:
		if stamina.current > 1.0:
			stamina.consume(swim_cost_per_second * delta)
		else:
			speed *= 0.5  # exhausted: barely keeping afloat
		face_direction(input, false)
	hunger.activity_multiplier = 1.5
	var accel := acceleration * 0.5 * delta
	velocity.x = move_toward(velocity.x, input.x * speed, accel)
	velocity.z = move_toward(velocity.z, input.z * speed, accel)


## Personal light, used underground.
func set_lantern(on: bool) -> void:
	if on and _lantern == null:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.8, 0.55)
		_lantern.light_energy = 1.8
		_lantern.omni_range = 14.0
		_lantern.omni_attenuation = 0.8
		_lantern.shadow_enabled = false
		_lantern.position = Vector3(0.3, 2.2, 0.2)
		add_child(_lantern)
	if _lantern:
		_lantern.visible = on


func _get_move_input() -> Vector3:
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if World.instance and World.instance.hud and World.instance.hud.mp_hud.is_typing():
		raw = Vector2.ZERO  # typing in the chat
	if raw == Vector2.ZERO or camera_rig == null:
		return Vector3(raw.x, 0, raw.y)
	var dir := camera_rig.get_right_flat() * raw.x - camera_rig.get_forward_flat() * raw.y
	return dir.limit_length(1.0)


## Sprint input, honouring the "toggle sprint" accessibility setting: one
## press starts sprinting until you stop moving or run out of stamina.
var _sprint_latched := false
var _sprint_frame := -1


func _sprint_held() -> bool:
	if not Settings.get_value("toggle_sprint"):
		return Input.is_action_pressed(&"sprint")
	if Input.is_action_just_pressed(&"sprint") and _sprint_frame != Engine.get_physics_frames():
		_sprint_frame = Engine.get_physics_frames()
		_sprint_latched = not _sprint_latched
	if _get_move_input() == Vector3.ZERO or stamina.current <= 1.0:
		_sprint_latched = false
	return _sprint_latched


func _move_normal(input: Vector3, delta: float) -> void:
	var speed := walk_speed
	var sprinting := _sprint_held() and input != Vector3.ZERO \
		and not is_blocking and not combat.is_attacking() and stamina.current > 1.0
	if sprinting:
		speed = sprint_speed
		stamina.consume(sprint_cost_per_second * delta)
		hunger.activity_multiplier = 2.0
	speed *= stats.get_mult(Stats.MOVE_SPEED)
	if is_blocking:
		speed *= block_move_multiplier
	if _in_water:
		speed *= water_speed_multiplier
	speed *= combat.get_move_multiplier()
	var target_vel := input * speed + combat.get_lunge_velocity()
	var accel := acceleration * delta
	velocity.x = move_toward(velocity.x, target_vel.x, accel)
	velocity.z = move_toward(velocity.z, target_vel.z, accel)
	if sprinting and not combat.is_attacking():
		face_direction(input, false)


func _consume_attack_requests() -> void:
	if _want_light:
		combat.request(&"light")
	elif _want_heavy:
		combat.request(&"heavy")
	_want_light = false
	_want_heavy = false


func can_start_attack() -> bool:
	return state == State.NORMAL and not is_blocking and not frozen


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = maxf(velocity.y, -0.1)
	else:
		velocity.y -= gravity * delta


# --- Facing / aiming ----------------------------------------------------------------

## Direction the player wants to act in: the lock-on target, else the mouse.
func get_aim_direction() -> Vector3:
	var aim_point: Vector3
	if is_instance_valid(lock_target):
		aim_point = lock_target.global_position
	elif InputSetup.using_gamepad:
		# Gamepad: act where the left stick points (or keep facing).
		var mv := _get_move_input()
		return mv.normalized() if mv.length() > 0.2 else _facing
	elif camera_rig:
		aim_point = camera_rig.get_mouse_world_point(global_position.y)
	else:
		return _facing
	var d := aim_point - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.2 else _facing


func face_direction(dir: Vector3, instant: bool) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_facing = dir.normalized()
	if instant:
		model.rotation.y = atan2(_facing.x, _facing.z)


func get_facing() -> Vector3:
	return _facing


func _update_facing(delta: float) -> void:
	if state == State.NORMAL and not combat.is_attacking():
		var sprinting := _sprint_held() and Vector2(velocity.x, velocity.z).length() > walk_speed
		if not sprinting:
			_facing = get_aim_direction()
	var target_yaw := atan2(_facing.x, _facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


# --- Dodge ------------------------------------------------------------------------

func _start_dodge(input: Vector3) -> void:
	if not stamina.try_consume(dodge_cost * Skill.dodge_cost_mult(character.skill_level(Skill.DEXTERITY)) * equipment.dodge_cost_mult()):
		Events.toast.emit("Not enough stamina to dodge", Color(1, 0.85, 0.4))
		return
	combat.cancel()
	is_blocking = false
	model.set_blocking(false)
	state = State.DODGING
	_dodge_time = 0.0
	_dodge_dir = input.normalized() if input != Vector3.ZERO else _facing
	face_direction(_dodge_dir, true)
	model.play_dodge(dodge_duration)
	Audio.play(&"dodge", -7.0)
	# Roll through enemies.
	collision_mask &= ~Layers.ENEMY


func _move_dodge(delta: float) -> void:
	_dodge_time += delta
	var iframe_end := dodge_iframe_start + (dodge_iframe_end - dodge_iframe_start) \
		* Skill.dodge_iframe_mult(character.skill_level(Skill.DEXTERITY))
	health.invulnerable = _dodge_time >= dodge_iframe_start and _dodge_time <= minf(iframe_end, dodge_duration)
	var t := _dodge_time / dodge_duration
	var speed := dodge_speed * (1.0 - t * t * 0.7) * stats.get_mult(Stats.MOVE_SPEED)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	if _dodge_time >= dodge_duration:
		_end_dodge()


## Ability dash (Rallying Charge): moves `distance` in `time`, invulnerable,
## calling `on_hit` once for every enemy passed through.
func start_ability_dash(dir: Vector3, distance: float, time: float, on_hit: Callable) -> void:
	combat.cancel()
	is_blocking = false
	model.set_blocking(false)
	state = State.DASHING
	_dash_dir = Vector3(dir.x, 0, dir.z).normalized()
	_dash_speed = distance / time
	_dash_left = time
	_dash_on_hit = on_hit
	_dash_hit.clear()
	face_direction(_dash_dir, true)
	health.invulnerable = true
	collision_mask &= ~Layers.ENEMY


func _move_dash(delta: float) -> void:
	_dash_left -= delta
	velocity.x = _dash_dir.x * _dash_speed
	velocity.z = _dash_dir.z * _dash_speed
	var space := get_world_3d().direct_space_state
	for t in HitQuery.query_arc(space, global_position + Vector3(0, 0.9, 0), _dash_dir, 1.6, 360.0, Layers.ENEMY, [get_rid()]):
		if not _dash_hit.has(t) and t.has_method("receive_hit") and _dash_on_hit.is_valid():
			_dash_hit.append(t)
			_dash_on_hit.call(t)
	if _dash_left <= 0.0:
		state = State.NORMAL
		health.invulnerable = false
		collision_mask |= Layers.ENEMY
		velocity.x *= 0.2
		velocity.z *= 0.2


func _end_dodge() -> void:
	state = State.NORMAL
	health.invulnerable = false
	_dodge_cooldown_left = dodge_cooldown
	collision_mask |= Layers.ENEMY


# --- Block --------------------------------------------------------------------------

func _update_blocking(delta: float) -> void:
	var wants := Input.is_action_pressed(&"block") and not combat.is_attacking() and stamina.current > 0.0
	if wants and not is_blocking:
		_block_time = 0.0
	is_blocking = wants
	if is_blocking:
		_block_time += delta
	model.set_blocking(is_blocking)


# --- Taking damage ------------------------------------------------------------------

## Called by enemies. Resolves dodge i-frames, block and parry before damage.
func receive_hit(info: DamageInfo) -> void:
	if is_dead:
		return
	if health.invulnerable:
		Events.damage_dealt.emit(global_position + Vector3(0, 2, 0), 0.0, false, true, "Dodged")
		return
	if is_blocking and _is_in_front(info):
		if _block_time <= character.parry_window:
			Events.damage_dealt.emit(global_position + Vector3(0, 2, 0), 0.0, false, false, "Parry!")
			Events.camera_shake.emit(0.3)
			Audio.play(&"parry", -2.0, 0.02)
			if info.source and info.source.has_method("on_parried"):
				info.source.on_parried()
			return
		var blocked := info.amount * character.block_reduction
		var cost := blocked * block_stamina_per_damage * Skill.block_stamina_mult(character.skill_level(Skill.DEFENSE))
		if stamina.current >= cost:
			stamina.consume(cost, false)
			info.amount -= blocked
			info.knockback *= 0.4
			info.poise_damage *= 0.3
			info.tag = "Blocked"
			Audio.play(&"block", -3.0)
		else:
			stamina.consume(stamina.current, false)
			info.tag = "Guard broken"
			_stagger(0.8)
	# Armor, buffs and Last Stand reduce everything that gets through.
	var reduction := character.damage_reduction
	if character.skill_level(Skill.DEFENSE) >= 75 and health.get_ratio() < 0.25:
		reduction = minf(reduction + 0.2, 0.85)
	if info.damage_type != &"starvation" and info.damage_type != &"true":
		info.amount *= (1.0 - reduction) * abilities.incoming_mult() * Settings.damage_taken_mult()
		var inc := status.incoming(info.damage_type)
		info.amount *= float(inc[0])
		if inc[1] != "":
			info.tag = inc[1]
		var before := info.amount
		info.amount = abilities.absorb(info.amount)
		if info.amount < before and info.amount <= 0.0:
			info.tag = "Absorbed"
	var dealt := health.apply_damage(info)
	if dealt > 0.0:
		abilities.on_damage_taken(dealt)
	if is_dead:
		return
	info.knockback *= Skill.knockback_taken_mult(character.skill_level(Skill.STRENGTH), character.skill_level(Skill.DEFENSE))
	_knockback += Vector3(info.knockback.x, 0, info.knockback.z)
	if info.poise_damage >= 30.0 and state != State.DODGING:
		_stagger(0.45)
	for e in info.status_effects:
		afflict(StringName(e[0]), float(e[1]), e[2] if e.size() > 2 else {})


## Applies a status effect to the player (see StatusEffects for ids).
## Harmful effects are shortened by the Defense perk "Iron Skin".
func afflict(id: StringName, duration: float, params: Dictionary = {}) -> bool:
	if is_dead:
		return false
	status.duration_mult = Skill.status_duration_mult(character.skill_level(Skill.DEFENSE))
	return status.apply(id, duration, params)


## Keeps an effect going without re-announcing it (standing in water keeps you wet).
func refresh_status(id: StringName, duration: float) -> void:
	if status.has(id):
		status.effects[id].time = maxf(float(status.effects[id].time), duration)
	else:
		afflict(id, duration)


func _on_status_applied(id: StringName) -> void:
	if StatusEffects.is_harmful(id) and id != &"wet":
		Events.damage_dealt.emit(global_position + Vector3(0, 2.3, 0), 0.0, false, true, StatusEffects.display_name(id))
	if id == &"stunned" and state == State.NORMAL:
		_stagger(status.time_left(id))
	_update_status_stats()
	Events.status_changed.emit(self)


func _on_status_expired(_id: StringName) -> void:
	_update_status_stats()
	Events.status_changed.emit(self)


func _update_status_stats() -> void:
	var m := status.speed_mult() if not status.is_stunned() else 1.0
	stats.set_source(&"afflictions", {} if is_equal_approx(m, 1.0) else {Stats.MOVE_SPEED: m})


## Drags the player with velocity `v` for `time` seconds (boss pull moves).
func set_pull(v: Vector3, time: float) -> void:
	if is_dead or state == State.DODGING:
		return
	_pull = v
	_pull_left = maxf(_pull_left, time)


func _is_in_front(info: DamageInfo) -> bool:
	if info.direction == Vector3.ZERO:
		return true
	# info.direction points from attacker to us; we must be facing against it.
	return _facing.angle_to(-info.direction) <= deg_to_rad(block_arc_degrees) * 0.5


func _stagger(duration: float) -> void:
	combat.cancel()
	is_blocking = false
	model.set_blocking(false)
	state = State.STAGGERED
	_stagger_left = duration
	model.play_stagger()


func _on_damaged(info: DamageInfo, dealt: float) -> void:
	model.flash()
	Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), dealt, info.is_crit, true, info.tag)
	if dealt >= 5.0:
		Events.camera_shake.emit(clampf(dealt / 40.0, 0.15, 0.6))


func _on_exhausted() -> void:
	if is_blocking:
		is_blocking = false
		model.set_blocking(false)


func _on_died() -> void:
	is_dead = true
	state = State.DEAD
	combat.cancel()
	health.invulnerable = false
	is_blocking = false
	model.set_blocking(false)
	model.play_death()
	set_lock_target(null)
	died.emit()
	Events.player_died.emit()


func respawn() -> void:
	if not is_dead:
		return
	is_dead = false
	state = State.NORMAL
	status.clear()
	_update_status_stats()
	Events.status_changed.emit(self)
	health.revive(0.6)
	stamina.refill()
	mana.refill()
	hunger.eat(maxf(0.0, 50.0 - hunger.current))
	model.reset_pose()
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	global_position = spawn_point
	temperature.snap_to_ambient()
	respawned.emit()
	Events.player_respawned.emit()


func _rescue_to_surface() -> void:
	if World.instance == null:
		return
	var ground := World.instance.get_ground_height(global_position)
	if global_position.y < ground - 8.0:
		global_position.y = ground + 1.0
		velocity = Vector3.ZERO


# --- Target lock ---------------------------------------------------------------------

func cycle_lock_target() -> void:
	var candidates: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := e as Node3D
		if enemy == null or not enemy.is_visible_in_tree() or enemy.get("is_dead"):
			continue
		if enemy.global_position.distance_to(global_position) <= 20.0:
			candidates.append(enemy)
	if candidates.is_empty():
		set_lock_target(null)
		return
	var me := global_position
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(me) < b.global_position.distance_squared_to(me))
	var idx := candidates.find(lock_target)
	if idx == candidates.size() - 1:
		set_lock_target(null)  # cycled through everything: release lock
	else:
		set_lock_target(candidates[idx + 1])


func set_lock_target(t: Node3D) -> void:
	if t == lock_target:
		return
	lock_target = t
	Events.target_changed.emit(t)


func _update_lock_target() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_visible_in_tree() \
			or lock_target.get("is_dead") or lock_target.global_position.distance_to(global_position) > 26.0:
		set_lock_target(null)


# --- Interaction / items ---------------------------------------------------------------

func _update_interact_target() -> void:
	var best: Node = null
	var best_d := interact_range
	for body in interact_area.get_overlapping_bodies():
		if body.has_method("get_interact_text") and (not body.has_method("is_interactable") or body.is_interactable()):
			var d := global_position.distance_to(body.global_position)
			if d < best_d:
				best_d = d
				best = body
	for area in interact_area.get_overlapping_areas():
		if area.has_method("get_interact_text") and area.is_visible_in_tree():
			var d := global_position.distance_to(area.global_position)
			if d < best_d:
				best_d = d
				best = area
	if best != _interact_target:
		_interact_target = best
		interact_target_changed.emit(best)


func get_interact_target() -> Node:
	return _interact_target if is_instance_valid(_interact_target) else null


func _try_interact() -> void:
	var t := get_interact_target()
	if t and t.has_method("interact"):
		t.interact(self)
		_interact_target = null


## Adds items to the inventory; overflow is dropped on the ground.
## Returns how many could not be stored.
func give_item(id: StringName, count: int) -> int:
	if inventory.remote:
		return count  # multiplayer guest: only the server hands out items
	var left := inventory.add_item(id, count)
	var added := count - left
	if added > 0:
		Events.item_picked_up.emit(id, added)
		discover_from(id)
	return left


## Learns discovery recipes unlocked by owning `id` (any way it reached you).
func discover_from(id: StringName) -> void:
	for r in recipes.on_item_obtained(id):
		_announce_recipe(r.id)


## Like give_item, but whatever doesn't fit is dropped at your feet (crafting, refunds).
func give_or_drop(id: StringName, count: int) -> void:
	if inventory.remote:
		return
	var left := give_item(id, count)
	if left > 0 and World.instance:
		World.instance.spawn_pickup(id, left, global_position + _facing * 1.2 + Vector3(0, 1.0, 0), false)
		Events.toast.emit("Inventory full: dropped %d on the ground" % left, Color(1, 0.8, 0.5))


func use_slot(index: int) -> void:
	var s = inventory.get_slot(index)
	if s == null or is_dead:
		return
	var item: ItemData = ItemDB.get_item(s.id)
	if item == null:
		return
	if item.is_recipe_book():
		read_recipe_book(index)
	elif item.is_spell_tome():
		read_spell_tome(index)
	elif item.is_equippable():
		equip_from_slot(index)
	elif item.is_consumable():
		_consume(item)
		_take_one(index)
	elif item.is_placeable():
		if inventory.remote:
			Net.client.request("place_object", [index, _place_target()])
		elif _place(item):
			inventory.remove_from_slot(index, 1)
	else:
		Events.toast.emit("%s can't be used directly" % item.display_name, Color(0.85, 0.85, 0.85))


# --- Class & equipment -------------------------------------------------------------------

## Applies a class. `fresh` gives a brand-new character its starting kit.
func setup_class(class_data: ClassData, fresh: bool) -> void:
	character.setup(class_data, fresh)
	model.set_appearance(class_data)
	if fresh:
		set_look(SaveManager.new_character_look if not SaveManager.new_character_look.is_empty()
			else CharacterLook.default_for(class_data.id))
		recipes.learn_starting()
		equipment.clear()
		for id in class_data.starting_equipment:
			var item: ItemData = ItemDB.get_item(StringName(id))
			if item:
				equipment.equip(item)
		for id in class_data.starting_items:
			inventory.add_item(StringName(id), int(class_data.starting_items[id]))
	_on_equipment_changed()
	character.recalculate(fresh)


## Equips the item in inventory slot `index`; the replaced item goes back to the inventory.
func equip_from_slot(index: int) -> bool:
	var s = inventory.get_slot(index)
	if s == null:
		return false
	if inventory.remote:
		Net.client.request("equip", [index], func(ok: bool, _m: String, _e: Dictionary) -> void:
			var it: ItemData = ItemDB.get_item(s.id)
			if ok and it:
				Events.toast.emit("Equipped %s" % it.display_name, it.rarity_color()))
		return true
	var item: ItemData = ItemDB.get_item(s.id)
	var err := Equipment.check_requirements(item, character.level)
	if err != "":
		Events.toast.emit("%s: %s" % [item.display_name if item else "?", err], Color(1, 0.7, 0.5))
		return false
	inventory.remove_from_slot(index, 1)
	var old := equipment.equip(item)
	if old != &"":
		var left := inventory.add_item(old, 1)
		if left > 0 and World.instance:
			World.instance.spawn_pickup(old, left, global_position + Vector3(0, 1, 0), false)
	Events.toast.emit("Equipped %s" % item.display_name, item.rarity_color())
	return true


## Moves an equipped item back into the inventory.
func unequip_slot(slot: int) -> bool:
	var id := equipment.get_item_id(slot)
	if id == &"":
		return false
	if inventory.remote:
		Net.client.request("unequip", [slot])
		return true
	if inventory.free_slot_count() == 0:
		Events.toast.emit("Inventory full", Color(1, 0.6, 0.5))
		return false
	equipment.unequip(slot)
	inventory.add_item(id, 1)
	return true


func _on_equipment_changed() -> void:
	var weapon := equipment.weapon()
	var moveset: WeaponMoveset = weapon.moveset if weapon and weapon.moveset else null
	if moveset == null and character.class_data:
		moveset = character.class_data.unarmed_moveset
	combat.set_moveset(moveset)
	model.set_weapon(equipment.weapon_type(), equipment.offhand() != null)
	model.set_outfit(equipment.outfit_ids(), weapon.id if weapon else &"")
	character.recalculate()


## The shared body chosen at character creation (Milestone 14, CharacterLook).
func set_look(p_look: Dictionary) -> void:
	look = CharacterLook.sanitize(p_look, character.class_data.id if character.class_data else &"knight")
	model.set_body(look)


## What other players need to draw us: Equipment.look_args() (weapon type,
## off-hand, outfit ids, weapon id) + our body (CharacterLook dict).
func look_args() -> Array:
	return equipment.look_args() + [look.duplicate()]


## Highest tier of a tool kind (&"axe", &"pickaxe") in the inventory (0 = none).
func best_tool_tier(kind: StringName) -> int:
	var best := 0
	for s in inventory.slots:
		if s != null:
			var item: ItemData = ItemDB.get_item(s.id)
			if item and item.tool_kind == kind:
				best = maxi(best, item.tool_tier)
	return best


func read_recipe_book(index: int) -> void:
	var s = inventory.get_slot(index)
	var item: ItemData = ItemDB.get_item(s.id) if s != null else null
	if item == null:
		return
	var learned := 0
	for id in item.teaches_recipes:
		if recipes.learn(StringName(id)):
			learned += 1
			_announce_recipe(StringName(id))
	if learned == 0:
		Events.toast.emit("You already know everything in %s" % item.display_name, Color(0.85, 0.85, 0.85))
		return
	_take_one(index)


## Learns the spell in a tome (consumed). You can learn any spell; casting
## needs its Mana Control requirement.
func read_spell_tome(index: int) -> bool:
	var s = inventory.get_slot(index)
	var item: ItemData = ItemDB.get_item(s.id) if s != null else null
	if item == null or not item.is_spell_tome():
		return false
	var sp := SpellBook.get_spell(item.teaches_spell)
	if sp == null:
		return false
	if not spells.learn(sp.id):
		Events.toast.emit("You already know %s" % sp.display_name, Color(0.85, 0.85, 0.85))
		return false
	_take_one(index)
	var mc := character.skill_level(Skill.MANA_CONTROL)
	var note := "" if mc >= sp.required_mana_control else " (needs Mana Control %d to cast)" % sp.required_mana_control
	Events.toast.emit("Learned spell: %s%s. Spellbook: L" % [sp.display_name, note], Color(0.75, 0.6, 1.0))
	Events.spell_learned.emit(sp.id)
	return true


func _announce_recipe(id: StringName) -> void:
	var r := RecipeBook.get_recipe(id)
	var d: ItemData = ItemDB.get_item(r.result_item) if r else null
	Events.toast.emit("Learned recipe: %s" % (d.display_name if d else String(id)), Color(0.6, 1.0, 0.9))
	Events.recipe_learned.emit(id)


func is_stealthed() -> bool:
	return abilities.is_stealthed()


## How far away enemies notice you, as a multiplier on their sight range
## (Milestone 14): light armour < 1, heavy armour > 1.
func notice_mult() -> float:
	return equipment.notice_mult()


func _consume(item: ItemData) -> void:
	if item.use_effect == &"respec":
		var n := character.respec()
		Events.toast.emit("You forget your training: %d skill point%s to spend again (K)" % [n, "" if n == 1 else "s"], Color(0.8, 0.75, 1.0))
	if item.hunger_restore > 0.0:
		hunger.eat(item.hunger_restore)
	if item.health_restore > 0.0:
		health.heal(item.health_restore)
	if item.temperature_offset != 0.0 and item.temperature_duration > 0.0:
		temperature.add_buff(StringName("food_%s" % item.id), item.temperature_offset, item.temperature_duration)
	if item.mana_restore > 0.0:
		mana.restore(item.mana_restore)
	if not item.cures.is_empty():
		var n := status.cleanse([] if item.cures.has(&"all") else item.cures)
		if n > 0:
			Events.toast.emit("Cured %d effect%s" % [n, "" if n == 1 else "s"], Color(0.6, 1, 0.7))
	if item.regen_hps > 0.0 and item.regen_duration > 0.0:
		afflict(&"regen", item.regen_duration, {"hps": item.regen_hps})
	if item.buff_id != &"" and item.buff_duration > 0.0:
		abilities.add_buff(item.buff_id, item.buff_duration)
		if item.buff_id == &"starlight":
			mana.refill()
	var potion := item.mana_restore > 0.0 or item.buff_id != &"" or item.hunger_restore <= 0.0
	Audio.play(&"drink" if potion else &"eat", -4.0)
	Events.toast.emit("%s %s" % ["Drank" if potion else "Ate", item.display_name], Color(0.7, 1, 0.6))


func _place(item: ItemData) -> bool:
	if World.instance == null:
		return false
	return World.instance.place_object(item.placeable_scene, _place_target()) != null


func _place_target() -> Vector3:
	var target := global_position + _facing * 1.6
	if camera_rig and camera_rig.is_inside_tree() and DisplayServer.get_name() != "headless" and not InputSetup.using_gamepad:
		var aim := camera_rig.get_mouse_world_point(global_position.y)
		if aim.distance_to(global_position) <= 4.0:
			target = aim
	return target


## Uses up one item from a slot (a request to the server for multiplayer guests).
func _take_one(index: int) -> void:
	if inventory.remote:
		Net.client.request("use", [index])
	else:
		inventory.remove_from_slot(index, 1)


func drop_slot(index: int, count: int) -> void:
	var s = inventory.get_slot(index)
	if s == null or World.instance == null:
		return
	if inventory.remote:
		Net.client.request("drop", [index, count])
		return
	var id: StringName = s.id
	var n := inventory.remove_from_slot(index, count)
	if n > 0:
		World.instance.spawn_pickup(id, n, global_position + _facing * 1.2 + Vector3(0, 1.0, 0), false)


# --- Save / load -------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {
		"position": _save_position(),
		"spawn_point": [spawn_point.x, spawn_point.y, spawn_point.z],
		"facing": [_facing.x, _facing.z],
		"health": health.current,
		"dead": is_dead,
		"stamina": stamina.current,
		"hunger": hunger.current,
		"temperature": temperature.felt,
		"temperature_buffs": temperature.get_buffs().duplicate(true),
		"inventory": inventory.to_array(),
		"character": character.to_save(),
		"equipment": equipment.to_save(),
		"mana": mana.current,
		"abilities": abilities.to_save(),
		"recipes": recipes.to_save(),
		"coins": coins,
		"reputation": reputation.to_save(),
		"spells": spells.to_save(),
		"look": look.duplicate(),
	}


## Inside a dungeon we save the entrance (dungeons are rebuilt, not saved).
func _save_position() -> Array:
	var p := global_position
	if World.instance and World.instance.dungeon:
		p = World.instance.dungeon.return_position
	return [p.x, p.y, p.z]


func from_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	var p: Array = data.get("position", [0, 0, 0])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var sp: Array = data.get("spawn_point", p)
	spawn_point = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	var f: Array = data.get("facing", [0, 1])
	face_direction(Vector3(float(f[0]), 0, float(f[1])), true)
	# Progression first: it determines max health/stamina/mana.
	equipment.from_save(data.get("equipment", {}))
	var ch: Dictionary = data.get("character", {})
	if ch.has("level"):
		character.load_progress(ch)
	health.current = clampf(float(data.get("health", health.max_health)), 1.0, health.max_health)
	health.health_changed.emit(health.current, health.max_health)
	stamina.current = float(data.get("stamina", stamina.max_stamina))
	hunger._set_current(float(data.get("hunger", hunger.max_hunger)))
	temperature.felt = float(data.get("temperature", temperature.felt))
	var buffs: Dictionary = data.get("temperature_buffs", {})
	for id in buffs:
		temperature.add_buff(StringName(id), float(buffs[id].offset), float(buffs[id].time_left))
	inventory.from_array(data.get("inventory", []))
	mana.current = minf(float(data.get("mana", mana.max_mana)), mana.max_mana)
	mana.mana_changed.emit(mana.current, mana.max_mana)
	abilities.from_save(data.get("abilities", {}))
	if data.has("recipes"):
		recipes.from_save(data.recipes)
	else:
		recipes.learn_starting()
	coins = int(data.get("coins", World.STARTING_COINS))
	reputation.from_save(data.get("reputation", {}))
	spells.from_save(data.get("spells", {}))
	# Saves from before Milestone 14 get the class's default body.
	set_look(data.get("look", CharacterLook.default_for(character.class_data.id if character.class_data else &"knight")))
