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
var _class_buttons: Dictionary = {}
var _class_info := Label.new()


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh_list()
	if not _cmdline_handled:
		_cmdline_handled = true
		_handle_command_line.call_deferred()


func _handle_command_line() -> void:
	var cls := ClassRegistry.DEFAULT_CLASS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			cls = StringName(arg.substr(8).to_lower())
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
	sub.text = "A blocky open-world survival RPG · prototype v%s" % ProjectSettings.get_setting("application/config/version", "")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	root.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 18)
	root.add_child(cols)

	# New world
	var new_panel := PanelContainer.new()
	new_panel.custom_minimum_size = Vector2(420, 0)
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
	nv.add_child(_small("Class"))
	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override(&"separation", 6)
	nv.add_child(class_row)
	for c in ClassRegistry.all():
		var b := Button.new()
		b.text = c.display_name
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid := c.id
		b.pressed.connect(func() -> void: _select_class(cid))
		class_row.add_child(b)
		_class_buttons[cid] = b
	_class_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_class_info.custom_minimum_size = Vector2(360, 96)
	_class_info.add_theme_font_size_override(&"font_size", 13)
	nv.add_child(_class_info)
	_select_class(_selected_class)
	var create := Button.new()
	create.text = "Create & play"
	create.pressed.connect(_on_create)
	nv.add_child(create)
	var quick := Button.new()
	quick.text = "Quick play (temporary, not saved)"
	quick.pressed.connect(func() -> void:
		SaveManager.start_transient(_read_seed(), _selected_class)
		_start_game())
	nv.add_child(quick)
	nv.add_child(_small("Same seed = same world, on any machine."))

	# World list
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(520, 420)
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


func _select_class(id: StringName) -> void:
	_selected_class = id
	for cid in _class_buttons:
		_class_buttons[cid].button_pressed = cid == id
	var c := ClassRegistry.get_class_data(id)
	var sk := PackedStringArray()
	for s in Skill.ALL:
		sk.append("%s %d" % [Skill.NAMES[s].substr(0, 3), c.starting_skill(s)])
	_class_info.text = "%s — %s\n%s\nStart: %s" % [c.display_name, c.role_summary, c.description, " · ".join(sk)]


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
	SaveManager.create_world(world_name, _read_seed(), _selected_class)
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
		var del := Button.new()
		del.text = "Delete"
		del.pressed.connect(func() -> void:
			_pending_delete = id
			_confirm.dialog_text = "Delete '%s' permanently?" % meta.get("name", id)
			_confirm.popup_centered())
		h.add_child(del)
		_list.add_child(row)


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
