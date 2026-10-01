class_name Chunk
extends Node3D
## Scene-side representation of one terrain chunk at a given LOD.
##
## Chunks are pooled by ChunkManager and rebuilt in place from ChunkData.
## LOD0: terrain mesh + collision + interactive props (PropBody).
## LOD1: terrain mesh + decorative props (no collision).
## LOD2: coarse terrain mesh only, no shadows.

var coord: Vector2i
var lod: int = -1
var layer: int = 0
var library: PropLibrary

var _terrain_mesh := ArrayMesh.new()
var _water_mesh := ArrayMesh.new()
var _terrain_mi := MeshInstance3D.new()
var _water_mi := MeshInstance3D.new()
var _body := StaticBody3D.new()
var _collision := CollisionShape3D.new()
var _shape := ConcavePolygonShape3D.new()
var _prop_mmis: Dictionary = {}  # StringName -> MultiMeshInstance3D
var _features: Array[Node] = []

## Scenes for special structures produced by the generator (data.features).
const FEATURE_SCENES := {
	&"cave_entrance": "res://scenes/world/cave_entrance.tscn",
	&"cave_exit": "res://scenes/world/cave_exit.tscn",
}
static var _feature_cache: Dictionary = {}
## prop index -> {"prop_id", "mm_index", "transform", "position", "body"}
var _instances: Dictionary = {}


func _init() -> void:
	_terrain_mi.mesh = _terrain_mesh
	add_child(_terrain_mi)
	_water_mi.mesh = _water_mesh
	_water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water_mi)
	_shape.backface_collision = true
	_collision.shape = _shape
	_body.collision_layer = Layers.TERRAIN
	_body.collision_mask = 0
	_body.add_child(_collision)
	add_child(_body)


func build(data: ChunkData) -> void:
	clear_props()
	coord = data.coord
	lod = data.lod
	layer = data.layer
	name = "Chunk_%d_%d" % [coord.x, coord.y]
	position = Vector3(coord.x * TerrainGenerator.CHUNK_SIZE, 0.0, coord.y * TerrainGenerator.CHUNK_SIZE)
	visible = true

	_terrain_mesh.clear_surfaces()
	if not data.vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data.vertices
		arrays[Mesh.ARRAY_NORMAL] = data.normals
		arrays[Mesh.ARRAY_COLOR] = data.colors
		arrays[Mesh.ARRAY_INDEX] = data.indices
		_terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_terrain_mesh.surface_set_material(0, Materials.vertex_color())
	_terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod <= 1 \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_water_mesh.clear_surfaces()
	if not data.water_vertices.is_empty():
		var warrays := []
		warrays.resize(Mesh.ARRAY_MAX)
		warrays[Mesh.ARRAY_VERTEX] = data.water_vertices
		var wn := PackedVector3Array()
		wn.resize(data.water_vertices.size())
		wn.fill(Vector3.UP)
		warrays[Mesh.ARRAY_NORMAL] = wn
		warrays[Mesh.ARRAY_INDEX] = data.water_indices
		_water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warrays)
		_water_mesh.surface_set_material(0, Materials.water())

	if lod == 0 and not data.collision_faces.is_empty():
		_shape.set_faces(data.collision_faces)
		_body.process_mode = Node.PROCESS_MODE_INHERIT
		_collision.disabled = false
	else:
		_shape.set_faces(PackedVector3Array())
		_collision.disabled = true
		_body.process_mode = Node.PROCESS_MODE_DISABLED

	_build_props(data)
	_build_features(data)


func _build_features(data: ChunkData) -> void:
	for f: Dictionary in data.features:
		var path: String = FEATURE_SCENES.get(f.type, "")
		if path == "":
			continue
		if not _feature_cache.has(path):
			_feature_cache[path] = load(path)
		var node := (_feature_cache[path] as PackedScene).instantiate() as Node3D
		node.position = f.position
		if node.has_method("setup"):
			node.setup(f)
		add_child(node)
		_features.append(node)


func has_collision() -> bool:
	return lod == 0 and not _collision.disabled


func _build_props(data: ChunkData) -> void:
	if library == null:
		return
	var groups: Dictionary = {}  # prop_id -> Array of prop dicts
	for p: Dictionary in data.props:
		var pdata := library.get_prop(p.prop_id)
		if pdata == null:
			continue
		if GameState.is_prop_removed(coord, p.index, pdata.regrow_time, layer):
			continue
		if not groups.has(p.prop_id):
			groups[p.prop_id] = []
		groups[p.prop_id].append(p)

	for prop_id: StringName in groups:
		var list: Array = groups[prop_id]
		var pdata := library.get_prop(prop_id)
		var mmi := _get_mmi(prop_id, pdata)
		var mm := mmi.multimesh
		mm.instance_count = list.size()
		for k in list.size():
			var p: Dictionary = list[k]
			var s: float = p.scale
			var xf := Transform3D(Basis(Vector3.UP, p.rotation).scaled(Vector3(s, s, s)), p.position)
			mm.set_instance_transform(k, xf)
			var entry := {"prop_id": prop_id, "mm_index": k, "transform": xf, "position": p.position, "body": null}
			if lod == 0 and pdata.interact_mode != PropData.InteractMode.NONE:
				entry.body = _create_body(p.index, pdata, p.position, s)
			_instances[p.index] = entry
		mmi.visible = true


