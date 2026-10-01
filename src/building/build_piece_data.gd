class_name BuildPieceData
extends Resource
## A buildable piece: cost, grid placement, looks and behaviour.

enum Category { FLOOR, WALL, DOOR, WINDOW, FENCE, ROOF, FURNITURE, STORAGE, STATION, DEFENSE, LIGHT, CLAIM, FARMING }
const CATEGORY_NAMES := ["Floors", "Walls", "Doors", "Windows", "Fences", "Roofs", "Furniture", "Storage",
	"Stations", "Defenses", "Lights", "Claims", "Farming"]

## Grid slot: FLOOR/OBJECT sit in a cell, EDGE on a cell edge, ROOF above a cell.
enum Placement { FLOOR, OBJECT, EDGE, ROOF }

## Behaviours implemented by BuildPiece. TURRET shoots raiders, BELL warns of raids (Milestone 7).
enum Behavior { NONE, DOOR, CHEST, BED, SPIKES, STATION, LIGHT, CLAIM, FARM, TURRET, BELL }

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
## Hit points against raiders (Milestone 7). 0 = from the material: wood 200, stone 500, metal 800
## (furniture, stations and lights have half, floors and roofs 80%).
@export var max_health: float = 0.0
## TURRET behaviour: arrow damage, range (m) and seconds between shots.
@export var turret_damage: float = 0.0
@export var turret_range: float = 16.0
@export var turret_interval: float = 1.6
## Dither out near the camera (walls/roofs shouldn't hide the player).
@export var fade_near_camera: bool = true


func cost_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for item in cost:
		var d: ItemData = ItemDB.get_item(item)
		out.append("%d %s" % [int(cost[item]), d.display_name if d else String(item)])
	return out


func get_max_health() -> float:
	if max_health > 0.0:
		return max_health
	var hp := 200.0
	if cost.has(&"iron_ingot") or cost.has(&"copper_ingot") or cost.has(&"mithril_ingot"):
		hp = 800.0
	elif cost.has(&"stone"):
		hp = 500.0
	if category in [Category.FURNITURE, Category.STORAGE, Category.STATION, Category.LIGHT, Category.FARMING]:
		hp *= 0.5
	elif category in [Category.FLOOR, Category.ROOF]:
		hp *= 0.8
	return hp
