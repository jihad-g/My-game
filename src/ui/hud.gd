class_name HUD
extends CanvasLayer
## In-game HUD, built in code with the shared UITheme.
##
## Shows: health / stamina / hunger bars, temperature gauge with active debuffs,
## hotbar, inventory window, lock-on target frame, interaction prompt, toasts,
## clock, help, debug overlay, loading / death / pause screens.
## Also: biome/layer label, world map (M), save buttons in the pause menu.
## Also (Milestone 3): mana/XP/rage bars, ability bar, buffs, character screen (K).
## Also (Milestone 4): crafting screen (G), build palette (B), storage chests,
## "Your land" / shelter indicator.
## Also (Milestone 5): coins, current settlement, dialogue, trade, notice board,
## reputation (J).
## NOT IMPLEMENTED yet (later phases): full quest system.

var player: Player
var world: World

var _root := Control.new()
var _hp_bar: ProgressBar
var _hp_label: Label
var _st_bar: ProgressBar
var _st_label: Label
var _hu_bar: ProgressBar
var _hu_label: Label
var _temp_gauge := TemperatureGauge.new()
var _temp_label := Label.new()
var _temp_effects := Label.new()
var _hotbar_slots: Array[ItemSlot] = []
var _inv_panel := PanelContainer.new()
var _inv_slots: Array[ItemSlot] = []
var _details_name := Label.new()
var _details_body := Label.new()
var _use_button := Button.new()
var _drop_button := Button.new()
var _selected_slot := -1
var _target_panel := PanelContainer.new()
var _target_name := Label.new()
var _target_bar: ProgressBar
var _target: Enemy
var _prompt := Label.new()
var _toasts := VBoxContainer.new()
var _clock := Label.new()
var _biome_label := Label.new()
var _map := WorldMap.new()
var _character := CharacterPanel.new()
var _crafting := CraftingPanel.new()
var _palette := BuildPalette.new()
var _chest := ContainerPanel.new()
var _land_label := Label.new()
var _dialogue := DialoguePanel.new()
var _trade := TradePanel.new()
var _requests := RequestsPanel.new()
var _reputation := ReputationPanel.new()
var _spellbook := SpellbookPanel.new()
var _blueprints := BlueprintPanel.new()
## Raid / world event banner (Milestone 7).
var _event_label := Label.new()
var _coins_label := Label.new()
var _boss_panel := PanelContainer.new()
var _boss_name := Label.new()
var _boss_bar: ProgressBar
var _boss: Enemy
var _town_label := Label.new()
var _mana_bar: ProgressBar
var _mana_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _level_label := Label.new()
var _rage_row: HBoxContainer
var _rage_bar: ProgressBar
var _rage_label: Label
var _buff_label := Label.new()
## Player status effects as coloured chips (Milestone 7).
var _status_row := HFlowContainer.new()
var _status_refresh := 0.0
var _ability_buttons: Array[Button] = []
var _ability_cd: Array[Label] = []
var _banner := Label.new()
var _save_button: Button
var _debug := Label.new()
var _help := PanelContainer.new()
var _loading := ColorRect.new()
var _loading_label := Label.new()
var _death := ColorRect.new()
var _pause := ColorRect.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)
	_build_status()
	_build_hotbar()
	_build_inventory()
	_build_target_frame()
	_build_prompt_and_toasts()
	_build_corner_info()
	_build_help()
	_build_ability_bar()
	_root.add_child(_map)
	_root.add_child(_character)
	_root.add_child(_crafting)
	_root.add_child(_palette)
	_root.add_child(_chest)
	_root.add_child(_dialogue)
	_root.add_child(_trade)
	_root.add_child(_requests)
	_root.add_child(_reputation)
	_root.add_child(_spellbook)
	_root.add_child(_blueprints)
	_dialogue.trade_requested.connect(func(n: NPC) -> void:
		_dialogue.close()
		_trade.open(n))
	Events.npc_talk.connect(func(n: Node) -> void:
		if not _trade.visible:
			_dialogue.open(n as NPC))
	Events.open_requests.connect(func(site: Node) -> void: _requests.open(site))
	Events.coins_changed.connect(func(_c: int) -> void: _refresh_coins())
	_build_boss_bar()
	Events.raid_wave.connect(func(_t: String, w: int, n: int) -> void: show_banner("Raid wave %d / %d" % [w, n]))
	Events.raid_ended.connect(func(_t: String, won: bool) -> void: show_banner("Raid repelled!" if won else "The raiders got away..."))
	Events.world_event_started.connect(func(id: StringName) -> void:
		if id != &"treasure_goblin":
			show_banner(WorldEvents.NAMES.get(id, String(id))))
	Events.boss_started.connect(func(b: Node) -> void:
		_boss = b as Enemy
		_boss_name.text = _boss.display_name()
		_boss_panel.visible = true)
	Events.dungeon_entered.connect(func(_id: String, f: int) -> void:
		if world and world.dungeon:
			_biome_label.text = "%s · Floor %d/%d" % [world.dungeon.poi.title(), f + 1, world.dungeon.plan.floor_count])
	Events.dungeon_left.connect(func(_id: String, _c: bool) -> void:
		if world and world.current_biome:
			_biome_label.text = world.current_biome.display_name)
	Events.boss_ended.connect(func(b: Node) -> void:
		if b == _boss:
			_boss_panel.visible = false
			_boss = null)
	Events.settlement_entered.connect(func(_id: String) -> void: _refresh_town())
	Events.settlement_left.connect(func(_id: String) -> void: _refresh_town())
	Events.reputation_changed.connect(func(_id: String, _v: float) -> void: _refresh_town())
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override(&"font_size", 40)
	_banner.add_theme_color_override(&"font_color", UITheme.GOLD)
	_banner.add_theme_constant_override(&"outline_size", 10)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_build_overlays()
	Events.toast.connect(show_toast)
	Events.item_picked_up.connect(_on_item_picked_up)
	Events.target_changed.connect(_on_target_changed)
	Events.player_died.connect(func() -> void: _death.visible = true)
	Events.player_respawned.connect(func() -> void: _death.visible = false)


