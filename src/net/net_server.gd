class_name NetServer
extends RefCounted
## Authoritative side of a multiplayer session (Milestone 11).
##
## Keeps one PeerState per connected guest: name, class, level, position
## (from its state packets, speed-checked), an authoritative Inventory and
## Equipment, and its puppet in the host's world. Every guest request is
## validated here against this state and the host's world, then applied and
## broadcast. The host's own actions go through the normal single-player code
## and are broadcast from hooks (Chunk.harvest_prop, BuildingManager.place/
## remove/destroy, World.spawn_pickup, Pickup.collect...).

class PeerState:
	var id := 0
	var name := ""
	var class_id: StringName = &"knight"
	var level := 1
	var ready := false
	var inventory := Inventory.new(32)
	var equipment := Equipment.new()
	var pos := Vector3.ZERO
	var layer := 0
	var last_state := {}
	var last_time := 0.0
	var puppet: RemotePlayer
	## Last "look" event (weapon + outfit), replayed to players who join later.
	var look: Array = []
	var profile := {}
	var regions_sent := {}
	var dirty_inventory := false

	func record() -> Dictionary:
		return {"class": String(class_id), "inventory": inventory.to_array(), "equipment": equipment.to_save(),
			"position": [pos.x, pos.y, pos.z], "layer": layer, "profile": profile}


var net: Node
var peers: Dictionary = {}  # peer id -> PeerState
var _pickups: Dictionary = {}  # net id -> Pickup
var _next_pickup := 1
var _state_t := 0.0
var _time_t := 0.0
var _props_cache: Dictionary = {}  # Vector3i(cx, cz, layer) -> Array of prop dicts
var _props_order: Array = []
var _rng := RandomNumberGenerator.new()


func _init(p_net: Node) -> void:
	net = p_net
	_rng.randomize()


func world() -> World:
	return World.instance


func shutdown() -> void:
	for id in peers.keys():
		_drop_peer(id)
	peers.clear()


# --- Connections -----------------------------------------------------------------------

func on_peer_connected(_id: int) -> void:
	pass  # wait for c2s_hello


func on_peer_disconnected(id: int) -> void:
	if peers.has(id):
		var ps: PeerState = peers[id]
		_save_record(ps)
		_drop_peer(id)
		for other in peers:
			if peers[other].ready:
				net.s2c_player_left.rpc_id(other, id)
		Events.toast.emit("%s left the game" % ps.name, Color(0.8, 0.85, 1.0))
	net.players.erase(id)
	net.players_changed.emit()


func _drop_peer(id: int) -> void:
	var ps: PeerState = peers.get(id)
	if ps and is_instance_valid(ps.puppet):
		ps.puppet.queue_free()
	peers.erase(id)


func _save_record(ps: PeerState) -> void:
	net.player_records[ps.name] = ps.record()


func kick(id: int, reason: String) -> void:
	net.s2c_reject.rpc_id(id, reason)
	net.stats.rejected += 1
	# Give the message a moment to leave before closing the connection.
	var tree := net.get_tree()
	tree.create_timer(0.3).timeout.connect(func() -> void:
		if net.multiplayer.multiplayer_peer and net.is_server():
			(net.multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))


func on_hello(id: int, info: Dictionary) -> void:
	if peers.has(id):
		return
	var w := world()
	if int(info.get("version", -1)) != NetProtocol.VERSION:
		kick(id, "Different game version (server protocol %d, yours %s)" % [NetProtocol.VERSION, str(info.get("version", "?"))])
		return
	if w == null or not w.is_ready:
		kick(id, "The server is still loading its world, try again in a moment")
		return
	if peers.size() + 1 >= NetProtocol.MAX_PLAYERS:
		kick(id, "The server is full")
		return
	var name := NetProtocol.clean_name(String(info.get("name", "Player")))
	var taken := [net.player_name] if not net.dedicated else []
	for p in peers.values():
		taken.append(p.name)
	var base := name
	var n := 2
	while name in taken:
		name = "%s %d" % [base.substr(0, 13), n]
		n += 1
	var ps := PeerState.new()
	ps.id = id
	ps.name = name
	var cls := StringName(String(info.get("class", "knight")))
	ps.class_id = cls if ClassRegistry.get_class_data(cls) else ClassRegistry.DEFAULT_CLASS
	var rec: Dictionary = net.player_records.get(name, {})
	var fresh := rec.is_empty()
	if fresh:
		_starting_kit(ps)
		ps.pos = _spawn_near_host()
		ps.layer = 0
	else:
		ps.class_id = StringName(String(rec.get("class", ps.class_id)))
		ps.inventory.from_array(rec.get("inventory", []))
		ps.equipment.from_save(rec.get("equipment", {}))
		var p: Array = rec.get("position", [0, 0, 0])
		ps.pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
		ps.layer = int(rec.get("layer", 0))
		ps.profile = rec.get("profile", {})
	ps.last_time = _now()
	ps.inventory.changed.connect(func() -> void: ps.dirty_inventory = true)
	peers[id] = ps
	net.players[id] = {"name": name, "class": String(ps.class_id)}
	net.s2c_welcome.rpc_id(id, _welcome(ps, fresh))
	net.stats.sent += 1


