extends Node
## Registers all gameplay input actions at startup, and handles rebinding
## (Milestone 13).
##
## Actions are defined in code (instead of project.godot) so the binding table is
## data-driven. Each action gets its default keyboard/mouse binding and, where it
## makes sense, a gamepad binding. Players rebind actions in Settings → Controls;
## custom bindings are saved by the Settings autoload ([input] section of
## settings.cfg) and re-applied on start.

## Emitted when bindings change (HUD hints and the guide refresh their key names).
signal bindings_changed
## Emitted when the player switches between keyboard/mouse and a gamepad.
signal device_changed(gamepad: bool)

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
	&"cam_recenter": [KEY_HOME],
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
	&"debug_weather": [KEY_F2],
	&"chat": [KEY_ENTER],
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
	&"ability_5": [KEY_V],
	&"ability_6": [KEY_U],
	&"character_screen": [KEY_K],
	&"crafting": [KEY_G],
	&"build_mode": [KEY_B],
	&"build_rotate": [KEY_R],
	&"world_map": [KEY_M],
	&"reputation": [KEY_J],
	&"build_repair": [KEY_U],
	&"spell_1": [KEY_Y],
	&"spell_2": [KEY_H],
	&"spell_3": [KEY_N],
	&"spellbook": [KEY_L],
	&"journal": [KEY_O],
	&"blueprints": [KEY_P],
	&"debug_raid": [KEY_F4],
	&"debug_event": [KEY_F12],
}

const MOUSE_BINDINGS := {
	&"attack_light": [MOUSE_BUTTON_LEFT],
	&"attack_heavy": [MOUSE_BUTTON_RIGHT],
}

## Default gamepad bindings (Xbox layout names): buttons, or [axis, direction].
const PAD_BINDINGS := {
	&"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"cam_rotate_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	&"cam_rotate_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	&"cam_pitch_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	&"cam_pitch_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	&"attack_light": [JOY_BUTTON_X],
	&"attack_heavy": [JOY_BUTTON_Y],
	&"dodge": [JOY_BUTTON_B],
	&"interact": [JOY_BUTTON_A],
	&"block": [JOY_BUTTON_LEFT_SHOULDER],
	&"ability_1": [JOY_BUTTON_RIGHT_SHOULDER],
	&"ability_2": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"ability_3": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	&"sprint": [JOY_BUTTON_LEFT_STICK],
	&"target_lock": [JOY_BUTTON_RIGHT_STICK],
	&"spell_1": [JOY_BUTTON_DPAD_UP],
	&"spell_2": [JOY_BUTTON_DPAD_DOWN],
	&"hotbar_1": [JOY_BUTTON_DPAD_LEFT],
	&"hotbar_2": [JOY_BUTTON_DPAD_RIGHT],
	&"inventory": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
	&"respawn": [JOY_BUTTON_A],
}

const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4",
	&"hotbar_5", &"hotbar_6", &"hotbar_7", &"hotbar_8",
]

## Actions shown in Settings → Controls, by group, with their display names.
## (Debug keys are deliberately not rebindable.)
const REBINDABLE := [
	["Movement", [[&"move_forward", "Move forward"], [&"move_back", "Move back"], [&"move_left", "Move left"],
		[&"move_right", "Move right"], [&"sprint", "Sprint"], [&"dodge", "Dodge roll"]]],
	["Combat", [[&"attack_light", "Light attack"], [&"attack_heavy", "Heavy attack"], [&"block", "Block / parry"],
		[&"target_lock", "Lock on"], [&"ability_1", "Ability 1"], [&"ability_2", "Ability 2"], [&"ability_3", "Ability 3"],
		[&"ability_shield", "Ability 4 (T)"], [&"ability_5", "Ability 5"], [&"ability_6", "Ability 6"],
		[&"spell_1", "Spell 1"], [&"spell_2", "Spell 2"], [&"spell_3", "Spell 3 (with a tome)"]]],
	["Interaction", [[&"interact", "Interact / gather"], [&"hotbar_1", "Hotbar 1"], [&"hotbar_2", "Hotbar 2"],
		[&"hotbar_3", "Hotbar 3"], [&"hotbar_4", "Hotbar 4"], [&"hotbar_5", "Hotbar 5"], [&"hotbar_6", "Hotbar 6"],
		[&"hotbar_7", "Hotbar 7"], [&"hotbar_8", "Hotbar 8"], [&"respawn", "Respawn"], [&"chat", "Chat"]]],
	["Menus", [[&"inventory", "Inventory"], [&"character_screen", "Character"], [&"crafting", "Crafting"],
		[&"spellbook", "Spellbook"], [&"journal", "Journal"], [&"world_map", "World map"], [&"reputation", "Reputation"],
		[&"blueprints", "Blueprints"], [&"toggle_help", "Guide"], [&"quick_save", "Quick save"], [&"pause", "Pause"]]],
	["Building", [[&"build_mode", "Build mode"], [&"build_rotate", "Rotate piece"], [&"build_repair", "Repair"]]],
	["Camera", [[&"cam_rotate_left", "Rotate left"], [&"cam_rotate_right", "Rotate right"], [&"cam_pitch_up", "Tilt up"],
		[&"cam_pitch_down", "Tilt down"], [&"cam_pan_forward", "Pan forward"], [&"cam_pan_back", "Pan back"],
		[&"cam_pan_left", "Pan left"], [&"cam_pan_right", "Pan right"], [&"cam_recenter", "Recenter"]]],
]

