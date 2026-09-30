class_name EnemyHealthBar
extends Node3D
## Billboard health bar above an enemy. Hidden until damaged or targeted.

const WIDTH := 1.1
const HEIGHT := 0.12

var _bg := MeshInstance3D.new()
var _fill := MeshInstance3D.new()
var _fill_mesh := QuadMesh.new()
var _show_time := 0.0
var force_visible := false


func _ready() -> void:
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(WIDTH + 0.06, HEIGHT + 0.06)
	_bg.mesh = bg_mesh
	_bg.material_override = Materials.overlay_color(Color(0.08, 0.05, 0.05, 0.85))
	_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bg)
	_fill_mesh.size = Vector2(WIDTH, HEIGHT)
	_fill.mesh = _fill_mesh
	var fill_mat := Materials.overlay_color(Color(0.9, 0.2, 0.2)).duplicate() as StandardMaterial3D
	fill_mat.render_priority = 11
	_fill.material_override = fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
	visible = false


func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_fill_mesh.size = Vector2(maxf(WIDTH * ratio, 0.001), HEIGHT)
	_fill_mesh.center_offset = Vector3(-(WIDTH - WIDTH * ratio) * 0.5, 0, 0)
	_show_time = 4.0


func hide_now() -> void:
	_show_time = 0.0
	force_visible = false
	visible = false


func _process(delta: float) -> void:
	_show_time -= delta
	visible = force_visible or _show_time > 0.0
