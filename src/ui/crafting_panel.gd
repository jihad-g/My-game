class_name CraftingPanel
extends PanelContainer
## Crafting screen (G): station tabs, recipe list and recipe details.
##
## Shows every recipe, including locked ones with how to unlock them. Costs are
## the real amounts at the character's current Crafting skill. Crafting never
## fails; a low skill only costs more materials.

var player: Player

var _station_buttons: Dictionary = {}  # station index (or -1 = all) -> Button
var _filter := -1
var _nearby: Dictionary = {}
var _nearby_label := Label.new()
var _list := VBoxContainer.new()
var _list_buttons: Dictionary = {}  # recipe id -> Button
var _selected: RecipeData
var _name := Label.new()
var _body := Label.new()
var _costs := VBoxContainer.new()
var _reason := Label.new()
var _craft1 := Button.new()
var _craft5 := Button.new()
var _poll := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 8)
	add_child(root)
	var title := Label.new()
	title.text = "Crafting"
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.GOLD)
	root.add_child(title)
	_nearby_label.add_theme_font_size_override(&"font_size", 13)
	_nearby_label.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	root.add_child(_nearby_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 4)
	root.add_child(tabs)
	var group := ButtonGroup.new()
	for i in range(-1, RecipeData.STATION_NAMES.size()):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.text = "All" if i < 0 else RecipeData.STATION_NAMES[i]
		b.button_pressed = i == -1
		var idx := i
		b.pressed.connect(func() -> void:
			_filter = idx
			_rebuild_list())
		tabs.add_child(b)
		_station_buttons[i] = b

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 14)
	root.add_child(cols)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 2)
	scroll.add_child(_list)

	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(360, 400)
	details.add_theme_stylebox_override(&"panel", UITheme.panel_style(Color(0.08, 0.07, 0.1, 0.8), Color(0.45, 0.38, 0.28)))
	cols.add_child(details)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override(&"separation", 6)
	details.add_child(dv)
	_name.add_theme_font_size_override(&"font_size", 20)
	dv.add_child(_name)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.custom_minimum_size.x = 340
	_body.add_theme_font_size_override(&"font_size", 13)
	dv.add_child(_body)
	var ing := Label.new()
	ing.text = "Materials (have / need):"
	ing.add_theme_color_override(&"font_color", UITheme.GOLD)
	dv.add_child(ing)
	dv.add_child(_costs)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(spacer)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD
	_reason.custom_minimum_size.x = 340
	_reason.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.5))
	dv.add_child(_reason)
	var buttons := HBoxContainer.new()
	dv.add_child(buttons)
	_craft1.text = "Craft"
	_craft1.pressed.connect(func() -> void: craft_selected(1))
	buttons.add_child(_craft1)
	_craft5.text = "Craft x5"
	_craft5.pressed.connect(func() -> void: craft_selected(5))
	buttons.add_child(_craft5)

	var hint := Label.new()
	hint.text = "G / Esc: close · Stand within 4 m of a station to use it · Crafting never fails: low skill only costs more materials"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	root.add_child(hint)


func bind(p: Player) -> void:
	player = p
	p.inventory.changed.connect(refresh)
	p.character.skills_changed.connect(refresh)
	p.recipes.learned.connect(func(_r: RecipeData) -> void: _rebuild_list())


func toggle() -> void:
	visible = not visible
	if visible:
		_update_nearby()
		_rebuild_list()


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		var before := _nearby.keys()
		_update_nearby()
		if before != _nearby.keys():
			refresh()


func _update_nearby() -> void:
	_nearby = Crafting.stations_near(get_tree(), player.global_position)
	var parts := PackedStringArray()
	for i in RecipeData.STATION_IDS.size():
		if i == 0:
			continue
		var on := _nearby.has(RecipeData.STATION_IDS[i])
		parts.append("%s %s" % ["●" if on else "○", RecipeData.STATION_NAMES[i]])
		var b: Button = _station_buttons[i]
		b.modulate = Color.WHITE if on else Color(0.65, 0.65, 0.7)
	_nearby_label.text = "Nearby stations: " + "   ".join(parts)


func _rebuild_list() -> void:
	if player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	_list_buttons.clear()
	var last_station := -99
	var first: RecipeData = null
	for r: RecipeData in RecipeBook.sorted_list():
		if _filter >= 0 and r.station != _filter:
			continue
		if r.station != last_station:
			last_station = r.station
			var h := Label.new()
			h.text = r.station_name()
			h.add_theme_color_override(&"font_color", UITheme.GOLD)
			h.add_theme_font_size_override(&"font_size", 14)
			_list.add_child(h)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		var rec := r
		b.pressed.connect(func() -> void: select(rec))
		_list.add_child(b)
		_list_buttons[r.id] = b
		if first == null:
			first = r
	if _selected == null or not _list_buttons.has(_selected.id):
		_selected = first
	refresh()


