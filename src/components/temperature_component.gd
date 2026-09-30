class_name TemperatureComponent
extends Node
## Body temperature exposure. NEVER deals damage by design.
##
## The "felt" temperature drifts toward the effective ambient temperature
## (ambient air + heat sources + buffs + insulation). The further it is outside
## the comfort band, the stronger the debuffs: slower movement, weaker attacks,
## worse regeneration, faster hunger, more expensive stamina, slower mana regen.
##
## Countermeasures:
##   - Campfires / heat sources (implemented)
##   - Warm food buffs (implemented: cooked meat)
##   - Time of day and altitude awareness (implemented via ambient)
##   - Clothing/armor insulation (hook: `insulation`, Phase 2 equipment)
##   - Shelter (NOT IMPLEMENTED - Phase 5 building)
##   - Magic temperature shield (NOT IMPLEMENTED - Phase 2 mana)

signal temperature_changed(felt: float, ambient: float)
signal exposure_changed(level: int)

## Exposure level: negative = cold, positive = heat, 0 = comfortable.
enum Exposure { FREEZING = -3, COLD = -2, CHILLY = -1, COMFORTABLE = 0, WARM = 1, HOT = 2, SCORCHING = 3 }

const EXPOSURE_NAMES := {
	-3: "Freezing", -2: "Cold", -1: "Chilly", 0: "Comfortable", 1: "Warm", 2: "Hot", 3: "Scorching",
}

## Thresholds in degrees C (felt temperature).
const COMFORT_MIN := 10.0
const COMFORT_MAX := 26.0
const COLD_THRESHOLD := 0.0
const FREEZING_THRESHOLD := -10.0
const HOT_THRESHOLD := 34.0
const SCORCHING_THRESHOLD := 42.0

## Data-driven debuff table. No entry touches health: temperature cannot kill.
const EXPOSURE_MODIFIERS := {
	-1: {Stats.STAMINA_REGEN: 0.85, Stats.HUNGER_RATE: 1.25},
	-2: {Stats.MOVE_SPEED: 0.9, Stats.STAMINA_REGEN: 0.65, Stats.HEALTH_REGEN: 0.5,
		Stats.HUNGER_RATE: 1.6, Stats.ATTACK_DAMAGE: 0.9, Stats.MANA_REGEN: 0.8},
	-3: {Stats.MOVE_SPEED: 0.75, Stats.STAMINA_REGEN: 0.4, Stats.HEALTH_REGEN: 0.0,
		Stats.HUNGER_RATE: 2.2, Stats.ATTACK_DAMAGE: 0.75, Stats.ATTACK_SPEED: 0.85, Stats.MANA_REGEN: 0.6},
	1: {Stats.STAMINA_REGEN: 0.85, Stats.STAMINA_COST: 1.1},
	2: {Stats.MOVE_SPEED: 0.9, Stats.STAMINA_REGEN: 0.6, Stats.HEALTH_REGEN: 0.5,
		Stats.STAMINA_COST: 1.25, Stats.ATTACK_DAMAGE: 0.9, Stats.MANA_REGEN: 0.8},
	3: {Stats.MOVE_SPEED: 0.8, Stats.STAMINA_REGEN: 0.35, Stats.HEALTH_REGEN: 0.0,
		Stats.STAMINA_COST: 1.5, Stats.ATTACK_DAMAGE: 0.8, Stats.ATTACK_SPEED: 0.9,
		Stats.HUNGER_RATE: 1.3, Stats.MANA_REGEN: 0.6},
}

@export var stats: StatBlock
## Degrees per second the body adapts, plus a proportional term so big
## differences are felt faster.
@export var adapt_rate: float = 0.35
@export var adapt_proportional: float = 0.04

## Returns ambient temperature (air + local heat sources) at the owner position.
var ambient_provider: Callable
## Clothing/armor insulation in degrees: pulls cold temperatures up toward the
## comfort band (Phase 2 equipment writes this). Does nothing against heat.
var insulation: float = 0.0
## Heat protection in degrees (Phase 2): pulls hot temperatures down.
var cooling: float = 0.0

var felt: float = 18.0
var ambient: float = 18.0
var exposure: int = 0
## Active temporary offsets: id -> {offset: float, time_left: float}
var _buffs: Dictionary = {}
var _initialized := false


func _process(delta: float) -> void:
	_tick_buffs(delta)
	if ambient_provider.is_valid():
		ambient = float(ambient_provider.call())
	var target := get_effective_ambient()
	if not _initialized:
		felt = target
		_initialized = true
	var diff := target - felt
	var step := (adapt_rate + absf(diff) * adapt_proportional) * delta
	felt = move_toward(felt, target, step)
	temperature_changed.emit(felt, ambient)
	_update_exposure()


## Ambient adjusted by buffs, insulation and cooling.
func get_effective_ambient() -> float:
	var t := ambient + get_buff_offset()
	if t < COMFORT_MIN:
		t = minf(t + insulation, COMFORT_MIN)
	elif t > COMFORT_MAX:
		t = maxf(t - cooling, COMFORT_MAX)
	return t


## Temporary temperature offset (warm meal = +, cooling drink = -).
func add_buff(id: StringName, offset: float, duration: float) -> void:
	_buffs[id] = {"offset": offset, "time_left": duration}


func get_buff_offset() -> float:
	var total := 0.0
	for id in _buffs:
		total += float(_buffs[id].offset)
	return total


func get_buffs() -> Dictionary:
	return _buffs


func snap_to_ambient() -> void:
	_initialized = false


func exposure_name() -> String:
	return EXPOSURE_NAMES[exposure]


static func exposure_for(temp: float) -> int:
	if temp < FREEZING_THRESHOLD:
		return Exposure.FREEZING
	if temp < COLD_THRESHOLD:
		return Exposure.COLD
	if temp < COMFORT_MIN:
		return Exposure.CHILLY
	if temp > SCORCHING_THRESHOLD:
		return Exposure.SCORCHING
	if temp > HOT_THRESHOLD:
		return Exposure.HOT
	if temp > COMFORT_MAX:
		return Exposure.WARM
	return Exposure.COMFORTABLE


func _tick_buffs(delta: float) -> void:
	for id in _buffs.keys():
		_buffs[id].time_left -= delta
		if _buffs[id].time_left <= 0.0:
			_buffs.erase(id)


func _update_exposure() -> void:
	# Small hysteresis so standing on a threshold doesn't flicker debuffs.
	var candidate := exposure_for(felt)
	if candidate == exposure:
		return
	var toward_comfort := absi(candidate) < absi(exposure)
	if toward_comfort and exposure_for(felt + (-0.5 if exposure < 0 else 0.5)) == exposure:
		return
	exposure = candidate
	if stats:
		stats.set_source(&"temperature", EXPOSURE_MODIFIERS.get(exposure, {}))
	exposure_changed.emit(exposure)
