class_name PoiObject
extends StaticBody3D
## Small interactive POI objects: tower lectern (a tome with recipes), temple
## altar (blessing), dungeon entrance, and magical plants in hidden groves.

enum Kind { LECTERN, ALTAR, ENTRANCE, PLANT }

var kind: int = Kind.LECTERN
var poi: PoiInfo
var persist_key := ""
## PLANT: item given and regrow time (world seconds).
var item_id: StringName = &""
var regrow := 1800.0
var mesh_name: StringName = &""
var _visual: Node3D


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 1.2) if kind != Kind.ENTRANCE else Vector3(3.0, 2.0, 3.0)
	cs.shape = box
	cs.position.y = 0.6
	add_child(cs)
	if kind == Kind.PLANT:
		var lib := World.instance.props if World.instance else PropLibrary.new()
		var mi := MeshInstance3D.new()
		mi.mesh = lib.get_mesh(mesh_name)
		mi.material_override = Materials.vertex_color_emissive()
		add_child(mi)
		_visual = mi
		_visual.visible = is_available()


func is_available() -> bool:
	var ex := World.instance.exploration if World.instance else null
	if ex == null:
		return true
	match kind:
		Kind.PLANT:
			return GameState.world_time - ex.get_state(persist_key, -1e9) >= regrow
		Kind.LECTERN:
			return not ex.has_state(persist_key)
		Kind.ALTAR:
			return ex.has_state("cleared:" + poi.id) and GameState.world_time - ex.get_state(persist_key, -1e9) >= 1200.0
	return true


func is_interactable() -> bool:
	return kind != Kind.PLANT or is_available()


func get_interact_text() -> String:
	match kind:
		Kind.LECTERN:
			return "Read the ancient tome" if is_available() else "An empty lectern"
		Kind.ALTAR:
			var ex := World.instance.exploration
			if not ex.has_state("cleared:" + poi.id):
				return "Altar (defeat the guardian first)"
			return "Pray at the altar" if is_available() else "The altar is quiet (pray again tomorrow)"
		Kind.ENTRANCE:
			return World.instance.exploration.entrance_text(poi) if World.instance else "Enter"
		Kind.PLANT:
			var d: ItemData = ItemDB.get_item(item_id)
			return "Pick %s" % (d.display_name if d else String(item_id))
	return ""


func interact(player: Node) -> void:
	var ex := World.instance.exploration
	match kind:
		Kind.LECTERN:
			if not is_available():
				Events.toast.emit("Someone already took the tome.", Color(0.8, 0.8, 0.8))
				return
			ex.set_state(persist_key)
			var books := [&"alchemists_grimoire", &"arcane_codex", &"smithing_manual", &"leatherworker_notes"]
			if poi.rank >= 4:
				books.append_array(LootTables.SCROLLS)
			var book: StringName = books[(poi.seed + int(GameState.world_time)) % books.size()]
			player.give_or_drop(book, 1)
			player.character.grant_xp(30, Progression.Source.EXPLORATION)
			var d: ItemData = ItemDB.get_item(book)
			Events.toast.emit("The tome is %s!" % d.display_name, UITheme.GOLD)
		Kind.ALTAR:
			if not ex.has_state("cleared:" + poi.id):
				Events.toast.emit("The guardian still watches over this altar.", Color(1, 0.7, 0.5))
				return
			if not is_available():
				Events.toast.emit("The altar is quiet. Come back tomorrow.", Color(0.8, 0.8, 0.8))
				return
			ex.set_state(persist_key)
			player.abilities.add_buff(&"blessing", 1200.0)
			player.health.heal(player.health.max_health)
			player.mana.refill()
			VFX.ring(get_parent(), global_position, 5.0, Color(1.0, 0.85, 0.4, 0.8), 0.8)
			Events.toast.emit("Blessing of the Ancients: +10% damage, -10% damage taken for 20 minutes", UITheme.GOLD)
		Kind.ENTRANCE:
			ex.world.enter_dungeon(poi)
		Kind.PLANT:
			if not is_available():
				return
			ex.set_state(persist_key, GameState.world_time)
			player.give_item(item_id, 1)
			player.character.grant_xp(15, Progression.Source.HARVEST)
			_visual.visible = false


func _process(_delta: float) -> void:
	if kind == Kind.PLANT and _visual and not _visual.visible and Engine.get_process_frames() % 60 == 0:
		_visual.visible = is_available()
