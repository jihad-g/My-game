extends Node
## Prints a hash of the generated terrain (heights + biomes, no props) for a few
## seeds. Used to prove that old saves keep exactly the same land when the
## terrain generator changes (Milestone 18d). Run:
##   godot --headless --path . res://tools/terrain_fingerprint.tscn -- [--shape=N]

static func fingerprint(gen: TerrainGenerator) -> int:
	var h := 17
	for c: Vector2i in [Vector2i(0, 0), Vector2i(5, -3), Vector2i(-17, 9), Vector2i(40, 40), Vector2i(-300, 120), Vector2i(77, -210)]:
		var d := gen.generate_chunk(c, 0)
		for k in d.heights.size():
			h = HashUtils.hash3(h, d.heights[k], d.biomes[k])
	return h


func _ready() -> void:
	var shape := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shape="):
			shape = int(a.substr(8))
	var settings: WorldGenSettings = load("res://data/worldgen/default_worldgen.tres")
	for s in [GameState.DEFAULT_SEED, 42, 987654321]:
		var gen := TerrainGenerator.new(s, settings, shape if shape >= 0 else TerrainGenerator.LATEST_SHAPE)
		print("seed %d shape %d -> %d" % [s, shape, fingerprint(gen)])
	get_tree().quit()
