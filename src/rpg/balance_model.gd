class_name BalanceModel
## Numbers behind the balance pass (Milestone 12). Pure calculations from the
## game's own data and formulas - shared by tools/balance_report.gd (which
## writes docs/BALANCE.md) and the balance tests, so the documented numbers and
## the enforced limits can never drift apart.
##
## Model of a "typical" character: skill points spent by a class build plan,
## the best gear the level allows (from data/items), the class's moveset; fights
## against a level-appropriate reference monster (Skeleton Warrior scaled by
## dungeon rank) without dodging or blocking. Abilities other than the
## Wizard's Firebolt are left out (they add burst for every class).

const LEVELS := [1, 5, 10, 20, 35, 55, 75, 100]
const CLASSES := [&"barbarian", &"knight", &"wizard", &"assassin"]
## How each class spends its skill points (shares of the total).
const BUILDS := {
	&"barbarian": {Skill.STRENGTH: 0.5, Skill.DEFENSE: 0.35, Skill.DEXTERITY: 0.15},
	&"knight": {Skill.DEFENSE: 0.45, Skill.STRENGTH: 0.4, Skill.DEXTERITY: 0.15},
	&"wizard": {Skill.MANA_CONTROL: 0.6, Skill.DEFENSE: 0.25, Skill.DEXTERITY: 0.15},
	&"assassin": {Skill.DEXTERITY: 0.5, Skill.STRENGTH: 0.3, Skill.DEFENSE: 0.2},
}
## Seconds between attack strings when fighting for real (moving, reacting).
const COMBAT_IDLE := 0.25
## Fight length used for sustained (mana-limited) spell damage.
const FIGHT := 30.0
const REF_ENEMY := &"skeleton_warrior"


# --- Characters --------------------------------------------------------------------------

## Skill levels of a class's typical build at `level`.
static func build_skills(c: ClassData, level: int) -> Dictionary:
	var skills := {}
	for s in Skill.ALL:
		skills[s] = c.starting_skill(s)
	var points := Progression.total_skill_points_at(level)
	var plan: Dictionary = BUILDS.get(c.id, {})
	var spent := 0
	for s in plan:
		var n := floori(points * float(plan[s]))
		var add := mini(n, Skill.MAX_LEVEL - int(skills[s]))
		skills[s] = int(skills[s]) + add
		spent += add
	# Leftovers (rounding, capped skills) go to Defense, then the rest.
	var left := points - spent
	for s in [Skill.DEFENSE, Skill.STRENGTH, Skill.DEXTERITY, Skill.MANA_CONTROL, Skill.CRAFTING]:
		var add := mini(left, Skill.MAX_LEVEL - int(skills[s]))
		skills[s] = int(skills[s]) + add
		left -= add
	return skills


static func _moveset_dps(ms: WeaponMoveset, flat_bonus: float, attack_speed: float) -> float:
	if ms == null or ms.light_combo.is_empty():
		return 0.0
	var dmg := 0.0
	var t := 0.0
	for a: AttackData in ms.light_combo:
		dmg += a.damage + flat_bonus
		t += (a.windup + a.active + a.recovery) / attack_speed
	return dmg / (t + COMBAT_IDLE)


## The best equipment a class can wear at `level`: slot -> ItemData.
static func best_gear(c: ClassData, level: int, skills: Dictionary) -> Dictionary:
	var gear := {}
	var score := {}
	for id in ItemDB.all_ids():
		var item: ItemData = ItemDB.get_item(id)
		if item == null or not item.is_equippable() or item.required_level > level:
			continue
		var slot := int(item.equip_slot)
		var s := _gear_score(c, item, skills)
		if s > float(score.get(slot, -INF)):
			score[slot] = s
			gear[slot] = item
	return gear


static func _gear_score(c: ClassData, item: ItemData, skills: Dictionary) -> float:
	var b: Dictionary = item.stat_bonuses
	var s := 0.0
	if item.equip_slot == ItemData.EquipSlot.MAIN_HAND:
		var ms: WeaponMoveset = item.moveset if item.moveset else c.unarmed_moveset
		var dex := int(skills.get(Skill.DEXTERITY, 1))
		s = _moveset_dps(ms, float(b.get(&"damage_bonus", 0.0)), Skill.attack_speed_mult(dex, c.efficiency(Skill.DEXTERITY)))
		s *= c.proficiency(item.weapon_type)
		if c.id == &"wizard":
			s = s * 0.2 + float(b.get(&"spell_power", 0.0)) * 3.0 + float(b.get(Skill.MANA_CONTROL, 0.0)) * 2.0
	else:
		s = float(b.get(&"armor", 0.0)) + float(b.get(&"max_health", 0.0)) * 0.4 + float(b.get(&"block", 0.0)) * 0.5
		for sk in Skill.ALL:
			s += float(b.get(sk, 0.0)) * (1.5 if BUILDS.get(c.id, {}).has(sk) else 0.3)
		s += float(b.get(&"spell_power", 0.0)) * (1.0 if c.id == &"wizard" else 0.0)
		s += float(b.get(&"crit_chance", 0.0)) * (1.0 if c.id == &"assassin" else 0.3)
	return s