func _starting_kit(ps: PeerState) -> void:
	var c := ClassRegistry.get_class_data(ps.class_id)
	if c:
		for id in c.starting_equipment:
			var item: ItemData = ItemDB.get_item(StringName(id))
			if item:
				ps.equipment.equip(item)
		for id in c.starting_items:
			ps.inventory.add_item(StringName(id), int(c.starting_items[id]))
	var w := world()
	if w:
		for id in w.starting_items:
			ps.inventory.add_item(id, int(w.starting_items[id]))


func _spawn_near_host() -> Vector3:
	var w := world()
	var base := w.player.global_position if w and w.player else Vector3.ZERO
	if w and w.layer != TerrainGenerator.Layer.SURFACE:
		base = w.player.spawn_point
	var a := _rng.randf() * TAU
	var p := base + Vector3(cos(a) * 3.0, 0, sin(a) * 3.0)
	p.y = w.generator.get_height_at(p) + 0.4 if w else 0.0
	return p


func _welcome(ps: PeerState, fresh: bool) -> Dictionary:
	var w := world()
	var players := {}
	for pid in net.players:
		if pid != ps.id:
			players[pid] = net.players[pid]
	var regions := []
	for key in _regions_around(ps.pos, ps.layer):
		regions.append(_region_payload(key))
		ps.regions_sent[key] = true
	var pickups := []
	for nid in _pickups:
		var pk: Pickup = _pickups[nid]
		if is_instance_valid(pk) and pk.is_inside_tree():
			pickups.append([nid, String(pk.item_id), pk.count, pk.global_position])
	var placed: Array = w.to_save().get("placed", [])
	return {
		"version": NetProtocol.VERSION, "seed": str(GameState.world_seed), "checksum": NetProtocol.world_checksum(w.generator),
		"world_time": GameState.world_time, "day": w.day_night.day, "hour": w.day_night.hour,
		"peer_id": ps.id, "name": ps.name, "class": String(ps.class_id), "fresh": fresh,
		"position": ps.pos, "layer": ps.layer, "inventory": ps.inventory.to_array(), "equipment": ps.equipment.to_save(),
		"profile": ps.profile, "buildings": _buildings_payload(), "regions": regions, "pickups": pickups, "placed": placed,
		"players": players, "host_name": net.player_name if not net.dedicated else "",
	}


func _buildings_payload() -> Array:
	var out := []
	var w := world()
	for k in w.building.pieces:
		out.append(piece_entry(w.building.pieces[k]))
	return out


static func piece_entry(p: BuildPiece) -> Dictionary:
	return {"id": String(p.data.id), "x": p.cell.x, "z": p.cell.y, "slot": p.slot, "rot": p.rot, "layer": p.layer,
		"data": p.save_data(), "owner": String(p.get_meta(&"owner", ""))}


func on_ready(id: int) -> void:
	var ps: PeerState = peers.get(id)
	if ps == null or ps.ready:
		return
	ps.ready = true
	var w := world()
	ps.puppet = RemotePlayer.new()
	ps.puppet.setup(id, ps.name, ps.class_id)
	w.add_child(ps.puppet)
	ps.puppet.snap_to(ps.pos, 0.0, ps.layer)
	for other in peers:
		if other != id and peers[other].ready:
			net.s2c_player_joined.rpc_id(other, id, net.players[id])
	net.players_changed.emit()
	Events.toast.emit("%s joined the game" % ps.name, Color(0.6, 1.0, 0.7))
	# Show the newcomer what everyone already wears (Milestone 14).
	if w.player:
		net.s2c_anim.rpc_id(id, 1, "look", w.player.equipment.look_args())
	for other in peers:
		if other != id and peers[other].ready and not peers[other].look.is_empty():
			net.s2c_anim.rpc_id(id, other, "look", peers[other].look)
	_send_inventory(ps)


