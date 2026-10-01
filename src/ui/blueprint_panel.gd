class_name BlueprintPanel
extends PanelContainer
## Blueprints screen (N, Milestone 8).
##   left:   built-in and saved designs; capture your base; import from the clipboard
##   right:  preview, size, pieces, total materials with what you have (inventory +
##           chests nearby) and what's missing, warnings; place / export / delete
##   bottom: active construction sites with progress, auto-build toggle and remove

var world: World
var selected: Blueprint
var _list := VBoxContainer.new()
var _title := Label.new()
var _info := Label.new()
var _preview := BlueprintPreview.new()
var _cost := VBoxContainer.new()
var _warn := Label.new()
var _place := Button.new()
var _export := Button.new()
var _delete := Button.new()
var _name_edit := LineEdit.new()
var _sites := VBoxContainer.new()
var _all: Array[Blueprint] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = "Blueprints"
	t.add_theme_font_size_override(&"font_size", 24)
	t.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
	v.add_child(t)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	v.add_child(h)
	# Left column
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	h.add_child(left)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_name_edit.placeholder_text = "Name for a new design"
	left.add_child(_name_edit)
	var cap := Button.new()
	cap.text = "Save my buildings here as a blueprint"
	cap.focus_mode = Control.FOCUS_NONE
	cap.pressed.connect(_capture)
	left.add_child(cap)
	var imp := Button.new()
	imp.text = "Import from clipboard"
	imp.focus_mode = Control.FOCUS_NONE
	imp.pressed.connect(_import)
	left.add_child(imp)
	# Right column
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 520
	h.add_child(right)
	_title.add_theme_font_size_override(&"font_size", 20)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	right.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	right.add_child(row)
	_preview.custom_minimum_size = Vector2(220, 220)
	row.add_child(_preview)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size.x = 280
	_info.add_theme_font_size_override(&"font_size", 13)
	col.add_child(_info)
	var ch := Label.new()
	ch.text = "Materials (need / have)"
	ch.add_theme_font_size_override(&"font_size", 14)
	ch.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	col.add_child(ch)
	col.add_child(_cost)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD
	_warn.custom_minimum_size.x = 500
	_warn.add_theme_font_size_override(&"font_size", 12)
	_warn.add_theme_color_override(&"font_color", Color(1, 0.7, 0.5))
	right.add_child(_warn)
	var btns := HBoxContainer.new()
	right.add_child(btns)
	for pair in [[_place, "Place (preview)"], [_export, "Export to clipboard"], [_delete, "Delete"]]:
		var b: Button = pair[0]
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_NONE
		btns.add_child(b)
	_place.pressed.connect(_on_place)
	_export.pressed.connect(_on_export)
	_delete.pressed.connect(_on_delete)
	# Sites
	var st := Label.new()
	st.text = "Construction sites"
	st.add_theme_font_size_override(&"font_size", 16)
	st.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
	v.add_child(st)
	v.add_child(_sites)
	var hint := Label.new()
	hint.text = "Auto-build takes materials from your bag, then chests near the site, while you're within %d m. Or press F on a hologram to build it by hand.\nDesign on the web: web/blueprint-designer/index.html (same file format). N / Esc: close" % roundi(ConstructionSite.AUTO_RANGE)
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func bind(p_world: World) -> void:
	world = p_world
	world.blueprints.sites_changed.connect(func() -> void:
		if visible:
			_refresh_sites())


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	_all = BlueprintLibrary.all()
	for c in _list.get_children():
		c.queue_free()
	for bp in _all:
		var b := Button.new()
		b.text = ("★ " if bp.get_meta(&"builtin", false) else "") + "%s (%d)" % [bp.name, bp.pieces.size()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = selected != null and selected.get_meta(&"path", "") == bp.get_meta(&"path", "")
		var sel := bp
		b.pressed.connect(func() -> void: select(sel))
		_list.add_child(b)
	if selected == null and not _all.is_empty():
		selected = _all[0]
	select(selected)
	_refresh_sites()


func select(bp: Blueprint) -> void:
	selected = bp
	for b in _list.get_children():
		(b as Button).button_pressed = false
	var idx := _all.find(bp)
	if idx >= 0 and idx < _list.get_child_count():
		(_list.get_child(idx) as Button).button_pressed = true
	for c in _cost.get_children():
		c.queue_free()
	_preview.show_blueprint(bp)
	_place.disabled = bp == null
	_export.disabled = bp == null
	_delete.disabled = bp == null or bp.get_meta(&"builtin", false)
	if bp == null:
		_title.text = "No blueprint selected"
		_info.text = ""
		_warn.text = ""
		return
	_title.text = bp.name
	var r := bp.bounds()
	var parts := PackedStringArray()
	var counts := bp.counts()
	for id in counts:
		var d := BuildingManager.get_piece_data(id)
		parts.append("%d× %s" % [counts[id], d.display_name if d else String(id)])
	_info.text = "%s%s\nFootprint %d × %d m · %d pieces · needs level %d\n%s" % [
		bp.description + "\n" if bp.description != "" else "", "by " + bp.author if bp.author != "" else "",
		r.size.x, r.size.y, bp.pieces.size(), bp.required_level(), ", ".join(parts)]
	var have := available_near_player()
	var cost := bp.total_cost()
	for item in cost:
		var d: ItemData = ItemDB.get_item(item)
		var l := Label.new()
		var n := int(have.get(item, 0))
		l.text = "%s: %d / %d" % [d.display_name if d else String(item), int(cost[item]), n]
		l.add_theme_font_size_override(&"font_size", 13)
		l.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6) if n >= int(cost[item]) else Color(1.0, 0.55, 0.45))
		_cost.add_child(l)
	var miss := bp.missing(have)
	var w := PackedStringArray()
	if not miss.is_empty():
		var m := PackedStringArray()
		for item in miss:
			var d: ItemData = ItemDB.get_item(item)
			m.append("%d %s" % [miss[item], d.display_name if d else String(item)])
		w.append("Missing: " + ", ".join(m) + " (you can still place it and build piece by piece)")
	if world and world.player.character.level < bp.required_level():
		w.append("Some pieces need level %d" % bp.required_level())
	w.append_array(bp.warnings)
	_warn.text = "\n".join(w)


