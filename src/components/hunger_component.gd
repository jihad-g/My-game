class_name HungerComponent
extends Node
## Hunger (fullness) meter. 100 = full, 0 = starving.
##
## Hunger drains over time (faster when active or cold) and applies stat
## modifiers per hunger state. At 0, starvation slowly damages health.
## (Unlike temperature, starvation CAN kill - it is the classic survival stake.)

signal hunger_changed(current: float, maximum: float)
signal state_changed(state: int)

enum State { WELL_FED, SATED, HUNGRY, STARVING }

const STATE_NAMES := {
	State.WELL_FED: "Well fed",
	State.SATED: "Sated",
	State.HUNGRY: "Hungry",
	State.STARVING: "Starving",
}

## Stat modifiers applied per state (data-driven; tweak freely).
const STATE_MODIFIERS := {
	State.WELL_FED: {Stats.HEALTH_REGEN: 1.5},
	State.SATED: {},
	State.HUNGRY: {Stats.STAMINA_REGEN: 0.8, Stats.HEALTH_REGEN: 0.5},
	State.STARVING: {Stats.STAMINA_REGEN: 0.55, Stats.HEALTH_REGEN: 0.0, Stats.ATTACK_DAMAGE: 0.85, Stats.MOVE_SPEED: 0.9},
}

@export var max_hunger: float = 100.0
## Base drain per second. 100 / 0.055 ~= 30 real minutes from full to empty.
@export var drain_per_second: float = 0.055
@export var starvation_damage_per_second: float = 0.5
@export var stats: StatBlock
@export var health: HealthComponent

var current: float = 0.0
var state: State = State.SATED
## Extra drain multiplier from activity (sprinting sets this); reset by owner.
var activity_multiplier: float = 1.0


func _ready() -> void:
	current = max_hunger * 0.8
	_update_state(true)


func _process(delta: float) -> void:
	var rate := drain_per_second * activity_multiplier
	if stats:
		rate *= stats.get_mult(Stats.HUNGER_RATE)
	_set_current(current - rate * delta)
	if current <= 0.0 and health and not health.is_dead:
		health.apply_raw_damage(starvation_damage_per_second * delta, &"starvation")


func eat(amount: float) -> void:
	_set_current(current + amount)


func get_ratio() -> float:
	return current / max_hunger


func state_name() -> String:
	return STATE_NAMES[state]


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_hunger)
	if is_equal_approx(clamped, current):
		current = clamped
		return
	current = clamped
	hunger_changed.emit(current, max_hunger)
	_update_state()


func _update_state(force: bool = false) -> void:
	var ratio := get_ratio()
	var new_state: State
	if ratio >= 0.8:
		new_state = State.WELL_FED
	elif ratio >= 0.3:
		new_state = State.SATED
	elif ratio > 0.0:
		new_state = State.HUNGRY
	else:
		new_state = State.STARVING
	if new_state == state and not force:
		return
	state = new_state
	if stats:
		stats.set_source(&"hunger", STATE_MODIFIERS[state])
	state_changed.emit(state)