func on_profile(id: int, profile: Dictionary) -> void:
	var ps: PeerState = peers.get(id)
	if ps == null:
		return
	# Character progression is client-reported (M11); keep it bounded.
	if var_to_bytes(profile).size() > 256 * 1024:
		return
	ps.profile = profile
	ps.level = clampi(int((profile.get("character", {}) as Dictionary).get("level", ps.level)), 1, 200)
	_save_record(ps)


# --- Ticking ---------------------------------------------------------------------------------

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func process(delta: float) -> void:
	var w := world()
	if w == null:
		return
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 1.0 / NetProtocol.STATE_RATE
		_broadcast_states()
	_time_t -= delta
	if _time_t <= 0.0:
		_time_t = 2.0
		for id in peers:
			if peers[id].ready:
				net.s2c_time.rpc_id(id, GameState.world_time, w.day_night.day, w.day_night.hour)
	for id in peers:
		var ps: PeerState = peers[id]
		if ps.dirty_inventory and ps.ready:
			_send_inventory(ps)
		elif ps.dirty_inventory:
			ps.dirty_inventory = false


func _broadcast_states() -> void:
	var w := world()
	var states := {}
	if not net.dedicated and w.player and w.is_ready:
		states[1] = local_state(w)
	for id in peers:
		var ps: PeerState = peers[id]
		if ps.ready and not ps.last_state.is_empty():
			states[id] = ps.last_state.raw
	if states.is_empty():
		return
	for id in peers:
		if peers[id].ready:
			net.s2c_states.rpc_id(id, states)


## This machine's player as a state packet.
static func local_state(w: World) -> Array:
	var p := w.player
	var flags := 0
	if p.is_blocking:
		flags |= NetProtocol.F_BLOCKING
	if p.is_swimming:
		flags |= NetProtocol.F_SWIMMING
	if not p.is_on_floor() and not p.is_swimming:
		flags |= NetProtocol.F_AIRBORNE
	if p.is_dead:
		flags |= NetProtocol.F_DEAD
	return NetProtocol.encode_state(p.global_position, p.model.rotation.y, p.velocity, p.model._move_amount, flags,
		w.layer, p.health.get_ratio())


func on_state(id: int, raw: Array) -> void:
	var ps: PeerState = peers.get(id)
	if ps == null or not ps.ready:
		return
	var s := NetProtocol.decode_state(raw)
	if s.is_empty():
		return
	var now := _now()
	var dt := maxf(now - ps.last_time, 0.05)
	var flat := Vector2(s.pos.x - ps.pos.x, s.pos.z - ps.pos.z).length()
	var teleport: bool = s.flags & NetProtocol.F_TELEPORT != 0
	if not teleport and s.layer == ps.layer and flat > NetProtocol.MAX_SPEED * dt + 2.0:
		# Too fast: put them back where they were.
		net.stats.corrections += 1
		net.s2c_correct.rpc_id(id, ps.pos, ps.layer)
		ps.last_time = now
		return
	var clamped := TerrainGenerator.clamp_to_world(s.pos)
	s.pos = clamped
	raw[0] = clamped.x
	raw[2] = clamped.z
	s.raw = raw
	ps.pos = s.pos
	ps.layer = s.layer
	ps.last_state = s
	ps.last_time = now
	if is_instance_valid(ps.puppet):
		ps.puppet.push_state(s)
	_maybe_send_regions(ps)


func on_anim(id: int, ev: String, args: Array) -> void:
	var ps: PeerState = peers.get(id)
	if ps == null or not ps.ready or not ev in RemotePlayer.ANIM_EVENTS or args.size() > 4:
		return
	if ev == "look":
		ps.look = args.duplicate()
	if is_instance_valid(ps.puppet):
		ps.puppet.play_event(ev, args)
	for other in peers:
		if other != id and peers[other].ready:
			net.s2c_anim.rpc_id(other, id, ev, args)


