class_name AttackData
extends Resource
## A single melee attack definition (player or enemy). Timings in seconds.
##
## Attack flow: WINDUP (telegraph, can't hit) -> ACTIVE (hit check happens at the
## start) -> RECOVERY (vulnerable; combos/dodges can cancel near the end).

@export var id: StringName
@export var display_name: String = ""
@export var damage: float = 10.0
@export var damage_type: StringName = &"physical"
@export var stamina_cost: float = 0.0
@export var windup: float = 0.15
@export var active: float = 0.1
@export var recovery: float = 0.25
## Fraction of recovery after which a buffered combo/dodge may cancel it.
@export_range(0.0, 1.0) var cancel_ratio: float = 0.4
@export var reach: float = 1.8
@export var arc_degrees: float = 100.0
@export var knockback: float = 3.0
@export var poise_damage: float = 10.0
## Forward movement during the windup/active phases (commits the attack).
@export var lunge_speed: float = 2.0
## Movement speed multiplier while this attack is running.
@export var move_multiplier: float = 0.25
@export var crit_chance_bonus: float = 0.0
@export var crit_multiplier: float = 1.5
## Animation id interpreted by the character model ("slash_r", "slash_l", "thrust", "overhead", "bite").
@export var animation: StringName = &"slash_r"
@export var camera_shake: float = 0.15
## Seconds every enemy hit is stunned (war hammers, Milestone 17a). 0 = none.
@export var stun: float = 0.0
## Milestone 18b (hack and slash): the last hit of a combo chain - a bigger hit with a ring, a
## stronger shake and a longer hit-stop.
@export var finisher: bool = false
## Seconds a hit enemy lies on the ground (0 = none). Bosses only fall when their poise breaks.
@export var knockdown: float = 0.0
## Freeze on hit, in seconds (0 = chosen from the attack's weight).
@export var hitstop: float = 0.0


func total_duration() -> float:
	return windup + active + recovery
