class_name PressurePlate
extends Node3D
## Milestone 31: a stone plate in the floor. Stepping on it clicks it down and
## emits `pressed` (the cage it is wired to opens for a few seconds).

signal pressed

const RADIUS := 0.75
var is_down := false
var _top: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"pressure_plates")
	var b := BlockMesh.new()
	b.box(Vector3(0, 0.02, 0), Vector3(1.4, 0.04, 1.4), Color(0.3, 0.3, 0.33))
	var base := MeshInstance3D.new()
	base.mesh = b.commit()
	add_child(base)
	var tb := BlockMesh.new()
	tb.box(Vector3(0, 0.08, 0), Vector3(1.1, 0.1, 1.1), Color(0.55, 0.52, 0.45))
	tb.box(Vector3(0, 0.135, 0), Vector3(0.5, 0.01, 0.5), Color(0.9, 0.75, 0.3))
	_top = MeshInstance3D.new()
	_top.mesh = tb.commit()
	add_child(_top)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	var w := World.instance
	if w == null or w.player == null:
		return
	var p := w.player.global_position
	var on := Vector2(p.x - global_position.x, p.z - global_position.z).length() < RADIUS and absf(p.y - global_position.y) < 1.0
	if on and not is_down:
		is_down = true
		_top.position.y = -0.07
		Audio.play_at(&"block", global_position, -4.0)
		pressed.emit()
	elif not on and is_down:
		is_down = false
		_top.position.y = 0.0