## The host's own animation events go to everyone.
func broadcast_local_anim(ev: String, args: Array) -> void:
	for id in peers:
		if peers[id].ready:
			net.s2c_anim.rpc_id(id, 1, ev, args)


func on_chat(id: int, text: String) -> void:
	var ps: PeerState = peers.get(id)
	if ps:
		broadcast_chat(ps.name, text.strip_edges().substr(0, 200))


func broadcast_chat(from: String, text: String) -> void:
	if text == "":
		return
	net.chat_received.emit(from, text)
	for id in peers:
		if peers[id].ready:
			net.s2c_chat.rpc_id(id, from, text)


# --- World changes -------------------------------------------------------------------------

func _regions_around(pos: Vector3, layer: int) -> Array:
	var c := RegionStore.region_of(TerrainGenerator.world_to_chunk(pos), layer)
	var out := []
	var r := NetProtocol.REGION_RADIUS
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out.append(Vector3i(c.x + dx, c.y + dz, layer))
	return out


func _region_payload(key: Vector3i) -> Array:
	var d := GameState.regions.export_region(key)
	return [key, d.props, d.deaths]


func _maybe_send_regions(ps: PeerState) -> void:
	for key in _regions_around(ps.pos, ps.layer):
		if not ps.regions_sent.has(key):
			ps.regions_sent[key] = true
			var p := _region_payload(key)
			net.s2c_region.rpc_id(ps.id, p[0], p[1], p[2])


func on_regions_request(id: int, keys: Array) -> void:
	var ps: PeerState = peers.get(id)
	if ps == null:
		return
	for k in keys.slice(0, 16):
		if k is Vector3i:
			ps.regions_sent[k] = true
			var p := _region_payload(k)
			net.s2c_region.rpc_id(id, p[0], p[1], p[2])


## A prop vanished on the server (host harvest or a guest's request).
func broadcast_prop_removed(coord: Vector2i, layer: int, index: int) -> void:
	for id in peers:
		if peers[id].ready:
			net.s2c_props_removed.rpc_id(id, [[coord, layer, index]])


func broadcast_build(op: String, entry: Dictionary) -> void:
	for id in peers:
		if peers[id].ready:
			net.s2c_build.rpc_id(id, op, entry)


## Called by World.spawn_pickup on the server.
func register_pickup(p: Pickup) -> void:
	if p.net_id == 0:
		p.net_id = _next_pickup
		_next_pickup += 1
	_pickups[p.net_id] = p
	for id in peers:
		if peers[id].ready:
			net.s2c_pickup.rpc_id(id, "add", p.net_id, String(p.item_id), p.count, p.global_position)


func pickup_gone(net_id: int) -> void:
	if not _pickups.has(net_id):
		return
	_pickups.erase(net_id)
	for id in peers:
		if peers[id].ready:
			net.s2c_pickup.rpc_id(id, "remove", net_id, "", 0, Vector3.ZERO)


func pickup_count_changed(p: Pickup) -> void:
	for id in peers:
		if peers[id].ready:
			net.s2c_pickup.rpc_id(id, "count", p.net_id, String(p.item_id), p.count, p.global_position)


func broadcast_placed(entry: Dictionary) -> void:
	for id in peers:
		if peers[id].ready:
			net.s2c_placed.rpc_id(id, entry)


# --- Requests ------------------------------------------------------------------------------

const ACTIONS := ["harvest", "pickup", "drop", "move", "use", "equip", "unequip", "craft", "place", "remove", "door", "place_object"]


func on_request(id: int, rid: int, action: String, args: Array) -> void:
	var ps: PeerState = peers.get(id)
	var res := {"ok": false, "msg": "Not connected", "extra": {}}
	if ps and ps.ready and action in ACTIONS and args.size() <= 8:
		res = call("_act_" + action, ps, args)
	if not res.ok:
		net.stats.rejected += 1
	net.s2c_reply.rpc_id(id, rid, bool(res.ok), String(res.msg), res.get("extra", {}))
	if ps and ps.dirty_inventory:
		_send_inventory(ps)


func _send_inventory(ps: PeerState) -> void:
	ps.dirty_inventory = false
	net.s2c_inventory.rpc_id(ps.id, ps.inventory.to_array(), ps.equipment.to_save())


static func _ok(msg: String = "", extra: Dictionary = {}) -> Dictionary:
	return {"ok": true, "msg": msg, "extra": extra}


