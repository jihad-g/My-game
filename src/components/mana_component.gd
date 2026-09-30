class_name ManaComponent
extends Node
## Mana pool for spells and magical abilities. Max and regen are set by
## CharacterStats (class + Mana Control + equipment).

signal mana_changed(current: float, maximum: float)

@export var max_mana: float = 30.0
@export var regen_per_second: float = 1.5
## Seconds after spending mana before regeneration resumes.
@export var regen_delay: float = 1.0
@export var stats: StatBlock

var current: float = 0.0
var _delay_left := 0.0


func _ready() -> void:
	current = max_mana


func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current < max_mana:
		var mult := stats.get_mult(Stats.MANA_REGEN) if stats else 1.0
		_set_current(current + regen_per_second * mult * delta)


func has(amount: float) -> bool:
	return current >= amount


func try_spend(amount: float) -> bool:
	if current < amount:
		return false
	_set_current(current - amount)
	_delay_left = regen_delay
	return true


func refill() -> void:
	_set_current(max_mana)


func set_max(value: float) -> void:
	max_mana = maxf(value, 0.0)
	_set_current(minf(current, max_mana), true)


func _set_current(value: float, force_signal: bool = false) -> void:
	var clamped := clampf(value, 0.0, max_mana)
	if is_equal_approx(clamped, current) and not force_signal:
		current = clamped
		return
	current = clamped
	mana_changed.emit(current, max_mana)
