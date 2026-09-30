class_name RequestsPanel
extends PanelContainer
## A settlement's notice board: today's delivery and hunt requests.

var site: SettlementSite
var manager: SettlementManager

var _title := Label.new()
var _list := VBoxContainer.new()
var _status := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(640, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	_list.add_theme_constant_override(&"separation", 10)
	v.add_child(_list)
	_status.add_theme_color_override(&"font_color", Color(1, 0.7, 0.5))
	v.add_child(_status)
	var hint := Label.new()
	hint.text = "New requests are posted every morning · Esc: close"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(hint)


func open(p_site: Node) -> void:
	site = p_site as SettlementSite
	manager = World.instance.living
	_status.text = ""
	visible = true
	refresh()


func close() -> void:
	visible = false
	site = null


func refresh() -> void:
	if site == null:
		return
	var info := site.info
	_title.text = "Notice board - %s" % info.name
	for c in _list.get_children():
		c.queue_free()
	for r in manager.requests(info):
		var row := HBoxContainer.new()
		_list.add_child(row)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = 470
		var prog := "(%d / %d)" % [mini(int(r.progress), int(r.count)), int(r.count)]
		l.text = "%s  %s\nReward: %s, +%d reputation" % [Requests.describe(r, info), prog,
			Economy.format_coins(int(r.reward)), roundi(float(r.rep))]
		if r.done:
			l.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
		row.add_child(l)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "Done" if r.done else ("Deliver" if r.type == "deliver" else "Claim")
		b.disabled = r.done or int(r.progress) < int(r.count)
		var req: Dictionary = r
		b.pressed.connect(func() -> void:
			var why := manager.complete_request(info, req)
			_status.text = why
			refresh())
		row.add_child(b)


func _process(_delta: float) -> void:
	if visible and (site == null or not is_instance_valid(site) or World.instance == null
			or site.to_local(World.instance.player.global_position).length() > site.info.radius + 10.0):
		close()