static func _no(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg, "extra": {}}


## Gives items to a guest; whatever doesn't fit drops at their feet.
func give(ps: PeerState, item: StringName, count: int) -> void:
	var left := ps.inventory.add_item(item, count)
	if left > 0:
		world().spawn_pickup(item, left, ps.pos + Vector3(0, 1.0, 0), false)


func _best_tool(inv: Inventory, kind: StringName) -> int:
	var best := 0
	for s in inv.slots:
		if s != null:
			var item: ItemData = ItemDB.get_item(s.id)
			if item and item.tool_kind == kind:
				best = maxi(best, item.tool_tier)
	return best


## Generated props of a chunk (to check a guest's harvest), cached.
func _chunk_props(coord: Vector2i, layer: int) -> Array:
	var key := Vector3i(coord.x, coord.y, layer)
	if _props_cache.has(key):
		return _props_cache[key]
	var props := world().generator.generate_chunk(coord, 0, layer).props
	_props_cache[key] = props
	_props_order.append(key)
	if _props_order.size() > 96:
		_props_cache.erase(_props_order.pop_front())
	return props


func _act_harvest(ps: PeerState, a: Array) -> Dictionary:
	if a.size() < 4:
		return _no("Bad request")
	var coord = NetProtocol.vec2i_arg(a[0])
	if coord == null:
		return _no("Bad request")
	var layer := clampi(int(a[1]), 0, 1)
	var index := int(a[2])
	var gather := bool(a[3])
	var prop := {}
	for p: Dictionary in _chunk_props(coord, layer):
		if int(p.index) == index:
			prop = p
			break
	if prop.is_empty():
		return _no("There's nothing there")
	var w := world()
	var pdata := w.props.get_prop(prop.prop_id)
	if pdata == null:
		return _no("There's nothing there")
	if GameState.is_prop_removed(coord, index, pdata.regrow_time, layer):
		return _no("Already gone")
	var wpos: Vector3 = Vector3(coord.x * TerrainGenerator.CHUNK_SIZE, 0, coord.y * TerrainGenerator.CHUNK_SIZE) + prop.position
	if ps.layer != layer or Vector2(wpos.x - ps.pos.x, wpos.z - ps.pos.z).length() > NetProtocol.REACH:
		return _no("Too far away")
	var want := PropData.InteractMode.GATHER if gather else PropData.InteractMode.HARVEST
	if pdata.interact_mode != want:
		return _no("That can't be done here")
	if pdata.tool_kind != &"" and _best_tool(ps.inventory, pdata.tool_kind) < pdata.tool_tier:
		return _no("%s needs a tier %d %s" % [pdata.display_name, pdata.tool_tier, pdata.tool_kind])
	remove_prop(coord, layer, index)
	var got := {}
	for loot in pdata.drops:
		if loot is LootEntry:
			var n: int = loot.roll(_rng)
			if n > 0:
				give(ps, loot.item_id, n)
				got[String(loot.item_id)] = int(got.get(String(loot.item_id), 0)) + n
	var xp := pdata.xp if pdata.xp > 0 else (3 if pdata.interact_mode == PropData.InteractMode.HARVEST else 1)
	return _ok("", {"prop": String(pdata.id), "xp": xp, "items": got})


## Removes a prop everywhere: world state, the server's chunk, every guest.
func remove_prop(coord: Vector2i, layer: int, index: int) -> void:
	GameState.mark_prop_removed(coord, index, layer)
	var w := world()
	var chunk := w.chunk_manager.get_chunk(coord)
	if chunk and chunk.layer == layer:
		chunk.hide_prop(index)
	broadcast_prop_removed(coord, layer, index)


func _act_pickup(ps: PeerState, a: Array) -> Dictionary:
	var nid := int(a[0]) if a.size() > 0 else 0
	var p: Pickup = _pickups.get(nid)
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		pickup_gone(nid)
		return _no("Someone was faster")
	if p.global_position.distance_to(ps.pos + Vector3(0, 0.8, 0)) > NetProtocol.REACH:
		return _no("Too far away")
	var left := ps.inventory.add_item(p.item_id, p.count)
	var taken := p.count - left
	if taken <= 0:
		return _no("Inventory full")
	var item := String(p.item_id)
	if left <= 0:
		pickup_gone(nid)
		NodePool.release_or_free(p)
	else:
		p.count = left
		pickup_count_changed(p)
	return _ok("", {"item": item, "count": taken})


