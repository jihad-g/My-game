class_name SettingsPanel
extends PanelContainer
## Settings screen. Milestone 10: audio, display, graphics, comfort.
## Milestone 13: tabs for Gameplay, Controls (key and gamepad rebinding),
## Audio, Display & graphics and Accessibility. Opened from the main menu and
## the pause menu; every change applies and saves at once (Settings autoload).

signal closed

var tabs := TabContainer.new()
var _rows: VBoxContainer
## Controls tab: action -> [keyboard Button, gamepad Button].
var bind_buttons: Dictionary = {}
var _listening: StringName = &""
var _listening_pad := false
var _bind_note := Label.new()


func _ready() -> void:
	custom_minimum_size = Vector2(720, 560)
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
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	_page("Gameplay")
	_choice("Difficulty", "difficulty", ["Story - you take half damage, hunger is slower", "Normal", "Hard - +50% damage taken, hungrier"])
	_toggle("Tutorial hints", "tutorial_hints")
	var reset_tut := Button.new()
	reset_tut.text = "Replay the tutorial"
	reset_tut.pressed.connect(func() -> void:
		Tutorial.reset_progress()
		Events.toast.emit("Tutorial hints will show again", Color(0.8, 1, 0.8)))
	_row("").add_child(reset_tut)
	_choice_values("Autosave", "autosave_minutes", Settings.AUTOSAVE_CHOICES, func(m: int) -> String: return "Off" if m == 0 else "Every %d min" % m)
	_toggle("Damage numbers", "damage_numbers")
	_slider("Camera rotation speed", "camera_rotate_speed", 0.25, 2.5, 0.05)
	_choice("Movement feel", "movement_feel", ["Snappy - quick start, stop and turn", "Weighty - slower, heavier"])
	_toggle("Fixed isometric camera (no rotating)", "fixed_camera")
	_toggle("Aim assist (swings turn to the nearest enemy in front)", "aim_assist")
	_toggle("Hold attack to keep attacking", "hold_to_chain")
	_slider("Hit-stop (freeze on hit, 0 = off)", "hit_stop", 0.0, 1.5, 0.1)

	_build_controls_page()

	_page("Audio")
	_slider("Master", "master_volume")
	_slider("Music", "music_volume")
	_slider("Sound effects", "sfx_volume")
	_slider("Ambience", "ambience_volume")
	_slider("Interface", "ui_volume")

	_page("Display & graphics")
	_toggle("Fullscreen", "fullscreen")
	_toggle("V-Sync", "vsync")
	_choice_values("Frame rate limit", "max_fps", Settings.FPS_CHOICES, func(f: int) -> String: return "Unlimited" if f == 0 else "%d FPS" % f)
	_toggle("Show FPS", "show_fps")
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05)
	_choice("Shadows", "shadows", ["Off", "Low", "High"])
	_toggle("Horizon terrain", "far_terrain")
	_toggle("Weather particles", "weather_particles")
	_toggle("Ambient particles (fireflies, leaves...)", "ambient_particles")
	_toggle("Hit & dust particles", "vfx_particles")

	_page("Accessibility")
	_slider("Interface scale", "ui_scale", 0.75, 1.5, 0.05)
	_choice("Colour vision filter", "colorblind_mode", Settings.COLORBLIND_NAMES)
	_toggle("High-contrast interface", "high_contrast")
	_toggle("Sound captions", "captions")
	_toggle("Reduce flashing (lightning, hit flashes, pulsing)", "reduce_flashing")
	_toggle("Reduce motion (panel animations, camera shake)", "reduce_motion")
	_toggle("Screen shake", "screen_shake")
	_toggle("Toggle sprint (press once instead of holding)", "toggle_sprint")
	_toggle("Character always faces the mouse", "face_mouse")

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 12)
	v.add_child(buttons)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func() -> void:
		if tabs.current_tab == 1:
			Settings.reset_controls()
		else:
			Settings.reset_defaults()
		_refresh())
	buttons.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	buttons.add_child(close)
	InputSetup.bindings_changed.connect(_refresh_bindings)


func _close() -> void:
	_listening = &""
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or _listening == &"":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_stop_listening("Cancelled.")
		get_viewport().set_input_as_handled()
		return
	if not InputSetup.is_bindable(event) or InputSetup.is_gamepad_event(event) != _listening_pad:
		return
	capture(event)
	get_viewport().set_input_as_handled()


