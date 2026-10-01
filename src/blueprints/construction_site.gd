class_name ConstructionSite
extends Node3D
## A blueprint placed in the world (Milestone 8). Every piece not built yet is
## shown as a hologram (blue = ready, red = blocked: a tree, water, a town,
## something already there).
##
## Manual construction: walk up to a hologram and press F to build that piece.
## Automatic construction: switch "auto-build" on and, while you're within
## AUTO_RANGE, the site builds one piece every BUILD_INTERVAL seconds in build
## order (floors, walls, furniture, roofs).
## Both take materials from your inventory first, then from storage chests
## within STORAGE_RANGE of the site. Missing materials pause auto-build.

signal changed

const AUTO_RANGE := 30.0
const STORAGE_RANGE := 18.0
const BUILD_INTERVAL := 0.3
const CHECK_INTERVAL := 1.0

var site_id := ""
var blueprint_name := ""
var anchor := Vector2i.ZERO
var rotation_q := 0
var layer := 0
var auto := false
## Planned pieces in build order: {id, cell: Vector2i, slot, rot, built: bool, reason: String}
var entries: Array = []
## Total pieces in the plan when it was placed (for progress).
var total := 0
## Why auto-build is waiting ("" while building).
var status := ""
var manager: BlueprintManager

var _holos: Dictionary = {}  # entry index -> BlueprintHologram
var _build_t := 0.0
var _check_t := 0.0


func setup(p_manager: BlueprintManager, bp: Blueprint, p_anchor: Vector2i, q: int, p_layer: int) -> void:
	manager = p_manager
	blueprint_name = bp.name
	anchor = p_anchor
	rotation_q = posmod(q, 4)
	layer = p_layer
	for e in bp.rotated(rotation_q).build_order():
		entries.append({"id": StringName(e.id), "cell": anchor + Vector2i(int(e.x), int(e.z)), "slot": String(e.slot),
			"rot": int(e.rot), "built": false, "reason": ""})
	total = entries.size()


func _ready() -> void:
	add_to_group(&"construction_sites")
	refresh()


func world() -> World:
	return manager.world if manager else World.instance


func center() -> Vector3:
	var w := world()
	var sum := Vector2.ZERO
	for e in entries:
		sum += Vector2(e.cell) + Vector2(0.5, 0.5)
	var c := sum / maxf(1.0, entries.size())
	var y := w.generator.get_height_at(Vector3(c.x, 0, c.y), layer) if w else 0.0
	return Vector3(c.x, y, c.y)


func pending_count() -> int:
	var n := 0
	for e in entries:
		if not e.built:
			n += 1
	return n


## Roofs waiting for their walls aren't blocked - they just come last.
static func is_blocking(reason: String) -> bool:
	return reason != "" and not reason.begins_with("Roofs need")


func blocked_count() -> int:
	var n := 0
	for e in entries:
		if not e.built and is_blocking(e.reason):
			n += 1
	return n


func is_complete() -> bool:
	return pending_count() == 0


## Materials still needed for the pieces not built yet: item -> count.
func remaining_cost() -> Dictionary:
	var out := {}
	for e in entries:
		if e.built:
			continue
		var data := BuildingManager.get_piece_data(e.id)
		if data:
			for item in data.cost:
				out[item] = int(out.get(item, 0)) + int(data.cost[item])
	return out


# --- Materials -------------------------------------------------------------------------------

func _chests() -> Array:
	var w := world()
	var out := []
	if w == null:
		return out
	for p in w.building.pieces_near(center(), STORAGE_RANGE):
		if p.storage:
			out.append(p)
	return out


## Item -> count you can build with: your inventory plus chests near the site.
func available() -> Dictionary:
	var out := {}
	var w := world()
	if w == null:
		return out
	for s in w.player.inventory.slots:
		if s != null:
			out[s.id] = int(out.get(s.id, 0)) + int(s.count)
	for c in _chests():
		for s in c.storage.slots:
			if s != null:
				out[s.id] = int(out.get(s.id, 0)) + int(s.count)
	return out


## Takes `cost` (item -> count) from the inventory first, then nearby chests. All or nothing.
func pay(cost: Dictionary) -> bool:
	var have := available()
	for item in cost:
		if int(have.get(item, 0)) < int(cost[item]):
			return false
	var inv := world().player.inventory
	var chests := _chests()
	for item in cost:
		var left := int(cost[item])
		var from_inv := mini(left, inv.count_of(item))
		if from_inv > 0:
			inv.remove_item(item, from_inv)
			left -= from_inv
		for c in chests:
			if left <= 0:
				break
			var n := mini(left, c.storage.count_of(item))
			if n > 0:
				c.storage.remove_item(item, n)
				left -= n
	return true


# --- Building -----------------------------------------------------------------------------------

## Why entry `i` can't be built right now ("" = it can, ignoring materials).
func check_entry(i: int) -> String:
	var w := world()
	var e: Dictionary = entries[i]
	if e.built:
		return ""
	if w == null or w.layer != layer:
		return "Not on this layer"
	var data := BuildingManager.get_piece_data(e.id)
	if data == null:
		return "Unknown piece"
	if w.player.character.level < data.required_level:
		return "Requires level %d" % data.required_level
	return w.building.check_place(data, e.cell, e.slot, null, false)


