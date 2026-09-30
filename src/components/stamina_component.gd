class_name StaminaComponent
extends Node
## Stamina pool for sprinting, dodging, blocking and heavy attacks.

signal stamina_changed(current: float, maximum: float)
## Emitted when stamina hits zero; regen is delayed longer ("exhausted").
signal exhausted

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 28.0
@export var regen_delay: float = 0.7
@export var exhausted_delay: float = 1.6
@export var stats: StatBlock

var current: float = 0.0
var _delay_left: float = 0.0


func _ready() -> void:
	current = max_stamina


func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current < max_stamina:
		var mult := stats.get_mult(Stats.STAMINA_REGEN) if stats else 1.0
		_set_current(current + regen_per_second * mult * delta)


## Cost after the Stats.STAMINA_COST multiplier (heat makes actions pricier).
func effective_cost(amount: float) -> float:
	return amount * (stats.get_mult(Stats.STAMINA_COST) if stats else 1.0)


## Consumes stamina if enough is available. Returns false (and consumes nothing)
## otherwise. `allow_partial` lets an action start with any stamina > 0.
func try_consume(amount: float, allow_partial: bool = false) -> bool:
	var cost := effective_cost(amount)
	if current >= cost or (allow_partial and current > 1.0):
		consume(cost, false)
		return true
	return false


## Unconditional drain (sprinting, blocking). Already-scaled if `apply_cost_mult` false.
func consume(amount: float, apply_cost_mult: bool = true) -> void:
	var cost := effective_cost(amount) if apply_cost_mult else amount
	_set_current(current - cost)
	_delay_left = regen_delay
	if current <= 0.0:
		_delay_left = exhausted_delay
		exhausted.emit()


func has(amount: float) -> bool:
	return current >= effective_cost(amount)


func refill() -> void:
	_delay_left = 0.0
	_set_current(max_stamina)


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_stamina)
	if is_equal_approx(clamped, current):
		current = clamped
		return
	current = clamped
	stamina_changed.emit(current, max_stamina)