func bind(p_player: Player, p_world: World) -> void:
	player = p_player
	world = p_world
	player.health.health_changed.connect(func(c: float, m: float) -> void: _set_bar(_hp_bar, _hp_label, c, m))
	player.stamina.stamina_changed.connect(func(c: float, m: float) -> void: _set_bar(_st_bar, _st_label, c, m))
	player.hunger.hunger_changed.connect(func(c: float, m: float) -> void: _set_bar(_hu_bar, _hu_label, c, m))
	player.inventory.changed.connect(_refresh_inventory)
	player.interact_target_changed.connect(_on_interact_target_changed)
	_set_bar(_hp_bar, _hp_label, player.health.current, player.health.max_health)
	_set_bar(_st_bar, _st_label, player.stamina.current, player.stamina.max_stamina)
	_set_bar(_hu_bar, _hu_label, player.hunger.current, player.hunger.max_hunger)
	_refresh_inventory()
	_map.world = world
	_bind_rpg()
	_crafting.bind(player)
	_chest.bind(player)
	_spellbook.bind(player)
	_blueprints.bind(world)
	_refresh_coins()
	if world.build_mode:
		_palette.bind(player, world.build_mode)
		var help_was := [true]
		world.build_mode.toggled.connect(func(on: bool) -> void:
			if on:
				help_was[0] = _help.visible
				_help.visible = false
			else:
				_help.visible = help_was[0])
	world.biome_changed.connect(_on_biome_changed)
	world.layer_changed.connect(func(_l: int) -> void: _map.visible = false)
	_save_button.disabled = not SaveManager.is_persistent()
	_save_button.text = "Save world  [F5]" if SaveManager.is_persistent() else "Save (temporary world)"


# --- Construction ----------------------------------------------------------------

func _make_bar(color: Color, width: float) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 20)
	bar.show_percentage = false
	bar.add_theme_stylebox_override(&"fill", UITheme.bar_fill(color))
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 13)
	bar.add_child(label)
	return [bar, label]


