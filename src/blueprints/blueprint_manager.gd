class_name BlueprintManager
extends Node3D
## Blueprints in the world (Milestone 8): the active construction sites, the
## placement preview, capturing your buildings as designs, and saving sites.

signal sites_changed

const MAX_SITES := 8

var world: World
var sites: Array[ConstructionSite] = []
var placer: BlueprintPlacer
var _counter := 0


func _ready() -> void:
	placer = BlueprintPlacer.new()
	placer.name = "BlueprintPlacer"
	placer.manager = self
	add_child(placer)


## Lays out `bp` at `anchor` (rotated `q` quarter turns) as a new construction site.
func start(bp: Blueprint, anchor: Vector2i, q: int, auto: bool = false) -> ConstructionSite:
	if bp == null or bp.pieces.is_empty():
		return null
	if sites.size() >= MAX_SITES:
		Events.toast.emit("You can only have %d construction sites at once" % MAX_SITES, Color(1, 0.7, 0.5))
		return null
	_counter += 1
	var s := ConstructionSite.new()
	s.setup(self, bp, anchor, q, world.layer)
	s.site_id = "site%d_%d" % [Time.get_ticks_msec(), _counter]
	s.auto = auto
	_add(s)
	Events.toast.emit("Construction site: %s (%d pieces). Press F on a hologram, or switch on auto-build (N)." % [bp.name, s.total],
		Color(0.6, 0.85, 1.0))
	return s


func _add(s: ConstructionSite) -> void:
	sites.append(s)
	add_child(s)
	s.changed.connect(func() -> void: sites_changed.emit())
	sites_changed.emit()


func finish_site(s: ConstructionSite) -> void:
	if not sites.has(s):
		return
	sites.erase(s)
	s.cancel()
	sites_changed.emit()


func cancel_site(s: ConstructionSite) -> void:
	if not sites.has(s):
		return
	sites.erase(s)
	s.cancel()
	Events.toast.emit("Construction site removed (built pieces stay)", Color(0.85, 0.85, 0.85))
	sites_changed.emit()


## Saves the pieces around you (your claim if you stand on one, else `radius` m) as a design.
func capture_here(p_name: String, radius: float = 10.0) -> Blueprint:
	var p := world.player.global_position
	var center := p
	var r := radius
	for c in get_tree().get_nodes_in_group(&"land_claims"):
		var claim := c as BuildPiece
		if claim and claim.layer == world.layer \
				and Vector2(p.x - claim.global_position.x, p.z - claim.global_position.z).length() <= claim.claim_radius():
			center = claim.global_position
			r = claim.claim_radius()
			break
	var bp := Blueprint.capture(world.building, center, r, world.layer, p_name)
	bp.author = world.player.character.class_data.display_name if world.player.character.class_data else ""
	return bp


func refresh_layer() -> void:
	for s in sites:
		s.refresh()


# --- Save -------------------------------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for s in sites:
		if not s.is_complete():
			out.append(s.to_save())
	return out


func from_save(list: Array) -> void:
	for s in sites:
		s.cancel()
	sites.clear()
	for d in list:
		var s := ConstructionSite.from_save(self, d)
		if not s.entries.is_empty():
			_add(s)
