class_name DungeonGate
extends StaticBody3D
## Milestone 31: locked iron bars across a corridor into a dungeon's last room.
## The key (a Dungeon Key) is carried by the floor's Keeper. Interact with the
## key in your bag to open every gate of that room at once.

const KEY_ITEM := &"dungeon_key"

var size := Vector3(3, 3.5, 0.3)
var horizontal := false
var is_open := false
## The other gates of the same room (they open together).
var group: Array = []
var _bars: Node3D


func _ready() -> void:
	add_to_group(&"dungeon_gates")
	collision_layer = Layers.PROP | Layers.INTERACTABLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	_bars = Node3D.new()
	add_child(_bars)
	var b := BlockMesh.new()
	var n := 7
	var iron := Color(0.3, 0.28, 0.32)
	for k in n:
		var off := (k - (n - 1) * 0.5) * 0.45
		var p := Vector3(0, size.y * 0.5, off) if horizontal else Vector3(off, size.y * 0.5, 0)
		b.box(p, Vector3(0.1, size.y, 0.1), iron)
	var w := maxf(size.x, size.z)
	b.box(Vector3(0, 0.6, 0), Vector3(0.14, 0.12, w) if horizontal else Vector3(w, 0.12, 0.14), iron * 1.2)
	b.box(Vector3(0, size.y - 0.4, 0), Vector3(0.14, 0.12, w) if horizontal else Vector3(w, 0.12, 0.14), iron * 1.2)
	# A big padlock in the middle.
	b.box(Vector3(0, 1.3, 0), Vector3(0.3, 0.36, 0.3), Color(0.85, 0.65, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	_bars.add_child(mi)


func get_interact_text() -> String:
	return "Locked gate (the floor's Keeper has the key)" if not _has_key() else "Unlock the gate with the Dungeon Key"


func _has_key() -> bool:
	var w := World.instance
	return w != null and w.player != null and w.player.inventory.count_of(KEY_ITEM) > 0


func interact(player: Node) -> void:
	if is_open:
		return
	if player.inventory.count_of(KEY_ITEM) <= 0:
		Events.toast.emit("Locked. Defeat the Keeper of this floor for the key", Color(1, 0.75, 0.45))
		Audio.play(&"error", -6.0)
		return
	player.inventory.remove_item(KEY_ITEM, 1)
	for g in group:
		if is_instance_valid(g):
			g.open()
	open()
	Events.toast.emit("The gate unlocks!", UITheme.GOLD)


func open() -> void:
	if is_open:
		return
	is_open = true
	collision_layer = 0
	Audio.play_at(&"gate_open", global_position, 0.0)
	var tw := create_tween()
	tw.tween_property(_bars, "position:y", -size.y + 0.1, 0.8).set_trans(Tween.TRANS_QUAD)
	NavGrid.invalidate_at(global_position)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
