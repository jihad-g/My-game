class_name StatusEffects
extends Node
## Timed status effects on a character (player and enemies share this):
## damage over time, slows, stuns, vulnerabilities, buffs and the elemental
## interactions between them (Milestone 7).
##
## Effect ids (data-driven tuning via `params`):
##   harmful
##   &"burn"     fire DoT                                 params: dps
##   &"poison"   stacking DoT (max 3 stacks)              params: dps (per stack)
##   &"bleed"    stacking physical DoT (max 5 stacks)     params: dps (per stack)
##   &"chilled"  40% slow; chilling again (or chilling a wet target) freezes
##   &"frozen"   65% slow; fire hits "Shatter" it for double damage
##   &"stunned"  cannot act (enemies: stagger; player: staggered)
##   &"shocked"  takes 20% more damage from everything
##   &"wet"      can't burn; lightning hits x1.5 ("Conducted"); chill freezes
##   &"weakened" deals 25% less damage
##   &"slowed"   30% slow
##   &"silenced" can't cast (player abilities/spells, enemy projectiles and boss moves)
##   &"taunted"  forced to target the taunter
##   beneficial
##   &"regen"    heals over time                          params: hps
##   &"haste"    +25% movement speed
##
## Interactions (applied automatically):
##   burn on a wet target -> "Steam": no burn, the target dries
##   wet on a burning target -> the fire goes out
##   chilled on a chilled or wet target -> "Deep Freeze": frozen
##   burn on a frozen target -> it thaws (and Enemy.receive_hit shatters it)

signal effect_applied(id: StringName)
signal effect_expired(id: StringName)
## Interaction text ("Steam", "Deep Freeze"...) for floating labels.
signal reaction(text: String)

const DOT_TICK := 1.0
const MAX_STACKS := {&"poison": 3, &"bleed": 5}
const BENEFICIAL: Array[StringName] = [&"regen", &"haste"]
## Display name, colour and two-letter glyph for each effect (HUD and labels).
const INFO := {
	&"burn": ["Burning", Color(1, 0.5, 0.2), "Bu"],
	&"poison": ["Poisoned", Color(0.5, 0.9, 0.3), "Po"],
	&"bleed": ["Bleeding", Color(0.85, 0.15, 0.15), "Bl"],
	&"chilled": ["Chilled", Color(0.7, 0.9, 1.0), "Ch"],
	&"frozen": ["Frozen", Color(0.6, 0.9, 1.0), "Fr"],
	&"stunned": ["Stunned", Color(1, 1, 0.5), "St"],
	&"shocked": ["Shocked", Color(0.75, 0.8, 1.0), "Sh"],
	&"wet": ["Wet", Color(0.4, 0.6, 1.0), "We"],
	&"weakened": ["Weakened", Color(0.7, 0.55, 0.8), "Wk"],
	&"slowed": ["Slowed", Color(0.6, 0.6, 0.65), "Sl"],
	&"silenced": ["Silenced", Color(0.85, 0.6, 1.0), "Si"],
	&"taunted": ["Taunted", Color(1, 0.6, 0.3), "Ta"],
	&"regen": ["Regenerating", Color(0.4, 1.0, 0.5), "Rg"],
	&"haste": ["Hasted", Color(1.0, 0.9, 0.4), "Ha"],
}

@export var health: HealthComponent
## Duration multiplier for harmful effects (Defense perk "Iron Skin").
var duration_mult: float = 1.0
## Effects this character never gets (e.g. golems can't bleed).
var immune: Array[StringName] = []

## id -> {time, stacks, dps, source}
var effects: Dictionary = {}
var _tick := 0.0


static func display_name(id: StringName) -> String:
	return INFO[id][0] if INFO.has(id) else String(id).capitalize()


static func color_of(id: StringName) -> Color:
	return INFO[id][1] if INFO.has(id) else Color.WHITE


static func is_harmful(id: StringName) -> bool:
	return not BENEFICIAL.has(id)


## Applies an effect. Returns false if it didn't take (immune or consumed by an interaction).
func apply(id: StringName, duration: float, params: Dictionary = {}) -> bool:
	if immune.has(id) or duration <= 0.0:
		return false
	# Elemental interactions first.
	match id:
		&"burn":
			if has(&"wet"):
				remove(&"wet")
				reaction.emit("Steam")
				return false
			if has(&"frozen"):
				remove(&"frozen")
		&"wet":
			if has(&"burn"):
				remove(&"burn")
				reaction.emit("Doused")
		&"chilled":
			if has(&"chilled") or has(&"wet"):
				remove(&"chilled")
				remove(&"wet")
				reaction.emit("Deep Freeze")
				return apply(&"frozen", minf(duration, 2.5), params)
	if is_harmful(id):
		duration *= duration_mult
	var e: Dictionary = effects.get(id, {"time": 0.0, "stacks": 0, "dps": 0.0, "source": null})
	e.time = maxf(e.time, duration)
	e.stacks = mini(e.stacks + 1, int(params.get("max_stacks", MAX_STACKS[id]))) if MAX_STACKS.has(id) else 1
	e.dps = float(params.get("dps", params.get("hps", e.dps)))
	e.source = params.get("source", e.source)
	effects[id] = e
	effect_applied.emit(id)
	return true


func has(id: StringName) -> bool:
	return effects.has(id)


func remove(id: StringName) -> void:
	if effects.erase(id):
		effect_expired.emit(id)


## Removes every harmful effect (Healing Light, purifying potions). Returns how many.
func cleanse(only: Array = []) -> int:
	var n := 0
	for id: StringName in effects.keys():
		if is_harmful(id) and (only.is_empty() or only.has(id)):
			remove(id)
			n += 1
	return n


func stacks(id: StringName) -> int:
	return int(effects[id].stacks) if effects.has(id) else 0


func time_left(id: StringName) -> float:
	return float(effects[id].time) if effects.has(id) else 0.0


func speed_mult() -> float:
	if has(&"stunned"):
		return 0.0
	var m := 1.0
	if has(&"frozen"):
		m = 0.35
	elif has(&"chilled"):
		m = 0.6
	if has(&"slowed"):
		m *= 0.7
	if has(&"haste"):
		m *= 1.25
	return m


func is_stunned() -> bool:
	return has(&"stunned")


func is_silenced() -> bool:
	return has(&"silenced")


## Multiplier on damage this character deals.
func outgoing_mult() -> float:
	return 0.75 if has(&"weakened") else 1.0


## Multiplier on damage this character takes, by damage type. Sets `tag` text via the returned array.
func incoming(damage_type: StringName) -> Array:
	var m := 1.0
	var tag := ""
	if has(&"shocked"):
		m *= 1.2
	if damage_type == &"lightning" and has(&"wet"):
		m *= 1.5
		tag = "Conducted"
	return [m, tag]


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
		if not effects.has(id):
			continue
		var e: Dictionary = effects[id]
		e.time -= delta
		if do_tick and health and not health.is_dead and e.dps > 0.0:
			if id == &"regen":
				health.heal(e.dps)
			else:
				var type: StringName = {&"burn": &"fire", &"bleed": &"physical"}.get(id, id)
				var info := DamageInfo.create(e.dps * e.stacks, e.source, type)
				info.tag = {&"burn": "Burn", &"poison": "Poison x%d" % e.stacks, &"bleed": "Bleed x%d" % e.stacks}.get(id, "")
				# DoT ignores armor (it already got through once).
				info.set_meta(&"dot", true)
				health.apply_damage(info)
		if e.time <= 0.0:
			effects.erase(id)
			effect_expired.emit(id)
