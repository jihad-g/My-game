extends Node
## Multiplayer session (Milestone 11): transport, handshake and every RPC.
##
## Architecture - one authoritative server, any number of clients (max 8):
##   - HOST: a player's game is also the server ("listen server"); with
##     `--server` it runs headless without a local player ("dedicated").
##   - CLIENT: joins a host. It generates the same world locally from the seed
##     (generation is deterministic), so terrain is never sent over the wire;
##     only *changes* are: felled trees, buildings, pickups, players.
##
## Authority:
##   - Players move themselves (client-authoritative movement, 20 Hz), the
##     server checks speed and corrects cheaters/teleports back.
##   - The server owns every inventory, the world's changes and buildings.
##     Clients send requests (harvest, pick up, drop, use, equip, craft, build,
##     remove...), the server validates them against its own state, applies
##     them and broadcasts the results; a client's inventory is a read-only
##     mirror updated from server snapshots.
##
## All RPCs live on this autoload (same node path on every peer). "authority"
## RPCs can only be sent by the server; "any_peer" ones are validated by
## NetServer before anything happens. Logic lives in NetServer / NetClient.

signal mode_changed
## Client: the server accepted us; `data` is the welcome (seed, time, buildings...).
signal welcomed(data: Dictionary)
signal join_failed(reason: String)
signal disconnected(reason: String)
signal players_changed
signal chat_received(from: String, text: String)

enum Mode { OFFLINE, HOST, CLIENT }

var mode: int = Mode.OFFLINE
## Host without a local player (headless server).
var dedicated := false
var player_name := "Player"
var player_class: StringName = &"knight"
var server: NetServer
var client: NetClient
## peer id -> {"name", "class"} (everyone in the session, including the host as 1).
var players: Dictionary = {}
## Saved data of players who joined this world, by name (stored in the host's save).
var player_records: Dictionary = {}
## Messages counted for the debug overlay and tests.
var stats := {"sent": 0, "received": 0, "rejected": 0, "corrections": 0}

var _peer: ENetMultiplayerPeer
## Start hosting on this port once the next world has loaded (-1 = don't).
var host_on_load := -1
var dedicated_on_load := false


## Called by World when its terrain is ready the first time.
func on_world_loaded() -> void:
	if host_on_load >= 0 and not is_online():
		var port := host_on_load
		var ded := dedicated_on_load
		host_on_load = -1
		dedicated_on_load = false
		var err := host(port, ded)
		if err == OK:
			Events.toast.emit("Hosting on port %d - friends can join with your IP address" % port, Color(0.6, 1.0, 0.8))
			print("Shardlands server listening on port %d" % port)
		else:
			Events.toast.emit("Couldn't host on port %d (%s)" % [port, error_string(err)], Color(1, 0.6, 0.5))


func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_server() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Shows `feature` as unavailable for clients and returns true (callers bail out).
func client_blocked(feature: String) -> bool:
	if not is_client():
		return false
	Events.toast.emit("%s isn't available to guests in multiplayer yet" % feature, Color(1, 0.75, 0.5))
	return true


# --- Session control ------------------------------------------------------------------

## Starts hosting the current world. Returns OK or an error.
func host(port: int = NetProtocol.DEFAULT_PORT, p_dedicated: bool = false) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, NetProtocol.MAX_PLAYERS)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	mode = Mode.HOST
	dedicated = p_dedicated
	server = NetServer.new(self)
	players.clear()
	if not dedicated:
		players[1] = {"name": player_name, "class": String(player_class)}
	multiplayer.peer_connected.connect(server.on_peer_connected)
	multiplayer.peer_disconnected.connect(server.on_peer_disconnected)
	mode_changed.emit()
	players_changed.emit()
	return OK


## Connects to a host. Listen to `welcomed` / `join_failed`.
func join(address: String, port: int = NetProtocol.DEFAULT_PORT) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	mode = Mode.CLIENT
	client = NetClient.new(self)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	mode_changed.emit()
	return OK


## Ends the session (both roles).
func leave() -> void:
	if server:
		server.shutdown()
	if client:
		client.shutdown()
	for sig in [multiplayer.peer_connected, multiplayer.peer_disconnected, multiplayer.connected_to_server,
			multiplayer.connection_failed, multiplayer.server_disconnected]:
		for c in sig.get_connections():
			sig.disconnect(c.callable)
	if _peer:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	var was := mode
	mode = Mode.OFFLINE
	dedicated = false
	server = null
	client = null
	players.clear()
	if was != Mode.OFFLINE:
		mode_changed.emit()
		players_changed.emit()


func _process(delta: float) -> void:
	if server:
		server.process(delta)
	elif client:
		client.process(delta)


func _on_connected() -> void:
	c2s_hello.rpc_id(1, {"version": NetProtocol.VERSION, "game": String(ProjectSettings.get_setting("application/config/version", "0")),
		"name": player_name, "class": String(player_class)})


