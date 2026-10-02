class_name ItemIcons
## Pixel-art item icons (Milestone 10), drawn in code so every item - including
## new ones added as data - gets a proper icon without image files.
##
## Each item is mapped to one of ~45 shapes (sword, axe, potion, ore, ingot,
## bread...) by its id, equipment slot and category, and painted in its own
## colours (material tint for metal tools: copper, iron, mithril, star metal).
## A shading pass lights top-left edges and darkens bottom-right ones, then an
## outline pass draws a dark border, for a crisp 32 x 32 sprite.

const SIZE := 32

static var _cache: Dictionary = {}  # item id -> ImageTexture


static func get_icon(item: ItemData) -> Texture2D:
	if item == null:
		return null
	if _cache.has(item.id):
		return _cache[item.id]
	var tex := ImageTexture.create_from_image(render(item))
	_cache[item.id] = tex
	return tex


## The icon image of an item (also used by tests).
static func render(item: ItemData) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shape := shape_of(item)
	_draw(img, shape, item)
	_shade(img)
	_outline(img, item.icon_color.darkened(0.75))
	return img


## Which drawing an item uses.
static func shape_of(item: ItemData) -> StringName:
	var s := String(item.id)
	var rules := [
		["seeds", &"seeds"], ["mushroom", &"mushroom"], ["glowcap", &"mushroom"], ["dreamcap", &"mushroom"],
		["scroll_", &"scroll"], ["tome_", &"book"], ["grimoire", &"book"], ["codex", &"book"], ["manual", &"book"],
		["journal", &"book"], ["notes", &"book"],
		["pickaxe", &"pickaxe"], ["hatchet", &"hatchet"], ["handaxe", &"hatchet"], ["waraxe", &"axe"], ["greataxe", &"axe"],
		["cleaver", &"axe"], ["dagger", &"dagger"], ["knife", &"dagger"], ["shadowfang", &"dagger"], ["staff", &"staff"],
		["sword", &"sword"], ["blade", &"sword"], ["shield", &"shield"], ["buckler", &"shield"], ["aegis", &"shield"],
		["crown", &"crown"], ["helm", &"helmet"], ["cap", &"helmet"], ["gauntlets", &"gloves"], ["greaves", &"boots"], ["hood", &"hood"], ["hat", &"hat"], ["boots", &"boots"], ["gloves", &"gloves"],
		["jerkin", &"armor"], ["vest", &"armor"], ["chainmail", &"armor"], ["plate", &"armor"], ["robe", &"robe"],
		["cloak", &"robe"], ["ring", &"ring"], ["signet", &"ring"], ["amulet", &"amulet"], ["pendant", &"amulet"],
		["charm", &"amulet"], ["insignia", &"badge"],
		["draught", &"potion"], ["elixir", &"potion"], ["tonic", &"potion"], ["antidote", &"potion"], ["brew", &"potion"],
		["venom", &"vial"],
		["raw_meat", &"meat"], ["cooked_meat", &"meat_cooked"], ["frostberries", &"berries"], ["berries", &"berries"],
		["bread", &"bread"], ["stew", &"bowl"], ["salad", &"bowl"], ["carrot", &"carrot"], ["pumpkin", &"pumpkin"],
		["coconut", &"coconut"], ["cactus_fruit", &"fruit"], ["wheat", &"wheat"],
		["moonpetal", &"flower"], ["sunbloom", &"flower"], ["frost_lotus", &"flower"], ["orchid", &"flower"],
		["emberroot", &"root"], ["thorn_heart", &"heart"], ["star_core", &"orb"], ["essence", &"orb"],
		["_ore", &"ore"], ["_ingot", &"ingot"], ["nugget", &"nugget"], ["gemstone", &"gem"], ["sunstone", &"gem"],
		["crystal_shard", &"crystal"], ["void_shard", &"crystal"], ["dust", &"dust"],
		["plank", &"plank"], ["wood", &"log"], ["stick", &"stick"], ["flint", &"flint"], ["stone", &"stone"],
		["clay", &"lump"], ["coal", &"coal"], ["plant_fiber", &"fiber"], ["rope", &"rope"], ["leather", &"hide"],
		["hide", &"hide"], ["tusk", &"tusk"], ["bone", &"bone"], ["campfire", &"campfire"], ["bandage", &"bandage"],
	]
	for r in rules:
		if s.contains(r[0]):
			return r[1]
	match item.category:
		ItemData.Category.FOOD:
			return &"fruit"
		ItemData.Category.WEAPON:
			return &"sword"
		ItemData.Category.TOOL:
			return &"hatchet"
		ItemData.Category.ARMOR:
			return &"armor"
		ItemData.Category.PLACEABLE:
			return &"crate"
	return &"lump"


