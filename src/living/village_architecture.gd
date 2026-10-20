class_name VillageArchitecture
extends RefCounted
## Milestone 40: the village look. Every settlement building gets a shell of
## 0.5 m blocks in one shared style (from the owner's reference sheets):
## a stone foundation, dark wood corner posts and floor beams, walls of stone,
## white plaster in a timber frame or wood planks, and a steep 45° roof with a
## one-block overhang and dark trim. Each building picks its own size, wall
## mix, roof colour, floors, jetty, hip roof, front gable, chimney, tower,
## awning, flowers and ivy, so no two houses in a settlement look the same.
## Job buildings add props that show the owner's work (oven, log pile, ...).
##
## Everything here is pure data work (Dictionaries and BlockMesh arrays), so it
## runs on the settlement worker thread.
##
## Coordinates: a building is drawn in its own frame (from
## SettlementLayout._frame): `a` runs across the door wall, `b` runs inward
## (b < 0 is in front of the door wall), `y` is up. All three count 0.5 m
## voxels. The inside of the building is a in [0, 2W), b in [0, 2D); the walls
## are the ring just outside it (a = -1 or 2W, b = -1 or 2D), so rooms keep
## their full size. Results are voxels in settlement-local voxel indices:
## voxel (i, y, k) fills [i, i+1] x [y, y+1] x [k, k+1] * VOX metres.

const VOX := 0.5
## Ground floor: foundation row 0, walls rows 1-4, beam row 5 (3 m tall).
const GROUND_TOP := 5
## Each upper floor: 3 rows of wall + 1 beam row (2 m).
const UPPER_H := 4

const PAL := {
	# The game's vertex colours are sRGB and get darker in the light, so these
	# are a little brighter than the reference renders.
	&"stone": Color(0.64, 0.64, 0.65), &"stone_d": Color(0.52, 0.52, 0.54), &"plaster": Color(0.94, 0.91, 0.84),
	&"plank": Color(0.8, 0.58, 0.35), &"beam": Color(0.55, 0.37, 0.21), &"trim": Color(0.46, 0.3, 0.17),
	&"glass": Color(0.62, 0.84, 0.92), &"brick": Color(0.74, 0.42, 0.31), &"leaf": Color(0.4, 0.62, 0.3),
	&"flower": Color(0.9, 0.42, 0.55), &"flower2": Color(0.96, 0.82, 0.38), &"lantern": Color(1.0, 0.84, 0.45),
	&"barrel": Color(0.62, 0.42, 0.24), &"red": Color(0.82, 0.32, 0.28), &"white": Color(0.97, 0.96, 0.93),
	&"blue": Color(0.32, 0.5, 0.8), &"yellow": Color(0.92, 0.76, 0.3),
	&"iron": Color(0.4, 0.42, 0.45), &"fire": Color(1.0, 0.52, 0.15), &"coal": Color(0.27, 0.27, 0.28),
	&"bread": Color(0.86, 0.64, 0.34), &"bark": Color(0.5, 0.36, 0.22), &"log_end": Color(0.84, 0.7, 0.48),
	&"potion_p": Color(0.66, 0.42, 0.86), &"potion_g": Color(0.38, 0.85, 0.6), &"potion_b": Color(0.36, 0.68, 0.93),
	&"fish": Color(0.76, 0.8, 0.83), &"shard": Color(0.55, 0.9, 1.0), &"sack": Color(0.92, 0.88, 0.78),
	&"banner": Color(0.74, 0.27, 0.29), &"gold": Color(0.9, 0.76, 0.34), &"hay": Color(0.87, 0.74, 0.34),
	&"dark": Color(0.2, 0.18, 0.17), &"hedge": Color(0.33, 0.56, 0.26),
	# Roof colours
	&"teal": Color(0.4, 0.79, 0.72), &"slate": Color(0.44, 0.47, 0.54), &"brown": Color(0.66, 0.4, 0.25),
	&"roof_red": Color(0.75, 0.4, 0.31), &"thatch": Color(0.84, 0.7, 0.38),
}
## Voxels that glow (drawn with the emissive material).
const GLOW := [&"fire", &"lantern", &"shard"]

const VILLAGE_ROOFS := [&"thatch", &"thatch", &"brown", &"brown", &"teal", &"roof_red", &"slate"]
const KINGDOM_ROOFS := [&"slate", &"slate", &"roof_red", &"roof_red", &"brown"]

