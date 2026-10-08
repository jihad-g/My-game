class_name SpellbookPanel
extends PanelContainer
## The ability book (L). Milestone 17b turned the Milestone 7 spellbook into
## two pages:
## - Abilities: every ability of your class, the level it is learned at,
##   active or passive, and buttons to put actives on the 6-slot bar
##   (Z X C T V U). The bar can only be changed while resting at a bed or a
##   campfire.
## - Spells: every advanced spell, whether you know it, its Mana Control
##   requirement, and buttons to put it into spell slot Y, H or N (N needs a
##   tome in your off hand). Also lists the elemental combos.

var player: Player
var _tabs := TabContainer.new()
var _ability_list := VBoxContainer.new()
var _bar_row := HBoxContainer.new()
var _rest := Label.new()
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
	t.text = "Ability Book"
	t.add_theme_font_size_override(&"font_size", 24)
	t.add_theme_color_override(&"font_color", Color(0.8, 0.65, 1.0))
	v.add_child(t)
	_tabs.custom_minimum_size = Vector2(800, 470)
	v.add_child(_tabs)
	_tabs.add_child(_build_abilities_page())
	_tabs.add_child(_build_spells_page())
	var hint := Label.new()
	hint.text = "Abilities: Z X C T V U · Spells: Y H (N with a tome) · L / Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func _build_abilities_page() -> Control:
	var v := VBoxContainer.new()
	v.name = "Abilities"
	v.add_theme_constant_override(&"separation", 6)
	var info := Label.new()
	info.text = "You learn a new ability every two levels. Active abilities go on your bar; passive abilities are always on.\n" \
		+ "Choose your bar while resting at a bed or a campfire - new abilities fill empty slots by themselves.\n" \
		+ "From level 30 you can give every active ability one of two upgrades (also at a bed or a campfire)."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size.x = 760
	info.add_theme_font_size_override(&"font_size", 12)
	info.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(info)
	_bar_row.add_theme_constant_override(&"separation", 6)
	v.add_child(_bar_row)
	_rest.add_theme_font_size_override(&"font_size", 12)
	v.add_child(_rest)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_ability_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_list.add_theme_constant_override(&"separation", 6)
	sc.add_child(_ability_list)
	return v


func _build_spells_page() -> Control:
	var v := VBoxContainer.new()
	v.name = "Spells"
	v.add_theme_constant_override(&"separation", 6)
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
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	sc.add_child(_list)
	return v


func bind(p: Player) -> void:
	player = p
	player.spells.changed.connect(func() -> void:
		if visible:
			refresh())
	player.abilities.bar_changed.connect(func() -> void:
		if visible:
			refresh())


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if player == null:
		return
	_refresh_abilities()
	_refresh_spells()


func _icon(glyph: String, color: Color) -> Label:
	var icon := Label.new()
	icon.text = glyph
	icon.custom_minimum_size = Vector2(36, 36)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override(&"font_size", 16)
	icon.add_theme_color_override(&"font_color", color)
	return icon


func _refresh_abilities() -> void:
	var ab := player.abilities
	var why := ab.bar_lock_reason()
	var can_change := why == ""
	_rest.text = "Resting: you can change your bar." if can_change else why + "."
	_rest.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6) if can_change else Color(1.0, 0.8, 0.5))
	for c in _bar_row.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "Your bar:"
	_bar_row.add_child(lbl)
	for i in PlayerAbilities.SLOTS:
		var a := ab.get_slot(i)
		var b := Button.new()
		b.text = "%s: %s" % [PlayerAbilities.SLOT_KEYS[i], a.display_name if a else "-"]
		b.tooltip_text = "Click to empty this slot" if a else "Empty slot"
		b.disabled = a == null or not can_change
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override(&"font_size", 11)
		var slot := i
		b.pressed.connect(func() -> void:
			ab.assign(slot, &"")
			refresh())
		_bar_row.add_child(b)
	for c in _ability_list.get_children():
		c.queue_free()
	for a: AbilityData in ab.book():
		var learned := ab.is_unlocked(a)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		_ability_list.add_child(row)
		row.add_child(_icon(a.icon_glyph, a.icon_color if learned else Color(0.45, 0.45, 0.5)))
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 430
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var when := "learned" if learned else ab.lock_reason(a).to_lower()
		var kind := "Passive" if a.passive else "Active"
		var cost := "" if a.passive else "\n%d %s · %ss cooldown" % [roundi(ab.effective_cost(a)),
			"mana" if a == PlayerAbilities.shield_ability() else a.cost_name(), a.cooldown]
		var lvl := "Universal" if a == PlayerAbilities.shield_ability() else "Level %d" % a.unlock_level
		if a.ultimate:
			kind = "ULTIMATE"
		# Milestone 17d: show the chosen upgrade and the upgraded cost and cooldown.
		var up := ab.upgrade_option(a.id)
		if not a.passive and a != PlayerAbilities.shield_ability():
			var e := ab.effective(a)
			cost = "\n%d %s · %ss cooldown" % [roundi(ab.effective_cost(a)), a.cost_name(), snappedf(e.cooldown * 1.0, 0.1)]
		var up_text := "" if up.is_empty() else "\nUpgrade: %s - %s" % [up.name, up.text]
		text.text = "%s  -  %s · %s · %s\n%s%s%s" % [a.display_name, lvl, kind, when, a.description, up_text, cost]
		text.add_theme_font_size_override(&"font_size", 12)
		text.add_theme_color_override(&"font_color", (UITheme.GOLD if a.ultimate else Color.WHITE) if learned else UITheme.TEXT_DIM)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(text)
		row.add_child(col)
		var opts := AbilityUpgrades.options(a)
		if learned and not opts.is_empty() and ab.upgrades_unlocked():
			col.add_child(_upgrade_row(a, opts, can_change))
		if a.passive:
			var on := Label.new()
			on.text = "Always on" if learned else ""
			on.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6))
			row.add_child(on)
			continue
		for i in PlayerAbilities.SLOTS:
			var b := Button.new()
			b.text = PlayerAbilities.SLOT_KEYS[i]
			b.custom_minimum_size = Vector2(30, 0)
			b.disabled = not learned or not can_change or ab.bar[i] == a.id
			b.tooltip_text = "Put %s on %s" % [a.display_name, PlayerAbilities.SLOT_KEYS[i]]
			b.focus_mode = Control.FOCUS_NONE
			var slot := i
			var id := a.id
			b.pressed.connect(func() -> void:
				ab.assign(slot, id)
				refresh())
			row.add_child(b)


