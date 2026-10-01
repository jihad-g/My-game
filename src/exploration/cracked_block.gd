class_name CrackedBlock
extends StaticBody3D
## A cracked wall or floor slab hiding something (a secret dungeon room, a ruin
## vault). Attack it to break it open; `broken` fires once.

signal broken(block: CrackedBlock)

var size := Vector3(1.0, 3.0, 0.5)
var hits_left := 3
var persist_key := ""
var is_floor := false
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.BUILDING | Layers.PROP
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	var b := BlockMesh.new()
	var stone := Color(0.42, 0.4, 0.44) if not is_floor else Color(0.5, 0.48, 0.45)
	b.box(Vector3(0, size.y * 0.5, 0), size, stone)
	# Cracks: darker lines that give the secret away to sharp eyes.
	var face := size.z * 0.5 + 0.01 if not is_floor else 0.0
	if is_floor:
		for k in 3:
			b.box(Vector3(-0.3 + k * 0.3, size.y + 0.005, -0.2 + k * 0.2), Vector3(0.5, 0.02, 0.05), Color(0.15, 0.13, 0.12), Basis(Vector3.UP, 0.5 * k))
	else:
		for k in 4:
			b.box(Vector3(-0.2 + k * 0.12, 0.8 + k * 0.4, face), Vector3(0.05, 0.5, 0.02), Color(0.15, 0.13, 0.12), Basis(Vector3.BACK, 0.4 - k * 0.25))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.commit()
	add_child(_mesh)


func receive_hit(info: DamageInfo) -> void:
	if hits_left <= 0:
		return
	hits_left -= 1
	Events.damage_dealt.emit(global_position + Vector3(0, size.y * 0.5 + 0.5, 0), 0.0, false, false, "Crack!" if hits_left > 0 else "Crumbles!")
	Events.camera_shake.emit(0.1)
	var tw := create_tween()
	tw.tween_property(_mesh, "position:x", 0.05, 0.04)
	tw.tween_property(_mesh, "position:x", 0.0, 0.04)
	if hits_left <= 0:
		_break()


func _break() -> void:
	VFX.burst(get_parent(), global_position + Vector3(0, size.y * 0.5, 0), 1.6, Color(0.6, 0.55, 0.5, 0.8))
	if persist_key != "" and World.instance:
		World.instance.exploration.set_state(persist_key)
	broken.emit(self)
	queue_free()
