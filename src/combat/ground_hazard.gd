class_name GroundHazard
extends Node3D
## A telegraphed area attack (Milestone 7): a danger circle fills up for
## `delay` seconds, then everything inside `radius` is hit once. Used by boss
## spikes and meteor rain, falling rocks, bandit bombs, elite death explosions
## and event meteors. Optionally lingers as a damaging pool (`linger` seconds,
## hitting every `linger_tick`).
##
## Who it can hurt: the player always (unless `hurts_player` is false), enemies
## when `hurts_enemies` (player spells), NPCs and buildings when `hurts_town`
## (raiders).

var radius := 2.0
var delay := 1.0
var damage := 20.0
var damage_type: StringName = &"physical"
## Optional status on hit: [id, duration, params]
var status_effect: Array = []
var source: Node = null
var color := Color(1, 0.3, 0.15)
var knockback := 5.0
var poise_damage := 25.0
var tag := ""
var hurts_player := true
var hurts_enemies := false
var hurts_town := false
## Damage multiplier against building pieces.
var building_mult := 1.0
## After the blast, stay as a pool for this many seconds (0 = one blast).
var linger := 0.0
var linger_tick := 1.0
## Fraction of `damage` dealt by each linger tick.
var linger_mult := 0.35
## Called with the position when the hazard blasts (meteors ignite poison clouds).
var on_blast: Callable
## Visual style of the blast: &"blast" (ring + burst), &"spikes", &"meteor".
var style: StringName = &"blast"

var _t := 0.0
var _fired := false
var _tick := 0.0
var _zone: Node3D
var _pool: MeshInstance3D


## Convenience constructor: adds the hazard to `parent` at `pos`.
static func spawn(parent: Node, pos: Vector3, p_radius: float, p_delay: float, p_damage: float,
		p_type: StringName = &"physical", p_source: Node = null) -> GroundHazard:
	var h := GroundHazard.new()
	h.radius = p_radius
	h.delay = p_delay
	h.damage = p_damage
	h.damage_type = p_type
	h.source = p_source
	h.position = pos
	h.color = {&"fire": Color(1, 0.45, 0.1), &"frost": Color(0.5, 0.85, 1.0), &"poison": Color(0.45, 0.85, 0.25),
		&"arcane": Color(0.75, 0.45, 1.0), &"lightning": Color(0.8, 0.85, 1.0)}.get(p_type, Color(1, 0.25, 0.15))
	parent.add_child(h)
	h.global_position = pos
	return h


var _setup := false


## Visuals and groups are set up on the first physics frame: callers configure
## the hazard (flags, linger, position) right after GroundHazard.spawn().
func _first_frame() -> void:
	_setup = true
	if damage_type == &"poison" and hurts_enemies and linger > 0.0:
		add_to_group(&"poison_clouds")
	if not hurts_player and hurts_enemies:
		# Player spells: friendly blue-ish edge instead of the red warning.
		_zone = Node3D.new()
		add_child(_zone)
		VFX.ring(self, global_position, radius, Color(color.r, color.g, color.b, 0.6), maxf(delay, 0.2))
	else:
		_zone = VFX.danger_zone(self, global_position, radius, delay)
	if style == &"meteor":
		_spawn_falling_rock()


func _physics_process(delta: float) -> void:
	if not _setup:
		_first_frame()
	_t += delta
	if not _fired:
		if _t >= delay:
			_fired = true
			_blast()
			if linger <= 0.0:
				queue_free()
			else:
				_make_pool()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = linger_tick
		_hit_all(linger_mult)
		if style == &"storm":
			VFX.burst(get_parent(), global_position + Vector3(randf_range(-radius, radius) * 0.6, 0.8, randf_range(-radius, radius) * 0.6), 1.0, Color(color.r, color.g, color.b, 0.6), 0.3)
	if _t >= delay + linger:
		queue_free()


