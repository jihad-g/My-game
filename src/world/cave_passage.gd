class_name CavePassage
extends StaticBody3D
## A passage between the surface and the underground layer.
##
## On the surface it is a rocky mound with a dark opening ("cave_entrance");
## underground it is a rope ladder under a shaft of daylight ("cave_exit").
## Both exist at the same world XZ position, so travelling keeps you in place.

@export var target_layer: int = TerrainGenerator.Layer.UNDERGROUND

var key: String = ""


func setup(feature: Dictionary) -> void:
	key = feature.get("key", "")


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE | Layers.PROP
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.2
	cs.shape = shape
	cs.position.y = 0.6
	add_child(cs)
	var mi := MeshInstance3D.new()
	var b := BlockMesh.new()
	if target_layer == TerrainGenerator.Layer.UNDERGROUND:
		_build_entrance(b)
	else:
		_build_exit(b)
	mi.mesh = b.commit()
	add_child(mi)
	if target_layer == TerrainGenerator.Layer.SURFACE:
		# Daylight falling down the shaft.
		var shaft := BlockMesh.new()
		shaft.box(Vector3(0, 3.0, 0), Vector3(1.4, 6.0, 1.4), Color(1.0, 0.95, 0.7))
		var sm := shaft.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.95, 0.7, 0.18)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.surface_set_material(0, mat)
		var smi := MeshInstance3D.new()
		smi.mesh = sm
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smi)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.75)
		light.light_energy = 1.6
		light.omni_range = 7.0
		light.position.y = 3.0
		add_child(light)


func _build_entrance(b: BlockMesh) -> void:
	var rock := Color(0.5, 0.49, 0.52)
	var dark := Color(0.05, 0.04, 0.06)
	b.box(Vector3(0, 0.02, 0), Vector3(1.5, 0.06, 1.5), dark)  # the hole
	b.box(Vector3(-1.0, 0.5, 0), Vector3(0.6, 1.0, 1.8), rock)
	b.box(Vector3(1.0, 0.45, 0.1), Vector3(0.6, 0.9, 1.6), rock * 0.9)
	b.box(Vector3(0, 0.4, -1.0), Vector3(1.6, 0.8, 0.6), rock * 1.05)
	b.box(Vector3(0, 1.15, -0.9), Vector3(1.2, 0.5, 0.5), rock * 0.95)
	b.box(Vector3(0.6, 0.15, 1.0), Vector3(0.5, 0.3, 0.4), rock * 0.85)


func _build_exit(b: BlockMesh) -> void:
	var rope := Color(0.62, 0.46, 0.26)
	for side in [-0.35, 0.35]:
		b.box(Vector3(side, 2.5, 0), Vector3(0.08, 5.0, 0.08), rope)
	for k in 10:
		b.box(Vector3(0, 0.3 + k * 0.5, 0), Vector3(0.75, 0.07, 0.12), rope * 0.9)
	b.box(Vector3(0, 0.05, 0), Vector3(1.6, 0.1, 1.6), Color(0.35, 0.33, 0.3))


func get_interact_text() -> String:
	return "Enter the cave" if target_layer == TerrainGenerator.Layer.UNDERGROUND else "Climb to the surface"


func interact(_player: Node) -> void:
	if World.instance:
		World.instance.travel_to_layer(target_layer, global_position)
