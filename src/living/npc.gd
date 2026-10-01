class_name NPC
extends CharacterBody3D
## A townsperson with a daily routine (Milestone 5).
##
## Roles: merchant, royal_merchant, blacksmith, farmer, villager, guard, noble,
## trader. Every couple of seconds the NPC checks its schedule for the current
## hour and walks (street graph + doors) to that activity's place: work spot,
## farm rows, plaza, wandering, or home to sleep (hidden inside). NPCs are
## placed directly at their current activity when the settlement streams in.
## Guards attack monsters that come near. Talking opens the dialogue window.
## Raids (Milestone 7): while the settlement is under attack villagers hide in
## their homes; guards fight and can be knocked down (never killed) - they get
## back up when the raid is over.

const WALK_SPEED := 1.8
const GUARD_RANGE := 18.0
const GUARD_HEALTH := 140.0

var site: SettlementSite
var data: Dictionary = {}
var role: StringName = &"villager"
var display_name := ""
var model: HumanoidModel
var activity: StringName = &""
var asleep := false
var talking := false

var _path := PackedVector3Array()
var _path_i := 0
var _inside := -1
var _think := 0.0
var _pause := 0.0
var _work_i := 0
var _anim_t := 0.0
var _guard_target: Enemy
var _attack_cd := 0.0
var _far_acc := 0.0
## Guards only: hit points during raids, and knocked down at 0.
var hp := GUARD_HEALTH
var downed := false
var is_dead := false  # townsfolk never die (raiders knock guards down)


func setup(p_site: SettlementSite, d: Dictionary) -> void:
	site = p_site
	data = d
	role = d.role
	display_name = d.name
	name = "NPC_%s_%d" % [role, int(d.get("index", 0))]


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE | Layers.NPC
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = HumanoidModel.new()
	add_child(model)
	model.set_npc_look(role, int(data.seed), site.info.color)
	add_to_group(&"npcs")
	_update_activity(true)


func role_title() -> String:
	match role:
		&"merchant":
			return "Merchant"
		&"royal_merchant":
			return "Royal Merchant"
		&"blacksmith":
			return "Armorer" if site.info.is_kingdom() else "Blacksmith"
		&"farmer":
			return "Farmer"
		&"guard":
			return "Guard"
		&"noble":
			return "Lady" if int(data.seed) % 2 == 0 else "Lord"
		&"trader":
			return "Travelling Trader"
	return "Villager"


func full_name() -> String:
	if role == &"noble":
		return "%s %s of %s" % [role_title(), display_name, site.info.kingdom_name]
	return "%s the %s" % [display_name, role_title()]


func is_shopkeeper() -> bool:
	return role in [&"merchant", &"royal_merchant", &"blacksmith", &"trader", &"farmer"]


## Daily schedule: activity for an hour (each person is offset by up to an hour).
func schedule(hour: float) -> StringName:
	if site and site.under_attack and role != &"guard":
		return &"sleep"  # hide at home until the raid is over
	var h := fposmod(hour - (int(data.seed) % 60) / 60.0, 24.0)
	match role:
		&"merchant", &"royal_merchant":
			if h >= 8.0 and h < 19.0:
				return &"work"
			return &"plaza" if h >= 19.0 and h < 21.5 else &"sleep"
		&"blacksmith":
			if (h >= 7.0 and h < 12.0) or (h >= 13.0 and h < 18.0):
				return &"work"
			return &"plaza" if (h >= 12.0 and h < 13.0) or (h >= 18.0 and h < 21.0) else &"sleep"
		&"farmer":
			if (h >= 6.0 and h < 12.0) or (h >= 13.0 and h < 19.0):
				return &"work"
			return &"plaza" if (h >= 12.0 and h < 13.0) or (h >= 19.0 and h < 21.0) else &"sleep"
		&"noble":
			return &"work" if h >= 8.0 and h < 20.0 else &"sleep"
		&"guard", &"trader":
			return &"work"
	if (h >= 7.0 and h < 12.0) or (h >= 13.0 and h < 20.0):
		return &"wander"
	return &"plaza" if (h >= 12.0 and h < 13.0) or (h >= 20.0 and h < 22.0) else &"sleep"


## Whether the NPC will trade right now (shop hours).
func is_open() -> bool:
	return not asleep and activity == &"work"


func _hour() -> float:
	return World.instance.day_night.hour if World.instance and World.instance.day_night else 12.0


# --- Activities ---------------------------------------------------------------------------

func _update_activity(teleport: bool = false) -> void:
	var a := schedule(_hour())
	if a == activity and not teleport:
		return
	activity = a
	_work_i = 0
	var target := _target_for(a)
	if teleport:
		_place_at(target)
	else:
		_go(target)


