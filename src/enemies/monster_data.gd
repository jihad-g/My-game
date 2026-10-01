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
## Moves the boss cycles through: cleave, slam, volley, charge, summon,
## and (Milestone 7) spikes, nova, beam, meteor_rain, teleport, shield, pull, roar, bomb.
@export var boss_moves: Array = []
@export var slam_damage: float = 30.0
@export var slam_radius: float = 4.5
@export var volley_count: int = 5
## Summoned adds (MonsterData) and how many per summon.
@export var summon: MonsterData
@export var summon_count: int = 2
## Health fraction below which the boss enrages (faster, shorter cooldowns).
@export var enrage_at: float = 0.5

@export_group("Boss phases (M7)")
## Phase changes as health drops: Array of Dictionaries
## {"at": 0.66, "moves": [&"..."], "text": "...", "hazard": &"falling_rocks" / &"fire_rain" / &"poison_pools" / &""}
## On entering a phase the boss roars (briefly invulnerable), switches its move
## list and, if `hazard` is set, keeps dropping hazards around the player.
@export var phases: Array = []
## Status put on the player by spikes / nova (e.g. [&"bleed", 5.0, {"dps": 3.0}]).
@export var spike_status: Array = []
## Shield move: number of ward pylons that must be destroyed.
@export var shield_pylons: int = 3
@export var beam_damage: float = 8.0
@export var nova_radius: float = 7.0

@export_group("Behaviour (M7)")
## Run away below this health fraction (once), then come back to fight. 1.0 = always flees (treasure goblin).
@export var flee_below: float = 0.0
## Chance to sidestep when the player swings at it from close by.
@export var dodge_chance: float = 0.0
## Alerts idle allies within this radius when it spots you.
@export var pack_alert: float = 10.0
## Support casters: &"heal" (heals the most wounded ally), &"haste" (speeds allies up), &"ward" (shields an ally).
@export var support: StringName = &""
@export var support_power: float = 40.0
@export var support_cooldown: float = 6.0
## Damage multiplier against building pieces (raiders: brutes smash walls).
@export var siege_mult: float = 1.0
## Projectiles explode on impact in this radius (bandit bombs). 0 = single target.
@export var projectile_explode_radius: float = 0.0
## Raiders also attack townsfolk (guards) and buildings.
@export var raider: bool = false
## Can roll elite affixes.
@export var can_be_elite: bool = true
