class_name SettlementManager
extends Node3D
## Runs the living world (Milestone 5):
## - streams SettlementSites in/out around the player (surface only),
## - discovery of settlements, "current settlement" for the HUD,
## - shop state (stock, money, saturation), buying & selling,
## - notice-board requests (deliveries, hunts),
## - saving all of it (reputation and coins live on the player).

const SPAWN_RANGE := 170.0
const DESPAWN_RANGE := 230.0
const ENTER_MARGIN := 6.0

var world: World
var sites: Dictionary = {}          # id -> SettlementSite
var shops: Dictionary = {}          # "<id>|<role>" -> state
var completed: Dictionary = {}      # request id -> true
var hunt_progress: Dictionary = {}  # request id -> kills
var current: SettlementInfo

var _tick := 0.0
var _trader_tick := 0.0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


func settlements() -> Settlements:
	return world.generator.settlements


func _day() -> int:
	return world.day_night.day if world.day_night else 1


func _process(delta: float) -> void:
	if world == null or world.player == null or not world.is_ready:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.4
	update_now()
	_trader_tick -= 0.4
	if _trader_tick <= 0.0:
		_trader_tick = 5.0
		for id in sites:
			sites[id].refresh_trader()


## Streams sites and updates the current settlement (also used by tests).
func update_now(spawn_all: bool = false) -> void:
	var p := world.player.global_position
	if world.layer != TerrainGenerator.Layer.SURFACE or world.dungeon != null:
		for id in sites.keys():
			_free_site(id)
		_set_current(null)
		return
	var near := settlements().near(p, SPAWN_RANGE)
	var spawned := 0
	for s in near:
		if not sites.has(s.id) and (spawn_all or spawned == 0):
			_spawn_site(s)
			spawned += 1
	for id in sites.keys():
		var site: SettlementSite = sites[id]
		if site.info.distance_to(p) > DESPAWN_RANGE:
			_free_site(id)
	var inside: SettlementInfo = null
	for s in near:
		if s.contains(p, ENTER_MARGIN):
			inside = s
			break
	_set_current(inside)


func _spawn_site(s: SettlementInfo) -> void:
	var site := SettlementSite.new()
	site.setup(s, self, _day())
	add_child(site)
	sites[s.id] = site


func _free_site(id: String) -> void:
	var site: SettlementSite = sites[id]
	sites.erase(id)
	site.queue_free()


func _set_current(s: SettlementInfo) -> void:
	if s == current:
		return
	if current:
		Events.settlement_left.emit(current.id)
	current = s
	if s == null:
		return
	if GameState.discover_place("settlement:%s" % s.id):
		Events.place_discovered.emit("settlement:%s" % s.id)
		world.player.reputation.add(s, 2.0)
		var extra := "" if s.kingdom_name == "" or s.is_kingdom() else " · Kingdom of %s" % s.kingdom_name
		Events.toast.emit("Discovered: %s%s" % [s.title(), extra], UITheme.GOLD)
	Events.settlement_entered.emit(s.id)


func is_discovered(id: String) -> bool:
	return GameState.discovered_places.has("settlement:%s" % id)


func site_of(info: SettlementInfo) -> SettlementSite:
	return sites.get(info.id)


## Finishes building every streamed-in site immediately (tests, teleports).
func finish_sites() -> void:
	for id in sites:
		sites[id].finish_now()


# --- Shops ---------------------------------------------------------------------------------

func shop_key(info: SettlementInfo, role: StringName) -> String:
	return "%s|%s" % [info.id, role]


func shop_state(info: SettlementInfo, role: StringName) -> Dictionary:
	var key := shop_key(info, role)
	var st: Dictionary = shops.get(key, {})
	if st.is_empty():
		st = Economy.new_shop_state(info, role, _day())
	else:
		st = Economy.roll_day(st, info, role, _day())
	shops[key] = st
	return st


func rep_tier(info: SettlementInfo) -> int:
	# Kingdom members also benefit from their standing with the crown.
	var t := world.player.reputation.tier(info.id)
	if info.kingdom_id != "" and info.kingdom_id != info.id:
		t = maxi(t, world.player.reputation.tier(info.kingdom_id) - 1)
	return t


func buy_price(info: SettlementInfo, role: StringName, item_id: StringName) -> int:
	return Economy.buy_price(info, item_id, rep_tier(info), role)


func sell_price(info: SettlementInfo, role: StringName, item_id: StringName) -> int:
	var st := shop_state(info, role)
	return Economy.sell_price(info, item_id, rep_tier(info), float(st.sold.get(String(item_id), 0.0)))


## "" on success, otherwise why not.
func buy(info: SettlementInfo, role: StringName, item_id: StringName, count: int = 1) -> String:
	var st := shop_state(info, role)
	var have := int(st.stock.get(String(item_id), 0))
	if have < count:
		return "Out of stock"
	if role != &"trader" and rep_tier(info) < Economy.required_tier(role, item_id):
		return "Requires %s reputation" % Reputation.TIER_NAMES[Economy.required_tier(role, item_id)]
	var price := buy_price(info, role, item_id) * count
	var player := world.player
	if player.coins < price:
		return "Not enough coins"
	player.coins -= price
	player.give_or_drop(item_id, count)
	st.stock[String(item_id)] = have - count
	st.money = int(st.money) + price
	player.reputation.on_trade(info, price)
	Events.coins_changed.emit(player.coins)
	Events.trade_done.emit(info.id, price)
	return ""


