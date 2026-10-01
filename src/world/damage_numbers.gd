class_name DamageNumbers
extends Node3D
## Floating combat text using a small pool of Label3D nodes.

const POOL_SIZE := 40
const LIFETIME := 0.9

var _labels: Array[Label3D] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.outline_size = 12
		l.pixel_size = 0.005
		l.render_priority = 20
		l.outline_render_priority = 19
		l.visible = false
		add_child(l)
		_labels.append(l)
	Events.damage_dealt.connect(_on_damage)


func _on_damage(pos: Vector3, amount: float, is_crit: bool, target_is_player: bool, tag: String) -> void:
	if not Settings.get_value("damage_numbers"):
		return
	var text := str(roundi(amount)) if amount >= 1.0 else ("%.1f" % amount)
	if tag != "":
		text = tag if amount <= 0.0 else "%s\n%s" % [tag, text]
	var color := Color(1, 0.35, 0.3) if target_is_player else Color(1, 1, 1)
	if is_crit:
		color = Color(1, 0.8, 0.2)
		text += "!"
	spawn_text(pos, text, color, 1.35 if is_crit else 1.0)


func spawn_text(pos: Vector3, text: String, color: Color, text_scale: float = 1.0) -> void:
	var l := _labels[_next]
	_next = (_next + 1) % _labels.size()
	if l.has_meta(&"tween"):
		var old: Tween = l.get_meta(&"tween")
		if old and old.is_valid():
			old.kill()
	l.text = text
	l.modulate = color
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * text_scale
	l.visible = true
	var tw := l.create_tween()
	l.set_meta(&"tween", tw)
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tw.chain().tween_callback(l.hide)
