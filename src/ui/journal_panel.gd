class_name JournalPanel
extends PanelContainer
## The journal (O, Milestone 16): quests with their steps, lore pages you have
## read, the chronicle of your big moments, and your hero's story.

var world: World
var _tabs := TabContainer.new()
var _quests := RichTextLabel.new()
var _lore_list := ItemList.new()
var _lore_text := RichTextLabel.new()
var _chronicle := RichTextLabel.new()
var _story := RichTextLabel.new()
var _lore_ids: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(820, 520)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = "Journal"
	t.add_theme_font_size_override(&"font_size", 24)
	t.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(t)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	for pair in [[_quests, "Quests"], [_chronicle, "Chronicle"], [_story, "Your story"]]:
		var r: RichTextLabel = pair[0]
		r.bbcode_enabled = true
		r.name = pair[1]
		r.custom_minimum_size = Vector2(780, 420)
		_tabs.add_child(r)
	var lore := HBoxContainer.new()
	lore.name = "Lore"
	lore.add_theme_constant_override(&"separation", 10)
	_tabs.add_child(lore)
	_tabs.move_child(lore, 1)
	_lore_list.custom_minimum_size = Vector2(230, 420)
	_lore_list.item_selected.connect(_show_page)
	lore.add_child(_lore_list)
	_lore_text.bbcode_enabled = true
	_lore_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore.add_child(_lore_text)
	var hint := Label.new()
	hint.text = "O / Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func bind(w: World) -> void:
	world = w
	w.quests.changed.connect(func() -> void:
		if visible:
			refresh())


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if world == null:
		return
	var ql := world.quests
	# Quests
	var s := ""
	for id in ql.active:
		var q := ql.definition(id)
		var cur := ql.step_index(id)
		s += "[font_size=20][color=#ffd36b]%s[/color][/font_size]\n[i]%s[/i]\n" % [q.title, q.summary]
		for i in (q.steps as Array).size():
			var mark := "[color=#7ad67a]✓[/color]" if i < cur else ("[color=#ffd36b]►[/color]" if i == cur else "[color=#888888]·[/color]")
			var text: String = q.steps[i].text if i <= cur else "???"
			s += "  %s %s\n" % [mark, text]
		var tr := ql.tracker()
		if not tr.is_empty() and tr.title == q.title:
			s += "  [color=#aaccff]%s%s[/color]\n" % [tr.text, (" - " + tr.where) if tr.where != "" else ""]
		s += "\n"
	if ql.active.is_empty():
		s += "No active quests. Rulers of kingdoms sometimes have errands for brave travellers.\n\n"
	if not ql.done.is_empty():
		s += "[font_size=18]Completed[/font_size]\n"
		for id in ql.done:
			var q := ql.definition(id)
			s += "  [color=#7ad67a]✓[/color] %s (day %d)\n" % [q.get("title", String(id)), int(ql.done[id])]
	_quests.text = s
	# Lore
	_lore_list.clear()
	_lore_ids = ql.lore.duplicate()
	for id in _lore_ids:
		_lore_list.add_item(ql.lore_title(id))
	var total := LoreBook.PAGES.size()
	_lore_text.text = "[i]%d of %d pages of the old histories found, plus %d kingdom histories.\nPages hide in the chests of ruins, towers, temples and buried caches; bosses and rulers tell their own stories.[/i]" % [
		_lore_ids.filter(func(x: StringName) -> bool: return LoreBook.PAGES.has(x)).size(), total, ql.lore_extra.size()]
	# Chronicle
	var c := ""
	for e in ql.chronicle:
		c += "[color=#ffd36b]Day %d[/color]  %s\n" % [int(e.day), e.text]
	_chronicle.text = c if c != "" else "Your story has not started yet."
	# Your story
	var p := world.player
	var cd := p.character.class_data
	var title := ql.best_title()
	if title == "":
		title = p.reputation.best_title(world.generator.settlements)
	_story.text = "[font_size=20]%s, level %d %s[/font_size]\n%s\n\n%s\n\n[color=#aaaaaa]%d quests done · %d pages read · %d chronicle entries[/color]" % [
		"The " + title if title != "" else "A traveller", p.character.level, cd.display_name if cd else "",
		("[i]%s[/i]" % title) if title != "" else "", cd.backstory if cd else "", ql.done.size(), ql.lore.size(), ql.chronicle.size()]


func _show_page(i: int) -> void:
	if i < 0 or i >= _lore_ids.size():
		return
	var id: StringName = _lore_ids[i]
	_lore_text.text = "[font_size=20][color=#ffd36b]%s[/color][/font_size]\n\n%s" % [world.quests.lore_title(id), world.quests.lore_text(id)]
