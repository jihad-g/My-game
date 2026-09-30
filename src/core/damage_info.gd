class_name DamageInfo
extends RefCounted
## Everything a receiver needs to resolve a hit.

var amount: float = 0.0
## Damage type id: &"physical", &"fire", &"frost", &"poison", ... (data-driven).
var damage_type: StringName = &"physical"
var source: Node = null
var is_crit: bool = false
## Extra label shown with the damage number ("Backstab", "Exposed", ...).
var tag: String = ""
var knockback: Vector3 = Vector3.ZERO
var poise_damage: float = 0.0
var hit_position: Vector3 = Vector3.ZERO
## Direction the attack travelled (attacker -> target), flattened.
var direction: Vector3 = Vector3.ZERO
## Status effects to apply on hit: Array of [id: StringName, duration: float, params: Dictionary]
var status_effects: Array = []


static func create(p_amount: float, p_source: Node, p_type: StringName = &"physical") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source = p_source
	info.damage_type = p_type
	return info