## Job buildings (village outer lots) and the NPC role that works there.
const JOBS := {&"bakery": &"baker", &"lumber_camp": &"lumberjack", &"alchemy": &"alchemist",
	&"fishery": &"fisher", &"mine": &"miner", &"mill": &"miller", &"watchtower": &"guard"}


static func _u(seed: int, salt: int) -> float:
	return HashUtils.to_unit(seed, salt)


static func _pick(seed: int, salt: int, list: Array):
	return list[int(_u(seed, salt) * list.size()) % list.size()]


## Random look for one building. `salt` lets the layout re-roll a duplicate.
static func pick_style(seed: int, kingdom: bool, kind: StringName, salt: int = 0) -> Dictionary:
	var s := seed + salt * 7919
	var st := {
		"ground": _pick(s, 1, [&"stone", &"stone", &"plaster", &"plank"] if not kingdom else [&"stone"]),
		"upper": _pick(s, 2, [&"plaster", &"plank"] if not kingdom else [&"plaster", &"plaster", &"plank"]),
		"roof": _pick(s, 3, KINGDOM_ROOFS if kingdom else VILLAGE_ROOFS),
		"floors": 2 if _u(s, 4) < (0.75 if kingdom else 0.55) else 1,
		"jetty": false, "hip": false, "front_gable": false,
		"chimney": int(_u(s, 5) * 3.0),  # 0 none, 1 left, 2 right
		"chimney_mat": _pick(s, 6, [&"stone", &"brick"]),
		"tower": &"", "awning": false,
		"flowers": _u(s, 7) < 0.6, "ivy": _u(s, 8) < 0.5,
	}
	if kingdom and _u(s, 9) < 0.3:
		st.floors = 3
	st.jetty = st.floors >= 2 and _u(s, 10) < 0.45
	st.front_gable = _u(s, 11) < 0.5
	st.hip = not st.front_gable and _u(s, 12) < 0.25
	if st.floors == 1 and st.ground == &"stone" and _u(s, 13) < 0.4:
		st.upper = &"stone"
	match kind:
		&"shop":
			st.awning = true
		&"smithy":
			st.ground = &"stone"; st.upper = &"stone"; st.roof = &"slate"; st.floors = 1
			st.jetty = false; st.hip = false; st.front_gable = false; st.chimney = 0; st.flowers = false
		&"keep":
			st.ground = &"stone"; st.upper = &"stone"; st.roof = &"slate"; st.floors = 2
			st.jetty = false; st.hip = false; st.front_gable = true; st.chimney = 0; st.tower = &"corners"
		&"barracks":
			st.ground = &"stone"; st.upper = &"stone"; st.roof = &"roof_red"; st.floors = 1
			st.jetty = false; st.hip = false; st.flowers = false
		&"manor":
			st.ground = &"stone"; st.upper = &"plaster"; st.roof = &"slate"; st.floors = 3
			st.jetty = false; st.hip = false; st.front_gable = true; st.tower = &"castle"; st.chimney = 1
		&"inn":
			st.ground = &"stone"; st.upper = &"plaster"; st.roof = &"brown"; st.floors = 3
			st.jetty = true; st.hip = false; st.front_gable = false; st.chimney = 2
		&"bakery":
			st.ground = &"plaster"; st.roof = &"roof_red"; st.awning = true; st.chimney = 0
		&"lumber_camp":
			st.ground = &"plank"; st.upper = &"plank"; st.roof = &"brown"; st.floors = 1
		&"alchemy":
			st.ground = &"stone"; st.upper = &"plaster"; st.roof = &"teal"; st.floors = 2; st.tower = &"spire"
			st.flowers = false
		&"fishery":
			st.ground = &"plank"; st.upper = &"plank"; st.roof = &"teal"; st.floors = 1
		&"mine":
			st.ground = &"stone"; st.upper = &"plank"; st.roof = &"slate"; st.floors = 1
		&"mill":
			st.ground = &"stone"; st.upper = &"plaster"; st.roof = &"brown"; st.floors = 3
			st.jetty = false; st.hip = false; st.front_gable = false; st.chimney = 0; st.flowers = false
		&"watchtower":
			st.ground = &"stone"; st.upper = &"stone"; st.roof = &"roof_red"; st.floors = 1
			st.jetty = false; st.hip = true; st.front_gable = false; st.chimney = 0; st.flowers = false
			st.ivy = false
	return st