func _home() -> Dictionary:
	var h: int = int(data.home)
	return site.layout.buildings[h] if h >= 0 and h < site.layout.buildings.size() else {}


func _target_for(a: StringName) -> Vector3:
	var pts: Dictionary = site.layout.points
	match a:
		&"sleep":
			var home := _home()
			if home.is_empty():
				return data.work
			var spots: Array = home.sleep
			return spots[int(data.seed) % spots.size()] if not spots.is_empty() else home.inside
		&"plaza":
			var p: Array = pts.plaza
			return p[(int(data.seed) + int(data.index)) % p.size()] + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		&"wander":
			var w: Array = pts.wander
			return w[randi() % w.size()] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		&"work":
			if role == &"farmer" and int(data.farm) >= 0:
				var farm: Dictionary = site.layout.farms[int(data.farm)]
				if not farm.work.is_empty():
					return farm.work[_work_i % farm.work.size()]
			if role == &"guard" and _is_patrol():
				return pts.patrol[(_patrol_start() + _work_i) % pts.patrol.size()]
			return data.work
	return data.work


func _is_patrol() -> bool:
	return not site.layout.points.patrol.is_empty() and not (data.work in site.layout.points.gate_guard)


func _patrol_start() -> int:
	return site.layout.points.patrol.find(data.work) if site.layout.points.patrol.has(data.work) else 0


func _farm_at(p: Vector3) -> int:
	for f in site.layout.farms:
		var r: Rect2 = f.rect
		if r.has_point(Vector2(p.x, p.z)):
			return f.id
	return -1


func _place_at(target: Vector3) -> void:
	position = target
	_path = PackedVector3Array()
	_inside = site.building_at(target)
	_arrived()


## Plans a route to `to`: out of the current building/farm, along the streets,
## in through the destination's door or gate.
func _go(to: Vector3) -> void:
	var pts := PackedVector3Array()
	var start := position
	var tb := site.building_at(to)
	var tf := _farm_at(to)
	if _inside >= 0 and _inside == tb:
		pts.append(to)
		_set_path(pts)
		return
	var cf := _farm_at(position)
	if _inside >= 0:
		var b: Dictionary = site.layout.buildings[_inside]
		pts.append(b.door_in)
		pts.append(b.door_out)
		start = b.door_out
	elif cf >= 0 and cf != tf:
		start = site.layout.farms[cf].gate
		pts.append(start)
	elif cf >= 0 and cf == tf:
		pts.append(to)
		_set_path(pts)
		return
	var end_out := to
	var tail := PackedVector3Array()
	if tb >= 0:
		var b2: Dictionary = site.layout.buildings[tb]
		end_out = b2.door_out
		tail.append(b2.door_in)
		tail.append(to)
	elif tf >= 0:
		end_out = site.layout.farms[tf].gate
		tail.append(to)
	pts.append_array(site.find_path(start, end_out))
	pts.append_array(tail)
	_set_path(pts)


func _set_path(pts: PackedVector3Array) -> void:
	if asleep:
		_wake()
	_path = pts
	_path_i = 0
	_inside = -1


func _wake() -> void:
	asleep = false
	visible = true
	collision_layer = Layers.INTERACTABLE | Layers.NPC


func _arrived() -> void:
	_path = PackedVector3Array()
	_inside = site.building_at(position)
	match activity:
		&"sleep":
			asleep = true
			visible = false
			collision_layer = 0
		&"work":
			if role == &"farmer":
				_pause = randf_range(4.0, 8.0)
			elif role == &"guard" and _is_patrol():
				_pause = randf_range(1.0, 3.0)
			else:
				model.rotation.y = float(data.work_rot)
		&"wander":
			_pause = randf_range(4.0, 12.0)
		&"plaza":
			var c := Vector3.ZERO - position
			model.rotation.y = atan2(c.x, c.z)


# --- Per frame ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if World.instance == null or downed:
		return
	var player := World.instance.player
	var far := player == null or global_position.distance_to(player.global_position) > 70.0
	if far:
		# Distant townsfolk update 4x per second.
		_far_acc += delta
		if _far_acc < 0.25:
			return
		delta = _far_acc
		_far_acc = 0.0
	_think -= delta
	if _think <= 0.0:
		_think = 1.5 + randf() * 0.5
		_update_activity()
		if role == &"guard":
			_scan_for_monsters()
	if talking and player:
		var to := player.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
		model.set_locomotion(0.0, delta)
		return
	if _guard_target != null:
		_fight(delta)
		return
	if not _path.is_empty():
		_walk(delta)
		return
	model.set_locomotion(0.0, delta)
	if asleep:
		return
	_idle(delta)


