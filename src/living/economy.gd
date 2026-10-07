class_name Economy
## Prices, regional supply & demand, shop stock tables and shop state rules.
##
## Money is counted in copper: 100 copper = 1 silver, 100 silver = 1 gold.
## Buy price  = base value x regional demand x 1.35 x (1 - reputation discount) x scarcity
## Sell price = base value x regional demand x 0.45 x (1 + reputation bonus) x saturation
## Buying is always dearer than selling back, so there is no buy/sell loop.
## Saturation: every unit you sell to a shop lowers what it pays for that item by
## 6% (down to 40%); it recovers by half each day. Shops restock and get new money daily.

const BUY_MARKUP := 1.35
const SELL_RATE := 0.45
const SATURATION_STEP := 0.06
const MIN_SATURATION := 0.4

## Stock entries: [item_id, quantity, minimum reputation tier].
const STOCK := {
	&"merchant": [
		[&"berries", 10, 0], [&"cooked_meat", 6, 0], [&"bread", 6, 0], [&"bandage", 6, 0], [&"rope", 10, 0],
		[&"plank", 20, 0], [&"plant_fiber", 20, 0], [&"campfire_kit", 3, 0], [&"stone_hatchet", 1, 0],
		[&"stone_pickaxe", 1, 0], [&"wheat_seeds", 8, 0], [&"carrot_seeds", 8, 0], [&"sun_hat", 1, 0],
		[&"padded_vest", 1, 0], [&"leather", 4, 1], [&"hearty_stew", 3, 2], [&"cooks_journal", 1, 2],
		[&"shadow_hood", 1, 0], [&"wizard_hat", 1, 0], [&"raider_boots", 1, 1],
		[&"wooden_shortbow", 1, 0], [&"wooden_arrow", 20, 0], [&"tome_light", 1, 0], [&"tome_haste", 1, 1],
	],
	&"blacksmith": [
		[&"flint_knife", 1, 0], [&"rough_handaxe", 1, 0], [&"stone_pickaxe", 2, 0], [&"stone_hatchet", 2, 0],
		[&"copper_ingot", 6, 0], [&"coal", 10, 0], [&"copper_dagger", 1, 0], [&"copper_sword", 1, 0],
		[&"copper_pickaxe", 1, 1], [&"copper_hatchet", 1, 1], [&"wooden_buckler", 1, 0], [&"iron_ingot", 4, 2],
		[&"iron_sword", 1, 2], [&"iron_waraxe", 1, 2], [&"iron_kite_shield", 1, 2], [&"iron_pickaxe", 1, 3],
		[&"chainmail", 1, 3], [&"smithing_manual", 1, 2], [&"squire_helm", 1, 0], [&"squire_gauntlets", 1, 1],
		# Milestone 17a: new weapons and arrows.
		[&"wooden_arrow", 30, 0], [&"ash_spear", 1, 0], [&"stone_maul", 1, 0], [&"copper_waraxe", 1, 1],
		[&"copper_arrow", 20, 1], [&"recurve_bow", 1, 2], [&"iron_arrow", 20, 2], [&"weaponsmith_folio", 1, 2],
		[&"iron_pike", 1, 2], [&"iron_greatsword", 1, 3], [&"iron_warhammer", 1, 3],
	],
	&"farmer": [
		[&"wheat_seeds", 10, 0], [&"carrot_seeds", 10, 0], [&"pumpkin_seeds", 5, 0], [&"wheat", 12, 0],
		[&"carrot", 10, 0], [&"pumpkin", 3, 0], [&"berries", 8, 0], [&"bread", 4, 1],
	],
	&"royal_merchant": [
		[&"bread", 10, 0], [&"hearty_stew", 5, 0], [&"leather", 8, 0], [&"iron_ingot", 6, 1], [&"fur_cap", 1, 1],
		[&"fur_boots", 1, 1], [&"leather_jerkin", 1, 1], [&"leatherworker_notes", 1, 1], [&"crystal_shard", 3, 2],
		[&"arcane_dust", 6, 2], [&"crystal_ring", 1, 3], [&"arcane_codex", 1, 3], [&"moonpetal", 2, 3],
		[&"shadow_cloak", 1, 4], [&"moonpetal_pendant", 1, 4], [&"crystal_staff", 1, 3],
		[&"horned_helm", 1, 0], [&"shadow_garb", 1, 1], [&"apprentice_wraps", 1, 1], [&"squire_plate", 1, 2],
		[&"apprentice_wand", 1, 0], [&"copper_staff", 1, 0], [&"iron_staff", 1, 2], [&"embers_tome", 1, 3],
		[&"master_weaponsmith_folio", 1, 3], [&"mithril_arrow", 20, 4], [&"tome_feather_fall", 1, 1], [&"tome_silence", 1, 3],
	],
}