## Short text that is the same for two buildings that would look the same.
static func signature(st: Dictionary, w: int, d: int) -> String:
	return "%s|%s|%s|%d|%s|%s|%s|%d|%s|%s|%dx%d" % [st.ground, st.upper, st.roof, st.floors, st.jetty, st.hip,
		st.front_gable, st.chimney, st.awning, st.tower, w, d]


# --- Building -------------------------------------------------------------------------------

## Builds the voxels of one building. `f` is SettlementLayout._frame(); the door
## is the cell `door_u` across the front wall. Returns
## {shell, upper, props, glow: voxel Dictionaries, boxes: [{size, xform}],
##  obstacles: [Rect2], work: Vector2 (u, v metres in the frame) or null, ridge: int}.
## `shell` = ground floor (fades near the camera), `upper` = upper floors and
## roof (hidden while the player is inside), `props` = always drawn.
static func build(f: Dictionary, kind: StringName, st: Dictionary, seed: int, door_u: int, open_front: bool = false) -> Dictionary:
	var c := {
		"o": f.origin, "ac": f.across, "in": f.inward, "seed": seed,
		"shell": {}, "upper": {}, "props": {}, "glow": {}, "boxes": [], "obstacles": [], "work": null,
		"W": int(f.width), "D": int(f.depth), "u": door_u,
	}
	var top := GROUND_TOP + UPPER_H * (int(st.floors) - 1)
	c["top"] = top
	_walls(c, st, open_front)
	var ridge := int(c.top) if kind == &"watchtower" else _roof(c, st)
	c["ridge"] = ridge
	_extras(c, st, kind)
	_job_props(c, st, kind)
	_wall_boxes(c, open_front)
	return c


static func _idx(c: Dictionary, a: int, b: int, y: int) -> Vector3i:
	var p: Vector3 = c.o + c.ac * ((a + 0.5) * VOX) + c["in"] * ((b + 0.5) * VOX)
	return Vector3i(floori(p.x / VOX), y, floori(p.z / VOX))


static func _tone(c: Dictionary, k: Vector3i, col: StringName) -> Color:
	var base: Color = PAL.get(col, Color.MAGENTA)
	var h := HashUtils.hash3(k.x * 7 + int(c.seed), k.y, k.z)
	var j := 1.0 + (float(h & 255) / 255.0 - 0.5) * 0.14
	return Color(minf(base.r * j, 1.0), minf(base.g * j, 1.0), minf(base.b * j, 1.0), 1.0)


## A building voxel: the ground floor goes to the shell, higher ones to `upper`.
static func _put(c: Dictionary, a: int, b: int, y: int, col: StringName) -> void:
	var k := _idx(c, a, b, y)
	var dst: Dictionary = c.shell if y <= GROUND_TOP else c.upper
	(c.upper if y <= GROUND_TOP else c.shell).erase(k)
	if col in GLOW:
		c.glow[k] = _tone(c, k, col)
		return
	dst[k] = _tone(c, k, col)


## A prop voxel (always visible).
static func _prop(c: Dictionary, a: int, b: int, y: int, col: StringName) -> void:
	var k := _idx(c, a, b, y)
	if col in GLOW:
		c.glow[k] = _tone(c, k, col)
	else:
		c.props[k] = _tone(c, k, col)


static func _clear(c: Dictionary, a: int, b: int, y: int) -> void:
	var k := _idx(c, a, b, y)
	c.shell.erase(k)
	c.upper.erase(k)
	c.props.erase(k)
	c.glow.erase(k)


static func _rand(c: Dictionary, a: int, b: int, y: int, salt: int) -> float:
	return HashUtils.to_unit(HashUtils.hash3(int(c.seed) + salt, a * 31 + b, y))


static func _stone(c: Dictionary, a: int, b: int, y: int) -> StringName:
	return &"stone_d" if _rand(c, a, b, y, 5) < 0.3 else &"stone"


