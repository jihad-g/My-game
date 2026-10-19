class_name TitleBackdrop
extends TextureRect
## Milestone 37: the title screen's moving pixel-art landscape, all our own:
## a banded dusk sky with twinkling stars and a setting sun, floating shard
## islands, three layers of blocky mountains and hills drifting past (pines,
## a little castle with a lit window), clouds and rising sparks. It is drawn
## at 320 x 180 into a small viewport and scaled up with crisp pixels.

const W := 320
const H := 180

var _vp := SubViewport.new()
var _painter := Painter.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.size = Vector2i(W, H)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_painter.size = Vector2(W, H)
	_vp.add_child(_painter)
	texture = _vp.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


## Seconds the scene has been moving (tests).
func time() -> float:
	return _painter.t


class Painter extends Control:
	var t := 0.0
	var _stars: Array = []  # [Vector2, phase, bright]
	var _sparks: Array = []  # [x, speed, phase, colour]
	const SKY := [Color(0.07, 0.06, 0.18), Color(0.2, 0.12, 0.33), Color(0.47, 0.22, 0.42), Color(0.86, 0.43, 0.38), Color(1.0, 0.72, 0.45)]

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 37
		for i in 70:
			_stars.append([Vector2(rng.randi_range(0, 319), rng.randi_range(0, 80)), rng.randf() * TAU, rng.randf()])
		for i in 24:
			var col := Color(0.6, 0.95, 1.0) if i % 3 else Color(1.0, 0.85, 0.45)
			_sparks.append([rng.randf_range(0, 320), rng.randf_range(4.0, 10.0), rng.randf() * TAU, col])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		_sky()
		_sun()
		_stars_draw()
		_clouds(0.6, 26.0, 0.55)
		_islands()
		_range(0.0, 2.0, 108.0, 16.0, 0.013, Color(0.36, 0.24, 0.46), false, 4)
		_clouds(1.2, 70.0, 0.75)
		_range(1.0, 5.0, 124.0, 13.0, 0.021, Color(0.22, 0.15, 0.31), true, 3)
		_castle(5.0, 124.0)
		_range(2.0, 11.0, 146.0, 9.0, 0.035, Color(0.11, 0.13, 0.18), false, 2)
		_pines(11.0, 146.0, 9.0)
		draw_rect(Rect2(0, 166, 320, 14), Color(0.05, 0.06, 0.09))
		_sparks_draw()

	func _sky() -> void:
		# Bands 3 px high: the stepped gradient is part of the pixel look.
		for y in range(0, 150, 3):
			var f := clampf(y / 150.0, 0.0, 1.0) * (SKY.size() - 1)
			var i := mini(int(f), SKY.size() - 2)
			draw_rect(Rect2(0, y, W, 3), (SKY[i] as Color).lerp(SKY[i + 1], f - i))
		draw_rect(Rect2(0, 150, W, 30), SKY[SKY.size() - 1])

	func _sun() -> void:
		var c := Vector2(232, 112)
		var r := 26
		for y in range(-r, r + 1):
			var half := int(sqrt(float(r * r - y * y)))
			var row := c.y + y
			# Retro stripes through the lower half.
			if y > 4 and posmod(int(row), 6) < (1 + (y - 4) / 8):
				continue
			var col := Color(1.0, 0.86, 0.5).lerp(Color(1.0, 0.5, 0.35), float(y + r) / (2.0 * r))
			draw_rect(Rect2(c.x - half, row, half * 2 + 1, 1), col)

	func _stars_draw() -> void:
		for s in _stars:
			var b: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (1.0 + s[2] * 2.0) + s[1]))
			var p: Vector2 = s[0]
			var col := Color(1, 1, 1, b * (1.0 - p.y / 110.0))
			draw_rect(Rect2(p, Vector2.ONE), col)
			if s[2] > 0.85:
				draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 1, col.a * 0.5))
				draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 1, col.a * 0.5))

	func _clouds(speed: float, y: float, alpha: float) -> void:
		for i in 4:
			var x := fposmod(i * 97.0 + t * speed * (1.0 + i * 0.15), W + 80.0) - 60.0
			var yy := y + (i % 2) * 9.0
			var col := Color(1.0, 0.78, 0.82, alpha * 0.55)
			draw_rect(Rect2(int(x), int(yy), 34, 4), col)
			draw_rect(Rect2(int(x) + 6, int(yy) - 3, 18, 3), col)
			draw_rect(Rect2(int(x) + 22, int(yy) - 2, 9, 2), col)

	## Floating rock islands with a glowing crystal on top, bobbing slowly.
	func _islands() -> void:
		var spots := [[44.0, 58.0, 1.0], [232.0, 24.0, 0.6], [278.0, 72.0, 0.85]]
		for k in spots.size():
			var sp: Array = spots[k]
			var s: float = sp[2]
			var x: float = sp[0] + sin(t * 0.13 + k) * 3.0
			var y: float = sp[1] + sin(t * 0.7 + k * 2.1) * 2.0
			var w := int(26 * s)
			# Rock: rows getting narrower downwards.
			for r in int(12 * s):
				var half := int(w * 0.5 * (1.0 - float(r) / (12.0 * s)))
				var col := Color(0.32, 0.25, 0.3).darkened(r * 0.03)
				draw_rect(Rect2(int(x) - half, int(y) + r, half * 2, 1), col)
			draw_rect(Rect2(int(x) - w / 2, int(y) - 2, w, 2), Color(0.3, 0.6, 0.35))  # grass
			# The shard and its glow.
			var glow := 0.5 + 0.5 * sin(t * 1.6 + k)
			draw_circle(Vector2(int(x), int(y) - 9), 7.0 * s, Color(0.5, 0.95, 1.0, 0.12 + 0.1 * glow))
			for r in 9:
				var half: int = [0, 1, 1, 2, 2, 2, 1, 1, 0][r]
				draw_rect(Rect2(int(x) - half, int(y) - 14 + r, half * 2 + 1, 1), Color(0.55, 0.95, 1.0) if r < 5 else Color(0.25, 0.65, 0.9))
			draw_rect(Rect2(int(x), int(y) - 14, 1, 7), Color(0.95, 1, 1))

	## A blocky mountain range drifting left, `step` px columns.
	func _range(sd: float, speed: float, base: float, amp: float, freq: float, col: Color, snow: bool, step: int) -> void:
		var off := t * speed
		for x in range(0, W, step):
			var h := _height(x + off, sd, base, amp, freq)
			var top := floorf(h / step) * step
			draw_rect(Rect2(x, top, step, H - top), col)
			if snow and top < base - amp * 0.9:
				draw_rect(Rect2(x, top, step, step), Color(0.92, 0.9, 1.0))
				if top < base - amp * 1.35:
					draw_rect(Rect2(x, top + step, step, step), Color(0.8, 0.78, 0.92))

	func _height(wx: float, sd: float, base: float, amp: float, freq: float) -> float:
		return base - amp * (sin(wx * freq + sd) + 0.6 * sin(wx * freq * 2.3 + sd * 3.0) + 0.35 * sin(wx * freq * 5.1 + sd * 7.0))

	## Pines along the nearest hills.
	func _pines(speed: float, base: float, amp: float) -> void:
		var off := t * speed
		var first := int(floor(off / 13.0))
		for k in range(first, first + 27):
			if posmod(k * 7919, 5) == 0:
				continue
			var wx := k * 13.0
			var x := int(wx - off)
			var gy := int(_height(wx, 2.0, base, amp, 0.035) / 2.0) * 2
			var tall := 6 + posmod(k * 31, 4)
			var green := Color(0.07, 0.17, 0.14)
			for r in tall:
				var half := int((r + 1) * 0.45)
				draw_rect(Rect2(x - half, gy - tall + r - 1, half * 2 + 1, 1), green)

	## A little castle on the middle range, with a lit window.
	func _castle(speed: float, base: float) -> void:
		var wx := 300.0
		var x := fposmod(wx - t * speed, W + 120.0) - 40.0
		var gy := _height(x + t * speed, 1.0, base, 13.0, 0.021)
		var col := Color(0.15, 0.1, 0.22)
		var xi := int(x)
		var yi := int(gy) + 2
		draw_rect(Rect2(xi, yi - 14, 16, 14), col)
		draw_rect(Rect2(xi - 4, yi - 20, 6, 20), col)
		draw_rect(Rect2(xi + 14, yi - 22, 6, 22), col)
		for i in 3:
			draw_rect(Rect2(xi + 1 + i * 5, yi - 16, 3, 2), col)
		draw_rect(Rect2(xi - 4, yi - 22, 2, 2), col)
		draw_rect(Rect2(xi, yi - 22, 2, 2), col)
		draw_rect(Rect2(xi + 14, yi - 24, 2, 2), col)
		draw_rect(Rect2(xi + 18, yi - 24, 2, 2), col)
		var lit := 0.75 + 0.25 * sin(t * 3.0)
		draw_rect(Rect2(xi + 16, yi - 16, 2, 3), Color(1.0, 0.8, 0.4, lit))
		draw_rect(Rect2(xi + 6, yi - 9, 3, 4), Color(1.0, 0.75, 0.35, lit * 0.9))

	## Sparks of shard light drifting up.
	func _sparks_draw() -> void:
		for s in _sparks:
			var y := fposmod(180.0 - t * float(s[1]) - float(s[2]) * 25.0, 200.0)
			var x: float = float(s[0]) + sin(t * 0.8 + float(s[2])) * 6.0
			var a := clampf(y / 180.0, 0.0, 1.0) * (0.5 + 0.5 * sin(t * 4.0 + float(s[2])))
			var c: Color = s[3]
			draw_rect(Rect2(int(x), int(y), 1, 1), Color(c.r, c.g, c.b, a))
