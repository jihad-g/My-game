class_name DamageNumbers
extends Node3D
## Floating combat text using a small pool of Label3D nodes.

const POOL_SIZE := 40
## Milestone 38: the measured motion - pop out sideways 4 frames, shrink from 115%
## over 8, hold 16, fade 5 (33 frames at 30 fps = 1.1 s). See CombatFeel.
const LIFETIME := (CombatFeel.NUM_POP + CombatFeel.NUM_HOLD + CombatFeel.NUM_FADE + 8.0) / CombatFeel.FPS
## Big hits (crits) are the clip's red; numbers have a dark outline.
const CRIT_COLOR := CombatFeel.NUM_RED
const HURT_COLOR := Color(1.0, 0.62, 0.55)
const OUTLINE := Color(0.07, 0.05, 0.05, 1.0)

var _labels: Array[Label3D] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.outline_size = 14
		l.outline_modulate = OUTLINE
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
	var color := HURT_COLOR if target_is_player else CombatFeel.NUM_WHITE
	if is_crit:
		color = CRIT_COLOR
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
	l.global_position = pos
	l.scale = Vector3.ONE * text_scale * 1.15
	l.visible = true
	# Sideways on the screen (the camera's right, either way) and a little up.
	var right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		right = cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var side := (1.0 if randf() < 0.5 else -1.0) * randf_range(CombatFeel.NUM_SIDE.x, CombatFeel.NUM_SIDE.y)
	var to := pos + right * side + Vector3(0, 0.3, 0)
	var tw := l.create_tween()
	l.set_meta(&"tween", tw)
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", to, CombatFeel.sec(CombatFeel.NUM_POP)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "scale", Vector3.ONE * text_scale, CombatFeel.sec(CombatFeel.NUM_SHRINK)).set_delay(CombatFeel.sec(CombatFeel.NUM_POP)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, CombatFeel.sec(CombatFeel.NUM_FADE)).set_delay(LIFETIME - CombatFeel.sec(CombatFeel.NUM_FADE))
	tw.chain().tween_callback(l.hide)
