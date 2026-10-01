class_name WeaponTrail
extends MeshInstance3D
## Fading ribbon behind a swinging weapon (Milestone 10). Samples the weapon's
## grip and tip in world space every frame while `active`, and keeps drawing
## the old samples until they fade out.

const MAX_SAMPLES := 14
const LIFE := 0.16

var base: Node3D
var tip: Node3D
var active := false
var color := Color(1, 1, 1)

var _samples: Array = []  # [grip: Vector3, tip: Vector3, age: float]
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat


func _process(delta: float) -> void:
	for s in _samples:
		s[2] += delta
	while not _samples.is_empty() and _samples[0][2] > LIFE:
		_samples.pop_front()
	if active and is_instance_valid(base) and is_instance_valid(tip) and base.is_inside_tree():
		var grip := base.global_position.lerp(tip.global_position, 0.35)
		_samples.append([grip, tip.global_position, 0.0])
		if _samples.size() > MAX_SAMPLES:
			_samples.pop_front()
	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in _samples:
		var a := clampf(1.0 - s[2] / LIFE, 0.0, 1.0) * 0.55
		_mesh.surface_set_color(Color(color.r, color.g, color.b, a * 0.2))
		_mesh.surface_add_vertex(s[0])
		_mesh.surface_set_color(Color(color.r, color.g, color.b, a))
		_mesh.surface_add_vertex(s[1])
	_mesh.surface_end()
