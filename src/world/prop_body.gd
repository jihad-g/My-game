class_name PropBody
extends StaticBody3D
## Physics/interaction proxy for one prop instance inside a chunk.
## Visuals live in the chunk's MultiMesh; this node only exists in LOD0 chunks.

var chunk: Chunk
var prop_index: int = -1
var data: PropData
var hits_left: int = 1


func setup(p_chunk: Chunk, p_index: int, p_data: PropData) -> void:
	chunk = p_chunk
	prop_index = p_index
	data = p_data
	hits_left = maxi(1, data.hits_to_break)


## Attacks hit HARVEST props (trees, rocks).
func receive_hit(info: DamageInfo) -> void:
	if data.interact_mode != PropData.InteractMode.HARVEST or not is_instance_valid(chunk):
		return
	# Tools in the player's inventory are used automatically.
	var power := 1
	if data.tool_kind != &"" and info and info.source and info.source.has_method("best_tool_tier"):
		var tier: int = info.source.best_tool_tier(data.tool_kind)
		if tier < data.tool_tier:
			Events.toast.emit("%s needs a tier %d %s" % [data.display_name, data.tool_tier, data.tool_kind], Color(1, 0.7, 0.5))
			Events.damage_dealt.emit(global_position + Vector3(0, 1.5, 0), 0.0, false, false, "Too hard")
			return
		power += tier
	hits_left -= power
	chunk.pulse_prop(prop_index)
	var axe := data.tool_kind != &"pickaxe"
	Audio.play_at(&"chop" if axe else &"mine", global_position + Vector3(0, 1, 0), -3.0)
	VFX.debris(get_parent(), global_position + Vector3(0, 0.9, 0), data_color(), 6 if axe else 8)
	if hits_left <= 0:
		Audio.play_at(&"tree_fall" if axe and data.collision_height > 2.0 else &"rock_break", global_position, -2.0)
		chunk.harvest_prop(prop_index, null)


func is_interactable() -> bool:
	return data.interact_mode == PropData.InteractMode.GATHER


func get_interact_text() -> String:
	return "%s %s" % [data.interact_text, data.display_name]


## Debris colour for hit effects (wood for trees, stone for rocks).
func data_color() -> Color:
	if data.tool_kind == &"pickaxe":
		return Color(0.55, 0.55, 0.58)
	return Color(0.55, 0.38, 0.22)


func interact(player: Node) -> void:
	if is_interactable() and is_instance_valid(chunk):
		Audio.play(&"gather", -6.0)
		chunk.harvest_prop(prop_index, player)
