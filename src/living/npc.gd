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
## Milestone 37: townsfolk don't walk through people. They steer around anyone
## in their way (keeping to the right), never end a step inside someone, wait
## and say "Excuse me" when the player blocks the way, step aside when the
## player keeps walking into them and go back to their spot afterwards.

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

## Milestone 37: keeping out of people's way.
const BODY_RADIUS := 0.35
## Room taken by a player on horseback.
const MOUNTED_RADIUS := 0.9
## How far ahead a walking townsperson looks for people in the way (metres).
const LOOK_AHEAD := 1.8
## Seconds without getting closer before a walker settles for "close enough".
const STALL_TIME := 2.5
## Creative toggle (and tests): off = townsfolk walk through people as before.
static var avoid_people := true
var _best_dist := INF
var _stall := 0.0
var _ghost := 0.0  # seconds left ignoring other townsfolk (two stuck in a doorway)
var _anchor := Vector3.INF  # where an idle townsperson stood before stepping aside
var _calm := 0.0
var _pressed := 0.0
var _crowd_t := 0.0
## Times this townsperson stepped aside or said "Excuse me" (tests, debug).
var made_way := 0
var excused := 0


func setup(p_site: SettlementSite, d: Dictionary) -> void:
	site = p_site
	data = d
	role = d.role
	display_name = d.name
	name = "NPC_%s_%d" % [role, int(d.get("index", 0))]


func _ready() -> void:
	safe_margin = 0.04  # Milestone 36: see Enemy._ready (cheap terrain contacts)
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
		# Milestone 40: village jobs
		&"baker":
			return "Baker"
		&"lumberjack":
			return "Lumberjack"
		&"alchemist":
			return "Alchemist"
		&"fisher":
			return "Fisher"
		&"miner":
			return "Miner"
		&"miller":
			return "Miller"
		&"innkeeper":
			return "Innkeeper"
		&"elder":
			return "Elder"
	return "Villager"


func full_name() -> String:
	if role == &"noble":
		return "%s %s of %s" % [role_title(), display_name, site.info.kingdom_name]
	return "%s the %s" % [display_name, role_title()]


func is_shopkeeper() -> bool:
	return role in [&"merchant", &"royal_merchant", &"blacksmith", &"trader", &"farmer"] or Economy.JOB_SHOPS.has(role)


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
		# Milestone 40: village jobs
		&"baker", &"miller":
			if h >= 5.5 and h < 15.0:
				return &"work"
			return &"plaza" if h >= 15.0 and h < 20.0 else &"sleep"
		&"lumberjack", &"miner", &"fisher":
			if (h >= 7.0 and h < 12.0) or (h >= 13.0 and h < 18.0):
				return &"work"
			return &"plaza" if (h >= 12.0 and h < 13.0) or (h >= 18.0 and h < 21.0) else &"sleep"
		&"alchemist":
			if h >= 9.0 and h < 19.0:
				return &"work"
			return &"plaza" if h >= 19.0 and h < 21.0 else &"sleep"
		&"innkeeper":
			return &"work" if h >= 9.0 or h < 1.0 else &"sleep"
		&"elder":
			if h >= 9.0 and h < 17.0:
				return &"work"
			return &"plaza" if h >= 17.0 and h < 20.0 else &"sleep"
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
	_anchor = Vector3.INF
	_path = PackedVector3Array()
	_inside = site.building_at(target)
	_arrived()


## Plans a route to `to`: out of the current building/farm, along the streets,
## in through the destination's door or gate.
func _go(to: Vector3) -> void:
	_anchor = Vector3.INF  # a new errand: no going back to where it stepped aside from
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
	_reset_progress()


func _reset_progress() -> void:
	_best_dist = INF
	_stall = 0.0


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
	var near := not far and avoid_people
	if _guard_target != null:
		_fight(delta, near)
		return
	if not _path.is_empty():
		_walk(delta, near)
		return
	model.set_locomotion(0.0, delta)
	if asleep:
		return
	if near:
		_make_way(delta)
	_idle(delta)


