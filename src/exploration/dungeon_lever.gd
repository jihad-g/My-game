class_name DungeonLever
extends StaticBody3D
## Milestone 31: a wall lever with a rune number (lever puzzles: pull them in
## order). The DungeonInstance listens to `pulled`.

signal pulled(lever: DungeonLever)

var number := 1
var is_down := false
var _handle: Node3D


func _ready() -> void:
	add_to_group(&"dungeon_levers")
	collision_layer = Layers.INTERACTABLE | Layers.PROP
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.2, 0.6)
	cs.shape = box
	cs.position.y = 0.6
	add_child(cs)
	var b := BlockMesh.new()
	var stone := Color(0.45, 0.45, 0.5)
	b.box(Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), stone)
	# Rune pips: one per number, glowing.
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	add_child(mi)
	var gb := BlockMesh.new()
	for k in number:
		gb.box(Vector3(-0.15 + k * 0.15, 0.75, 0.31), Vector3(0.08, 0.2, 0.02), Color(0.45, 0.9, 1.0))
	var gm := gb.commit()
	gm.surface_set_material(0, Materials.vertex_color_emissive())
	var glow := MeshInstance3D.new()
	glow.mesh = gm
	add_child(glow)
	_handle = Node3D.new()
	_handle.position = Vector3(0, 1.0, 0)
	add_child(_handle)
	var hb := BlockMesh.new()
	hb.box(Vector3(0, 0.3, 0), Vector3(0.08, 0.6, 0.08), Color(0.35, 0.25, 0.15))
	hb.box(Vector3(0, 0.62, 0), Vector3(0.16, 0.16, 0.16), Color(0.75, 0.2, 0.15))
	var hm := MeshInstance3D.new()
	hm.mesh = hb.commit()
	_handle.add_child(hm)
	set_down(false)


func set_down(down: bool) -> void:
	is_down = down
	if _handle:
		var tw := create_tween()
		tw.tween_property(_handle, "rotation:x", 0.9 if down else -0.9, 0.2)


func get_interact_text() -> String:
	return "Pull lever %s" % ["I", "II", "III", "IV"][clampi(number - 1, 0, 3)]


func interact(_player: Node) -> void:
	if is_down:
		return
	set_down(true)
	Audio.play_at(&"lever", global_position, -2.0)
	pulled.emit(self)
