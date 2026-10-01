class_name DungeonDoor
extends StaticBody3D
## Ways out of a dungeon floor: the glowing exit portal (back to the surface)
## and the stairs down to the next floor.

enum Kind { EXIT, STAIRS }

var kind: int = Kind.EXIT
var dungeon: DungeonInstance
var _spin: Node3D


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.0, 1.6)
	cs.shape = box
	cs.position.y = 1.0
	add_child(cs)
	var b := BlockMesh.new()
	if kind == Kind.EXIT:
		b.box(Vector3(0, 0.05, 0), Vector3(2.0, 0.1, 2.0), Color(0.3, 0.3, 0.35))
		var ring := BlockMesh.new()
		for k in 10:
			var a := TAU * k / 10.0
			ring.box(Vector3(cos(a) * 0.8, 1.2 + sin(a) * 0.9, 0), Vector3(0.25, 0.25, 0.2), Color(0.5, 0.85, 1.0))
		ring.box(Vector3(0, 1.2, 0), Vector3(1.1, 1.5, 0.05), Color(0.35, 0.6, 1.0))
		var rm := ring.commit()
		rm.surface_set_material(0, Materials.vertex_color_emissive())
		_spin = MeshInstance3D.new()
		(_spin as MeshInstance3D).mesh = rm
		add_child(_spin)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.8, 1.0)
		light.omni_range = 6.0
		light.position.y = 1.2
		add_child(light)
	else:
		for k in 5:
			b.box(Vector3(0, -0.1 - k * 0.2, -k * 0.4), Vector3(2.4, 0.2, 0.4), Color(0.3, 0.29, 0.32) * (1.0 - k * 0.12))
		b.box(Vector3(0, 0.02, -1.0), Vector3(2.6, 0.04, 2.4), Color(0.05, 0.05, 0.07))
		b.box(Vector3(-1.3, 0.5, -1.0), Vector3(0.2, 1.0, 2.4), Color(0.35, 0.33, 0.38))
		b.box(Vector3(1.3, 0.5, -1.0), Vector3(0.2, 1.0, 2.4), Color(0.35, 0.33, 0.38))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	add_child(mi)


func _process(delta: float) -> void:
	if _spin:
		_spin.rotation.y += delta * 0.8


func get_interact_text() -> String:
	if kind == Kind.EXIT:
		return "Leave the dungeon"
	return "Descend to floor %d of %d" % [dungeon.floor_index + 2, dungeon.plan.floor_count]


func interact(_player: Node) -> void:
	if World.instance == null:
		return
	if kind == Kind.EXIT:
		World.instance.exit_dungeon()
	else:
		World.instance.next_dungeon_floor()
