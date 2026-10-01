class_name DungeonTrap
extends Node3D
## Spike floor trap: retracted -> warning (spikes peek, click) -> spikes up
## (hurts the player once per cycle) -> retracted. Watch the rhythm and dodge
## through, or roll with i-frames.

const CYCLE := 3.0
const WARN := 1.6
const UP := 2.1
const DOWN := 2.9

var damage := 14.0
var phase := 0.0
var _t := 0.0
var _spikes: Node3D
var _area := Area3D.new()
var _hit_this_cycle := false


func _ready() -> void:
	var base := BlockMesh.new()
	base.box(Vector3(0, 0.02, 0), Vector3(1.0, 0.04, 1.0), Color(0.22, 0.2, 0.22))
	for i in 3:
		for j in 3:
			base.box(Vector3(-0.3 + i * 0.3, 0.045, -0.3 + j * 0.3), Vector3(0.1, 0.01, 0.1), Color(0.08, 0.07, 0.08))
	var mi := MeshInstance3D.new()
	mi.mesh = base.commit()
	add_child(mi)
	_spikes = Node3D.new()
	add_child(_spikes)
	var sb := BlockMesh.new()
	for i in 3:
		for j in 3:
			sb.box(Vector3(-0.3 + i * 0.3, 0.3, -0.3 + j * 0.3), Vector3(0.08, 0.6, 0.08), Color(0.7, 0.7, 0.75))
	var sm := MeshInstance3D.new()
	sm.mesh = sb.commit()
	_spikes.add_child(sm)
	_spikes.position.y = -0.62
	_area.collision_layer = 0
	_area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = box
	cs.position.y = 0.5
	_area.add_child(cs)
	add_child(_area)
	_t = phase


func is_up() -> bool:
	var t := fmod(_t, CYCLE)
	return t >= UP and t < DOWN


func _physics_process(delta: float) -> void:
	_t += delta
	var t := fmod(_t, CYCLE)
	var target := -0.62
	if t >= WARN and t < UP:
		target = -0.45  # peeking: the warning
	elif t >= UP and t < DOWN:
		target = 0.0
	else:
		_hit_this_cycle = false
	_spikes.position.y = move_toward(_spikes.position.y, target, delta * 8.0)
	if is_up() and not _hit_this_cycle:
		for body in _area.get_overlapping_bodies():
			if body.has_method("receive_hit") and body.is_in_group(&"player"):
				_hit_this_cycle = true
				var info := DamageInfo.create(damage, self, &"physical")
				info.tag = "Spike trap"
				info.direction = Vector3.ZERO
				info.poise_damage = 20.0
				body.receive_hit(info)
