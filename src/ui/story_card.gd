class_name StoryCard
extends PanelContainer
## A page of story in the middle of the screen (Milestone 16): the intro of a
## new world and the ending of the main quest. Does not pause the game.

var _title := Label.new()
var _text := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(640, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	add_child(v)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 30)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(600, 0)
	_text.add_theme_font_size_override(&"font_size", 17)
	v.add_child(_text)
	var b := Button.new()
	b.text = "Continue"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: visible = false)
	v.add_child(b)


func show_story(title: String, text: String) -> void:
	_title.text = title
	_text.text = text
	visible = true
