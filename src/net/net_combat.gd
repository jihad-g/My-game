class_name NetCombat
extends RefCounted
## Milestone 19 "Together in Danger": real co-op combat.
##
## The host simulates every monster (AI, attacks, damage, loot). Guests see
## "puppet" copies that follow the host:
##   - s2c_enemy_spawn: a monster came into a guest's range (scene, data,
##     strength, elite affixes) -> the guest builds a puppet of it;
##   - s2c_enemy_states (10/s, unreliable): position, facing, health, flags;
##   - s2c_enemy_event: animation events (attack swings, telegraphs, flinches,
##     knock-downs...) replayed on the puppet's model;
##   - s2c_enemy_gone: out of range or despawned -> the puppet is removed;
##   - s2c_fx: monster bolts and ground warnings drawn on the guest's screen
##     (visual only - the host already decides who they hit);
##   - s2c_hurt: a monster hit this guest; the guest's own game applies it, so
##     blocking, parrying and dodging work exactly as in single player.
## Guests attack puppets locally (instant feedback) and send c2s_hit; the host
## checks range, rate and size, then applies the hit to the real monster with
## the guest's puppet as the source (so the monster turns on that guest).
## Kills are shared: everyone within KILL_SHARE metres gets the XP and quest
## credit. Support abilities (heals, war cries, cleanses) reach friends nearby
## through c2s_support / s2c_support.

## Monsters are sent to a guest within this distance (m).
const RANGE := 90.0
## Monster state updates per second.
const RATE := 10.0
## A guest's hit counts on monsters this close to them (spells and arrows reach far).
const HIT_RANGE := 45.0
## Largest single hit the host accepts from a guest.
const MAX_HIT := 5000.0
## Hits a guest may send per second (multi-hit spells included).
const HITS_PER_SEC := 40
## Players this close to a kill share its XP and quest credit.
const KILL_SHARE := 45.0
## Support abilities reach friends this close to the caster (m).
const SUPPORT_RANGE := 12.0
## Damage types a guest's hit may carry.
const DAMAGE_TYPES := [&"physical", &"fire", &"frost", &"lightning", &"arcane", &"holy", &"poison", &"shadow", &"true"]
## Model methods replayed on puppets (anything else from the host is ignored).
const MODEL_EVENTS := [&"play_attack", &"set_telegraph", &"show_alert", &"play_flinch", &"freeze", &"set_exposed", &"play_bite", &"hit_frame"]
## Enemy methods a guest may ask the host to call on a monster.
const ENEMY_CALLS := [&"apply_status", &"knock_down", &"stagger", &"on_parried", &"taunt", &"lose_target"]
## State flags.
const F_DEAD := 1
const F_EXPOSED := 2
const F_DOWN := 4

var net: Node

# --- Host side ---
var _next_id := 1
var _enemies: Dictionary = {}  # net id -> Enemy
var _known: Dictionary = {}  # peer id -> {net id: true}
var _t := 0.0
var _hits: Dictionary = {}  # peer id -> [second, count]
## Counters for tests and the debug overlay.
var stats := {"spawned": 0, "hits_ok": 0, "hits_rejected": 0, "hurts": 0, "support": 0, "events": 0}

# --- Guest side ---
## net id -> Enemy puppet
var puppets: Dictionary = {}


func _init(p_net: Node) -> void:
	net = p_net


static func world() -> World:
	return World.instance


static func host() -> NetCombat:
	return Net.server.combat if Net.server else null


static func guest() -> NetCombat:
	return Net.client.combat if Net.client else null


func shutdown() -> void:
	for id in puppets:
		if is_instance_valid(puppets[id]):
			puppets[id].queue_free()
	puppets.clear()
	_enemies.clear()
	_known.clear()


# ==============================================================================================
# Host
# ==============================================================================================

func server_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0 / RATE
	var w := world()
	if w == null:
		return
	_scan(w)
	for pid in Net.server.peers:
		var ps: NetServer.PeerState = Net.server.peers[pid]
		if ps.ready:
			_sync_peer(w, ps)


