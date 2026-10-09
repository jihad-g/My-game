class_name AbilityZone
extends Node3D
## A player ability's area on the ground (Milestone 17b): Consecrate, Time Warp,
## Fire Wall, Static Field, Caltrops, Smoke Bomb. Every `tick` seconds for
## `duration` seconds it calls `on_tick` with the living enemies inside `radius`.

var radius := 3.0
var duration := 5.0
var tick := 0.5
var color := Color(1, 1, 1, 0.35)
## func(enemies: Array[Node]) -> void
var on_tick: Callable
## Milestone 17c: the zone stays on this node (Fire Ring) or moves (Fire Tornado).
var follow: Node3D
## Milestone 17d: the zone ends when the node it follows dies or is gone (a summon's aura);
## otherwise it just stays where that happened (Pillar of Light).
var end_with_follow := false
var velocity := Vector3.ZERO

## Milestone 18c: the element look, guessed from `color`.
var element: StringName = &"physical"
var _t := 0.0
var _next := 0.0
var _disc: MeshInstance3D


func _ready() -> void:
	add_to_group(&"ability_zones")
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06
	cyl.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.16)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	_disc = MeshInstance3D.new()
	_disc.mesh = cyl
	_disc.position.y = 0.08
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	# Milestone 18c: a soft glow on the ground in the element's look, and motes rising from it.
	element = FX.element_from_color(color)
	var glow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.2, radius * 2.2)
	glow.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = FX.soft_texture()
	gm.albedo_color = Color(color.r, color.g, color.b, 0.55)
	if color.v > 0.3:
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.material_override = gm
	glow.position.y = 0.1
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(gm, "albedo_color:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gm, "albedo_color:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	_t += delta
	if follow != null:
		if is_instance_valid(follow) and follow.is_inside_tree() and not follow.get("is_dead"):
			global_position = follow.global_position
		else:
			follow = null
			if end_with_follow:
				queue_free()
				return
	elif velocity != Vector3.ZERO:
		var p := global_position + velocity * delta
		if World.instance:
			p.y = World.instance.get_ground_height(p)
		global_position = p
	_next -= delta
	if _next <= 0.0:
		_next = tick
		if on_tick.is_valid():
			on_tick.call(enemies_inside())
		VFX.ring(get_parent(), global_position, radius, Color(color.r, color.g, color.b, 0.5), 0.3)
		if tick >= 0.3:
			FX.particles(get_parent(), global_position + Vector3(0, 0.2, 0), {"color": Color(color.r, color.g, color.b, 0.8),
				"amount": clampi(int(radius * 4), 4, 18), "life": 0.9, "speed": 0.8, "spread": 25.0,
				"gravity": -1.5 if element != &"frost" else 0.5, "size": 0.5, "radius": radius * 0.7, "explosive": 0.3,
				"add": element != &"shadow"})
	if _t >= duration:
		queue_free()


func enemies_inside() -> Array[Node]:
	var out: Array[Node] = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or n.get("is_dead") or not n.is_visible_in_tree() or not n.has_method("receive_hit"):
			continue
		var d := n.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 3.0:
			out.append(n)
	return out
