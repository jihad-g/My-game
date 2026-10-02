class_name NetClient
extends RefCounted
## Guest side of a multiplayer session (Milestone 11).
##
## Flow: connect -> hello -> welcome (seed, time, buildings, nearby world
## changes, our inventory) -> the world checksum is verified locally ->
## `Net.welcomed` -> the game loads the world from the same seed ->
## setup_world() applies the welcome -> once the terrain is ready, c2s_ready.
##
## Our inventory is a read-only mirror (Inventory.remote): actions become
## requests and the server's snapshots overwrite it. Everything received
## before the world exists is kept in a backlog and applied after setup.

var net: Node
var welcome: Dictionary = {}
var peer_id := 0
## peer id -> RemotePlayer
var puppets: Dictionary = {}
var world_set_up := false
var ready_sent := false
## Request replies received (tests and the debug overlay).
var replies := {"ok": 0, "failed": 0}

var _rid := 0
var _pending: Dictionary = {}  # request id -> Callable(ok, msg, extra)
var _backlog: Array[Callable] = []
var _pickups: Dictionary = {}  # net id -> Pickup
var _state_t := 0.0
var _profile_t := 5.0
var _teleport := true


func _init(p_net: Node) -> void:
	net = p_net


func shutdown() -> void:
	for pid in puppets:
		if is_instance_valid(puppets[pid]):
			puppets[pid].queue_free()
	puppets.clear()
	var w := World.instance
	if w and w.player and w.player.inventory.remote:
		w.player.inventory.remote = false


# --- Handshake ---------------------------------------------------------------------------

func on_welcome(data: Dictionary) -> void:
	if int(data.get("version", -1)) != NetProtocol.VERSION:
		net.fail_join("Different game version")
		return
	var seed := GameState.parse_seed(data.get("seed", "0"))
	var gen := TerrainGenerator.new(seed, load("res://data/worldgen/default_worldgen.tres"))
	if NetProtocol.world_checksum(gen) != int(data.get("checksum", 0)):
		net.fail_join("This world generates differently on your game (different version?)")
		return
	welcome = data
	peer_id = int(data.get("peer_id", net.my_id()))
	net.player_name = String(data.get("name", net.player_name))
	net.players = (data.get("players", {}) as Dictionary).duplicate()
	net.players[peer_id] = {"name": net.player_name, "class": String(data.get("class", "knight"))}
	net.players_changed.emit()
	net.welcomed.emit(data)


## Called by World._ready (before streaming starts) on a guest.
func setup_world(w: World) -> void:
	var d := welcome
	GameState.world_time = float(d.get("world_time", 0.0))
	w.day_night.day = int(d.get("day", 1))
	w.day_night.hour = float(d.get("hour", 8.0))
	var p := w.player
	var profile: Dictionary = d.get("profile", {})
	if not profile.is_empty():
		p.from_save(profile)
	p.inventory.remote = true
	p.inventory.remote_mover = func(f: int, t: int) -> void: request("move", [f, t])
	p.inventory.from_array(d.get("inventory", []))
	p.equipment.from_save(d.get("equipment", {}))
	p._on_equipment_changed()
	var pos: Vector3 = d.get("position", Vector3.ZERO)
	p.global_position = pos
	p.spawn_point = pos
	w.layer = int(d.get("layer", 0))
	_load_buildings(w, d.get("buildings", []))
	for r in d.get("regions", []):
		on_region(r[0], r[1], r[2])
	for pk in d.get("pickups", []):
		_spawn_pickup(w, int(pk[0]), String(pk[1]), int(pk[2]), pk[3])
	w.load_placed(d.get("placed", []))
	for pid in net.players:
		if int(pid) != peer_id:
			_ensure_puppet(int(pid))
	# Shared world, guest rules: no local monsters, raids, events or saving.
	w.make_guest()
	p.model.anim_event.connect(func(ev: String, args: Array) -> void:
		if net.is_client():
			net.c2s_anim.rpc_id(1, ev, args))
	p.equipment.changed.connect(_send_look)
	world_set_up = true
	for c in _backlog:
		c.call()
	_backlog.clear()


func _send_look() -> void:
	var w := World.instance
	if w and net.is_client() and ready_sent:
		net.c2s_anim.rpc_id(1, "look", w.player.look_args())


## Runs `fn` now if the world is set up, otherwise after setup.
func _later(fn: Callable) -> void:
	if world_set_up and World.instance:
		fn.call()
	else:
		_backlog.append(fn)


func process(delta: float) -> void:
	var w := World.instance
	if not world_set_up or w == null or w.player == null:
		return
	if not ready_sent and w.is_ready:
		ready_sent = true
		net.c2s_ready.rpc_id(1)
		_send_profile(w)
		_send_look()
	if not ready_sent:
		return
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 1.0 / NetProtocol.STATE_RATE
		var s := NetServer.local_state(w)
		if _teleport:
			s[7] = int(s[7]) | NetProtocol.F_TELEPORT
			_teleport = false
		net.c2s_state.rpc_id(1, s)
	_profile_t -= delta
	if _profile_t <= 0.0:
		_profile_t = 30.0
		_send_profile(w)


