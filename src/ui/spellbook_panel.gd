class_name SpellbookPanel
extends PanelContainer
## Spellbook (L, Milestone 7): every advanced spell, whether you know it, its
## Mana Control requirement, and buttons to put it into spell slot Y or H.
## Also lists the elemental combos.

var player: Player
var _list := VBoxContainer.new()
var _slots := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = "Spellbook"
	t.add_theme_font_size_override(&"font_size", 24)
	t.add_theme_color_override(&"font_color", Color(0.8, 0.65, 1.0))
	v.add_child(t)
	var info := Label.new()
	info.text = "Learn spells by reading tomes (found in wizard towers, dungeons, from elites and treasure goblins, or crafted at the Arcane Altar).\n" \
		+ "Any class can cast a spell once its Mana Control is high enough; damage grows with spell power.\n" \
		+ "Combos: Shatter (fire on frozen x2) · Conducted (lightning on wet x1.5) · Deep Freeze (chill a chilled or wet foe) · Combustion (fire into Miasma)"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size.x = 760
	info.add_theme_font_size_override(&"font_size", 12)
	info.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(info)
	_slots.add_theme_font_size_override(&"font_size", 14)
	v.add_child(_slots)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	sc.add_child(_list)
	var hint := Label.new()
	hint.text = "Cast with Y and H · L / Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func bind(p: Player) -> void:
	player = p
	player.spells.changed.connect(func() -> void:
		if visible:
			refresh())


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var book := player.spells
	var names := PackedStringArray()
	for i in SpellBook.SLOTS:
		var a := book.get_slot(i)
		names.append("%s: %s" % [["Y", "H"][i], a.display_name if a else "(empty)"])
	_slots.text = "Spell slots - " + "   ·   ".join(names)
	var mc := player.character.skill_level(Skill.MANA_CONTROL)
	for id in SpellBook.sorted_ids():
		var a := SpellBook.get_spell(id)
		var known := book.knows(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		_list.add_child(row)
		var icon := Label.new()
		icon.text = a.icon_glyph
		icon.custom_minimum_size = Vector2(36, 36)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override(&"font_size", 16)
		icon.add_theme_color_override(&"font_color", a.icon_color if known else Color(0.45, 0.45, 0.5))
		row.add_child(icon)
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 520
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var req := "Mana Control %d%s" % [a.required_mana_control, "" if mc >= a.required_mana_control else " (you: %d)" % mc]
		text.text = "%s  -  %s\n%s\n%d mana · %ss cooldown · %s" % [a.display_name, "known" if known else "not learned",
			a.description, roundi(player.abilities.effective_cost(a)), a.cooldown, req]
		text.add_theme_font_size_override(&"font_size", 12)
		text.add_theme_color_override(&"font_color", Color.WHITE if known else UITheme.TEXT_DIM)
		row.add_child(text)
		for i in SpellBook.SLOTS:
			var b := Button.new()
			b.text = "Slot %s" % ["Y", "H"][i]
			b.disabled = not known or book.slots[i] == id
			b.focus_mode = Control.FOCUS_NONE
			var slot := i
			b.pressed.connect(func() -> void:
				book.assign(slot, id)
				refresh())
			row.add_child(b)
