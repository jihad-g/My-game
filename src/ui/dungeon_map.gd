class_name DungeonMap
extends Control
## Milestone 31: the dungeon mini-map in the top-right corner. It only shows the
## rooms and corridors you have explored (DungeonInstance.explored), so it fills in
## as you walk. Markers: the exit portal, the stairs or boss arena, locked gates,
## puzzle rooms, the Keeper (once you have seen its room) and you.

const SIZE := Vector2(210, 170)
const PAD := 8.0

const COL_BG := Color(0.03, 0.03, 0.05, 0.78)
const COL_ROOM := Color(0.42, 0.40, 0.36)
const COL_CORRIDOR := Color(0.30, 0.29, 0.27)
const COL_SECRET := Color(0.55, 0.45, 0.75)
const COL_EXIT := Color(0.35, 1.0, 0.6)
const COL_STAIRS := Color(0.45, 0.75, 1.0)
const COL_BOSS := Color(1.0, 0.3, 0.25)
const COL_GATE := Color(1.0, 0.8, 0.25)
const COL_PUZZLE := Color(0.8, 0.5, 1.0)
const COL_KEEPER := Color(1.0, 0.55, 0.15)
const COL_PLAYER := Color(1, 1, 1)

var dungeon: DungeonInstance
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE.x - 16
	offset_right = -16
	offset_top = 118
	offset_bottom = 118 + SIZE.y
	visible = false


func _process(delta: float) -> void:
	var w := World.instance
	var d: DungeonInstance = w.dungeon if w else null
	if d != dungeon:
		dungeon = d
	visible = dungeon != null and is_instance_valid(dungeon)
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.1
		queue_redraw()


## Plan bounds (local metres) -> the scale and offset that fit them in the box.
func _fit() -> Array:
	var b := Rect2()
	var first := true
	for r in dungeon.plan.rooms:
		var rr: Rect2i = r.rect
		var rf := Rect2(rr.position, rr.size)
		b = rf if first else b.merge(rf)
		first = false
	var inner := SIZE - Vector2(PAD, PAD) * 2.0
	var s: float = minf(inner.x / maxf(b.size.x, 1.0), inner.y / maxf(b.size.y, 1.0))
	var off := Vector2(PAD, PAD) + (inner - b.size * s) * 0.5 - b.position * s
	return [s, off]


func to_map(local: Vector3) -> Vector2:
	var f := _fit()
	return Vector2(local.x, local.z) * float(f[0]) + (f[1] as Vector2)


## How many rooms the map shows (for tests and the debug overlay).
func shown_rooms() -> int:
	return dungeon.explored.size() if dungeon else 0


func _draw() -> void:
	if dungeon == null or not is_instance_valid(dungeon):
		return
	var plan := dungeon.plan
	draw_rect(Rect2(Vector2.ZERO, SIZE), COL_BG)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.6, 0.5, 0.35, 0.8), false, 1.5)
	var f := _fit()
	var s: float = f[0]
	var off: Vector2 = f[1]
	var rect_of := func(r: Rect2i) -> Rect2:
		return Rect2(Vector2(r.position) * s + off, Vector2(r.size) * s)
	for ci in plan.corridors.size():
		if dungeon.explored_corridors.has(ci):
			draw_rect(rect_of.call(plan.corridors[ci]), COL_CORRIDOR)
	for i in plan.rooms.size():
		if not dungeon.explored.has(i):
			continue
		var room: Dictionary = plan.rooms[i]
		var col := COL_SECRET if room.type == DungeonPlan.Room.SECRET else COL_ROOM
		draw_rect(rect_of.call(room.rect), col)
		var c: Vector2 = (rect_of.call(room.rect) as Rect2).get_center()
		match room.type:
			DungeonPlan.Room.START:
				draw_circle(c, 3.5, COL_EXIT)
			DungeonPlan.Room.END:
				_stairs_icon(c)
			DungeonPlan.Room.BOSS:
				_skull_icon(c)
			DungeonPlan.Room.PUZZLE:
				var solved: bool = dungeon.puzzles.has(i) and dungeon.puzzles[i].cage.is_open
				draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), COL_PUZZLE, not solved, 1.5)
	for g in dungeon.gates:
		if is_instance_valid(g) and not g.is_open and _seen(g.position):
			var p := Vector2(g.position.x, g.position.z) * s + off
			var half := Vector2(0, g.size.z * s * 0.5) if g.horizontal else Vector2(g.size.x * s * 0.5, 0)
			draw_line(p - half, p + half, COL_GATE, 2.5)
	var k := dungeon.keeper
	if k and is_instance_valid(k) and not k.is_dead:
		var kl := dungeon.to_local(k.global_position)
		if dungeon.explored.has(plan.room_at(kl)):
			draw_circle(Vector2(kl.x, kl.z) * s + off, 3.0, COL_KEEPER)
	var w := World.instance
	if w and w.player:
		var lp := dungeon.to_local(w.player.global_position)
		var pp := Vector2(lp.x, lp.z) * s + off
		var cam := get_viewport().get_camera_3d()
		var fwd: Vector3 = -cam.global_transform.basis.z if cam else Vector3.FORWARD
		var dir := Vector2(fwd.x, fwd.z).normalized() if Vector2(fwd.x, fwd.z).length() > 0.01 else Vector2(0, -1)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp + dir * 6.0, pp - dir * 3.5 + side * 3.5, pp - dir * 3.5 - side * 3.5]), COL_PLAYER)


## True when a local point sits in an explored room or corridor (gates sit on the seam).
func _seen(local: Vector3) -> bool:
	var c := Vector2(local.x, local.z)
	for i in dungeon.explored:
		var rr: Rect2i = dungeon.plan.rooms[i].rect
		if Rect2(rr.position, rr.size).grow(0.6).has_point(c):
			return true
	return false


func _stairs_icon(c: Vector2) -> void:
	for k in 3:
		draw_rect(Rect2(c + Vector2(-4 + k * 2.5, 2 - k * 2.5), Vector2(2.5, 2.5 + k * 2.5)), COL_STAIRS)


func _skull_icon(c: Vector2) -> void:
	draw_circle(c, 4.0, COL_BOSS)
	draw_circle(c + Vector2(-1.5, -0.5), 1.0, Color.BLACK)
	draw_circle(c + Vector2(1.5, -0.5), 1.0, Color.BLACK)