func _send_profile(w: World) -> void:
	var prof := w.player.to_save()
	prof.erase("inventory")
	prof.erase("equipment")
	net.c2s_profile.rpc_id(1, prof)


## Next state packet tells the server we jumped (respawn, travel, correction).
func mark_teleport() -> void:
	_teleport = true


# --- Players -----------------------------------------------------------------------------

func _ensure_puppet(pid: int) -> RemotePlayer:
	if puppets.has(pid) and is_instance_valid(puppets[pid]):
		return puppets[pid]
	var w := World.instance
	var info: Dictionary = net.players.get(pid, {})
	if w == null or info.is_empty():
		return null
	var rp := RemotePlayer.new()
	rp.setup(pid, String(info.get("name", "?")), StringName(String(info.get("class", "knight"))))
	w.add_child(rp)
	puppets[pid] = rp
	return rp


func on_player_joined(pid: int, info: Dictionary) -> void:
	net.players[pid] = info
	net.players_changed.emit()
	_later(_joined.bind(pid, String(info.get("name", "?"))))


func _joined(pid: int, who: String) -> void:
	_ensure_puppet(pid)
	Events.toast.emit("%s joined the game" % who, Color(0.6, 1.0, 0.7))


func on_player_left(pid: int) -> void:
	var info: Dictionary = net.players.get(pid, {})
	net.players.erase(pid)
	net.players_changed.emit()
	if puppets.has(pid):
		if is_instance_valid(puppets[pid]):
			puppets[pid].queue_free()
		puppets.erase(pid)
	if not info.is_empty():
		Events.toast.emit("%s left the game" % String(info.get("name", "?")), Color(0.8, 0.85, 1.0))


func on_states(states: Dictionary) -> void:
	if not world_set_up:
		return
	for pid in states:
		if int(pid) == peer_id:
			continue
		var s := NetProtocol.decode_state(states[pid])
		if s.is_empty():
			continue
		var rp := _ensure_puppet(int(pid))
		if rp:
			rp.push_state(s)


func on_anim(pid: int, ev: String, args: Array) -> void:
	if ev == "look":
		# Outfits can arrive before the puppet exists (just after joining).
		_later(func() -> void:
			var p := _ensure_puppet(pid)
			if p:
				p.play_event(ev, args))
		return
	var rp: RemotePlayer = puppets.get(pid)
	if rp and is_instance_valid(rp) and ev in RemotePlayer.ANIM_EVENTS:
		rp.play_event(ev, args)


func on_correct(pos: Vector3, layer: int) -> void:
	_later(_corrected.bind(pos, layer))


func _corrected(pos: Vector3, layer: int) -> void:
	var w := World.instance
	if layer != w.layer:
		w.travel_to_layer(layer, pos)
	w.player.global_position = pos
	w.player.velocity = Vector3.ZERO
	mark_teleport()


func on_time(t: float, day: int, hour: float) -> void:
	if absf(GameState.world_time - t) > 1.0:
		GameState.world_time = t
	var w := World.instance
	if w and world_set_up:
		var dh := absf(w.day_night.hour + w.day_night.day * 24.0 - (hour + day * 24.0))
		if dh > 0.05:
			w.day_night.day = day
			w.day_night.hour = hour


# --- Requests ----------------------------------------------------------------------------

## Sends a request; `cb(ok, msg, extra)` runs when the server answers.
func request(action: String, args: Array, cb: Callable = Callable()) -> int:
	_rid += 1
	_pending[_rid] = cb
	net.stats.sent += 1
	net.c2s_request.rpc_id(1, _rid, action, args)
	return _rid


func pending_requests() -> int:
	return _pending.size()


func on_reply(rid: int, ok: bool, msg: String, extra: Dictionary) -> void:
	var cb: Callable = _pending.get(rid, Callable())
	_pending.erase(rid)
	if ok:
		replies.ok += 1
	else:
		replies.failed += 1
		if msg != "":
			Events.toast.emit(msg, Color(1, 0.7, 0.5))
	if cb.is_valid():
		cb.call(ok, msg, extra)


func on_inventory(slots: Array, equipment: Dictionary) -> void:
	_later(_apply_inventory.bind(slots, equipment))


func _apply_inventory(slots: Array, equipment: Dictionary) -> void:
	var p := World.instance.player
	var before := {}
	for st in p.inventory.slots:
		if st != null:
			before[st.id] = int(before.get(st.id, 0)) + int(st.count)
	p.inventory.from_array(slots)
	for st in p.inventory.slots:
		if st != null and int(before.get(st.id, 0)) == 0:
			p.discover_from(st.id)
	if p.equipment.to_save() != equipment:
		p.equipment.from_save(equipment)
		p._on_equipment_changed()


## Harvest (hit) or gather (interact) a prop; the server decides.
func harvest(chunk: Chunk, index: int, gather: bool, done: Callable = Callable()) -> void:
	request("harvest", [chunk.coord, chunk.layer, index, gather], func(ok: bool, _m: String, extra: Dictionary) -> void:
		if ok:
			Events.resource_harvested.emit(StringName(String(extra.get("prop", ""))), int(extra.get("xp", 1)))
			var items: Dictionary = extra.get("items", {})
			for id in items:
				Events.item_picked_up.emit(StringName(id), int(items[id]))
		if done.is_valid():
			done.call(ok))


