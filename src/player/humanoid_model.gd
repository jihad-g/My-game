class_name HumanoidModel
extends Node3D
## Blocky, cartoon-proportioned humanoid built from coloured boxes, with
## procedural animation (walk cycle, attack swings, dodge roll, block pose,
## hit flash). No external model or animation files needed.
##
## The public API (set_locomotion, play_attack, play_dodge, set_blocking, flash)
## is what a future skeletal/AnimationTree model must also provide.

@export var skin_color := Color(0.96, 0.78, 0.62)
@export var hair_color := Color(0.42, 0.26, 0.14)
@export var shirt_color := Color(0.25, 0.48, 0.85)
@export var pants_color := Color(0.28, 0.24, 0.3)
@export var boot_color := Color(0.35, 0.22, 0.14)
@export var weapon_color := Color(0.78, 0.8, 0.86)

var _root: Node3D  # rotated for rolls/tilts
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _weapon: Node3D
var _parts: Array[MeshInstance3D] = []

var _walk_phase := 0.0
var _move_amount := 0.0
var _blocking := false
var _attack_tween: Tween
var _dodge_tween: Tween
var _flash_time := 0.0
## Arm swing override while attacking (x = shoulder pitch, y = shoulder yaw).
var _attack_arm := Vector2.ZERO
var _attack_torso := 0.0


var _class_id: StringName = &""
var _accent := Color(0.75, 0.6, 0.25)
var _weapon_type: StringName = &"sword"
var _has_shield := false
var _shield: Node3D
var _ghost := false


func _ready() -> void:
	_build()


## Class look: colours + class-specific headgear/clothing.
func set_appearance(c: ClassData) -> void:
	if c == null:
		return
	_class_id = c.id
	shirt_color = c.shirt_color
	pants_color = c.pants_color
	hair_color = c.hair_color
	_accent = c.accent_color
	_build()


func set_weapon(weapon_type: StringName, has_shield: bool) -> void:
	_weapon_type = weapon_type
	_has_shield = has_shield
	if _root:
		_build_weapon()