func _act_drop(ps: PeerState, a: Array) -> Dictionary:
	var i := NetProtocol.slot_arg(a[0] if a.size() > 0 else -1, ps.inventory.capacity)
	var s = ps.inventory.get_slot(i)
	if s == null:
		return _no("Nothing there")
	var n := clampi(int(a[1]) if a.size() > 1 else 1, 1, int(s.count))
	var id: StringName = s.id
	ps.inventory.remove_from_slot(i, n)
	var yaw := float(ps.last_state.get("yaw", 0.0))
	world().spawn_pickup(id, n, ps.pos + Vector3(sin(yaw), 1.0, cos(yaw)) * Vector3(1.2, 1, 1.2), false)
	return _ok()


func _act_move(ps: PeerState, a: Array) -> Dictionary:
	var f := NetProtocol.slot_arg(a[0] if a.size() > 0 else -1, ps.inventory.capacity)
	var t := NetProtocol.slot_arg(a[1] if a.size() > 1 else -1, ps.inventory.capacity)
	if f < 0 or t < 0:
		return _no("Bad slot")
	ps.inventory.move_slot(f, t)
	return _ok()


func _act_use(ps: PeerState, a: Array) -> Dictionary:
	var i := NetProtocol.slot_arg(a[0] if a.size() > 0 else -1, ps.inventory.capacity)
	var s = ps.inventory.get_slot(i)
	if s == null:
		return _no("Nothing there")
	var item: ItemData = ItemDB.get_item(s.id)
	if item == null or not (item.is_consumable() or item.is_recipe_book() or item.is_spell_tome()):
		return _no("That can't be used like this")
	ps.inventory.remove_from_slot(i, 1)
	return _ok("", {"item": String(item.id)})


func _act_equip(ps: PeerState, a: Array) -> Dictionary:
	var i := NetProtocol.slot_arg(a[0] if a.size() > 0 else -1, ps.inventory.capacity)
	var s = ps.inventory.get_slot(i)
	if s == null:
		return _no("Nothing there")
	var item: ItemData = ItemDB.get_item(s.id)
	var err := Equipment.check_requirements(item, ps.level)
	if err != "":
		return _no(err)
	ps.inventory.remove_from_slot(i, 1)
	var old := ps.equipment.equip(item)
	if old != &"":
		give(ps, old, 1)
	ps.dirty_inventory = true
	return _ok("", {"item": String(item.id)})


func _act_unequip(ps: PeerState, a: Array) -> Dictionary:
	var slot := int(a[0]) if a.size() > 0 else -1
	var id := ps.equipment.get_item_id(slot)
	if id == &"":
		return _no("Nothing equipped there")
	if ps.inventory.free_slot_count() == 0:
		return _no("Inventory full")
	ps.equipment.unequip(slot)
	ps.inventory.add_item(id, 1)
	return _ok()


func _act_craft(ps: PeerState, a: Array) -> Dictionary:
	if a.size() < 3:
		return _no("Bad request")
	var recipe: RecipeData = RecipeBook.get_recipe(StringName(String(a[0])))
	if recipe == null:
		return _no("Unknown recipe")
	var times := clampi(int(a[1]), 1, 50)
	var skill := clampi(int(a[2]), 0, 100)  # client-reported (M11)
	var stations := Crafting.stations_near(net.get_tree(), ps.pos, 4.5)
	if not stations.has(recipe.station_id()):
		return _no("Requires a %s nearby" % recipe.station_name())
	if skill < recipe.required_crafting():
		return _no("Requires Crafting %d" % recipe.required_crafting())
	var made := 0
	var cost := recipe.cost_at(skill)
	for k in times:
		var ok := true
		for item in cost:
			if ps.inventory.count_of(item) < int(cost[item]):
				ok = false
		if not ok:
			break
		for item in cost:
			ps.inventory.remove_item(item, int(cost[item]))
		give(ps, recipe.result_item, recipe.result_count)
		made += 1
	if made == 0:
		return _no("Missing materials")
	return _ok("", {"made": made, "item": String(recipe.result_item), "xp": recipe.xp})


