class_name PoiLayout
extends RefCounted
## Deterministic plan of a point of interest (like SettlementLayout, smaller).
## Local coordinates: origin = POI centre at its (flattened) ground height.

## Rank scaling (E..S) for guardians and dungeon monsters.
const RANK_POWER := [1.0, 1.4, 2.0, 2.8, 3.8, 5.0]
const RANK_DAMAGE := [1.0, 1.2, 1.45, 1.75, 2.1, 2.5]
const RANK_LEVELS := [0, 4, 10, 18, 28, 40]
const RANK_XP := [1.0, 1.5, 2.2, 3.2, 4.5, 6.0]
## Monsters per dungeon theme: [melee, ranged/caster, boss]
const THEME_MONSTERS := [
	[&"skeleton_warrior", &"skeleton_archer", &"bone_king"],
	[&"arcane_sentinel", &"arcane_wisp", &"arcane_colossus"],
	[&"thorn_crawler", &"grotto_cultist", &"elder_thornmaw"],
]

var poi: PoiInfo
var statics: Array = []
var boxes: Array = []
var roofs: Dictionary = {}
var buildings: Array = []        # {rect: Rect2}
var doors: Array = []
## {table, xform, key, golden, sealed}
var chests: Array = []
## {data, pos, key, dormant: float (0 = awake), home_leash}
var guardians: Array = []
## {kind (PoiObject.Kind), xform, key, item, mesh}
var objects: Array = []
## {xform, size, is_floor, key, reveals (chest dict)}
var cracked: Array = []
var lights: Array = []  # [pos, color]
var _ground: Callable


static func build(p: PoiInfo, ground: Callable = Callable()) -> PoiLayout:
	var l := PoiLayout.new()
	l.poi = p
	l._ground = ground
	match p.kind:
		PoiInfo.Kind.RUINS:
			l._ruins()
		PoiInfo.Kind.TOWER:
			l._tower()
		PoiInfo.Kind.TEMPLE:
			l._temple()
		PoiInfo.Kind.DUNGEON:
			l._entrance()
		PoiInfo.Kind.GROVE:
			l._grove()
	return l


func _r(salt: int) -> float:
	return HashUtils.to_unit(poi.seed, salt)


func _deco(mesh: StringName, xform: Transform3D, box_size: Vector3 = Vector3.ZERO, box_center: Vector3 = Vector3.ZERO, fade: bool = false, glow: bool = false) -> void:
	statics.append({"mesh": mesh, "xform": xform, "box_size": box_size, "box_center": box_center, "fade": fade, "glow": glow})


func _piece(id: StringName, xform: Transform3D) -> void:
	var d := BuildingManager.get_piece_data(id)
	_deco(d.mesh, xform, d.collision_size if d.blocks_movement else Vector3.ZERO, d.collision_center, d.fade_near_camera)


func _y(x: float, z: float) -> float:
	## Local ground height (groves are not flattened).
	if not _ground.is_valid():
		return 0.0
	return float(_ground.call(Vector3(poi.center.x + 0.5 + x, 0, poi.center.y + 0.5 + z))) - poi.ground_y()


func _guard(data_id: StringName, pos: Vector3, k: int, dormant: float = 0.0) -> void:
	guardians.append({"data": data_id, "pos": pos, "key": "%s:g%d" % [poi.id, k], "dormant": dormant})


func _brazier(pos: Vector3) -> void:
	_deco(&"brazier", Transform3D(Basis.IDENTITY, pos), Vector3(0.7, 1.2, 0.7), Vector3(0, 0.6, 0))
	_deco(&"brazier_fire", Transform3D(Basis.IDENTITY, pos), Vector3.ZERO, Vector3.ZERO, false, true)
	lights.append([pos + Vector3(0, 1.6, 0), Color(1.0, 0.65, 0.3)])


# --- Ruins --------------------------------------------------------------------------------

func _ruins() -> void:
	var k := 0
	for x in range(-5, 5):
		for side in [-4, 4]:
			_ruin_edge(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, side)), k)
			k += 1
	for z in range(-4, 4):
		for side in [-5, 5]:
			_ruin_edge(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side, 0, z + 0.5)), k)
			k += 1
	for c: Vector2 in [Vector2(-5, -4), Vector2(5, -4), Vector2(-5, 4), Vector2(5, 4)]:
		var broken := _r(k) < 0.5
		_deco(&"pillar_broken" if broken else &"pillar", Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)),
			Vector3(0.7, 1.4 if broken else 3.2, 0.7), Vector3(0, 0.7 if broken else 1.6, 0))
		k += 1
	for i in 6:
		var a := TAU * _r(50 + i)
		var d := 2.0 + _r(60 + i) * 7.0
		_deco(&"rubble", Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * d, 0, sin(a) * d)))
	for i in 10:
		var x := int(_r(70 + i) * 9.0) - 4
		var z := int(_r(80 + i) * 7.0) - 3
		_deco(&"stone_floor", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, -0.1, z + 0.5)))
	chests.append({"table": &"ruin_chest", "xform": Transform3D(Basis.IDENTITY, Vector3(2.5, 0, -2.5)), "key": "%s:c0" % poi.id, "golden": false, "sealed": false})
	if _r(90) < 0.5:
		cracked.append({"xform": Transform3D(Basis.IDENTITY, Vector3(-2.0, 0, 1.5)), "size": Vector3(1.8, 0.2, 1.8), "is_floor": true,
			"key": "vault:%s" % poi.id, "reveals": {"table": &"vault", "xform": Transform3D(Basis.IDENTITY, Vector3(-2.0, 0, 1.5)),
			"key": "%s:vault" % poi.id, "golden": true, "sealed": false}})
	var n := 2 + poi.rank / 2
	for i in n:
		var a := TAU * i / n + 0.5
		_guard(&"skeleton_archer" if i % 3 == 2 else &"skeleton_warrior", Vector3(cos(a) * 3.0, 0.3, sin(a) * 2.5), i)


