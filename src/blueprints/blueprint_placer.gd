class_name BlueprintPlacer
extends Node3D
## Placement preview for a blueprint (Milestone 8): the whole design follows
## the cursor as holograms (blue = fine, red = blocked), R rotates it by 90°,
## left click lays it out as a construction site, right click / Esc cancels.

signal toggled(active: bool)

var manager: BlueprintManager
var active := false
var blueprint: Blueprint
var rotation_q := 0
## Anchor cell under the cursor and how many pieces are blocked there.
var anchor := Vector2i.ZERO
var blocked := 0

var _ghosts: Array[MeshInstance3D] = []
var _rotated: Blueprint
var _last_anchor := Vector2i(1 << 30, 0)


func begin(bp: Blueprint) -> void:
	var w := manager.world
	if w.player.is_dead or w.player.frozen or w.dungeon != null:
		return
	if w.build_mode.active:
		w.build_mode.set_active(false)
	blueprint = bp
	rotation_q = 0
	active = true
	_rebuild_ghosts()
	toggled.emit(true)
	Events.toast.emit("Placing %s: R rotate · left click place · right click / Esc cancel" % bp.name, Color(0.6, 0.85, 1.0))


func end() -> void:
	active = false
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()
	toggled.emit(false)


func rotate_cw() -> void:
	rotation_q = (rotation_q + 1) % 4
	_rebuild_ghosts()


func _rebuild_ghosts() -> void:
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()
	_rotated = blueprint.rotated(rotation_q)
	for e in _rotated.pieces:
		var data := BuildingManager.get_piece_data(StringName(e.id))
		var mi := MeshInstance3D.new()
		mi.mesh = BuildMeshes.get_mesh(data.mesh)
		mi.material_override = BlueprintHologram.material(false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_ghosts.append(mi)
	_last_anchor = Vector2i(1 << 30, 0)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"attack_light"):
		confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"attack_heavy") or event.is_action_pressed(&"pause"):
		end()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_rotate"):
		rotate_cw()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not active:
		return
	var w := manager.world
	if w.player.is_dead:
		end()
		return
	var p := w.camera_rig.get_mouse_world_point(w.player.global_position.y)
	move_to(Vector2i(floori(p.x), floori(p.z)))


## Moves the preview to an anchor cell (also used by tests). Re-checks every piece.
func move_to(cell: Vector2i) -> void:
	anchor = cell
	if cell == _last_anchor:
		return
	_last_anchor = cell
	var w := manager.world
	blocked = 0
	for i in _rotated.pieces.size():
		var e: Dictionary = _rotated.pieces[i]
		var data := BuildingManager.get_piece_data(StringName(e.id))
		var c := cell + Vector2i(int(e.x), int(e.z))
		_ghosts[i].global_transform = w.building.transform_for(data, c, String(e.slot), int(e.rot))
		# Roofs are checked for support once the walls stand, so don't mark them now.
		var why := "" if e.slot == "roof" else w.building.check_place(data, c, String(e.slot), null, false)
		if why != "":
			blocked += 1
		_ghosts[i].material_override = BlueprintHologram.material(why != "")


func confirm() -> ConstructionSite:
	if not active:
		return null
	if blocked >= _rotated.pieces.size():
		Events.toast.emit("Every piece is blocked here", Color(1, 0.6, 0.5))
		return null
	var bp := blueprint
	var q := rotation_q
	var a := anchor
	end()
	return manager.start(bp, a, q)
