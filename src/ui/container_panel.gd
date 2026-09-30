class_name ContainerPanel
extends PanelContainer
## Storage chest window: chest slots on the left, your inventory on the right.
## Click a stack to move it across (right-click moves one item).

var player: Player
var container: BuildPiece

var _title := Label.new()
var _chest_grid := GridContainer.new()
var _chest_slots: Array[ItemSlot] = []
var _inv_slots: Array[ItemSlot] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 24)
	v.add_child(h)
	_chest_grid.columns = 4
	h.add_child(_chest_grid)
	var inv_box := VBoxContainer.new()
	h.add_child(inv_box)
	var inv_title := Label.new()
	inv_title.text = "Inventory"
	inv_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	inv_box.add_child(inv_title)
	var inv_grid := GridContainer.new()
	inv_grid.columns = 8
	inv_box.add_child(inv_grid)
	for i in 24:
		var slot := ItemSlot.new(i, "")
		slot.slot_clicked.connect(func(idx: int, b: MouseButton) -> void:
			if player and container:
				transfer(player.inventory, idx, container.storage, 1 if b == MOUSE_BUTTON_RIGHT else -1))
		inv_grid.add_child(slot)
		_inv_slots.append(slot)
	var hint := Label.new()
	hint.text = "Click: move stack · Right-click: move one · F / Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func bind(p: Player) -> void:
	player = p
	p.inventory.changed.connect(refresh)
	Events.open_container.connect(open)


func open(c: Node) -> void:
	var piece := c as BuildPiece
	if piece == null or piece.storage == null:
		return
	if visible and piece == container:
		close()  # interacting again closes it
		return
	close()
	container = piece
	container.storage.changed.connect(refresh)
	_title.text = piece.data.display_name
	for s in _chest_slots:
		s.queue_free()
	_chest_slots.clear()
	for i in piece.storage.capacity:
		var slot := ItemSlot.new(i, "")
		slot.slot_clicked.connect(func(idx: int, b: MouseButton) -> void:
			if player and container:
				var st = container.storage.get_slot(idx)
				if st != null and transfer(container.storage, idx, player.inventory, 1 if b == MOUSE_BUTTON_RIGHT else -1) > 0:
					player.discover_from(st.id))
		_chest_grid.add_child(slot)
		_chest_slots.append(slot)
	visible = true
	refresh()


func close() -> void:
	if container and is_instance_valid(container) and container.storage.changed.is_connected(refresh):
		container.storage.changed.disconnect(refresh)
	container = null
	visible = false


## Moves `count` items (-1 = whole stack) from slot `index` of `from` into `to`.
## Returns how many moved.
static func transfer(from: Inventory, index: int, to: Inventory, count: int = -1) -> int:
	var s = from.get_slot(index)
	if s == null:
		return 0
	var n: int = s.count if count < 0 else mini(count, s.count)
	var id: StringName = s.id
	var left := to.add_item(id, n)
	var moved := n - left
	if moved > 0:
		from.remove_from_slot(index, moved)
	return moved


func _process(_delta: float) -> void:
	if not visible:
		return
	if container == null or not is_instance_valid(container) or player == null or player.is_dead \
			or container.global_position.distance_to(player.global_position) > 4.5:
		close()


func refresh() -> void:
	if player == null or container == null or not is_instance_valid(container):
		return
	for i in _chest_slots.size():
		_chest_slots[i].set_stack(container.storage.get_slot(i), false)
	for i in _inv_slots.size():
		_inv_slots[i].set_stack(player.inventory.get_slot(i), false)