## A solid block of the frame (voxel box a0..a1, b0..b1) that people can't walk
## through: a collision box `h` metres tall and a street blocker.
static func _solid(c: Dictionary, a0: int, b0: int, a1: int, b1: int, h: float) -> void:
	var p0: Vector3 = c.o + c.ac * (a0 * VOX) + c["in"] * (b0 * VOX)
	var p1: Vector3 = c.o + c.ac * ((a1 + 1) * VOX) + c["in"] * ((b1 + 1) * VOX)
	var lo := Vector2(minf(p0.x, p1.x), minf(p0.z, p1.z))
	var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.z, p1.z))
	c.obstacles.append(Rect2(lo, hi - lo))
	var mid := (lo + hi) * 0.5
	c.boxes.append({"size": Vector3(hi.x - lo.x, h, hi.y - lo.y), "xform": Transform3D(Basis.IDENTITY, Vector3(mid.x, h * 0.5, mid.y))})


static func _walls(c: Dictionary, st: Dictionary, open_front: bool) -> void:
	var W2: int = int(c.W) * 2
	var D2: int = int(c.D) * 2
	var du: int = int(c.u) * 2
	for y in range(0, int(c.top) + 1):
		var fl := 0 if y <= GROUND_TOP else 1 + (y - GROUND_TOP - 1) / UPPER_H
		var zt := GROUND_TOP + UPPER_H * fl
		var fb := 1 if fl == 0 else GROUND_TOP + 1 + UPPER_H * (fl - 1)  # first wall row of the floor
		var jet: bool = st.jetty and fl >= 1
		var bmin := -2 if jet else -1
		var bmax := D2 + 1 if jet else D2
		var m: StringName = st.ground if fl == 0 else st.upper
		for a in range(-1, W2 + 1):
			for b in range(bmin, bmax + 1):
				var ea := a == -1 or a == W2
				var eb := b == bmin or b == bmax
				if not (ea or eb):
					continue
				var corner := ea and eb
				if open_front and fl == 0 and b == bmin and not corner and y != zt:
					continue
				var col: StringName = m
				if m == &"stone":
					col = _stone(c, a, b, y)
				if corner:
					col = &"stone_d" if m == &"stone" else &"beam"
				elif y == zt:
					col = &"beam"
				elif y == 0:
					col = _stone(c, a, b, y)
				elif m == &"plaster" and ((eb and posmod(a, 4) == 0) or (ea and posmod(b, 4) == 0)):
					col = &"beam"
				if not corner and (y == fb + 1 or y == fb + 2) and y < zt:
					var win := false
					if eb and posmod(a, 4) in [1, 2] and a >= 1 and a <= W2 - 2:
						win = not (fl == 0 and b == bmin and a >= du - 1 and a <= du + 2)
					elif ea and posmod(b, 4) in [1, 2] and b >= 1 and b <= D2 - 2:
						win = true
					if win:
						col = &"glass"
				_put(c, a, b, y, col)
		if jet and y == GROUND_TOP + 1:
			for a in range(-1, W2 + 1, 2):  # joists under the jetty
				_put(c, a, -2, GROUND_TOP, &"beam")
				_put(c, a, D2 + 1, GROUND_TOP, &"beam")
	# Door gap (the interactive door sits on the edge line just inside).
	if not open_front:
		for y in range(0, 5):
			_clear(c, du, -1, y)
			_clear(c, du + 1, -1, y)


## Main roof (ridge across the door wall) plus the optional front gable.
## Returns the voxel row of the ridge.
static func _roof(c: Dictionary, st: Dictionary) -> int:
	var W2: int = int(c.W) * 2
	var D2: int = int(c.D) * 2
	var yr: int = int(c.top) + 1
	var bf := -3 if st.jetty else -2
	var bb := D2 + 2 if st.jetty else D2 + 1
	var al := -2
	var ar := W2 + 1
	var roof: StringName = st.roof
	var gable: StringName = st.upper
	var k := 0
	if st.hip:
		while al + k <= ar - k and bf + k <= bb - k:
			for a in range(al + k, ar - k + 1):
				for b in range(bf + k, bb - k + 1):
					if a == al + k or a == ar - k or b == bf + k or b == bb - k:
						_put(c, a, b, yr + k, &"trim" if k == 0 else roof)
			k += 1
		return yr + k - 1
	var mid := (bf + bb) / 2
	while bf + k <= bb - k:
		for a in range(al, ar + 1):
			for b in [bf + k, bb - k]:
				_put(c, a, b, yr + k, &"trim" if (a == al or a == ar) else roof)
		for b in range(bf + k + 1, bb - k):
			for a in [-1, W2]:
				var win := k == 1 and (b == mid or b == mid + 1) and bb - bf > 6
				_put(c, a, b, yr + k, &"glass" if win else gable)
		k += 1
	var ridge := yr + k - 1
	if st.front_gable:
		var du: int = int(c.u) * 2
		var hw := 2 if int(c.W) <= 6 else 3
		var aL := du - hw
		var aR := du + 1 + hw
		var face := -2 if st.jetty else -1
		k = 0
		while aL + k <= aR - k:
			for b in range(bf, bf + k + 2):
				_put(c, aL + k, b, yr + k, &"trim" if b == bf else roof)
				_put(c, aR - k, b, yr + k, &"trim" if b == bf else roof)
			for a in range(aL + k + 1, aR - k):
				_put(c, a, face, yr + k, &"glass" if (k == 1 and (a == du or a == du + 1)) else gable)
			k += 1
	return ridge


