class_name NodePool
extends Node
## Generic object pool for scene instances (enemies, pickups, damage numbers...).
##
## Released nodes stay in the tree but are hidden and have processing disabled
## (which also removes CollisionObjects from physics via disable_mode). Pooled
## scenes may implement `on_pool_acquire()` and `on_pool_release()`.

@export var scene: PackedScene
@export var prewarm: int = 0
## Hard cap on live + free instances (0 = unlimited).
@export var max_size: int = 0

var _free: Array[Node] = []
var _all: Array[Node] = []


func _ready() -> void:
	for i in prewarm:
		var n := _create()
		if n:
			_deactivate(n)
			_free.append(n)


func acquire() -> Node:
	var node: Node = null
	while not _free.is_empty() and node == null:
		node = _free.pop_back()
		if not is_instance_valid(node):
			node = null
	if node == null:
		if max_size > 0 and _all.size() >= max_size:
			return null
		node = _create()
		if node == null:
			return null
	_activate(node)
	if node.has_method("on_pool_acquire"):
		node.on_pool_acquire()
	return node


func release(node: Node) -> void:
	if not is_instance_valid(node) or _free.has(node):
		return
	if node.has_method("on_pool_release"):
		node.on_pool_release()
	_deactivate(node)
	_free.append(node)


func active_count() -> int:
	return _all.size() - _free.size()


func total_count() -> int:
	return _all.size()


func _create() -> Node:
	if scene == null:
		push_error("NodePool '%s' has no scene" % name)
		return null
	var n := scene.instantiate()
	n.set_meta(&"pool", self)
	add_child(n)
	_all.append(n)
	return n


func _activate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is Node3D:
		(node as Node3D).visible = true


func _deactivate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Node3D:
		(node as Node3D).visible = false


## Releases `node` to the pool it came from, or frees it if not pooled.
static func release_or_free(node: Node) -> void:
	if node.has_meta(&"pool"):
		var pool = node.get_meta(&"pool")
		if is_instance_valid(pool):
			pool.release(node)
			return
	node.queue_free()
