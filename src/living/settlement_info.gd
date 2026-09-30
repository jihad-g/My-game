class_name SettlementInfo
extends RefCounted
## One generated settlement (village or kingdom capital). Pure data, derived
## deterministically from the world seed by `Settlements`.

enum Type { VILLAGE, KINGDOM }

var id: String = ""
var type: int = Type.VILLAGE
## Centre column.
var center := Vector2i.ZERO
## Flattened ground height in blocks.
var height: int = 0
## Flat area radius and blend distance back to natural terrain (metres).
var radius: float = 36.0
var blend: float = 12.0
var biome_id: StringName
var biome_index: int = 0
var name: String = ""
## Per-settlement hash for layouts, names, NPCs.
var seed: int = 0
## Villages: id/name of the kingdom they belong to ("" = independent).
var kingdom_id: String = ""
var kingdom_name: String = ""
## Kingdom banner colour (villages inherit their kingdom's).
var color := Color(0.6, 0.6, 0.6)


func is_kingdom() -> bool:
	return type == Type.KINGDOM


func world_center() -> Vector3:
	return Vector3(center.x + 0.5, height * TerrainGenerator.BLOCK_HEIGHT, center.y + 0.5)


func ground_y() -> float:
	return height * TerrainGenerator.BLOCK_HEIGHT


## Horizontal distance from the centre.
func distance_to(pos: Vector3) -> float:
	return Vector2(pos.x - (center.x + 0.5), pos.z - (center.y + 0.5)).length()


func contains(pos: Vector3, margin: float = 0.0) -> bool:
	return distance_to(pos) <= radius + margin


func title() -> String:
	if is_kingdom():
		return "%s, capital of the Kingdom of %s" % [name, kingdom_name]
	return "Village of %s" % name


func short_title() -> String:
	return name if not is_kingdom() else "%s (capital)" % name