func _build() -> void:
	if _attack_tween:
		_attack_tween.kill()
	if _dodge_tween:
		_dodge_tween.kill()
	if _root:
		_root.free()
	_parts.clear()
	_root = Node3D.new()
	add_child(_root)
	# Legs (pivot at hip)
	_leg_l = _pivot(_root, Vector3(-0.14, 0.72, 0))
	_part(_leg_l, Vector3(0, -0.3, 0), Vector3(0.22, 0.5, 0.24), pants_color)
	_part(_leg_l, Vector3(0, -0.63, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	_leg_r = _pivot(_root, Vector3(0.14, 0.72, 0))
	_part(_leg_r, Vector3(0, -0.3, 0), Vector3(0.22, 0.5, 0.24), pants_color)
	_part(_leg_r, Vector3(0, -0.63, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	# Torso
	_torso = _pivot(_root, Vector3(0, 0.72, 0))
	_part(_torso, Vector3(0, 0.3, 0), Vector3(0.56, 0.6, 0.32), shirt_color)
	_part(_torso, Vector3(0, 0.03, 0), Vector3(0.58, 0.1, 0.34), Color(0.4, 0.28, 0.16))  # belt
	# Head
	_head = _pivot(_torso, Vector3(0, 0.62, 0))
	_part(_head, Vector3(0, 0.24, 0), Vector3(0.46, 0.46, 0.44), skin_color)
	_part(_head, Vector3(0, 0.49, -0.02), Vector3(0.5, 0.12, 0.48), hair_color)
	_part(_head, Vector3(0, 0.33, -0.2), Vector3(0.5, 0.3, 0.1), hair_color)
	_part(_head, Vector3(-0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))  # eyes
	_part(_head, Vector3(0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))
	# Arms (pivot at shoulder)
	_arm_l = _pivot(_torso, Vector3(-0.36, 0.54, 0))
	_part(_arm_l, Vector3(0, -0.22, 0), Vector3(0.18, 0.46, 0.2), shirt_color * 0.92)
	_part(_arm_l, Vector3(0, -0.5, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_arm_r = _pivot(_torso, Vector3(0.36, 0.54, 0))
	_part(_arm_r, Vector3(0, -0.22, 0), Vector3(0.18, 0.46, 0.2), shirt_color * 0.92)
	_part(_arm_r, Vector3(0, -0.5, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_build_class_gear()
	_weapon = _pivot(_arm_r, Vector3(0, -0.52, 0.05))
	_shield = _pivot(_arm_l, Vector3(-0.1, -0.35, 0.08))
	_build_weapon()
	if _ghost:
		set_ghost(true)


func _build_class_gear() -> void:
	var a := _accent
	match _class_id:
		&"barbarian":
			_part(_head, Vector3(0.27, 0.52, 0), Vector3(0.1, 0.22, 0.1), Color(0.95, 0.92, 0.82))  # horns
			_part(_head, Vector3(-0.27, 0.52, 0), Vector3(0.1, 0.22, 0.1), Color(0.95, 0.92, 0.82))
			_part(_torso, Vector3(0, 0.62, -0.02), Vector3(0.7, 0.14, 0.4), a)  # fur mantle
			_part(_head, Vector3(0, 0.08, 0.2), Vector3(0.36, 0.14, 0.08), hair_color)  # beard
		&"knight":
			_part(_head, Vector3(0, 0.36, 0), Vector3(0.52, 0.34, 0.5), Color(0.72, 0.74, 0.8))  # helm
			_part(_head, Vector3(0, 0.26, 0.24), Vector3(0.36, 0.06, 0.04), Color(0.2, 0.2, 0.25))  # visor slit
			_part(_head, Vector3(0, 0.6, -0.05), Vector3(0.08, 0.14, 0.34), a)  # plume
			_part(_torso, Vector3(0, 0.32, 0.17), Vector3(0.44, 0.44, 0.04), Color(0.78, 0.8, 0.86))  # breastplate
			_part(_torso, Vector3(-0.4, 0.6, 0), Vector3(0.24, 0.12, 0.26), Color(0.72, 0.74, 0.8))  # pauldrons
			_part(_torso, Vector3(0.4, 0.6, 0), Vector3(0.24, 0.12, 0.26), Color(0.72, 0.74, 0.8))
		&"wizard":
			_part(_head, Vector3(0, 0.52, 0), Vector3(0.62, 0.06, 0.6), shirt_color * 0.8)  # hat brim
			_part(_head, Vector3(0, 0.68, 0), Vector3(0.36, 0.28, 0.36), shirt_color * 0.85)
			_part(_head, Vector3(0.03, 0.88, -0.03), Vector3(0.2, 0.2, 0.2), shirt_color * 0.9)
			_part(_head, Vector3(0.06, 1.02, -0.06), Vector3(0.1, 0.12, 0.1), a)
			_part(_head, Vector3(0, 0.02, 0.2), Vector3(0.3, 0.26, 0.08), Color(0.9, 0.9, 0.92))  # beard
			_part(_torso, Vector3(0, -0.12, 0), Vector3(0.6, 0.36, 0.36), shirt_color * 0.9)  # robe skirt
		&"assassin":
			_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.54, 0.4, 0.5), shirt_color * 0.8)  # hood
			_part(_head, Vector3(0, 0.1, 0.23), Vector3(0.44, 0.16, 0.04), Color(0.12, 0.12, 0.15))  # mask
			_part(_torso, Vector3(0, 0.3, -0.19), Vector3(0.5, 0.56, 0.06), a)  # cape


func _build_weapon() -> void:
	for holder in [_weapon, _shield]:
		for c in holder.get_children():
			_parts.erase(c as MeshInstance3D)
			c.free()
	var wood := Color(0.42, 0.28, 0.16)
	var steel := weapon_color
	match _weapon_type:
		&"sword":
			_part(_weapon, Vector3(0, 0, 0.12), Vector3(0.08, 0.08, 0.2), Color(0.35, 0.22, 0.12))
			_part(_weapon, Vector3(0, 0, 0.24), Vector3(0.3, 0.06, 0.06), Color(0.75, 0.6, 0.25))
			_part(_weapon, Vector3(0, 0, 0.62), Vector3(0.1, 0.04, 0.7), steel)
		&"axe":
			_part(_weapon, Vector3(0, 0, 0.35), Vector3(0.08, 0.08, 0.85), wood)
			_part(_weapon, Vector3(0.14, 0, 0.66), Vector3(0.28, 0.05, 0.3), steel)
			_part(_weapon, Vector3(0.3, 0, 0.66), Vector3(0.06, 0.05, 0.38), steel * 1.1)
		&"dagger":
			_part(_weapon, Vector3(0, 0, 0.08), Vector3(0.07, 0.07, 0.14), Color(0.2, 0.15, 0.12))
			_part(_weapon, Vector3(0, 0, 0.17), Vector3(0.18, 0.05, 0.04), Color(0.5, 0.5, 0.55))
			_part(_weapon, Vector3(0, 0, 0.36), Vector3(0.07, 0.03, 0.34), steel)
			# Off-hand dagger for dual wield look.
			_part(_shield, Vector3(0.1, -0.1, 0.2), Vector3(0.06, 0.03, 0.3), steel)
		&"staff":
			_part(_weapon, Vector3(0, 0, 0.35), Vector3(0.07, 0.07, 1.5), wood)
			_part(_weapon, Vector3(0, 0, 1.12), Vector3(0.18, 0.18, 0.18), _accent)
		&"unarmed":
			pass
		_:
			_part(_weapon, Vector3(0, 0, 0.5), Vector3(0.1, 0.1, 0.8), steel)
	if _has_shield:
		_part(_shield, Vector3(-0.05, 0, 0.1), Vector3(0.08, 0.55, 0.45), Color(0.5, 0.32, 0.18))
		_part(_shield, Vector3(-0.1, 0, 0.1), Vector3(0.04, 0.2, 0.2), _accent)


## Stealth look: parts become translucent.
func set_ghost(on: bool) -> void:
	_ghost = on
	for p in _parts:
		if is_instance_valid(p):
			p.transparency = 0.7 if on else 0.0


func play_spin(duration: float) -> void:
	if _dodge_tween:
		_dodge_tween.kill()
	_dodge_tween = create_tween()
	_dodge_tween.tween_property(_root, "rotation:y", TAU * 2.0, duration).from(0.0)
	_dodge_tween.tween_callback(func() -> void: _root.rotation.y = 0.0)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, size, color)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.position = pos
	parent.add_child(mi)
	_parts.append(mi)
	return mi


## `speed_ratio` 0..1+ (1 = running).
func set_locomotion(speed_ratio: float, delta: float) -> void:
	_move_amount = lerpf(_move_amount, clampf(speed_ratio, 0.0, 1.4), 1.0 - exp(-12.0 * delta))
	_walk_phase += delta * (4.0 + 7.0 * _move_amount) * (1.0 if _move_amount > 0.05 else 0.0)


func set_blocking(value: bool) -> void:
	_blocking = value


func play_attack(anim: StringName, windup: float, active: float, recovery: float) -> void:
	if _attack_tween:
		_attack_tween.kill()
	# Poses: x = arm pitch (negative = raised forward/up), y = arm yaw, torso twist.
	var ready_pose := Vector3(-2.2, 0.9, -0.5)
	var strike_pose := Vector3(-1.3, -1.1, 0.6)
	match anim:
		&"slash_l":
			ready_pose = Vector3(-1.4, -1.2, 0.6)
			strike_pose = Vector3(-1.5, 1.0, -0.6)
		&"thrust":
			ready_pose = Vector3(-0.9, 0.2, -0.3)
			strike_pose = Vector3(-1.7, 0.0, 0.3)
		&"overhead":
			ready_pose = Vector3(-3.0, 0.1, -0.2)
			strike_pose = Vector3(-0.6, 0.0, 0.2)
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_attack_pose, Vector3(_attack_arm.x, _attack_arm.y, _attack_torso), ready_pose, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_method(_set_attack_pose, ready_pose, strike_pose, maxf(active, 0.05)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_method(_set_attack_pose, strike_pose, Vector3.ZERO, recovery).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _set_attack_pose(v: Vector3) -> void:
	_attack_arm = Vector2(v.x, v.y)
	_attack_torso = v.z


func cancel_attack() -> void:
	if _attack_tween:
		_attack_tween.kill()
	_attack_arm = Vector2.ZERO
	_attack_torso = 0.0


func play_dodge(duration: float) -> void:
	if _dodge_tween:
		_dodge_tween.kill()
	_root.rotation.x = 0.0
	_dodge_tween = create_tween()
	_dodge_tween.tween_property(_root, "rotation:x", TAU, duration).set_trans(Tween.TRANS_SINE)
	_dodge_tween.tween_callback(func() -> void: _root.rotation.x = 0.0)


func flash() -> void:
	_flash_time = 0.1
	for p in _parts:
		p.material_overlay = Materials.hit_flash()


func play_stagger() -> void:
	var tw := create_tween()
	tw.tween_property(_torso, "rotation:x", -0.5, 0.08)
	tw.tween_property(_torso, "rotation:x", 0.0, 0.3)


func play_death() -> void:
	cancel_attack()
	var tw := create_tween()
	tw.tween_property(_root, "rotation:z", PI * 0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "position:y", 0.25, 0.5)


func reset_pose() -> void:
	cancel_attack()
	_root.rotation = Vector3.ZERO
	_root.position = Vector3.ZERO
	_torso.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			for p in _parts:
				p.material_overlay = null
	var swing := sin(_walk_phase) * 0.9 * minf(_move_amount, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	var bob := absf(sin(_walk_phase)) * 0.06 * minf(_move_amount, 1.0)
	_torso.position.y = 0.72 + bob
	_torso.rotation.y = _attack_torso
	_torso.rotation.z = 0.0
	_arm_l.rotation.x = -swing * 0.8
	_arm_l.rotation.y = 0.0
	if _blocking:
		_arm_l.rotation = Vector3(-1.4, 0.6, 0.0)
		_arm_r.rotation = Vector3(-1.2, -0.9, 0.0)
		_weapon.rotation = Vector3(0.0, -1.2, 0.0)
	elif _attack_arm != Vector2.ZERO:
		_arm_r.rotation = Vector3(_attack_arm.x, _attack_arm.y, 0.0)
		_weapon.rotation = Vector3.ZERO
	else:
		_arm_r.rotation = Vector3(swing * 0.8 - 0.25, 0.0, 0.0)
		_weapon.rotation = Vector3(-0.9, 0.0, 0.0)
