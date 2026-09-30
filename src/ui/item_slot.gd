class_name ItemSlot
extends Button
## One inventory/hotbar slot. Placeholder icon = coloured tile + glyph.

signal slot_clicked(index: int, button: MouseButton)

var index: int = -1
var _icon := Panel.new()
var _glyph := Label.new()
var _count := Label.new()
var _key := Label.new()
var _style := StyleBoxFlat.new()
var _icon_style := StyleBoxFlat.new()


func _init(p_index: int = -1, key_hint: String = "") -> void:
	index = p_index
	custom_minimum_size = Vector2(58, 58)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style.bg_color = Color(0.1, 0.08, 0.13, 0.85)
	_style.set_corner_radius_all(6)
	_style.set_border_width_all(2)
	_style.border_color = Color(0.4, 0.36, 0.3)
	for s in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(s, _style)

	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 9
	_icon.offset_top = 9
	_icon.offset_right = -9
	_icon.offset_bottom = -9
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_style.set_corner_radius_all(4)
	_icon.add_theme_stylebox_override(&"panel", _icon_style)
	add_child(_icon)

	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.add_theme_font_size_override(&"font_size", 20)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph)

	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.offset_right = -4
	_count.offset_bottom = -1
	_count.add_theme_font_size_override(&"font_size", 14)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)

	_key.text = key_hint
	_key.position = Vector2(4, 1)
	_key.add_theme_font_size_override(&"font_size", 11)
	_key.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	set_stack(null, false)


func set_stack(stack, selected: bool) -> void:
	var item: ItemData = ItemDB.get_item(stack.id) if stack != null else null
	if item == null:
		_icon.visible = false
		_glyph.text = ""
		_count.text = ""
		tooltip_text = ""
		_style.border_color = UITheme.GOLD if selected else Color(0.4, 0.36, 0.3)
	else:
		_icon.visible = true
		_icon_style.bg_color = item.icon_color
		_icon_style.border_color = item.icon_color.darkened(0.4)
		_icon_style.set_border_width_all(2)
		_glyph.text = item.icon_glyph
		_count.text = str(stack.count) if stack.count > 1 else ""
		_style.border_color = UITheme.GOLD if selected else item.rarity_color().darkened(0.25)
		var lines := PackedStringArray([item.display_name, "%s · %s" % [item.rarity_name(), item.category_name()]])
		lines.append_array(item.effect_lines())
		if item.description != "":
			lines.append(item.description)
		tooltip_text = "\n".join(lines)
	_style.set_border_width_all(3 if selected else 2)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			slot_clicked.emit(index, mb.button_index)
			accept_event()
