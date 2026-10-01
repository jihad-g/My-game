extends Node
## Scripted multiplayer guest for the automated tests (Milestone 11).
##
## Started by tests/test_runner.gd (test_m11_session) as a second Godot
## process: joins the host, loads the shared world, exercises player sync,
## authoritative inventory, gathering, building, dropping/picking up, chat and
## the server's speed check, then writes what it observed to --out=<file>.
##
##   godot --headless --path . res://tests/net_client_runner.tscn -- --connect=127.0.0.1:24565 --out=user://net.json

var r := {"welcome": false}
var _out := "user://net_client_result.json"
var _world: World
var _test_msgs: Array = []
## --rejoin: only join, report what the server remembered, leave.
var _rejoin := false


func _ready() -> void:
	var address := "127.0.0.1"
	var port := NetProtocol.DEFAULT_PORT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--connect="):
			var v := a.substr(10)
			address = v.get_slice(":", 0)
			if v.contains(":"):
				port = v.get_slice(":", 1).to_int()
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--rejoin":
			_rejoin = true
	Net.player_name = "Guesty"
	Net.player_class = &"barbarian"
	Net.welcomed.connect(_on_welcome)
	Net.join_failed.connect(func(reason: String) -> void:
		r.join_failed = reason
		_finish())
	Net.chat_received.connect(func(_from: String, text: String) -> void:
		if text.begins_with("TEST "):
			_test_msgs.append(text.substr(5)))
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
		r.timed_out = true
		_finish())
	var err := Net.join(address, port)
	r.join_error = err


func _on_welcome(data: Dictionary) -> void:
	r.welcome = true
	r.seed = String(data.get("seed", ""))
	r.name = String(data.get("name", ""))
	r.fresh = bool(data.get("fresh", true))
	r.host_name = String(data.get("host_name", ""))
	var wood := 0
	for s in data.get("inventory", []):
		if s != null and String(s.id) == "wood":
			wood += int(s.count)
	r.welcome_wood = wood
	if _rejoin:
		_finish()
		return
	SaveManager.start_transient(GameState.parse_seed(data.seed), StringName(String(data.get("class", "knight"))))
	_world = (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(_world)
	_run.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > seconds:
			return false
	return true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _msg(prefix: String) -> String:
	for m in _test_msgs:
		if String(m).begins_with(prefix):
			return String(m).substr(prefix.length())
	return ""


## Waits for the server's answer to the last request.
func _reply() -> Array:
	var box := []
	var rid := Net.client._rid
	var cb: Callable = Net.client._pending.get(rid, Callable())
	Net.client._pending[rid] = func(ok: bool, msg: String, extra: Dictionary) -> void:
		if cb.is_valid():
			cb.call(ok, msg, extra)
		box.append([ok, msg, extra])
	await _wait(func() -> bool: return not box.is_empty(), 10.0)
	return box[0] if not box.is_empty() else [false, "no reply", {}]


func _walk_to(target: Vector3) -> void:
	var p := _world.player
	for i in 600:
		var d := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z)
		if d.length() < 1.0:
			break
		var step := d.normalized() * minf(0.25, d.length())
		var np := p.global_position + step
		np.y = _world.get_ground_height(np) + 0.2
		p.global_position = np
		await get_tree().physics_frame


