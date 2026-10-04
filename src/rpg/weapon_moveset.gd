class_name WeaponMoveset
extends Resource
## The attacks a weapon type performs (light combo + heavy attack).

@export var id: StringName
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Lunge used when attacking out of a sprint (Milestone 17a). Null = the
## shared sprint lunge.
@export var sprint_attack: AttackData
## How long the heavy attack can be charged by holding the button (0 = no charge).
@export var charge_time: float = 0.8
## Ranged weapon (bows): the light attack draws and shoots an arrow.
@export var ranged: bool = false
