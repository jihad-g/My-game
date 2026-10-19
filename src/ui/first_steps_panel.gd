class_name FirstStepsPanel
extends PanelContainer
## Milestone 37: the "First steps" checklist on the HUD (see Tutorial). It
## offers the short tutorial to a new player, then lists the six steps with a
## tick for each one done and what to do for the next. Skip ends it any time.

const DONE_SHOW := 5.0  # seconds the finished checklist stays up

var _title := Label.new()
var _count := Label.new()
var _skip := Button.new()
var _offer := VBoxContainer.new()
var _rows := VBoxContainer.new()
var _done_t := 0.0
var _last_state := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = 16
	custom_minimum_size = Vector2(310, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title.text = "First steps"
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_count.add_theme_font_size_override(&"font_size", 14)
	_count.add_theme_color_override(&"font_color", Color(0.8, 0.85, 0.9))
	top.add_child(_count)
	_skip.text = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.tooltip_text = "End the tutorial (Settings > Replay the tutorial brings it back)"
	_skip.pressed.connect(func() -> void: Tutorial.skip_first_steps())
	top.add_child(_skip)
	# The offer, for a new player.
	var msg := Label.new()
	msg.text = "New to Shardlands? A short tutorial shows you the basics in six quick steps."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size.x = 290
	msg.add_theme_font_size_override(&"font_size", 15)
	_offer.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	var start := Button.new()
	start.name = "Start"
	start.text = "Start the tutorial"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func() -> void: Tutorial.start_first_steps())
	buttons.add_child(start)
	var no := Button.new()
	no.name = "NoThanks"
	no.text = "No thanks"
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(func() -> void: Tutorial.skip_first_steps())
	buttons.add_child(no)
	_offer.add_child(buttons)
	v.add_child(_offer)
	_rows.add_theme_constant_override(&"separation", 3)
	v.add_child(_rows)
	visible = false
	Tutorial.first_steps_changed.connect(_refresh)
	InputSetup.bindings_changed.connect(_refresh)
	InputSetup.device_changed.connect(func(_pad: bool) -> void: _refresh())
	_last_state = Tutorial.first_steps
	_refresh()


func _process(delta: float) -> void:
	if Tutorial.first_steps != _last_state:
		_done_t = DONE_SHOW if Tutorial.first_steps == "finished" and _last_state == "running" else 0.0
		_last_state = Tutorial.first_steps
	_done_t = maxf(_done_t - delta, 0.0)
	var w := World.instance
	var in_game := w != null and w.is_ready and is_instance_valid(w.player) and bool(Settings.get_value("tutorial_hints"))
	var want := in_game and (Tutorial.first_steps_offered() or Tutorial.first_steps == "running" or _done_t > 0.0)
	if want != visible:
		visible = want
		if want:
			_refresh()
			UIFx.pop_in(self)


func _refresh() -> void:
	var state := Tutorial.first_steps
	_offer.visible = state == ""
	_rows.visible = state != ""
	_skip.visible = state == "running"
	_count.text = "%d / %d" % [Tutorial.fs_done.size(), Tutorial.FIRST_STEPS.size()] if state != "" else ""
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	if state == "":
		return
	var next := Tutorial.first_steps_next()
	for st in Tutorial.FIRST_STEPS:
		var ticked: bool = Tutorial.fs_done.has(st.id)
		var is_next: bool = not next.is_empty() and next.id == st.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		var mark := Label.new()
		mark.text = "✓" if ticked else ("▸" if is_next else "•")
		mark.custom_minimum_size.x = 18
		mark.add_theme_color_override(&"font_color", Color(0.5, 1.0, 0.55) if ticked else (UITheme.GOLD if is_next else Color(0.6, 0.62, 0.66)))
		row.add_child(mark)
		var name_l := Label.new()
		name_l.text = String(st.title)
		name_l.add_theme_font_size_override(&"font_size", 15)
		name_l.add_theme_color_override(&"font_color", Color(0.65, 0.8, 0.65) if ticked else (Color.WHITE if is_next else Color(0.72, 0.74, 0.78)))
		row.add_child(name_l)
		_rows.add_child(row)
		if is_next:
			var how := Label.new()
			how.name = "Next"
			how.text = Tutorial.format_text(st)
			how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			how.custom_minimum_size.x = 280
			how.add_theme_font_size_override(&"font_size", 14)
			how.add_theme_color_override(&"font_color", Color(1.0, 0.93, 0.75))
			var pad := MarginContainer.new()
			pad.add_theme_constant_override(&"margin_left", 24)
			pad.add_child(how)
			_rows.add_child(pad)
	if next.is_empty():
		var done_l := Label.new()
		done_l.text = "All done - you're ready. Good luck out there!"
		done_l.add_theme_color_override(&"font_color", Color(0.75, 1.0, 0.7))
		done_l.add_theme_font_size_override(&"font_size", 15)
		_rows.add_child(done_l)


## The hint under the current step (tests).
func next_text() -> String:
	var n := _rows.find_child("Next", true, false) as Label
	return n.text if n else ""