## Metal colour from the item's material (tools and weapons).
static func metal_of(item: ItemData) -> Color:
	var s := String(item.id)
	for pair in [["copper", Color(0.88, 0.52, 0.3)], ["iron", Color(0.76, 0.78, 0.84)], ["mithril", Color(0.6, 0.88, 0.98)],
			["star", Color(0.82, 0.72, 1.0)], ["sun", Color(1.0, 0.82, 0.35)], ["rusty", Color(0.62, 0.42, 0.3)],
			["flint", Color(0.42, 0.42, 0.48)], ["stone", Color(0.62, 0.62, 0.64)], ["rough", Color(0.6, 0.6, 0.62)],
			["shadow", Color(0.42, 0.3, 0.6)], ["titan", Color(0.7, 0.7, 0.8)], ["warlord", Color(0.55, 0.5, 0.5)],
			["squire", Color(0.76, 0.78, 0.84)], ["crystal", Color(0.65, 0.9, 1.0)]]:
		if s.contains(pair[0]):
			return pair[1]
	return item.icon_color


# --- Drawing ---------------------------------------------------------------------------

const WOOD := Color(0.55, 0.36, 0.2)
const WOOD_D := Color(0.4, 0.25, 0.14)
const GOLD := Color(1.0, 0.8, 0.3)
const PAPER := Color(0.93, 0.88, 0.72)


