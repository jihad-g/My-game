class_name RemotePlayer
extends Node3D
## Another player in a multiplayer session (Milestone 11): a puppet that
## follows the state packets of its owner.
##
## Snapshots are buffered and drawn NetProtocol.INTERP_DELAY in the past,
## interpolating between the two around that moment (briefly extrapolating if
## packets are late), so movement stays smooth at 20 updates per second and
## jitter. Animation events (swings, dodges, casts) arrive reliably and are
## replayed on the same HumanoidModel the local player uses.

const ANIM_EVENTS := ["attack", "dodge", "cast", "death", "respawn", "look", "pose"]
const BUFFER := 24

var peer_id := 0
var player_name := ""
var class_id: StringName = &"knight"
var model: HumanoidModel
var layer := 0
var health_ratio := 1.0
var flags := 0

var _label := Label3D.new()
var _snaps: Array = []  # {t, pos, yaw, move, flags, layer, hp}


func setup(p_peer: int, p_name: String, p_class: StringName) -> void:
	peer_id = p_peer
	player_name = p_name
	class_id = p_class
	name = "Remote_%d" % p_peer


func _ready() -> void:
	add_to_group(&"remote_players")
	model = HumanoidModel.new()
	add_child(model)
	var c := ClassRegistry.get_class_data(class_id)
	if c:
		model.set_appearance(c)
	_label.text = player_name
	_label.position = Vector3(0, 2.35, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.modulate = Color(0.75, 0.9, 1.0)
	_label.no_depth_test = true
	add_child(_label)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func snap_to(pos: Vector3, yaw: float, p_layer: int) -> void:
	_snaps.clear()
	push_state({"pos": pos, "yaw": yaw, "move": 0.0, "flags": 0, "layer": p_layer, "hp": 1.0})


func push_state(s: Dictionary) -> void:
	var e := s.duplicate()
	e.t = _now()
	# A teleport (or a big jump) restarts interpolation.
	if not _snaps.is_empty() and (int(s.get("flags", 0)) & NetProtocol.F_TELEPORT != 0
			or (_snaps.back().pos as Vector3).distance_to(s.pos) > 30.0):
		_snaps.clear()
	_snaps.append(e)
	if _snaps.size() > BUFFER:
		_snaps.pop_front()


## Weapon and outfit (Milestone 14): `outfit` is a comma-separated list of item
## ids (unknown ids are ignored), `weapon_id` colours the weapon.
func set_equipment_look(weapon_type: StringName, shield: bool, outfit: String = "", weapon_id: String = "") -> void:
	if model:
		model.set_weapon(weapon_type, shield)
		model.set_outfit(PackedStringArray(outfit.split(",", false)), StringName(weapon_id))


## The body from a "look" event (skin, hair, style, beard). Data comes from
## another peer, so it is sanitised.
func set_body_look(body: Dictionary) -> void:
	if model:
		model.set_body(CharacterLook.sanitize(body, class_id))


## Replays an animation event from the owner.
func play_event(ev: String, args: Array) -> void:
	if model == null:
		return
	match ev:
		"attack":
			if args.size() >= 4:
				model.play_attack(StringName(String(args[0])), float(args[1]), float(args[2]), float(args[3]))
				Audio.play_at(&"swing", global_position + Vector3(0, 1, 0), -8.0)
		"dodge":
			model.play_dodge(float(args[0]) if args.size() > 0 else 0.4)
		"cast":
			model.play_cast(float(args[0]) if args.size() > 0 else 0.45)
		"pose":
			if args.size() >= 2:
				model.play_pose(StringName(String(args[0]).substr(0, 24)), clampf(float(args[1]), 0.1, 6.0))
		"death":
			model.play_death()
		"respawn":
			model.reset_pose()
		"look":
			if args.size() >= 2:
				set_equipment_look(StringName(String(args[0])), bool(args[1]),
					String(args[2]).substr(0, 400) if args.size() > 2 else "", String(args[3]).substr(0, 64) if args.size() > 3 else "")
			if args.size() > 4 and args[4] is Dictionary:
				set_body_look(args[4])


## Interpolated state at `t` (seconds, same clock as push_state).
func sample(t: float) -> Dictionary:
	if _snaps.is_empty():
		return {}
	if _snaps.size() == 1 or t <= _snaps[0].t:
		return _snaps[0]
	for i in range(_snaps.size() - 1, 0, -1):
		var a: Dictionary = _snaps[i - 1]
		var b: Dictionary = _snaps[i]
		if t >= a.t and t <= b.t:
			var k: float = (t - float(a.t)) / maxf(float(b.t) - float(a.t), 0.0001)
			return {"pos": (a.pos as Vector3).lerp(b.pos, k), "yaw": lerp_angle(a.yaw, b.yaw, k),
				"move": lerpf(a.move, b.move, k), "flags": b.flags, "layer": b.layer, "hp": b.hp}
	# Late packets: extrapolate a little along the last movement, then hold.
	var last: Dictionary = _snaps.back()
	var prev: Dictionary = _snaps[_snaps.size() - 2]
	var over: float = minf(t - float(last.t), 0.2)
	var vel: Vector3 = ((last.pos as Vector3) - (prev.pos as Vector3)) / maxf(float(last.t) - float(prev.t), 0.0001)
	return {"pos": (last.pos as Vector3) + vel * over, "yaw": last.yaw, "move": last.move, "flags": last.flags,
		"layer": last.layer, "hp": last.hp}


func _process(delta: float) -> void:
	var s := sample(_now() - NetProtocol.INTERP_DELAY)
	if s.is_empty():
		return
	global_position = s.pos
	layer = int(s.layer)
	flags = int(s.flags)
	health_ratio = float(s.hp)
	model.rotation.y = lerp_angle(model.rotation.y, float(s.yaw), 1.0 - exp(-20.0 * delta))
	model.set_locomotion(float(s.move), delta)
	model.set_blocking(flags & NetProtocol.F_BLOCKING != 0)
	model.set_air_state(flags & NetProtocol.F_AIRBORNE != 0, flags & NetProtocol.F_SWIMMING != 0)
	var w := World.instance
	visible = w == null or (w.layer == layer and w.dungeon == null)
	_label.text = player_name if flags & NetProtocol.F_DEAD == 0 else "%s (down)" % player_name
