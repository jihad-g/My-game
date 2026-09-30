class_name ReputationPanel
extends PanelContainer
## Reputation screen (J): standing with every settlement you know, kingdoms,
## titles and what each tier gives.

var _list := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = "Reputation"
	t.add_theme_font_size_override(&"font_size", 24)
	t.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(t)
	var tiers := Label.new()
	var parts := PackedStringArray()
	for i in Reputation.TIERS.size():
		parts.append("%s %d (-%d%%)" % [Reputation.TIER_NAMES[i], roundi(Reputation.TIERS[i]), roundi(Reputation.DISCOUNTS[i] * 100.0)])
	tiers.text = "Tiers: " + " · ".join(parts) + "\nEarn standing by trading, finishing notice-board requests and defending the land around towns.\nVillages share half of your standing gains with their kingdom. Rulers grant titles at Friendly, Honored and Revered."
	tiers.add_theme_font_size_override(&"font_size", 12)
	tiers.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(tiers)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var hint := Label.new()
	hint.text = "J / Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var w := World.instance
	if w == null:
		return
	var rep := w.player.reputation
	var known: Array[SettlementInfo] = []
	for s in w.generator.settlements.near(w.player.global_position, 6000.0):
		if w.living.is_discovered(s.id):
			known.append(s)
	if known.is_empty():
		var l := Label.new()
		l.text = "You haven't found any settlements yet. Villages show up on the map (M) once you visit them or hear of them."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = 700
		_list.add_child(l)
		return
	for s in known:
		var row := HBoxContainer.new()
		_list.add_child(row)
		var n := Label.new()
		n.custom_minimum_size.x = 300
		n.text = "%s%s" % [s.title() if not s.is_kingdom() else "Kingdom of %s (%s)" % [s.kingdom_name, s.name],
			"" if s.kingdom_name == "" or s.is_kingdom() else "\n   part of %s" % s.kingdom_name]
		n.add_theme_color_override(&"font_color", UITheme.GOLD if s.is_kingdom() else Color.WHITE)
		row.add_child(n)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 18)
		bar.show_percentage = false
		bar.max_value = Reputation.MAX
		bar.value = rep.get_points(s.id)
		bar.add_theme_stylebox_override(&"fill", UITheme.bar_fill(s.color))
		row.add_child(bar)
		var t := Label.new()
		var title := rep.title_for(s.id, s.kingdom_name) if s.is_kingdom() else ""
		t.text = "  %s (%d)%s  ·  %d m away" % [rep.tier_name(s.id), roundi(rep.get_points(s.id)),
			("  ·  " + title) if title != "" else "", roundi(s.distance_to(w.player.global_position))]
		row.add_child(t)
