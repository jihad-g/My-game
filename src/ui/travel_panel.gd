class_name TravelPanel
extends PanelContainer
## Milestone 29: the waystone travel list (opened at an unlocked waystone) and
## the horse panel (Shift + interact on your horse): its saddle slot.

var from_key := ""
var horse: Horse

var _title := Label.new()
var _list := VBoxContainer.new()
var _status := Label.new()
var _hint := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list.add_theme_constant_override(&"separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_status.add_theme_color_override(&"font_color", Color(1, 0.7, 0.5))
	v.add_child(_status)
	_hint.add_theme_font_size_override(&"font_size", 11)
	_hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(_hint)


func open_travel(p_from_key: String) -> void:
	from_key = p_from_key
	horse = null
	_status.text = ""
	visible = true
	refresh()


func open_horse(p_horse: Horse) -> void:
	horse = p_horse
	from_key = ""
	_status.text = ""
	visible = true
	refresh()


func close() -> void:
	visible = false
	horse = null


func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()


func _row(text: String, button_text: String, action: Callable, enabled: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(l)
	if button_text != "":
		var b := Button.new()
		b.text = button_text
		b.disabled = not enabled
		b.pressed.connect(action)
		row.add_child(b)
	_list.add_child(row)


func refresh() -> void:
	_clear()
	var w := World.instance
	if w == null:
		return
	if horse:
		_refresh_horse(w)
		return
	var here := w.player.global_position
	_title.text = "Waystone - travel"
	_hint.text = "Touch a waystone once to add it here · Esc: close"
	var dests := w.travel.destinations(here, from_key)
	if dests.is_empty():
		_row("No other waystone is unlocked yet. Every village, capital and dungeon entrance has one.", "", Callable())
	for d: Dictionary in dests:
		var key: String = d.key
		var cost: int = d.cost
		_row("%s  ·  %.1f km" % [d.title, float(d.distance) / 1000.0], "Travel (%d c)" % cost if cost > 0 else "Travel (free)",
			func() -> void: _travel(key), w.player.coins >= cost)


func _travel(key: String) -> void:
	var w := World.instance
	var why: String = w.travel.travel(key)
	if why != "":
		_status.text = why
		return
	close()


func _refresh_horse(w: World) -> void:
	_title.text = "%s - your horse" % horse.horse_name
	_hint.text = "Ride: %s · whistle: %s · Esc: close" % [InputSetup.action_label(&"interact"), InputSetup.action_label(&"whistle")]
	var p := w.player
	if horse.saddle != &"":
		var d: ItemData = ItemDB.get_item(horse.saddle)
		_row("Saddle: %s" % (d.display_name if d else String(horse.saddle)), "Take off", func() -> void:
			horse.take_saddle(p)
			refresh())
		_row("Gallop: %d / %d" % [roundi(horse.stamina), roundi(horse.stamina_max())], "Ride", func() -> void:
			close()
			horse.mount(p))
	else:
		_row("Saddle: (empty)", "", Callable())
		for s in Horse.SADDLES:
			if p.inventory.count_of(s) > 0:
				var d: ItemData = ItemDB.get_item(s)
				var sid: StringName = s
				_row("  %s in your bag" % (d.display_name if d else String(s)), "Put on", func() -> void:
					horse.put_saddle(p, sid)
					refresh())
		if not Horse.SADDLES.keys().any(func(s: StringName) -> bool: return p.inventory.count_of(s) > 0):
			_row("Craft a Leather Saddle at a tailoring table (4 leather, 2 rope, 1 plank).", "", Callable())
