extends Node
## Contextual tutorial (Milestone 13).
##
## A list of short hints, each shown when its situation comes up (an enemy is
## near, you're hungry, it's getting dark, you found a village...) and cleared
## when you do the thing (or after a while for "good to know" tips). Only one
## hint shows at a time; key names come from the current bindings and device.
## Progress is per player profile (user://profile.cfg), not per world, so a
## second world doesn't repeat what you already know. Settings → Gameplay turns
## hints off or replays them.

signal hint_changed(step: Dictionary)  ## empty = no hint
signal step_completed(id: StringName)

const PROFILE_PATH := "user://profile.cfg"
## Seconds between a finished hint and the next one.
const GAP := 2.5

## id, title, text ({action} = key name), show = when, done = completed when,
## timeout = auto-complete after showing this long (0 = never).
const STEPS := [
	{"id": &"move", "title": "Getting around", "show": &"always", "done": &"moved", "timeout": 0.0,
		"text": "Walk with {move}. Hold {sprint} to sprint and press {dodge} to dodge-roll."},
	{"id": &"camera", "title": "Camera", "show": &"after_move", "done": &"camera_turned", "timeout": 25.0,
		"text": "Turn the camera with {cam_rotate_left} / {cam_rotate_right} (or drag with the middle mouse button). Scroll to zoom."},
	{"id": &"gather", "title": "Gathering", "show": &"after_move", "done": &"picked_up", "timeout": 0.0,
		"text": "Walk up to sticks, stones, fibre plants and berry bushes and press {interact} to gather them."},
	{"id": &"inventory", "title": "Inventory", "show": &"has_items", "done": &"inventory_opened", "timeout": 40.0,
		"text": "Press {inventory} to see your bag. Right-click food to eat it and gear to equip it."},
	{"id": &"craft", "title": "Crafting", "show": &"has_items", "done": &"crafted", "timeout": 0.0,
		"text": "Press {crafting} to craft. Start with a Stone Hatchet: stones, sticks and rope (rope is twisted plant fibre). Crafting never fails."},
	{"id": &"chop", "title": "Chopping and mining", "show": &"has_tool", "done": &"harvested", "timeout": 0.0,
		"text": "Hit trees and rocks with {attack_light}. Tools in your bag are used automatically: hatchets for wood, pickaxes for stone and ore."},
	{"id": &"combat", "title": "Combat", "show": &"enemy_near", "done": &"hit_enemy", "timeout": 30.0,
		"text": "Enemy! {attack_light} light combo, {attack_heavy} heavy attack, {dodge} roll through attacks. Hold {block} to block - tap it right before a hit to parry. {target_lock} locks on."},
	{"id": &"hunger", "title": "Hunger", "show": &"hungry", "done": &"ate", "timeout": 45.0,
		"text": "You're getting hungry. Eat from the hotbar ({hotbar_1}-{hotbar_8}) or the bag. Raw meat is better cooked at a campfire."},
	{"id": &"cold", "title": "Temperature", "show": &"cold", "done": &"warm", "timeout": 30.0,
		"text": "You're cold: you get slower and hungrier (it never kills you). Stand by a campfire, wear warm clothes, eat hot food or use your shield ({ability_shield})."},
	{"id": &"level", "title": "Level up", "show": &"points", "done": &"points_spent", "timeout": 60.0,
		"text": "You levelled up! Press {character_screen} to spend your skill points. Your class makes some skills cheaper to grow."},
	{"id": &"build", "title": "Building", "show": &"can_build", "done": &"built", "timeout": 60.0,
		"text": "Press {build_mode} to build: a Claim Totem protects your base, then floors, walls and a door. {build_rotate} rotates, right-click removes."},
	{"id": &"night", "title": "Night", "show": &"night", "done": &"timeout", "timeout": 20.0,
		"text": "Night falls and monsters grow bolder. Stay near a campfire or torch, or sleep in a bed to skip the night."},
	{"id": &"village", "title": "Villages", "show": &"in_village", "done": &"talked", "timeout": 40.0,
		"text": "A village! Press {interact} to talk to people, trade with the merchant and take requests from the notice board."},
	{"id": &"poi", "title": "Points of interest", "show": &"found_poi", "done": &"timeout", "timeout": 25.0,
		"text": "You found a point of interest. Its rank (E → S) shows how dangerous it is; ranks rise the further you go from spawn. Open the map with {world_map}."},
	{"id": &"death", "title": "Collapsed", "show": &"dead", "done": &"respawned", "timeout": 0.0,
		"text": "You collapsed. Press {respawn} to get back up at your bed or where you started."},
	{"id": &"guide", "title": "Guide", "show": &"after_three", "done": &"guide_opened", "timeout": 20.0,
		"text": "Press {toggle_help} any time for the guide: every control, and how survival, combat, crafting and the world work."},
]

