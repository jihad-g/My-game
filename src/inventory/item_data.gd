class_name ItemData
extends Resource
## Definition of an item type. One .tres per item in res://data/items/.

enum Category { MATERIAL, FOOD, TOOL, WEAPON, ARMOR, PLACEABLE, MISC }
## Material/item tiers used across crafting and loot (see design doc).
enum Rarity { BASIC, COMMON, UNCOMMON, RARE, VERY_RARE, MAGICAL, LEGENDARY }

const RARITY_NAMES := ["Basic", "Common", "Uncommon", "Rare", "Very Rare", "Magical", "Legendary"]
const RARITY_COLORS := [
	Color(0.78, 0.78, 0.78), Color(1, 1, 1), Color(0.45, 0.9, 0.4), Color(0.35, 0.6, 1.0),
	Color(0.7, 0.45, 1.0), Color(1.0, 0.45, 0.85), Color(1.0, 0.72, 0.2),
]
const CATEGORY_NAMES := ["Material", "Food", "Tool", "Weapon", "Armor", "Placeable", "Misc"]

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MATERIAL
@export var rarity: Rarity = Rarity.BASIC
@export var max_stack: int = 99
## Base trade value in copper (economy is Phase 4; used for display now).
@export var base_value: int = 1

@export_group("Icon")
## Placeholder icon: coloured tile + glyph until real icon art exists.
@export var icon_color: Color = Color.WHITE
@export var icon_glyph: String = "?"

@export_group("Consumable")
@export var hunger_restore: float = 0.0
@export var health_restore: float = 0.0
## Temporary temperature offset in degrees C (+ warms, - cools).
@export var temperature_offset: float = 0.0
@export var temperature_duration: float = 0.0

@export_group("Placeable")
## Scene spawned in the world when the item is used/placed.
@export var placeable_scene: PackedScene


func is_consumable() -> bool:
	return category == Category.FOOD


func is_placeable() -> bool:
	return category == Category.PLACEABLE and placeable_scene != null


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func category_name() -> String:
	return CATEGORY_NAMES[category]


## Lines describing gameplay effects, for tooltips.
func effect_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if hunger_restore > 0.0:
		lines.append("Restores %d hunger" % roundi(hunger_restore))
	if health_restore > 0.0:
		lines.append("Restores %d health" % roundi(health_restore))
	if temperature_offset != 0.0 and temperature_duration > 0.0:
		lines.append("%s %+d°C for %ds" % ["Warms" if temperature_offset > 0 else "Cools",
			roundi(temperature_offset), roundi(temperature_duration)])
	return lines
