class_name HUD
extends CanvasLayer
## In-game HUD, built in code with the shared UITheme.
##
## Shows: health / stamina / hunger bars, temperature gauge with active debuffs,
## hotbar, inventory window, lock-on target frame, interaction prompt, toasts,
## clock, help, debug overlay, loading / death / pause screens.
## NOT IMPLEMENTED yet (later phases): mana bar, XP/level, map, quests,
## skills, equipment, crafting, reputation, building UI.

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
	_loading_label.text = "Generating world...\nSeed: %d" % GameState.world_seed


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
	_temp_effects.add_theme_font_size_override(&"font_size", 12)
	_temp_effects.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.6))
	_temp_effects.autowrap_mode = TextServer.AUTOWRAP_WORD
	_temp_effects.custom_minimum_size.x = 290
	box.add_child(_temp_effects)
	var na := Label.new()
	na.text = "Mana · XP · Level: Phase 2 (not implemented)"
	na.add_theme_font_size_override(&"font_size", 11)
	na.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.65))
	box.add_child(na)


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
	not_impl.text = "Equipment / Crafting: Phase 2"
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


func _build_prompt_and_toasts() -> void:
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_bottom = -110
	_prompt.offset_top = -140
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
		"Arrows pan camera · V recenter · F3 debug · F1 hide help",
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
	var save_na := Button.new()
	save_na.text = "Save (Phase 6 - not implemented)"
	save_na.disabled = true
	pv.add_child(save_na)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
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

func set_loading(on: bool) -> void:
	_loading.visible = on


func set_paused(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _inv_panel.visible:
			_toggle_inventory()
		elif not _loading.visible:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif get_tree().paused:
		return
	elif event.is_action_pressed(&"inventory"):
		_toggle_inventory()
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
