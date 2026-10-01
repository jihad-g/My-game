class_name TutorialCard
extends PanelContainer
## The tutorial hint on the HUD (Milestone 13): title, text with the current
## key names, and a "hide" button (completes the hint).

var _title := Label.new()
var _text := Label.new()
var _step: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_right = -16
	custom_minimum_size = Vector2(330, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Got it"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		if not _step.is_empty():
			Tutorial.complete(_step.id))
	top.add_child(close)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 310
	_text.add_theme_font_size_override(&"font_size", 15)
	v.add_child(_text)
	visible = false
	Tutorial.hint_changed.connect(show_step)
	InputSetup.bindings_changed.connect(_refresh)
	InputSetup.device_changed.connect(func(_p: bool) -> void: _refresh())
	if not Tutorial.current.is_empty():
		show_step(Tutorial.current)


func show_step(step: Dictionary) -> void:
	_step = step
	visible = not step.is_empty()
	if visible:
		_refresh()
		UIFx.pop_in(self)
		Audio.play_ui(&"notify", -8.0)


func _refresh() -> void:
	if _step.is_empty():
		return
	_title.text = "Tip: " + String(_step.title)
	_text.text = Tutorial.format_text(_step)


func text() -> String:
	return _text.text