## Inventory + storage chests within 18 m of the player.
func available_near_player() -> Dictionary:
	var out := {}
	if world == null:
		return out
	for s in world.player.inventory.slots:
		if s != null:
			out[s.id] = int(out.get(s.id, 0)) + int(s.count)
	for p in world.building.pieces_near(world.player.global_position, ConstructionSite.STORAGE_RANGE):
		if p.storage:
			for s in p.storage.slots:
				if s != null:
					out[s.id] = int(out.get(s.id, 0)) + int(s.count)
	return out


func _on_place() -> void:
	if selected == null or world == null:
		return
	visible = false
	world.blueprints.placer.begin(selected)


func _on_export() -> void:
	if selected == null:
		return
	DisplayServer.clipboard_set(selected.to_json())
	var path := String(selected.get_meta(&"path", ""))
	Events.toast.emit("Copied %s to the clipboard%s" % [selected.name, " (file: %s)" % ProjectSettings.globalize_path(path) if path != "" else ""],
		Color(0.6, 0.85, 1.0))


func _on_delete() -> void:
	if selected and BlueprintLibrary.delete(selected):
		Events.toast.emit("Deleted %s" % selected.name, Color(0.85, 0.85, 0.85))
		selected = null
		refresh()


func _capture() -> void:
	if world == null:
		return
	var nm := _name_edit.text.strip_edges()
	if nm == "":
		nm = "My Design %d" % (BlueprintLibrary.user().size() + 1)
	var bp := world.blueprints.capture_here(nm)
	if bp.pieces.is_empty():
		Events.toast.emit("Nothing built around you to save", Color(1, 0.7, 0.5))
		return
	BlueprintLibrary.save(bp)
	_name_edit.text = ""
	Events.toast.emit("Saved blueprint %s (%d pieces)" % [bp.name, bp.pieces.size()], Color(0.6, 1, 0.7))
	selected = bp
	refresh()


func _import() -> void:
	var bp := BlueprintLibrary.import_text(DisplayServer.clipboard_get())
	if bp == null:
		Events.toast.emit("The clipboard doesn't hold a Shardlands blueprint", Color(1, 0.7, 0.5))
		return
	Events.toast.emit("Imported %s (%d pieces%s)" % [bp.name, bp.pieces.size(), ", %d warnings" % bp.warnings.size() if not bp.warnings.is_empty() else ""],
		Color(0.6, 1, 0.7))
	selected = bp
	refresh()


func _refresh_sites() -> void:
	for c in _sites.get_children():
		c.queue_free()
	if world == null:
		return
	if world.blueprints.sites.is_empty():
		var l := Label.new()
		l.text = "None. Pick a blueprint and press Place."
		l.add_theme_font_size_override(&"font_size", 12)
		l.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		_sites.add_child(l)
		return
	for s in world.blueprints.sites:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		_sites.add_child(row)
		var l := Label.new()
		var done := s.total - s.pending_count()
		var c := s.center()
		l.text = "%s: %d / %d built%s%s · %d m away" % [s.blueprint_name, done, s.total,
			" · %d blocked" % s.blocked_count() if s.blocked_count() > 0 else "", " · " + s.status if s.status != "" else "",
			roundi(world.player.global_position.distance_to(c))]
		l.custom_minimum_size.x = 560
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.add_theme_font_size_override(&"font_size", 13)
		row.add_child(l)
		var auto := Button.new()
		auto.text = "Auto-build: ON" if s.auto else "Auto-build: off"
		auto.focus_mode = Control.FOCUS_NONE
		var site := s
		auto.pressed.connect(func() -> void:
			site.auto = not site.auto
			_refresh_sites())
		row.add_child(auto)
		var rm := Button.new()
		rm.text = "Remove"
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func() -> void: world.blueprints.cancel_site(site))
		row.add_child(rm)
