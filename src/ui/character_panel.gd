class_name CharacterPanel
extends PanelContainer
## Character screen (K): class & level, XP, skill allocation, derived stats,
## equipment slots and abilities.

var player: Player

var _title := Label.new()
var _xp_label := Label.new()
var _points_label := Label.new()
var _skill_rows: Dictionary = {}  # skill -> {level: Label, effect: Label, perk: Label, button: Button}
var _stats_label := Label.new()
var _equip_slots: Dictionary = {}  # EquipSlot -> ItemSlot
var _abilities_label := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 8)
	add_child(root)
	_title.add_theme_font_size_override(&"font_size", 24)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	root.add_child(_title)
	root.add_child(_xp_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 18)
	root.add_child(cols)

	# Skills column
	var skills_box := VBoxContainer.new()
	skills_box.custom_minimum_size.x = 470
	cols.add_child(skills_box)
	_points_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	skills_box.add_child(_points_label)
	for s in Skill.ALL:
		var row := VBoxContainer.new()
		row.add_theme_constant_override(&"separation", 0)
		var top := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = Skill.NAMES[s]
		name_l.custom_minimum_size.x = 130
		name_l.tooltip_text = _perk_tooltip(s)
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		top.add_child(name_l)
		var lv := Label.new()
		lv.custom_minimum_size.x = 70
		top.add_child(lv)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(34, 0)
		btn.tooltip_text = "Spend a skill point on %s" % Skill.NAMES[s]
		btn.pressed.connect(func() -> void:
			if player:
				player.character.spend_point(s)
				refresh())
		top.add_child(btn)
		row.add_child(top)
		var effect := Label.new()
		effect.add_theme_font_size_override(&"font_size", 12)
		effect.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		row.add_child(effect)
		var perk := Label.new()
		perk.add_theme_font_size_override(&"font_size", 12)
		perk.add_theme_color_override(&"font_color", Color(0.75, 0.85, 1.0))
		row.add_child(perk)
		skills_box.add_child(row)
		_skill_rows[s] = {"level": lv, "effect": effect, "perk": perk, "button": btn}
	_abilities_label.add_theme_font_size_override(&"font_size", 12)
	_abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_abilities_label.custom_minimum_size.x = 460
	skills_box.add_child(_abilities_label)

	# Stats + equipment column
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	cols.add_child(right)
	var eq_title := Label.new()
	eq_title.text = "Equipment (click to unequip)"
	eq_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	right.add_child(eq_title)
	var grid := GridContainer.new()
	grid.columns = 4
	right.add_child(grid)
	for slot in range(1, ItemData.SLOT_NAMES.size()):
		var box := VBoxContainer.new()
		var cap := Label.new()
		cap.text = ItemData.SLOT_NAMES[slot]
		cap.add_theme_font_size_override(&"font_size", 11)
		cap.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		box.add_child(cap)
		var item_slot := ItemSlot.new(slot, "")
		item_slot.slot_clicked.connect(func(idx: int, _b: MouseButton) -> void:
			if player:
				player.unequip_slot(idx)
				refresh())
		box.add_child(item_slot)
		grid.add_child(box)
		_equip_slots[slot] = item_slot
	var st_title := Label.new()
	st_title.text = "Attributes"
	st_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	right.add_child(st_title)
	_stats_label.add_theme_font_size_override(&"font_size", 13)
	right.add_child(_stats_label)
	var hint := Label.new()
	hint.text = "K / Esc: close · Right-click gear in the inventory to equip"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	root.add_child(hint)


func bind(p: Player) -> void:
	player = p
	var ch := p.character
	ch.xp_changed.connect(func(_a: int, _b: int, _c: int) -> void: refresh())
	ch.skills_changed.connect(refresh)
	ch.recalculated.connect(refresh)
	p.equipment.changed.connect(refresh)
	refresh()


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _perk_tooltip(s: StringName) -> String:
	var lines := PackedStringArray([Skill.DESCRIPTIONS[s], "", "Milestones:"])
	for p in Skill.PERKS[s]:
		lines.append("  %d  %s — %s" % [p[0], p[1], p[2]])
	return "\n".join(lines)