## The travelling trader carries a rotating selection from this pool.
const TRADER_POOL := [
	[&"coconut", 5], [&"cactus_fruit", 5], [&"frostberries", 6], [&"glowcap", 4], [&"moonpetal", 1],
	[&"crystal_shard", 2], [&"cooks_journal", 1], [&"leatherworker_notes", 1], [&"arcane_dust", 4],
	[&"boar_tusk", 3], [&"pumpkin_seeds", 6], [&"tusk_charm", 1], [&"copper_ring", 1], [&"hearty_stew", 3],
	[&"cooling_salad", 4], [&"smithing_manual", 1], [&"fire_arrow", 15], [&"weaponsmith_folio", 1],
]
const TRADER_MARKUP := 1.25

## Which item categories each shopkeeper buys from you.
const BUYS := {
	&"merchant": [ItemData.Category.MATERIAL, ItemData.Category.FOOD, ItemData.Category.TOOL, ItemData.Category.PLACEABLE, ItemData.Category.ARMOR],
	&"blacksmith": [ItemData.Category.MATERIAL, ItemData.Category.TOOL, ItemData.Category.WEAPON, ItemData.Category.ARMOR],
	&"farmer": [ItemData.Category.FOOD, ItemData.Category.MATERIAL],
	&"royal_merchant": [ItemData.Category.MATERIAL, ItemData.Category.FOOD, ItemData.Category.TOOL, ItemData.Category.WEAPON,
		ItemData.Category.ARMOR, ItemData.Category.MISC, ItemData.Category.PLACEABLE],
	&"trader": [ItemData.Category.MATERIAL, ItemData.Category.FOOD, ItemData.Category.WEAPON, ItemData.Category.ARMOR,
		ItemData.Category.MISC, ItemData.Category.TOOL],
}
## Farmers only buy produce-type materials.
const FARMER_MATERIALS := [&"plant_fiber", &"wheat_seeds", &"carrot_seeds", &"pumpkin_seeds", &"pumpkin", &"wheat", &"mushroom"]
const SMITH_MATERIALS := [&"copper_ore", &"iron_ore", &"coal", &"copper_ingot", &"iron_ingot", &"stone", &"flint", &"crystal_shard"]

## Daily shop money in copper (villages / kingdoms).
const SHOP_MONEY := {&"merchant": [300, 1000], &"blacksmith": [400, 1500], &"farmer": [150, 400],
	&"royal_merchant": [0, 3000], &"trader": [800, 800]}

## Regional supply (< 1, cheap) and demand (> 1, dear) by biome.
const REGION := {
	&"verdant_meadow": {&"cheap": [&"wheat", &"bread", &"berries", &"carrot"], &"dear": [&"iron_ore", &"iron_ingot", &"crystal_shard"]},
	&"whispering_forest": {&"cheap": [&"wood", &"plank", &"stick", &"mushroom"], &"dear": [&"iron_ingot", &"coal", &"stone"]},
	&"emerald_jungle": {&"cheap": [&"wood", &"plant_fiber", &"rope", &"berries"], &"dear": [&"copper_ingot", &"iron_ingot", &"bread"]},
	&"frostpine_taiga": {&"cheap": [&"wood", &"boar_hide", &"leather"], &"dear": [&"bread", &"cooked_meat", &"hearty_stew", &"fur_cap", &"fur_boots"]},
	&"snowy_tundra": {&"cheap": [&"frostberries", &"stone"], &"dear": [&"wood", &"cooked_meat", &"hearty_stew", &"campfire_kit", &"fur_cap", &"fur_boots", &"leather"]},
	&"sunscorch_desert": {&"cheap": [&"cactus_fruit", &"coconut", &"clay", &"stone"], &"dear": [&"wood", &"plank", &"berries", &"cooling_salad", &"sun_hat"]},
	&"murk_swamp": {&"cheap": [&"mushroom", &"plant_fiber", &"clay"], &"dear": [&"stone", &"bread", &"iron_ingot"]},
}
const REGIONAL_CHEAP := 0.7
const REGIONAL_DEAR := 1.3


