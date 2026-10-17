class_name Horse
extends CharacterBody3D
## Horses (Milestone 29).
##
## Wild horses graze in herds on meadows and in the forest edges (TravelManager
## spawns them). Feed one carrots, wheat, pumpkins or honeycomb until it trusts
## you (TRUST_NEEDED) and it becomes yours: it is moved to the world's placed
## objects, so it is saved where you leave it.
##
## A tame horse has a saddle slot. Put a saddle on (interact with a saddle in your
## bag; Shift + interact opens the horse panel) and ride it: interact (F) to get on,
## interact or the dodge key to get off.
## Hold sprint to gallop; galloping uses the horse's own stamina (the sprint bar
## on the HUD), which comes back when it trots or rests. Whistle (9) and your
## horse comes running from up to WHISTLE_RANGE metres.
##
## While ridden the horse has no physics of its own: the rider's body moves and
## the horse model follows it (Player._physics_mounted).

const SCENE_PATH := "res://scenes/world/horse.tscn"
## Food -> trust it gives.
const FOODS := {&"carrot": 2, &"wheat": 1, &"pumpkin": 2, &"honeycomb": 3}
const TRUST_NEEDED := 4
## Saddle item -> speed and stamina multipliers.
const SADDLES := {
	&"leather_saddle": {"speed": 1.0, "stamina": 1.0},
	&"riding_saddle": {"speed": 1.12, "stamina": 1.5},
}
const TROT_SPEED := 7.5
const GALLOP_SPEED := 13.5
const STAMINA_MAX := 100.0
const GALLOP_COST := 14.0  # per second
const STAMINA_REGEN := 10.0  # per second when not galloping
const WHISTLE_RANGE := 160.0
## Coat, mane (body colour, mane/tail colour).
const COATS := [
	[Color(0.45, 0.28, 0.16), Color(0.16, 0.1, 0.07)],  # bay
	[Color(0.62, 0.36, 0.18), Color(0.78, 0.6, 0.36)],  # chestnut, flaxen mane
	[Color(0.14, 0.13, 0.14), Color(0.06, 0.06, 0.07)],  # black
	[Color(0.86, 0.84, 0.8), Color(0.62, 0.6, 0.58)],   # white
	[Color(0.55, 0.55, 0.58), Color(0.2, 0.2, 0.22)],   # grey
	[Color(0.85, 0.66, 0.36), Color(0.95, 0.9, 0.78)],  # palomino
]
const NAMES := ["Clover", "Ember", "Willow", "Thunder", "Maple", "Dusk", "Biscuit", "Storm", "Juniper", "Pepper",
	"Barley", "Comet", "Hazel", "Sable", "Rowan", "Pip"]

var tame := false
var trust := 0
var saddle: StringName = &""
var horse_name := ""
var coat := 0
var stamina := STAMINA_MAX
## The player riding it (null when nobody rides).
var rider: Node3D = null
var home := Vector3.ZERO
## Wild horses: which herd slot they came from ("" for tame ones).
var herd_key := ""
var model: BeastModel

var _wander_t := 0.0
var _goal := Vector3.ZERO
var _follow: Node3D = null
var _gallop_t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * 2.0


func _ready() -> void:
	add_to_group(&"horses")
	collision_layer = Layers.INTERACTABLE
	collision_mask = Layers.TERRAIN | Layers.PROP | Layers.BUILDING
	floor_snap_length = 0.5
	if get_child_count() == 0 or get_node_or_null("Shape") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 1.6, 1.9)
		cs.shape = box
		cs.position.y = 0.85
		add_child(cs)
	model = BeastModel.new()
	add_child(model)
	_build_model()
	if home == Vector3.ZERO:
		home = global_position
	_goal = home


func _build_model() -> void:
	var c: Array = COATS[coat % COATS.size()]
	model.build(&"horse", c[0], c[1])
	model.set_saddle(saddle != &"")


## Wild horse with a coat picked from `seed`.
func setup_wild(seed: int, p_home: Vector3, p_herd_key: String) -> void:
	coat = absi(seed) % COATS.size()
	home = p_home
	herd_key = p_herd_key
	if model:
		_build_model()


