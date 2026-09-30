class_name TradePanel
extends PanelContainer
## Buying from and selling to a shopkeeper. Prices include regional demand,
## your reputation discount and (when selling) how much of it you already sold.

var npc: NPC
var manager: SettlementManager

var _title := Label.new()
var _info := Label.new()
var _status := Label.new()
var _buy_list := VBoxContainer.new()
var _sell_list := VBoxContainer.new()


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
	_info.add_theme_font_size_override(&"font_size", 13)
	v.add_child(_info)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 16)
	v.add_child(cols)
	for pair in [["Buy", _buy_list], ["Sell (your inventory)", _sell_list]]:
		var box := VBoxContainer.new()
		cols.add_child(box)
		var h := Label.new()
		h.text = pair[0]
		h.add_theme_color_override(&"font_color", UITheme.GOLD)
		box.add_child(h)
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(430, 380)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(sc)
		var list: VBoxContainer = pair[1]
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override(&"separation", 2)
		sc.add_child(list)
	_status.add_theme_color_override(&"font_color", Color(1, 0.7, 0.5))
	v.add_child(_status)
	var hint := Label.new()
	hint.text = "Esc: close · Selling the same item again pays less (the market saturates; recovers daily) · Shops restock every morning"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func open(p_npc: NPC) -> void:
	npc = p_npc
	manager = World.instance.living
	npc.talking = true
	_status.text = ""
	visible = true
	refresh()


func close() -> void:
	if npc and is_instance_valid(npc):
		npc.talking = false
	npc = null
	visible = false


func refresh() -> void:
	if npc == null:
		return
	var info := npc.site.info
	var role := npc.role
	var player := World.instance.player
	var st := manager.shop_state(info, role)
	var tier := manager.rep_tier(info)
	_title.text = "%s - %s" % [npc.full_name(), info.name]
	_info.text = "Your coins: %s   ·   Shop's coins today: %s   ·   Standing: %s (%d%% better prices)" % [
		Economy.format_coins(player.coins), Economy.format_coins(int(st.money)), Reputation.TIER_NAMES[tier],
		roundi(Reputation.DISCOUNTS[tier] * 100.0)]
	for c in _buy_list.get_children():
		c.queue_free()
	for c in _sell_list.get_children():
		c.queue_free()
	var keys: Array = st.stock.keys()
	keys.sort()
	for key in keys:
		var id := StringName(key)
		var qty := int(st.stock[key])
		var item: ItemData = ItemDB.get_item(id)
		if item == null or qty <= 0:
			continue
		var need := Economy.required_tier(role, id) if role != &"trader" else 0
		var price := manager.buy_price(info, role, id)
		var locked := tier < need
		var b := _row(_buy_list, item, "x%d" % qty, Economy.format_coins(price),
			"Needs %s" % Reputation.TIER_NAMES[need] if locked else "Buy", not locked and player.coins >= price)
		b.pressed.connect(func() -> void:
			var why := manager.buy(info, role, id, 1)
			_status.text = why if why != "" else "Bought %s" % item.display_name
			refresh())
	var seen := {}
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s == null or seen.has(s.id):
			continue
		seen[s.id] = true
		var item: ItemData = ItemDB.get_item(s.id)
		if item == null:
			continue
		var wants := Economy.will_buy(role, s.id)
		var price := manager.sell_price(info, role, s.id) if wants else 0
		var slot := i
		var total := player.inventory.count_of(s.id)
		var b := _row(_sell_list, item, "x%d" % total, Economy.format_coins(price) if wants else "-",
			"Sell" if wants else "Not wanted", wants and price > 0)
		b.pressed.connect(func() -> void:
			var why := manager.sell(info, role, slot, 1)
			_status.text = why if why != "" else "Sold %s" % item.display_name
			refresh())
		if wants and price > 0 and int(s.count) > 1:
			var all := Button.new()
			all.text = "All"
			all.focus_mode = Control.FOCUS_NONE
			all.pressed.connect(func() -> void:
				var why := manager.sell(info, role, slot, 999)
				_status.text = why if why != "" else "Sold a stack of %s" % item.display_name
				refresh())
			b.get_parent().add_child(all)


func _row(list: VBoxContainer, item: ItemData, qty: String, price: String, action: String, enabled: bool) -> Button:
	var row := HBoxContainer.new()
	list.add_child(row)
	var n := Label.new()
	n.text = item.display_name
	n.custom_minimum_size.x = 190
	n.add_theme_color_override(&"font_color", item.rarity_color())
	n.tooltip_text = "\n".join(PackedStringArray([item.description]) + item.effect_lines())
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(n)
	var q := Label.new()
	q.text = qty
	q.custom_minimum_size.x = 44
	row.add_child(q)
	var p := Label.new()
	p.text = price
	p.custom_minimum_size.x = 80
	p.add_theme_color_override(&"font_color", UITheme.GOLD)
	row.add_child(p)
	var b := Button.new()
	b.text = action
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	row.add_child(b)
	return b


func _process(_delta: float) -> void:
	if not visible:
		return
	var p := World.instance.player if World.instance else null
	if npc == null or not is_instance_valid(npc) or not npc.is_open() or p == null \
			or p.global_position.distance_to(npc.global_position) > 6.0:
		close()