## Builds entry `i` (paying materials). Returns "" on success or why not.
func build_entry(i: int) -> String:
	var e: Dictionary = entries[i]
	if e.built:
		return "Already built"
	var why := check_entry(i)
	if why != "":
		e.reason = why
		_update_holo(i)
		return why
	var data := BuildingManager.get_piece_data(e.id)
	if not pay(data.cost):
		var m := PackedStringArray()
		var have := available()
		for item in data.cost:
			var short := int(data.cost[item]) - int(have.get(item, 0))
			if short > 0:
				var d: ItemData = ItemDB.get_item(item)
				m.append("%d %s" % [short, d.display_name if d else String(item)])
		return "Missing " + ", ".join(m)
	var piece := world().building.place(data, e.cell, e.slot, e.rot, null, false)
	if piece == null:
		# Shouldn't happen (checked above) - refund.
		for item in data.cost:
			world().player.give_or_drop(item, int(data.cost[item]))
		return "Couldn't build here"
	e.built = true
	e.reason = ""
	Events.item_crafted.emit(data.id, 1)  # building grants a little crafting XP
	VFX.burst(get_parent(), piece.global_position + Vector3(0, 0.8, 0), 0.9, Color(0.5, 0.8, 1.0, 0.5), 0.25)
	_remove_holo(i)
	changed.emit()
	if is_complete():
		Events.toast.emit("%s is finished!" % blueprint_name, UITheme.GOLD)
		if manager:
			manager.finish_site(self)
	return ""


## Index of the next piece auto-build would place (-1 = none can be built).
func next_buildable() -> int:
	for i in entries.size():
		if not entries[i].built and check_entry(i) == "":
			return i
	return -1


func _process(delta: float) -> void:
	var w := world()
	if w == null or not w.is_ready:
		return
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = CHECK_INTERVAL
		refresh()
	if not auto:
		return
	if w.layer != layer or w.player.is_dead or w.player.global_position.distance_to(center()) > AUTO_RANGE:
		status = "Come closer to build (within %d m)" % roundi(AUTO_RANGE)
		return
	_build_t -= delta
	if _build_t > 0.0:
		return
	_build_t = BUILD_INTERVAL
	var i := next_buildable()
	if i < 0:
		status = "%d piece%s blocked" % [blocked_count(), "" if blocked_count() == 1 else "s"] if blocked_count() > 0 else ""
		return
	var why := build_entry(i)
	status = "" if why == "" else why


## Re-checks every pending piece: already built by hand? blocked? Updates holograms.
func refresh() -> void:
	var w := world()
	if w == null:
		return
	var show := w.layer == layer and w.dungeon == null
	for i in entries.size():
		var e: Dictionary = entries[i]
		if e.built:
			continue
		var existing: BuildPiece = w.building.pieces.get(BuildingManager.key(e.cell, e.slot, layer))
		if existing and existing.data.id == e.id:
			e.built = true  # built some other way (build mode, another site)
			_remove_holo(i)
			continue
		e.reason = check_entry(i) if show else ""
		if show:
			_update_holo(i)
	for i in _holos:
		_holos[i].visible = show
	if is_complete() and manager:
		manager.finish_site(self)
	changed.emit()


func _update_holo(i: int) -> void:
	var e: Dictionary = entries[i]
	var h: BlueprintHologram = _holos.get(i)
	if h == null:
		h = BlueprintHologram.new()
		h.site = self
		h.index = i
		add_child(h)
		h.setup(BuildingManager.get_piece_data(e.id))
		_holos[i] = h
	# Recomputed each check: furniture rises onto floors once they are built.
	h.global_transform = world().building.transform_for(h.data, e.cell, e.slot, e.rot)
	h.set_blocked(is_blocking(e.reason))


func _remove_holo(i: int) -> void:
	if _holos.has(i):
		_holos[i].queue_free()
		_holos.erase(i)


func cancel() -> void:
	for i in _holos:
		_holos[i].queue_free()
	_holos.clear()
	queue_free()


# --- Save ------------------------------------------------------------------------------------

func to_save() -> Dictionary:
	var list := []
	for e in entries:
		if not e.built:
			list.append({"id": String(e.id), "x": e.cell.x, "z": e.cell.y, "slot": e.slot, "rot": e.rot})
	return {"id": site_id, "name": blueprint_name, "anchor": [anchor.x, anchor.y], "rot": rotation_q, "layer": layer,
		"auto": auto, "total": total, "pending": list}


static func from_save(p_manager: BlueprintManager, d: Dictionary) -> ConstructionSite:
	var s := ConstructionSite.new()
	s.manager = p_manager
	s.site_id = String(d.get("id", ""))
	s.blueprint_name = String(d.get("name", "Blueprint"))
	var a: Array = d.get("anchor", [0, 0])
	s.anchor = Vector2i(int(a[0]), int(a[1]))
	s.rotation_q = int(d.get("rot", 0))
	s.layer = int(d.get("layer", 0))
	s.auto = bool(d.get("auto", false))
	for e in d.get("pending", []):
		if BuildingManager.get_piece_data(StringName(String(e.id))):
			s.entries.append({"id": StringName(String(e.id)), "cell": Vector2i(int(e.x), int(e.z)), "slot": String(e.slot),
				"rot": int(e.rot), "built": false, "reason": ""})
	s.total = maxi(int(d.get("total", s.entries.size())), s.entries.size())
	return s