static func _gear_total(gear: Dictionary, stat: StringName) -> float:
	var t := 0.0
	for slot in gear:
		t += float((gear[slot] as ItemData).stat_bonuses.get(stat, 0.0))
	return t


## Everything about one class at one level.
static func snapshot(class_id: StringName, level: int) -> Dictionary:
	var c := ClassRegistry.get_class_data(class_id)
	var skills := build_skills(c, level)
	var gear := best_gear(c, level, skills)
	var lv := func(s: StringName) -> int: return clampi(int(skills[s]) + int(_gear_total(gear, s)), 1, Skill.MAX_LEVEL)
	var strength: int = lv.call(Skill.STRENGTH)
	var mc: int = lv.call(Skill.MANA_CONTROL)
	var def: int = lv.call(Skill.DEFENSE)
	var dex: int = lv.call(Skill.DEXTERITY)
	var hp := Skill.max_health(def, c.base_health, c.health_per_defense) + _gear_total(gear, &"max_health")
	var armor := c.base_armor + Skill.skill_armor(def, c.efficiency(Skill.DEFENSE)) + _gear_total(gear, &"armor")
	var dr := Skill.damage_reduction(armor)
	var crit := Skill.crit_chance(dex, c.efficiency(Skill.DEXTERITY)) + c.crit_bonus + _gear_total(gear, &"crit_chance") / 100.0
	var crit_mult := Skill.crit_damage_mult(dex)
	var aspd := Skill.attack_speed_mult(dex, c.efficiency(Skill.DEXTERITY)) * (1.0 + _gear_total(gear, &"attack_speed") / 100.0)
	var weapon: ItemData = gear.get(ItemData.EquipSlot.MAIN_HAND)
	var ms: WeaponMoveset = weapon.moveset if weapon and weapon.moveset else c.unarmed_moveset
	var wtype := weapon.weapon_type if weapon else &"unarmed"
	var phys := Skill.physical_damage_mult(strength, c.efficiency(Skill.STRENGTH), c.physical_power)
	var prof := 1.0 if wtype == &"unarmed" else c.proficiency(wtype)
	var crit_avg := 1.0 + clampf(crit, 0.0, 1.0) * (crit_mult - 1.0)
	var melee := _moveset_dps(ms, float(weapon.stat_bonuses.get(&"damage_bonus", 0.0)) if weapon else 0.0, aspd) * phys * prof * crit_avg
	# Firebolt-style spell damage, limited by mana over a 30 s fight.
	var spell := 0.0
	var fb: AbilityData = null
	for a in c.abilities:
		if a is AbilityData and a.id == &"firebolt" and a.unlock_level <= level:
			fb = a
	if fb:
		var sp := Skill.spell_power_mult(mc, c.efficiency(Skill.MANA_CONTROL), c.spell_power) * (1.0 + _gear_total(gear, &"spell_power") / 100.0)
		var mana := Skill.max_mana(mc, c.base_mana, c.mana_per_point) + _gear_total(gear, &"max_mana")
		var regen := Skill.mana_regen(mc, c.efficiency(Skill.MANA_CONTROL)) * (1.0 + _gear_total(gear, &"mana_regen") / 100.0)
		var cost := fb.cost * Skill.mana_cost_mult(mc)
		var casts := minf(FIGHT / (fb.cooldown + 0.3), (mana + regen * FIGHT) / cost)
		spell = casts * fb.damage * sp * crit_avg / FIGHT
	var best := maxf(melee, spell)
	return {"class": class_id, "level": level, "skills": skills, "hp": hp, "armor": armor, "dr": dr, "ehp": hp / (1.0 - dr),
		"melee_dps": melee, "spell_dps": spell, "dps": best, "weapon": String(weapon.id) if weapon else "unarmed",
		"phys_mult": phys, "power": best * hp / (1.0 - dr)}


## Max-Strength physical damage multiplier of a class (Wizard rule).
static func max_strength_phys(class_id: StringName) -> float:
	var c := ClassRegistry.get_class_data(class_id)
	return Skill.physical_damage_mult(Skill.MAX_LEVEL, c.efficiency(Skill.STRENGTH), c.physical_power)


# --- Content -----------------------------------------------------------------------------

## Dungeon rank whose monsters match a player level (0 = E ... 5 = S).
static func rank_for_level(level: int) -> int:
	var base := 4  # reference monster level
	var r := 0
	for i in PoiLayout.RANK_LEVELS.size():
		if base + PoiLayout.RANK_LEVELS[i] <= level + 3:
			r = i
	return r


## Reference monster at a player level: hp, dps, level, xp.
static func reference_enemy(level: int) -> Dictionary:
	var md: MonsterData = load("res://data/enemies/%s.tres" % REF_ENEMY)
	var r := rank_for_level(level)
	var a: AttackData = md.melee
	var cycle := a.windup + a.active + a.recovery + 1.2  # repositioning between swings
	var lvl: int = md.level + int(PoiLayout.RANK_LEVELS[r])
	return {"rank": r, "hp": md.max_health * PoiLayout.RANK_POWER[r], "dps": a.damage * PoiLayout.RANK_DAMAGE[r] / cycle,
		"level": lvl, "xp": Progression.combat_xp(roundi(md.xp_reward * PoiLayout.RANK_XP[r]), lvl, level)}