func _row(label_text: String, bar_parts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 64
	l.add_theme_font_size_override(&"font_size", 14)
	row.add_child(l)
	row.add_child(bar_parts[0])
	return row


func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	var hp := _make_bar(UITheme.HEALTH, 220)
	_hp_bar = hp[0]
	_hp_label = hp[1]
	box.add_child(_row("Health", hp))
	var st := _make_bar(UITheme.STAMINA, 220)
	_st_bar = st[0]
	_st_label = st[1]
	box.add_child(_row("Stamina", st))
	var hu := _make_bar(UITheme.HUNGER, 220)
	_hu_bar = hu[0]
	_hu_label = hu[1]
	box.add_child(_row("Hunger", hu))
	var mp := _make_bar(Color(0.3, 0.5, 1.0), 220)
	_mana_bar = mp[0]
	_mana_label = mp[1]
	box.add_child(_row("Mana", mp))
	var rg := _make_bar(Color(0.85, 0.15, 0.1), 220)
	_rage_bar = rg[0]
	_rage_label = rg[1]
	_rage_row = _row("Rage", rg)
	_rage_row.visible = false
	box.add_child(_rage_row)
	var xpb := _make_bar(Color(0.95, 0.8, 0.3), 220)
	_xp_bar = xpb[0]
	_xp_label = xpb[1]
	_xp_bar.custom_minimum_size.y = 14
	var xrow := _row("XP", xpb)
	_level_label.add_theme_font_size_override(&"font_size", 14)
	_level_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	xrow.add_child(_level_label)
	box.add_child(xrow)
	# Temperature
	var trow := HBoxContainer.new()
	var tl := Label.new()
	tl.text = "Temp"
	tl.custom_minimum_size.x = 64
	tl.add_theme_font_size_override(&"font_size", 14)
	trow.add_child(tl)
	var gauge_holder := MarginContainer.new()
	gauge_holder.add_theme_constant_override(&"margin_top", 3)
	gauge_holder.add_child(_temp_gauge)
	trow.add_child(gauge_holder)
	box.add_child(trow)
	_temp_label.add_theme_font_size_override(&"font_size", 14)
	box.add_child(_temp_label)
	_coins_label.add_theme_font_size_override(&"font_size", 14)
	_coins_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	box.add_child(_coins_label)
	_temp_effects.add_theme_font_size_override(&"font_size", 12)
	_temp_effects.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.6))
	_temp_effects.autowrap_mode = TextServer.AUTOWRAP_WORD
	_temp_effects.custom_minimum_size.x = 290
	box.add_child(_temp_effects)
	_buff_label.add_theme_font_size_override(&"font_size", 12)
	_buff_label.add_theme_color_override(&"font_color", Color(0.7, 0.9, 1.0))
	box.add_child(_buff_label)
	_status_row.custom_minimum_size.x = 290
	_status_row.add_theme_constant_override(&"h_separation", 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_status_row)


func _build_hotbar() -> void:
	var holder := PanelContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_bottom = -14
	_root.add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	holder.add_child(row)
	for i in Inventory.HOTBAR_SIZE:
		var slot := ItemSlot.new(i, str(i + 1))
		slot.slot_clicked.connect(_on_slot_clicked)
		row.add_child(slot)
		_hotbar_slots.append(slot)


func _build_inventory() -> void:
	_inv_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_inv_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inv_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_inv_panel.visible = false
	_root.add_child(_inv_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	_inv_panel.add_child(v)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(title)
	var hint := Label.new()
	hint.text = "Left-click: select / move · Right-click: use · Top row = hotbar (keys 1-8)"
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	v.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	h.add_child(grid)
	for i in 24:
		var slot := ItemSlot.new(i, str(i + 1) if i < Inventory.HOTBAR_SIZE else "")
		slot.slot_clicked.connect(_on_slot_clicked)
		grid.add_child(slot)
		_inv_slots.append(slot)
	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(240, 0)
	details.add_theme_stylebox_override(&"panel", UITheme.panel_style(Color(0.08, 0.07, 0.1, 0.8), Color(0.45, 0.38, 0.28)))
	h.add_child(details)
	var dv := VBoxContainer.new()
	details.add_child(dv)
	_details_name.add_theme_font_size_override(&"font_size", 18)
	dv.add_child(_details_name)
	_details_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details_body.custom_minimum_size = Vector2(220, 120)
	_details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_body.add_theme_font_size_override(&"font_size", 13)
	dv.add_child(_details_body)
	var buttons := HBoxContainer.new()
	dv.add_child(buttons)
	_use_button.text = "Use"
	_use_button.pressed.connect(func() -> void:
		if player and _selected_slot >= 0:
			player.use_slot(_selected_slot))
	buttons.add_child(_use_button)
	_drop_button.text = "Drop 1"
	_drop_button.pressed.connect(func() -> void:
		if player and _selected_slot >= 0:
			player.drop_slot(_selected_slot, 1))
	buttons.add_child(_drop_button)
	var not_impl := Label.new()
	not_impl.text = "K: character & equipment · G: crafting · B: build mode"
	not_impl.add_theme_font_size_override(&"font_size", 11)
	not_impl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.65))
	v.add_child(not_impl)