func pickup(p: Pickup) -> void:
	if p.has_meta(&"requested"):
		return
	p.set_meta(&"requested", true)
	request("pickup", [p.net_id], func(ok: bool, _m: String, extra: Dictionary) -> void:
		if is_instance_valid(p):
			p.remove_meta(&"requested")
		if ok:
			Events.item_picked_up.emit(StringName(String(extra.get("item", ""))), int(extra.get("count", 0))))


func craft(recipe: RecipeData, times: int, skill: int) -> void:
	request("craft", [String(recipe.id), times, skill], func(ok: bool, _m: String, extra: Dictionary) -> void:
		if ok:
			var made := int(extra.get("made", 0))
			var item: ItemData = ItemDB.get_item(StringName(String(extra.get("item", ""))))
			for k in made:
				Events.item_crafted.emit(recipe.result_item, maxi(1, recipe.xp / 4))
			Events.toast.emit("Crafted %s x%d" % [item.display_name if item else "?", made * recipe.result_count], UITheme.GOLD))


func place_piece(data: BuildPieceData, cell: Vector2i, slot: String, rot: int, layer: int) -> void:
	request("place", [String(data.id), cell, slot, rot, layer], func(ok: bool, _m: String, _e: Dictionary) -> void:
		if ok:
			Events.item_crafted.emit(data.id, 1)
			Audio.play(&"build", -4.0))


func remove_piece(piece: BuildPiece) -> void:
	request("remove", [piece.cell, piece.slot, piece.layer])


func toggle_door(piece: BuildPiece) -> void:
	request("door", [piece.cell, piece.slot, piece.layer])


# --- Authoritative world state ------------------------------------------------------------

func on_props_removed(list: Array) -> void:
	_later(_apply_props_removed.bind(list))


func _apply_props_removed(list: Array) -> void:
	var w := World.instance
	for e in list:
		if not e is Array or (e as Array).size() < 3:
			continue
		var coord = NetProtocol.vec2i_arg(e[0])
		if coord == null:
			continue
		GameState.mark_prop_removed(coord, int(e[2]), int(e[1]))
		var chunk := w.chunk_manager.get_chunk(coord)
		if chunk and chunk.layer == int(e[1]):
			chunk.hide_prop(int(e[2]))


func on_region(key: Vector3i, props: Dictionary, deaths: Dictionary) -> void:
	GameState.regions.import_region(key, props, deaths)
	_later(_refresh_region.bind(key, props))


func _refresh_region(key: Vector3i, props: Dictionary) -> void:
	var w := World.instance
	for c in props:
		var chunk := w.chunk_manager.get_chunk(c)
		if chunk and chunk.layer == key.z:
			chunk.refresh_removed()


func _load_buildings(w: World, entries: Array) -> void:
	w.building.from_save(entries)


func on_build(op: String, entry: Dictionary) -> void:
	_later(_apply_build.bind(op, entry))


func _apply_build(op: String, entry: Dictionary) -> void:
	var b := World.instance.building
	var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("z", 0)))
	var k := BuildingManager.key(cell, String(entry.get("slot", "")), int(entry.get("layer", 0)))
	var piece: BuildPiece = b.pieces.get(k)
	if op == "add":
		if piece == null:
			b.from_save([entry])
	elif op == "remove":
		if piece:
			b.pieces.erase(k)
			VFX.burst(piece.get_parent(), piece.global_position + Vector3(0, 1.0, 0), 1.2, Color(0.55, 0.45, 0.35, 0.6), 0.25)
			piece.queue_free()
			Events.building_changed.emit()
	elif op == "state" and piece:
		var data: Dictionary = entry.get("data", {})
		if piece.data.behavior == BuildPieceData.Behavior.DOOR:
			piece.set_open(bool(data.get("open", false)))
		piece.load_data(data)


func _spawn_pickup(w: World, nid: int, item: String, count: int, pos: Vector3) -> void:
	if _pickups.has(nid) and is_instance_valid(_pickups[nid]):
		return
	var p := w.spawn_pickup(StringName(item), count, pos, true)
	if p:
		p.net_id = nid
		_pickups[nid] = p


func on_pickup(op: String, nid: int, item: String, count: int, pos: Vector3) -> void:
	_later(_apply_pickup.bind(op, nid, item, count, pos))


func _apply_pickup(op: String, nid: int, item: String, count: int, pos: Vector3) -> void:
	var p: Pickup = _pickups.get(nid)
	if op == "add":
		_spawn_pickup(World.instance, nid, item, count, pos)
	elif op == "remove":
		_pickups.erase(nid)
		if p and is_instance_valid(p) and p.net_id == nid:
			NodePool.release_or_free(p)
	elif op == "count" and p and is_instance_valid(p):
		p.count = count


func on_placed(entry: Dictionary) -> void:
	_later(_apply_placed.bind(entry))


func _apply_placed(entry: Dictionary) -> void:
	World.instance.load_placed([entry])
