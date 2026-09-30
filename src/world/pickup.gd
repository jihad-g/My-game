class_name Pickup
extends Area3D
## A dropped item stack lying in the world. Pooled.
## Floats, bobs, gets pulled toward a nearby player and auto-collects.

const MAGNET_RANGE := 2.6
const COLLECT_RANGE := 0.7
const PICKUP_DELAY := 0.5
const LIFETIME := 300.0

var item_id: StringName
var count: int = 1
## Loot drops fly to the player; items the player dropped must be picked up with F.
var auto_collect: bool = true
var _age := 0.0
var _velocity := Vector3.ZERO
var _ground_y := 0.0
var _visual: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	cs.shape = sphere
	add_child(cs)
	_visual = MeshInstance3D.new()
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_visual)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 0.6
	_label.font_size = 28
	_label.outline_size = 8
	_label.pixel_size = 0.004
	_label.no_depth_test = true
	add_child(_label)


func setup(p_item_id: StringName, p_count: int, pos: Vector3, ground_y: float, p_auto_collect: bool = true) -> void:
	item_id = p_item_id
	auto_collect = p_auto_collect
	count = p_count
	_age = 0.0
	_ground_y = ground_y
	global_position = pos
	_velocity = Vector3(randf_range(-1.5, 1.5), 3.5, randf_range(-1.5, 1.5))
	var item: ItemData = ItemDB.get_item(item_id)
	var col := item.icon_color if item else Color.MAGENTA
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, Vector3(0.3, 0.3, 0.3), col)
	b.box(Vector3(0, 0.2, 0), Vector3(0.14, 0.1, 0.14), col.lightened(0.3))
	_visual.mesh = b.commit()
	_label.text = "%s%s" % [item.display_name if item else String(item_id), " x%d" % count if count > 1 else ""]
	_label.modulate = item.rarity_color() if item else Color.WHITE


func get_interact_text() -> String:
	return "Pick up %s" % _label.text


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		NodePool.release_or_free(self)
		return
	# Toss arc, then rest on the ground.
	var rest_y := _ground_y + 0.35
	if _velocity != Vector3.ZERO:
		_velocity.y -= 12.0 * delta
		global_position += _velocity * delta
		if global_position.y <= rest_y and _velocity.y < 0.0:
			global_position.y = rest_y
			_velocity = Vector3.ZERO
	_visual.rotation.y += delta * 2.0
	_visual.position.y = sin(_age * 3.0) * 0.08

	if _age < PICKUP_DELAY or not auto_collect:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or not player.has_method("give_item") or player.get("is_dead"):
		return
	var target := player.global_position + Vector3(0, 0.8, 0)
	var dist := global_position.distance_to(target)
	if dist < COLLECT_RANGE:
		collect(player)
	elif dist < MAGNET_RANGE:
		_velocity = Vector3.ZERO
		global_position = global_position.move_toward(target, delta * (4.0 + (MAGNET_RANGE - dist) * 6.0))


func interact(player: Node) -> void:
	collect(player)


func collect(player: Node) -> void:
	var left: int = player.give_item(item_id, count)
	if left <= 0:
		NodePool.release_or_free(self)
	else:
		count = left
		_age = -2.0  # inventory full: wait before trying again