func _build_target_frame() -> void:
	_target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_target_panel.offset_top = 16
	_target_panel.visible = false
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_target_panel)
	var v := VBoxContainer.new()
	_target_panel.add_child(v)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_target_name)
	var parts := _make_bar(UITheme.HEALTH, 300)
	_target_bar = parts[0]
	v.add_child(_target_bar)


func _build_ability_bar() -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_bottom = -104
	holder.add_theme_constant_override(&"separation", 8)
	_root.add_child(holder)
	for i in 6:
		if i == 4:
			var gap := Control.new()
			gap.custom_minimum_size.x = 14
			holder.add_child(gap)
		var b := Button.new()
		b.custom_minimum_size = Vector2(54, 54)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override(&"font_size", 18)
		var idx := i
		b.pressed.connect(func() -> void:
			if player:
				if idx < 4:
					player.abilities.try_use(idx)
				else:
					player.abilities.try_cast(idx - 4))
		var key := Label.new()
		key.text = ["Z", "X", "C", "T", "Y", "H"][i]
		key.position = Vector2(4, 1)
		key.add_theme_font_size_override(&"font_size", 11)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		var cd := Label.new()
		cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cd.add_theme_font_size_override(&"font_size", 12)
		cd.add_theme_color_override(&"font_color", Color(1, 0.9, 0.6))
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cd)
		holder.add_child(b)
		_ability_buttons.append(b)
		_ability_cd.append(cd)


func _bind_rpg() -> void:
	var ch := player.character
	_character.bind(player)
	player.mana.mana_changed.connect(func(c: float, m: float) -> void: _set_bar(_mana_bar, _mana_label, c, m))
	_set_bar(_mana_bar, _mana_label, player.mana.current, player.mana.max_mana)
	ch.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(ch.xp, ch.xp_needed(), ch.level)
	player.abilities.rage_changed.connect(func(v: float) -> void: _set_bar(_rage_bar, _rage_label, v, PlayerAbilities.MAX_RAGE))
	_rage_row.visible = ch.class_data != null and ch.class_data.uses_rage
	_set_bar(_rage_bar, _rage_label, player.abilities.rage, PlayerAbilities.MAX_RAGE)
	Events.level_up.connect(_on_level_up)
	Events.xp_gained.connect(func(amount: int, source: int) -> void:
		show_toast("+%d XP (%s)" % [amount, Progression.SOURCE_NAMES[source]], Color(1, 0.9, 0.5)))
	_refresh_abilities()


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_level_label.text = "  Lv %d" % level
	_xp_bar.max_value = maxi(needed, 1)
	_xp_bar.value = xp
	_xp_label.text = "%d / %d" % [xp, needed] if needed > 0 else "MAX"


## Big centred announcement that fades out.
func show_banner(text: String, color: Color = UITheme.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)


func _on_level_up(level: int) -> void:
	_banner.add_theme_color_override(&"font_color", UITheme.GOLD)
	var pts := player.character.unspent_points
	_banner.text = "Level %d!\n%d skill point%s to spend (K)" % [level, pts, "" if pts == 1 else "s"]
	var tw := _banner.create_tween()
	_banner.modulate.a = 1.0
	tw.tween_interval(2.5)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)
	var unlocked := PackedStringArray()
	for i in 3:
		var a := player.abilities.get_slot(i)
		if a and a.unlock_level == level:
			unlocked.append(a.display_name)
	if not unlocked.is_empty():
		show_toast("New ability: %s" % ", ".join(unlocked), UITheme.GOLD)
	_refresh_abilities()