## Gives every active monster a network id and forgets the ones that are gone.
func _scan(w: World) -> void:
	for g in [&"enemies", &"pets"]:
		for n in w.get_tree().get_nodes_in_group(g):
			var e := n as Enemy
			if e == null or e.net_puppet or not _active(e):
				continue
			if e.net_id == 0:
				e.net_id = _next_id
				_next_id += 1
				stats.spawned += 1
				if e.model and e.model.has_signal(&"net_event") and not e.has_meta(&"net_hooked"):
					e.set_meta(&"net_hooked", true)
					e.model.connect(&"net_event", _on_model_event.bind(e))
			_enemies[e.net_id] = e
	for id in _enemies.keys():
		var e: Enemy = _enemies[id]
		if not is_instance_valid(e) or e.net_id != id or not _active(e):
			_enemies.erase(id)


static func _active(e: Enemy) -> bool:
	return e.is_inside_tree() and e.visible and e.process_mode != Node.PROCESS_MODE_DISABLED


func _sync_peer(w: World, ps: NetServer.PeerState) -> void:
	var known: Dictionary = _known.get(ps.id, {})
	var now := {}
	var spawns := []
	var states := []
	if ps.layer == w.layer and w.dungeon == null:
		for id in _enemies:
			var e: Enemy = _enemies[id]
			if e.global_position.distance_to(ps.pos) > RANGE:
				continue
			now[id] = true
			if not known.has(id):
				spawns.append(spawn_entry(e))
			states.append(state_entry(e))
	var gone := []
	for id in known:
		if not now.has(id):
			gone.append(id)
	_known[ps.id] = now
	if not gone.is_empty():
		net.s2c_enemy_gone.rpc_id(ps.id, gone)
	if not spawns.is_empty():
		net.s2c_enemy_spawn.rpc_id(ps.id, spawns)
	if not states.is_empty():
		net.s2c_enemy_states.rpc_id(ps.id, states)


## Everything a guest needs to build a puppet of `e`.
static func spawn_entry(e: Enemy) -> Array:
	var cfg := {}
	if e is Monster:
		var m := e as Monster
		var aff := PackedStringArray()
		for a in m.affixes:
			aff.append(String(a))
		cfg = {"p": m.power, "d": m.damage_mult, "l": m.level_bonus, "x": m.xp_mult, "a": aff, "boss": m.is_boss()}
	if e.is_tamed():
		cfg["pet"] = true
	return [e.net_id, e.scene_file_path, e.data.resource_path if e.data else "", cfg, e.global_position,
		e.model.rotation.y if e.model else 0.0, e.health.get_ratio(), e.is_dead]


static func state_entry(e: Enemy) -> Array:
	var flags := 0
	if e.is_dead:
		flags |= F_DEAD
	if e.exposed:
		flags |= F_EXPOSED
	if e.is_knocked_down():
		flags |= F_DOWN
	var p := e.global_position
	return [e.net_id, p.x, p.y, p.z, e.model.rotation.y if e.model else 0.0, e.health.get_ratio(), flags]


func _peers_knowing(id: int) -> Array:
	var out := []
	for pid in _known:
		if (_known[pid] as Dictionary).has(id):
			out.append(pid)
	return out


func _on_model_event(method: StringName, args: Array, e: Enemy) -> void:
	if not is_instance_valid(e) or e.net_id == 0:
		return
	enemy_event(e, method, args)


## Sends an animation event of a monster to the guests who see it.
func enemy_event(e: Enemy, method: StringName, args: Array) -> void:
	for pid in _peers_knowing(e.net_id):
		net.s2c_enemy_event.rpc_id(pid, e.net_id, String(method), args)
		stats.events += 1


## Static helper for game code: relays an event if we are a co-op host.
static func relay(e: Enemy, method: StringName, args: Array) -> void:
	var nc := host()
	if nc and e.net_id > 0 and not e.net_puppet:
		nc.enemy_event(e, method, args)


## Monster bolts and ground warnings near guests (visual only on their side).
static func relay_fx(kind: String, pos: Vector3, args: Array) -> void:
	var nc := host()
	if nc == null:
		return
	var w := world()
	for pid in Net.server.peers:
		var ps: NetServer.PeerState = Net.server.peers[pid]
		if ps.ready and w and ps.layer == w.layer and ps.pos.distance_to(pos) < RANGE:
			nc.net.s2c_fx.rpc_id(pid, kind, args)


