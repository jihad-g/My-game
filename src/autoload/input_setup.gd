extends Node
## Registers all gameplay input actions at startup.
##
## Actions are defined in code (instead of project.godot) so the binding table is
## data-driven, easy to read, and ready for a future rebinding menu. Existing
## actions (e.g. defined in project settings) are never overwritten.

const KEY_BINDINGS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"sprint": [KEY_SHIFT],
	&"dodge": [KEY_SPACE],
	&"block": [KEY_CTRL],
	&"interact": [KEY_F],
	&"inventory": [KEY_I],
	&"target_lock": [KEY_TAB],
	&"cam_rotate_left": [KEY_Q],
	&"cam_rotate_right": [KEY_E],
	&"cam_pitch_up": [KEY_PAGEUP],
	&"cam_pitch_down": [KEY_PAGEDOWN],
	&"cam_pan_forward": [KEY_UP],
	&"cam_pan_back": [KEY_DOWN],
	&"cam_pan_left": [KEY_LEFT],
	&"cam_pan_right": [KEY_RIGHT],
	&"cam_recenter": [KEY_V],
	&"hotbar_1": [KEY_1],
	&"hotbar_2": [KEY_2],
	&"hotbar_3": [KEY_3],
	&"hotbar_4": [KEY_4],
	&"hotbar_5": [KEY_5],
	&"hotbar_6": [KEY_6],
	&"hotbar_7": [KEY_7],
	&"hotbar_8": [KEY_8],
	&"pause": [KEY_ESCAPE],
	&"respawn": [KEY_R],
	&"toggle_help": [KEY_F1],
	&"toggle_debug": [KEY_F3],
	&"debug_temp_down": [KEY_F6],
	&"debug_temp_up": [KEY_F7],
	&"debug_spawn_enemy": [KEY_F8],
	&"debug_time_skip": [KEY_F9],
	&"quick_save": [KEY_F5],
	&"debug_give_gear": [KEY_F10],
	&"debug_give_xp": [KEY_F11],
	&"ability_1": [KEY_Z],
	&"ability_2": [KEY_X],
	&"ability_3": [KEY_C],
	&"ability_shield": [KEY_T],
	&"character_screen": [KEY_K],
	&"crafting": [KEY_G],
	&"build_mode": [KEY_B],
	&"build_rotate": [KEY_R],
	&"world_map": [KEY_M],
	&"reputation": [KEY_J],
}

const MOUSE_BINDINGS := {
	&"attack_light": [MOUSE_BUTTON_LEFT],
	&"attack_heavy": [MOUSE_BUTTON_RIGHT],
}

const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4",
	&"hotbar_5", &"hotbar_6", &"hotbar_7", &"hotbar_8",
]


func _enter_tree() -> void:
	for action: StringName in KEY_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	for action: StringName in MOUSE_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: MouseButton in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