func _refresh_abilities() -> void:
	if player == null:
		return
	for i in 4:
		var a := player.abilities.get_slot(i)
		var b := _ability_buttons[i]
		if a == null:
			b.visible = false
			continue
		b.visible = true
		b.text = a.icon_glyph
		var unlocked := player.abilities.is_unlocked(a)
		b.modulate = a.icon_color.lerp(Color.WHITE, 0.35) if unlocked else Color(0.4, 0.4, 0.45)
		var cost := player.abilities.effective_cost(a)
		b.tooltip_text = "%s\n%s\nCost: %d %s · Cooldown %ss%s" % [a.display_name, a.description, roundi(cost),
			"mana" if i == 3 else a.cost_name(), a.cooldown,
			"" if unlocked else "\n" + player.abilities.lock_reason(a)]
		var cd := player.abilities.cooldown_left(a)
		if cd >= 0.05:
			_ability_cd[i].text = "%.1f" % cd
		elif unlocked:
			_ability_cd[i].text = ""
		else:
			_ability_cd[i].text = "Lv%d" % a.unlock_level if i < 3 else "MC"
	# Spell slots (Milestone 7)
	for k in SpellBook.SLOTS:
		var b := _ability_buttons[4 + k]
		var sp := player.spells.get_slot(k)
		if sp == null:
			b.text = "+"
			b.modulate = Color(0.55, 0.5, 0.65)
			b.tooltip_text = "Spell slot %s: empty\nLearn spells from tomes. Spellbook: L" % ["Y", "H"][k]
			_ability_cd[4 + k].text = ""
			continue
		b.text = sp.icon_glyph
		var why := player.abilities.spell_block_reason(sp)
		var castable := why == "" or why == "Not enough mana"
		b.modulate = sp.icon_color.lerp(Color.WHITE, 0.35) if castable else Color(0.4, 0.4, 0.45)
		b.tooltip_text = "%s\n%s\nCost: %d mana · Cooldown %ss · Mana Control %d" % [sp.display_name, sp.description,
			roundi(player.abilities.effective_cost(sp)), sp.cooldown, sp.required_mana_control]
		var cd := player.abilities.cooldown_left(sp)
		_ability_cd[4 + k].text = "%.1f" % cd if cd >= 0.05 else ("" if castable else "MC")


func _build_prompt_and_toasts() -> void:
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_bottom = -166
	_prompt.offset_top = -196
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", 18)
	_prompt.add_theme_color_override(&"font_color", UITheme.GOLD)
	_root.add_child(_prompt)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_right = -20
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


func _build_corner_info() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_clock.add_theme_font_size_override(&"font_size", 18)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_clock)
	_biome_label.add_theme_font_size_override(&"font_size", 15)
	_biome_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_biome_label)
	_town_label.add_theme_font_size_override(&"font_size", 15)
	_town_label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.6))
	_town_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_town_label)
	_land_label.add_theme_font_size_override(&"font_size", 14)
	_land_label.add_theme_color_override(&"font_color", Color(0.6, 0.85, 1.0))
	_land_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_land_label)
	# Raids and rare events (Milestone 7).
	_event_label.add_theme_font_size_override(&"font_size", 15)
	_event_label.add_theme_color_override(&"font_color", Color(1, 0.6, 0.45))
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_event_label.custom_minimum_size.x = 300
	_event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_event_label)
	_debug.add_theme_font_size_override(&"font_size", 12)
	_debug.add_theme_color_override(&"font_color", Color(0.8, 0.9, 1.0))
	_debug.visible = false
	v.add_child(_debug)


func _build_help() -> void:
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_left = 16
	_help.offset_bottom = -16
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_help)
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", 12)
	l.text = "\n".join([
		"WASD move · Shift sprint · Space dodge roll",
		"LMB light combo · RMB heavy · Hold Ctrl block (tap = parry)",
		"Tab lock-on target · F interact / gather · I inventory",
		"1-8 use hotbar item (eat / place campfire)",
		"Q/E or MMB-drag rotate · Wheel zoom · PgUp/PgDn tilt",
		"Z/X/C class abilities · T temperature shield · K character",
		"Y/H cast spells · L spellbook · N blueprints",
		"G crafting · B build mode (LMB place, RMB remove, R rotate, U repair)",
		"F talk to townsfolk / read notice boards · J reputation",
		"Arrows pan camera · V recenter · M map · F5 save",
		"F3 debug · F1 hide help",
		"Debug: F6/F7 temp -/+10°C · F8 spawn boar · F9 +2h",
	])
	_help.add_child(l)


