class_name BoarModel
extends Node3D
## Blocky quadruped model for the Thornback Boar with procedural animation.

@export var body_color := Color(0.46, 0.3, 0.2)
@export var belly_color := Color(0.62, 0.45, 0.32)
@export var thorn_color := Color(0.42, 0.55, 0.3)
@export var tusk_color := Color(0.96, 0.93, 0.82)

var _root: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _parts: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []
var _alert_label: Label3D
var _phase := 0.0
var _move := 0.0
var _flash := 0.0
var _telegraph := false
var _exposed := false
var _t := 0.0


func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)
	# Body
	_part(_root, Vector3(0, 0.75, 0), Vector3(0.9, 0.7, 1.4), body_color)
	_part(_root, Vector3(0, 0.45, 0.05), Vector3(0.8, 0.12, 1.2), belly_color)
	# Thorny back ridge
	for k in 5:
		var z := -0.5 + k * 0.25
		_part(_root, Vector3(0, 1.18 + (0.05 if k % 2 == 0 else 0.0), z), Vector3(0.14, 0.26, 0.14), thorn_color,
			Basis(Vector3.RIGHT, -0.5))
		_part(_root, Vector3(0.28, 1.08, z + 0.1), Vector3(0.1, 0.18, 0.1), thorn_color * 0.9, Basis(Vector3.FORWARD, 0.5))
		_part(_root, Vector3(-0.28, 1.08, z + 0.1), Vector3(0.1, 0.18, 0.1), thorn_color * 0.9, Basis(Vector3.FORWARD, -0.5))
	# Head (pivot at neck)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.8, 0.7)
	_root.add_child(_head)
	_part(_head, Vector3(0, 0.0, 0.25), Vector3(0.62, 0.55, 0.5), body_color * 1.05)
	_part(_head, Vector3(0, -0.08, 0.56), Vector3(0.36, 0.28, 0.16), Color(0.85, 0.55, 0.55))  # snout
	_part(_head, Vector3(0.22, -0.12, 0.55), Vector3(0.07, 0.24, 0.07), tusk_color, Basis(Vector3.RIGHT, -0.4))
	_part(_head, Vector3(-0.22, -0.12, 0.55), Vector3(0.07, 0.24, 0.07), tusk_color, Basis(Vector3.RIGHT, -0.4))
	_part(_head, Vector3(0.2, 0.3, 0.1), Vector3(0.12, 0.18, 0.08), body_color * 0.8)  # ears
	_part(_head, Vector3(-0.2, 0.3, 0.1), Vector3(0.12, 0.18, 0.08), body_color * 0.8)
	_eyes.append(_part(_head, Vector3(0.17, 0.1, 0.505), Vector3(0.08, 0.08, 0.02), Color(0.08, 0.05, 0.05)))
	_eyes.append(_part(_head, Vector3(-0.17, 0.1, 0.505), Vector3(0.08, 0.08, 0.02), Color(0.08, 0.05, 0.05)))
	# Legs (pivot at hip)
	for p: Vector3 in [Vector3(0.3, 0.45, 0.45), Vector3(-0.3, 0.45, 0.45), Vector3(0.3, 0.45, -0.45), Vector3(-0.3, 0.45, -0.45)]:
		var leg := Node3D.new()
		leg.position = p
		_root.add_child(leg)
		_part(leg, Vector3(0, -0.22, 0), Vector3(0.2, 0.46, 0.22), body_color * 0.85)
		_part(leg, Vector3(0, -0.42, 0.02), Vector3(0.22, 0.08, 0.26), Color(0.2, 0.15, 0.12))
		_legs.append(leg)
	_alert_label = Label3D.new()
	_alert_label.text = "!"
	_alert_label.font_size = 96
	_alert_label.outline_size = 18
	_alert_label.modulate = Color(1, 0.85, 0.2)
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.position = Vector3(0, 2.3, 0)
	_alert_label.pixel_size = 0.006
	_alert_label.visible = false
	add_child(_alert_label)


func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, size, color)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.position = pos
	mi.basis = basis
	parent.add_child(mi)
	_parts.append(mi)
	return mi


func set_locomotion(speed: float, delta: float) -> void:
	_move = lerpf(_move, clampf(speed / 5.0, 0.0, 2.0), 1.0 - exp(-10.0 * delta))


func set_telegraph(on: bool) -> void:
	_telegraph = on
	_update_overlay()


func set_exposed(on: bool) -> void:
	_exposed = on


func show_alert(duration: float = 0.7) -> void:
	_alert_label.visible = true
	get_tree().create_timer(duration, false).timeout.connect(func() -> void: _alert_label.visible = false)


func play_bite() -> void:
	var tw := create_tween()
	tw.tween_property(_head, "rotation:x", 0.5, 0.12)
	tw.tween_property(_head, "rotation:x", -0.35, 0.08)
	tw.tween_property(_head, "rotation:x", 0.0, 0.25)


func flash() -> void:
	_flash = 0.1
	_update_overlay()


func play_death() -> void:
	set_telegraph(false)
	_alert_label.visible = false
	var tw := create_tween()
	tw.tween_property(_root, "rotation:z", PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "position:y", -0.1, 0.45)


func reset_pose() -> void:
	_root.rotation = Vector3.ZERO
	_root.position = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	_telegraph = false
	_exposed = false
	_flash = 0.0
	_alert_label.visible = false
	_update_overlay()


func _update_overlay() -> void:
	var mat: Material = null
	if _flash > 0.0:
		mat = Materials.hit_flash()
	elif _telegraph:
		mat = Materials.danger_glow()
	for p in _parts:
		p.material_overlay = mat


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_update_overlay()
	_phase += delta * (5.0 + 9.0 * _move) * (1.0 if _move > 0.05 else 0.0)
	var swing := sin(_phase) * 0.7 * minf(_move, 1.2)
	for i in _legs.size():
		_legs[i].rotation.x = swing if i in [0, 3] else -swing
	if _telegraph:
		# Scraping the ground: rapid shake and lowered head.
		_root.position.x = sin(_t * 60.0) * 0.04
		_head.rotation.x = 0.35
		_legs[0].rotation.x = sin(_t * 18.0) * 0.8
	elif _exposed:
		_root.position.x = 0.0
		_root.position.y = sin(_t * 9.0) * 0.03 - 0.05  # panting
		_head.rotation.x = 0.25
	else:
		_root.position.x = 0.0
		if _root.rotation.z == 0.0:
			_root.position.y = absf(sin(_phase)) * 0.05 * minf(_move, 1.0)
			# Idle: breathing and sniffing about; running: head bobs with the gait.
			var idle := 1.0 - clampf(_move * 3.0, 0.0, 1.0)
			_root.scale = Vector3(1.0, 1.0 + sin(_t * 2.6) * 0.025 * idle, 1.0)
			_head.rotation.y = sin(_t * 0.7) * sin(_t * 0.23) * 0.35 * idle
			_head.rotation.x = sin(_phase * 2.0) * 0.08 * minf(_move, 1.0) + sin(_t * 5.0) * 0.04 * idle
