class_name StatusEffects
extends Node
## Timed status effects on a character: damage over time, slows, stuns, taunts.
##
## Effect ids (data-driven tuning via `params`):
##   &"burn"    fire DoT            params: dps
##   &"poison"  stacking DoT (max 3 stacks) params: dps (per stack)
##   &"chilled" 40% slow
##   &"frozen"  65% slow; fire hits "Shatter" it for double damage
##   &"stunned" cannot act (enemies: stagger)
##   &"taunted" forced to target the taunter

signal effect_applied(id: StringName)
signal effect_expired(id: StringName)

const DOT_TICK := 1.0
const MAX_POISON_STACKS := 3

@export var health: HealthComponent
## Duration multiplier for harmful effects (Defense perk "Iron Skin").
var duration_mult: float = 1.0

## id -> {time, stacks, dps, source}
var effects: Dictionary = {}
var _tick := 0.0


func apply(id: StringName, duration: float, params: Dictionary = {}) -> void:
	duration *= duration_mult
	var e: Dictionary = effects.get(id, {"time": 0.0, "stacks": 0, "dps": 0.0, "source": null})
	e.time = maxf(e.time, duration)
	e.stacks = mini(e.stacks + 1, MAX_POISON_STACKS) if id == &"poison" else 1
	e.dps = float(params.get("dps", e.dps))
	e.source = params.get("source", e.source)
	effects[id] = e
	effect_applied.emit(id)


func has(id: StringName) -> bool:
	return effects.has(id)


func remove(id: StringName) -> void:
	if effects.erase(id):
		effect_expired.emit(id)


func stacks(id: StringName) -> int:
	return int(effects[id].stacks) if effects.has(id) else 0


func time_left(id: StringName) -> float:
	return float(effects[id].time) if effects.has(id) else 0.0


func speed_mult() -> float:
	if has(&"stunned"):
		return 0.0
	if has(&"frozen"):
		return 0.35
	if has(&"chilled"):
		return 0.6
	return 1.0


func is_stunned() -> bool:
	return has(&"stunned")


func clear() -> void:
	effects.clear()


func _process(delta: float) -> void:
	if effects.is_empty():
		return
	_tick += delta
	var do_tick := _tick >= DOT_TICK
	if do_tick:
		_tick -= DOT_TICK
	for id: StringName in effects.keys():
		var e: Dictionary = effects[id]
		e.time -= delta
		if do_tick and health and not health.is_dead and e.dps > 0.0:
			var info := DamageInfo.create(e.dps * e.stacks, e.source, &"fire" if id == &"burn" else id)
			info.tag = "Burn" if id == &"burn" else ("Poison x%d" % e.stacks if id == &"poison" else "")
			health.apply_damage(info)
		if e.time <= 0.0:
			effects.erase(id)
			effect_expired.emit(id)