func _ruin_edge(xf: Transform3D, k: int) -> void:
	var roll := _r(k)
	if roll < 0.35:
		return
	if roll < 0.7:
		_deco(&"ruin_wall_low", xf, Vector3(1.0, 0.7, 0.35), Vector3(0, 0.35, 0))
	elif roll < 0.9:
		_deco(&"ruin_wall_mid", xf, Vector3(1.0, 1.5, 0.35), Vector3(0, 0.75, 0))
	else:
		_piece(&"stone_wall", xf)


# --- Wizard tower -------------------------------------------------------------------------

func _tower() -> void:
	var x0 := -3
	var z0 := -3
	var n := 6
	for x in range(x0, x0 + n):
		for z in range(z0, z0 + n):
			_deco(&"stone_floor", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, z + 0.5)))
	boxes.append({"size": Vector3(n, 0.13, n), "xform": Transform3D(Basis.IDENTITY, Vector3(x0 + n * 0.5, 0.065, z0 + n * 0.5))})
	for level in 3:
		var y := level * 2.6
		for i in n:
			for side in 4:
				var xf: Transform3D
				match side:
					0:
						xf = Transform3D(Basis.IDENTITY, Vector3(x0 + i + 0.5, y, z0))
					1:
						xf = Transform3D(Basis.IDENTITY, Vector3(x0 + i + 0.5, y, z0 + n))
					2:
						xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x0, y, z0 + i + 0.5))
					_:
						xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x0 + n, y, z0 + i + 0.5))
				if level == 0 and side == 1 and i == n / 2:
					doors.append(xf)
					continue
				if level == 1 and i == n / 2 and side != 1:
					_deco(&"wood_window", xf, Vector3.ZERO, Vector3.ZERO, true)
				elif level == 0:
					_piece(&"stone_wall", xf)
				else:
					_deco(&"stone_wall", xf, Vector3.ZERO, Vector3.ZERO, true)
	var roof: Array = []
	for x in range(x0, x0 + n):
		for z in range(z0, z0 + n):
			roof.append({"mesh": &"stone_floor", "xform": Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 7.9, z + 0.5))})
			if x == x0 or z == z0 or x == x0 + n - 1 or z == z0 + n - 1:
				if (x + z) % 2 == 0:
					roof.append({"mesh": &"crate", "xform": Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 8.0, z + 0.5))})
	roofs[0] = roof
	buildings.append({"rect": Rect2(x0, z0, n, n)})
	objects.append({"kind": PoiObject.Kind.LECTERN, "xform": Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -1.8)), "key": "tome:%s" % poi.id})
	_deco(&"lectern", Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -1.8)))
	_deco(&"lectern_book", Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -1.8)), Vector3.ZERO, Vector3.ZERO, false, true)
	_piece(&"table", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.8, 0.13, 0.5)))
	_deco(&"barrel", Transform3D(Basis.IDENTITY, Vector3(1.9, 0.13, 1.8)), Vector3(0.55, 0.8, 0.55), Vector3(0, 0.4, 0))
	lights.append([Vector3(0, 2.2, 0), Color(0.6, 0.7, 1.0)])
	chests.append({"table": &"tower", "xform": Transform3D(Basis(Vector3.UP, PI), Vector3(1.8, 0.13, -1.9)), "key": "%s:c0" % poi.id, "golden": false, "sealed": false})
	_guard(&"tower_warden", Vector3(0, 0.4, 0.5), 0)
	_guard(&"arcane_wisp", Vector3(-4.5, 0.3, 4.5), 1)
	_guard(&"arcane_wisp", Vector3(4.5, 0.3, 4.5), 2)


# --- Temple -------------------------------------------------------------------------------

