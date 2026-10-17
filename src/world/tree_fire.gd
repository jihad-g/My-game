class_name TreeFire
extends Node3D
## A burning tree (Milestone 28). Lightning starts it (WeatherSystem.strike_tree);
## Creative mode can start one too.
##
## The fire grows for a few seconds, burns for BURN_TIME and then the tree falls:
## it is removed like a chopped tree (it regrows later) and leaves its wood and a
## lump of coal. It can jump to trees within SPREAD_RADIUS. Heavy rain puts it out
## early and the tree survives. Standing in it sets you on fire.

const BURN_TIME := 18.0
## Rain puts the fire out after this long (rain_at > RAIN_PUT_OUT).
const RAIN_TIME := 9.0
const RAIN_PUT_OUT := 0.55
const SPREAD_RADIUS := 4.5
const SPREAD_CHANCE := 0.35
## Most trees that can burn at once.
const MAX_FIRES := 8
const BURN_DPS := 4.0

static var active := 0

var tree: PropBody
var chunk: Chunk
var prop_index := -1
var age := 0.0
var put_out := false
var burned_down := false
## The coal left behind (tests).
var left_coal: Node3D
var _height := 4.0
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _tick := 0.0
var _spread_done := false
var _rain_t := 0.0


## Trees (harvestable with an axe, taller than 2 m) in a ring around `center`.
static func trees_near(world: Node3D, center: Vector3, radius: float, min_dist: float = 0.0) -> Array[PropBody]:
	var out: Array[PropBody] = []
	if world == null or not world.is_inside_tree():
		return out
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = Layers.PROP | Layers.INTERACTABLE
	q.collide_with_bodies = true
	for hit in space.intersect_shape(q, 256):
		var b := hit.collider as PropBody
		if b == null or b.data == null or b.has_meta(&"burning"):
			continue
		if b.data.tool_kind != &"axe" or b.data.collision_height < 2.0:
			continue
		var d := Vector2(b.global_position.x - center.x, b.global_position.z - center.z).length()
		if d >= min_dist and d <= radius:
			out.append(b)
	return out


## Sets `p_tree` on fire. Returns null if it already burns or too many trees burn.
static func ignite(p_tree: PropBody) -> TreeFire:
	if p_tree == null or not is_instance_valid(p_tree) or p_tree.has_meta(&"burning") or active >= MAX_FIRES:
		return null
	var f := TreeFire.new()
	f.tree = p_tree
	f.chunk = p_tree.chunk
	f.prop_index = p_tree.prop_index
	p_tree.set_meta(&"burning", true)
	var parent: Node = p_tree.chunk if is_instance_valid(p_tree.chunk) else p_tree.get_parent()
	parent.add_child(f)
	f.global_position = p_tree.global_position
	return f


