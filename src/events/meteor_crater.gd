class_name MeteorCrater
extends StaticBody3D
## A fallen meteor (Milestone 7 rare event): a smoking crater with a glowing
## star-metal rock. Mine it (F, needs a copper pickaxe or better) once for
## star metal ore. Sometimes a Starborn Colossus rises to guard it.

signal mined(crater: MeteorCrater)

var crater_id := ""
var is_mined := false
var _rock: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE | Layers.PROP
	collision_mask = 0
	add_to_group(&"meteor_craters")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 1.6)
	cs.shape = box
	cs.position.y = 0.6
	add_child(cs)
	var b := BlockMesh.new()
	# Scorched rim
	for k in 12:
		var a := k * TAU / 12.0
		b.box(Vector3(cos(a) * 2.6, 0.12, sin(a) * 2.6), Vector3(1.4, 0.35 + (k % 3) * 0.1, 0.9), Color(0.22, 0.18, 0.16))
	b.box(Vector3(0, 0.02, 0), Vector3(4.4, 0.05, 4.4), Color(0.12, 0.1, 0.1))
	var rim := MeshInstance3D.new()
	rim.mesh = b.commit()
	add_child(rim)
	var r := BlockMesh.new()
	r.box(Vector3(0, 0.55, 0), Vector3(1.3, 1.1, 1.2), Color(0.35, 0.38, 0.6))
	r.box(Vector3(0.2, 0.9, 0.1), Vector3(0.7, 0.6, 0.8), Color(0.55, 0.6, 0.95))
	r.box(Vector3(-0.3, 0.4, -0.2), Vector3(0.5, 0.5, 0.6), Color(0.7, 0.75, 1.0))
	var rm := r.commit()
	rm.surface_set_material(0, Materials.vertex_color_emissive())
	_rock = MeshInstance3D.new()
	_rock.mesh = rm
	add_child(_rock)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.65, 1.0)
	_light.light_energy = 2.0
	_light.omni_range = 9.0
	_light.position.y = 1.4
	add_child(_light)


func is_interactable() -> bool:
	return not is_mined


func get_interact_text() -> String:
	return "Mine the meteor (star metal)"


func interact(player: Node) -> void:
	if is_mined or player == null:
		return
	if player.has_method("best_tool_tier") and player.best_tool_tier(&"pickaxe") < 1:
		Events.toast.emit("You need a pickaxe to break the meteor", Color(1, 0.7, 0.5))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(crater_id)
	LootTables.give(LootTables.roll(&"meteor", 0, rng), global_position + Vector3(0, 0.8, 0))
	if "character" in player:
		player.character.grant_xp(60, Progression.Source.EXPLORATION)
	is_mined = true
	_rock.visible = false
	_light.light_energy = 0.4
	VFX.burst(get_parent(), global_position + Vector3(0, 0.8, 0), 2.0, Color(0.6, 0.65, 1.0, 0.8))
	mined.emit(self)