## Two upgrade buttons for an ability (Milestone 17d). The chosen one is marked.
func _upgrade_row(a: AbilityData, opts: Array, can_change: bool) -> HBoxContainer:
	var ab := player.abilities
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	var l := Label.new()
	l.text = "Upgrade:"
	l.add_theme_font_size_override(&"font_size", 11)
	l.add_theme_color_override(&"font_color", UITheme.GOLD)
	h.add_child(l)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var chosen := ab.upgrade_of(a.id) == i
		var b := Button.new()
		b.text = ("✓ " if chosen else "") + String(o.name)
		b.tooltip_text = "%s: %s" % [o.name, o.text]
		b.disabled = chosen or not can_change
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override(&"font_size", 11)
		if chosen:
			b.add_theme_color_override(&"font_disabled_color", UITheme.GOLD)
		var idx := i
		var id := a.id
		b.pressed.connect(func() -> void:
			ab.choose_upgrade(id, idx)
			refresh())
		h.add_child(b)
	var hint := Label.new()
	hint.text = String(opts[0].name) + ": " + String(opts[0].text) + "   " + String(opts[1].name) + ": " + String(opts[1].text)
	hint.add_theme_font_size_override(&"font_size", 10)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hint)
	return h


func _refresh_spells() -> void:
	for c in _list.get_children():
		c.queue_free()
	var book := player.spells
	var names := PackedStringArray()
	for i in SpellBook.SLOTS:
		var a := book.get_slot(i)
		var usable := i < book.usable_slots()
		names.append("%s: %s" % [SpellBook.SLOT_KEYS[i], (a.display_name if a else "(empty)") if usable else "(needs a tome)"])
	_slots.text = "Spell slots - " + "   ·   ".join(names)
	var mc := player.character.skill_level(Skill.MANA_CONTROL)
	for id in SpellBook.sorted_ids():
		var a := SpellBook.get_spell(id)
		var known := book.knows(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		_list.add_child(row)
		row.add_child(_icon(a.icon_glyph, a.icon_color if known else Color(0.45, 0.45, 0.5)))
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 480
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var req := "Mana Control %d%s" % [a.required_mana_control, "" if mc >= a.required_mana_control else " (you: %d)" % mc]
		text.text = "%s  -  %s\n%s\n%d mana · %ss cooldown · %s" % [a.display_name, "known" if known else "not learned",
			a.description, roundi(player.abilities.effective_cost(a)), a.cooldown, req]
		text.add_theme_font_size_override(&"font_size", 12)
		text.add_theme_color_override(&"font_color", Color.WHITE if known else UITheme.TEXT_DIM)
		row.add_child(text)
		for i in SpellBook.SLOTS:
			var b := Button.new()
			b.text = "Slot %s" % SpellBook.SLOT_KEYS[i]
			b.disabled = not known or book.slots[i] == id or i >= book.usable_slots()
			b.focus_mode = Control.FOCUS_NONE
			var slot := i
			b.pressed.connect(func() -> void:
				book.assign(slot, id)
				refresh())
			row.add_child(b)
