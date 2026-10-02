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
	_quest_buttons(info)
	if npc.role == &"noble":
		_button("Ask for recognition", func() -> void: _say(manager.recognition(info)))
	if npc.role == &"guard":
		_button("Any trouble?", func() -> void: _say(_trouble()))
	_button("Goodbye", close)


# --- Quests (Milestone 16) ------------------------------------------------------------------

func _quest_buttons(info: SettlementInfo) -> void:
	var ql: QuestLog = World.instance.quests if World.instance else null
	if ql == null:
		return
	if ql.current_step(QuestBook.MAIN).get("goal", "") == "talk":
		_button("Ask about the falling stars", func() -> void:
			var text := ql.talk_main()
			_choices(text, [
				["\"I will find the shards.\"", func() -> void: _say("Then go with the sky's blessing. Start with the old ruins - nobody else wants to.")],
				["\"What's in it for me?\"", func() -> void:
					_say("Gold, if you are lucky. A name, if you are brave. The ruins are full of both.")],
				["\"Tell me more about the Shattering.\"", func() -> void: _say(LoreBook.text_of(&"shattering"))],
			]))
	if npc.role != &"noble" or not info.is_kingdom():
		return
	_button("Tell me the history of %s" % info.kingdom_name, func() -> void: _say(ql.kingdom_history(info)))
	var q := QuestBook.kingdom_quest(info)
	match ql.kingdom_state(info):
		"offer":
			_button("Do you have work for me?", func() -> void:
				_choices("%s A royal errand: %s; then %s; then %s. Do it, and you will kneel as a knight of %s." % [
					q.summary, String(q.steps[0].text).to_lower(), String(q.steps[1].text).to_lower(),
					String(q.steps[2].text).to_lower(), info.kingdom_name], [
					["Accept the errand", func() -> void:
						ql.accept_kingdom(info, false)
						_say("Good. The realm remembers those who serve it.")],
					["Ask for half the gold up front", func() -> void:
						ql.accept_kingdom(info, true)
						_say("Hmph. Coin before deeds? Take it - but the realm will remember that too.")],
					["\"Not now.\"", func() -> void: _say("The offer stands. Come back when you are ready.")],
				]))
		"deliver", "return":
			var label := "Hand over the goods" if ql.kingdom_state(info) == "deliver" else "I have done everything you asked"
			_button(label, func() -> void:
				_say(ql.kingdom_turn_in(info))
				_rebuild_buttons())
		"done":
			pass
		_:
			_button("About your errand...", func() -> void:
				_say("You have not finished yet: %s." % String(ql.current_step(StringName("kingdom:%s" % info.kingdom_id)).get("text", "")).to_lower()))


## Says `text`, then shows the choices [[label, callable], ...] instead of the
## usual buttons (Milestone 16 dialogue choices). Picking one runs it and
## brings the usual buttons back.
func _choices(text: String, options: Array) -> void:
	_say(text)
	for c in _buttons.get_children():
		c.queue_free()
	for o in options:
		var cb: Callable = o[1]
		_button(String(o[0]), func() -> void:
			cb.call()
			_rebuild_buttons())


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