## A monster hit a guest's puppet: the guest's game resolves it (block, parry, dodge).
func hurt_peer(peer_id: int, info: DamageInfo) -> float:
	var ps: NetServer.PeerState = Net.server.peers.get(peer_id)
	if ps == null or not ps.ready:
		return 0.0
	var st := []
	for s in info.status_effects:
		if s is Array and s.size() >= 2:
			st.append([String(s[0]), float(s[1]), s[2] if s.size() > 2 and s[2] is Dictionary else {}])
	var src: int = info.source.net_id if info.source is Enemy else 0
	net.s2c_hurt.rpc_id(peer_id, [info.amount, String(info.damage_type), info.direction, info.knockback,
		info.poise_damage, st, src, info.tag, info.is_crit])
	stats.hurts += 1
	return info.amount


## A guest hit a monster. Returns true when the host accepted it.
func on_hit(peer_id: int, id: int, a: Array) -> bool:
	var ps: NetServer.PeerState = Net.server.peers.get(peer_id)
	var e: Enemy = _enemies.get(id)
	if ps == null or not ps.ready or e == null or not is_instance_valid(e) or e.is_dead or a.size() < 8:
		stats.hits_rejected += 1
		return false
	if e.global_position.distance_to(ps.pos) > HIT_RANGE or not _rate_ok(peer_id):
		stats.hits_rejected += 1
		return false
	var amount := clampf(float(a[0]), 0.0, MAX_HIT)
	var type := StringName(String(a[1]))
	if not type in DAMAGE_TYPES:
		type = &"physical"
	var info := DamageInfo.create(amount, ps.puppet, type)
	info.direction = _vec(a[2]).normalized()
	info.knockback = _vec(a[3]).limit_length(40.0)
	info.poise_damage = clampf(float(a[4]), 0.0, 400.0)
	info.is_crit = bool(a[5])
	info.tag = String(a[6]).substr(0, 24)
	info.status_effects = sanitize_statuses(a[7])
	info.hit_position = e.global_position + Vector3(0, 1.4, 0)
	e.receive_hit(info)
	stats.hits_ok += 1
	return true


## A guest asks for a whitelisted call on a monster (status, knock-down, parry...).
func on_call(peer_id: int, id: int, method: String, a: Array) -> bool:
	var ps: NetServer.PeerState = Net.server.peers.get(peer_id)
	var e: Enemy = _enemies.get(id)
	var m := StringName(method)
	if ps == null or not ps.ready or e == null or not is_instance_valid(e) or e.is_dead or not m in ENEMY_CALLS:
		return false
	if e.global_position.distance_to(ps.pos) > HIT_RANGE or not _rate_ok(peer_id):
		return false
	match m:
		&"apply_status":
			var st := sanitize_statuses([a])
			if not st.is_empty():
				e.apply_status(st[0][0], st[0][1], st[0][2])
		&"knock_down":
			e.knock_down(clampf(float(a[0]) if a.size() > 0 else 1.0, 0.1, 4.0))
		&"stagger":
			e.stagger(clampf(float(a[0]) if a.size() > 0 else 0.5, 0.05, 4.0))
		&"on_parried":
			e.on_parried()
		&"taunt":
			if is_instance_valid(ps.puppet):
				e.taunt(ps.puppet, clampf(float(a[0]) if a.size() > 0 else 3.0, 0.5, 10.0))
		&"lose_target":
			# Smoke, blindness, vanish: the monster loses this guest for a moment.
			if is_instance_valid(ps.puppet):
				e.set_meta(&"blind_until", Time.get_ticks_msec() + 3000)
				e.lose_target(ps.puppet)
	return true


func _rate_ok(peer_id: int) -> bool:
	var sec := Time.get_ticks_msec() / 1000
	var h: Array = _hits.get(peer_id, [sec, 0])
	if int(h[0]) != sec:
		h = [sec, 0]
	h[1] = int(h[1]) + 1
	_hits[peer_id] = h
	return int(h[1]) <= HITS_PER_SEC