static func _extras(c: Dictionary, st: Dictionary, kind: StringName) -> void:
	var W2: int = int(c.W) * 2
	var D2: int = int(c.D) * 2
	var du: int = int(c.u) * 2
	var ridge: int = int(c.ridge)
	var back := D2 + 1 if st.jetty else D2
	if int(st.chimney) > 0:
		var ca := 1 if int(st.chimney) == 1 else W2 - 2
		for y in range(1, ridge + 3):
			_put(c, ca, D2, y, st.chimney_mat)
		_put(c, ca, D2, ridge + 3, &"stone_d")
	if st.awning:
		for a in range(du - 2, du + 4):
			for b in [-2, -3]:
				_prop(c, a, b, GROUND_TOP, &"red" if posmod(a - du, 2) == 0 else &"white")
	elif kind != &"smithy":
		_prop(c, du - 1, -2, 4, &"lantern")
		_prop(c, du + 2, -2, 4, &"lantern")
	if st.flowers:
		for a in range(1, W2 - 1):
			if posmod(a, 4) in [1, 2] and (a < du - 1 or a > du + 2) and _rand(c, a, 0, 0, 11) < 0.7:
				_prop(c, a, -2, 1, &"flower" if _rand(c, a, 0, 0, 12) < 0.5 else &"flower2")
	if st.ivy:
		var start := 2 if _rand(c, 0, 0, 0, 13) < 0.5 else W2 - 5
		for a in range(start, start + 3):
			var length := 2 + int(_rand(c, a, 0, 0, 14) * 4.0)
			for y in range(int(c.top), maxi(int(c.top) - length, 1), -1):
				if _rand(c, a, y, 0, 15) < 0.75:
					_prop(c, a, back + 1, y, &"leaf")
	match st.tower:
		&"castle":
			_tower(c, st, W2 - 3, D2 + 1, 3, ridge + 3, false)
		&"spire":
			_tower(c, st, W2 + 1, D2 - 4, 4, ridge + 2, true)
		&"corners":
			for p: Vector2i in [Vector2i(-3, -3), Vector2i(W2, -3), Vector2i(-3, D2), Vector2i(W2, D2)]:
				_tower(c, st, p.x, p.y, 3, ridge + 2, false)


## A square stone tower (a0, b0, size in voxels) with battlements or a spire.
static func _tower(c: Dictionary, st: Dictionary, a0: int, b0: int, size: int, h: int, spire: bool) -> void:
	for y in range(0, h + 1):
		for a in range(a0, a0 + size):
			for b in range(b0, b0 + size):
				var ring := a == a0 or a == a0 + size - 1 or b == b0 or b == b0 + size - 1
				if not ring and y != h:
					continue
				var col := _stone(c, a, b, y)
				if y > 0 and y % 6 == 0:
					col = &"beam"
				if b == b0 and a == a0 + size / 2 and y % 4 == 2 and y > 2:
					col = &"trim"
				_put(c, a, b, y, col)
	if spire:
		var k := 0
		while k <= (size + 1) / 2:
			for a in range(a0 - 1 + k, a0 + size + 1 - k):
				for b in range(b0 - 1 + k, b0 + size + 1 - k):
					if a == a0 - 1 + k or a == a0 + size - k or b == b0 - 1 + k or b == b0 + size - k:
						_put(c, a, b, h + 1 + k, &"trim" if k == 0 else st.roof)
			k += 1
		_put(c, a0 + size / 2, b0 + size / 2, h + 1 + k, &"gold")
		_put(c, a0 + size / 2, b0 + size / 2, h + 2 + k, &"gold")
	else:
		for a in range(a0, a0 + size):
			for b in range(b0, b0 + size):
				var ring := a == a0 or a == a0 + size - 1 or b == b0 or b == b0 + size - 1
				if ring and posmod(a + b, 2) == 0:
					_put(c, a, b, h + 1, &"stone")
	_solid(c, a0, b0, a0 + size - 1, b0 + size - 1, (h + 1) * VOX)


