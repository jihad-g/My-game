class_name WorldMap
extends PanelContainer
## Full-screen-ish world map (M). Rendered on a worker thread by sampling the
## generator around the player: biome colours shaded by height, water, cave
## entrances. Underground it shows the cave layout instead.
## Settlements you discovered (or heard of from townsfolk) are marked with names.
## (No fog-of-war yet: the terrain itself is fully revealed.)

const SIZE_PX := 220
const METRES_PER_PX := 3.0

var world: World
var _texture_rect := TextureRect.new()
var _title := Label.new()
var _legend := RichTextLabel.new()
var _task_id := -1
var _image: Image
var _center := Vector3.ZERO
var _legend_biomes: Dictionary = {}
var _marker := Control.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	v.add_child(h)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX) * 2.6
	h.add_child(holder)
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(_texture_rect)
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	holder.add_child(_marker)
	_legend.bbcode_enabled = true
	_legend.fit_content = true
	_legend.add_theme_font_size_override(&"normal_font_size", 14)
	_legend.custom_minimum_size.x = 240
	h.add_child(_legend)
	var hint := Label.new()
	hint.text = "M / Esc: close · %d m across · black dots: cave entrances · squares: villages, crowns: kingdom capitals (? = heard of)" % int(SIZE_PX * METRES_PER_PX)
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if world == null or _task_id != -1:
		return
	_center = world.player.global_position
	_title.text = "Map · %s" % ("The Deeps (underground)" if world.layer == TerrainGenerator.Layer.UNDERGROUND else "Surface")
	_legend.text = "Charting..."
	var gen := world.generator
	var layer := world.layer
	var center := _center
	_task_id = WorkerThreadPool.add_task(func() -> void: _render(gen, layer, center), false, "world_map")


func _process(_delta: float) -> void:
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_texture_rect.texture = ImageTexture.create_from_image(_image)
		var lines := PackedStringArray()
		for id in _legend_biomes:
			var entry: Array = _legend_biomes[id]
			lines.append("[color=#%s]■[/color] %s%s" % [(entry[1] as Color).to_html(false), entry[0],
				"  [color=#aaaaaa](discovered)[/color]" if GameState.discovered_biomes.has(id) else ""])
		if world.layer == TerrainGenerator.Layer.SURFACE:
			var towns := PackedStringArray()
			for st in _visible_settlements():
				var known := world.living.is_discovered(st.id)
				towns.append("%s %s%s" % ["♛" if st.is_kingdom() else "▪", st.name if known else st.name + " (heard of)",
					"" if st.kingdom_name == "" or st.is_kingdom() else " [color=#aaaaaa]· %s[/color]" % st.kingdom_name])
			if not towns.is_empty():
				lines.append("")
				lines.append("[color=#e6c35c]Settlements[/color]")
				lines.append_array(towns)
		_legend.text = "\n".join(lines)
		_marker.queue_redraw()


func _exit_tree() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)


## Worker thread: sample the generator into an image.
func _render(gen: TerrainGenerator, layer: int, center: Vector3) -> void:
	var img := Image.create(SIZE_PX, SIZE_PX, false, Image.FORMAT_RGB8)
	var legend := {}
	var half := SIZE_PX * 0.5
	var ox := center.x - half * METRES_PER_PX
	var oz := center.z - half * METRES_PER_PX
	var entrances := gen.get_cave_entrances_near(floori(ox), floori(oz),
		floori(ox + SIZE_PX * METRES_PER_PX), floori(oz + SIZE_PX * METRES_PER_PX))
	for py in SIZE_PX:
		for px in SIZE_PX:
			var wx := floori(ox + px * METRES_PER_PX)
			var wz := floori(oz + py * METRES_PER_PX)
			var c: Color
			if layer == TerrainGenerator.Layer.UNDERGROUND:
				c = Color(0.55, 0.5, 0.45) if gen.is_cave_open(wx, wz, entrances) else Color(0.1, 0.09, 0.11)
			else:
				var smp := gen.sample_column(wx, wz)
				var h := TerrainGenerator.unpack_height(smp)
				var b := gen.biomes[TerrainGenerator.unpack_biome(smp)]
				legend[String(b.id)] = [b.display_name, b.map_color]
				if h < TerrainGenerator.SEA_LEVEL and not b.frozen_water:
					c = Color(0.2, 0.42, 0.75).darkened(clampf(-h / 30.0, 0.0, 0.5))
				else:
					c = b.map_color.lightened(clampf(h / 120.0, 0.0, 0.4))
					if h >= b.peak_height:
						c = Color(0.95, 0.96, 1.0)
			img.set_pixel(px, py, c)
	for e in entrances:
		var px := int((e.x - ox) / METRES_PER_PX)
		var py := int((e.y - oz) / METRES_PER_PX)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if px + dx >= 0 and px + dx < SIZE_PX and py + dy >= 0 and py + dy < SIZE_PX:
					img.set_pixel(px + dx, py + dy, Color.BLACK)
	_image = img
	_legend_biomes = legend


## Settlements on the map that you discovered or heard of.
func _visible_settlements() -> Array[SettlementInfo]:
	var out: Array[SettlementInfo] = []
	if world == null or world.layer != TerrainGenerator.Layer.SURFACE:
		return out
	for st in world.generator.settlements.near(_center, SIZE_PX * METRES_PER_PX * 0.72):
		if world.living.is_discovered(st.id) or GameState.discovered_places.has("heard:%s" % st.id):
			out.append(st)
	return out


func _draw_marker() -> void:
	if world == null:
		return
	var sz := _marker.size
	var font := ThemeDB.fallback_font
	for st in _visible_settlements():
		var rel_s := (st.world_center() - _center) / (SIZE_PX * METRES_PER_PX)
		var q := sz * 0.5 + Vector2(rel_s.x, rel_s.z) * sz
		if q.x < 0 or q.y < 0 or q.x > sz.x or q.y > sz.y:
			continue
		var known := world.living.is_discovered(st.id)
		var r := 9.0 if st.is_kingdom() else 6.0
		_marker.draw_rect(Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0), st.color if st.kingdom_id != "" else Color(0.85, 0.7, 0.45))
		_marker.draw_rect(Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0), Color.WHITE, false, 2.0)
		if st.is_kingdom():
			for k in 3:
				_marker.draw_rect(Rect2(q + Vector2(-r + k * r * 0.8, -r - 6), Vector2(4, 6)), Color(1.0, 0.85, 0.3))
		var label := st.name if known else st.name + " ?"
		_marker.draw_string_outline(font, q + Vector2(r + 4, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
		_marker.draw_string(font, q + Vector2(r + 4, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var rel := (world.player.global_position - _center) / (SIZE_PX * METRES_PER_PX)
	var p := sz * 0.5 + Vector2(rel.x, rel.z) * sz
	var f := world.player.get_facing()
	var dir := Vector2(f.x, f.z)
	var side := Vector2(-dir.y, dir.x)
	_marker.draw_colored_polygon(PackedVector2Array([p + dir * 12, p - dir * 7 + side * 7, p - dir * 7 - side * 7]), Color(1, 0.2, 0.2))
	_marker.draw_polyline(PackedVector2Array([p + dir * 12, p - dir * 7 + side * 7, p - dir * 7 - side * 7, p + dir * 12]), Color.WHITE, 2.0)