static func format_coins(copper: int) -> String:
	var g := copper / 10000
	var s := (copper / 100) % 100
	var c := copper % 100
	var parts := PackedStringArray()
	if g > 0:
		parts.append("%dg" % g)
	if s > 0 or g > 0:
		parts.append("%ds" % s)
	parts.append("%dc" % c)
	return " ".join(parts)


## Regional multiplier for an item in a settlement.
static func demand(info: SettlementInfo, item_id: StringName) -> float:
	var m := 1.0
	var r: Dictionary = REGION.get(info.biome_id, {})
	if item_id in r.get(&"cheap", []):
		m *= REGIONAL_CHEAP
	elif item_id in r.get(&"dear", []):
		m *= REGIONAL_DEAR
	var item: ItemData = ItemDB.get_item(item_id)
	if info.is_kingdom() and item and item.category in [ItemData.Category.WEAPON, ItemData.Category.ARMOR]:
		m *= 1.15  # the capital's nobles pay for fine gear
	return m


static func buy_price(info: SettlementInfo, item_id: StringName, rep_tier: int, role: StringName = &"merchant") -> int:
	var item: ItemData = ItemDB.get_item(item_id)
	if item == null:
		return 0
	var p: float = maxf(1.0, item.base_value) * demand(info, item_id) * BUY_MARKUP * (1.0 - Reputation.DISCOUNTS[rep_tier])
	if role == &"trader":
		p *= TRADER_MARKUP
	return maxi(1, ceili(p))


static func sell_price(info: SettlementInfo, item_id: StringName, rep_tier: int, saturation_count: float) -> int:
	var item: ItemData = ItemDB.get_item(item_id)
	if item == null:
		return 0
	var sat := maxf(MIN_SATURATION, 1.0 - SATURATION_STEP * saturation_count)
	var p: float = float(item.base_value) * demand(info, item_id) * SELL_RATE * (1.0 + Reputation.DISCOUNTS[rep_tier]) * sat
	return maxi(0, floori(p))


static func will_buy(role: StringName, item_id: StringName) -> bool:
	var item: ItemData = ItemDB.get_item(item_id)
	if item == null or item.base_value <= 0:
		return false
	if not item.category in BUYS.get(role, []):
		return false
	if role == &"farmer" and item.category == ItemData.Category.MATERIAL:
		return item_id in FARMER_MATERIALS
	if role == &"blacksmith" and item.category == ItemData.Category.MATERIAL:
		return item_id in SMITH_MATERIALS
	return true


## Fresh daily state of a shop: stock, money, what you've sold recently.
static func new_shop_state(info: SettlementInfo, role: StringName, day: int) -> Dictionary:
	var stock := {}
	if role == &"trader":
		var n := TRADER_POOL.size()
		for k in 7:
			var e: Array = TRADER_POOL[HashUtils.hash3(info.seed, day, 300 + k) % n]
			stock[String(e[0])] = int(stock.get(String(e[0]), 0)) + int(e[1])
	else:
		for e in STOCK.get(role, []):
			var qty := int(e[1])
			if info.is_kingdom():
				qty = ceili(qty * 1.5)
			stock[String(e[0])] = qty
	var money: Array = SHOP_MONEY.get(role, [200, 800])
	return {"day": day, "stock": stock, "money": int(money[1] if info.is_kingdom() else money[0]), "sold": {}}


## Restocks a shop state for a new day (saturation recovers by half per day).
static func roll_day(state: Dictionary, info: SettlementInfo, role: StringName, day: int) -> Dictionary:
	if int(state.get("day", -1)) == day:
		return state
	var days := day - int(state.get("day", day))
	var fresh := new_shop_state(info, role, day)
	var sold: Dictionary = state.get("sold", {})
	for k in sold.keys():
		var v := float(sold[k]) * pow(0.5, maxi(days, 1))
		if v >= 0.25:
			fresh.sold[k] = v
	return fresh


## Minimum reputation tier for a stock item (trader: none).
static func required_tier(role: StringName, item_id: StringName) -> int:
	for e in STOCK.get(role, []):
		if e[0] == item_id:
			return int(e[2])
	return 0
