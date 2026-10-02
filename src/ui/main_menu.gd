class_name MainMenu
extends Control
## Title screen: create worlds (name + seed), load or delete saved worlds,
## or quick-play a temporary world.
##
## Command line shortcuts (handled once per launch):
##   -- --seed=<number or text>   quick-play a temporary world with that seed
##   -- --world=<world_id>        load a saved world directly

const GAME_SCENE := "res://scenes/main.tscn"

static var _cmdline_handled := false

var _name_edit := LineEdit.new()
var _seed_edit := LineEdit.new()
var _list := VBoxContainer.new()
var _status := Label.new()
var _confirm := ConfirmationDialog.new()
var _pending_delete := ""
var _selected_class: StringName = ClassRegistry.DEFAULT_CLASS
## Character creation: class, starting kit preview and body (Milestone 14).
var picker := ClassPicker.new()


var _settings := SettingsPanel.new()
var recovery := RecoveryPanel.new()
var achievements := AchievementsPanel.new()
var crash_notice := PanelContainer.new()
var _mp_name := LineEdit.new()
var _mp_host := CheckBox.new()
var _mp_address := LineEdit.new()


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.set_music(&"menu")
	Audio.clear_ambience()
	_build()
	_settings.visible = false
	add_child(_settings)
	UIFx.attach(_settings)
	add_child(recovery)
	UIFx.attach(recovery)
	add_child(achievements)
	UIFx.attach(achievements)
	recovery.restored.connect(func(_id: String) -> void:
		_status.text = "Backup restored."
		_refresh_list())
	_refresh_list()
	if not _cmdline_handled:
		_cmdline_handled = true
		_handle_command_line.call_deferred()