var done: Dictionary = {}  # id -> true
var current: Dictionary = {}
var profile_path := PROFILE_PATH
## Things that happened since the current hint appeared (set by events/UI).
var _flags: Dictionary = {}
var _shown_for := 0.0
var _gap := 0.0
var _check_left := 0.0
var _start_pos := Vector3.INF
var _start_yaw := 0.0
var _start_hunger := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_progress()
	Events.item_picked_up.connect(func(_i: StringName, _n: int) -> void: _flags[&"picked_up"] = true)
	Events.item_crafted.connect(func(_i: StringName, _n: int) -> void: _flags[&"crafted"] = true)
	Events.resource_harvested.connect(func(_p: StringName, _x: int) -> void: _flags[&"harvested"] = true)
	Events.damage_dealt.connect(func(_p: Vector3, amount: float, _c: bool, to_player: bool, _t: String) -> void:
		if not to_player and amount > 0.0:
			_flags[&"hit_enemy"] = true)
	Events.building_changed.connect(func() -> void: _flags[&"built"] = true)
	Events.npc_talk.connect(func(_n: Node) -> void: _flags[&"talked"] = true)
	Events.open_requests.connect(func(_s: Node) -> void: _flags[&"talked"] = true)
	Events.settlement_entered.connect(func(_id: String) -> void: _flags[&"in_village"] = true)
	Events.poi_discovered.connect(func(_id: String) -> void: _flags[&"found_poi"] = true)
	Events.player_respawned.connect(func() -> void: _flags[&"respawned"] = true)


## UI and systems report actions the tutorial waits for (inventory_opened...).
func notify(flag: StringName) -> void:
	_flags[flag] = true


func is_done(id: StringName) -> bool:
	return done.has(id)


func _process(delta: float) -> void:
	var w := World.instance
	if w == null or not w.is_ready or not is_instance_valid(w.player):
		if not current.is_empty():
			_set_current({})
		_start_pos = Vector3.INF
		return
	if not bool(Settings.get_value("tutorial_hints")):
		if not current.is_empty():
			_set_current({})
		return
	if _start_pos == Vector3.INF:
		_start_pos = w.player.global_position
		_start_yaw = w.camera_rig._target_yaw if w.camera_rig else 0.0
	_check_left -= delta
	if not current.is_empty():
		_shown_for += delta
		if _check_left <= 0.0:
			_check_left = 0.2
			var t: float = current.timeout
			if _condition(current.done, w) or (t > 0.0 and _shown_for >= t):
				complete(current.id)
		return
	_gap -= delta
	if _gap > 0.0 or _check_left > 0.0:
		return
	_check_left = 0.4
	for step in STEPS:
		if done.has(step.id):
			continue
		if _condition(step.show, w):
			# Already did it before the hint came up? Count it and move on.
			if step.done != &"timeout" and _condition(step.done, w) and step.id not in [&"move", &"camera", &"hunger"]:
				complete(step.id)
				continue
			_begin(step, w)
			return


