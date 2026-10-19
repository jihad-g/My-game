class_name PixelLogo
extends RefCounted
## Milestone 37: the SHARDLANDS logo, drawn pixel by pixel from our own blocky
## letters - a gold-to-ember gradient with a light top edge, a dark outline,
## a drop shadow and a crystal shard above the word. Made once at runtime, so
## there is no image file to keep in sync.

## Our own 6 x 7 letters ("#" = filled).
const GLYPHS := {
	"S": [".####.", "##..##", "##....", ".####.", "....##", "##..##", ".####."],
	"H": ["##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
	"A": ["..##..", ".####.", "##..##", "##..##", "######", "##..##", "##..##"],
	"R": ["#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##"],
	"D": ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
	"L": ["##....", "##....", "##....", "##....", "##....", "##....", "######"],
	"N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
}
## The crystal shard above the word.
const SHARD := ["....#....", "...###...", "..#####..", ".#######.", ".#######.", ".#######.",
	".#######.", "..#####..", "...###...", "....#...."]
const GLYPH_W := 6
const GLYPH_H := 7
const GAP := 1
const PAD := 2

const OUTLINE := Color(0.13, 0.06, 0.05)
const SHADOW := Color(0.04, 0.02, 0.07, 0.75)
const TOP := Color(1.0, 0.93, 0.5)
const BOTTOM := Color(0.93, 0.42, 0.14)
const SHARD_LIGHT := Color(0.62, 0.97, 1.0)
const SHARD_DARK := Color(0.16, 0.55, 0.85)
const SHARD_OUTLINE := Color(0.05, 0.08, 0.2)


static func texture() -> ImageTexture:
	return ImageTexture.create_from_image(image())


## The logo at 1 pixel per pixel (scale it up with nearest filtering).
static func image(word: String = "SHARDLANDS") -> Image:
	var text_w := word.length() * (GLYPH_W + GAP) - GAP
	var shard_w: int = SHARD[0].length()
	var shard_h := SHARD.size()
	var w := text_w + PAD * 2 + 1
	var h := shard_h + 2 + GLYPH_H + PAD * 2 + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Which pixels are letters (value = row, for the gradient) and which are shard.
	var letters := {}
	var ty := PAD + shard_h + 2
	for i in word.length():
		var g: Array = GLYPHS.get(word[i], GLYPHS["S"])
		for r in GLYPH_H:
			var row: String = g[r]
			for c in GLYPH_W:
				if row[c] == "#":
					letters[Vector2i(PAD + i * (GLYPH_W + GAP) + c, ty + r)] = r
	var shard := {}
	var sx := (w - shard_w) / 2
	for r in shard_h:
		var row: String = SHARD[r]
		for c in shard_w:
			if row[c] == "#":
				shard[Vector2i(sx + c, PAD - 1 + r)] = c
	var all := letters.duplicate()
	all.merge(shard)
	# Shadow, then outline, then fill.
	for p: Vector2i in all:
		var q := p + Vector2i(1, 1)
		if not all.has(q) and _inside(img, q):
			img.set_pixelv(q, SHADOW)
	for p: Vector2i in all:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var q: Vector2i = p + d
			if not all.has(q) and _inside(img, q):
				img.set_pixelv(q, SHARD_OUTLINE if shard.has(p) else OUTLINE)
	for p: Vector2i in letters:
		var t: float = float(letters[p]) / float(GLYPH_H - 1)
		var col := TOP.lerp(BOTTOM, t)
		if not letters.has(p + Vector2i(0, -1)):
			col = col.lightened(0.35)  # light top edge
		elif not letters.has(p + Vector2i(0, 1)):
			col = col.darkened(0.18)
		img.set_pixelv(p, col)
	var mid := sx + shard_w / 2
	for p: Vector2i in shard:
		var col := SHARD_LIGHT if p.x < mid else SHARD_DARK
		if p.x == mid:
			col = Color(0.95, 1.0, 1.0)  # the bright facet edge
		img.set_pixelv(p, col)
	return img


static func _inside(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height()