func _handle_command_line() -> void:
	var cls := ClassRegistry.DEFAULT_CLASS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			cls = StringName(arg.substr(8).to_lower())
			_select_class(cls)
		elif arg.begins_with("--name="):
			_mp_name.text = arg.substr(7)
		elif arg == "--host" or arg.begins_with("--host="):
			Net.host_on_load = arg.substr(7).to_int() if arg.begins_with("--host=") else NetProtocol.DEFAULT_PORT
		elif arg == "--server" or arg.begins_with("--server="):
			Net.host_on_load = arg.substr(9).to_int() if arg.begins_with("--server=") else NetProtocol.DEFAULT_PORT
			Net.dedicated_on_load = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--connect="):
			join_game(arg.substr(10))
			return
	if Net.dedicated_on_load and not ("--seed=" in " ".join(OS.get_cmdline_user_args()) or "--world=" in " ".join(OS.get_cmdline_user_args())):
		# Dedicated server without a world argument: play (or create) the world "server".
		if SaveManager.world_exists("server") and SaveManager.load_world("server"):
			_start_game()
		else:
			SaveManager.create_world("server", randi(), cls)
			_start_game()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			SaveManager.start_transient(GameState.seed_from_string(arg.substr(7)), cls)
			_start_game()
			return
		if arg.begins_with("--world="):
			if SaveManager.load_world(arg.substr(8)):
				_start_game()
			return


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.17)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 18)
	center.add_child(root)

	var title := Label.new()
	title.text = "SHARDLANDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 64)
	title.add_theme_color_override(&"font_color", UITheme.GOLD)
	title.add_theme_constant_override(&"outline_size", 12)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "A blocky open-world survival RPG · beta v%s" % ProjectSettings.get_setting("application/config/version", "")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	root.add_child(sub)

	_build_crash_notice(root)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 18)
	root.add_child(cols)

	# New world
	var new_panel := PanelContainer.new()
	new_panel.custom_minimum_size = Vector2(580, 0)
	cols.add_child(new_panel)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override(&"separation", 10)
	new_panel.add_child(nv)
	nv.add_child(_header("Create a world"))
	nv.add_child(_small("World name"))
	_name_edit.placeholder_text = "My World"
	nv.add_child(_name_edit)
	nv.add_child(_small("Seed (number or any text - empty = random)"))
	var seed_row := HBoxContainer.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_edit)
	var dice := Button.new()
	dice.text = "Random"
	dice.pressed.connect(func() -> void: _seed_edit.text = str(randi()))
	seed_row.add_child(dice)
	nv.add_child(seed_row)
	nv.add_child(_small("Class & character"))
	picker.selected_class = _selected_class
	picker.changed.connect(func() -> void: _selected_class = picker.selected_class)
	nv.add_child(picker)
	var create := Button.new()
	create.text = "Create & play"
	create.pressed.connect(_on_create)
	nv.add_child(create)
	var quick := Button.new()
	quick.text = "Quick play (temporary, not saved)"
	quick.pressed.connect(func() -> void:
		SaveManager.start_transient(_read_seed(), _selected_class, picker.look)
		_start_game())
	nv.add_child(quick)
	nv.add_child(_small("Same seed = same world, on any machine."))

	# World list
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(430, 420)
	cols.add_child(list_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override(&"separation", 10)
	list_panel.add_child(lv)
	lv.add_child(_header("Your worlds"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_list)

	# Multiplayer (Milestone 11)
	var mp_panel := PanelContainer.new()
	mp_panel.custom_minimum_size = Vector2(340, 0)
	cols.add_child(mp_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override(&"separation", 8)
	mp_panel.add_child(mv)
	mv.add_child(_header("Multiplayer"))
	mv.add_child(_small("Your name"))
	_mp_name.text = Net.player_name
	_mp_name.max_length = 16
	mv.add_child(_mp_name)
	_mp_host.text = "Host the world I play (port %d)" % NetProtocol.DEFAULT_PORT
	mv.add_child(_mp_host)
	mv.add_child(_small("Friends join with your IP address. Guests use the class picked on the left."))
	mv.add_child(_small("Join a game: address (IP or IP:port)"))
	_mp_address.placeholder_text = "127.0.0.1"
	mv.add_child(_mp_address)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(func() -> void:
		var a := _mp_address.text.strip_edges()
		join_game(a if a != "" else "127.0.0.1"))
	mv.add_child(join)
	mv.add_child(_small("Co-op foundation: building, gathering and crafting\nare shared; monsters are paused in shared games."))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 12)
	root.add_child(bottom)
	var folder := Button.new()
	folder.text = "Open saves folder"
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(SaveManager.worlds_dir)
		OS.shell_open(ProjectSettings.globalize_path(SaveManager.worlds_dir)))
	bottom.add_child(folder)
	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(func() -> void: _settings.visible = true)
	bottom.add_child(settings_btn)
	var ach_btn := Button.new()
	ach_btn.text = "Achievements"
	ach_btn.pressed.connect(func() -> void: achievements.visible = true)
	bottom.add_child(ach_btn)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", Color(1, 0.6, 0.5))
	root.add_child(_status)

	_confirm.dialog_text = "Delete this world permanently?"
	_confirm.confirmed.connect(func() -> void:
		SaveManager.delete_world(_pending_delete)
		_refresh_list())
	add_child(_confirm)


## "The game closed unexpectedly" notice (Milestone 13, CrashHandler).
func _build_crash_notice(root: VBoxContainer) -> void:
	crash_notice.visible = CrashHandler.crashed_last_time
	crash_notice.add_theme_stylebox_override(&"panel", UITheme.panel_style(Color(0.25, 0.1, 0.08, 0.95), Color(1, 0.6, 0.4)))
	root.add_child(crash_notice)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	crash_notice.add_child(h)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ps := CrashHandler.previous_session
	var where := ""
	if ps.has("world"):
		where = " while playing \"%s\"" % ps.world
	l.text = "Shardlands closed unexpectedly last time%s. A crash report was saved - sending it to us helps fix the problem.%s" % [
		where, "\nAn emergency backup of your world was made: use Recover if anything is missing." if String(ps.get("emergency_snapshot", "")) != "" else ""]
	h.add_child(l)
	var report := Button.new()
	report.text = "Open report"
	report.pressed.connect(func() -> void:
		if CrashHandler.last_report != "":
			OS.shell_open(ProjectSettings.globalize_path(CrashHandler.last_report)))
	h.add_child(report)
	if ps.has("world") and SaveManager.world_exists(String(ps.world)):
		var rec := Button.new()
		rec.text = "Recover world"
		rec.pressed.connect(func() -> void: recovery.open(String(ps.world)))
		h.add_child(rec)
	var dismiss := Button.new()
	dismiss.text = "Dismiss"
	dismiss.pressed.connect(func() -> void:
		CrashHandler.crashed_last_time = false
		crash_notice.visible = false)
	h.add_child(dismiss)


func _select_class(id: StringName) -> void:
	_selected_class = id
	picker.select_class(id)


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 24)
	l.add_theme_color_override(&"font_color", UITheme.GOLD)
	return l


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	return l


