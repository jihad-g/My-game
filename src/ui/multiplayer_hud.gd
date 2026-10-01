class_name MultiplayerHud
extends Control
## In-game multiplayer UI (Milestone 11): who's online (top centre), a chat log
## and chat line (Enter), join/leave notices, and the way back to the menu
## when the connection drops.

const MAX_LINES := 8
const LINE_TIME := 20.0

var _online := Label.new()
var _log := VBoxContainer.new()
var _input := LineEdit.new()
var _lines: Array = []  # [Label, age]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_online.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_online.position.y = 8
	_online.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_online.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online.add_theme_font_size_override(&"font_size", 14)
	_online.add_theme_color_override(&"font_color", Color(0.7, 0.9, 1.0))
	add_child(_online)
	_log.position = Vector2(16, 0)
	_log.anchor_top = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_top = -330
	_log.offset_bottom = -150
	_log.offset_left = 16
	_log.custom_minimum_size = Vector2(460, 0)
	_log.alignment = BoxContainer.ALIGNMENT_END
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)
	_input.anchor_top = 1.0
	_input.anchor_bottom = 1.0
	_input.offset_top = -146
	_input.offset_bottom = -116
	_input.offset_left = 16
	_input.offset_right = 476
	_input.placeholder_text = "Say something (Enter to send, Esc to cancel)"
	_input.max_length = 200
	_input.visible = false
	_input.text_submitted.connect(_on_submit)
	add_child(_input)
	Net.chat_received.connect(func(from: String, text: String) -> void: add_line("[%s] %s" % [from, text], Color(1, 1, 1)))
	Net.players_changed.connect(_refresh_online)
	Net.mode_changed.connect(_refresh_online)
	Net.disconnected.connect(_on_disconnected)
	_refresh_online()


func add_line(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	l.add_theme_font_size_override(&"font_size", 15)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", 5)
	_log.add_child(l)
	_lines.append([l, 0.0])
	while _lines.size() > MAX_LINES:
		_lines.pop_front()[0].queue_free()


func _process(delta: float) -> void:
	for e in _lines:
		e[1] += delta
		(e[0] as Label).modulate.a = 1.0 if _input.visible else clampf(LINE_TIME - e[1], 0.0, 1.0)


func _refresh_online() -> void:
	if not Net.is_online():
		_online.text = ""
		return
	var names := PackedStringArray()
	for pid in Net.players:
		names.append(String(Net.players[pid].get("name", "?")))
	var role := "Hosting" if Net.is_server() else "Online"
	_online.text = "%s · %d player%s: %s" % [role, names.size(), "" if names.size() == 1 else "s", ", ".join(names)]


func _unhandled_input(event: InputEvent) -> void:
	if not Net.is_online():
		return
	if event.is_action_pressed(&"chat") and not _input.visible:
		_input.visible = true
		_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif _input.visible and event.is_action_pressed(&"ui_cancel"):
		_close_input()
		get_viewport().set_input_as_handled()


func _on_submit(text: String) -> void:
	Net.say(text)
	_close_input()


func _close_input() -> void:
	_input.text = ""
	_input.release_focus()
	_input.visible = false


func is_typing() -> bool:
	return _input.visible


func _on_disconnected(reason: String) -> void:
	Events.toast.emit(reason, Color(1, 0.6, 0.5))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
