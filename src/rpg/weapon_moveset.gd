class_name WeaponMoveset
extends Resource
## The attacks a weapon type performs (light combo + heavy attack).

@export var id: StringName
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