func refresh() -> void:
	if player == null or not visible:
		return
	var ch := player.character
	var c := ch.class_data
	_title.text = "%s · Level %d" % [c.display_name if c else "?", ch.level]
	if ch.level >= Progression.MAX_LEVEL:
		_xp_label.text = "Maximum level reached · %d XP total" % ch.total_xp
	else:
		_xp_label.text = "XP %d / %d to level %d · %d XP total" % [ch.xp, ch.xp_needed(), ch.level + 1, ch.total_xp]
	_points_label.text = "Skill points to spend: %d" % ch.unspent_points
	for s in Skill.ALL:
		var row: Dictionary = _skill_rows[s]
		var base := ch.base_skill(s)
		var eff_lv := ch.skill_level(s)
		row.level.text = "%d%s" % [base, " (+%d)" % (eff_lv - base) if eff_lv != base else ""]
		row.effect.text = ch.describe_skill(s)
		var nxt := Skill.next_perk(s, eff_lv)
		row.perk.text = "Next: %d %s — %s" % [nxt[0], nxt[1], nxt[2]] if not nxt.is_empty() else "All milestones unlocked"
		row.button.disabled = ch.unspent_points <= 0 or base >= Skill.MAX_LEVEL
	for slot in _equip_slots:
		var id := player.equipment.get_item_id(slot)
		(_equip_slots[slot] as ItemSlot).set_stack({"id": id, "count": 1} if id != &"" else null, false)
	var lines := PackedStringArray()
	lines.append("Health %d · Stamina %d · Mana %d" % [roundi(player.health.max_health), roundi(player.stamina.max_stamina), roundi(player.mana.max_mana)])
	lines.append("Armor %d → %d%% damage reduction" % [roundi(ch.armor), roundi(ch.damage_reduction * 100.0)])
	lines.append("Physical power x%.2f (%s x%.2f)" % [ch.physical_mult, String(player.equipment.weapon_type()).capitalize(),
		ch.weapon_mult(player.equipment.weapon_type())])
	lines.append("Spell power x%.2f" % ch.spell_mult)
	lines.append("Crit %d%% · crit damage x%.2f" % [roundi(ch.crit_chance * 100.0), ch.crit_mult])
	lines.append("Attack speed x%.2f · Move speed x%.2f" % [ch.attack_speed, ch.move_speed])
	lines.append("Backstab x%.2f · Block %d%% · Parry %.2fs" % [ch.backstab_mult, roundi(ch.block_reduction * 100.0), ch.parry_window])
	lines.append("Cold protection %+d°C · Heat protection %+d°C" % [roundi(player.temperature.insulation), roundi(player.temperature.cooling)])
	var eq := player.equipment
	lines.append("Outfit: %s · enemies notice you at %d%% range · dodge costs %d%%" % [eq.outfit_style(),
		roundi(player.notice_mult() * 100.0), roundi(player.dodge_cost_mult() * 100.0)])
	var shield_req := c.temperature_shield_requirement() if c else 0
	lines.append("Temperature Shield: %s" % ("available" if ch.can_use_temperature_shield() else "needs Mana Control %d" % shield_req))
	_stats_label.text = "\n".join(lines)
	var ab := PackedStringArray(["Ability bar (change it in the ability book, L, at a bed or campfire):"])
	for i in PlayerAbilities.SLOTS:
		var a := player.abilities.get_slot(i)
		if a == null:
			continue
		var key: String = PlayerAbilities.SLOT_KEYS[i]
		var state := "ready" if player.abilities.is_unlocked(a) else player.abilities.lock_reason(a)
		ab.append("[%s] %s (%s) — %s" % [key, a.display_name, state, a.description])
	var passives := PackedStringArray()
	for a in player.abilities.class_abilities():
		if (a as AbilityData).passive and player.abilities.is_unlocked(a):
			passives.append((a as AbilityData).display_name)
	if not passives.is_empty():
		ab.append("Passives: %s" % ", ".join(passives))
	_abilities_label.text = "\n".join(ab)
