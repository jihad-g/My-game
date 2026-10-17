extends SceneTree
## Checks the structure of many generated dungeon floors (no game needed):
##   godot --headless --path . -s res://tests/dungeon_audit.gd
## Prints every problem it finds and a summary.

func _init() -> void:
	var problems := {}
	var floors := 0
	for rank in 6:
		for theme in 3:
			for s in 60:
				var poi := PoiInfo.new()
				poi.kind = PoiInfo.Kind.DUNGEON
				poi.rank = rank
				poi.theme = theme
				poi.seed = 1000 + s * 7919 + rank * 31 + theme
				poi.id = "audit_%d_%d_%d" % [rank, theme, s]
				for f in DungeonPlan.FLOORS[rank]:
					var plan := DungeonPlan.generate(poi, f)
					floors += 1
					for p in check_plan(plan):
						problems[p] = int(problems.get(p, 0)) + 1
	print("floors checked: ", floors)
	for p in problems:
		print("PROBLEM x%d: %s" % [problems[p], p])
	if problems.is_empty():
		print("no problems")
	quit()


func check_plan(plan: DungeonPlan) -> Array:
	var out := []
	# Rooms must not overlap or touch other rooms' cells.
	for i in plan.rooms.size():
		for j in range(i + 1, plan.rooms.size()):
			if (plan.rooms[i].rect as Rect2i).grow(1).intersects(plan.rooms[j].rect):
				out.append("rooms overlap or touch (%s / %s)" % [plan.rooms[i].type, plan.rooms[j].type])
	# Every room reachable from the start through floor cells.
	var start := Vector2i(plan.room_center(plan.start_room).x, plan.room_center(plan.start_room).z)
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if plan.cells.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	for i in plan.rooms.size():
		var ctr := plan.room_center(i)
		if not seen.has(Vector2i(int(ctr.x), int(ctr.z))):
			out.append("room type %d unreachable" % plan.rooms[i].type)
	if seen.size() != plan.cells.size():
		out.append("floor cells not connected to the start")
	# Final floors have a boss room, others stairs.
	var types := []
	for r in plan.rooms:
		types.append(r.type)
	if plan.is_final and not types.has(DungeonPlan.Room.BOSS):
		out.append("final floor without a boss room")
	if not plan.is_final and not types.has(DungeonPlan.Room.END):
		out.append("floor without stairs")
	if plan.rooms.size() < 4:
		out.append("tiny floor (%d rooms)" % plan.rooms.size())
	if not types.has(DungeonPlan.Room.TREASURE):
		out.append("no treasure room")
	# Secret wall must sit on the corridor where it leaves the room (inside the corridor cells).
	if not plan.secret.is_empty():
		var bp: Vector3 = plan.secret.block_pos
		var cor: Rect2i = plan.secret.rect
		var on_edge := (absf(bp.x - cor.position.x) < 0.01 or absf(bp.x - cor.end.x) < 0.01 or absf(bp.z - cor.position.y) < 0.01 or absf(bp.z - cor.end.y) < 0.01)
		if not on_edge:
			out.append("secret wall not at a corridor end")
		var sr: Rect2i = plan.rooms[plan.secret.room].rect
		if sr.position.x < 0 or sr.position.y < 0:
			out.append("secret room outside the grid")
		var rot: float = plan.secret.block_rot
		var horizontal := cor.size.x > cor.size.y
		if horizontal != (absf(rot) > 0.1):
			out.append("secret wall turned the wrong way")
	else:
		out.append("no secret room")
	# Corridors connect rooms (each end touches a room).
	for cr: Rect2i in plan.corridors:
		var touching := 0
		for r in plan.rooms:
			if (r.rect as Rect2i).grow(1).intersects(cr):
				touching += 1
		if touching < 2:
			out.append("corridor touches %d rooms" % touching)
		if cr.size.x <= 0 or cr.size.y <= 0:
			out.append("empty corridor (rooms touching)")
	# Exit portal spot and stairs inside the floor.
	var exit_spot := plan.room_center(plan.start_room) + Vector3(0, 0, -2.0)
	if not plan.cells.has(Vector2i(floori(exit_spot.x), floori(exit_spot.z))):
		out.append("exit portal off the floor")
	return out