func _act_place(ps: PeerState, a: Array) -> Dictionary:
	if a.size() < 5:
		return _no("Bad request")
	var data := BuildingManager.get_piece_data(StringName(String(a[0])))
	var cell = NetProtocol.vec2i_arg(a[1])
	var slot := String(a[2])
	var rot := posmod(int(a[3]), 4)
	var layer := clampi(int(a[4]), 0, 1)
	if data == null or cell == null:
		return _no("Bad request")
	var kind := BuildingManager.slot_kind(data)
	if not (slot == kind or (kind == "edge" and slot in ["edge_n", "edge_w"])):
		return _no("Wrong placement")
	if ps.layer != layer or Vector2(cell.x + 0.5 - ps.pos.x, cell.y + 0.5 - ps.pos.z).length() > NetProtocol.BUILD_REACH:
		return _no("Too far away")
	if ps.level < data.required_level:
		return _no("Requires level %d" % data.required_level)
	var w := world()
	var why: String = with_layer(layer, func() -> String: return w.building.check_place(data, cell, slot, null, false))
	if why != "":
		return _no(why)
	for item in data.cost:
		if ps.inventory.count_of(item) < int(data.cost[item]):
			var d: ItemData = ItemDB.get_item(item)
			return _no("Missing %s" % (d.display_name if d else String(item)))
	for item in data.cost:
		ps.inventory.remove_item(item, int(data.cost[item]))
	var piece := w.building._spawn(data, cell, slot, rot, layer)
	piece.set_meta(&"owner", ps.name)
	broadcast_build("add", piece_entry(piece))
	return _ok("", {"key": BuildingManager.key(cell, slot, layer)})


## Runs `fn` with the world's active layer temporarily set (validation of
## pieces on another layer than the host's).
func with_layer(layer: int, fn: Callable) -> Variant:
	var w := world()
	var saved := w.layer
	w.layer = layer
	var r = fn.call()
	w.layer = saved
	return r


func _piece_for(ps: PeerState, a: Array) -> BuildPiece:
	if a.size() < 3:
		return null
	var cell = NetProtocol.vec2i_arg(a[0])
	if cell == null:
		return null
	var piece: BuildPiece = world().building.pieces.get(BuildingManager.key(cell, String(a[1]), clampi(int(a[2]), 0, 1)))
	if piece == null or not is_instance_valid(piece):
		return null
	if piece.layer != ps.layer or Vector2(piece.global_position.x - ps.pos.x, piece.global_position.z - ps.pos.z).length() > NetProtocol.BUILD_REACH:
		return null
	return piece


func _act_remove(ps: PeerState, a: Array) -> Dictionary:
	var piece := _piece_for(ps, a)
	if piece == null:
		return _no("Nothing to remove there")
	if String(piece.get_meta(&"owner", "")) != ps.name:
		return _no("That belongs to someone else")
	if piece.storage and piece.storage.free_slot_count() < piece.storage.capacity:
		return _no("Empty the %s first" % piece.data.display_name)
	var w := world()
	var share := 1.0 if (w.building.is_claimed(piece.global_position) or piece.data.behavior == BuildPieceData.Behavior.CLAIM) else BuildingManager.UNCLAIMED_REFUND
	for item in piece.data.cost:
		var n := floori(int(piece.data.cost[item]) * share)
		if n > 0:
			give(ps, item, n)
	w.building.remove(piece, null)
	return _ok()


func _act_door(ps: PeerState, a: Array) -> Dictionary:
	var piece := _piece_for(ps, a)
	if piece == null or piece.data.behavior != BuildPieceData.Behavior.DOOR:
		return _no("No door there")
	piece.set_open(not piece.is_open)
	broadcast_build("state", piece_entry(piece))
	return _ok()


func _act_place_object(ps: PeerState, a: Array) -> Dictionary:
	var i := NetProtocol.slot_arg(a[0] if a.size() > 0 else -1, ps.inventory.capacity)
	var s = ps.inventory.get_slot(i)
	if s == null or a.size() < 2 or not a[1] is Vector3:
		return _no("Nothing there")
	var item: ItemData = ItemDB.get_item(s.id)
	if item == null or not item.is_placeable() or item.placeable_scene == null:
		return _no("That can't be placed")
	var pos: Vector3 = a[1]
	if pos.distance_to(ps.pos) > NetProtocol.REACH:
		return _no("Too far away")
	ps.inventory.remove_from_slot(i, 1)
	world().place_object(item.placeable_scene, pos)
	return _ok()
