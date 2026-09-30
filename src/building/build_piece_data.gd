class_name BuildPieceData
extends Resource
## A buildable piece: cost, grid placement, looks and behaviour.

enum Category { FLOOR, WALL, DOOR, WINDOW, FENCE, ROOF, FURNITURE, STORAGE, STATION, DEFENSE, LIGHT, CLAIM, FARMING }
const CATEGORY_NAMES := ["Floors", "Walls", "Doors", "Windows", "Fences", "Roofs", "Furniture", "Storage",
	"Stations", "Defenses", "Lights", "Claims", "Farming"]

## Grid slot: FLOOR/OBJECT sit in a cell, EDGE on a cell edge, ROOF above a cell.
enum Placement { FLOOR, OBJECT, EDGE, ROOF }

## Behaviours implemented by BuildPiece.
enum Behavior { NONE, DOOR, CHEST, BED, SPIKES, STATION, LIGHT, CLAIM, FARM }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.WALL
@export var placement: Placement = Placement.EDGE
@export var behavior: Behavior = Behavior.NONE
## item id -> count
@export var cost: Dictionary = {}
## BuildMeshes function name (build_<name>).
@export var mesh: StringName
## Collision box size and centre (local, before rotation).
@export var collision_size: Vector3 = Vector3(1, 2.6, 0.2)
@export var collision_center: Vector3 = Vector3(0, 1.3, 0)
@export var blocks_movement: bool = true
## Station id for STATION behaviour (&"workbench", &"forge"...).
@export var station_id: StringName
## CLAIM behaviour: claimed radius in metres.
@export var claim_radius: float = 0.0
## SPIKES behaviour: damage per second to enemies touching it (charging enemies take 3x).
@export var spike_damage: float = 0.0
## CHEST behaviour: storage slots.
@export var storage_slots: int = 0
@export var required_level: int = 1
## Dither out near the camera (walls/roofs shouldn't hide the player).
@export var fade_near_camera: bool = true


func cost_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for item in cost:
		var d: ItemData = ItemDB.get_item(item)
		out.append("%d %s" % [int(cost[item]), d.display_name if d else String(item)])
	return out
