class_name MonsterModel
extends Node3D
## Visual host for Monster: builds a humanoid rig (HumanoidModel with monster
## gear) or a beast rig (BeastModel) from the monster's look, and forwards the
## animation calls Enemy/Monster make. Also handles hit flash and the red
## telegraph glow for dangerous attacks.

const BEASTS := [&"wisp", &"crawler", &"thornmaw", &"wolf", &"scorpion", &"crab", &"deer", &"rabbit"]

var rig: Node3D
var _look: StringName = &""
var _flash := 0.0
var _telegraph := false
var _alert: Label3D


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
	if rig:
		rig.play_attack(anim, windup, active, recovery)


func set_telegraph(on: bool) -> void:
	_telegraph = on
	_update_overlay()


func flash() -> void:
	_flash = 0.1
	_update_overlay()


func _update_overlay() -> void:
	var mat: Material = Materials.hit_flash() if _flash > 0.0 else (Materials.danger_glow() if _telegraph else null)
	for m in _meshes():
		(m as MeshInstance3D).material_overlay = mat


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_update_overlay()


func show_alert(duration: float = 0.7) -> void:
	if _alert == null:
		return
	_alert.visible = true
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if is_instance_valid(_alert):
			_alert.visible = false)


func play_death() -> void:
	set_telegraph(false)
	if rig:
		rig.play_death()


func reset_pose() -> void:
	set_telegraph(false)
	if rig:
		rig.reset_pose()
		if rig is HumanoidModel:
			(rig as HumanoidModel)._root.rotation = Vector3.ZERO
			(rig as HumanoidModel)._root.position = Vector3.ZERO