static func _draw(img: Image, shape: StringName, item: ItemData) -> void:
	var c := item.icon_color
	var m := metal_of(item)
	match shape:
		&"sword":
			_line(img, Vector2(8, 24), Vector2(24, 8), 3, m)
			_line(img, Vector2(9, 22), Vector2(23, 8), 1, m.lightened(0.4))
			_line(img, Vector2(6, 19), Vector2(13, 26), 2, GOLD if item.rarity >= ItemData.Rarity.RARE else Color(0.5, 0.42, 0.3))
			_line(img, Vector2(5, 27), Vector2(9, 23), 2, WOOD_D)
			_disc(img, Vector2(4, 28), 1.5, GOLD)
		&"dagger":
			_line(img, Vector2(10, 22), Vector2(22, 10), 2, m)
			_line(img, Vector2(8, 18), Vector2(14, 24), 2, Color(0.5, 0.42, 0.3))
			_line(img, Vector2(6, 26), Vector2(10, 22), 2, WOOD_D)
		&"axe", &"hatchet":
			_line(img, Vector2(7, 27), Vector2(22, 8), 2, WOOD)
			var big := shape == &"axe"
			_poly(img, [Vector2(17, 6), Vector2(27 if big else 25, 5), Vector2(28 if big else 25, 16 if big else 13), Vector2(20, 13)], m)
			if big:
				_poly(img, [Vector2(13, 9), Vector2(17, 6), Vector2(19, 12), Vector2(14, 14)], m.darkened(0.15))
		&"pickaxe":
			_line(img, Vector2(8, 27), Vector2(20, 9), 2, WOOD)
			_line(img, Vector2(9, 8), Vector2(18, 5), 2, m)
			_line(img, Vector2(18, 5), Vector2(27, 12), 2, m)
			_line(img, Vector2(6, 11), Vector2(9, 8), 1, m.darkened(0.2))
		&"staff":
			_line(img, Vector2(7, 28), Vector2(21, 10), 2, WOOD)
			_disc(img, Vector2(23, 8), 4.5, c)
			_disc(img, Vector2(22, 7), 1.5, c.lightened(0.6))
		&"shield":
			_poly(img, [Vector2(7, 6), Vector2(25, 6), Vector2(25, 17), Vector2(16, 27), Vector2(7, 17)], c)
			_line(img, Vector2(16, 7), Vector2(16, 25), 2, c.darkened(0.25))
			_line(img, Vector2(8, 13), Vector2(24, 13), 2, c.darkened(0.25))
			_disc(img, Vector2(16, 13), 2.5, GOLD)
		&"helmet":
			_ellipse(img, Vector2(16, 16), 10, 9, c, true)
			_rect(img, 5, 18, 22, 4, c.darkened(0.2))
		&"hood":
			_poly(img, [Vector2(16, 4), Vector2(26, 14), Vector2(26, 26), Vector2(6, 26), Vector2(6, 14)], c)
			_ellipse(img, Vector2(16, 19), 6, 6, Color(0.15, 0.12, 0.15), false)
		&"hat":
			_rect(img, 4, 20, 24, 4, c.darkened(0.15))
			_poly(img, [Vector2(10, 21), Vector2(16, 5), Vector2(22, 21)], c)
		&"crown":
			_poly(img, [Vector2(5, 24), Vector2(5, 10), Vector2(10, 16), Vector2(16, 7), Vector2(22, 16), Vector2(27, 10), Vector2(27, 24)], GOLD)
			for x in [9, 16, 23]:
				_disc(img, Vector2(x, 20), 1.6, c)
		&"armor":
			_poly(img, [Vector2(6, 8), Vector2(12, 5), Vector2(20, 5), Vector2(26, 8), Vector2(26, 15), Vector2(22, 14), Vector2(22, 27), Vector2(10, 27), Vector2(10, 14), Vector2(6, 15)], c)
			_line(img, Vector2(16, 7), Vector2(16, 26), 1, c.darkened(0.25))
		&"robe":
			_poly(img, [Vector2(10, 4), Vector2(22, 4), Vector2(27, 28), Vector2(5, 28)], c)
			_rect(img, 9, 13, 14, 2, GOLD)
		&"boots":
			_rect(img, 7, 6, 7, 16, c)
			_rect(img, 7, 20, 12, 6, c)
			_rect(img, 17, 8, 7, 14, c.darkened(0.12))
			_rect(img, 17, 20, 10, 6, c.darkened(0.12))
		&"gloves":
			_rect(img, 9, 12, 14, 14, c)
			for k in 4:
				_rect(img, 9 + k * 4, 5, 3, 8, c)
			_rect(img, 22, 14, 4, 6, c)
		&"ring":
			_ring(img, Vector2(16, 18), 8, 2.5, GOLD if not String(item.id).contains("copper") else metal_of(item))
			_disc(img, Vector2(16, 9), 3.5, c)
		&"amulet", &"badge":
			if shape == &"amulet":
				_line(img, Vector2(8, 5), Vector2(16, 16), 1, GOLD)
				_line(img, Vector2(24, 5), Vector2(16, 16), 1, GOLD)
			_poly(img, [Vector2(16, 12), Vector2(23, 19), Vector2(16, 27), Vector2(9, 19)], c)
			_disc(img, Vector2(16, 19), 2.0, c.lightened(0.5))
		&"potion", &"vial":
			_rect(img, 13, 4, 6, 3, WOOD)
			_rect(img, 14, 7, 4, 4, Color(0.8, 0.88, 0.95))
			if shape == &"potion":
				_disc(img, Vector2(16, 19), 8.5, Color(0.8, 0.88, 0.95))
				_disc(img, Vector2(16, 20), 7.0, c)
				_disc(img, Vector2(13, 17), 1.8, Color(1, 1, 1, 0.9))
			else:
				_rect(img, 12, 10, 8, 17, Color(0.8, 0.88, 0.95))
				_rect(img, 13, 14, 6, 12, c)
		&"meat", &"meat_cooked":
			var mc := Color(0.85, 0.35, 0.35) if shape == &"meat" else Color(0.62, 0.36, 0.2)
			_ellipse(img, Vector2(14, 15), 9, 7, mc, true)
			_line(img, Vector2(20, 19), Vector2(27, 26), 3, Color(0.95, 0.92, 0.85))
			_disc(img, Vector2(27, 26), 2.5, Color(0.95, 0.92, 0.85))
		&"berries":
			for p in [Vector2(11, 18), Vector2(19, 18), Vector2(15, 24), Vector2(15, 13)]:
				_disc(img, p, 4.5, c)
			_line(img, Vector2(15, 9), Vector2(19, 4), 1, Color(0.3, 0.55, 0.2))
		&"bread":
			_ellipse(img, Vector2(16, 17), 12, 8, Color(0.85, 0.62, 0.3), true)
			for x in [10, 16, 22]:
				_line(img, Vector2(x - 2, 13), Vector2(x + 1, 17), 1, Color(0.95, 0.82, 0.55))
		&"bowl":
			_ellipse(img, Vector2(16, 15), 11, 4, c, true)
			_poly(img, [Vector2(5, 15), Vector2(27, 15), Vector2(22, 25), Vector2(10, 25)], WOOD)
		&"carrot":
			_poly(img, [Vector2(10, 10), Vector2(16, 8), Vector2(26, 27)], Color(0.95, 0.55, 0.15))
			_line(img, Vector2(12, 8), Vector2(8, 3), 2, Color(0.3, 0.65, 0.25))
			_line(img, Vector2(13, 8), Vector2(14, 2), 2, Color(0.3, 0.65, 0.25))
		&"pumpkin":
			_ellipse(img, Vector2(16, 18), 12, 9, Color(0.95, 0.55, 0.15), true)
			_line(img, Vector2(16, 10), Vector2(16, 26), 1, Color(0.8, 0.4, 0.1))
			_rect(img, 15, 5, 3, 5, Color(0.35, 0.5, 0.2))
		&"coconut":
			_disc(img, Vector2(16, 17), 10, Color(0.5, 0.33, 0.2))
			for p in [Vector2(13, 13), Vector2(18, 13), Vector2(16, 17)]:
				_disc(img, p, 1.2, Color(0.25, 0.15, 0.1))
		&"fruit":
			_disc(img, Vector2(16, 18), 9, c)
			_line(img, Vector2(16, 9), Vector2(19, 4), 1, Color(0.3, 0.55, 0.2))
		&"seeds":
			_poly(img, [Vector2(9, 10), Vector2(23, 10), Vector2(26, 26), Vector2(6, 26)], Color(0.8, 0.7, 0.5))
			_rect(img, 11, 6, 10, 4, Color(0.65, 0.55, 0.38))
			for p in [Vector2(13, 18), Vector2(19, 20), Vector2(16, 23)]:
				_disc(img, p, 1.5, c)
		&"wheat":
			for k in 3:
				var x := 10 + k * 6
				_line(img, Vector2(x, 28), Vector2(x + 2, 8), 1, Color(0.75, 0.62, 0.3))
				_ellipse(img, Vector2(x + 2, 9), 2, 5, Color(0.95, 0.8, 0.4), true)
		&"mushroom":
			_rect(img, 13, 16, 6, 11, Color(0.92, 0.88, 0.8))
			_ellipse(img, Vector2(16, 14), 11, 7, c, true)
			_disc(img, Vector2(12, 12), 1.5, Color(1, 1, 1, 0.9))
			_disc(img, Vector2(20, 11), 1.2, Color(1, 1, 1, 0.9))
		&"flower":
			_line(img, Vector2(16, 28), Vector2(16, 14), 2, Color(0.3, 0.6, 0.25))
			for k in 5:
				var a := TAU * k / 5.0 - PI / 2.0
				_disc(img, Vector2(16, 11) + Vector2(cos(a), sin(a)) * 5.0, 3.5, c)
			_disc(img, Vector2(16, 11), 2.5, GOLD)
		&"root":
			_line(img, Vector2(16, 4), Vector2(14, 26), 3, c)
			_line(img, Vector2(15, 14), Vector2(8, 22), 2, c)
			_line(img, Vector2(15, 17), Vector2(23, 25), 2, c)
		&"heart":
			_disc(img, Vector2(12, 13), 5.5, c)
			_disc(img, Vector2(20, 13), 5.5, c)
			_poly(img, [Vector2(6, 15), Vector2(26, 15), Vector2(16, 27)], c)
		&"orb":
			_disc(img, Vector2(16, 16), 10, c)
			_disc(img, Vector2(16, 16), 6, c.lightened(0.45))
			_disc(img, Vector2(13, 12), 2, Color(1, 1, 1, 0.95))
		&"ore":
			_poly(img, [Vector2(6, 20), Vector2(10, 9), Vector2(20, 6), Vector2(27, 14), Vector2(25, 25), Vector2(11, 27)], Color(0.48, 0.47, 0.5))
			for p in [Vector2(12, 14), Vector2(19, 11), Vector2(21, 20), Vector2(13, 22)]:
				_disc(img, p, 2.2, c)
		&"ingot":
			_poly(img, [Vector2(4, 22), Vector2(9, 12), Vector2(27, 12), Vector2(28, 22)], c)
			_poly(img, [Vector2(9, 12), Vector2(12, 8), Vector2(26, 8), Vector2(27, 12)], c.lightened(0.3))
		&"nugget":
			_poly(img, [Vector2(8, 18), Vector2(13, 10), Vector2(22, 11), Vector2(25, 20), Vector2(16, 25)], c)
		&"gem":
			_poly(img, [Vector2(9, 11), Vector2(23, 11), Vector2(27, 16), Vector2(16, 28), Vector2(5, 16)], c)
			_poly(img, [Vector2(12, 7), Vector2(20, 7), Vector2(23, 11), Vector2(9, 11)], c.lightened(0.35))
		&"crystal":
			_poly(img, [Vector2(13, 28), Vector2(11, 12), Vector2(16, 3), Vector2(21, 12), Vector2(19, 28)], c)
			_poly(img, [Vector2(6, 28), Vector2(6, 18), Vector2(9, 14), Vector2(12, 18), Vector2(12, 28)], c.darkened(0.15))
		&"dust":
			_ellipse(img, Vector2(16, 22), 11, 5, c, true)
			for p in [Vector2(10, 12), Vector2(20, 9), Vector2(24, 15), Vector2(14, 7)]:
				_disc(img, p, 1.2, c.lightened(0.5))
		&"log":
			_rect(img, 4, 11, 22, 11, WOOD)
			_ellipse(img, Vector2(26, 16), 4, 6, Color(0.82, 0.65, 0.42), true)
			_line(img, Vector2(6, 14), Vector2(22, 14), 1, WOOD_D)
		&"plank":
			_rect(img, 3, 11, 26, 10, Color(0.78, 0.58, 0.35))
			_line(img, Vector2(4, 16), Vector2(28, 16), 1, Color(0.6, 0.42, 0.25))
		&"stick":
			_line(img, Vector2(6, 26), Vector2(26, 6), 2, WOOD)
			_line(img, Vector2(16, 16), Vector2(22, 18), 1, WOOD)
		&"stone":
			_ellipse(img, Vector2(16, 18), 11, 8, Color(0.62, 0.62, 0.64), true)
		&"flint":
			_poly(img, [Vector2(8, 22), Vector2(14, 6), Vector2(24, 12), Vector2(22, 26)], Color(0.36, 0.36, 0.42))
		&"lump":
			_ellipse(img, Vector2(16, 18), 11, 8, c, true)
		&"coal":
			_poly(img, [Vector2(6, 20), Vector2(11, 9), Vector2(22, 8), Vector2(27, 18), Vector2(19, 27)], Color(0.18, 0.18, 0.2))
			_disc(img, Vector2(13, 13), 1.5, Color(0.5, 0.5, 0.55))
		&"fiber":
			for k in 4:
				_line(img, Vector2(8 + k * 4, 28), Vector2(12 + k * 3, 5), 1, Color(0.55, 0.75, 0.35))
		&"rope":
			_ring(img, Vector2(16, 16), 10, 3, Color(0.75, 0.62, 0.4))
			_ring(img, Vector2(16, 16), 5, 2, Color(0.68, 0.55, 0.35))
		&"hide":
			_poly(img, [Vector2(6, 8), Vector2(26, 6), Vector2(28, 18), Vector2(24, 27), Vector2(9, 26), Vector2(4, 16)], c)
		&"tusk", &"bone":
			if shape == &"tusk":
				_line(img, Vector2(8, 26), Vector2(18, 12), 4, Color(0.96, 0.92, 0.82))
				_line(img, Vector2(18, 12), Vector2(25, 5), 2, Color(0.96, 0.92, 0.82))
			else:
				_line(img, Vector2(9, 23), Vector2(23, 9), 3, Color(0.94, 0.9, 0.8))
				for p in [Vector2(7, 23), Vector2(9, 25), Vector2(23, 7), Vector2(25, 9)]:
					_disc(img, p, 2.5, Color(0.94, 0.9, 0.8))
		&"scroll":
			_rect(img, 8, 6, 16, 20, PAPER)
			_rect(img, 6, 4, 20, 4, Color(0.8, 0.72, 0.55))
			_rect(img, 6, 25, 20, 4, Color(0.8, 0.72, 0.55))
			for y in [11, 15, 19]:
				_line(img, Vector2(11, y), Vector2(21, y), 1, c)
		&"book":
			_rect(img, 6, 5, 20, 23, c)
			_rect(img, 22, 7, 3, 19, PAPER)
			_rect(img, 9, 10, 10, 6, c.lightened(0.35))
		&"campfire":
			_line(img, Vector2(6, 26), Vector2(26, 20), 3, WOOD)
			_line(img, Vector2(6, 20), Vector2(26, 26), 3, WOOD_D)
			_poly(img, [Vector2(10, 21), Vector2(16, 5), Vector2(22, 21)], Color(1.0, 0.55, 0.15))
			_poly(img, [Vector2(13, 21), Vector2(16, 11), Vector2(19, 21)], Color(1.0, 0.85, 0.3))
		&"bandage":
			_rect(img, 6, 11, 20, 10, Color(0.95, 0.93, 0.88))
			_rect(img, 13, 11, 6, 10, Color(0.85, 0.3, 0.3))
		&"crate":
			_rect(img, 6, 8, 20, 18, WOOD)
			_line(img, Vector2(6, 8), Vector2(26, 26), 1, WOOD_D)
		_:
			_disc(img, Vector2(16, 16), 9, c)