func _ready() -> void:
	active += 1
	add_to_group(&"tree_fires")
	add_to_group(&"heat_sources")
	_height = tree.data.collision_height * tree.scale.y if is_instance_valid(tree) else 4.0
	var cols := [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.15), Color(1.0, 0.32, 0.1)]
	# Flames lick out of the crown and up the trunk (outside the leaves, so they show).
	for k in 9:
		var fb := BlockMesh.new()
		var sz := 1.1 - (k % 3) * 0.25
		fb.box(Vector3.ZERO, Vector3(sz, sz * 1.6, sz), cols[k % 3])
		var fm := fb.commit()
		fm.surface_set_material(0, Materials.vertex_color_emissive())
		var mi := MeshInstance3D.new()
		mi.mesh = fm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 7.0 + 0.4
		if k < 7:
			var r := 1.2 + (k % 2) * 0.7
			mi.position = Vector3(cos(a) * r, _height * (0.5 + 0.45 * float(k) / 7.0), sin(a) * r)
		else:
			mi.position = Vector3(cos(a) * 0.45, _height * (0.12 + 0.2 * (k - 7)), sin(a) * 0.45)
		mi.scale = Vector3.ONE * 0.01
		add_child(mi)
		_flames.append(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.omni_range = 12.0
	_light.light_energy = 0.0
	_light.position.y = _height * 0.7
	add_child(_light)
	Audio.play_at(&"fire_ignite", global_position + Vector3(0, 2, 0), 0.0)


func _exit_tree() -> void:
	active = maxi(0, active - 1)
	if is_instance_valid(tree):
		tree.remove_meta(&"burning")


## 0..1 how big the fire is right now.
func strength() -> float:
	if put_out:
		return 0.0
	return clampf(age / 3.0, 0.0, 1.0) * clampf((BURN_TIME - age) / 2.0 + 0.3, 0.0, 1.0)


## Degrees C added near the fire (it warms you like a campfire).
func heat_at(pos: Vector3) -> float:
	var d := pos.distance_to(global_position)
	return 0.0 if d > 8.0 else 25.0 * (1.0 - d / 8.0) * strength()


func _process(delta: float) -> void:
	age += delta
	var s := strength()
	var t := age
	for k in _flames.size():
		var f := _flames[k]
		var w := s * (0.8 + sin(t * (6.0 + k * 1.7) + k) * 0.2)
		f.scale = Vector3(w, w * (1.0 + sin(t * 9.0 + k) * 0.15), w)
		f.rotation.y = t * (1.0 + k * 0.3)
	_light.light_energy = s * (3.0 + sin(t * 11.0) * 0.4)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	if VFX.enabled and s > 0.2:
		VFX.motes(get_parent(), global_position + Vector3(0, _height * 0.8, 0), Color(0.25, 0.22, 0.2, 0.6), 4, 1.0)
	_hurt_nearby(s)
	var world := World.instance
	var rain := world.weather.rain_at(global_position) if world and world.weather else 0.0
	_rain_t = _rain_t + 0.5 if rain > RAIN_PUT_OUT else maxf(0.0, _rain_t - 0.5)
	if _rain_t >= RAIN_TIME:
		extinguish()
		return
	if not _spread_done and age > 6.0:
		_spread_done = true
		_spread(rain)
	if age >= BURN_TIME:
		_burn_down()


func _hurt_nearby(s: float) -> void:
	if s < 0.4:
		return
	for p in get_tree().get_nodes_in_group(&"player"):
		var n := p as Node3D
		if n == null or not n.has_method("afflict"):
			continue
		var d := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
		if d < 1.6 and absf(n.global_position.y - global_position.y) < _height:
			n.afflict(&"burn", 2.0, {"dps": BURN_DPS})


func _spread(rain: float) -> void:
	var chance := SPREAD_CHANCE * (0.3 if rain > 0.2 else 1.0)
	for b in TreeFire.trees_near(World.instance, global_position, SPREAD_RADIUS, 0.5):
		if randf() < chance:
			TreeFire.ignite(b)


## Rain (or water) puts the fire out: the tree stays.
func extinguish() -> void:
	if put_out or burned_down:
		return
	put_out = true
	VFX.dust(get_parent(), global_position + Vector3(0, _height * 0.6, 0), Color(0.6, 0.6, 0.62, 0.7), 12)
	Audio.play_at(&"splash", global_position + Vector3(0, 2, 0), -2.0)
	queue_free()


func _burn_down() -> void:
	if burned_down:
		return
	burned_down = true
	var pos := global_position
	if is_instance_valid(chunk):
		chunk.harvest_prop(prop_index, null)  # falls like a chopped tree, drops its wood
	if World.instance:
		left_coal = World.instance.spawn_pickup(&"coal", 1, pos + Vector3(0, 0.8, 0), false)
	VFX.debris(get_parent(), pos + Vector3(0, 1.0, 0), Color(0.2, 0.17, 0.15), 14)
	Audio.play_at(&"tree_fall", pos, -2.0)
	queue_free()
