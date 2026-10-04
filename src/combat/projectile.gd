class_name Projectile
extends Node3D
## A simple straight-flying spell projectile (Firebolt). Hits the first enemy,
## prop or wall along its path using ray casts (no tunnelling at high speed).

var info_builder: Callable  ## func(target: Node) -> DamageInfo
var velocity := Vector3.ZERO
var lifetime := 1.5
var exclude: Array[RID] = []
var color := Color(1.0, 0.5, 0.15)
var on_hit: Callable  ## optional func(target: Node, dealt: float)
var on_impact: Callable  ## optional func(position: Vector3), called on any impact (bombs explode)
## Homing (Arcane Missiles): steer toward this target at `turn_rate` radians/s.
var homing_target: Node3D
var turn_rate := 6.0
## Played where the projectile starts (arrows, turret bolts); "" = silent (spells have their own cast sound).
var launch_sound: StringName = &""
## &"arrow" (Milestone 17a): a thin wooden shaft without a glow; "" = magic bolt.
var style: StringName = &""
## What the projectile can hit (enemy projectiles use PLAYER instead of ENEMY).
var mask := Layers.TERRAIN | Layers.ENEMY | Layers.PROP | Layers.BUILDING

var _age := 0.0
var _shape := SphereShape3D.new()


func _ready() -> void:
	_shape.radius = 0.3
	if launch_sound != &"":
		(func() -> void: Audio.play_at(launch_sound, global_position, -4.0)).call_deferred()
	var b := BlockMesh.new()
	if style == &"arrow":
		_shape.radius = 0.2
		b.box(Vector3.ZERO, Vector3(0.05, 0.05, 0.8), Color(0.5, 0.36, 0.2))
		b.box(Vector3(0, 0, -0.42), Vector3(0.09, 0.09, 0.12), color)  # head (flies towards -Z)
		b.box(Vector3(0, 0, 0.36), Vector3(0.14, 0.02, 0.14), Color(0.92, 0.9, 0.85))  # fletching
		var arrow_mi := MeshInstance3D.new()
		arrow_mi.mesh = b.commit()
		arrow_mi.mesh.surface_set_material(0, Materials.vertex_color())
		arrow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arrow_mi)
		if velocity.length_squared() > 0.0:
			look_at(global_position + velocity, Vector3.UP)
		return
	b.box(Vector3.ZERO, Vector3(0.35, 0.35, 0.35), color)
	b.box(Vector3.ZERO, Vector3(0.22, 0.22, 0.6), color.lightened(0.4))
	var mesh := b.commit()
	mesh.surface_set_material(0, Materials.vertex_color_emissive())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	add_child(light)
	if velocity.length_squared() > 0.0:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	_age += delta
	if homing_target and is_instance_valid(homing_target) and homing_target.is_inside_tree() and homing_target.get("is_dead") != true:
		var want := (homing_target.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
		var speed := velocity.length()
		var cur := velocity / maxf(speed, 0.001)
		var ang := cur.angle_to(want)
		if ang > 0.001:
			var axis := cur.cross(want)
			if axis.length() > 0.0001:
				velocity = cur.rotated(axis.normalized(), minf(ang, turn_rate * delta)) * speed
	var from := global_position
	var motion := velocity * delta
	var space := get_world_3d().direct_space_state
	# Swept sphere: the bolt has volume, so glancing hits count.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = motion
	params.collision_mask = mask
	params.exclude = exclude
	var fractions := space.cast_motion(params)
	if fractions.size() == 2 and fractions[1] < 1.0:
		params.transform.origin = from + motion * fractions[1]
		params.motion = Vector3.ZERO
		var rest := space.get_rest_info(params)
		if not rest.is_empty():
			_impact(instance_from_id(rest.collider_id), rest.point)
			return
	global_position = from + motion
	if style != &"arrow":
		rotation.z += delta * 12.0
	if _age >= lifetime:
		_impact(null, global_position)


func _impact(target: Object, pos: Vector3) -> void:
	if target and target.has_method("receive_hit") and info_builder.is_valid():
		var info: DamageInfo = info_builder.call(target)
		info.hit_position = pos
		var dealt = target.receive_hit(info)
		if on_hit.is_valid():
			on_hit.call(target, float(dealt) if dealt != null else 0.0)
	if on_impact.is_valid():
		on_impact.call(pos)
	VFX.burst(get_parent(), pos, 0.6 if style == &"arrow" else 1.2, Color(color.r, color.g, color.b, 0.8))
	queue_free()