func display_name() -> String:
	return horse_name if horse_name != "" else "Wild horse"


# --- Interaction --------------------------------------------------------------------

func is_interactable() -> bool:
	return rider == null


func get_interact_text() -> String:
	if not tame:
		return "Feed the wild horse (%d/%d trust)" % [trust, TRUST_NEEDED]
	if saddle == &"":
		return "%s (needs a saddle)" % horse_name
	return "Ride %s" % horse_name


func interact(player: Node) -> void:
	if rider != null or player == null:
		return
	if not tame:
		feed(player)
		return
	if saddle == &"":
		var s := _saddle_in(player)
		if s != &"":
			put_saddle(player, s)
		else:
			Events.toast.emit("%s needs a saddle (craft one at a tailoring table)" % horse_name, Color(1, 0.85, 0.55))
		return
	if World.instance and World.instance.hud and World.instance.hud.has_method("open_horse_panel") \
			and Input.is_action_pressed(&"sprint"):
		World.instance.hud.open_horse_panel(self)  # Shift + interact: the saddle slot
		return
	mount(player)


func _saddle_in(player: Node) -> StringName:
	if not "inventory" in player:
		return &""
	for s in SADDLES:
		if player.inventory.count_of(s) > 0:
			return s
	return &""


## Feeds the first food the player carries. Returns true when the horse became tame.
func feed(player: Node) -> bool:
	if tame or not "inventory" in player:
		return false
	var food: StringName = &""
	for f in FOODS:
		if player.inventory.count_of(f) > 0:
			food = f
			break
	if food == &"":
		Events.toast.emit("A wild horse. Feed it carrots, wheat, pumpkins or honeycomb to tame it", Color(1, 0.85, 0.55))
		return false
	player.inventory.remove_item(food, 1)
	trust += int(FOODS[food])
	Audio.play_at(&"eat", global_position + Vector3(0, 1.2, 0), -4.0)
	VFX.motes(get_parent(), global_position + Vector3(0, 1.8, 0.6), Color(1.0, 0.45, 0.6), 8, 0.4)
	if trust < TRUST_NEEDED:
		Events.toast.emit("The horse trusts you a little more (%d/%d)" % [trust, TRUST_NEEDED], Color(0.9, 1, 0.8))
		return false
	make_tame()
	Events.toast.emit("You tamed %s! Put a saddle on to ride (craft one at a tailoring table)" % horse_name, Color(0.7, 1, 0.7))
	Audio.play(&"level_up", -6.0)
	return true


## Becomes the player's horse: named, saved with the world's placed objects.
func make_tame() -> void:
	tame = true
	trust = TRUST_NEEDED
	if horse_name == "":
		horse_name = NAMES[absi(hash(herd_key + str(coat))) % NAMES.size()]
	var w := World.instance
	if w and herd_key != "" and w.travel:
		w.travel.mark_herd_taken(herd_key)
	herd_key = ""
	home = global_position
	if w and get_parent() != w.placed_root:
		var pos := global_position
		get_parent().remove_child(self)
		w.placed_root.add_child(self)
		global_position = pos
	# Saved by World.to_save (placed objects need a scene path).
	scene_file_path = SCENE_PATH


func put_saddle(player: Node, id: StringName) -> bool:
	if not tame or saddle != &"" or not SADDLES.has(id) or player.inventory.count_of(id) <= 0:
		return false
	player.inventory.remove_item(id, 1)
	saddle = id
	model.set_saddle(true)
	Audio.play_at(&"craft", global_position, -4.0)
	var d: ItemData = ItemDB.get_item(id)
	Events.toast.emit("%s wears the %s. Press %s to ride" % [horse_name, d.display_name if d else String(id), InputSetup.action_label(&"interact")],
		Color(0.8, 1, 0.7))
	return true


func take_saddle(player: Node) -> bool:
	if saddle == &"" or rider != null:
		return false
	player.give_or_drop(saddle, 1)
	saddle = &""
	model.set_saddle(false)
	return true


# --- Riding ---------------------------------------------------------------------------

func mount(player: Node) -> bool:
	if not tame or saddle == &"" or rider != null or not player.has_method("start_riding"):
		return false
	if not player.start_riding(self):
		return false
	rider = player
	_follow = null
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	Audio.play_at(&"step_grass_0", global_position, -2.0)
	return true


