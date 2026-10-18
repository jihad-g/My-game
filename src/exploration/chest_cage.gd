class_name ChestCage
extends StaticBody3D
## Milestone 31: an iron cage around a puzzle room's chest. open() lifts it;
## close() drops it again (pressure plates only hold it open for a while).

const SEALED := "it is locked in an iron cage"

var is_open := false
## The chest inside: sealed while the cage is down.
var chest: LootChest
var _bars: Node3D


func _ready() -> void:
	collision_layer = Layers.PROP
	collision_mask = 0
	_bars = Node3D.new()
	add_child(_bars)
	var b := BlockMesh.new()
	var iron := Color(0.32, 0.3, 0.35)
	for side in 4:
		for k in 5:
			var t := -0.8 + k * 0.4
			var p: Vector3 = [Vector3(t, 0.8, -0.9), Vector3(t, 0.8, 0.9), Vector3(-0.9, 0.8, t), Vector3(0.9, 0.8, t)][side]
			b.box(p, Vector3(0.08, 1.6, 0.08), iron)
	b.box(Vector3(0, 1.62, 0), Vector3(1.9, 0.08, 1.9), iron * 1.2)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	_bars.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.7, 1.9)
	cs.shape = box
	cs.position.y = 0.85
	add_child(cs)
	if chest:
		chest.locked_reason = SEALED


func open() -> void:
	if is_open:
		return
	is_open = true
	if chest and is_instance_valid(chest) and chest.locked_reason == SEALED:
		chest.locked_reason = ""
	Audio.play_at(&"door", global_position, -2.0)
	create_tween().tween_property(_bars, "position:y", 1.75, 0.5)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if chest and is_instance_valid(chest) and chest.locked_reason == "":
		chest.locked_reason = SEALED
	Audio.play_at(&"door", global_position, -2.0)
	create_tween().tween_property(_bars, "position:y", 0.0, 0.25)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", false)
