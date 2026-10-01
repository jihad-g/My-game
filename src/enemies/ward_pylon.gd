class_name WardPylon
extends StaticBody3D
## A crystal that powers a boss's protective ward (Milestone 7, boss move
## "shield"). While any pylon stands the boss takes no damage. Pylons are hit
## like enemies (melee, spells, projectiles) but don't fight back.

signal destroyed(pylon: WardPylon)

var max_health := 60.0
var health := 60.0
var is_dead := false
var color := Color(0.75, 0.5, 1.0)
var boss: Node3D

var _crystal: MeshInstance3D
var _link: MeshInstance3D
var _flash := 0.0
var _spin := 0.0


func _ready() -> void:
	add_to_group(&"ward_pylons")
	collision_layer = Layers.ENEMY
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 2.0, 0.9)
	cs.shape = box
	cs.position.y = 1.0
	add_child(cs)
	var base := BlockMesh.new()
	base.box(Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 1.0), Color(0.3, 0.28, 0.33))
	var bm := MeshInstance3D.new()
	bm.mesh = base.commit()
	add_child(bm)
	var b := BlockMesh.new()
	b.box(Vector3(0, 0, 0), Vector3(0.45, 1.2, 0.45), color)
	b.box(Vector3(0, 0.75, 0), Vector3(0.25, 0.35, 0.25), color.lightened(0.3))
	var m := b.commit()
	m.surface_set_material(0, Materials.vertex_color_emissive())
	_crystal = MeshInstance3D.new()
	_crystal.mesh = m
	_crystal.position.y = 1.2
	add_child(_crystal)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position.y = 1.4
	add_child(light)
	_link = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.08, 0.08, 1.0)
	_link.mesh = lm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_link.material_override = mat
	_link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_link)


func _process(delta: float) -> void:
	_spin += delta
	_crystal.rotation.y = _spin
	_crystal.position.y = 1.2 + sin(_spin * 2.0) * 0.1
	if _flash > 0.0:
		_flash -= delta
		_crystal.material_overlay = Materials.hit_flash() if _flash > 0.0 else null
	# Energy link to the boss.
	if boss and is_instance_valid(boss) and boss.is_inside_tree():
		var a := global_position + Vector3(0, 1.4, 0)
		var b := boss.global_position + Vector3(0, 1.6, 0)
		var mid := (a + b) * 0.5
		_link.global_position = mid
		_link.visible = a.distance_to(b) > 0.5
		if _link.visible:
			_link.look_at(b, Vector3.UP)
			_link.scale = Vector3(1, 1, a.distance_to(b))
	else:
		_link.visible = false


func get_facing() -> Vector3:
	return Vector3.FORWARD


func display_name() -> String:
	return "Ward Pylon"


func receive_hit(info: DamageInfo) -> float:
	if is_dead:
		return 0.0
	var dealt := minf(info.amount, health)
	health -= dealt
	_flash = 0.1
	Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), dealt, info.is_crit, false, "Pylon")
	if health <= 0.0:
		is_dead = true
		VFX.burst(get_parent(), global_position + Vector3(0, 1.2, 0), 2.0, Color(color.r, color.g, color.b, 0.8), 0.35)
		destroyed.emit(self)
		queue_free()
	return dealt