func _build_overlays() -> void:
	for overlay: ColorRect in [_loading, _death, _pause]:
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		_root.add_child(overlay)
	_loading.color = Color(0.07, 0.08, 0.14, 1.0)
	_loading.visible = true
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override(&"font_size", 28)
	_loading.add_child(_loading_label)

	_death.color = Color(0.25, 0.02, 0.02, 0.55)
	var dv := _centered_box(_death)
	var dl := Label.new()
	dl.text = "You collapsed..."
	dl.add_theme_font_size_override(&"font_size", 40)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(dl)
	var rb := Button.new()
	rb.text = "Respawn  [R]"
	rb.pressed.connect(func() -> void:
		if player:
			player.respawn())
	dv.add_child(rb)

	_pause.color = Color(0.03, 0.03, 0.06, 0.6)
	var pv := _centered_box(_pause)
	var pl := Label.new()
	pl.text = "Paused"
	pl.add_theme_font_size_override(&"font_size", 40)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var seed_label := Label.new()
	seed_label.text = "World seed: %d" % GameState.world_seed
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(seed_label)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: set_paused(false))
	pv.add_child(resume)
	_save_button = Button.new()
	_save_button.text = "Save world"
	_save_button.pressed.connect(func() -> void:
		if world:
			world.save_now(true))
	pv.add_child(_save_button)
	var menu := Button.new()
	menu.text = "Save & quit to menu"
	menu.pressed.connect(_quit_to_menu)
	pv.add_child(menu)
	var quit := Button.new()
	quit.text = "Save & quit to desktop"
	quit.pressed.connect(func() -> void:
		if world and world.is_ready:
			world.save_now(false)
		get_tree().quit())
	pv.add_child(quit)


func _centered_box(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	center.add_child(v)
	return v


# --- Runtime -----------------------------------------------------------------------

func set_loading(on: bool, text: String = "") -> void:
	_loading.visible = on
	if text != "":
		_loading_label.text = text


func _quit_to_menu() -> void:
	if world and world.is_ready:
		world.save_now(false)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_biome_changed(b: BiomeData) -> void:
	_biome_label.text = b.display_name


func set_paused(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if world and world.blueprints and world.blueprints.placer.active:
			world.blueprints.placer.end()
		elif world and world.build_mode and world.build_mode.active:
			world.build_mode.set_active(false)
		elif _blueprints.visible:
			_blueprints.visible = false
		elif _trade.visible:
			_trade.close()
		elif _dialogue.visible:
			_dialogue.close()
		elif _requests.visible:
			_requests.close()
		elif _reputation.visible:
			_reputation.visible = false
		elif _spellbook.visible:
			_spellbook.visible = false
		elif _chest.visible:
			_chest.close()
		elif _crafting.visible:
			_crafting.visible = false
		elif _character.visible:
			_character.visible = false
		elif _map.visible:
			_map.visible = false
		elif _inv_panel.visible:
			_toggle_inventory()
		elif not _loading.visible:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif get_tree().paused:
		return
	elif event.is_action_pressed(&"inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reputation"):
		if not _loading.visible:
			_reputation.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"blueprints"):
		if not _loading.visible:
			_blueprints.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spellbook"):
		if not _loading.visible:
			_spellbook.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"crafting"):
		if not _loading.visible:
			_crafting.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"character_screen"):
		if not _loading.visible:
			_character.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"world_map"):
		if not _loading.visible:
			_map.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_help"):
		_help.visible = not _help.visible
	elif event.is_action_pressed(&"toggle_debug"):
		_debug.visible = not _debug.visible


func _toggle_inventory() -> void:
	_inv_panel.visible = not _inv_panel.visible
	_selected_slot = -1
	_refresh_inventory()


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_temperature()
	if world and world.day_night:
		_clock.text = world.day_night.time_string()
	if _target and is_instance_valid(_target):
		_target_bar.value = _target.health.get_ratio() * 100.0
		_target_panel.visible = not _target.is_dead and _target.is_visible_in_tree()
	if _debug.visible:
		_update_debug()
	_refresh_abilities()
	_update_buffs()
	_status_refresh -= _delta
	if _status_refresh <= 0.0:
		_status_refresh = 0.2
		_update_status_chips()
		if world and world.raids and world.events:
			var parts := PackedStringArray()
			for t in [world.raids.status_text(), world.events.status_text()]:
				if t != "":
					parts.append(t)
			_event_label.text = "\n".join(parts)
			_event_label.visible = not parts.is_empty()
	_update_land()
	_update_boss_bar()


func _build_boss_bar() -> void:
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.offset_top = 70
	_boss_panel.visible = false
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_panel)
	var v := VBoxContainer.new()
	_boss_panel.add_child(v)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override(&"font_size", 20)
	_boss_name.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.4))
	v.add_child(_boss_name)
	var parts := _make_bar(Color(0.75, 0.1, 0.12), 560)
	_boss_bar = parts[0]
	_boss_bar.custom_minimum_size.y = 22
	v.add_child(_boss_bar)