## True while the player is using a gamepad (aiming then follows the stick).
var using_gamepad := false


func _enter_tree() -> void:
	for action: StringName in KEY_BINDINGS:
		_ensure(action)
	for action: StringName in MOUSE_BINDINGS:
		_ensure(action)
	reset_all()


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4)
	var kbm := event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0)
	if pad and not using_gamepad:
		using_gamepad = true
		device_changed.emit(true)
	elif kbm and using_gamepad:
		using_gamepad = false
		device_changed.emit(false)


# --- Defaults ------------------------------------------------------------------------------

## Default events of an action (keyboard/mouse + gamepad).
static func default_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for keycode: Key in KEY_BINDINGS.get(action, []):
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		out.append(ev)
	for button: MouseButton in MOUSE_BINDINGS.get(action, []):
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		out.append(mb)
	for p in PAD_BINDINGS.get(action, []):
		if p is Array:
			var jm := InputEventJoypadMotion.new()
			jm.axis = p[0]
			jm.axis_value = p[1]
			out.append(jm)
		else:
			var jb := InputEventJoypadButton.new()
			jb.button_index = p
			out.append(jb)
	return out


## Restores every action to its defaults.
func reset_all() -> void:
	for action: StringName in _all_actions():
		reset_action(action, false)
	bindings_changed.emit()


func reset_action(action: StringName, notify: bool = true) -> void:
	_ensure(action)
	InputMap.action_erase_events(action)
	for ev in default_events(action):
		InputMap.action_add_event(action, ev)
	if notify:
		bindings_changed.emit()


static func _all_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: StringName in KEY_BINDINGS:
		out.append(a)
	for a: StringName in MOUSE_BINDINGS:
		if not out.has(a):
			out.append(a)
	return out


# --- Rebinding -----------------------------------------------------------------------------

## Binds `ev` as the keyboard/mouse (or gamepad) binding of `action`, replacing
## the previous binding of that kind. Returns the actions that also used this
## input (the caller decides whether to warn; both keep working).
func rebind(action: StringName, ev: InputEvent) -> Array[StringName]:
	var gamepad := is_gamepad_event(ev)
	for old in InputMap.action_get_events(action):
		if is_gamepad_event(old) == gamepad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)
	bindings_changed.emit()
	return conflicts(action, ev)


## Other rebindable actions bound to the same input.
func conflicts(action: StringName, ev: InputEvent) -> Array[StringName]:
	var out: Array[StringName] = []
	for group in REBINDABLE:
		for entry in group[1]:
			var other: StringName = entry[0]
			if other == action:
				continue
			for e in InputMap.action_get_events(other):
				if same_input(e, ev):
					out.append(other)
	return out


