class_name Waystone
extends StaticBody3D
## A waystone (Milestone 29): a rune pillar in every village, capital and dungeon
## entrance. Touch it (E) once to unlock it; after that, use any unlocked waystone
## to travel to another one for a few coins (TravelManager.travel_cost).
## TravelManager spawns these near the player; they are not saved themselves
## (the list of unlocked waystones is).

var key := ""
var title := ""
var _rune: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0


func setup(p_key: String, p_title: String) -> void:
	key = p_key
	title = p_title


func _ready() -> void:
	add_to_group(&"waystones")
	collision_layer = Layers.INTERACTABLE | Layers.PROP
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 2.6, 0.9)
	cs.shape = box
	cs.position.y = 1.3
	add_child(cs)
	var stone := Color(0.56, 0.58, 0.62)
	var b := BlockMesh.new()
	b.box(Vector3(0, 0.15, 0), Vector3(1.5, 0.3, 1.5), stone.darkened(0.2))  # plinth
	b.box(Vector3(0, 0.38, 0), Vector3(1.15, 0.18, 1.15), stone.darkened(0.1))
	b.box(Vector3(0, 1.35, 0), Vector3(0.7, 1.8, 0.7), stone)  # pillar
	b.box(Vector3(0, 2.35, 0), Vector3(0.85, 0.22, 0.85), stone.lightened(0.1))  # cap
	b.box(Vector3(0, 2.58, 0), Vector3(0.45, 0.25, 0.45), stone.lightened(0.15))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.38, 0.9, 0.0), Vector3(0.06, 0.5, 0.5), Color(0.38, 0.52, 0.3))  # moss
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = Materials.vertex_color()
	add_child(mi)
	var rb := BlockMesh.new()
	for z in [-1.0, 1.0]:
		rb.box(Vector3(0, 1.55, z * 0.36), Vector3(0.12, 0.7, 0.02), Color(0.4, 0.85, 1.0))
		rb.box(Vector3(0, 1.75, z * 0.36), Vector3(0.36, 0.08, 0.02), Color(0.4, 0.85, 1.0))
		rb.box(Vector3(0, 1.3, z * 0.36), Vector3(0.26, 0.08, 0.02), Color(0.4, 0.85, 1.0))
	var rm := rb.commit()
	rm.surface_set_material(0, Materials.vertex_color_emissive())
	_rune = MeshInstance3D.new()
	_rune.mesh = rm
	_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rune)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.45, 0.8, 1.0)
	_light.omni_range = 6.0
	_light.position.y = 2.0
	add_child(_light)
	refresh()


func is_unlocked() -> bool:
	var w := World.instance
	return w != null and w.travel != null and w.travel.is_unlocked(key)


## Glows when unlocked, dark when not.
func refresh() -> void:
	var on := is_unlocked()
	_rune.visible = on
	_light.light_energy = 1.4 if on else 0.0


func _process(delta: float) -> void:
	_t += delta
	if _rune.visible:
		_light.light_energy = 1.2 + sin(_t * 2.0) * 0.3


func get_interact_text() -> String:
	return "Travel from the %s waystone" % title if is_unlocked() else "Touch the waystone of %s" % title


func interact(player: Node) -> void:
	var w := World.instance
	if w == null or w.travel == null:
		return
	if not is_unlocked():
		w.travel.unlock(key, title, global_position)
		refresh()
		VFX.motes(get_parent(), global_position + Vector3(0, 1.6, 0), Color(0.45, 0.85, 1.0), 24, 0.8)
		Audio.play(&"discover", -2.0)
		Events.toast.emit("Waystone unlocked: %s. Use any waystone to travel here" % title, Color(0.6, 0.9, 1.0))
		return
	if w.hud and w.hud.has_method("open_travel_panel"):
		w.hud.open_travel_panel(key)
	elif player:
		pass
