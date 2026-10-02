class_name LootChest
extends StaticBody3D
## A treasure chest (ruins, vaults, towers, temples, dungeons). Opens once.
## `persist_key` != "" stores the opened state in the world save (surface
## POIs); dungeon chests are per run and reset with the dungeon.

var table: StringName = &"ruin_chest"
var rank := 0
var persist_key := ""
var golden := false
## Non-empty while the chest can't be opened (e.g. "Sealed by the guardian").
var locked_reason := ""
var opened := false
var _lid: Node3D


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE | Layers.BUILDING
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.7, 0.6)
	cs.shape = box
	cs.position.y = 0.35
	add_child(cs)
	var wood := Color(0.5, 0.33, 0.2) if not golden else Color(0.45, 0.3, 0.35)
	var trim := Color(0.9, 0.72, 0.25) if golden else Color(0.45, 0.45, 0.5)
	var b := BlockMesh.new()
	b.box(Vector3(0, 0.25, 0), Vector3(0.84, 0.5, 0.56), wood)
	b.box(Vector3(0, 0.25, 0.285), Vector3(0.86, 0.08, 0.02), trim)
	b.box(Vector3(0, 0.1, 0), Vector3(0.88, 0.06, 0.6), trim)
	var body := MeshInstance3D.new()
	body.mesh = b.commit()
	add_child(body)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, -0.28)
	add_child(_lid)
	var lb := BlockMesh.new()
	lb.box(Vector3(0, 0.08, 0.28), Vector3(0.88, 0.16, 0.6), wood * 0.9)
	lb.box(Vector3(0, 0.08, 0.58), Vector3(0.14, 0.14, 0.04), trim)
	var lid := MeshInstance3D.new()
	lid.mesh = lb.commit()
	_lid.add_child(lid)
	if persist_key != "" and World.instance and World.instance.exploration.has_state("open:" + persist_key):
		opened = true
	if opened:
		_lid.rotation.x = -1.9


func get_interact_text() -> String:
	if locked_reason != "":
		return "Sealed chest (%s)" % locked_reason
	return "Empty chest" if opened else ("Open golden chest" if golden else "Open chest")


func interact(_player: Node) -> void:
	if locked_reason != "":
		Events.toast.emit(locked_reason, Color(1, 0.7, 0.5))
		return
	if opened:
		Events.toast.emit("It's empty.", Color(0.8, 0.8, 0.8))
		return
	open()


## Opens the chest and hands out its loot. Returns the roll.
func open() -> Dictionary:
	opened = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(persist_key + str(GameState.world_time) + str(get_instance_id()))
	var result := LootTables.roll(table, rank, rng)
	LootTables.give(result, global_position)
	if persist_key != "" and World.instance:
		World.instance.exploration.set_state("open:" + persist_key)
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK)
	VFX.burst(get_parent(), global_position + Vector3(0, 0.8, 0), 1.0, Color(1.0, 0.85, 0.4, 0.7))
	if World.instance:
		World.instance.player.character.grant_xp(8 + rank * 6, Progression.Source.EXPLORATION)
		if World.instance.quests:
			World.instance.quests.on_chest_opened(self)
	return result
