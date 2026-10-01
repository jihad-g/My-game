class_name BlueprintHologram
extends StaticBody3D
## One planned piece of a ConstructionSite: a see-through blue (ready) or red
## (blocked) ghost. Press F on it to build that piece by hand. It doesn't block
## movement (interactable layer only).

var site: ConstructionSite
var index := -1
var data: BuildPieceData

var _mesh := MeshInstance3D.new()
var _blocked := false

static var _ok_mat: StandardMaterial3D
static var _bad_mat: StandardMaterial3D


static func material(blocked: bool) -> StandardMaterial3D:
	if _ok_mat == null:
		_ok_mat = StandardMaterial3D.new()
		_ok_mat.albedo_color = Color(0.35, 0.7, 1.0, 0.32)
		_bad_mat = StandardMaterial3D.new()
		_bad_mat.albedo_color = Color(1.0, 0.3, 0.25, 0.32)
		for m in [_ok_mat, _bad_mat]:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bad_mat if blocked else _ok_mat


func setup(p_data: BuildPieceData) -> void:
	data = p_data
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	_mesh.mesh = BuildMeshes.get_mesh(data.mesh)
	_mesh.material_override = material(false)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.collision_size.max(Vector3(0.4, 0.4, 0.4))
	cs.shape = box
	cs.position = data.collision_center
	add_child(cs)


func set_blocked(on: bool) -> void:
	_blocked = on
	_mesh.material_override = material(on)


func is_interactable() -> bool:
	return visible and site != null


func get_interact_text() -> String:
	if site == null or index < 0:
		return ""
	var e: Dictionary = site.entries[index]
	if e.reason != "":
		return "%s: %s" % [data.display_name, e.reason]
	return "Build %s (%s)" % [data.display_name, ", ".join(data.cost_lines())]


func interact(_player: Node) -> void:
	if site == null:
		return
	var why := site.build_entry(index)
	if why != "":
		Events.toast.emit(why, Color(1, 0.7, 0.5))
