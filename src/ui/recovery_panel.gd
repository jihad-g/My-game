class_name RecoveryPanel
extends PanelContainer
## Save recovery screen (Milestone 13): a world's health and its backups, with
## Restore. Opened from the main menu (Recover / the crash notice).

signal closed
signal restored(world_id: String)

var world_id := ""
var _title := Label.new()
var _health := Label.new()
var _list := VBoxContainer.new()
var _confirm := ConfirmationDialog.new()
var _pending := ""


func _ready() -> void:
	custom_minimum_size = Vector2(640, 420)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 24)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	_health.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_health)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	var folder := Button.new()
	folder.text = "Open backups folder"
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(SaveManager.backups_path(world_id))
		OS.shell_open(ProjectSettings.globalize_path(SaveManager.backups_path(world_id))))
	buttons.add_child(folder)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	buttons.add_child(close)
	_confirm.confirmed.connect(func() -> void: restore(_pending))
	add_child(_confirm)


func open(id: String) -> void:
	world_id = id
	refresh()
	visible = true


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var meta := {}
	for m in SaveManager.list_worlds():
		if m.id == world_id:
			meta = m
	_title.text = "Recover \"%s\"" % meta.get("name", world_id)
	var h := SaveManager.verify_world(world_id)
	if h.ok:
		_health.text = "The current save is healthy. Backups are kept automatically; restoring one replaces the current save (which is kept as a backup itself, so you can undo)."
		_health.add_theme_color_override(&"font_color", Color(0.7, 1, 0.7))
	else:
		_health.text = "Problems: %s. The game loads the newest good copy automatically; you can also pick a backup below." % ", ".join(h.problems)
		_health.add_theme_color_override(&"font_color", Color(1, 0.75, 0.45))
	var backups := SaveManager.list_backups(world_id)
	if backups.is_empty():
		var l := Label.new()
		l.text = "No backups yet - they are made when you load a world and every 10 minutes of play."
		_list.add_child(l)
	for b: Dictionary in backups:
		var row := HBoxContainer.new()
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var when := Time.get_datetime_string_from_unix_time(int(b.created), true) if float(b.created) > 0 else String(b.name)
		info.text = "%s  ·  %s  ·  Lv %d  ·  %d min played%s" % [when, _reason(String(b.reason)), int(b.level), int(float(b.play_time) / 60.0),
			"" if b.valid else "  ·  DAMAGED"]
		row.add_child(info)
		var btn := Button.new()
		btn.text = "Restore"
		btn.disabled = not b.valid
		var name: String = b.name
		btn.pressed.connect(func() -> void:
			_pending = name
			_confirm.dialog_text = "Restore the backup from %s?\nThe current save is kept as a backup." % when
			_confirm.popup_centered())
		row.add_child(btn)
		_list.add_child(row)


func restore(name: String) -> bool:
	var ok := SaveManager.restore_backup(world_id, name)
	if ok:
		restored.emit(world_id)
	refresh()
	return ok


static func _reason(r: String) -> String:
	match r:
		"loaded": return "when the world was loaded"
		"autosave": return "during play"
		"crash": return "emergency save (crash)"
		"before restore": return "before a restore"
	return r