## Status list from the network: [[id, seconds, {numbers}], ...], at most 4.
static func sanitize_statuses(v: Variant) -> Array:
	var out := []
	if not v is Array:
		return out
	for s in (v as Array).slice(0, 4):
		if not s is Array or (s as Array).size() < 2:
			continue
		var id := StringName(String(s[0]).substr(0, 24))
		if not StatusEffects.INFO.has(id):
			continue
		var params := {}
		if (s as Array).size() > 2 and s[2] is Dictionary:
			for k in (s[2] as Dictionary).keys().slice(0, 6):
				var val = s[2][k]
				if val is float or val is int:
					params[String(k).substr(0, 16)] = clampf(float(val), -1000.0, 1000.0)
		out.append([id, clampf(float(s[1]), 0.0, 30.0), params])
	return out


static func _vec(v: Variant) -> Vector3:
	return v if v is Vector3 and (v as Vector3).is_finite() else Vector3.ZERO


## A guest's support ability (heal, war cry...): passed on to the players
## near the caster, the host included.
func on_support(peer_id: int, kind: String, a: Array) -> void:
	var ps: NetServer.PeerState = Net.server.peers.get(peer_id)
	if ps == null or not ps.ready or not kind in PlayerAbilities.SUPPORT_KINDS or a.size() > 4:
		return
	stats.support += 1
	deliver_support(ps.pos, ps.layer, ps.name, kind, a, peer_id)


## Sends a support effect from `pos` to everyone in range except `from_peer`.
func deliver_support(pos: Vector3, layer: int, from_name: String, kind: String, a: Array, from_peer: int) -> void:
	var w := world()
	if from_peer != 1 and w and w.player and not Net.dedicated and w.layer == layer \
			and w.player.global_position.distance_to(pos) <= SUPPORT_RANGE:
		w.player.abilities.receive_support(kind, a, from_name)
	for pid in Net.server.peers:
		var ps: NetServer.PeerState = Net.server.peers[pid]
		if pid != from_peer and ps.ready and ps.layer == layer and ps.pos.distance_to(pos) <= SUPPORT_RANGE:
			net.s2c_support.rpc_id(pid, from_name, kind, a)


# ==============================================================================================
# Guest
# ==============================================================================================

func on_spawn(list: Array) -> void:
	var w := world()
	if w == null:
		return
	for entry in list:
		if not entry is Array or (entry as Array).size() < 8:
			continue
		var id := int(entry[0])
		if puppets.has(id) and is_instance_valid(puppets[id]):
			continue
		var e := _make_puppet(w, String(entry[1]), String(entry[2]), entry[3] if entry[3] is Dictionary else {})
		if e == null:
			continue
		e.net_id = id
		puppets[id] = e
		e.global_position = _vec(entry[4])
		e.net_target(_vec(entry[4]), float(entry[5]), float(entry[6]), F_DEAD if bool(entry[7]) else 0, true)


static func _make_puppet(w: World, scene_path: String, data_path: String, cfg: Dictionary) -> Enemy:
	if not scene_path.begins_with("res://scenes/") or not ResourceLoader.exists(scene_path):
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	var e := scene.instantiate() as Enemy
	if e == null:
		return null
	if data_path != "" and data_path.begins_with("res://data/") and ResourceLoader.exists(data_path):
		var d := load(data_path) as EnemyData
		if d:
			e.data = d
	e.net_puppet = true
	w.add_child(e)
	e.spawn_at(Vector3.ZERO, "")
	if e is Monster and not cfg.is_empty():
		var m := e as Monster
		var aff := []
		for a in (cfg.get("a", []) as Array).slice(0, 4):
			if EliteAffixes.AFFIXES.has(StringName(String(a))):
				aff.append(StringName(String(a)))
		m.configure(1.0, 1.0, 0, 1.0)
		m.make_elite(aff)
		# The host's final numbers (they already include the elite bonus).
		m.power = clampf(float(cfg.get("p", 1.0)), 0.1, 100.0)
		m.damage_mult = clampf(float(cfg.get("d", 1.0)), 0.1, 100.0)
		m.level_bonus = clampi(int(cfg.get("l", 0)), 0, 200)
		m.xp_mult = clampf(float(cfg.get("x", 1.0)), 0.0, 100.0)
		m.health.max_health = m.data.max_health * m.power
	return e


