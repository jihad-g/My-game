class_name Reputation
extends RefCounted
## The player's standing with every settlement and kingdom (Milestone 5).
##
## Points per settlement id; a kingdom's standing is stored under its capital's id.
## Gains in a village also give half as much standing with its kingdom.
## Tiers: Stranger 0, Acquainted 10, Friendly 30, Honored 60, Revered 100.
## Effects: shop discount / sell bonus, better stock, and kingdom titles and gifts.

signal changed(target_id: String, value: float)

const TIERS := [0.0, 10.0, 30.0, 60.0, 100.0]
const TIER_NAMES := ["Stranger", "Acquainted", "Friendly", "Honored", "Revered"]
const DISCOUNTS := [0.0, 0.03, 0.06, 0.1, 0.15]
const MAX := 150.0
const KINGDOM_SHARE := 0.5
## Kingdom titles by tier (granted by the capital's noble).
const TITLES := ["", "", "Friend of %s", "Knight of %s", "Champion of %s"]

var points: Dictionary = {}  # id -> float
## Kingdom id -> highest title tier granted.
var titles: Dictionary = {}
## Trading turnover not yet converted to reputation, per settlement.
var _trade_carry: Dictionary = {}


func get_points(id: String) -> float:
	return float(points.get(id, 0.0))


static func tier_of(value: float) -> int:
	var t := 0
	for i in TIERS.size():
		if value >= TIERS[i]:
			t = i
	return t


func tier(id: String) -> int:
	return tier_of(get_points(id))


func tier_name(id: String) -> String:
	return TIER_NAMES[tier(id)]


## Adds standing with a settlement (and half of it with its kingdom).
func add(info: SettlementInfo, amount: float) -> void:
	if info == null or amount == 0.0:
		return
	_add_raw(info.id, amount)
	if info.kingdom_id != "" and info.kingdom_id != info.id:
		_add_raw(info.kingdom_id, amount * KINGDOM_SHARE)


func _add_raw(id: String, amount: float) -> void:
	var v := clampf(get_points(id) + amount, 0.0, MAX)
	points[id] = v
	changed.emit(id, v)
	Events.reputation_changed.emit(id, v)


## Trading: +1 standing per 50 copper of business.
func on_trade(info: SettlementInfo, copper: int) -> void:
	var carry := float(_trade_carry.get(info.id, 0.0)) + copper / 50.0
	var whole := floorf(carry)
	_trade_carry[info.id] = carry - whole
	if whole > 0.0:
		add(info, whole)


func title_for(kingdom_id: String, kingdom_name: String) -> String:
	var t := int(titles.get(kingdom_id, 0))
	return TITLES[t] % kingdom_name if t >= 2 else ""


## Highest title across kingdoms (for the character screen).
func best_title(settlements: Settlements) -> String:
	var best := ""
	var best_t := 1
	for k in titles:
		if int(titles[k]) > best_t and settlements:
			var s := settlements.find(k)
			if s:
				best_t = int(titles[k])
				best = TITLES[best_t] % s.kingdom_name
	return best


func to_save() -> Dictionary:
	return {"points": points.duplicate(), "titles": titles.duplicate(), "carry": _trade_carry.duplicate()}


func from_save(d: Dictionary) -> void:
	points.clear()
	titles.clear()
	_trade_carry.clear()
	for k in d.get("points", {}):
		points[String(k)] = float(d.points[k])
	for k in d.get("titles", {}):
		titles[String(k)] = int(d.titles[k])
	for k in d.get("carry", {}):
		_trade_carry[String(k)] = float(d.carry[k])
