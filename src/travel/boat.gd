class_name Boat
extends StaticBody3D
## A rowing boat (Milestone 29). Craft a Rowboat at a workbench, place it on
## water (it floats; on land it can't be placed), press interact (F) to climb in. Row with
## the move keys; hold sprint to row hard (it costs the rower's stamina). The boat
## can't go onto land: press interact or the dodge key near the shore to step out onto
## the bank. It stays where you leave it and is saved with the world.

const SCENE_PATH := "res://scenes/world/rowboat.tscn"
const ITEM_ID := &"rowboat"
const ROW_SPEED := 7.0
const ROW_HARD_SPEED := 10.5
const HARD_COST := 6.0  # rower's stamina per second
## The deck sits this far below the water line.
const DRAFT := 0.25

var rider: Node3D = null
var _model: Node3D
var _oars: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	add_to_group(&"boats")
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.8, 3.0)
	cs.shape = box
	cs.position.y = 0.3
	add_child(cs)
	_model = Node3D.new()
	add_child(_model)
	var wood := Color(0.52, 0.34, 0.2)
	var dark := wood.darkened(0.3)
	var b := BlockMesh.new()
	b.box(Vector3(0, 0.05, 0), Vector3(1.1, 0.12, 2.6), dark)  # bottom
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.6, 0.3, 0), Vector3(0.12, 0.45, 2.5), wood)  # sides
		b.box(Vector3(sx * 0.6, 0.55, 0), Vector3(0.18, 0.08, 2.5), wood.lightened(0.15))  # gunwale
	b.box(Vector3(0, 0.3, 1.3), Vector3(1.2, 0.45, 0.12), wood)  # bow
	b.box(Vector3(0, 0.38, 1.45), Vector3(0.7, 0.35, 0.2), wood.lightened(0.1))
	b.box(Vector3(0, 0.3, -1.3), Vector3(1.2, 0.45, 0.12), wood)  # stern
	b.box(Vector3(0, 0.36, 0.25), Vector3(1.1, 0.08, 0.35), wood.lightened(0.2))  # seat
	b.box(Vector3(0, 0.36, -0.85), Vector3(1.1, 0.08, 0.3), wood.lightened(0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	_model.add_child(mi)
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.62, 0.6, 0.1)
		_model.add_child(pivot)
		var ob := BlockMesh.new()
		ob.box(Vector3(sx * 0.7, -0.1, 0), Vector3(1.5, 0.06, 0.06), Color(0.66, 0.5, 0.32))
		ob.box(Vector3(sx * 1.45, -0.18, 0), Vector3(0.3, 0.04, 0.16), Color(0.6, 0.44, 0.28))
		var om := MeshInstance3D.new()
		om.mesh = ob.commit()
		pivot.add_child(om)
		_oars.append(pivot)


var _stroke := 0


func _process(delta: float) -> void:
	_t += delta
	# Bob on the water.
	_model.position.y = sin(_t * 1.7) * 0.04
	_model.rotation.z = sin(_t * 1.3) * 0.03
	var rowing := rider != null and rider.get("velocity") is Vector3 and Vector2(rider.velocity.x, rider.velocity.z).length() > 0.5
	# Milestone 37: a splash of the oars at each stroke.
	var stroke := int(_t * 5.0 / PI)
	if rowing and stroke != _stroke:
		Audio.play_at(&"oar", global_position, -8.0, 0.1)
	_stroke = stroke
	for i in _oars.size():
		var side := -1.0 if i == 0 else 1.0
		_oars[i].rotation.y = (sin(_t * 5.0) * 0.6 * side) if rowing else lerpf(_oars[i].rotation.y, 0.0, delta * 3.0)
		_oars[i].rotation.z = (absf(cos(_t * 5.0)) * 0.25 * side) if rowing else 0.0


# --- Interaction ----------------------------------------------------------------------

func is_interactable() -> bool:
	return rider == null


func get_interact_text() -> String:
	return "Climb into the rowboat (hold Shift: pick it up)"


func interact(player: Node) -> void:
	if rider != null:
		return
	if Input.is_action_pressed(&"sprint"):
		pick_up(player)
		return
	board(player)


func board(player: Node) -> bool:
	if rider != null or not player.has_method("start_riding"):
		return false
	if not player.start_riding(self):
		return false
	rider = player
	collision_layer = 0
	return true


## Back into the bag.
func pick_up(player: Node) -> void:
	if rider != null:
		return
	player.give_or_drop(ITEM_ID, 1)
	queue_free()


func on_dismounted(_pos: Vector3, _yaw: float) -> void:
	rider = null
	collision_layer = Layers.INTERACTABLE


func ride_speed(wants_hard: bool, moving: bool, delta: float) -> float:
	if wants_hard and moving and rider and rider.stamina.current > 1.0:
		rider.stamina.consume(HARD_COST * delta)
		return ROW_HARD_SPEED
	return ROW_SPEED


## Called by the rower every physics frame.
func follow_rider(pos: Vector3, yaw: float, _speed: float, _delta: float) -> void:
	global_position = Vector3(pos.x, water_y(), pos.z)
	rotation = Vector3(0, yaw, 0)


static func water_y() -> float:
	return TerrainGenerator.WATER_Y - DRAFT


## Places the boat on the water at `pos` (or returns null on land).
static func launch(world: World, pos: Vector3) -> Boat:
	if world == null or world.layer != TerrainGenerator.Layer.SURFACE or not world.is_deep_water(pos):
		Events.toast.emit("Put the boat on deep water", Color(1, 0.7, 0.5))
		return null
	var b := (load(SCENE_PATH) as PackedScene).instantiate() as Boat
	world.placed_root.add_child(b)
	b.global_position = Vector3(pos.x, water_y(), pos.z)
	if Net.is_server():
		Net.server.broadcast_placed({"scene": SCENE_PATH, "position": [b.global_position.x, b.global_position.y, b.global_position.z],
			"rotation_y": 0.0})
	return b


func save_data() -> Dictionary:
	return {}


func load_data(_d: Dictionary) -> void:
	pass