func _temple() -> void:
	var top := 0.53
	for x in range(-6, 6):
		for z in range(-5, 5):
			_deco(&"stone_floor", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0.4, z + 0.5)))
	boxes.append({"size": Vector3(12, top, 10), "xform": Transform3D(Basis.IDENTITY, Vector3(0, top * 0.5, 0))})
	for x in range(-2, 2):
		_deco(&"stone_floor", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0.15, 5.5)))
	boxes.append({"size": Vector3(4, 0.28, 1), "xform": Transform3D(Basis.IDENTITY, Vector3(0, 0.14, 5.5))})
	var k := 0
	for z in [-4.0, -1.5, 1.0, 3.5]:
		for sx in [-5.3, 5.3]:
			var broken := _r(200 + k) < 0.3
			_deco(&"pillar_broken" if broken else &"pillar", Transform3D(Basis.IDENTITY, Vector3(sx, top, z)),
				Vector3(0.7, 1.4 if broken else 3.2, 0.7), Vector3(0, 0.7 if broken else 1.6, 0))
			k += 1
	var altar := Vector3(0, top, -3.0)
	_deco(&"altar", Transform3D(Basis.IDENTITY, altar), Vector3(1.8, 1.0, 1.0), Vector3(0, 0.5, 0))
	_deco(&"altar_glow", Transform3D(Basis.IDENTITY, altar), Vector3.ZERO, Vector3.ZERO, false, true)
	_deco(&"statue", Transform3D(Basis.IDENTITY, Vector3(0, top, -4.3)), Vector3(1.4, 3.0, 1.4), Vector3(0, 1.5, 0))
	objects.append({"kind": PoiObject.Kind.ALTAR, "xform": Transform3D(Basis.IDENTITY, altar + Vector3(0, 0, 1.0)), "key": "prayed:%s" % poi.id})
	_brazier(Vector3(-2.5, top, -3.0))
	_brazier(Vector3(2.5, top, -3.0))
	chests.append({"table": &"temple", "xform": Transform3D(Basis.IDENTITY, Vector3(3.8, top, -3.8)), "key": "%s:c0" % poi.id, "golden": true, "sealed": true})
	_guard(&"temple_guardian", Vector3(0, top + 0.3, 0.5), 0, 9.0)


# --- Dungeon entrance -------------------------------------------------------------------

func _entrance() -> void:
	_deco(&"dungeon_arch", Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.0)), Vector3(0.9, 3.6, 1.2), Vector3(-1.7, 1.8, 0))
	# The arch mesh has both sides; the right side and lintel only need collision.
	boxes.append({"size": Vector3(0.9, 3.6, 1.2), "xform": Transform3D(Basis.IDENTITY, Vector3(1.7, 1.8, -1.0))})
	boxes.append({"size": Vector3(4.4, 0.8, 1.3), "xform": Transform3D(Basis.IDENTITY, Vector3(0, 3.9, -1.0))})
	_brazier(Vector3(-3.2, 0, 1.0))
	_brazier(Vector3(3.2, 0, 1.0))
	objects.append({"kind": PoiObject.Kind.ENTRANCE, "xform": Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.6)), "key": ""})
	for i in 5:
		var a := TAU * _r(300 + i)
		_deco(&"rubble", Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 5.5, 0, sin(a) * 5.5)))
	var mons: Array = THEME_MONSTERS[poi.theme]
	for i in 1 + poi.rank / 2:
		var a := PI * 0.3 + i * 1.2
		_guard(mons[i % 2], Vector3(cos(a) * 4.0, 0.3, 2.0 + sin(a) * 2.0), i)


# --- Hidden grove -----------------------------------------------------------------------

func _grove() -> void:
	_deco(&"ancient_tree", Transform3D(Basis.IDENTITY, Vector3(0, _y(0, 0), 0)), Vector3(1.6, 6.0, 1.6), Vector3(0, 3.0, 0))
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
		p.y = _y(p.x, p.z)
		var xf := Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p)
		_deco(&"standing_stone", xf, Vector3(0.8, 2.6, 0.5), Vector3(0, 1.2, 0))
		_deco(&"rune_glow", xf, Vector3.ZERO, Vector3.ZERO, false, true)
	_deco(&"mushroom_ring", Transform3D(Basis.IDENTITY, Vector3(3.5, _y(3.5, 3.5), 3.5)), Vector3.ZERO, Vector3.ZERO, false, true)
	var plants := [[&"starlight_orchid", &"starlight_orchid"], [&"starlight_orchid", &"starlight_orchid"], [&"moonpetal", &"moonpetal"],
		[&"sunbloom", &"sunbloom"], [&"starlight_orchid", &"starlight_orchid"], [&"dreamcap", &"dreamcap"]]
	for i in plants.size():
		var a := TAU * i / plants.size() + 0.4
		var d := 3.0 + (i % 2) * 1.5
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = _y(p.x, p.z)
		objects.append({"kind": PoiObject.Kind.PLANT, "xform": Transform3D(Basis.IDENTITY, p), "key": "plant:%s:%d" % [poi.id, i],
			"item": plants[i][0], "mesh": plants[i][1]})
	lights.append([Vector3(0, _y(0, 0) + 3.0, 0), Color(0.6, 0.9, 1.0)])
	lights.append([Vector3(3.5, _y(3.5, 3.5) + 1.0, 3.5), Color(0.9, 0.6, 1.0)])