func _begin(step: Dictionary, w: World) -> void:
	_shown_for = 0.0
	for k in [step.done]:
		_flags.erase(k)
	if step.id == &"move":
		_start_pos = w.player.global_position
	if step.id == &"camera" and w.camera_rig:
		_start_yaw = w.camera_rig._target_yaw
	if step.id == &"hunger":
		_start_hunger = w.player.hunger.current
	_set_current(step)


func complete(id: StringName) -> void:
	if done.has(id):
		return
	done[id] = true
	save_progress()
	step_completed.emit(id)
	if not current.is_empty() and current.id == id:
		_set_current({})
		_gap = GAP


func _set_current(step: Dictionary) -> void:
	current = step
	hint_changed.emit(step)


## Hint text with key names filled in for the current bindings/device.
func format_text(step: Dictionary) -> String:
	var text: String = step.get("text", "")
	var out := ""
	var i := 0
	while i < text.length():
		var open := text.find("{", i)
		if open < 0:
			out += text.substr(i)
			break
		var close := text.find("}", open)
		if close < 0:
			out += text.substr(i)
			break
		out += text.substr(i, open - i)
		var name := text.substr(open + 1, close - open - 1)
		out += "[%s]" % (InputSetup.move_label() if name == "move" else InputSetup.action_label(StringName(name)))
		i = close + 1
	return out


func _condition(c: StringName, w: World) -> bool:
	var p := w.player
	match c:
		&"always":
			return true
		&"timeout":
			return false
		&"after_move":
			return done.has(&"move")
		&"after_three":
			return done.size() >= 3
		&"moved":
			return _start_pos != Vector3.INF and Vector2(p.global_position.x - _start_pos.x, p.global_position.z - _start_pos.z).length() > 8.0
		&"camera_turned":
			return w.camera_rig != null and absf(angle_difference(deg_to_rad(w.camera_rig._target_yaw), deg_to_rad(_start_yaw))) > deg_to_rad(25.0)
		&"has_items":
			return done.has(&"gather") or _flags.has(&"picked_up")
		&"has_tool":
			return p.best_tool_tier(&"axe") > 0 or p.best_tool_tier(&"pickaxe") > 0
		&"enemy_near":
			for e in get_tree().get_nodes_in_group(&"enemies"):
				var en := e as Enemy
				if en and not en.is_dead and en.is_visible_in_tree() and en.global_position.distance_to(p.global_position) < 18.0:
					return true
			return false
		&"hungry":
			return p.hunger.get_ratio() < 0.45
		&"ate":
			return p.hunger.current > _start_hunger + 1.0
		&"cold":
			return p.temperature.exposure in [TemperatureComponent.Exposure.COLD, TemperatureComponent.Exposure.FREEZING]
		&"warm":
			return p.temperature.exposure not in [TemperatureComponent.Exposure.COLD, TemperatureComponent.Exposure.FREEZING]
		&"points":
			return p.character.unspent_points > 0 and p.character.level >= 2
		&"points_spent":
			return p.character.unspent_points == 0 or _flags.has(&"character_opened")
		&"can_build":
			return p.inventory.count_of(&"wood") >= 10 and done.has(&"craft")
		&"night":
			return w.day_night != null and w.day_night.is_night() and w.dungeon == null and w.layer == TerrainGenerator.Layer.SURFACE
		&"dead":
			return p.is_dead
	return _flags.has(c)


# --- Progress ------------------------------------------------------------------------------

func load_progress() -> void:
	done.clear()
	var cf := ConfigFile.new()
	if cf.load(profile_path) != OK:
		return
	for id in cf.get_value("tutorial", "done", []):
		done[StringName(id)] = true


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(profile_path)  # keep other profile sections
	var ids := []
	for id in done:
		ids.append(String(id))
	cf.set_value("tutorial", "done", ids)
	cf.save(profile_path)


func reset_progress() -> void:
	done.clear()
	_flags.clear()
	_start_pos = Vector3.INF
	save_progress()
	_set_current({})
