class_name ClassData
extends Resource
## A playable class. One .tres per class in res://data/classes/.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var role_summary: String = ""
## Where this hero comes from (Milestone 16 story; shown at creation and in the journal).
@export_multiline var backstory: String = ""
## Starting skill levels; must add up to exactly 50.
@export var starting_skills: Dictionary = {}
## How strongly each skill's effects apply for this class (1.0 = normal).
@export var skill_efficiency: Dictionary = {}

@export_group("Base stats")
@export var base_health: float = 80.0
@export var health_per_defense: float = 2.0
@export var base_stamina: float = 100.0
@export var base_mana: float = 30.0
@export var mana_per_point: float = 2.5
## Class multipliers applied on top of skills (a Wizard's ceiling is lower).
@export var physical_power: float = 1.0
@export var spell_power: float = 1.0
@export var base_armor: float = 0.0

@export_group("Weapons")
## Weapon type -> damage multiplier. Missing types use `unskilled_weapon_mult`.
@export var weapon_proficiency: Dictionary = {}
@export var unskilled_weapon_mult: float = 0.6
## Moveset used when no weapon is equipped.
@export var unarmed_moveset: WeaponMoveset

@export_group("Passives")
@export var block_reduction: float = 0.7
@export var parry_window: float = 0.2
@export var backstab_multiplier: float = 1.5
@export var crit_bonus: float = 0.0
## Barbarian rage mechanic.
@export var uses_rage: bool = false

@export_group("Abilities")
@export var abilities: Array = []  ## Array of AbilityData (unlock order)
## Mana cost of the Magic Temperature Shield before Mana Control discounts.
@export var temperature_shield_cost: float = 50.0

@export_group("Starting kit")
## Milestone 14: a full outfit (head, chest, hands, feet) + weapon, like a
## starting class in a souls-like. Any class can later wear any gear.
@export var starting_equipment: Array = []  ## item ids
@export var starting_items: Dictionary = {}

@export_group("Appearance")
## Milestone 14: every class shares one body and players look like the gear
## they wear. Only accent_color is still used (staff gem, shield emblem, swing
## trail); the other colours remain for older tools.
@export var shirt_color: Color = Color(0.25, 0.48, 0.85)
@export var pants_color: Color = Color(0.28, 0.24, 0.3)
@export var hair_color: Color = Color(0.42, 0.26, 0.14)
@export var accent_color: Color = Color(0.75, 0.6, 0.25)


func starting_skill(skill: StringName) -> int:
	return int(starting_skills.get(skill, 1))


func efficiency(skill: StringName) -> float:
	return float(skill_efficiency.get(skill, 1.0))


func proficiency(weapon_type: StringName) -> float:
	return float(weapon_proficiency.get(weapon_type, unskilled_weapon_mult))


## Mana Control needed before the Magic Temperature Shield can be cast.
func temperature_shield_requirement() -> int:
	return starting_skill(Skill.MANA_CONTROL) + 2


func starting_skill_total() -> int:
	var t := 0
	for s in Skill.ALL:
		t += starting_skill(s)
	return t
