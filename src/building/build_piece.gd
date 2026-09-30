class_name BuildPiece
extends StaticBody3D
## A placed building piece. Behaviour depends on BuildPieceData.behavior:
## doors open/close, chests store items, beds set respawn and let you sleep,
## spikes hurt enemies, stations enable crafting, torches light and warm,
## claims protect land.

var data: BuildPieceData
## Grid address: cell, slot ("floor", "object", "roof", "edge_n", "edge_w"), rotation (0-3), layer.
var cell := Vector2i.ZERO
var slot: String = "object"
var rot: int = 0
var layer: int = 0
## CHEST storage.
var storage: Inventory
var is_open := false
## FARM: planted crop (&"" = empty) and when it was planted (world time).
var crop: StringName = &""
var planted_at := 0.0
var _crop_mesh: MeshInstance3D
var _crop_stage := -1
var _crop_tick := 0.0

var _mesh_instance := MeshInstance3D.new()
var _leaf: Node3D
var _spike_area: Area3D
var _spike_tick := 0.0
var _light: OmniLight3D


func setup(p_data: BuildPieceData) -> void:
	data = p_data
	name = "%s_%d_%d_%s" % [data.id, cell.x, cell.y, slot]
	collision_layer = Layers.BUILDING
	if data.behavior in [BuildPieceData.Behavior.DOOR, BuildPieceData.Behavior.CHEST, BuildPieceData.Behavior.BED,
			BuildPieceData.Behavior.CLAIM, BuildPieceData.Behavior.FARM]:
		collision_layer |= Layers.INTERACTABLE
	if not data.blocks_movement:
		collision_layer = Layers.INTERACTABLE if collision_layer & Layers.INTERACTABLE else 0
	collision_mask = 0
	_mesh_instance.mesh = BuildMeshes.get_mesh(data.mesh)
	if data.fade_near_camera:
		_mesh_instance.material_override = Materials.vertex_color_occluder()
	add_child(_mesh_instance)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.collision_size
	cs.shape = box
	cs.position = data.collision_center
	add_child(cs)
	match data.behavior:
		BuildPieceData.Behavior.DOOR:
			_leaf = Node3D.new()
			_leaf.position = Vector3(-0.4, 0, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = BuildMeshes.get_mesh(&"door_leaf")
			mi.material_override = Materials.vertex_color_occluder()
			_leaf.add_child(mi)
			add_child(_leaf)
		BuildPieceData.Behavior.CHEST:
			storage = Inventory.new(data.storage_slots)
		BuildPieceData.Behavior.SPIKES:
			_spike_area = Area3D.new()
			_spike_area.collision_layer = 0
			_spike_area.collision_mask = Layers.ENEMY
			var acs := CollisionShape3D.new()
			var abox := BoxShape3D.new()
			abox.size = data.collision_size + Vector3(0.6, 0.4, 0.6)
			acs.shape = abox
			acs.position = data.collision_center
			_spike_area.add_child(acs)
			add_child(_spike_area)
		BuildPieceData.Behavior.STATION:
			add_to_group(&"crafting_stations")
			set_meta(&"station_id", data.station_id)
			if data.station_id == &"forge" or data.station_id == &"arcane":
				_add_light(Color(1.0, 0.55, 0.2) if data.station_id == &"forge" else Color(0.6, 0.5, 1.0), 1.4, 5.0, Vector3(0, 1.0, 0.4))
		BuildPieceData.Behavior.LIGHT:
			add_to_group(&"heat_sources")
			_add_light(Color(1.0, 0.7, 0.35), 1.8, 8.0, Vector3(0, 1.45, 0))
			var flame := MeshInstance3D.new()
			var fb := BlockMesh.new()
			fb.box(Vector3.ZERO, Vector3(0.14, 0.22, 0.14), Color(1.0, 0.75, 0.3))
			var fm := fb.commit()
			fm.surface_set_material(0, Materials.vertex_color_emissive())
			flame.mesh = fm
			flame.position = Vector3(0, 1.42, 0)
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(flame)
		BuildPieceData.Behavior.CLAIM:
			add_to_group(&"land_claims")
		BuildPieceData.Behavior.FARM:
			add_to_group(&"farm_plots")
			_crop_mesh = MeshInstance3D.new()
			_crop_mesh.position.y = 0.1
			add_child(_crop_mesh)


func _add_light(color: Color, energy: float, range_m: float, pos: Vector3) -> void:
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = energy
	_light.omni_range = range_m
	_light.position = pos
	add_child(_light)


func _process(delta: float) -> void:
	if _crop_mesh == null:
		return
	_crop_tick -= delta
	if _crop_tick > 0.0:
		return
	_crop_tick = 1.0
	update_crop_visual()


func update_crop_visual() -> void:
	if _crop_mesh == null:
		return
	var st := -1 if crop == &"" else Farming.stage(crop, planted_at, GameState.world_time)
	if st != _crop_stage:
		_crop_stage = st
		_crop_mesh.mesh = null if st < 0 else BuildMeshes.get_mesh(StringName("crop_%s_%d" % [crop, st]))


func _physics_process(delta: float) -> void:
	if _spike_area == null:
		return
	_spike_tick -= delta
	if _spike_tick > 0.0:
		return
	_spike_tick = 0.5
	for body in _spike_area.get_overlapping_bodies():
		if body is Enemy and not body.is_dead:
			var charging: bool = body.is_charging()
			var info := DamageInfo.create(data.spike_damage * 0.5 * (3.0 if charging else 1.0), self, &"physical")
			info.tag = "Spikes"
			info.hit_position = body.global_position + Vector3(0, 1.2, 0)
			var away: Vector3 = body.global_position - global_position
			away.y = 0.0
			info.knockback = away.normalized() * 3.0
			info.poise_damage = 40.0 if charging else 5.0
			body.receive_hit(info)


## Warmth for TemperatureComponent (torches are small heat sources).
func heat_at(pos: Vector3) -> float:
	if data.behavior != BuildPieceData.Behavior.LIGHT:
		return 0.0
	var d := pos.distance_to(global_position)
	return 0.0 if d >= 3.0 else 6.0 * (1.0 - d / 3.0)


func claim_radius() -> float:
	return data.claim_radius


# --- Interaction ------------------------------------------------------------------------

func is_interactable() -> bool:
	return data.behavior in [BuildPieceData.Behavior.DOOR, BuildPieceData.Behavior.CHEST,
		BuildPieceData.Behavior.BED, BuildPieceData.Behavior.CLAIM, BuildPieceData.Behavior.FARM]


func get_interact_text() -> String:
	match data.behavior:
		BuildPieceData.Behavior.DOOR:
			return "Close door" if is_open else "Open door"
		BuildPieceData.Behavior.CHEST:
			return "Open %s" % data.display_name
		BuildPieceData.Behavior.BED:
			return "Sleep / set respawn point"
		BuildPieceData.Behavior.CLAIM:
			return "%s (radius %d m)" % [data.display_name, roundi(data.claim_radius)]
		BuildPieceData.Behavior.FARM:
			return _farm_text()
	return data.display_name


func interact(player: Node) -> void:
	match data.behavior:
		BuildPieceData.Behavior.DOOR:
			set_open(not is_open)
		BuildPieceData.Behavior.CHEST:
			Events.open_container.emit(self)
		BuildPieceData.Behavior.BED:
			if World.instance:
				World.instance.use_bed(self, player)
		BuildPieceData.Behavior.FARM:
			farm_interact(player)
		BuildPieceData.Behavior.CLAIM:
			Events.toast.emit("This land is yours: no monsters spawn within %d m, full refunds when deconstructing" % roundi(data.claim_radius), Color(0.6, 0.85, 1.0))


# --- Farming ------------------------------------------------------------------------------

func _seed_in(player: Node) -> StringName:
	if player == null or not "inventory" in player:
		return &""
	for c in Farming.CROPS:
		if player.inventory.count_of(Farming.CROPS[c].seed) > 0:
			return Farming.CROPS[c].seed
	return &""


func _farm_text() -> String:
	if crop == &"":
		var seed := _seed_in(World.instance.player if World.instance else null)
		if seed == &"":
			return "Farm plot (you need seeds)"
		var d: ItemData = ItemDB.get_item(seed)
		return "Plant %s" % (d.display_name if d else String(seed))
	var name_ := String(crop).capitalize()
	var p := Farming.progress(crop, planted_at, GameState.world_time)
	return "Harvest %s" % name_ if p >= 1.0 else "%s: %d%% grown" % [name_, floori(p * 100.0)]


## Plants the first seed you carry, or harvests a ripe crop. Returns what happened.
func farm_interact(player: Node) -> StringName:
	if crop == &"":
		var seed := _seed_in(player)
		if seed == &"":
			Events.toast.emit("You need seeds (farmers and merchants sell them)", Color(1, 0.8, 0.5))
			return &"no_seeds"
		player.inventory.remove_item(seed, 1)
		crop = Farming.crop_for_seed(seed)
		planted_at = GameState.world_time
		update_crop_visual()
		return &"planted"
	if Farming.progress(crop, planted_at, GameState.world_time) < 1.0:
		Events.toast.emit(_farm_text(), Color(0.8, 1, 0.7))
		return &"growing"
	var c: Dictionary = Farming.CROPS[crop]
	var n := randi_range(int(c.yield[0]), int(c.yield[1]))
	if "character" in player and randf() < player.character.harvest_bonus_chance():
		n += 1
	player.give_or_drop(c.produce, n)
	player.give_or_drop(c.seed, randi_range(int(c.seeds[0]), int(c.seeds[1])))
	if "character" in player:
		player.character.grant_xp(Farming.XP_PER_HARVEST, Progression.Source.FARMING)
	crop = &""
	update_crop_visual()
	return &"harvested"


func set_open(open: bool) -> void:
	is_open = open
	if _leaf:
		var tw := create_tween()
		tw.tween_property(_leaf, "rotation:y", -PI * 0.5 if open else 0.0, 0.25)
	# An open door lets things through.
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", open)


# --- Save ------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var d := {}
	if storage:
		d["storage"] = storage.to_array()
	if data.behavior == BuildPieceData.Behavior.DOOR:
		d["open"] = is_open
	if crop != &"":
		d["crop"] = String(crop)
		d["planted_at"] = planted_at
	return d


func load_data(d: Dictionary) -> void:
	if storage and d.has("storage"):
		storage.from_array(d.storage)
	if d.get("open", false):
		set_open(true)
	if d.has("crop"):
		crop = StringName(d.crop)
		planted_at = float(d.get("planted_at", 0.0))
		update_crop_visual()