# --- Job props --------------------------------------------------------------------------------

## Props of job buildings. Job buildings sit at one side of their lot; the
## free strip is a in [2W+1, 2W+6] (3 m) beside the building.
static func _job_props(c: Dictionary, st: Dictionary, kind: StringName) -> void:
	var W2: int = int(c.W) * 2
	var D2: int = int(c.D) * 2
	var du: int = int(c.u) * 2
	var z0 := W2 + 1  # first voxel of the side strip
	match kind:
		&"smithy":
			# Big forge chimney at the back, over the forge station.
			for y in range(1, int(c.ridge) + 4):
				for a in [du, du + 1]:
					_put(c, a, D2, y, _stone(c, a, D2, y))
		&"bakery":
			# Brick oven with fire, its own chimney, bread crates by the door.
			for a in range(z0 + 1, z0 + 5):
				for b in range(1, 5):
					_prop(c, a, b, 0, &"stone")
					_prop(c, a, b, 1, &"brick")
					_prop(c, a, b, 2, &"brick")
					if a > z0 + 1 and a < z0 + 4 and b > 1 and b < 4:
						_prop(c, a, b, 3, &"brick")
			_prop(c, z0 + 2, 1, 1, &"fire")
			_prop(c, z0 + 3, 1, 1, &"fire")
			for y in range(3, 8):
				_prop(c, z0 + 3, 3, y, &"brick")
			_solid(c, z0 + 1, 1, z0 + 4, 4, 2.0)
			for a in [du - 3, du + 4]:
				_prop(c, a, -2, 0, &"plank")
				_prop(c, a, -2, 1, &"bread")
			c.work = Vector2((z0 + 3) * VOX, -0.6)
		&"lumber_camp":
			# Stacked logs (bark on the sides, rings on the ends) + chopping stump.
			for layer in 3:
				for a in range(z0 + 1 + (1 if layer == 2 else 0), z0 + 5 - (1 if layer >= 1 else 0)):
					for b in range(1, D2 - 1):
						_prop(c, a, b, layer, &"log_end" if (b == 1 or b == D2 - 2) else &"bark")
			_solid(c, z0 + 1, 1, z0 + 4, D2 - 2, 1.5)
			_prop(c, z0 + 2, -3, 0, &"bark")
			_prop(c, z0 + 2, -3, 1, &"log_end")
			_prop(c, z0 + 2, -3, 2, &"beam")
			_prop(c, z0 + 3, -3, 2, &"iron")
			c.work = Vector2((z0 + 2) * VOX + 0.25, -2.0)
		&"alchemy":
			# Potions on the window ledges and a bubbling cauldron.
			for a in range(1, W2 - 1):
				if posmod(a, 4) in [1, 2] and (a < du - 1 or a > du + 2):
					_prop(c, a, -2, 1, [&"potion_p", &"potion_g", &"potion_b"][posmod(a * 7, 3)])
			for a in range(z0 + 1, z0 + 4):
				for b in range(-4, -1):
					_prop(c, a, b, 0, &"iron")
					if not (a == z0 + 2 and b == -3):
						_prop(c, a, b, 1, &"iron")
			_prop(c, z0 + 2, -3, 1, &"potion_g")
			_solid(c, z0 + 1, -4, z0 + 3, -2, 1.0)
			c.work = Vector2((z0 + 2) * VOX + 0.25, 0.3)
			c["work_out"] = true
		&"fishery":
			# Fish drying rack, an upturned boat on trestles, barrels.
			for b in [1, 6]:
				for y in range(0, 4):
					_prop(c, z0 + 2, b, y, &"beam")
			for b in range(1, 7):
				_prop(c, z0 + 2, b, 4, &"beam")
			for b in [2, 3, 4, 5]:
				_prop(c, z0 + 2, b, 3, &"fish")
			for b in range(D2 - 4, D2):
				_prop(c, z0 + 4, b, 0, &"beam")
			for b in range(D2 - 5, D2 + 1):
				for a in [z0 + 3, z0 + 4, z0 + 5]:
					_prop(c, a, b, 1, &"plank" if a == z0 + 4 else &"beam")
			_prop(c, z0 + 1, -2, 0, &"barrel")
			_prop(c, z0 + 1, -2, 1, &"fish")
			_solid(c, z0 + 2, 1, z0 + 5, D2, 2.0)
			c.work = Vector2((z0 + 1) * VOX, -0.3)
		&"mine":
			# A rocky hill with a timbered mine mouth and a cart of shards.
			for y in range(0, 6):
				for a in range(z0 + y / 2, z0 + 6 - y / 3):
					for b in range(y / 2, D2 - y / 2):
						_prop(c, a, b, y, _stone(c, a, b, y))
			for y in range(0, 4):
				for a in [z0 + 2, z0 + 3]:
					_clear(c, a, 0, y)
					_clear(c, a, 1, y)
					_prop(c, a, 1, y, &"dark")
			for y in range(0, 4):
				_prop(c, z0 + 1, -1, y, &"beam")
				_prop(c, z0 + 4, -1, y, &"beam")
			for a in range(z0 + 1, z0 + 5):
				_prop(c, a, -1, 4, &"beam")
			_prop(c, z0 + 1, -2, 3, &"lantern")
			_solid(c, z0, 0, z0 + 5, D2 - 1, 3.0)
			for a in [z0 + 2, z0 + 3]:
				_prop(c, a, -4, 0, &"iron")
			_prop(c, z0 + 2, -4, 1, &"shard")
			_prop(c, z0 + 3, -4, 1, &"coal")
			c.work = Vector2((z0 + 1) * VOX, -1.8)
		&"mill":
			# Windmill sails in an X on the front, flour sacks by the door.
			var hub := Vector2i(du, int(c.top) - 1)
			_prop(c, hub.x, -2, hub.y, &"beam")
			_prop(c, hub.x + 1, -2, hub.y, &"beam")
			_prop(c, hub.x, -3, hub.y, &"trim")
			_prop(c, hub.x + 1, -3, hub.y, &"trim")
			for dir: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var base := Vector2i(hub.x + (1 if dir.x > 0 else 0), hub.y)
				for i in range(1, 9):
					var p := base + dir * i
					if p.y < 2:
						break
					_prop(c, p.x, -3, p.y, &"beam")
					if i >= 3:
						# Cloth on one side of the arm (turning direction).
						var side := Vector2i(-dir.y, dir.x)
						for t: int in [1, 2]:
							var q := p + side * t
							if q.y >= 2:
								_prop(c, q.x, -3, q.y, &"beam" if (i % 3 == 0 and t == 2) else &"white")
			for a in [du - 2, du + 3]:
				_prop(c, a, -2, 0, &"sack")
			_prop(c, du + 4, -2, 0, &"sack")
			_prop(c, du + 3, -2, 1, &"sack")
		&"watchtower":
			# The tower rises to a lookout platform with a railing and a roof.
			var top := int(c.top)
			var h := 18
			for y in range(top + 1, h + 1):
				for a in range(-1, W2 + 1):
					for b in range(-1, D2 + 1):
						if a == -1 or a == W2 or b == -1 or b == D2:
							var col := _stone(c, a, b, y)
							if (a == W2 / 2 or b == D2 / 2) and y % 5 == 0:
								col = &"trim"
							_put(c, a, b, y, col)
			for a in range(-2, W2 + 2):
				for b in range(-2, D2 + 2):
					_put(c, a, b, h + 1, &"plank")
					var edge := a == -2 or a == W2 + 1 or b == -2 or b == D2 + 1
					if edge and posmod(a + b, 2) == 0:
						_put(c, a, b, h + 2, &"beam")
			for p: Vector2i in [Vector2i(-2, -2), Vector2i(W2 + 1, -2), Vector2i(-2, D2 + 1), Vector2i(W2 + 1, D2 + 1)]:
				for y in range(h + 2, h + 5):
					_put(c, p.x, p.y, y, &"beam")
			var k := 0
			while -3 + k <= W2 + 2 - k and -3 + k <= D2 + 2 - k:
				for a in range(-3 + k, W2 + 3 - k):
					for b in range(-3 + k, D2 + 3 - k):
						if a == -3 + k or a == W2 + 2 - k or b == -3 + k or b == D2 + 2 - k:
							_put(c, a, b, h + 5 + k, &"trim" if k == 0 else st.roof)
				k += 1
			for y in range(h + 5 + k, h + 9 + k):
				_put(c, W2 / 2, D2 / 2, y, &"beam")
			for y in range(h + 6 + k, h + 9 + k):
				_put(c, W2 / 2 + 1, D2 / 2, y, &"banner")
				_put(c, W2 / 2 + 2, D2 / 2, y, &"banner")
		&"inn":
			# Hanging sign, barrels by the wall.
			for b in [-2, -3]:
				_prop(c, du + 4, b, GROUND_TOP + 1, &"beam")
			_prop(c, du + 4, -3, GROUND_TOP, &"plank")
			_prop(c, du + 4, -3, GROUND_TOP - 1, &"gold")
			for a in [0, 1]:
				_prop(c, a, -2, 0, &"barrel")
			_prop(c, 0, -2, 1, &"barrel")
		&"manor":
			# Banners on the front wall.
			for a in [2, W2 - 3]:
				for y in range(GROUND_TOP + 2, GROUND_TOP + 7):
					_prop(c, a, -2, y, &"banner")
				_prop(c, a, -2, GROUND_TOP + 7, &"gold")
		&"barracks":
			for a in [1, W2 - 2]:
				for y in range(2, 5):
					_prop(c, a, -2, y, &"banner")