func _update_boss_bar() -> void:
	if _boss == null:
		return
	if not is_instance_valid(_boss) or _boss.is_dead or not _boss.is_inside_tree() or not _boss.visible \
			or (_boss.has_method("is_boss") and not _boss.is_boss()):
		_boss_panel.visible = false
		_boss = null
		return
	_boss_bar.max_value = _boss.health.max_health
	_boss_bar.value = _boss.health.current
	var enr: bool = _boss.get("enraged") == true
	_boss_name.text = "%s%s" % [_boss.display_name(), "  - ENRAGED" if enr else ""]


func _refresh_coins() -> void:
	if player:
		_coins_label.text = "Coins: %s" % Economy.format_coins(player.coins)


func _refresh_town() -> void:
	if world == null or world.living == null or player == null:
		return
	var s := world.living.current
	if s == null:
		_town_label.text = ""
		return
	var rep := player.reputation
	_town_label.text = "%s · %s" % [s.short_title(), rep.tier_name(s.id)]


func _update_land() -> void:
	if world == null or world.building == null:
		return
	var p := player.global_position
	var parts := PackedStringArray()
	if world.building.is_claimed(p):
		parts.append("Your land")
	if world.building.is_sheltered(p):
		parts.append("Sheltered")
	_land_label.text = " · ".join(parts)