func _get_mmi(prop_id: StringName, pdata: PropData) -> MultiMeshInstance3D:
	if _prop_mmis.has(prop_id):
		return _prop_mmis[prop_id]
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = library.get_mesh(prop_id)
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pdata.cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if pdata.visibility_range > 0.0:
		mmi.visibility_range_end = pdata.visibility_range
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	_prop_mmis[prop_id] = mmi
	return mmi


func _create_body(index: int, pdata: PropData, pos: Vector3, s: float) -> PropBody:
	var body := PropBody.new()
	body.setup(self, index, pdata)
	if pdata.blocks_movement:
		body.collision_layer = Layers.PROP
	else:
		body.collision_layer = Layers.INTERACTABLE
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = library.get_shape(pdata.id)
	cs.position.y = pdata.collision_height * 0.5
	body.add_child(cs)
	body.position = pos
	body.scale = Vector3(s, s, s)
	add_child(body)
	return body


## Removes a prop permanently (until it regrows) and hands out its drops.
## `gatherer` receives items directly; otherwise drops spawn as pickups.
func harvest_prop(index: int, gatherer: Node) -> void:
	if not _instances.has(index):
		return
	var entry: Dictionary = _instances[index]
	var pdata := library.get_prop(entry.prop_id)
	var world_pos: Vector3 = to_global(entry.position)
	_hide_instance(entry)
	_instances.erase(index)
	GameState.mark_prop_removed(coord, index, layer)
	if Net.is_server():
		Net.server.broadcast_prop_removed(coord, layer, index)
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtils.hash3(index, int(GameState.world_time * 10.0), coord.x * 31 + coord.y)
	# Crafting skill: chance of one extra item per drop.
	var bonus_chance := 0.0
	if World.instance and World.instance.player:
		bonus_chance = World.instance.player.character.harvest_bonus_chance()
	var xp := pdata.xp if pdata.xp > 0 else (3 if pdata.interact_mode == PropData.InteractMode.HARVEST else 1)
	Events.resource_harvested.emit(pdata.id, xp)
	for loot in pdata.drops:
		if not loot is LootEntry:
			continue
		var n: int = loot.roll(rng)
		if n <= 0:
			continue
		if rng.randf() < bonus_chance:
			n += 1
		if gatherer and gatherer.has_method("give_item"):
			gatherer.give_item(loot.item_id, n)
		elif World.instance:
			World.instance.spawn_pickup(loot.item_id, n, world_pos + Vector3(0, 0.8, 0))


## Hides a prop that is gone (another player took it; multiplayer, Milestone 11).
func hide_prop(index: int) -> void:
	if not _instances.has(index):
		return
	_hide_instance(_instances[index])
	_instances.erase(index)


## Hides every prop the world state says is removed (after a region snapshot).
func refresh_removed() -> void:
	for index in _instances.keys():
		var pdata := library.get_prop(_instances[index].prop_id)
		if pdata and GameState.is_prop_removed(coord, index, pdata.regrow_time, layer):
			hide_prop(index)


## Quick "wobble" feedback when a harvestable prop is hit.
func pulse_prop(index: int) -> void:
	if not _instances.has(index):
		return
	var entry: Dictionary = _instances[index]
	var mm: MultiMesh = _prop_mmis[entry.prop_id].multimesh
	var base: Transform3D = entry.transform
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if _instances.get(index) != entry:
			return
		var squash := 1.0 + sin(t * PI) * 0.12
		mm.set_instance_transform(entry.mm_index, Transform3D(base.basis.scaled(Vector3(squash, 1.0 / squash, squash)), base.origin)),
		0.0, 1.0, 0.18)


func _hide_instance(entry: Dictionary) -> void:
	var mm: MultiMesh = _prop_mmis[entry.prop_id].multimesh
	mm.set_instance_transform(entry.mm_index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -1000, 0)))
	if is_instance_valid(entry.body):
		entry.body.queue_free()


func prop_count() -> int:
	return _instances.size()


func clear_props() -> void:
	for index in _instances:
		var body = _instances[index].body
		if is_instance_valid(body):
			body.queue_free()
	_instances.clear()
	for f in _features:
		if is_instance_valid(f):
			f.queue_free()
	_features.clear()
	for id in _prop_mmis:
		var mmi: MultiMeshInstance3D = _prop_mmis[id]
		mmi.multimesh.instance_count = 0
		mmi.visible = false


## Called when the chunk goes back to the pool.
func release() -> void:
	clear_props()
	lod = -1
	visible = false
	_collision.disabled = true
	_body.process_mode = Node.PROCESS_MODE_DISABLED