## Collision: one box per 1 m wall segment (like the old wall pieces), plus the corners.
static func _wall_boxes(c: Dictionary, open_front: bool) -> void:
	var W: int = int(c.W)
	var D: int = int(c.D)
	var ac: Vector3 = c.ac
	var inw: Vector3 = c["in"]
	var h := (GROUND_TOP + 1) * VOX
	var add := func(center_uv: Vector2, along_ac: bool, length: float) -> void:
		var p: Vector3 = c.o + ac * center_uv.x + inw * center_uv.y + Vector3(0, h * 0.5, 0)
		var along := ac if along_ac else inw
		var across := inw if along_ac else ac
		var size := along.abs() * length + across.abs() * VOX + Vector3(0, h, 0)
		c.boxes.append({"size": size, "xform": Transform3D(Basis.IDENTITY, p)})
	for u in W:
		if u != int(c.u) and not open_front:
			add.call(Vector2(u + 0.5, -VOX * 0.5), true, 1.0)
		add.call(Vector2(u + 0.5, D + VOX * 0.5), true, 1.0)
	for v in D:
		add.call(Vector2(-VOX * 0.5, v + 0.5), false, 1.0)
		add.call(Vector2(W + VOX * 0.5, v + 0.5), false, 1.0)
	for p: Vector2 in [Vector2(-0.25, -0.25), Vector2(W + 0.25, -0.25), Vector2(-0.25, D + 0.25), Vector2(W + 0.25, D + 0.25)]:
		add.call(p, true, VOX)


# --- Meshing ----------------------------------------------------------------------------------

const _DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const _TINT := [1.0, 0.92, 1.08, 0.7, 0.92, 0.92]


## Adds the visible faces of `vox` (settlement voxel index -> Color) to `b`.
## Faces between two voxels of the same set are skipped.
static func emit(b: BlockMesh, vox: Dictionary) -> void:
	for k: Vector3i in vox:
		var col: Color = vox[k]
		var x0 := k.x * VOX
		var y0 := k.y * VOX
		var z0 := k.z * VOX
		var x1 := x0 + VOX
		var y1 := y0 + VOX
		var z1 := z0 + VOX
		for f in 6:
			if vox.has(k + _DIRS[f]):
				continue
			var t: Color = col * float(_TINT[f])
			t.a = 1.0
			match f:
				0:
					b.quad(Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.RIGHT, t)
				1:
					b.quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, t)
				2:
					b.quad(Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.UP, t)
				3:
					b.quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, t)
				4:
					b.quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, t)
				5:
					b.quad(Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3.FORWARD, t)