func _blast() -> void:
	var parent := get_parent()
	match style:
		&"spikes":
			var b := BlockMesh.new()
			for k in 7:
				var a := TAU * k / 7.0
				var r := radius * (0.3 if k == 0 else 0.7)
				var off := Vector3(cos(a) * r, 0, sin(a) * r) if k > 0 else Vector3.ZERO
				b.box(off + Vector3(0, 0.5, 0), Vector3(0.22, 1.0 + (k % 3) * 0.3, 0.22), color.lerp(Color(0.9, 0.88, 0.8), 0.5))
			var mi := MeshInstance3D.new()
			mi.mesh = b.commit()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			mi.global_position = global_position + Vector3(0, -1.2, 0)
			var tw := mi.create_tween()
			tw.tween_property(mi, "global_position:y", global_position.y, 0.08)
			tw.tween_interval(0.5)
			tw.tween_property(mi, "global_position:y", global_position.y - 1.4, 0.3)
			tw.tween_callback(mi.queue_free)
		_:
			VFX.ring(parent, global_position, radius, Color(color.r, color.g, color.b, 0.85), 0.3)
			VFX.burst(parent, global_position + Vector3(0, 0.6, 0), radius * 0.8, Color(color.r, color.g, color.b, 0.7), 0.3)
	if radius >= 2.5:
		Events.camera_shake.emit(0.25)
	_hit_all(1.0)
	if on_blast.is_valid():
		on_blast.call(global_position)


func _spawn_falling_rock() -> void:
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, Vector3(0.7, 0.7, 0.7), color)
	b.box(Vector3(0, 0, 0), Vector3(0.5, 0.9, 0.5), color.lightened(0.3))
	var m := b.commit()
	m.surface_set_material(0, Materials.vertex_color_emissive())
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(-6, 18, -3)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", Vector3(0, 0.3, 0), delay).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


func _make_pool() -> void:
	_pool = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.radial_segments = 20
	_pool.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool.material_override = mat
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.position.y = 0.06
	add_child(_pool)
	_tick = linger_tick


## Hits every valid target in the circle once, with `mult` of the damage.
func _hit_all(mult: float) -> void:
	var c := global_position
	for t in targets_in_radius(get_tree(), c, radius, hurts_player, hurts_enemies, hurts_town):
		if t == source:
			continue
		var info := DamageInfo.create(damage * mult * (building_mult if t is BuildPiece else 1.0),
			source if is_instance_valid(source) else null, damage_type)
		var dir: Vector3 = (t as Node3D).global_position - c
		dir.y = 0.0
		info.direction = dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
		info.knockback = info.direction * knockback * mult
		info.poise_damage = poise_damage * mult
		info.hit_position = (t as Node3D).global_position + Vector3(0, 1.0, 0)
		info.tag = tag
		if not status_effect.is_empty():
			info.status_effects = [status_effect]
		t.receive_hit(info)


## Combustion: a fire blast ignites poison clouds it touches (player spells).
func ignite(pos: Vector3, blast_radius: float, power: float) -> bool:
	if not is_in_group(&"poison_clouds") or _t < delay:
		return false
	if Vector2(pos.x - global_position.x, pos.z - global_position.z).length() > radius + blast_radius:
		return false
	var h := GroundHazard.spawn(get_parent(), global_position, radius + 1.5, 0.05, power, &"fire", source)
	h.hurts_player = false
	h.hurts_enemies = true
	h.tag = "Combustion!"
	h.status_effect = [&"burn", 4.0, {"dps": power * 0.1, "source": source}]
	Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Combustion!")
	queue_free()
	return true


## Everything damageable inside a flat circle. Shared with boss AoE moves.
static func targets_in_radius(tree: SceneTree, c: Vector3, r: float, player: bool, enemies: bool, town: bool) -> Array:
	var out := []
	var r2 := r * r
	var groups: Array[StringName] = []
	if player:
		groups.append(&"player")
	if enemies:
		groups.append(&"enemies")
		groups.append(&"ward_pylons")
	if town:
		groups.append(&"npcs")
	for g in groups:
		for n in tree.get_nodes_in_group(g):
			var n3 := n as Node3D
			if n3 == null or not n3.is_visible_in_tree() or n3.get("is_dead") == true or not n3.has_method("receive_hit"):
				continue
			if n3.has_method("can_be_attacked") and not n3.can_be_attacked():
				continue
			var d := Vector2(n3.global_position.x - c.x, n3.global_position.z - c.z)
			if d.length_squared() <= r2 and absf(n3.global_position.y - c.y) < 4.0:
				out.append(n3)
	if town and World.instance and World.instance.building:
		for piece in World.instance.building.pieces_near(c, r):
			out.append(piece)
	return out
