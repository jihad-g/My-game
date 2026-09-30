class_name BuildPalette
extends PanelContainer
## Build mode palette (visible while build mode is on): pieces grouped by
## category with costs, the current placement verdict and the controls.

var player: Player
var build_mode: BuildMode

var _status := Label.new()
var _selected_label := Label.new()
var _list := VBoxContainer.new()
var _buttons: Dictionary = {}  # piece id -> Button
var _group := ButtonGroup.new()


func _ready() -> void:
	# Below the status panel (top-left), clear of the help box (hidden in build mode).
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 16
	offset_top = 268
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var title := Label.new()
	title.text = "Build mode"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(title)
	_selected_label.add_theme_font_size_override(&"font_size", 13)
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_selected_label.custom_minimum_size.x = 290
	v.add_child(_selected_label)
	_status.add_theme_font_size_override(&"font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size.x = 290
	v.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 2)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "LMB place · RMB deconstruct · R rotate · B / Esc exit\nDeconstructing refunds 100% on your land, 50% elsewhere"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func bind(p: Player, mode: BuildMode) -> void:
	player = p
	build_mode = mode
	_build_list()
	mode.toggled.connect(func(on: bool) -> void:
		visible = on
		refresh())
	mode.selection_changed.connect(func(_d: BuildPieceData) -> void: refresh())
	mode.status_changed.connect(_on_status)
	p.inventory.changed.connect(refresh)
	p.character.leveled_up.connect(func(_l: int) -> void: refresh())


func _build_list() -> void:
	var pieces := BuildingManager.all_pieces().values()
	pieces.sort_custom(func(a: BuildPieceData, b: BuildPieceData) -> bool:
		if a.category != b.category:
			return a.category < b.category
		return a.required_level < b.required_level if a.required_level != b.required_level else String(a.id) < String(b.id))
	var last := -1
	for d: BuildPieceData in pieces:
		if d.category != last:
			last = d.category
			var h := Label.new()
			h.text = BuildPieceData.CATEGORY_NAMES[d.category]
			h.add_theme_color_override(&"font_color", UITheme.GOLD)
			h.add_theme_font_size_override(&"font_size", 13)
			_list.add_child(h)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override(&"font_size", 13)
		b.tooltip_text = d.description
		var data := d
		b.pressed.connect(func() -> void: build_mode.select(data))
		_list.add_child(b)
		_buttons[d.id] = b


func refresh() -> void:
	if player == null or not visible:
		return
	for id in _buttons:
		var d := BuildingManager.get_piece_data(id)
		var b: Button = _buttons[id]
		var afford := true
		for item in d.cost:
			if player.inventory.count_of(item) < int(d.cost[item]):
				afford = false
		var locked := player.character.level < d.required_level
		b.text = "%s  ·  %s%s" % [d.display_name, ", ".join(d.cost_lines()), "  (Lv %d)" % d.required_level if locked else ""]
		b.modulate = Color(0.55, 0.55, 0.6) if locked else (Color.WHITE if afford else Color(1.0, 0.65, 0.6))
		b.set_pressed_no_signal(build_mode.selected == d)
	var s := build_mode.selected
	if s:
		var lines := PackedStringArray(["%s — %s" % [s.display_name, s.description]])
		var have := PackedStringArray()
		for item in s.cost:
			var idata: ItemData = ItemDB.get_item(item)
			have.append("%s %d/%d" % [idata.display_name if idata else String(item), player.inventory.count_of(item), int(s.cost[item])])
		lines.append("Cost: " + ", ".join(have))
		_selected_label.text = "\n".join(lines)


func _on_status(reason: String) -> void:
	if reason == "":
		_status.text = "✔ Can place here"
		_status.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6))
	else:
		_status.text = "✖ " + reason
		_status.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.5))
