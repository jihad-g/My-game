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

enum EquipSlot { NONE, MAIN_HAND, OFF_HAND, HEAD, CHEST, HANDS, FEET, RING, AMULET }
const SLOT_NAMES := ["", "Main hand", "Off hand", "Head", "Chest", "Hands", "Feet", "Ring", "Amulet"]

## Milestone 14 (Outfits): how heavy a piece of armour is. Light pieces make you
## harder to notice and cheaper to dodge in; heavy pieces do the opposite.
enum ArmorWeight { NONE, LIGHT, MEDIUM, HEAVY }
const WEIGHT_NAMES := ["", "Light", "Medium", "Heavy"]
## Slots that are drawn on the character and count towards armour weight.
const OUTFIT_SLOTS := [EquipSlot.HEAD, EquipSlot.CHEST, EquipSlot.HANDS, EquipSlot.FEET, EquipSlot.OFF_HAND, EquipSlot.AMULET]

## Human-readable names for stat_bonuses keys.
const STAT_NAMES := {
	&"armor": "Armor", &"damage_bonus": "Weapon damage", &"spell_power": "Spell power %",
	&"crit_chance": "Crit chance %", &"attack_speed": "Attack speed %", &"move_speed": "Move speed %",
	&"max_health": "Max health", &"max_mana": "Max mana", &"max_stamina": "Max stamina",
	&"mana_regen": "Mana regen %", &"insulation": "Cold protection °C", &"cooling": "Heat protection °C",
	&"block": "Block %", &"strength": "Strength", &"mana_control": "Mana Control",
	&"defense": "Defense", &"crafting": "Crafting", &"dexterity": "Dexterity",
}

## Description of potion/shrine buffs (see PlayerAbilities outgoing/incoming_mult).
const BUFF_TEXT := {&"might": "+20% damage", &"stoneskin": "-20% damage taken",
	&"starlight": "+15% damage, full mana", &"blessing": "+10% damage, -10% damage taken"}

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
## Potions (Milestone 6): mana restored and a timed buff (PlayerAbilities buff id).
@export var mana_restore: float = 0.0
@export var buff_id: StringName
@export var buff_duration: float = 0.0
## Status effects removed on use (Milestone 7): e.g. [&"poison", &"bleed"]; [&"all"] cures every harmful effect.
@export var cures: Array[StringName] = []
## Healing over time (the "regen" status): health per second for regen_duration seconds.
@export var regen_hps: float = 0.0
@export var regen_duration: float = 0.0

@export_group("Equipment")
@export var equip_slot: EquipSlot = EquipSlot.NONE
## Weapon/offhand type: &"sword", &"axe", &"dagger", &"staff", &"shield"...
@export var weapon_type: StringName
@export var moveset: WeaponMoveset
@export var required_level: int = 1
## Stat -> value (see STAT_NAMES). Percent stats are in percent points.
@export var stat_bonuses: Dictionary = {}
## Armour weight (Milestone 14). NONE for weapons, rings and amulets.
@export var armor_weight: ArmorWeight = ArmorWeight.NONE
## How the piece is drawn on the character (HumanoidModel outfit looks, e.g.
## &"helm_plume", &"robe", &"hood_mask"). Empty = not drawn.
@export var outfit_look: StringName

@export_group("Tool")
## Harvesting tool type (&"axe", &"pickaxe") - used automatically from the inventory.
@export var tool_kind: StringName
@export var tool_tier: int = 0

@export_group("Recipe book")
## Recipe ids learned when this item is used (books, scrolls).
@export var teaches_recipes: Array = []

@export_group("Spell tome")
## Advanced spell learned when this item is used (Milestone 7, see SpellBook).
@export var teaches_spell: StringName

@export_group("Placeable")
## Scene spawned in the world when the item is used/placed.
@export var placeable_scene: PackedScene


func is_tool() -> bool:
	return tool_kind != &""


func is_recipe_book() -> bool:
	return not teaches_recipes.is_empty()


func is_spell_tome() -> bool:
	return teaches_spell != &""


func is_equippable() -> bool:
	return equip_slot != EquipSlot.NONE


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
	if mana_restore > 0.0:
		lines.append("Restores %d mana" % roundi(mana_restore))
	if buff_id != &"" and buff_duration > 0.0:
		lines.append("%s for %d min" % [BUFF_TEXT.get(buff_id, String(buff_id).capitalize()), roundi(buff_duration / 60.0)])
	if regen_hps > 0.0 and regen_duration > 0.0:
		lines.append("Heals %d health per second for %ds" % [roundi(regen_hps), roundi(regen_duration)])
	if not cures.is_empty():
		lines.append("Cures %s" % ("all harmful effects" if cures.has(&"all") else ", ".join(cures.map(func(c: StringName) -> String: return StatusEffects.display_name(c).to_lower()))))
	if teaches_spell != &"":
		lines.append("Use to learn a spell")
	if is_tool():
		lines.append("%s tier %d (used automatically when harvesting)" % [String(tool_kind).capitalize(), tool_tier])
	if is_recipe_book():
		lines.append("Use to learn %d recipe%s" % [teaches_recipes.size(), "" if teaches_recipes.size() == 1 else "s"])
	if is_equippable():
		var slot_line: String = SLOT_NAMES[equip_slot]
		if weapon_type != &"":
			slot_line += " · %s" % String(weapon_type).capitalize()
		if armor_weight != ArmorWeight.NONE:
			slot_line += " · %s armour" % WEIGHT_NAMES[armor_weight]
		lines.append(slot_line)
		match armor_weight:
			ArmorWeight.LIGHT:
				lines.append("Light: enemies notice you later, dodging costs less")
			ArmorWeight.HEAVY:
				lines.append("Heavy: enemies notice you sooner, dodging costs more")
		if required_level > 1:
			lines.append("Requires level %d" % required_level)
		for stat in stat_bonuses:
			lines.append("%+d %s" % [roundi(float(stat_bonuses[stat])), STAT_NAMES.get(stat, String(stat))])
	return lines