func _walk(delta: float) -> void:
	var target := _path[_path_i]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var step := WALK_SPEED * delta
	if dist <= step:
		position = Vector3(target.x, target.y, target.z)
		_path_i += 1
		if _path_i >= _path.size():
			_arrived()
		return
	var dir := to / dist
	position += dir * step
	position.y = move_toward(position.y, target.y, delta)
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-10.0 * delta))
	model.set_locomotion(0.45, delta)


func _idle(delta: float) -> void:
	_anim_t -= delta
	match activity:
		&"work":
			match role:
				&"blacksmith":
					if _anim_t <= 0.0:
						_anim_t = 1.3
						model.play_attack(&"light", 0.35, 0.1, 0.4)
				&"farmer":
					if _anim_t <= 0.0:
						_anim_t = 2.2
						model.play_attack(&"light", 0.4, 0.15, 0.6)
					_pause -= delta
					if _pause <= 0.0:
						_work_i += 1
						_go(_target_for(&"work"))
				&"guard":
					if _is_patrol():
						_pause -= delta
						if _pause <= 0.0:
							_work_i += 1
							_go(_target_for(&"work"))
		&"wander":
			_pause -= delta
			if _pause <= 0.0:
				_go(_target_for(&"wander"))


# --- Guards -------------------------------------------------------------------------------

func _scan_for_monsters() -> void:
	if is_instance_valid(_guard_target) and not _guard_target.is_dead \
			and _guard_target.global_position.distance_to(global_position) < GUARD_RANGE * 1.5:
		return
	_guard_target = null
	var best := GUARD_RANGE
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Enemy
		if en == null or en.is_dead or not en.is_visible_in_tree():
			continue
		var d := en.global_position.distance_to(global_position)
		if d < best and site.info.contains(en.global_position, 20.0):
			best = d
			_guard_target = en
	if _guard_target == null and _path.is_empty() and activity == &"work":
		_go(_target_for(&"work"))


func _fight(delta: float) -> void:
	if not is_instance_valid(_guard_target) or _guard_target.is_dead:
		_guard_target = null
		_go(_target_for(activity))
		return
	var to := _guard_target.global_position - global_position
	to.y = 0.0
	model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
	_attack_cd -= delta
	if to.length() > 1.7:
		global_position += to.normalized() * WALK_SPEED * 1.6 * delta
		model.set_locomotion(0.9, delta)
		return
	model.set_locomotion(0.0, delta)
	if _attack_cd <= 0.0:
		_attack_cd = 1.1
		model.play_attack(&"light", 0.15, 0.1, 0.3)
		var info := DamageInfo.create(14.0, self, &"physical")
		info.hit_position = _guard_target.global_position + Vector3(0, 1.0, 0)
		info.knockback = to.normalized() * 2.0
		info.poise_damage = 10.0
		info.tag = "Guard"
		var e := _guard_target
		# Kills by guards give the player no XP (see CharacterStats._on_enemy_killed).
		e.set_meta(&"killed_by_npc", true)
		e.receive_hit(info)
		if is_instance_valid(e) and not e.is_dead:
			e.remove_meta(&"killed_by_npc")


# --- Raids (Milestone 7) ------------------------------------------------------------------

## Raiders only go for people who are out in the open (and guards still standing).
func can_be_attacked() -> bool:
	return visible and not asleep and not downed and (role == &"guard" or (site != null and site.under_attack))


func receive_hit(info: DamageInfo) -> float:
	if not can_be_attacked():
		return 0.0
	if role != &"guard":
		# Civilians run for home instead of fighting.
		Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Help!")
		_update_activity(true)
		return 0.0
	var dealt := minf(info.amount, hp)
	hp -= dealt
	model.flash()
	Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), dealt, false, false, "Guard")
	if info.source is Enemy and (_guard_target == null or not is_instance_valid(_guard_target)):
		_guard_target = info.source
	if hp <= 0.0:
		downed = true
		_guard_target = null
		_path = PackedVector3Array()
		model.play_death()
		Events.toast.emit("Guard %s is down!" % display_name, Color(1, 0.6, 0.4))
	return dealt


## After a raid: guards get back up, everyone resumes their day.
func recover() -> void:
	hp = GUARD_HEALTH
	if downed:
		downed = false
		model.reset_pose()
	_update_activity(true)


# --- Interaction --------------------------------------------------------------------------

func is_interactable() -> bool:
	return not asleep and visible and not downed


func get_interact_text() -> String:
	return "Talk to %s" % full_name()


func interact(_player: Node) -> void:
	Events.npc_talk.emit(self)