func _on_connection_failed() -> void:
	var reason := "Couldn't reach the server"
	leave()
	join_failed.emit(reason)


func _on_server_disconnected() -> void:
	var c: NetClient = client
	leave()
	if c and c.welcome.is_empty():
		join_failed.emit("The server closed the connection")
	else:
		disconnected.emit("Disconnected from the server")


## Called by NetClient when the welcome is unusable (version or world mismatch).
func fail_join(reason: String) -> void:
	leave()
	join_failed.emit(reason)


func sender() -> int:
	return multiplayer.get_remote_sender_id()


# --- RPCs: handshake ---------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_hello(info: Dictionary) -> void:
	stats.received += 1
	if server:
		server.on_hello(sender(), info)


@rpc("authority", "call_remote", "reliable")
func s2c_welcome(data: Dictionary) -> void:
	stats.received += 1
	if client:
		client.on_welcome(data)


@rpc("authority", "call_remote", "reliable")
func s2c_reject(reason: String) -> void:
	if client:
		fail_join(reason)


@rpc("any_peer", "call_remote", "reliable")
func c2s_ready() -> void:
	if server:
		server.on_ready(sender())


@rpc("authority", "call_remote", "reliable")
func s2c_player_joined(peer_id: int, info: Dictionary) -> void:
	if client:
		client.on_player_joined(peer_id, info)


@rpc("authority", "call_remote", "reliable")
func s2c_player_left(peer_id: int) -> void:
	if client:
		client.on_player_left(peer_id)


# --- RPCs: players --------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func c2s_state(s: Array) -> void:
	if server:
		server.on_state(sender(), s)


@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_states(states: Dictionary) -> void:
	if client:
		client.on_states(states)


@rpc("any_peer", "call_remote", "reliable")
func c2s_anim(ev: String, args: Array) -> void:
	if server:
		server.on_anim(sender(), ev, args)


@rpc("authority", "call_remote", "reliable")
func s2c_anim(peer_id: int, ev: String, args: Array) -> void:
	if client:
		client.on_anim(peer_id, ev, args)


@rpc("authority", "call_remote", "reliable")
func s2c_correct(pos: Vector3, layer: int) -> void:
	if client:
		client.on_correct(pos, layer)


@rpc("any_peer", "call_remote", "reliable")
func c2s_profile(profile: Dictionary) -> void:
	if server:
		server.on_profile(sender(), profile)


# --- RPCs: requests & authoritative state ---------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_request(rid: int, action: String, args: Array) -> void:
	stats.received += 1
	if server:
		server.on_request(sender(), rid, action, args)


@rpc("authority", "call_remote", "reliable")
func s2c_reply(rid: int, ok: bool, msg: String, extra: Dictionary) -> void:
	if client:
		client.on_reply(rid, ok, msg, extra)


@rpc("authority", "call_remote", "reliable")
func s2c_inventory(slots: Array, equipment: Dictionary) -> void:
	if client:
		client.on_inventory(slots, equipment)


@rpc("authority", "call_remote", "reliable")
func s2c_props_removed(list: Array) -> void:
	if client:
		client.on_props_removed(list)


@rpc("any_peer", "call_remote", "reliable")
func c2s_regions(keys: Array) -> void:
	if server:
		server.on_regions_request(sender(), keys)


@rpc("authority", "call_remote", "reliable")
func s2c_region(key: Vector3i, props: Dictionary, deaths: Dictionary) -> void:
	if client:
		client.on_region(key, props, deaths)


@rpc("authority", "call_remote", "reliable")
func s2c_build(op: String, entry: Dictionary) -> void:
	if client:
		client.on_build(op, entry)


@rpc("authority", "call_remote", "reliable")
func s2c_pickup(op: String, net_id: int, item: String, count: int, pos: Vector3) -> void:
	if client:
		client.on_pickup(op, net_id, item, count, pos)


@rpc("authority", "call_remote", "reliable")
func s2c_placed(entry: Dictionary) -> void:
	if client:
		client.on_placed(entry)


@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_time(world_time: float, day: int, hour: float) -> void:
	if client:
		client.on_time(world_time, day, hour)


# --- RPCs: chat --------------------------------------------------------------------------------

## Sends a chat line (any role).
func say(text: String) -> void:
	text = text.strip_edges().substr(0, 200)
	if text == "" or not is_online():
		return
	if is_server():
		server.broadcast_chat(player_name, text)
	else:
		c2s_chat.rpc_id(1, text)


@rpc("any_peer", "call_remote", "reliable")
func c2s_chat(text: String) -> void:
	if server:
		server.on_chat(sender(), text)


@rpc("authority", "call_remote", "reliable")
func s2c_chat(from: String, text: String) -> void:
	chat_received.emit(from, text)