## Sells `count` items from an inventory slot. "" on success.
func sell(info: SettlementInfo, role: StringName, slot: int, count: int = 1) -> String:
	var player := world.player
	var s = player.inventory.get_slot(slot)
	if s == null:
		return "Nothing there"
	var item_id: StringName = s.id
	if not Economy.will_buy(role, item_id):
		return "Not interested in that"
	var st := shop_state(info, role)
	count = mini(count, int(s.count))
	var total := 0
	var sold := 0
	for i in count:
		var price := sell_price(info, role, item_id)
		if price <= 0:
			if sold == 0:
				return "Worthless here"
			break
		if int(st.money) < price:
			if sold == 0:
				return "The shop can't afford it today"
			break
		player.inventory.remove_from_slot(slot, 1)
		st.money = int(st.money) - price
		st.sold[String(item_id)] = float(st.sold.get(String(item_id), 0.0)) + 1.0
		st.stock[String(item_id)] = int(st.stock.get(String(item_id), 0)) + 1
		total += price
		sold += 1
	player.coins += total
	player.reputation.on_trade(info, total)
	Events.coins_changed.emit(player.coins)
	Events.trade_done.emit(info.id, total)
	return ""


# --- Kingdom titles ---------------------------------------------------------------------------

## Gifts granted with each title tier (2 Friendly, 3 Honored, 4 Revered).
const TITLE_GIFTS := {2: {"coins": 100}, 3: {"item": &"royal_signet"}, 4: {"coins": 500}}


## The ruler grants titles you have earned with the kingdom. Returns what they say.
func recognition(info: SettlementInfo) -> String:
	var rep := world.player.reputation
	var kid := info.kingdom_id
	var t := rep.tier(kid)
	var had := int(rep.titles.get(kid, 0))
	if t < 2:
		return "Serve %s first. When the realm counts you a friend, come back to me. (Needs Friendly standing with the kingdom: %d / %d)" % [
			info.kingdom_name, roundi(rep.get_points(kid)), roundi(Reputation.TIERS[2])]
	if had >= t:
		return "You already carry the title %s. Keep serving the realm." % rep.title_for(kid, info.kingdom_name)
	var gifts := PackedStringArray()
	for tt in range(maxi(had + 1, 2), t + 1):
		var g: Dictionary = TITLE_GIFTS.get(tt, {})
		if g.has("coins"):
			world.player.coins += int(g.coins)
			gifts.append(Economy.format_coins(int(g.coins)))
		if g.has("item"):
			world.player.give_or_drop(g.item, 1)
			var d: ItemData = ItemDB.get_item(g.item)
			gifts.append(d.display_name if d else String(g.item))
	rep.titles[kid] = t
	Events.coins_changed.emit(world.player.coins)
	var title := rep.title_for(kid, info.kingdom_name)
	Events.toast.emit("Title granted: %s" % title, UITheme.GOLD)
	return "By my decree, you are named %s! Take these as thanks: %s." % [title, ", ".join(gifts)]


# --- Requests -------------------------------------------------------------------------------

func requests(info: SettlementInfo) -> Array:
	var out := []
	for r in Requests.for_settlement(info, _day()):
		r["done"] = completed.has(r.id)
		r["progress"] = int(hunt_progress.get(r.id, 0)) if r.type == "hunt" else world.player.inventory.count_of(r.item)
		out.append(r)
	return out


## Hands in a request. "" on success.
func complete_request(info: SettlementInfo, r: Dictionary) -> String:
	if completed.has(r.id):
		return "Already done"
	var player := world.player
	if r.type == "deliver":
		if player.inventory.count_of(r.item) < int(r.count):
			return "You don't have enough"
		player.inventory.remove_item(r.item, int(r.count))
	elif int(hunt_progress.get(r.id, 0)) < int(r.count):
		return "Not done yet"
	completed[r.id] = true
	player.coins += int(r.reward)
	player.reputation.add(info, float(r.rep))
	player.character.grant_xp(20 + int(r.reward) / 4, Progression.Source.QUEST)
	Events.coins_changed.emit(player.coins)
	Events.toast.emit("Request done: +%s, +%d reputation" % [Economy.format_coins(int(r.reward)), roundi(float(r.rep))], UITheme.GOLD)
	return ""


func _on_enemy_killed(enemy: Node, _id: StringName, pos: Vector3) -> void:
	if world == null or enemy.get_meta(&"killed_by_npc", false):
		return
	for s in settlements().near(pos, Requests.HUNT_RANGE):
		for r in Requests.for_settlement(s, _day()):
			if r.type == "hunt" and not completed.has(r.id):
				hunt_progress[r.id] = int(hunt_progress.get(r.id, 0)) + 1
				if int(hunt_progress[r.id]) == int(r.count):
					Events.toast.emit("%s's hunt request is complete: claim it at the notice board" % s.name, UITheme.GOLD)
		# Protecting a town's surroundings earns a little goodwill.
		if s.distance_to(pos) < 120.0:
			world.player.reputation.add(s, 0.5)


# --- Save --------------------------------------------------------------------------------------

func to_save() -> Dictionary:
	# Old request data is useless: keep only recent days.
	var day := _day()
	var done := {}
	for k in completed:
		if _request_day(k) >= day - 2:
			done[k] = true
	var hunts := {}
	for k in hunt_progress:
		if _request_day(k) >= day - 2:
			hunts[k] = hunt_progress[k]
	return {"shops": shops.duplicate(true), "completed": done, "hunts": hunts}


static func _request_day(req_id: String) -> int:
	var parts := req_id.split(":")
	return int(parts[2]) if parts.size() > 2 else 0


func from_save(d: Dictionary) -> void:
	shops = d.get("shops", {}).duplicate(true)
	completed = d.get("completed", {}).duplicate()
	hunt_progress = d.get("hunts", {}).duplicate()
