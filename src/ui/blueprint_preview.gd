class_name BlueprintPreview
extends Control
## Top-down drawing of a blueprint for the blueprint panel (Milestone 8):
## floors as tiles, walls/doors as thick lines on cell edges, furniture as
## dots, roofs as a light hatch. North is up; the anchor cell is outlined.

var blueprint: Blueprint

const COLORS := {
	BuildPieceData.Category.FLOOR: Color(0.55, 0.45, 0.32),
	BuildPieceData.Category.WALL: Color(0.85, 0.7, 0.5),
	BuildPieceData.Category.DOOR: Color(0.45, 0.85, 0.5),
	BuildPieceData.Category.WINDOW: Color(0.55, 0.8, 1.0),
	BuildPieceData.Category.FENCE: Color(0.7, 0.55, 0.35),
	BuildPieceData.Category.ROOF: Color(0.9, 0.4, 0.3, 0.35),
	BuildPieceData.Category.DEFENSE: Color(1.0, 0.45, 0.35),
	BuildPieceData.Category.LIGHT: Color(1.0, 0.85, 0.4),
}


func show_blueprint(bp: Blueprint) -> void:
	blueprint = bp
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.07, 0.1, 0.9))
	if blueprint == null or blueprint.pieces.is_empty():
		return
	var b := blueprint.bounds().grow(1)
	var s := minf(size.x / b.size.x, size.y / b.size.y)
	var off := (size - Vector2(b.size) * s) * 0.5 - Vector2(b.position) * s
	var to_px := func(x: float, z: float) -> Vector2: return off + Vector2(x, z) * s
	# Grid
	for x in range(b.position.x, b.end.x + 1):
		draw_line(to_px.call(x, b.position.y), to_px.call(x, b.end.y), Color(1, 1, 1, 0.05))
	for z in range(b.position.y, b.end.y + 1):
		draw_line(to_px.call(b.position.x, z), to_px.call(b.end.x, z), Color(1, 1, 1, 0.05))
	var layers := {"floor": [], "roof": [], "edge": [], "object": []}
	for e in blueprint.pieces:
		var k := "edge" if String(e.slot).begins_with("edge") else String(e.slot)
		layers[k].append(e)
	for e in layers.floor:
		draw_rect(Rect2(to_px.call(e.x, e.z), Vector2(s, s)).grow(-0.5), _color(e))
	for e in layers.roof:
		draw_rect(Rect2(to_px.call(e.x, e.z), Vector2(s, s)).grow(-1.0), _color(e))
	var w := maxf(2.0, s * 0.18)
	for e in layers.edge:
		var a: Vector2
		var c: Vector2
		if e.slot == "edge_n":
			a = to_px.call(e.x, e.z)
			c = to_px.call(e.x + 1, e.z)
		else:
			a = to_px.call(e.x, e.z)
			c = to_px.call(e.x, e.z + 1)
		draw_line(a, c, _color(e), w)
	for e in layers.object:
		draw_circle(to_px.call(e.x + 0.5, e.z + 0.5), maxf(2.0, s * 0.28), _color(e))
	draw_rect(Rect2(to_px.call(0, 0), Vector2(s, s)), Color(1, 1, 1, 0.7), false, 1.5)


func _color(e: Dictionary) -> Color:
	var data := BuildingManager.get_piece_data(StringName(e.id))
	if data == null:
		return Color.MAGENTA
	return COLORS.get(data.category, Color(0.75, 0.75, 0.8))