# --- Primitives --------------------------------------------------------------------------

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0) if c.a >= 0.5 else img.get_pixel(x, y))


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _disc(img: Image, center: Vector2, r: float, c: Color) -> void:
	_ellipse(img, center, r, r, c, true)


static func _ellipse(img: Image, center: Vector2, rx: float, ry: float, c: Color, filled: bool) -> void:
	for y in range(int(center.y - ry) - 1, int(center.y + ry) + 2):
		for x in range(int(center.x - rx) - 1, int(center.x + rx) + 2):
			var d := pow((x + 0.5 - center.x) / rx, 2) + pow((y + 0.5 - center.y) / ry, 2)
			if d <= 1.0 and (filled or d >= 0.55):
				_px(img, x, y, c)


static func _ring(img: Image, center: Vector2, r: float, width: float, c: Color) -> void:
	for y in range(int(center.y - r) - 2, int(center.y + r) + 3):
		for x in range(int(center.x - r) - 2, int(center.x + r) + 3):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if absf(d - r) <= width * 0.5:
				_px(img, x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, width: int, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var off := (width - 1) / 2.0
		for dy in width:
			for dx in width:
				_px(img, int(p.x - off) + dx, int(p.y - off) + dy, c)


## Fills a convex polygon.
static func _poly(img: Image, pts: Array, c: Color) -> void:
	var minv := Vector2(SIZE, SIZE)
	var maxv := Vector2.ZERO
	for p: Vector2 in pts:
		minv = minv.min(p)
		maxv = maxv.max(p)
	var packed := PackedVector2Array(pts)
	for y in range(int(minv.y), int(maxv.y) + 1):
		for x in range(int(minv.x), int(maxv.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), packed):
				_px(img, x, y, c)


## Light from the top-left: brighten pixels with an empty neighbour up/left,
## darken the ones with an empty neighbour down/right.
static func _shade(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var up := y == 0 or src.get_pixel(x, y - 1).a < 0.5 or x == 0 or src.get_pixel(x - 1, y).a < 0.5
			var down := y == SIZE - 1 or src.get_pixel(x, y + 1).a < 0.5 or x == SIZE - 1 or src.get_pixel(x + 1, y).a < 0.5
			if up and not down:
				img.set_pixel(x, y, c.lightened(0.28))
			elif down and not up:
				img.set_pixel(x, y, c.darkened(0.28))


static func _outline(img: Image, color: Color) -> void:
	var src := img.duplicate() as Image
	var oc := Color(color.r, color.g, color.b, 1.0)
	for y in SIZE:
		for x in SIZE:
			if src.get_pixel(x, y).a >= 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and src.get_pixel(q.x, q.y).a >= 0.5:
					img.set_pixel(x, y, oc)
					break