func _walk(delta: float, near: bool = false) -> void:
	var target := _path[_path_i]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var step := WALK_SPEED * delta
	if dist <= step:
		position = Vector3(target.x, target.y, target.z)
		_path_i += 1
		_reset_progress()
		if _path_i >= _path.size():
			_arrived()
		return
	var dir := to / dist
	var v := dir
	if near:
		_ghost = maxf(_ghost - delta, 0.0)
		v = _avoid(dir)
	position += v * step
	position.y = move_toward(position.y, target.y, delta)
	if near:
		_keep_apart()
		if _stalled(dist, delta):
			return
	var face := v if v.length_squared() > 0.04 else dir
	model.rotation.y = lerp_angle(model.rotation.y, atan2(face.x, face.z), 1.0 - exp(-10.0 * delta))
	model.set_locomotion(0.45 * clampf(v.length(), 0.3, 1.0), delta)


# --- Keeping out of people's way (Milestone 37) -------------------------------------------

## The walking direction steered around the nearest person ahead, shorter when
## someone is right in front. Two townsfolk meeting head-on both keep to the right.
## (Only the nearest one steers: adding up every push can cancel out in a crowd.)
func _avoid(dir: Vector3) -> Vector3:
	var right := dir.cross(Vector3.UP)
	var steer := Vector3.ZERO
	var nearest := INF
	var speed := 1.0
	for e in site.people_near(position, self):
		if e[2] and _ghost > 0.0:
			continue
		var rel: Vector3 = site.person_pos(e) - position
		rel.y = 0.0
		var ahead := rel.dot(dir)
		var reach: float = LOOK_AHEAD + e[1]
		if ahead <= 0.0 or ahead > reach:
			continue
		var side := rel.dot(right)
		var clear: float = BODY_RADIUS + e[1] + 0.25
		if absf(side) >= clear:
			continue
		if ahead < clear + 0.15:
			speed = minf(speed, clampf((ahead - BODY_RADIUS - e[1]) / 0.4, 0.15, 1.0))
		if ahead < nearest:
			nearest = ahead
			var away := -signf(side) if absf(side) > 0.12 else 1.0
			steer = right * away * (0.6 + 1.6 * (1.0 - ahead / reach))
	if steer == Vector3.ZERO:
		return dir
	return (dir + steer).normalized() * speed


## Never ends a step inside someone: pushed out along the line between them.
## A townsperson always gives way to players; walkers give way to people
## standing still; two walkers (or two standing) share the push.
func _keep_apart() -> bool:
	var pushed := false
	var me_walking := not _path.is_empty()
	for e in site.people_near(position, self):
		if e[2] and _ghost > 0.0:
			continue
		var rel: Vector3 = position - site.person_pos(e)
		rel.y = 0.0
		var need: float = BODY_RADIUS + e[1] + 0.02
		var d := rel.length()
		if d >= need:
			continue
		var share := 1.0
		if e[2]:
			var other_walking := not (e[0] as NPC)._path.is_empty()
			if me_walking == other_walking:
				share = 0.5
			elif not me_walking:
				continue  # the walker steps around me
		if d < 0.001:
			rel = Vector3.RIGHT.rotated(Vector3.UP, float(get_instance_id() % 628) * 0.01)
		else:
			rel /= d
		position += rel * (need - d) * share
		pushed = true
	return pushed


