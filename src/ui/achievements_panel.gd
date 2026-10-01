class_name AchievementsPanel
extends PanelContainer
## Achievements and lifetime stats (Milestone 13). Works on every platform:
## progress comes from the Platform autoload's profile (and is mirrored to
## Steam when that backend is active).

const STAT_NAMES := {&"items_crafted": "Items crafted", &"trees_felled": "Trees felled", &"monsters_killed": "Monsters defeated",
	&"bosses_killed": "Bosses defeated", &"dungeons_cleared": "Dungeons cleared", &"biomes_discovered": "Biomes discovered",
	&"pois_discovered": "Places discovered", &"copper_traded": "Copper traded", &"raids_repelled": "Raids repelled",
	&"deaths": "Times collapsed", &"distance_km": "Kilometres walked"}

var _list := VBoxContainer.new()
var _summary := Label.new()


func _ready() -> void:
	custom_minimum_size = Vector2(640, 520)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var title := Label.new()
	title.text = "Achievements"
	title.add_theme_font_size_override(&"font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var got := 0
	for a in Achievements.LIST:
		var id: StringName = a[0]
		var done := Platform.is_unlocked(id)
		if done:
			got += 1
		var row := HBoxContainer.new()
		var mark := Label.new()
		mark.text = "★" if done else "☆"
		mark.add_theme_color_override(&"font_color", UITheme.GOLD if done else UITheme.TEXT_DIM)
		mark.add_theme_font_size_override(&"font_size", 22)
		row.add_child(mark)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := Label.new()
		name.text = "???" if (a[5] and not done) else a[1]
		name.add_theme_color_override(&"font_color", UITheme.GOLD if done else UITheme.TEXT)
		info.add_child(name)
		var desc := Label.new()
		desc.text = "A hidden achievement." if (a[5] and not done) else a[2]
		desc.add_theme_font_size_override(&"font_size", 13)
		desc.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		info.add_child(desc)
		row.add_child(info)
		var p := Platform.progress(id)
		if not done and int(p[1]) > 1 and a[Achievements.STAT] != &"":
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(140, 14)
			bar.max_value = float(p[1])
			bar.value = float(p[0])
			bar.show_percentage = false
			bar.add_theme_stylebox_override(&"fill", UITheme.bar_fill(UITheme.GOLD))
			bar.tooltip_text = "%d / %d" % [p[0], p[1]]
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
		elif done:
			var when := Label.new()
			when.text = Time.get_date_string_from_unix_time(int(Platform.unlocked[id]))
			when.add_theme_font_size_override(&"font_size", 12)
			row.add_child(when)
		_list.add_child(row)
	var stats := PackedStringArray()
	for s in STAT_NAMES:
		if Platform.stat(s) > 0:
			stats.append("%s %d" % [STAT_NAMES[s], Platform.stat(s)])
	_summary.text = "%d / %d unlocked  ·  platform: %s%s" % [got, Achievements.LIST.size(), Platform.backend_id(),
		("\n" + " · ".join(stats)) if not stats.is_empty() else ""]
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
