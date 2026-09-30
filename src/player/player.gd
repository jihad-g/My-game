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

enum State { NORMAL, DODGING, STAGGERED, DEAD }

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 40.0
@export var turn_speed: float = 16.0
@export var gravity: float = 24.0
@export var max_step_height: float = 0.6
## Movement multiplier while wading through water.
@export var water_speed_multiplier: float = 0.65

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


func _ready() -> void:
	add_to_group(&"player")
	combat.player = self
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	stamina.exhausted.connect(_on_exhausted)
	interact_area.collision_mask = Layers.INTERACTABLE | Layers.PICKUP
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or frozen:
		if is_dead and event.is_action_pressed(&"respawn"):
			respawn()
		return
	if event.is_action_pressed(&"attack_light"):
		_want_light = true
	elif event.is_action_pressed(&"attack_heavy"):
		_want_heavy = true
	elif event.is_action_pressed(&"interact"):
		_try_interact()
	elif event.is_action_pressed(&"target_lock"):
		cycle_lock_target()
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
	_in_water = global_position.y < TerrainGenerator.WATER_Y - 0.25

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
			if Input.is_action_just_pressed(&"dodge") and _dodge_cooldown_left <= 0.0 and combat.can_cancel():
				_start_dodge(input)
			else:
				_consume_attack_requests()
				_move_normal(input, delta)
		State.DODGING:
			_move_dodge(delta)
		State.STAGGERED:
			_stagger_left -= delta
			velocity.x = move_toward(velocity.x, 0.0, acceleration * 0.5 * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * 0.5 * delta)
			if _stagger_left <= 0.0:
				state = State.NORMAL

	combat.physics_update(delta)

	# Knockback decays quickly and stacks on top of controlled movement.
	velocity += _knockback
	_apply_gravity(delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z) * delta
	if is_on_floor():
		GroundMotion.try_step_up(self, horizontal, max_step_height)
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)

	_update_facing(delta)
	_update_interact_target()
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	model.set_locomotion(planar_speed / walk_speed * 0.8, delta)

	# Safety net: fell out of the world (e.g. terrain not yet loaded).
	if global_position.y < -60.0:
		_rescue_to_surface()


func _get_move_input() -> Vector3:
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if raw == Vector2.ZERO or camera_rig == null:
		return Vector3(raw.x, 0, raw.y)
	var dir := camera_rig.get_right_flat() * raw.x - camera_rig.get_forward_flat() * raw.y
	return dir.limit_length(1.0)


func _move_normal(input: Vector3, delta: float) -> void:
	var speed := walk_speed
	var sprinting := Input.is_action_pressed(&"sprint") and input != Vector3.ZERO \
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
		var sprinting := Input.is_action_pressed(&"sprint") and Vector2(velocity.x, velocity.z).length() > walk_speed
		if not sprinting:
			_facing = get_aim_direction()
	var target_yaw := atan2(_facing.x, _facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


# --- Dodge ------------------------------------------------------------------------

func _start_dodge(input: Vector3) -> void:
	if not stamina.try_consume(dodge_cost):
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
	# Roll through enemies.
	collision_mask &= ~Layers.ENEMY


func _move_dodge(delta: float) -> void:
	_dodge_time += delta
	health.invulnerable = _dodge_time >= dodge_iframe_start and _dodge_time <= dodge_iframe_end
	var t := _dodge_time / dodge_duration
	var speed := dodge_speed * (1.0 - t * t * 0.7) * stats.get_mult(Stats.MOVE_SPEED)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	if _dodge_time >= dodge_duration:
		_end_dodge()


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
		if _block_time <= parry_window:
			Events.damage_dealt.emit(global_position + Vector3(0, 2, 0), 0.0, false, false, "Parry!")
			Events.camera_shake.emit(0.3)
			if info.source and info.source.has_method("on_parried"):
				info.source.on_parried()
			return
		var blocked := info.amount * block_reduction
		var cost := blocked * block_stamina_per_damage
		if stamina.current >= cost:
			stamina.consume(cost, false)
			info.amount -= blocked
			info.knockback *= 0.4
			info.poise_damage *= 0.3
			info.tag = "Blocked"
		else:
			stamina.consume(stamina.current, false)
			info.tag = "Guard broken"
			_stagger(0.8)
	health.apply_damage(info)
	if is_dead:
		return
	_knockback += Vector3(info.knockback.x, 0, info.knockback.z)
	if info.poise_damage >= 30.0 and state != State.DODGING:
		_stagger(0.45)


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
	health.revive(0.6)
	stamina.refill()
	hunger.eat(maxf(0.0, 50.0 - hunger.current))
	model.reset_pose()
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	global_position = spawn_point
	temperature.snap_to_ambient()
	respawned.emit()
	Events.player_respawned.emit()


func _rescue_to_surface() -> void:
	if World.instance:
		var p := global_position
		p.y = World.instance.get_ground_height(p) + 1.0
		global_position = p
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
	var left := inventory.add_item(id, count)
	var added := count - left
	if added > 0:
		Events.item_picked_up.emit(id, added)
	return left


func use_slot(index: int) -> void:
	var s = inventory.get_slot(index)
	if s == null or is_dead:
		return
	var item: ItemData = ItemDB.get_item(s.id)
	if item == null:
		return
	if item.is_consumable():
		_consume(item)
		inventory.remove_from_slot(index, 1)
	elif item.is_placeable():
		if _place(item):
			inventory.remove_from_slot(index, 1)
	else:
		Events.toast.emit("%s can't be used directly" % item.display_name, Color(0.85, 0.85, 0.85))


func _consume(item: ItemData) -> void:
	if item.hunger_restore > 0.0:
		hunger.eat(item.hunger_restore)
	if item.health_restore > 0.0:
		health.heal(item.health_restore)
	if item.temperature_offset != 0.0 and item.temperature_duration > 0.0:
		temperature.add_buff(StringName("food_%s" % item.id), item.temperature_offset, item.temperature_duration)
	Events.toast.emit("Ate %s" % item.display_name, Color(0.7, 1, 0.6))


func _place(item: ItemData) -> bool:
	if World.instance == null:
		return false
	var target := global_position + _facing * 1.6
	if camera_rig:
		var aim := camera_rig.get_mouse_world_point(global_position.y)
		if aim.distance_to(global_position) <= 4.0:
			target = aim
	return World.instance.place_object(item.placeable_scene, target)


func drop_slot(index: int, count: int) -> void:
	var s = inventory.get_slot(index)
	if s == null or World.instance == null:
		return
	var id: StringName = s.id
	var n := inventory.remove_from_slot(index, count)
	if n > 0:
		World.instance.spawn_pickup(id, n, global_position + _facing * 1.2 + Vector3(0, 1.0, 0), false)