func _run() -> void:
	var w := _world
	r.world_loaded = await _wait(func() -> bool: return w.is_ready, 60.0)
	if not r.world_loaded:
		_finish()
		return
	var p := w.player
	r.remote_inventory = p.inventory.remote
	r.spawn_near_host = false
	r.local_add_refused = p.inventory.add_item(&"wood", 5) == 5
	r.monsters_paused = w.spawner.max_active == 0
	# The host appears as a puppet that moves.
	r.host_seen = await _wait(func() -> bool:
		for rp in get_tree().get_nodes_in_group(&"remote_players"):
			if rp.peer_id == 1 and rp.visible and rp.global_position != Vector3.ZERO:
				return true
		return false, 15.0)
	for rp in get_tree().get_nodes_in_group(&"remote_players"):
		if rp.peer_id == 1:
			r.host_distance = rp.global_position.distance_to(p.global_position)
			r.spawn_near_host = r.host_distance < 12.0
			var start: Vector3 = rp.global_position
			await _wait(func() -> bool: return rp.global_position.distance_to(start) > 1.5, 10.0)
			r.host_moved = rp.global_position.distance_to(start)
	# Items from the host (authoritative inventory).
	r.got_items = await _wait(func() -> bool: return p.inventory.count_of(&"wood") >= 10, 15.0)
	r.wood_before = p.inventory.count_of(&"wood")
	# Gather something nearby (the server checks reach and existence).
	var target: PropBody = null
	var best := 40.0
	for chunk in w.chunk_manager._chunks.values():
		if chunk.lod != 0:
			continue
		for c in chunk.get_children():
			if c is PropBody and c.is_interactable():
				var dd: float = c.global_position.distance_to(p.global_position)
				if dd < best:
					best = dd
					target = c
	r.found_gatherable = target != null
	if target:
		var tchunk: Chunk = target.chunk
		var tindex := target.prop_index
		await _walk_to(target.global_position)
		await _frames(6)
		target.interact(p)
		var rep := await _reply()
		r.gather_ok = rep[0]
		r.gather_msg = rep[1]
		r.gather_items = (rep[2] as Dictionary).get("items", {})
		await _frames(10)
		r.gather_removed_locally = GameState.is_prop_removed(tchunk.coord, tindex, 0.0, tchunk.layer)
		Net.say("TEST gathered %d,%d,%d,%d" % [tchunk.coord.x, tchunk.coord.y, tchunk.layer, tindex])
	# Build a floor next to us.
	var cell := Vector2i(floori(p.global_position.x) + 2, floori(p.global_position.z))
	var floor_data := BuildingManager.get_piece_data(&"wood_floor")
	var why := w.building.check_place(floor_data, cell, "floor", p)
	if why != "":
		cell += Vector2i(0, 2)
	Net.client.place_piece(floor_data, cell, "floor", 0, w.layer)
	var prep := await _reply()
	r.place_ok = prep[0]
	r.place_msg = prep[1]
	r.place_seen = await _wait(func() -> bool: return w.building.pieces.has(BuildingManager.key(cell, "floor", w.layer)), 5.0)
	await _frames(10)
	r.wood_after_build = p.inventory.count_of(&"wood")
	Net.say("TEST built %d,%d" % [cell.x, cell.y])
	# Someone else's piece can't be removed.
	# Drop one wood and pick it up again.
	var slot := -1
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"wood":
			slot = i
	var wood_now := p.inventory.count_of(&"wood")
	p.drop_slot(slot, 1)
	var drep := await _reply()
	r.drop_ok = drep[0]
	var found := []  # lambdas capture locals by value: collect through an array
	await _wait(func() -> bool:
		for k in Net.client._pickups:
			var q: Pickup = Net.client._pickups[k]
			if is_instance_valid(q) and q.item_id == &"wood":
				found.append(q)
				return true
		return false, 5.0)
	var pk: Pickup = found[0] if not found.is_empty() else null
	r.drop_seen = pk != null
	await _frames(10)
	r.wood_after_drop = p.inventory.count_of(&"wood")
	if pk:
		pk.interact(p)
		var krep := await _reply()
		r.pickup_ok = krep[0]
		await _frames(10)
		r.wood_after_pickup = p.inventory.count_of(&"wood")
	r.wood_drop_roundtrip = r.get("wood_after_drop", -1) == wood_now - 1 and r.get("wood_after_pickup", -1) == wood_now
	# What the host did reaches us.
	await _wait(func() -> bool: return _msg("host_piece ") != "" and _msg("host_prop ") != "", 20.0)
	var hp := _msg("host_piece ").split(",")
	if hp.size() == 2:
		var hcell := Vector2i(hp[0].to_int(), hp[1].to_int())
		r.host_piece_seen = await _wait(func() -> bool: return w.building.pieces.has(BuildingManager.key(hcell, "floor", 0)), 10.0)
		if r.host_piece_seen:
			var hpiece: BuildPiece = w.building.pieces[BuildingManager.key(hcell, "floor", 0)]
			r.host_piece_owner = String(hpiece.get_meta(&"owner", ""))
			Net.client.remove_piece(hpiece)
			var rrep := await _reply()
			r.remove_others_refused = not rrep[0]
	var hpp := _msg("host_prop ").split(",")
	if hpp.size() == 4:
		var c := Vector2i(hpp[0].to_int(), hpp[1].to_int())
		r.host_prop_seen = await _wait(func() -> bool: return GameState.is_prop_removed(c, hpp[3].to_int(), 0.0, hpp[2].to_int()), 10.0)
	# Same terrain on both sides.
	var probe := Vector3(37.5, 0, -81.5)
	Net.say("TEST height %.3f" % w.generator.get_height_at(probe))
	# Time and day follow the host.
	r.world_time = GameState.world_time
	# Cheating: a 300 m jump without the teleport flag is put back.
	var before := p.global_position
	p.global_position = before + Vector3(300, 0, 0)
	r.corrected = await _wait(func() -> bool: return p.global_position.distance_to(before) < 20.0, 8.0)
	Net.say("hello from guest")
	await _frames(30)
	r.requests_ok = Net.client.replies.ok
	r.requests_failed = Net.client.replies.failed
	_finish()


func _finish() -> void:
	r.done = true
	var f := FileAccess.open(_out, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(r, "\t"))
		f.close()
	Net.leave()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
