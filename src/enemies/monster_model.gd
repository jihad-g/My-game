class_name MonsterModel
extends Node3D
## Visual host for Monster: builds a humanoid rig (HumanoidModel with monster
## gear) or a beast rig (BeastModel) from the monster's look, and forwards the
## animation calls Enemy/Monster make. Also handles hit flash and the red
## telegraph glow for dangerous attacks.

## Milestone 19: animation events, sent to co-op guests by the host (NetCombat).
signal net_event(method: StringName, args: Array)
## Milestone 32: an attack's damage just landed (the hit frame).
signal struck

const BEASTS := [&"wisp", &"crawler", &"thornmaw", &"wolf", &"scorpion", &"crab", &"deer", &"rabbit",
	# Milestone 27
	&"fox", &"stag", &"hedgehog", &"cat", &"bee", &"phoenix", &"candle_skull", &"spider", &"pumpkin", &"acorn"]

var rig: Node3D
var _look: StringName = &""
var _flash := 0.0
var _telegraph := false
var _alert: Label3D
## Milestone 32: when the current attack's strike pose is due and when the last
## hit frame happened (msec), and the shake before big attacks.
const BIG_WINDUP := 0.5
var strike_ms := 0
var last_hit_ms := 0
## Game-time seconds until the strike pose (counts down in physics ticks), and
## how far off the last hit frame was from it (0 = exactly on the strike).
var strike_left := 0.0
var strike_error := 0.0
var _tremble := 0.0


func build(data: MonsterData) -> void:
	if data.look == _look and rig:
		scale = Vector3.ONE * data.model_scale
		return
	_look = data.look
	for c in get_children():
		c.free()
	if data.look in BEASTS:
		var b := BeastModel.new()
		add_child(b)
		b.build(data.look, data.tint, data.accent)
		rig = b
	else:
		var h := HumanoidModel.new()
		add_child(h)
		h.set_monster_look(data.look, data.tint, data.accent)
		rig = h
	scale = Vector3.ONE * data.model_scale
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.modulate = Color(1, 0.3, 0.2)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position.y = 2.6
	_alert.visible = false
	add_child(_alert)


func _meshes() -> Array:
	var out := []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out


func set_locomotion(speed: float, delta: float) -> void:
	if rig:
		rig.set_locomotion(speed / 5.0, delta)


func play_attack(anim: StringName, windup: float, active: float, recovery: float) -> void:
	net_event.emit(&"play_attack", [anim, windup, active, recovery])
	strike_ms = Time.get_ticks_msec() + int(windup * 1000.0)
	strike_left = windup
	# Big attacks: the whole body shakes with effort until the strike.
	_tremble = windup if windup >= BIG_WINDUP else 0.0
	if rig:
		rig.play_attack(anim, windup, active, recovery)


## The moment an attack's damage lands. Beasts jolt; the strike pose is reached
## at this same moment because the damage waits for the end of the wind-up.
func hit_frame() -> void:
	net_event.emit(&"hit_frame", [])
	last_hit_ms = Time.get_ticks_msec()
	strike_error = strike_left
	_tremble = 0.0
	if rig and rig.has_method("on_hit_frame"):
		rig.on_hit_frame()
	struck.emit()


func _physics_process(delta: float) -> void:
	if strike_left > -10.0:
		strike_left -= delta


func is_trembling() -> bool:
	return _tremble > 0.0


func set_telegraph(on: bool) -> void:
	net_event.emit(&"set_telegraph", [on])
	_telegraph = on
	_update_overlay()


func flash() -> void:
	_flash = 0.1
	_update_overlay()


## Milestone 18b: elites are outlined in their affix colour (hit flash and the
## danger glow are shown instead while they play).
var _outline := Color(0, 0, 0, 0)


func set_outline(color: Color) -> void:
	_outline = color
	_update_overlay()


func _update_overlay() -> void:
	var mat: Material = Materials.hit_flash() if _flash > 0.0 else (Materials.danger_glow() if _telegraph else null)
	if mat == null and _outline.a > 0.0:
		mat = Materials.outline(_outline)
	for m in _meshes():
		(m as MeshInstance3D).material_overlay = mat


func _process(delta: float) -> void:
	if _tremble > 0.0 and rig:
		_tremble -= delta
		rig.position.x = randf_range(-0.035, 0.035) if _tremble > 0.0 else 0.0
		rig.position.z = randf_range(-0.02, 0.02) if _tremble > 0.0 else 0.0
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_update_overlay()


func show_alert(duration: float = 0.7) -> void:
	net_event.emit(&"show_alert", [duration])
	if _alert == null:
		return
	_alert.visible = true
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if is_instance_valid(_alert):
			_alert.visible = false)


## Milestone 18b: hit-stop and flinches for humanoid and beast bodies.
func freeze(seconds: float) -> void:
	net_event.emit(&"freeze", [seconds])
	if rig and rig.has_method("freeze"):
		rig.freeze(seconds)
	elif rig:
		rig.set_process(false)
		get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(rig):
				rig.set_process(true))


func play_flinch(strength: float, side: float) -> void:
	net_event.emit(&"play_flinch", [strength, side])
	if rig and rig.has_method("play_flinch"):
		rig.play_flinch(strength, side)
	elif rig:
		# Beasts: the body rocks back and to the side.
		var tw := rig.create_tween()
		tw.tween_property(rig, "rotation", Vector3(-0.3 * strength, 0.0, side * 0.2 * strength), 0.07).set_ease(Tween.EASE_OUT)
		tw.tween_property(rig, "rotation", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_QUAD)


func play_death() -> void:
	set_telegraph(false)
	_tremble = 0.0
	if rig:
		rig.position = Vector3.ZERO
		rig.play_death()


func reset_pose() -> void:
	_outline = Color(0, 0, 0, 0)
	set_telegraph(false)
	_tremble = 0.0
	if rig:
		rig.position = Vector3.ZERO
		rig.reset_pose()
		if rig is HumanoidModel:
			(rig as HumanoidModel)._root.rotation = Vector3.ZERO
			(rig as HumanoidModel)._root.position = Vector3.ZERO
