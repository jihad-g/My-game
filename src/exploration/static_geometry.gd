class_name StaticGeometry
## Merges placed pieces ({mesh, xform, box_size, box_center, fade, glow}) into
## a few meshes + one collision body. `merge()` is pure array work (worker-safe);
## `attach()` creates the nodes on the main thread.


static func merge(statics: Array, boxes: Array, roofs: Dictionary = {}, color: Color = Color.WHITE) -> Dictionary:
	var groups := {"solid": BlockMesh.new(), "walls": BlockMesh.new(), "glow": BlockMesh.new()}
	var out_boxes := []
	for s in statics:
		var g: BlockMesh = groups["glow"] if s.get("glow", false) else (groups["walls"] if s.get("fade", false) else groups["solid"])
		g.xform = s.xform
		BuildMeshes.build_into(g, s.mesh, color)
		var size: Vector3 = s.get("box_size", Vector3.ZERO)
		if size != Vector3.ZERO:
			out_boxes.append([size, (s.xform as Transform3D) * Transform3D(Basis.IDENTITY, s.get("box_center", Vector3.ZERO))])
	for b in boxes:
		out_boxes.append([b.size, b.xform])
	var arrays := {}
	for k in groups:
		if not groups[k].is_empty():
			arrays[k] = groups[k].to_arrays()
	for idx in roofs:
		var rb := BlockMesh.new()
		for r in roofs[idx]:
			rb.xform = r.xform
			BuildMeshes.build_into(rb, r.mesh)
		arrays["roof_%d" % idx] = rb.to_arrays()
	return {"arrays": arrays, "boxes": out_boxes}


## Adds meshes and collision under `parent`. Returns roof index -> MeshInstance3D.
static func attach(parent: Node3D, merged: Dictionary, layer: int = Layers.BUILDING) -> Dictionary:
	var roofs := {}
	var mats := {"solid": Materials.vertex_color(), "walls": Materials.vertex_color_occluder(), "glow": Materials.vertex_color_emissive()}
	for key: String in merged.arrays:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged.arrays[key])
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize().replace(" ", "")
		mi.mesh = mesh
		mi.material_override = mats.get(key, Materials.vertex_color())
		if key == "glow":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		if key.begins_with("roof_"):
			roofs[int(key.substr(5))] = mi
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = layer
	body.collision_mask = 0
	var shapes := {}
	for b in merged.boxes:
		var size: Vector3 = b[0]
		var key := size.snapped(Vector3(0.001, 0.001, 0.001))
		if not shapes.has(key):
			var box := BoxShape3D.new()
			box.size = size
			shapes[key] = box
		var cs := CollisionShape3D.new()
		cs.shape = shapes[key]
		cs.transform = b[1]
		body.add_child(cs)
	parent.add_child(body)
	return roofs
