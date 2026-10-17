class_name Campfire
extends StaticBody3D
## Placeable campfire: a heat source, a light, and a cooking station.
##
## Heat: registered in group "heat_sources"; World sums heat_at() into the
## ambient temperature, so standing near a fire counters cold exposure.
## Cooking: interact to cook one raw ingredient (data: COOK_RECIPES); it is
## also the "campfire" crafting station for campfire recipes (G).
## Milestone 28: rain puts it out. In the open, RAIN_OUT_TIME seconds of rain
## (less in a storm) and the fire dies; under a roof it keeps burning.

const COOK_RECIPES := {&"raw_meat": &"cooked_meat"}

@export var heat: float = 22.0
@export var radius: float = 6.0
@export var burn_time: float = 480.0

var _time_left := 0.0
var _light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _t := 0.0
## Seconds of rain the fire has taken (0..RAIN_OUT_TIME).
var rain_soak := 0.0
var _rain_tick := 0.0
const RAIN_OUT_TIME := 20.0


func _ready() -> void:
	add_to_group(&"heat_sources")
	add_to_group(&"crafting_stations")
	add_to_group(&"rest_spots")  # change the ability bar here (Milestone 17b)
	set_meta(&"station_id", &"campfire")
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	_time_left = burn_time
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 0.8
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)

	var logs := BlockMesh.new()
	var wood := Color(0.45, 0.28, 0.16)
	logs.box(Vector3(0, 0.1, 0), Vector3(1.1, 0.18, 0.2), wood, Basis(Vector3.UP, 0.5))
	logs.box(Vector3(0, 0.12, 0), Vector3(1.1, 0.18, 0.2), wood * 0.9, Basis(Vector3.UP, -0.6))
	logs.box(Vector3(0, 0.14, 0), Vector3(1.0, 0.18, 0.2), wood * 1.1, Basis(Vector3.UP, 1.6))
	for k in 8:
		var a := TAU * k / 8.0
		logs.box(Vector3(cos(a) * 0.65, 0.08, sin(a) * 0.65), Vector3(0.22, 0.16, 0.22), Color(0.5, 0.5, 0.54))
	var mi := MeshInstance3D.new()
	mi.mesh = logs.commit()
	add_child(mi)

	var flame_cols := [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.15), Color(1.0, 0.3, 0.1)]
	for k in 3:
		var fb := BlockMesh.new()
		var sz := 0.42 - k * 0.1
		fb.box(Vector3.ZERO, Vector3(sz, sz * 1.4, sz), flame_cols[k])
		var fm := fb.commit()
		fm.surface_set_material(0, Materials.vertex_color_emissive())
		var f := MeshInstance3D.new()
		f.mesh = fm
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(0, 0.35 + k * 0.22, 0)
		add_child(f)
		_flames.append(f)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.light_energy = 2.2
	_light.omni_range = radius + 2.0
	_light.position.y = 1.0
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	_rain_tick -= delta
	if _rain_tick <= 0.0:
		_rain_tick = 1.0
		var w := World.instance
		var rain := w.weather.rain_at(global_position) if w and w.weather else 0.0
		if rain > 0.15:
			rain_soak += 1.0 * (0.5 + rain)
		else:
			rain_soak = maxf(0.0, rain_soak - 0.5)
		if rain_soak >= RAIN_OUT_TIME:
			put_out_by_rain()
			return
	var fade := clampf(_time_left / 30.0, 0.0, 1.0) * (1.0 - 0.6 * rain_soak / RAIN_OUT_TIME)  # dies down in the last 30 s
	for k in _flames.size():
		var f := _flames[k]
		var s := (0.85 + sin(_t * (7.0 + k * 3.0) + k) * 0.15) * fade
		f.scale = Vector3(s, s * (1.0 + sin(_t * 11.0 + k) * 0.1), s)
		f.rotation.y = _t * (1.5 + k)
	_light.light_energy = (2.0 + sin(_t * 13.0) * 0.25 + sin(_t * 7.3) * 0.2) * fade


## The rain put the fire out: a puff of steam and it is gone.
func put_out_by_rain() -> void:
	VFX.dust(get_parent(), global_position + Vector3(0, 0.6, 0), Color(0.7, 0.7, 0.72, 0.7), 10)
	Audio.play_at(&"splash", global_position, -4.0)
	var w := World.instance
	if w and w.player and w.player.global_position.distance_to(global_position) < 30.0:
		Events.toast.emit("The rain put out your campfire (build a roof over it)", Color(0.7, 0.85, 1.0))
	queue_free()


func save_data() -> Dictionary:
	return {"time_left": _time_left}


func load_data(data: Dictionary) -> void:
	_time_left = float(data.get("time_left", burn_time))


## Degrees C added to the ambient temperature at `pos`.
func heat_at(pos: Vector3) -> float:
	var d := pos.distance_to(global_position)
	if d >= radius:
		return 0.0
	var fade := clampf(_time_left / 30.0, 0.0, 1.0) * (1.0 - 0.6 * rain_soak / RAIN_OUT_TIME)
	return heat * (1.0 - d / radius) * fade


func get_interact_text() -> String:
	return "Cook at Campfire (%ds left)" % int(_time_left)


func interact(player: Node) -> void:
	if Net.client_blocked("Cooking at a campfire (use the crafting screen, G)"):
		return
	var inv: Inventory = player.get("inventory")
	if inv == null:
		return
	for raw: StringName in COOK_RECIPES:
		if inv.count_of(raw) > 0:
			inv.remove_item(raw, 1)
			var cooked: StringName = COOK_RECIPES[raw]
			var n := 1
			var ch = player.get("character")
			if ch and randf() < ch.cooking_bonus_chance():
				n = 2
				Events.toast.emit("Skilled cooking: +1 portion", Color(0.8, 1.0, 0.6))
			player.give_item(cooked, n)
			Events.item_crafted.emit(cooked, 1)
			return
	Events.toast.emit("Nothing to cook (needs Raw Meat)", Color(1, 0.8, 0.5))