func _read_seed() -> int:
	var t := _seed_edit.text.strip_edges()
	if t == "":
		return randi()
	return GameState.seed_from_string(t)


func _on_create() -> void:
	var world_name := _name_edit.text.strip_edges()
	if world_name == "":
		world_name = "World %d" % (SaveManager.list_worlds().size() + 1)
	SaveManager.create_world(world_name, _read_seed(), _selected_class, picker.look)
	_start_game()


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var worlds := SaveManager.list_worlds()
	if worlds.is_empty():
		_list.add_child(_small("No saved worlds yet. Create one on the left!"))
		return
	for meta: Dictionary in worlds:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override(&"panel", UITheme.panel_style(Color(0.08, 0.07, 0.1, 0.8), Color(0.45, 0.38, 0.28)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 10)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var n := Label.new()
		n.text = str(meta.get("name", meta.id))
		n.add_theme_font_size_override(&"font_size", 18)
		info.add_child(n)
		var played := int(float(meta.get("play_time", 0)) / 60.0)
		var last := Time.get_datetime_string_from_unix_time(int(float(meta.get("last_played", 0))), true)
		info.add_child(_small("%s Lv %d · Seed %s · %d min played · %s" % [
			String(meta.get("class", "knight")).capitalize(), int(meta.get("level", 1)),
			meta.get("seed", "?"), played, last]))
		var play := Button.new()
		play.text = "Play"
		var id: String = meta.id
		play.pressed.connect(func() -> void:
			if SaveManager.load_world(id):
				_start_game()
			else:
				_status.text = "Could not load '%s' (see log)" % id)
		h.add_child(play)
		var health := SaveManager.verify_world(id)
		if not health.ok:
			info.add_child(_small("⚠ " + ", ".join(health.problems) + " - the newest good copy will be loaded"))
		var rec := Button.new()
		rec.text = "Recover"
		rec.tooltip_text = "Backups of this world"
		rec.pressed.connect(func() -> void: recovery.open(id))
		h.add_child(rec)
		var del := Button.new()
		del.text = "Delete"
		del.pressed.connect(func() -> void:
			_pending_delete = id
			_confirm.dialog_text = "Delete '%s' permanently?" % meta.get("name", id)
			_confirm.popup_centered())
		h.add_child(del)
		_list.add_child(row)


func _start_game() -> void:
	Net.player_name = NetProtocol.clean_name(_mp_name.text) if _mp_name.text != "" else Net.player_name
	Net.player_class = _selected_class
	if _mp_host.button_pressed and Net.host_on_load < 0:
		Net.host_on_load = NetProtocol.DEFAULT_PORT
	get_tree().change_scene_to_file(GAME_SCENE)


## Connects to a host; the world loads once the host welcomes us.
func join_game(address: String) -> void:
	var host := address
	var port := NetProtocol.DEFAULT_PORT
	if address.contains(":"):
		host = address.get_slice(":", 0)
		port = address.get_slice(":", 1).to_int()
	Net.player_name = NetProtocol.clean_name(_mp_name.text) if _mp_name.text != "" else Net.player_name
	Net.player_class = _selected_class
	_status.text = "Connecting to %s:%d..." % [host, port]
	for c in Net.welcomed.get_connections():
		Net.welcomed.disconnect(c.callable)
	for c in Net.join_failed.get_connections():
		Net.join_failed.disconnect(c.callable)
	Net.welcomed.connect(func(data: Dictionary) -> void:
		SaveManager.start_transient(GameState.parse_seed(data.get("seed", "0")), StringName(String(data.get("class", "knight"))), picker.look)
		get_tree().change_scene_to_file(GAME_SCENE), CONNECT_ONE_SHOT)
	Net.join_failed.connect(func(reason: String) -> void: _status.text = "Couldn't join: %s" % reason, CONNECT_ONE_SHOT)
	var err := Net.join(host, port)
	if err != OK:
		_status.text = "Couldn't connect (%s)" % error_string(err)