## Binds the input to the action we're listening for (also used by tests).
func capture(event: InputEvent) -> void:
	if _listening == &"":
		return
	var action := _listening
	var ev := event.duplicate() as InputEvent
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var clean := InputEventKey.new()
		clean.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		ev = clean
	elif ev is InputEventJoypadMotion:
		(ev as InputEventJoypadMotion).axis_value = signf((ev as InputEventJoypadMotion).axis_value)
	var clashes := InputSetup.rebind(action, ev)
	var names := PackedStringArray()
	for c in clashes:
		names.append(_action_name(c))
	_stop_listening("%s → %s%s" % [_action_name(action), InputSetup.event_label(ev),
		("   (also used by %s)" % ", ".join(names)) if not names.is_empty() else ""])


func listen(action: StringName, gamepad: bool) -> void:
	_listening = action
	_listening_pad = gamepad
	_bind_note.text = "Press a %s for \"%s\"  (Esc to cancel)" % ["gamepad button" if gamepad else "key or mouse button", _action_name(action)]
	_refresh_bindings()


func _stop_listening(note: String) -> void:
	_listening = &""
	_bind_note.text = note
	_refresh_bindings()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _listening == &"" and event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


# --- Pages and rows ---------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_rows)
	return _rows


func _build_controls_page() -> void:
	_page("Controls")
	_bind_note.text = "Click a binding, then press the new key or button."
	_bind_note.add_theme_color_override(&"font_color", UITheme.GOLD)
	_rows.add_child(_bind_note)
	for group in InputSetup.REBINDABLE:
		_section(group[0])
		for entry in group[1]:
			var action: StringName = entry[0]
			var h := _row(entry[1])
			var kb := Button.new()
			kb.custom_minimum_size.x = 150
			kb.pressed.connect(listen.bind(action, false))
			h.add_child(kb)
			var pad := Button.new()
			pad.custom_minimum_size.x = 150
			pad.pressed.connect(listen.bind(action, true))
			h.add_child(pad)
			var reset := Button.new()
			reset.text = "↺"
			reset.tooltip_text = "Default"
			reset.pressed.connect(func() -> void: InputSetup.reset_action(action))
			h.add_child(reset)
			bind_buttons[action] = [kb, pad]
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action: StringName in bind_buttons:
		var b: Array = bind_buttons[action]
		(b[0] as Button).text = "..." if (_listening == action and not _listening_pad) else _device_label(action, false)
		(b[1] as Button).text = "..." if (_listening == action and _listening_pad) else _device_label(action, true)


func _device_label(action: StringName, pad: bool) -> String:
	var names := PackedStringArray()
	for ev in InputMap.action_get_events(action):
		if InputSetup.is_gamepad_event(ev) == pad:
			names.append(InputSetup.event_label(ev))
	return " / ".join(names) if not names.is_empty() else "—"


func _action_name(action: StringName) -> String:
	for group in InputSetup.REBINDABLE:
		for entry in group[1]:
			if entry[0] == action:
				return entry[1]
	return String(action)


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
	l.custom_minimum_size.x = 320
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	_rows.add_child(h)
	return h


func _slider(text: String, key: String, lo: float = 0.0, hi: float = 1.0, step: float = 0.05) -> void:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = 200
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.set_meta(&"key", key)
	h.add_child(s)
	var val := Label.new()
	val.custom_minimum_size.x = 60
	h.add_child(val)
	s.value = float(Settings.get_value(key))
	val.text = "%d%%" % roundi(s.value * 100.0)
	# The interface scale applies when you let go (rescaling while dragging
	# would move the slider out from under the mouse).
	var live := key != "ui_scale"
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d%%" % roundi(x * 100.0)
		if live or not s.has_focus():
			Settings.set_value(key, x))
	if not live:
		s.drag_ended.connect(func(_c: bool) -> void: Settings.set_value(key, s.value))


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


## A choice whose stored value is one of `choices` (not the index).
func _choice_values(text: String, key: String, choices: Array, label: Callable) -> void:
	var h := _row(text)
	var o := OptionButton.new()
	for c in choices:
		o.add_item(label.call(c))
	o.set_meta(&"key", key)
	o.set_meta(&"choices", choices)
	o.selected = maxi(0, choices.find(int(Settings.get_value(key))))
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, choices[i]))
	h.add_child(o)


## Re-reads every control from Settings (after reset).
func _refresh() -> void:
	for c in find_children("*", "", true, false):
		if not c.has_meta(&"key"):
			continue
		var v = Settings.get_value(String(c.get_meta(&"key")))
		if c is HSlider:
			(c as HSlider).set_value_no_signal(float(v))
		elif c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(bool(v))
		elif c is OptionButton:
			if c.has_meta(&"choices"):
				(c as OptionButton).selected = maxi(0, (c.get_meta(&"choices") as Array).find(int(v)))
			else:
				(c as OptionButton).selected = int(v)
	_refresh_bindings()
