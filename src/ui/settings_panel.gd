class_name SettingsPanel
extends PanelContainer
## Settings screen (Milestone 10): audio volumes, display, graphics quality and
## comfort options. Opened from the main menu and the pause menu; every change
## applies and saves at once (Settings autoload).

signal closed

var _rows := VBoxContainer.new()


func _ready() -> void:
	custom_minimum_size = Vector2(560, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override(&"font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_rows.add_theme_constant_override(&"separation", 6)
	v.add_child(_rows)
	_section("Audio")
	_slider("Master", "master_volume")
	_slider("Music", "music_volume")
	_slider("Sound effects", "sfx_volume")
	_slider("Ambience", "ambience_volume")
	_slider("Interface", "ui_volume")
	_section("Display & graphics")
	_toggle("Fullscreen", "fullscreen")
	_toggle("V-Sync", "vsync")
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05)
	_choice("Shadows", "shadows", ["Off", "Low", "High"])
	_toggle("Horizon terrain", "far_terrain")
	_toggle("Weather particles", "weather_particles")
	_toggle("Ambient particles (fireflies, leaves...)", "ambient_particles")
	_toggle("Hit & dust particles", "vfx_particles")
	_section("Comfort")
	_toggle("Screen shake", "screen_shake")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 12)
	v.add_child(buttons)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh())
	buttons.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	buttons.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", UITheme.GOLD)
	l.add_theme_font_size_override(&"font_size", 18)
	_rows.add_child(l)


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 300
	h.add_child(l)
	_rows.add_child(h)
	return h


func _slider(text: String, key: String, lo: float = 0.0, hi: float = 1.0, step: float = 0.05) -> void:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = 180
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.set_meta(&"key", key)
	h.add_child(s)
	var val := Label.new()
	val.custom_minimum_size.x = 50
	h.add_child(val)
	s.value = float(Settings.get_value(key))
	val.text = "%d%%" % roundi(s.value * 100.0)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d%%" % roundi(x * 100.0)
		Settings.set_value(key, x))


func _toggle(text: String, key: String) -> void:
	var h := _row(text)
	var c := CheckButton.new()
	c.set_meta(&"key", key)
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	h.add_child(c)


func _choice(text: String, key: String, options: Array) -> void:
	var h := _row(text)
	var o := OptionButton.new()
	for opt in options:
		o.add_item(opt)
	o.set_meta(&"key", key)
	o.selected = int(Settings.get_value(key))
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	h.add_child(o)


## Re-reads every control from Settings (after reset).
func _refresh() -> void:
	for h in _rows.get_children():
		for c in h.get_children():
			if not c.has_meta(&"key"):
				continue
			var v = Settings.get_value(String(c.get_meta(&"key")))
			if c is HSlider:
				(c as HSlider).set_value_no_signal(float(v))
			elif c is CheckButton:
				(c as CheckButton).set_pressed_no_signal(bool(v))
			elif c is OptionButton:
				(c as OptionButton).selected = int(v)