func select(r: RecipeData) -> void:
	_selected = r
	refresh()


func refresh() -> void:
	if player == null or not visible:
		return
	var crafting := player.character.skill_level(Skill.CRAFTING)
	for id in _list_buttons:
		var r := RecipeBook.get_recipe(id)
		var b: Button = _list_buttons[id]
		var item: ItemData = ItemDB.get_item(r.result_item)
		var nm := item.display_name if item else String(r.result_item)
		if r.result_count > 1:
			nm += " x%d" % r.result_count
		var known := player.recipes.knows(r.id)
		var ok := Crafting.check(player, r, _nearby) == ""
		b.text = nm if known else "? " + nm
		b.button_pressed = r == _selected
		if not known:
			b.modulate = Color(0.55, 0.55, 0.6)
		elif ok:
			b.modulate = Color(0.75, 1.0, 0.75)
		else:
			b.modulate = Color.WHITE
	_show_details(crafting)


func _show_details(crafting: int) -> void:
	for c in _costs.get_children():
		c.queue_free()
	var r := _selected
	if r == null:
		_name.text = "No recipes"
		_body.text = ""
		_reason.text = ""
		_craft1.disabled = true
		_craft5.disabled = true
		return
	var item: ItemData = ItemDB.get_item(r.result_item)
	var known := player.recipes.knows(r.id)
	_name.text = "%s%s" % [item.display_name if item else String(r.result_item), " x%d" % r.result_count if r.result_count > 1 else ""]
	_name.add_theme_color_override(&"font_color", item.rarity_color() if item else Color.WHITE)
	var lines := PackedStringArray()
	if item:
		lines.append("%s %s" % [item.rarity_name(), item.category_name()])
		lines.append_array(item.effect_lines())
		if item.description != "":
			lines.append(item.description)
	lines.append("")
	lines.append("Station: %s" % r.station_name())
	lines.append("Tier: %s (Crafting %d)" % [ItemData.RARITY_NAMES[clampi(r.tier, 0, ItemData.RARITY_NAMES.size() - 1)], r.required_crafting()])
	match r.source:
		RecipeData.Source.STARTING:
			lines.append("Known from the start")
		RecipeData.Source.DISCOVERY:
			var d: ItemData = ItemDB.get_item(r.discovered_by)
			lines.append("Discovery: learned by obtaining %s" % (d.display_name if d else String(r.discovered_by)))
		RecipeData.Source.BOOK:
			lines.append("Recipe book: %s" % r.source_hint)
	lines.append("+%d Crafting XP" % (maxi(1, r.xp / 4) * 4))
	_body.text = "\n".join(lines)
	var cost := r.cost_at(crafting)
	for id in cost:
		var d: ItemData = ItemDB.get_item(id)
		var have := player.inventory.count_of(id)
		var need := int(cost[id])
		var l := Label.new()
		var base := int(r.ingredients[id])
		l.text = "  %s  %d / %d%s" % [d.display_name if d else String(id), have, need,
			"  (base %d)" % base if base != need else ""]
		l.add_theme_font_size_override(&"font_size", 14)
		l.add_theme_color_override(&"font_color", Color(0.7, 1.0, 0.7) if have >= need else Color(1.0, 0.6, 0.5))
		_costs.add_child(l)
	var reason := Crafting.check(player, r, _nearby)
	_reason.text = reason
	_craft1.disabled = reason != ""
	_craft5.disabled = Crafting.check(player, r, _nearby, 5) != ""
	if not known:
		_name.text = "? " + _name.text


func craft_selected(times: int) -> int:
	if _selected == null or player == null:
		return 0
	_update_nearby()
	if Net.is_client():
		if Crafting.check(player, _selected, _nearby, 1) != "":
			return 0
		Net.client.craft(_selected, times, player.character.skill_level(Skill.CRAFTING))
		return 0
	var made := Crafting.craft(player, _selected, _nearby, times)
	if made > 0:
		var item: ItemData = ItemDB.get_item(_selected.result_item)
		Events.toast.emit("Crafted %s x%d" % [item.display_name if item else String(_selected.result_item),
			made * _selected.result_count], UITheme.GOLD)
	refresh()
	return made
