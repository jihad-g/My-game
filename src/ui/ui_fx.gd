class_name UIFx
## Small UI motion (Milestone 10): panels pop in (scale + fade) and play the
## open/close sounds whenever they are shown or hidden.


static func attach(panel: Control, sounds: bool = true) -> void:
	if panel.has_meta(&"ui_fx"):
		return
	panel.set_meta(&"ui_fx", true)
	panel.visibility_changed.connect(func() -> void:
		if not panel.is_inside_tree():
			return
		if panel.visible:
			if sounds:
				Audio.play_ui(&"ui_open", -10.0)
			pop_in(panel)
		elif sounds:
			Audio.play_ui(&"ui_close", -12.0))


static func pop_in(panel: Control, time: float = 0.14) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, time * 0.8)