## Duel numbers for a class at a level: time to kill, time to die, ratio.
static func duel(class_id: StringName, level: int) -> Dictionary:
	var s := snapshot(class_id, level)
	var e := reference_enemy(level)
	var ttk: float = e.hp / maxf(s.dps, 0.01)
	var ttd: float = s.ehp / maxf(e.dps, 0.01)
	return {"ttk": ttk, "ttd": ttd, "ratio": ttd / ttk, "enemy": e, "char": s}


# --- XP pacing ----------------------------------------------------------------------------

## Minutes of play per level when fighting level-appropriate monsters: a kill
## takes the class's time to kill plus 25 s of finding the next target, and
## harvesting/crafting/discovery add 25% on top (from play testing the loop).
static func minutes_per_level(level: int, class_id: StringName = &"knight") -> float:
	var d := duel(class_id, level)
	var per_kill: float = d.ttk + 25.0
	var xp_per_min := float(d.enemy.xp) * 60.0 / per_kill * 1.25
	return Progression.xp_to_next(level) / maxf(xp_per_min, 0.01)


static func hours_to_level(target: int, class_id: StringName = &"knight") -> float:
	var total := 0.0
	for l in range(1, target):
		total += minutes_per_level(l, class_id)
	return total / 60.0


# --- Crafting & economy --------------------------------------------------------------------

## Value of a recipe's inputs (at a Crafting level) and of its output.
static func recipe_value(r: RecipeData, crafting: int) -> Dictionary:
	var cost := r.cost_at(crafting)
	var input := 0.0
	for id in cost:
		var it: ItemData = ItemDB.get_item(id)
		input += float(it.base_value if it else 1) * int(cost[id])
	var out_item: ItemData = ItemDB.get_item(r.result_item)
	var output := float(out_item.base_value if out_item else 0) * r.result_count
	return {"input": input, "output": output, "ratio": output / maxf(input, 0.01)}


## Items any shop or trader sells (only these can be bought for a money machine).
static func buyable() -> Dictionary:
	var out := {}
	for role in Economy.STOCK:
		for e in Economy.STOCK[role]:
			out[e[0]] = true
	for e in Economy.TRADER_POOL:
		out[e[0]] = true
	return out


static func _regional(item: StringName, key: StringName) -> bool:
	for b in Economy.REGION:
		if item in (Economy.REGION[b] as Dictionary).get(key, []):
			return true
	return false


## Best possible margin of buying a recipe's materials in shops and selling the
## result: cheapest region and best reputation when buying, dearest region,
## kingdom and best reputation when selling, master crafting. 0 = some
## ingredient can't be bought. Must stay below 1.0 (no money machines).
static func craft_arbitrage(r: RecipeData) -> float:
	var out_item: ItemData = ItemDB.get_item(r.result_item)
	if out_item == null:
		return 0.0
	var shop := buyable()
	var rep_best: float = Reputation.DISCOUNTS[Reputation.DISCOUNTS.size() - 1]
	var cost := r.cost_at(Skill.MAX_LEVEL)
	var paid := 0.0
	for id in cost:
		if not shop.has(id):
			return 0.0
		var it: ItemData = ItemDB.get_item(id)
		var m: float = (Economy.REGIONAL_CHEAP if _regional(id, &"cheap") else 1.0) * Economy.BUY_MARKUP * (1.0 - rep_best)
		paid += maxf(1.0, float(it.base_value)) * m * int(cost[id])
	var sell: float = Economy.SELL_RATE * (1.0 + rep_best) * (Economy.REGIONAL_DEAR if _regional(r.result_item, &"dear") else 1.0)
	if out_item.category in [ItemData.Category.WEAPON, ItemData.Category.ARMOR]:
		sell *= 1.15
	return float(out_item.base_value) * r.result_count * sell / maxf(paid, 0.01)


## Best margin of buying any shop item in one town and selling it in another.
static func trade_arbitrage() -> float:
	var best := 0.0
	var rep_best: float = Reputation.DISCOUNTS[Reputation.DISCOUNTS.size() - 1]
	for id in buyable():
		var it: ItemData = ItemDB.get_item(id)
		if it == null:
			continue
		var buy: float = (Economy.REGIONAL_CHEAP if _regional(id, &"cheap") else 1.0) * Economy.BUY_MARKUP * (1.0 - rep_best)
		var sell: float = Economy.SELL_RATE * (1.0 + rep_best) * (Economy.REGIONAL_DEAR if _regional(id, &"dear") else 1.0)
		if it.category in [ItemData.Category.WEAPON, ItemData.Category.ARMOR]:
			sell *= 1.15
		best = maxf(best, sell / buy)
	return best
