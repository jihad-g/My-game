class_name BlastFX
extends RefCounted
## Milestone 38: explosions and hit effects in the style of the reference clip,
## measured frame by frame (30 fps, see CombatFeel). Everything is built from code:
## glowing shapes, flat-coloured smoke blocks and square sparks, no textures.
##
##   BlastFX.hit_pop(parent, at, heavy, color)          the light pop + sparks where a blow lands
##   BlastFX.poof(parent, at, count, size)              pale puffs (deaths)
##   BlastFX.fire_blast(parent, at, radius)             screen +40%, fireball 5f, ground ring 8f, smoke, embers
##   BlastFX.magic_burst(parent, at, radius, element)   core 2f, dome peaks at frame 5, puffs that stay ~2 s
##   BlastFX.poison_cloud(parent, at, radius, seconds)  chunky emerald blocks
##   BlastFX.fire_pillar(parent, at, height)            ring 2f, shoots up 2f, burns 5f, fades 3f
##   BlastFX.beam(parent, from, to, color)              thin beam 4f, impact 1f, sparks 3f
##   BlastFX.element_blast(parent, at, element, radius) picks the right one for an element
##
## Effects are tweened in game time, so they freeze during hit-stop. With "reduce
## flashing" the screen and light flashes are much weaker. VFX.enabled (the
## "vfx_particles" setting) turns the smoke, embers and sparks off.

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 edge_color : source_color = vec4(0.97, 0.87, 0.53, 1.0);
uniform vec4 body_color : source_color = vec4(0.86, 0.44, 0.27, 1.0);
uniform float energy = 1.6;
uniform float ring_inner = 0.6;
uniform float fade_alpha = 1.0;
void fragment() {
	float r = COLOR.r;
	float inside = smoothstep(ring_inner, ring_inner + 0.08, r);
	float edge = smoothstep(mix(ring_inner, 1.0, 0.55), 1.0, r) * (1.0 - smoothstep(0.985, 1.0, r) * 0.6);
	ALBEDO = mix(body_color.rgb, edge_color.rgb * 1.4, edge) * energy;
	ALPHA = inside * (0.35 + 0.65 * edge) * fade_alpha;
}
"""

const FRESNEL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform vec4 inner_color : source_color = vec4(1.0);
uniform float energy = 1.4;
uniform float fresnel_power = 1.6;
uniform float core_alpha = 0.2;
uniform float fade_alpha = 1.0;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	ALBEDO = mix(inner_color.rgb, rim_color.rgb, f) * energy;
	ALPHA = (core_alpha + (1.0 - core_alpha) * f) * fade_alpha;
}
"""

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 core_color : source_color = vec4(0.97, 0.95, 0.59, 1.0);
uniform vec4 edge_color : source_color = vec4(0.91, 0.49, 0.26, 1.0);
uniform float energy = 1.2;
uniform float fade_alpha = 1.0;
varying float vy;
void vertex() {
	vy = VERTEX.y + 0.5;
}
void fragment() {
	float flick = 0.7 + 0.3 * sin(TIME * 42.0 + vy * 16.0 + UV.x * 37.7);
	float fade = (1.0 - smoothstep(0.5, 1.0, vy)) * smoothstep(0.0, 0.05, vy);
	ALBEDO = mix(core_color.rgb, edge_color.rgb, smoothstep(0.0, 0.85, vy)) * energy;
	ALPHA = fade * flick * fade_alpha;
}
"""

## Colours of each element's dome burst: [rim, inner, puff start, puff end, light].
const DOMES := {
	&"arcane": [Color("f7dafa"), Color("c98dc7"), Color("d3dfa0"), Color("6a9c5f"), Color("ff9be8")],
	&"frost": [Color("e6fbff"), Color("84d2dc"), Color("eaf6fb"), Color("9cc4d6"), Color("a9e4e3")],
	&"lightning": [Color("e6fbff"), Color("a9e4e3"), Color("f2f7ff"), Color("8fa6c8"), Color("cfe8ff")],
	&"holy": [Color("fff3c4"), Color("f7d16f"), Color("fff1c8"), Color("d8c27a"), Color("ffe08a")],
	&"shadow": [Color("b49cff"), Color("4a2a6a"), Color("5b4372"), Color("241a30"), Color("9a6bff")],
	&"poison": [Color("bdf5a0"), Color("48b94c"), Color("8fd46a"), Color("2f6e36"), Color("7fe07a")],
	&"physical": [Color("f2e6cf"), Color("a7907a"), Color("d2d6c2"), Color("989e90"), Color("ffe6c0")],
}
## Most blasts alive at once; past this the light version plays (big fights stay fast).
const MAX_ACTIVE := 8
## Screen flashes and camera kicks only for blasts this close to the camera's focus.
const NEAR := 30.0

static var _shaders := {}
static var _disk: ArrayMesh
static var _cube: BoxMesh
static var _sphere: SphereMesh
static var _column: CylinderMesh
static var active := 0
## Counts for tests.
static var made := 0


# --- Small pieces ----------------------------------------------------------------------

## Where a blow lands: a real light that pops on for 1 frame and fades over 2
## (measured), a soft glow and a few square sparks. Heavy hits are bigger and warmer.
static func hit_pop(parent: Node, at: Vector3, heavy: bool, color: Color = Color(1, 1, 1)) -> void:
	if not _ok(parent):
		return
	var c := color.lerp(Color(1, 0.96, 0.85), 0.55)
	light_pop(parent, at, c, 3.2 if heavy else 2.0, CombatFeel.POP_UP, CombatFeel.POP_HOLD, CombatFeel.POP_DOWN,
		5.0 if heavy else 3.5)
	sparks(parent, at, 9 if heavy else 5, c)


## A light plus a glow. up/hold/down are frames at 30 fps.
static func light_pop(parent: Node, at: Vector3, color: Color, energy: float, up: float, hold: float, down: float, light_range: float) -> void:
	if not _ok(parent):
		return
	var root := _host(parent, at)
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = light_range
	l.light_energy = 0.0
	l.shadow_enabled = false
	root.add_child(l)
	var g := _glow_sprite(root, minf(2.4, light_range * 0.18), color)
	var gm: StandardMaterial3D = g.material_override
	var dim := 0.35 if Settings.reduce_flashing() else 1.0
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var k := 1.0
		if f < up:
			k = f / up
		elif f > up + hold:
			k = maxf(0.0, 1.0 - (f - up - hold) / maxf(1.0, down))
		l.light_energy = energy * k * dim
		gm.albedo_color.a = 0.5 * k * dim
	_run(root, CombatFeel.sec(up + hold + down + 1.0), upd)


## Tiny glowing square sparks thrown out (life 9 frames).
static func sparks(parent: Node, at: Vector3, count: int, color: Color) -> void:
	if not _ok(parent) or not VFX.enabled or count <= 0:
		return
	var root := _host(parent, at)
	var mat := glow_material(color, 1.8)
	var cubes: Array[MeshInstance3D] = []
	var vels: Array[Vector3] = []
	var sizes: Array[float] = []
	for i in count:
		var m := MeshInstance3D.new()
		m.mesh = _cube_mesh()
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		cubes.append(m)
		vels.append(Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.2), randf_range(-1.0, 1.0)).normalized() * randf_range(3.5, 7.0))
		sizes.append(randf_range(0.05, 0.1))
	var life := 9.0
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		for i in cubes.size():
			cubes[i].position = vels[i] * t + Vector3(0.0, -7.0 * t * t, 0.0)
			cubes[i].scale = Vector3.ONE * sizes[i] * maxf(0.0, 1.0 - f / life)
	_run(root, CombatFeel.sec(life), upd)


## A flat ring on the ground. Radii in metres, frames at 30 fps.
static func ground_ring(parent: Node, at: Vector3, r0: float, r1: float, frames: float, thick0: float, thick1: float,
		edge: Color, body: Color, fade_at: float, fade_len := 3.0) -> void:
	if not _ok(parent):
		return
	var root := _host(parent, ground_point(at) + Vector3(0, 0.05, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = _disk_mesh()
	var mat := _shader_mat("ring", RING_SHADER)
	mat.set_shader_parameter("edge_color", edge)
	mat.set_shader_parameter("body_color", body)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var life := frames + fade_len
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var u := CombatFeel.ease_out_quad(f / frames)
		var r := maxf(lerpf(r0, r1, u), 0.01)
		var th := lerpf(thick0, thick1, u)
		mi.scale = Vector3(r, 1.0, r)
		mat.set_shader_parameter("ring_inner", maxf(0.0, 1.0 - th / r))
		mat.set_shader_parameter("fade_alpha", 1.0 if f < fade_at else maxf(0.0, 1.0 - (f - fade_at) / maxf(life - fade_at, 0.01)))
	_run(root, CombatFeel.sec(life), upd)


## Pale puffs for deaths (the clip's poof). `size` ~ the body's size in metres.
static func poof(parent: Node, at: Vector3, count: int = 12, size := 1.0) -> void:
	if not _ok(parent):
		return
	var g := ground_point(at)
	_puffs(parent, g + Vector3(0, 0.6 * size, 0), count, [Color("d2d6c2"), Color("989e90")], 0.45 * size,
		Vector2(0.28, 0.42) * size, 0.9 * size, 14.0, 0.9 * size)
	made += 1


## The whole screen brightens for a moment (measured: fire +40%, pillar +27%, magic +24%).
## up/hold/down are frames. Only when the blast is near the camera.
static func screen_flash(at: Vector3, peak: float, up: float, hold: float, down: float) -> void:
	var w := World.instance
	if w == null or w.day_night == null or not _near_camera(at):
		return
	var dn := w.day_night
	if Settings.reduce_flashing():
		peak *= 0.3
	var tw := dn.create_tween()
	tw.tween_property(dn, "blast_flash", maxf(dn.blast_flash, peak), maxf(0.001, CombatFeel.sec(up)))
	tw.tween_interval(maxf(0.001, CombatFeel.sec(hold)))
	tw.tween_property(dn, "blast_flash", 0.0, maxf(0.001, CombatFeel.sec(down)))


# --- Big effects -------------------------------------------------------------------------

## Fire (measured on the clip): screen +40% for 10 frames, a fireball grows over 5
## frames, a ground ring forms at frame 4 and spreads 2 m -> 6.5 m over 8 frames,
## then hot red-brown smoke that cools to charcoal-green, and embers.
## `radius` = the blast's damage radius (the ring ends there).
static func fire_blast(parent: Node, at: Vector3, radius: float = 3.25) -> void:
	if not _ok(parent):
		return
	var k := clampf(radius / 3.25, 0.3, 2.5)
	var c := ground_point(at)
	if not _begin():
		_light_version(parent, c, &"fire", radius)
		return
	screen_flash(c, CombatFeel.FLASH_FIRE * minf(1.0, k), 0.0, 10.0, 5.0)
	_kick(c, 1.25 * minf(1.0, k))
	light_pop(parent, c + Vector3.UP * 1.6 * k, Color("ffb15a"), 6.0, 0.0, 10.0, 5.0, 16.0 * k)
	var root := _host(parent, c)
	# The ring forms as the fireball peaks (frame 4). Tied to the effect, so it never
	# fires after the effect (or its parent) is gone.
	root.create_tween().tween_callback(func() -> void:
		if root.is_inside_tree():
			ground_ring(root.get_parent(), c, 2.0 * k, 6.5 * k, 8.0, 1.4 * k, 0.3 * k, Color("f8de86"), Color("db7046"), 6.0, 5.0)).set_delay(CombatFeel.sec(4.0))
	var ball := MeshInstance3D.new()
	ball.mesh = _sphere_mesh()
	var bm := _shader_mat("fresnel", FRESNEL_SHADER)
	bm.set_shader_parameter("rim_color", Color("f39951"))
	bm.set_shader_parameter("inner_color", Color("fbe9b0"))
	bm.set_shader_parameter("energy", 1.3)
	bm.set_shader_parameter("core_alpha", 0.5)
	bm.set_shader_parameter("fresnel_power", 1.3)
	ball.material_override = bm
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position.y = 0.9 * k
	root.add_child(ball)
	var puffs: Array[MeshInstance3D] = []
	var puff_data: Array[Dictionary] = []
	var embers: Array[MeshInstance3D] = []
	var ember_v: Array[Vector3] = []
	var ember_life: Array[float] = []
	if VFX.enabled:
		var smoke_cols := [Color("cf664d"), Color("7c523f"), Color("a85a40"), Color("426742"), Color("343e36")]
		for i in 14:
			var m := MeshInstance3D.new()
			m.mesh = _cube_mesh()
			var pm := StandardMaterial3D.new()
			pm.albedo_color = smoke_cols[i % smoke_cols.size()]
			pm.roughness = 1.0
			pm.emission_enabled = true
			pm.emission = Color("ff6a3a")
			pm.emission_energy_multiplier = 0.9
			m.material_override = pm
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := randf() * TAU
			var r := randf_range(1.0, 3.2) * k
			m.position = Vector3(cos(a) * r, randf_range(0.4, 1.4) * k, sin(a) * r)
			m.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
			m.scale = Vector3.ONE * 0.001
			root.add_child(m)
			puffs.append(m)
			puff_data.append({"p0": m.position, "v": Vector3(cos(a) * 0.5, randf_range(0.4, 0.8), sin(a) * 0.5) * k,
				"s": randf_range(0.6, 1.1) * k, "born": randf_range(5.0, 8.0), "life": randf_range(18.0, 26.0), "mat": pm})
		var em1 := glow_material(Color("fbbd42"), 2.0)
		var em2 := glow_material(Color("e97e42"), 1.7)
		for i in 22:
			var e := MeshInstance3D.new()
			e.mesh = _cube_mesh()
			e.material_override = em1 if i % 2 == 0 else em2
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			e.position = Vector3(0.0, 0.8 * k, 0.0)
			e.scale = Vector3.ONE * 0.07
			root.add_child(e)
			embers.append(e)
			var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(3.0, 8.0) * k
			ember_v.append(Vector3(dir.x, randf_range(3.0, 7.0) * sqrt(k), dir.z))
			ember_life.append(randf_range(25.0, 40.0))
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		ball.scale = Vector3.ONE * lerpf(0.3, 2.2, CombatFeel.ease_out_cubic(f / 5.0)) * k
		bm.set_shader_parameter("fade_alpha", 1.0 if f < 5.0 else maxf(0.0, 1.0 - (f - 5.0) / 3.0))
		ball.visible = f < 8.0
		for i in puffs.size():
			var d: Dictionary = puff_data[i]
			var lf := f - float(d["born"])
			if lf < 0.0:
				continue
			var u := lf / float(d["life"])
			var size := CombatFeel.ease_out_cubic(u / 0.25) if u < 0.25 else maxf(0.0, 1.0 - CombatFeel.ease_in_out_quad((u - 0.25) / 0.75))
			puffs[i].scale = Vector3.ONE * float(d["s"]) * maxf(size, 0.001)
			puffs[i].position = (d["p0"] as Vector3) + (d["v"] as Vector3) * CombatFeel.sec(lf)
			(d["mat"] as StandardMaterial3D).emission_energy_multiplier = maxf(0.0, 0.9 - u * 1.8)
		for i in embers.size():
			var v0 := ember_v[i]
			var p := Vector3(v0.x * t * 0.8, 0.0, v0.z * t * 0.8)
			p.y = maxf(0.05, 0.8 * k + v0.y * t - 6.0 * t * t)
			embers[i].position = p
			embers[i].scale = Vector3.ONE * (0.07 * (0.6 + 0.4 * sin(f * 1.7 + float(i))) if f < ember_life[i] else 0.001)
	_run(root, CombatFeel.sec(42.0), upd, true)


## Magic (measured on the clip, arcane): a white core 2 frames, a dome that grows for
## 3 frames (peak at frame 5) and fades by frame 8, spark lines shooting out, then
## puffs that settle and stay about 2 s. Screen +24% (5 up, 6 down).
## Other elements use the same timing in their own colours (DOMES).
## `full` = false: only the core, dome and spark lines (small buffs and blinks) - no
## screen flash, no lingering puffs, and it centres on `at` instead of the ground.
static func magic_burst(parent: Node, at: Vector3, radius: float = 4.2, element: StringName = &"arcane", full := true) -> void:
	if not _ok(parent):
		return
	var k := clampf(radius / 4.2, 0.2, 2.5)
	var c := ground_point(at) if full else at - Vector3(0, 0.9 * k, 0)
	if full and not _begin():
		_light_version(parent, c, element, radius)
		return
	var col: Array = DOMES.get(element, DOMES[&"arcane"])
	if full:
		screen_flash(c, CombatFeel.FLASH_MAGIC * minf(1.0, k), 5.0, 0.0, 6.0)
		if radius >= 3.0:
			_kick(c, 0.6 * minf(1.0, k))
	else:
		made += 1
	light_pop(parent, c + Vector3.UP * 1.4 * k, col[4], 4.0 if full else 2.2, 4.0, 1.0, 6.0, (12.0 if full else 7.0) * k)
	var root := _host(parent, c)
	var core := MeshInstance3D.new()
	core.mesh = _sphere_mesh()
	var cm := _shader_mat("fresnel", FRESNEL_SHADER)
	cm.set_shader_parameter("rim_color", Color("fff3c4"))
	cm.set_shader_parameter("inner_color", Color("fbf9d5"))
	cm.set_shader_parameter("energy", 1.6)
	cm.set_shader_parameter("core_alpha", 0.8)
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position.y = 0.9 * k
	root.add_child(core)
	var dome := MeshInstance3D.new()
	dome.mesh = _sphere_mesh()
	var dm := _shader_mat("fresnel", FRESNEL_SHADER)
	dm.set_shader_parameter("rim_color", col[0])
	dm.set_shader_parameter("inner_color", col[1])
	dm.set_shader_parameter("energy", 1.1)
	dm.set_shader_parameter("core_alpha", 0.1)
	dome.material_override = dm
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position.y = 0.3 * k
	dome.scale = Vector3.ONE * 0.01
	root.add_child(dome)
	var lines: Array[MeshInstance3D] = []
	var line_dir: Array[Vector3] = []
	var line_len: Array[float] = []
	var puffs: Array[MeshInstance3D] = []
	var puff_data: Array[Dictionary] = []
	if VFX.enabled:
		var line_mat := glow_material((col[0] as Color).lerp(Color.WHITE, 0.5), 1.8)
		for i in 12:
			var ln := MeshInstance3D.new()
			ln.mesh = _cube_mesh()
			ln.material_override = line_mat
			ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ln.visible = false
			root.add_child(ln)
			var a := float(i) / 12.0 * TAU + randf_range(-0.2, 0.2)
			var el := randf_range(-0.15, 0.5)
			lines.append(ln)
			line_dir.append(Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el)))
			line_len.append(randf_range(1.6, 2.8) * k)
		for i in (14 if full else 0):
			var m := MeshInstance3D.new()
			m.mesh = _cube_mesh()
			var pm := StandardMaterial3D.new()
			var c0: Color = col[2] if i % 3 != 0 else (col[2] as Color).darkened(0.15)
			pm.albedo_color = c0
			pm.roughness = 1.0
			pm.emission_enabled = true
			pm.emission = c0
			pm.emission_energy_multiplier = 0.8
			m.material_override = pm
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := randf() * TAU
			var r := randf_range(2.0, 3.8) * k
			m.position = Vector3(cos(a) * r, randf_range(0.3, 1.3) * k, sin(a) * r)
			m.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
			m.scale = Vector3.ONE * 0.001
			root.add_child(m)
			puffs.append(m)
			puff_data.append({"p0": m.position, "v": Vector3(cos(a) * 0.25, randf_range(0.02, 0.1), sin(a) * 0.25) * k,
				"s": randf_range(0.6, 1.0) * k, "born": randf_range(2.0, 4.0), "life": randf_range(55.0, 80.0),
				"mat": pm, "c0": c0, "c1": (col[3] as Color) if i % 2 == 0 else (col[3] as Color).darkened(0.2)})
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		core.scale = Vector3.ONE * lerpf(0.25, 0.8, CombatFeel.ease_out_cubic(f / 2.0)) * k
		cm.set_shader_parameter("fade_alpha", maxf(0.0, 1.0 - maxf(0.0, f - 2.0) / 2.0))
		core.visible = f < 4.0
		var du := clampf((f - 2.0) / 3.0, 0.0, 1.0)
		dome.scale = Vector3.ONE * (lerpf(0.8, 4.2, CombatFeel.ease_out_cubic(du)) + maxf(0.0, f - 5.0) * 0.08) * k
		var da := 0.0
		if f >= 2.0 and f < 5.0:
			da = CombatFeel.ease_out_cubic(du)
		elif f >= 5.0:
			da = maxf(0.0, 1.0 - (f - 5.0) / 3.0)
		dm.set_shader_parameter("fade_alpha", da)
		dome.visible = f >= 2.0 and f < 9.0
		for i in lines.size():
			var lu := (f - 2.0) / 5.0
			lines[i].visible = lu >= 0.0 and lu < 1.0
			if not lines[i].visible:
				continue
			var length := line_len[i] * CombatFeel.ease_out_cubic(lu * 2.5)
			var off := (0.6 + 3.2 * CombatFeel.ease_out_quad(lu)) * k
			var dir := line_dir[i]
			lines[i].position = Vector3(0.0, 0.9 * k, 0.0) + dir * (off + length * 0.5)
			lines[i].basis = _look_basis(dir) * Basis.from_scale(Vector3(0.035, 0.035, maxf(0.01, length)))
		for i in puffs.size():
			var d: Dictionary = puff_data[i]
			var lf := f - float(d["born"])
			if lf < 0.0:
				continue
			var u := lf / float(d["life"])
			var size := 1.0
			if lf < 4.0:
				size = CombatFeel.ease_out_back(lf / 4.0)
			elif u > 0.8:
				size = maxf(0.0, 1.0 - (u - 0.8) / 0.2)
			puffs[i].scale = Vector3.ONE * float(d["s"]) * maxf(0.001, size)
			puffs[i].position = (d["p0"] as Vector3) + (d["v"] as Vector3) * CombatFeel.sec(lf)
			var pmat: StandardMaterial3D = d["mat"]
			var cu := minf(1.0, lf / 12.0)
			pmat.albedo_color = (d["c0"] as Color).lerp(d["c1"], cu)
			pmat.emission_energy_multiplier = 0.8 * (1.0 - cu)
	_run(root, CombatFeel.sec(86.0 if VFX.enabled and full else 10.0), upd, full)


## Poison (measured on the clip): chunky emerald blocks that grow in 6 frames, churn
## and shrink away at the end. `seconds` = how long the cloud stays (min 1 s).
static func poison_cloud(parent: Node, at: Vector3, radius: float = 2.3, seconds: float = 2.6) -> void:
	if not _ok(parent):
		return
	var c := ground_point(at)
	if not VFX.enabled or not _begin():
		_light_version(parent, c, &"poison", radius)
		return
	var k := clampf(radius / 2.3, 0.4, 3.0)
	var root := _host(parent, c)
	var cols := [Color("01a431"), Color("008d2c"), Color("007d25"), Color("01a431"), Color("54bb60")]
	var mats: Array[StandardMaterial3D] = []
	for i in cols.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 1.0
		m.emission_enabled = true
		m.emission = Color("54bb60") if i == 4 else Color("0b5a22")
		m.emission_energy_multiplier = 1.2 if i == 4 else 0.7
		mats.append(m)
	var cubes: Array[MeshInstance3D] = []
	var data: Array[Dictionary] = []
	for b in 6:
		var a := float(b) / 6.0 * TAU + randf_range(-0.4, 0.4)
		var r := 0.0 if b == 0 else randf_range(1.1, 2.3) * k
		var bc := Vector3(cos(a) * r, randf_range(0.5, 0.9), sin(a) * r)
		for i in 6 + randi() % 3:
			var m := MeshInstance3D.new()
			m.mesh = _cube_mesh()
			m.material_override = mats[randi() % mats.size()]
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var home := bc + Vector3(randf_range(-0.6, 0.6), randf_range(-0.35, 0.55), randf_range(-0.6, 0.6)) * sqrt(k)
			m.position = home
			m.rotation = Vector3(randf(), randf() * 3.0, randf())
			m.scale = Vector3.ONE * 0.001
			root.add_child(m)
			cubes.append(m)
			data.append({"home": home, "s": randf_range(0.35, 0.7) * sqrt(k), "ph": randf() * TAU, "spin": randf_range(-0.8, 0.8), "rot0": m.rotation.y})
	var fin := 6.0
	var fout := 6.0
	var stay := maxf(seconds * CombatFeel.FPS - fin - fout, 18.0)
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var grow := 1.0
		if f < fin:
			grow = CombatFeel.ease_out_back(f / fin)
		elif f > fin + stay:
			grow = maxf(0.0, 1.0 - (f - fin - stay) / fout)
		for i in cubes.size():
			var d: Dictionary = data[i]
			var home: Vector3 = d["home"]
			cubes[i].scale = Vector3.ONE * float(d["s"]) * maxf(0.001, grow)
			cubes[i].position = Vector3(home.x, home.y + sin(f * 0.12 + float(d["ph"])) * 0.08, home.z)
			cubes[i].rotation.y = float(d["rot0"]) + float(d["spin"]) * t
	_run(root, CombatFeel.sec(fin + stay + fout), upd, true)


## Fire pillar (measured on the clip): a ring at the base 2 frames, the column shoots
## up 2 frames, burns 5 and fades 3. Screen +27%.
static func fire_pillar(parent: Node, at: Vector3, height: float = 4.8) -> void:
	if not _ok(parent):
		return
	var c := ground_point(at)
	if not _begin():
		_light_version(parent, c, &"fire", 1.3)
		return
	var k := clampf(height / 4.8, 0.4, 3.0)
	screen_flash(c, CombatFeel.FLASH_PILLAR, 3.0, 3.0, 3.0)
	light_pop(parent, c + Vector3.UP * 2.0 * k, Color("ff9a40"), 4.0, 3.0, 3.0, 3.0, 10.0 * k)
	ground_ring(parent, c, 0.5 * k, 1.3 * k, 4.0, 0.45 * k, 0.2 * k, Color("fbbd42"), Color("e97e42"), 8.0, 4.0)
	var root := _host(parent, c)
	var outer := MeshInstance3D.new()
	outer.mesh = _column_mesh()
	var om := _shader_mat("column", COLUMN_SHADER)
	outer.material_override = om
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.mesh = _column_mesh()
	var im := _shader_mat("column", COLUMN_SHADER)
	im.set_shader_parameter("core_color", Color("fffbe0"))
	im.set_shader_parameter("edge_color", Color("fbbd42"))
	im.set_shader_parameter("energy", 1.3)
	inner.material_override = im
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner)
	var rg := 2.0
	var up := 2.0
	var ho := 5.0
	var fa := 3.0
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var h := 0.0 if f < rg else CombatFeel.ease_out_cubic((f - rg) / up)
		var a := 1.0 if f < rg + up + ho else maxf(0.0, 1.0 - (f - rg - up - ho) / fa)
		var wob := 1.0 + sin(f * 2.1) * 0.06
		var h_out := 4.8 * k * h + 0.01
		var h_in := 4.4 * k * h + 0.01
		outer.scale = Vector3(0.72 * wob * k, h_out, 0.72 * wob * k)
		outer.position.y = h_out * 0.5
		inner.scale = Vector3(0.3 * k, h_in, 0.3 * k)
		inner.position.y = h_in * 0.5
		om.set_shader_parameter("fade_alpha", a)
		im.set_shader_parameter("fade_alpha", a)
	_run(root, CombatFeel.sec(rg + up + ho + fa), upd, true)


## Beam (measured on the clip): a thin beam 4 frames, a gold impact 1 frame, sparks 3 frames.
static func beam(parent: Node, from: Vector3, to: Vector3, color: Color = Color("84d2dc")) -> void:
	if not _ok(parent) or from.distance_to(to) < 0.05:
		return
	var root := _host(parent, from)
	var dir := to - from
	var length := dir.length()
	var core := MeshInstance3D.new()
	core.mesh = _cube_mesh()
	core.material_override = glow_material(color.lerp(Color.WHITE, 0.75), 2.0)
	var glow := MeshInstance3D.new()
	glow.mesh = _cube_mesh()
	glow.material_override = glow_material(color, 1.4, 0.5)
	var look := _look_basis(dir.normalized())
	for m: MeshInstance3D in [core, glow]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		m.position = dir * 0.5
	var bf := 4.0
	var state := {"impact": false}
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var th := lerpf(1.0, 0.4, f / bf) if f < bf else 0.0
		core.basis = look * Basis.from_scale(Vector3(0.06 * th + 0.001, 0.06 * th + 0.001, length))
		glow.basis = look * Basis.from_scale(Vector3(0.22 * th + 0.001, 0.22 * th + 0.001, length))
		core.visible = f < bf
		glow.visible = f < bf
		if not state["impact"] and f >= bf and is_instance_valid(parent):
			state["impact"] = true
			light_pop(parent, to, Color("f7d16f"), 2.5, 0.0, 1.0, 3.0, 6.0)
			sparks(parent, to, 10, Color("f7d16f"))
	_run(root, CombatFeel.sec(bf + 1.0), upd)


## The right big effect for an element. Physical blasts are a dust ring and a poof.
static func element_blast(parent: Node, at: Vector3, element: StringName, radius: float) -> void:
	match element:
		&"fire":
			fire_blast(parent, at, radius)
		&"poison":
			poison_cloud(parent, at, radius)
			magic_burst(parent, at, radius * 0.8, &"poison")
		&"physical":
			if not _ok(parent):
				return
			var c := ground_point(at)
			ground_ring(parent, c, 0.4 * radius, radius, 8.0, 0.5 * radius, 0.15 * radius, Color("f2e6cf"), Color("a7907a"), 6.0, 4.0)
			poof(parent, c, 10, clampf(radius * 0.45, 0.5, 2.5))
			_kick(c, 0.8)
		_:
			magic_burst(parent, at, radius, element)


# --- Helpers -------------------------------------------------------------------------------

## The ground under `at` (or `at` itself when the ground is far, e.g. on a roof).
static func ground_point(at: Vector3) -> Vector3:
	var w := World.instance
	if w and w.is_inside_tree() and w.generator:
		var y := w.get_ground_height(at)
		if at.y - y > -1.0 and at.y - y < 3.0:
			return Vector3(at.x, y, at.z)
	return Vector3(at.x, at.y - 0.8, at.z)


static func glow_material(color: Color, energy := 1.5, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
	return m


static func _ok(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func _begin() -> bool:
	if active >= MAX_ACTIVE:
		return false
	active += 1
	made += 1
	return true


## The cheap version when too many blasts are alive: a ring and a light.
static func _light_version(parent: Node, c: Vector3, element: StringName, radius: float) -> void:
	var col := FX.color_of(element)
	ground_ring(parent, c, 0.3 * radius, radius, 8.0, 0.4 * radius, 0.15 * radius, col.lerp(Color.WHITE, 0.5), col, 6.0, 4.0)
	light_pop(parent, c + Vector3.UP, col, 3.0, 0.0, 3.0, 5.0, 4.0 + radius * 2.0)


static func _near_camera(at: Vector3) -> bool:
	var w := World.instance
	if w == null or w.camera_rig == null or not w.camera_rig.is_inside_tree():
		return false
	return w.camera_rig.global_position.distance_to(at) < NEAR


static func _kick(at: Vector3, scale: float) -> void:
	if _near_camera(at):
		World.instance.camera_rig.kick(scale)


static func _look_basis(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(dir, up)


static func _glow_sprite(parent: Node3D, size: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := glow_material(color, 1.0, 0.5)
	m.albedo_texture = FX.soft_texture()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _puffs(parent: Node, at: Vector3, count: int, colors: Array, spread: float, size_range: Vector2, speed: float,
		life: float, rise: float) -> void:
	if not VFX.enabled:
		return
	var root := _host(parent, at)
	var cubes: Array[MeshInstance3D] = []
	var data: Array[Dictionary] = []
	var mats: Array[StandardMaterial3D] = []
	for c in colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		mats.append(m)
	for i in count:
		var cube := MeshInstance3D.new()
		cube.mesh = _cube_mesh()
		cube.material_override = mats[i % mats.size()]
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := float(i) / float(count) * TAU + randf_range(-0.3, 0.3)
		var r := randf_range(0.4, 1.0) * spread
		var p0 := Vector3(cos(a) * r, randf_range(-0.2, 0.3), sin(a) * r)
		cube.position = p0
		cube.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		cube.scale = Vector3.ONE * 0.001
		root.add_child(cube)
		cubes.append(cube)
		data.append({"p0": p0, "v": Vector3(cos(a) * speed, randf_range(0.4, 0.9) + rise, sin(a) * speed), "s": randf_range(size_range.x, size_range.y)})
	var upd := func(t: float) -> void:
		var f := t * CombatFeel.FPS
		var u := minf(1.0, f / life)
		var size := CombatFeel.ease_out_cubic(u / 0.25) * 1.15 if u < 0.25 else 1.15 * (1.0 - CombatFeel.ease_in_out_quad((u - 0.25) / 0.75))
		var travel := (1.0 - exp(-5.0 * t)) / 5.0  # movement that slows down (drag)
		for i in cubes.size():
			var d: Dictionary = data[i]
			cubes[i].position = (d["p0"] as Vector3) + (d["v"] as Vector3) * travel
			cubes[i].scale = Vector3.ONE * float(d["s"]) * maxf(0.001, size)
	_run(root, CombatFeel.sec(life), upd)


static func _host(parent: Node, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.add_to_group(&"blast_fx")
	parent.add_child(root)
	root.global_position = at
	return root


## Plays `update(t)` over `seconds` of game time, then frees the effect.
## `counted` effects free a slot of MAX_ACTIVE when they end.
static func _run(root: Node3D, seconds: float, update: Callable, counted := false) -> void:
	update.call(0.0)
	var tw := root.create_tween()
	tw.tween_method(update, 0.0, seconds, seconds)
	tw.tween_callback(root.queue_free)
	if counted:
		root.tree_exiting.connect(func() -> void: active = maxi(active - 1, 0), CONNECT_ONE_SHOT)


static func _shader_mat(id: String, code: String) -> ShaderMaterial:
	if not _shaders.has(id):
		var s := Shader.new()
		s.code = code
		_shaders[id] = s
	var m := ShaderMaterial.new()
	m.shader = _shaders[id]
	return m


static func _cube_mesh() -> BoxMesh:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	return _cube


static func _sphere_mesh() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 20
		_sphere.rings = 10
	return _sphere


static func _column_mesh() -> CylinderMesh:
	if _column == null:
		_column = CylinderMesh.new()
		_column.top_radius = 0.5
		_column.bottom_radius = 0.7
		_column.height = 1.0
		_column.radial_segments = 14
		_column.rings = 1
		_column.cap_top = false
		_column.cap_bottom = false
	return _column


## Flat disk, radius 1. Vertex colour r = distance from the centre (0..1).
static func _disk_mesh() -> ArrayMesh:
	if _disk != null:
		return _disk
	var rs := [0.0, 0.4, 0.6, 0.72, 0.82, 0.9, 0.95, 1.0]
	var segs := 48
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in rs.size():
		var r: float = rs[j]
		for i in segs + 1:
			var a := float(i) / float(segs) * TAU
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			cols.append(Color(r, 0.0, 0.0, 1.0))
	for j in rs.size() - 1:
		for i in segs:
			var a := j * (segs + 1) + i
			var b := a + segs + 1
			idx.append_array(PackedInt32Array([a, b, a + 1, b, b + 1, a + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	_disk = ArrayMesh.new()
	_disk.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _disk