## Walking but not getting closer: settles for "close enough" at the end of
## the way; otherwise says "Excuse me" and walks a detour round a player in
## the way, and lets other stuck townsfolk through (they ignore each other for
## a moment). True if it arrived.
func _stalled(dist: float, delta: float) -> bool:
	if dist < _best_dist - 0.05:
		_best_dist = dist
		_stall = 0.0
		return false
	_stall += delta
	if _stall < STALL_TIME:
		return false
	_reset_progress()
	if _path_i == _path.size() - 1 and dist < 1.6:
		_path_i = _path.size()
		_arrived()
		return true
	var by_player := false
	for e in site.people_near(position, self):
		if not e[2] and (site.person_pos(e) - position).length() < BODY_RADIUS + e[1] + 0.6:
			by_player = true
	if by_player:
		excused += 1
		Events.damage_dealt.emit(global_position + Vector3(0, 2.0, 0), 0.0, false, false, "Excuse me")
		_detour()
	_ghost = 2.0
	return false


## A corner point beside whoever is in the way (on the quieter side, the right
## if both are the same), then on along the old way.
func _detour() -> void:
	var dir := _path[_path_i] - position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var right := dir.cross(Vector3.UP)
	var best := right
	var best_crowd := INF
	for side: Vector3 in [right, -right]:
		var corner := position + side * 1.3 + dir * 0.5
		var crowd := 0.0
		for e in site.people_near(corner, self):
			crowd += maxf(0.0, 1.5 - (site.person_pos(e) - corner).length())
		if crowd < best_crowd - 0.01:
			best_crowd = crowd
			best = side
	var to := position + best * 1.3 + dir * 0.5
	to.y = position.y
	_path.insert(_path_i, to)
	_reset_progress()


## Standing townsfolk: no overlapping (people placed in the same spot spread
## out), and they step aside when the player keeps walking into them, then go
## back to their spot once the player has moved on.
func _make_way(delta: float) -> void:
	_crowd_t -= delta
	if _crowd_t > 0.0:
		return
	_crowd_t = 0.2
	_keep_apart()
	var player := World.instance.player
	var rel := position - site.to_local(player.global_position)
	rel.y = 0.0
	var d := rel.length()
	var vel := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if d < BODY_RADIUS * 2.0 + 0.3 and vel.length() > 1.0 and vel.normalized().dot(rel / maxf(d, 0.01)) > 0.4:
		_calm = 0.0
		_pressed += 0.2
		if _pressed >= 0.6:
			_pressed = 0.0
			_step_aside(rel, vel)
		return
	_pressed = 0.0
	if _anchor != Vector3.INF and d > 2.5:
		_calm += 0.2
		if _calm >= 2.0:
			_calm = 0.0
			var back := _anchor
			_anchor = Vector3.INF
			_path = PackedVector3Array([back])
			_path_i = 0
			_reset_progress()


func _step_aside(rel: Vector3, vel: Vector3) -> void:
	if _anchor == Vector3.INF:
		_anchor = position
	var fwd := vel.normalized()
	var side := fwd.cross(Vector3.UP)
	if side.dot(rel) < 0.0:
		side = -side
	var to := position + side * 1.0 + fwd * 0.2
	to.y = position.y
	_path = PackedVector3Array([to])
	_path_i = 0
	_reset_progress()
	made_way += 1


## Creative toggle: townsfolk keep out of people's way, and the player bumps
## into them instead of passing through.
static func set_avoidance(on: bool) -> void:
	avoid_people = on
	var w := World.instance
	if w and w.player:
		if on:
			w.player.collision_mask |= Layers.NPC
		else:
			w.player.collision_mask &= ~Layers.NPC


func _idle(delta: float) -> void:
	_anim_t -= delta
	match activity:
		&"work":
			match role:
				&"blacksmith":
					if _anim_t <= 0.0:
						_anim_t = 1.3
						model.play_attack(&"light", 0.35, 0.1, 0.4)
				&"lumberjack", &"miner":
					if _anim_t <= 0.0:
						_anim_t = 1.6
						model.play_attack(&"overhead", 0.4, 0.12, 0.5)
				&"baker", &"alchemist":
					if _anim_t <= 0.0:
						_anim_t = 2.6
						model.play_attack(&"light", 0.45, 0.15, 0.6)
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


func _fight(delta: float, near: bool = false) -> void:
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
		if near:
			_keep_apart()
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