static func is_gamepad_event(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _keycode(a) == _keycode(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	return false


static func _keycode(k: InputEventKey) -> Key:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


## True for inputs a player may bind (not modifiers-only mouse motion etc.).
static func is_bindable(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		return (ev as InputEventKey).pressed and _keycode(ev) != KEY_NONE
	if ev is InputEventMouseButton:
		return (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if ev is InputEventJoypadButton:
		return (ev as InputEventJoypadButton).pressed
	if ev is InputEventJoypadMotion:
		return absf((ev as InputEventJoypadMotion).axis_value) > 0.6
	return false


# --- Saving --------------------------------------------------------------------------------

## Serializable form of an event: "key:<physical keycode>", "mouse:<button>",
## "pad:<button>" or "axis:<axis>:<+|->".
static func event_to_string(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "key:%d" % _keycode(ev)
	if ev is InputEventMouseButton:
		return "mouse:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "pad:%d" % (ev as InputEventJoypadButton).button_index
	if ev is InputEventJoypadMotion:
		return "axis:%d:%s" % [(ev as InputEventJoypadMotion).axis, "+" if (ev as InputEventJoypadMotion).axis_value > 0 else "-"]
	return ""


static func event_from_string(s: String) -> InputEvent:
	var p := s.split(":")
	if p.size() < 2 or not p[1].is_valid_int():
		return null
	match p[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = p[1].to_int() as Key
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = p[1].to_int() as MouseButton
			return m
		"pad":
			var b := InputEventJoypadButton.new()
			b.button_index = p[1].to_int() as JoyButton
			return b
		"axis":
			var a := InputEventJoypadMotion.new()
			a.axis = p[1].to_int() as JoyAxis
			a.axis_value = -1.0 if p.size() > 2 and p[2] == "-" else 1.0
			return a
	return null


## Bindings that differ from the defaults: action -> Array[String].
func custom_bindings() -> Dictionary:
	var out := {}
	for action: StringName in _all_actions():
		var now := PackedStringArray()
		for ev in InputMap.action_get_events(action):
			now.append(event_to_string(ev))
		var def := PackedStringArray()
		for ev in default_events(action):
			def.append(event_to_string(ev))
		now.sort()
		def.sort()
		if now != def:
			out[String(action)] = Array(now)
	return out


func apply_custom_bindings(data: Dictionary) -> void:
	for action_name in data:
		var action := StringName(action_name)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for s in data[action_name]:
			var ev := event_from_string(String(s))
			if ev:
				InputMap.action_add_event(action, ev)
	bindings_changed.emit()


# --- Display names -------------------------------------------------------------------------

## Short name of an input for hints: "W", "Shift", "LMB", "A", "RT"...
static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := _keycode(ev)
		match k:
			KEY_SPACE: return "Space"
			KEY_ESCAPE: return "Esc"
			KEY_CTRL: return "Ctrl"
			KEY_SHIFT: return "Shift"
			KEY_ALT: return "Alt"
			KEY_ENTER: return "Enter"
			KEY_TAB: return "Tab"
			KEY_PAGEUP: return "PgUp"
			KEY_PAGEDOWN: return "PgDn"
		# Layout-aware name (AZERTY shows "Z" for the physical W key) where the
		# platform supports it; browsers and headless runs use the US name.
		var name := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k)) \
			if DisplayServer.get_name() != "headless" and not OS.has_feature("web") else ""
		if name == "":
			name = OS.get_keycode_string(k)
		return name
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
			JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
			JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←",
			JOY_BUTTON_DPAD_RIGHT: "D-pad →"}
		return names.get((ev as InputEventJoypadButton).button_index, "Pad %d" % (ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		match jm.axis:
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
			JOY_AXIS_LEFT_X: return "Left stick " + ("→" if jm.axis_value > 0 else "←")
			JOY_AXIS_LEFT_Y: return "Left stick " + ("↓" if jm.axis_value > 0 else "↑")
			JOY_AXIS_RIGHT_X: return "Right stick " + ("→" if jm.axis_value > 0 else "←")
			JOY_AXIS_RIGHT_Y: return "Right stick " + ("↓" if jm.axis_value > 0 else "↑")
		return "Axis %d" % jm.axis
	return "?"


## The key(s) for an action on the current device, e.g. "F" or "A". "—" if unbound.
func action_label(action: StringName, gamepad: Variant = null) -> String:
	var pad: bool = using_gamepad if gamepad == null else bool(gamepad)
	if not InputMap.has_action(action):
		return "—"
	var names := PackedStringArray()
	for ev in InputMap.action_get_events(action):
		if is_gamepad_event(ev) == pad:
			names.append(event_label(ev))
	if names.is_empty() and pad:
		return action_label(action, false)
	return " / ".join(names) if not names.is_empty() else "—"


## "WASD"-style label for the four movement actions.
func move_label() -> String:
	if using_gamepad:
		return "Left stick"
	return "%s%s%s%s" % [action_label(&"move_forward"), action_label(&"move_left"), action_label(&"move_back"), action_label(&"move_right")]
