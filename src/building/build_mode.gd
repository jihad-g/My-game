class_name BuildMode
extends Node3D
## Player building mode (B): ghost preview snapped to the grid, place with
## left click, deconstruct with right click, rotate with R, repair the piece
## under the cursor with U (Shift+U repairs everything nearby).

signal toggled(active: bool)
signal selection_changed(data: BuildPieceData)
## Current placement verdict ("" = valid) for the UI.
signal status_changed(reason: String)

var world: World
var active := false
var selected: BuildPieceData
var rot := 0

var _ghost := MeshInstance3D.new()
var _ok_mat := StandardMaterial3D.new()
var _bad_mat := StandardMaterial3D.new()
var _address: Dictionary = {}
var _reason := ""
var _claim_ring: MeshInstance3D


func _ready() -> void:
	for pair in [[_ok_mat, Color(0.3, 1.0, 0.4, 0.45)], [_bad_mat, Color(1.0, 0.25, 0.2, 0.45)]]:
		var m: StandardMaterial3D = pair[0]
		m.albedo_color = pair[1]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_claim_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 3
	_claim_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.3, 0.7, 1.0, 0.6)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_claim_ring.material_override = rm
	_claim_ring.visible = false
	add_child(_claim_ring)
	if selected == null:
		selected = BuildingManager.get_piece_data(&"wood_wall")


func set_active(on: bool) -> void:
	if on and (world.player.is_dead or world.player.frozen):
		return
	if on and world.blueprints and world.blueprints.placer.active:
		world.blueprints.placer.end()
	active = on
	_ghost.visible = on
	_claim_ring.visible = false
	if on:
		world.player.combat.cancel()
	toggled.emit(on)


func select(data: BuildPieceData) -> void:
	selected = data
	rot = 0
	_ghost.mesh = BuildMeshes.get_mesh(data.mesh) if data else null
	selection_changed.emit(data)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		set_active(not active)
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event.is_action_pressed(&"attack_light"):
		place_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"attack_heavy"):
		remove_under_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_repair"):
		if Input.is_key_pressed(KEY_SHIFT):
			var n := world.building.repair_all_near(world.player.global_position, 20.0, world.player)
			Events.toast.emit("Repaired %d piece%s" % [n, "" if n == 1 else "s"] if n > 0 else "Nothing you can repair nearby",
				Color(0.7, 1, 0.7) if n > 0 else Color(1, 0.8, 0.5))
		else:
			repair_under_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_rotate"):
		rot = (rot + 1) % 4
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		set_active(false)
		get_viewport().set_input_as_handled()


func _cursor() -> Vector3:
	return world.camera_rig.get_mouse_world_point(world.player.global_position.y)


func _process(_delta: float) -> void:
	if not active or selected == null:
		return
	if world.player.is_dead:
		set_active(false)
		return
	if _ghost.mesh == null:
		_ghost.mesh = BuildMeshes.get_mesh(selected.mesh)
	_update_target(_cursor())


## Updates the preview for a world point (also used by tests/automation).
func _update_target(point: Vector3) -> void:
	_address = world.building.address_for(selected, point)
	_ghost.global_transform = world.building.transform_for(selected, _address.cell, _address.slot, rot)
	var reason := world.building.check_place(selected, _address.cell, _address.slot, world.player)
	_ghost.material_override = _ok_mat if reason == "" else _bad_mat
	if selected.behavior == BuildPieceData.Behavior.CLAIM:
		_claim_ring.visible = true
		_claim_ring.global_position = _ghost.global_position + Vector3(0, 0.3, 0)
		_claim_ring.scale = Vector3(selected.claim_radius, 1.0, selected.claim_radius)
	else:
		_claim_ring.visible = false
	if reason != _reason:
		_reason = reason
		status_changed.emit(reason)


func place_current() -> BuildPiece:
	if selected == null or _address.is_empty():
		return null
	if _reason != "":
		Events.toast.emit(_reason, Color(1, 0.6, 0.5))
		return null
	if Net.is_client():
		Net.client.place_piece(selected, _address.cell, _address.slot, rot, world.layer)
		return null
	var piece := world.building.place(selected, _address.cell, _address.slot, rot, world.player)
	if piece:
		Events.item_crafted.emit(selected.id, 1)  # building grants a little crafting XP
	return piece


func remove_under_cursor() -> void:
	var piece := world.building.piece_at(_cursor())
	if piece and Net.is_client():
		Net.client.remove_piece(piece)
	elif piece:
		world.building.remove(piece, world.player)


func repair_under_cursor() -> void:
	var piece := world.building.piece_at(_cursor())
	if piece == null:
		return
	var err := world.building.repair(piece, world.player)
	Events.toast.emit("Repaired %s" % piece.data.display_name if err == "" else err,
		Color(0.7, 1, 0.7) if err == "" else Color(1, 0.7, 0.5))