func on_states(list: Array) -> void:
	for s in list:
		if not s is Array or (s as Array).size() < 7:
			continue
		var e: Enemy = puppets.get(int(s[0]))
		if e and is_instance_valid(e):
			e.net_target(Vector3(float(s[1]), float(s[2]), float(s[3])), float(s[4]), float(s[5]), int(s[6]))


func on_gone(ids: Array) -> void:
	for id in ids:
		var e: Enemy = puppets.get(int(id))
		puppets.erase(int(id))
		if e and is_instance_valid(e):
			e.net_remove()


func on_event(id: int, method: String, a: Array) -> void:
	var e: Enemy = puppets.get(id)
	if e == null or not is_instance_valid(e) or a.size() > 6:
		return
	var m := StringName(method)
	if m == &"knock_down":
		e.net_knock_down(clampf(float(a[0]) if a.size() > 0 else 1.0, 0.1, 4.0))
	elif m == &"ice_shell":
		e._set_ice_shell(a.size() > 0 and bool(a[0]))
	elif m in MODEL_EVENTS and e.model and e.model.has_method(m):
		e.model.callv(m, a)


func on_fx(kind: String, a: Array) -> void:
	var w := world()
	if w == null:
		return
	match kind:
		"bolt":
			if a.size() >= 4:
				var p := Projectile.new()
				p.velocity = _vec(a[1]).limit_length(80.0)
				p.color = a[2] if a[2] is Color else Color.WHITE
				p.lifetime = clampf(float(a[3]), 0.1, 4.0)
				p.mask = Layers.TERRAIN | Layers.BUILDING
				w.add_child(p)
				p.global_position = _vec(a[0])
		"hazard":
			if a.size() >= 5:
				var h := GroundHazard.new()
				h.radius = clampf(float(a[1]), 0.5, 20.0)
				h.delay = clampf(float(a[2]), 0.0, 5.0)
				h.color = a[3] if a[3] is Color else Color(1, 0.3, 0.15)
				h.style = StringName(String(a[4]).substr(0, 12))
				h.damage = 0.0
				h.hurts_player = false
				h.visual_only = true
				h.linger = clampf(float(a[5]), 0.0, 20.0) if a.size() > 5 else 0.0
				w.add_child(h)
				h.global_position = _vec(a[0])


## A monster on the host hit us.
func on_hurt(a: Array) -> void:
	var w := world()
	if w == null or w.player == null or a.size() < 9:
		return
	var src: Enemy = puppets.get(int(a[6]))
	var type := StringName(String(a[1]))
	if not type in DAMAGE_TYPES:
		type = &"physical"
	var info := DamageInfo.create(clampf(float(a[0]), 0.0, 100000.0), src if src and is_instance_valid(src) else null, type)
	info.direction = _vec(a[2])
	info.knockback = _vec(a[3]).limit_length(40.0)
	info.poise_damage = clampf(float(a[4]), 0.0, 1000.0)
	info.status_effects = sanitize_statuses(a[5])
	info.tag = String(a[7]).substr(0, 24)
	info.is_crit = bool(a[8])
	w.player.receive_hit(info)


## Our hit on a puppet goes to the host.
func send_hit(e: Enemy, info: DamageInfo) -> void:
	net.c2s_hit.rpc_id(1, e.net_id, [info.amount, String(info.damage_type), info.direction, info.knockback,
		info.poise_damage, info.is_crit, info.tag, sanitize_statuses(info.status_effects)])


func send_call(e: Enemy, method: StringName, a: Array) -> void:
	# Only plain values travel (status params may hold the caster node).
	var safe := []
	for v in a:
		if v is Dictionary:
			var d := {}
			for k in v:
				if v[k] is float or v[k] is int:
					d[String(k)] = v[k]
			safe.append(d)
		elif v is float or v is int or v is String or v is bool or v is StringName:
			safe.append(String(v) if v is StringName else v)
	net.c2s_enemy_call.rpc_id(1, e.net_id, String(method), safe)


## The host (or another guest) helped us.
func on_support_received(from_name: String, kind: String, a: Array) -> void:
	var w := world()
	if w and w.player and kind in PlayerAbilities.SUPPORT_KINDS and a.size() <= 4:
		w.player.abilities.receive_support(kind, a, from_name.substr(0, 16))
