class_name EnemyData
extends Resource
## Data definition of an enemy type. AI behaviour lives in the enemy script,
## tuning lives here so designers can make variants without code.

enum Category { WILDLIFE, MONSTER, BANDIT, UNDEAD, MAGICAL, DUNGEON, ELITE, BOSS }

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.WILDLIFE
@export var max_health: float = 60.0
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.5
@export var turn_speed: float = 8.0
## Distance at which the enemy notices the player.
@export var aggro_range: float = 10.0
## Gives up the chase when this far from its home position.
@export var leash_range: float = 26.0
@export var max_poise: float = 30.0
## Damage type -> multiplier (>1 weakness, <1 resistance).
@export var damage_multipliers: Dictionary = {}
## Extra damage multiplier while the enemy is in its "exposed" recovery window.
@export var exposed_damage_multiplier: float = 1.5
@export var attacks: Array = []  ## Array of AttackData
@export var loot: Array = []  ## Array of LootEntry
## XP reward (XP system is Phase 2; stored for forward compatibility).
@export var xp_reward: int = 10
## Seconds before a killed spawn slot can respawn.
@export var respawn_time: float = 300.0


func get_attack(attack_id: StringName) -> AttackData:
	for a in attacks:
		if a is AttackData and a.id == attack_id:
			return a
	return null
