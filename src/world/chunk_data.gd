class_name ChunkData
extends RefCounted
## Pure data produced by TerrainGenerator for one chunk at one LOD.
##
## Generated on worker threads; contains no nodes or GPU resources. The main
## thread turns it into meshes/collision in Chunk.build().

var coord: Vector2i
var lod: int = 0
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
## Array of Dictionary {key, rule_index, position(world)}
var spawns: Array = []
## Column heights (blocks) at this LOD's resolution, with a 1-column border.
var heights := PackedInt32Array()
var min_height: int = 0
var max_height: int = 0
