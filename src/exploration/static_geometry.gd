class_name StaticGeometry
## Merges placed pieces ({mesh, xform, box_size, box_center, fade, glow}) into
## a few meshes + one collision body. `merge()` is pure array work (worker-safe);
## `attach()` creates the nodes on the main thread.


## `tile` > 0 (Milestone 36): the meshes are split into tiles of that many metres
## ("solid@x_z"), so a town is many small meshes - each is quick to attach and
## the renderer can skip the ones off screen.
static func merge(statics: Array, boxes: Array, roofs: Dictionary = {}, color: Color = Color.WHITE, tile: float = 0.0) -> Dictionary:
	var groups := {}
	var out_boxes := []
	for s in statics:
		var key: String = "glow" if s.get("glow", false) else ("walls" if s.get("fade", false) else "solid")
		if tile > 0.0:
			var o: Vector3 = (s.xform as Transform3D).origin
			key = "%s@%d_%d" % [key, floori(o.x / tile), floori(o.z / tile)]
		if not groups.has(key):
			groups[key] = BlockMesh.new()
		var g: BlockMesh = groups[key]
		g.xform = s.xform
		if s.has("vox"):
			VillageArchitecture.emit(g, s.vox)  # Milestone 40: voxel building shells
		else:
			BuildMeshes.build_into(g, s.mesh, color)
		var size: Vector3 = s.get("box_size", Vector3.ZERO)
		if size != Vector3.ZERO:
			out_boxes.append([size, (s.xform as Transform3D) * Transform3D(Basis.IDENTITY, s.get("box_center", Vector3.ZERO))])
	for b in boxes:
		out_boxes.append([b.size, b.xform])
	var arrays := {}
	for k in groups:
		if groups[k].has_boxes():
			arrays[k] = groups[k].to_arrays()
		var cards: Array = groups[k].card_arrays()
		if not cards.is_empty():
			arrays["cards_%s" % k] = cards  # v0.26.0: crops/plants on cut-out cards
	for idx in roofs:
		var rb := BlockMesh.new()
		for r in roofs[idx]:
			rb.xform = r.xform
			if r.has("vox"):
				VillageArchitecture.emit(rb, r.vox)
			else:
				BuildMeshes.build_into(rb, r.mesh)
		if not rb.has_boxes():
			continue
		arrays["roof_%d" % idx] = rb.to_arrays()
	return {"arrays": arrays, "boxes": out_boxes}


## Adds meshes and collision under `parent`. Returns roof index -> MeshInstance3D.
## (All at once; PoiSite and SettlementSite use the step functions below to
## spread the work over several frames - Milestone 36.)
static func attach(parent: Node3D, merged: Dictionary, layer: int = Layers.BUILDING) -> Dictionary:
	var roofs := {}
	for key: String in merged.arrays:
		var mi := attach_mesh(parent, key, merged.arrays[key])
		if key.begins_with("roof_"):
			roofs[int(key.substr(5))] = mi
	var body := make_body(parent, layer)
	add_boxes(body, merged.boxes, 0, merged.boxes.size(), {})
	return roofs


## One merged mesh (surface arrays) as a MeshInstance3D under `parent`.
static func attach_mesh(parent: Node3D, key: String, arrays: Array) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = key.capitalize().replace(" ", "")
	mi.mesh = mesh
	var kind := key.get_slice("@", 0)
	if kind.begins_with("cards_"):
		mi.material_override = Materials.sprite(0.25)
	elif kind == "walls":
		mi.material_override = Materials.vertex_color_occluder()
	elif kind == "glow":
		mi.material_override = Materials.vertex_color_emissive()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mi.material_override = Materials.vertex_color()
	parent.add_child(mi)
	return mi


## The (empty) static body the collision boxes go on.
static func make_body(parent: Node3D, layer: int = Layers.BUILDING) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = layer
	body.collision_mask = 0
	parent.add_child(body)
	return body


## Adds boxes [from, to) ([size, transform] pairs) to `body`. Shapes go straight
## onto the body (shape owners) instead of one CollisionShape3D node each, which
## was most of the cost. `shapes` caches one BoxShape3D per size.
static func add_boxes(body: StaticBody3D, boxes: Array, from: int, to: int, shapes: Dictionary) -> void:
	for i in range(from, to):
		var b: Array = boxes[i]
		var size: Vector3 = b[0]
		var key := size.snapped(Vector3(0.001, 0.001, 0.001))
		if not shapes.has(key):
			var box := BoxShape3D.new()
			box.size = size
			shapes[key] = box
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, shapes[key])
		body.shape_owner_set_transform(owner_id, b[1])
