class_name HealthComponent
extends Node
## Hit points, damage resolution, resistances and regeneration.

signal health_changed(current: float, maximum: float)
## Emitted after damage is applied; `dealt` is the final amount after resistances.
signal damaged(info: DamageInfo, dealt: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
## Health regenerated per second (scaled by Stats.HEALTH_REGEN).
@export var regen_per_second: float = 0.0
## Seconds after taking damage before regeneration resumes.
@export var regen_delay: float = 6.0
## Damage type -> multiplier. >1 = weakness, <1 = resistance, 0 = immune.
@export var damage_multipliers: Dictionary = {}
@export var stats: StatBlock

var current: float = 0.0
var is_dead: bool = false
## While true all incoming damage is ignored (dodge i-frames, cutscenes...).
var invulnerable: bool = false
var _time_since_damage: float = 999.0


func _ready() -> void:
	current = max_health


func _process(delta: float) -> void:
	_time_since_damage += delta
	if is_dead or regen_per_second <= 0.0 or current >= max_health:
		return
	if _time_since_damage < regen_delay:
		return
	var mult := stats.get_mult(Stats.HEALTH_REGEN) if stats else 1.0
	if mult > 0.0:
		_set_current(current + regen_per_second * mult * delta)


## Applies damage after resistances. Returns the damage actually dealt.
func apply_damage(info: DamageInfo) -> float:
	if is_dead or invulnerable or info.amount <= 0.0:
		return 0.0
	var mult := float(damage_multipliers.get(info.damage_type, 1.0))
	var dealt := info.amount * mult
	if dealt <= 0.0:
		return 0.0
	_time_since_damage = 0.0
	_set_current(current - dealt)
	damaged.emit(info, dealt)
	if current <= 0.0:
		is_dead = true
		died.emit()
	return dealt


## Direct damage without a DamageInfo (starvation, falling, ...).
func apply_raw_damage(amount: float, type: StringName = &"true") -> float:
	return apply_damage(DamageInfo.create(amount, null, type))


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var before := current
	_set_current(current + amount)
	if current > before:
		healed.emit(current - before)


func revive(fraction: float = 1.0) -> void:
	is_dead = false
	_time_since_damage = 999.0
	_set_current(max_health * clampf(fraction, 0.01, 1.0))


func reset_full() -> void:
	revive(1.0)


func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_health)
	if is_equal_approx(clamped, current):
		current = clamped
		return
	current = clamped
	health_changed.emit(current, max_health)
