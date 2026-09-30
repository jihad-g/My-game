class_name HitQuery
## Melee hit detection: finds physics bodies inside an arc in front of an attacker.


static func query_arc(space: PhysicsDirectSpaceState3D, origin: Vector3, facing: Vector3,
		reach: float, arc_degrees: float, mask: int, exclude: Array[RID] = []) -> Array[Node]:
	var shape := SphereShape3D.new()
	shape.radius = reach
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = mask
	params.exclude = exclude
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var results := space.intersect_shape(params, 32)
	var out: Array[Node] = []
	var flat_facing := Vector3(facing.x, 0.0, facing.z).normalized()
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	for r in results:
		var collider: Node = r.get("collider")
		if collider == null or out.has(collider):
			continue
		var to: Vector3 = (collider as Node3D).global_position - origin
		to.y = 0.0
		# Targets basically on top of us always count; otherwise check the arc.
		if to.length() > 0.4 and flat_facing.angle_to(to.normalized()) > half_arc:
			continue
		out.append(collider)
	return out
