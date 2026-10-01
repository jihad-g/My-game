class_name MonsterData
extends EnemyData
## Data for the generic Monster AI (Milestone 6): dungeon dwellers, ruin
## guardians, tower mages, temple guardians and bosses.

enum Style { MELEE, RANGED, CASTER, BOSS }

@export var style: Style = Style.MELEE
## Model: humanoid looks (skeleton, skeleton_archer, cultist, golem, bone_king,
## arcane_colossus, temple_guardian, warden) or beast looks (wisp, crawler, thornmaw).
@export var look: StringName = &"skeleton"
@export var model_scale: float = 1.0
@export var tint: Color = Color(0.9, 0.88, 0.8)
@export var accent: Color = Color(1.0, 0.3, 0.2)
## Main melee attack (reach/arc/timings/damage).
@export var melee: AttackData
## Heavy telegraphed attack (optional; bosses and brutes).
@export var heavy: AttackData
@export var heavy_cooldown: float = 6.0
## Optional status applied by melee hits: [id, duration, params] (e.g. poison).
@export var melee_status: Array = []

@export_group("Ranged")
@export var projectile_damage: float = 10.0
@export var projectile_type: StringName = &"physical"
@export var projectile_speed: float = 14.0
@export var projectile_color: Color = Color(0.9, 0.85, 0.7)
## Optional status on hit: [id, duration, params]
@export var projectile_status: Array = []
@export var projectile_windup: float = 0.6
@export var projectile_cooldown: float = 2.2
## Ranged/casters try to stay between these distances.
@export var preferred_min: float = 5.0
@export var preferred_max: float = 10.0
## Floats (wisps) - ignores gravity, hovers.
@export var flying: bool = false

@export_group("Boss")
## Title shown on the boss bar ("The Bone King").
@export var boss_title: String = ""
## Moves the boss cycles through: cleave, slam, volley, charge, summon.
@export var boss_moves: Array = []
@export var slam_damage: float = 30.0
@export var slam_radius: float = 4.5
@export var volley_count: int = 5
## Summoned adds (MonsterData) and how many per summon.
@export var summon: MonsterData
@export var summon_count: int = 2
## Health fraction below which the boss enrages (faster, shorter cooldowns).
@export var enrage_at: float = 0.5