## The rider got off at `pos` (the player calls this).
func on_dismounted(pos: Vector3, yaw: float) -> void:
	rider = null
	collision_layer = Layers.INTERACTABLE
	collision_mask = Layers.TERRAIN | Layers.PROP | Layers.BUILDING
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	model.rotation = Vector3.ZERO
	home = pos
	_goal = pos


func speed_mult() -> float:
	return float(SADDLES.get(saddle, {"speed": 1.0}).speed)


func stamina_max() -> float:
	return STAMINA_MAX * float(SADDLES.get(saddle, {"stamina": 1.0}).stamina)


## Speed for this frame while ridden; uses stamina when galloping. `wants_gallop`
## is the rider's sprint button.
func ride_speed(wants_gallop: bool, moving: bool, delta: float) -> float:
	var gallop := wants_gallop and moving and stamina > 1.0
	if gallop:
		stamina = maxf(0.0, stamina - GALLOP_COST * delta)
		_gallop_t = 0.4
	else:
		_gallop_t = maxf(0.0, _gallop_t - delta)
		if _gallop_t <= 0.0:
			stamina = minf(stamina_max(), stamina + STAMINA_REGEN * delta * (1.6 if not moving else 1.0))
	return (GALLOP_SPEED if gallop else TROT_SPEED) * speed_mult()


func is_galloping() -> bool:
	return _gallop_t > 0.0


## Called every physics frame by the rider: the horse stands under them.
func follow_rider(pos: Vector3, yaw: float, speed: float, delta: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	model.set_locomotion(speed / 6.0, delta)


# --- Whistle ------------------------------------------------------------------------

## Comes running to `who`. Returns false when too far away.
func call_to(who: Node3D) -> bool:
	if not tame or rider != null:
		return false
	if global_position.distance_to(who.global_position) > WHISTLE_RANGE:
		return false
	_follow = who
	return true


# --- AI --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if rider != null:
		return
	var w := World.instance
	if w == null or not w.is_ready:
		return
	stamina = minf(stamina_max(), stamina + STAMINA_REGEN * delta)
	var speed := 0.0
	var to := Vector3.ZERO
	if is_instance_valid(_follow):
		to = _follow.global_position - global_position
		to.y = 0.0
		if to.length() < 3.0:
			_follow = null
			home = global_position
			_goal = home
		else:
			speed = GALLOP_SPEED * 0.9 if to.length() > 12.0 else TROT_SPEED
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(4.0, 9.0)
			var r := 9.0 if not tame else 3.0
			var a := randf() * TAU
			_goal = home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, r)
		to = _goal - global_position
		to.y = 0.0
		if to.length() > 0.6:
			speed = 1.6
	var dir := to.normalized() if to.length() > 0.01 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	if is_on_floor():
		velocity.y = maxf(velocity.y, -0.1)
	else:
		velocity.y -= _gravity * delta
	# Horses avoid deep water.
	var ahead := global_position + dir * 1.5
	if dir != Vector3.ZERO and w.is_deep_water(ahead):
		velocity.x = 0.0
		velocity.z = 0.0
		_wander_t = 0.0
	if is_on_floor() and dir != Vector3.ZERO:
		GroundMotion.try_step_up(self, Vector3(velocity.x, 0, velocity.z) * delta, 1.1)
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.y), 1.0 - exp(-6.0 * delta))
	model.set_locomotion(flat.length() / 6.0, delta)
	if global_position.y < -40.0:
		global_position = home + Vector3(0, 2, 0)
		velocity = Vector3.ZERO


# --- Save ----------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"tame": tame, "saddle": String(saddle), "name": horse_name, "coat": coat, "stamina": stamina}


func load_data(d: Dictionary) -> void:
	tame = bool(d.get("tame", true))
	trust = TRUST_NEEDED if tame else 0
	saddle = StringName(d.get("saddle", ""))
	horse_name = String(d.get("name", ""))
	coat = int(d.get("coat", 0))
	stamina = float(d.get("stamina", STAMINA_MAX))
	home = global_position
	_goal = home
	if model:
		_build_model()