func _set_bar(bar: ProgressBar, label: Label, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _update_temperature() -> void:
	var t := player.temperature
	_temp_gauge.set_values(t.felt, t.ambient)
	var extra := ""
	var air := t.ambient
	if world:
		air = world.get_air_temperature(player.global_position)
		var warmth := t.ambient - air
		if warmth > 0.5:
			extra = "  (fire +%d°)" % roundi(warmth)
	var buff := t.get_buff_offset()
	if absf(buff) > 0.1:
		extra += "  (food %+d°)" % roundi(buff)
	if player.is_swimming:
		extra += "  · Swimming"
	_temp_label.text = "%s · Body %d°C · Air %d°C%s" % [t.exposure_name(), roundi(t.felt), roundi(air), extra]
	var color := Color(0.7, 1.0, 0.7)
	if t.exposure < 0:
		color = Color(0.6, 0.8, 1.0)
	elif t.exposure > 0:
		color = Color(1.0, 0.7, 0.45)
	_temp_label.add_theme_color_override(&"font_color", color)
	var mods := player.stats.get_source(&"temperature")
	var parts := PackedStringArray()
	for stat: StringName in mods:
		parts.append(Stats.describe(stat, mods[stat]))
	var hunger_mods := player.stats.get_source(&"hunger")
	var hparts := PackedStringArray()
	for stat: StringName in hunger_mods:
		hparts.append(Stats.describe(stat, hunger_mods[stat]))
	var lines := PackedStringArray()
	if not parts.is_empty():
		lines.append("%s: %s" % [t.exposure_name(), ", ".join(parts)])
	if not hparts.is_empty():
		lines.append("%s: %s" % [player.hunger.state_name(), ", ".join(hparts)])
	_temp_effects.text = "\n".join(lines)


func _update_buffs() -> void:
	var parts := PackedStringArray()
	for id in player.abilities.buffs:
		var t := float(player.abilities.buffs[id])
		var nice := String(id).capitalize()
		parts.append("%s %s" % [nice, "%d:%02d" % [int(t) / 60, int(t) % 60] if t >= 60.0 else "%ds" % ceili(t)])
	_buff_label.text = " · ".join(parts)


## One chip per active status effect: name, stacks and seconds left.
func _update_status_chips() -> void:
	var fx: Dictionary = player.status.effects if player.status else {}
	var ids: Array = fx.keys()
	while _status_row.get_child_count() < ids.size():
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		chip.add_theme_stylebox_override(&"panel", sb)
		var l := Label.new()
		l.add_theme_font_size_override(&"font_size", 12)
		l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
		chip.add_child(l)
		_status_row.add_child(chip)
	for i in _status_row.get_child_count():
		var chip := _status_row.get_child(i) as PanelContainer
		chip.visible = i < ids.size()
		if not chip.visible:
			continue
		var id: StringName = ids[i]
		var e: Dictionary = fx[id]
		var st := int(e.get("stacks", 1))
		(chip.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = StatusEffects.color_of(id)
		(chip.get_child(0) as Label).text = "%s%s %ds" % [StatusEffects.display_name(id), " x%d" % st if st > 1 else "", ceili(float(e.time))]


func _update_debug() -> void:
	var p := player.global_position
	var lines := PackedStringArray()
	lines.append("FPS %d · draw calls %d" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	lines.append("Seed %d" % GameState.world_seed)
	lines.append("Pos %.1f, %.1f, %.1f" % [p.x, p.y, p.z])
	var c := TerrainGenerator.world_to_chunk(p)
	lines.append("Chunk %d, %d" % [c.x, c.y])
	if world:
		var s := world.chunk_manager.get_debug_stats()
		lines.append("Chunks %d (L0 %d / L1 %d / L2 %d)" % [s.loaded, s.lod0, s.lod1, s.lod2])
		lines.append("Gen pending %d queued %d pooled %d" % [s.pending, s.queued, s.pooled])
		lines.append("Generated %d (discarded %d)" % [s.generated, s.discarded])
		lines.append("Enemies %d · Pickups %d" % [world.spawner.active_count(), world.pickup_pool.active_count()])
		lines.append("Air %.1f°C (debug offset %+d)" % [world.get_air_temperature(p), roundi(world.debug_temperature_offset)])
		var climate := world.generator.get_climate(p)
		lines.append("Layer %s · Biome %s" % ["underground" if world.layer == 1 else "surface",
			world.current_biome.id if world.current_biome else "-"])
		lines.append("Climate T %.2f M %.2f (base %.1f°C ±%.1f)" % [world.generator.temperature01(p.x, p.z),
			world.generator.moisture01(p.x, p.z), climate.x, climate.y])
	_debug.text = "\n".join(lines)


func _refresh_inventory() -> void:
	if player == null:
		return
	var inv := player.inventory
	for i in _hotbar_slots.size():
		_hotbar_slots[i].set_stack(inv.get_slot(i), _inv_panel.visible and i == _selected_slot)
	for i in _inv_slots.size():
		_inv_slots[i].set_stack(inv.get_slot(i), i == _selected_slot)
	_update_details()


func _update_details() -> void:
	var s = player.inventory.get_slot(_selected_slot) if _selected_slot >= 0 else null
	var item: ItemData = ItemDB.get_item(s.id) if s != null else null
	if item == null:
		_details_name.text = "Select an item"
		_details_name.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		_details_body.text = ""
		_use_button.disabled = true
		_drop_button.disabled = true
		return
	_details_name.text = "%s  x%d" % [item.display_name, s.count]
	_details_name.add_theme_color_override(&"font_color", item.rarity_color())
	var lines := PackedStringArray(["%s %s" % [item.rarity_name(), item.category_name()]])
	lines.append_array(item.effect_lines())
	lines.append("")
	lines.append(item.description)
	lines.append("Value: %d copper" % item.base_value)
	_details_body.text = "\n".join(lines)
	_use_button.disabled = not (item.is_consumable() or item.is_placeable())
	_use_button.text = "Place" if item.is_placeable() else "Eat" if item.is_consumable() else "Use"
	_drop_button.disabled = false


func _on_slot_clicked(index: int, button: MouseButton) -> void:
	if player == null or player.is_dead:
		return
	if button == MOUSE_BUTTON_RIGHT or not _inv_panel.visible:
		player.use_slot(index)
		return
	if _selected_slot == -1:
		if player.inventory.get_slot(index) != null:
			_selected_slot = index
	elif _selected_slot == index:
		_selected_slot = -1
	else:
		player.inventory.move_slot(_selected_slot, index)
		_selected_slot = index if player.inventory.get_slot(index) != null else -1
	_refresh_inventory()


func _on_interact_target_changed(target: Node) -> void:
	if target and target.has_method("get_interact_text"):
		_prompt.text = "[F] %s" % target.get_interact_text()
	else:
		_prompt.text = ""


func _on_target_changed(target: Node) -> void:
	_target = target as Enemy
	if _target:
		_target_name.text = _target.display_name()
		_target_panel.visible = true
	else:
		_target_panel.visible = false


func _on_item_picked_up(id: StringName, count: int) -> void:
	var item: ItemData = ItemDB.get_item(id)
	if item:
		show_toast("+%d %s" % [count, item.display_name], item.rarity_color())


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_font_size_override(&"font_size", 17)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		_toasts.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
