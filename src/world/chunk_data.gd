class_name ChunkData
extends RefCounted
## Pure data produced by TerrainGenerator for one chunk at one LOD and layer.
##
## Generated on worker threads; contains no nodes or GPU resources. The main
## thread turns it into meshes/collision in Chunk.build().

var coord: Vector2i
var lod: int = 0
## 0 = surface, 1 = underground (see TerrainGenerator.Layer).
var layer: int = 0
## Blocks per column (1 at LOD0, 2 at LOD1, 4 at LOD2).
var step: int = 1
## Terrain surface arrays (local to the chunk origin).
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## Triangle soup for ConcavePolygonShape3D (LOD0 only).
var collision_faces := PackedVector3Array()
## Water surface arrays.
var water_vertices := PackedVector3Array()
var water_indices := PackedInt32Array()
## Array of Dictionary {prop_id, index, position(local), rotation, scale}
var props: Array = []
## Array of Dictionary {key, rule, position(world)}
var spawns: Array = []
## Special structures: Array of Dictionary {type: StringName, position(local), key}
var features: Array = []
## Column heights (blocks) at this LOD's resolution, with a 1-column border.
var heights := PackedInt32Array()
## Biome index per column (same layout as heights).
var biomes := PackedByteArray()
var min_height: int = 0
var max_height: int = 0


## Rough memory footprint in bytes (for the ChunkManager's data cache budget).
func estimate_bytes() -> int:
	return 256 + vertices.size() * 12 + normals.size() * 12 + colors.size() * 16 + indices.size() * 4 \
		+ collision_faces.size() * 12 + water_vertices.size() * 12 + water_indices.size() * 4 \
		+ heights.size() * 4 + biomes.size() + props.size() * 160 + spawns.size() * 96 + features.size() * 96
