class_name PropData
extends Resource
## A world prop type: trees, rocks, bushes, flowers, loose items.

enum InteractMode {
	NONE,     ## Decoration only (flowers, grass tufts).
	HARVEST,  ## Hit it with attacks to break it (trees, rocks).
	GATHER,   ## Press interact to collect (bushes, loose sticks/stones).
}

@export var id: StringName
@export var display_name: String = ""
## Name of the builder function in PropLibrary that creates the mesh.
@export var mesh_builder: StringName
@export var interact_mode: InteractMode = InteractMode.NONE
## Blocks movement (collision layer PROP) - otherwise it is walk-through.
@export var blocks_movement: bool = false
@export var collision_radius: float = 0.4
@export var collision_height: float = 2.0
## Hits needed to break a HARVEST prop.
@export var hits_to_break: int = 3
@export var drops: Array = []  ## Array of LootEntry
## Seconds of world time until it comes back (0 = never).
@export var regrow_time: float = 0.0
@export var interact_text: String = "Gather"
## Hide beyond this camera distance (0 = always visible).
@export var visibility_range: float = 0.0
@export var cast_shadow: bool = true
## Dither out when between the camera and the player (tall props like trees).
@export var fade_near_camera: bool = false
## XP for harvesting/gathering (0 = default: 3 for HARVEST, 1 for GATHER).
@export var xp: int = 0
## Rendered unshaded/glowing (crystals, glowing fungi, magical plants).
@export var glow: bool = false
