class_name DialoguePanel
extends PanelContainer
## Talking to a townsperson: greeting, gossip, trade, recognition (nobles).

signal trade_requested(npc: NPC)

var npc: NPC
var manager: SettlementManager

var _title := Label.new()
var _sub := Label.new()
var _text := Label.new()
var _buttons := VBoxContainer.new()
var _gossip: Array[String] = []
var _gossip_i := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -170
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	v.add_child(_title)
	_sub.add_theme_font_size_override(&"font_size", 13)
	_sub.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	v.add_child(_sub)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(600, 48)
	_text.add_theme_font_size_override(&"font_size", 17)
	v.add_child(_text)
	_buttons.add_theme_constant_override(&"separation", 4)
	v.add_child(_buttons)


func open(p_npc: NPC) -> void:
	close()
	npc = p_npc
	manager = World.instance.living
	npc.talking = true
	_gossip = Gossip.lines(npc, manager)
	_gossip_i = int(npc.data.seed) % maxi(1, _gossip.size())
	var info := npc.site.info
	_title.text = npc.full_name()
	var rep := World.instance.player.reputation
	_sub.text = "%s · your standing: %s (%d)" % [info.title(), rep.tier_name(info.id), roundi(rep.get_points(info.id))]
	_say(Gossip.greeting(npc, rep.tier(info.id)))
	_rebuild_buttons()
	visible = true


func close() -> void:
	if npc and is_instance_valid(npc):
		npc.talking = false
	npc = null
	visible = false


func _say(t: String) -> void:
	_text.text = "\"%s\"" % t


func _button(label: String, cb: Callable, enabled: bool = true) -> void:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _rebuild_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var info := npc.site.info
	if npc.is_shopkeeper():
		_button("Trade" if npc.is_open() else "Trade (closed - come back during work hours)", func() -> void:
			trade_requested.emit(npc), npc.is_open())
	_button("What's new?", func() -> void:
		if _gossip.is_empty():
			_say("Nothing much happens around here.")
		else:
			_say(_gossip[_gossip_i % _gossip.size()])
			_gossip_i += 1)
	_button("Tell me about %s" % info.name, func() -> void: _say(_about()))
	if npc.role == &"noble":
		_button("Ask for recognition", func() -> void: _say(manager.recognition(info)))
	if npc.role == &"guard":
		_button("Any trouble?", func() -> void: _say(_trouble()))
	_button("Goodbye", close)


func _about() -> String:
	var s := npc.site.info
	var people := npc.site.npcs.size()
	var farms := npc.site.layout.farms.size()
	var what := "the capital of the Kingdom of %s" % s.kingdom_name if s.is_kingdom() \
		else ("a village of the Kingdom of %s" % s.kingdom_name if s.kingdom_name != "" else "a free village")
	var crops := {}
	for f in npc.site.layout.farms:
		crops[String(f.crop)] = true
	var farm_text := "We farm %s." % ", ".join(crops.keys()) if farms > 0 else "We buy most of our food."
	return "%s is %s. About %d of us live here. %s The notice board by the well lists work that pays." % [s.name, what, people, farm_text]


func _trouble() -> String:
	for r in manager.requests(npc.site.info):
		if r.type == "hunt" and not r.done:
			return "Boars keep raiding the fields. Defeat %d of them near town (%d so far) and claim the bounty at the notice board." % [r.count, r.progress]
	return "Quiet, for now. We guards keep monsters from wandering into town."


func _process(_delta: float) -> void:
	if not visible:
		return
	var p := World.instance.player if World.instance else null
	if npc == null or not is_instance_valid(npc) or npc.asleep or p == null or p.global_position.distance_to(npc.global_position) > 5.0:
		close()
