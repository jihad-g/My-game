class_name ClassPicker
extends VBoxContainer
## Character creation (Milestone 14), souls-like: pick a starting class - its
## starting stats, outfit and weapon - and the body of your character. Every
## class shares the same body; how you look comes from what you wear, so a
## Knight who later dresses in Shadowstalker's Garb looks like an Assassin.
##
## Shows a turning 3D preview wearing the class's starting kit, stat bars,
## health / mana / armour, the kit and supplies, and body options.

signal changed

const BAR_MAX := 30.0

var selected_class: StringName = ClassRegistry.DEFAULT_CLASS
## CharacterLook dict (skin, hair, style, beard).
var look: Dictionary = {}
## Set true once the player edits the body (then class changes keep it).
var look_edited := false

var _class_buttons: Dictionary = {}
var _title := Label.new()
var _bars := GridContainer.new()
var _derived := Label.new()
var _kit := Label.new()
var _look_labels: Dictionary = {}
var _beard := CheckBox.new()
var _viewport := SubViewport.new()
var _pivot := Node3D.new()
var _model: HumanoidModel


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	for c in ClassRegistry.all():
		var b := Button.new()
		b.text = c.display_name
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: StringName = c.id
		b.pressed.connect(func() -> void: select_class(cid))
		row.add_child(b)
		_class_buttons[cid] = b

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	add_child(body)
	body.add_child(_build_preview())
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 4)
	body.add_child(info)
	_title.add_theme_font_size_override(&"font_size", 16)
	_title.add_theme_color_override(&"font_color", UITheme.GOLD)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title.custom_minimum_size = Vector2(230, 0)
	info.add_child(_title)
	_bars.columns = 3
	_bars.add_theme_constant_override(&"h_separation", 6)
	_bars.add_theme_constant_override(&"v_separation", 2)
	info.add_child(_bars)
	for l in [_derived, _kit]:
		l.add_theme_font_size_override(&"font_size", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(230, 0)
		info.add_child(l)
	_derived.add_theme_color_override(&"font_color", Color(0.8, 0.9, 1.0))
	_kit.add_theme_color_override(&"font_color", UITheme.TEXT_DIM)
	add_child(_build_look_rows())
	select_class(selected_class)


func _build_preview() -> Control:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(150, 210)
	box.stretch = true
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(150, 210)
	box.add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.4)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 40.0
	_viewport.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.8
	_viewport.add_child(env)
	_viewport.add_child(_pivot)
	_model = HumanoidModel.new()
	_pivot.add_child(_model)
	return box


## Two compact rows: skin + hair colour, hair style + beard + random.
func _build_look_rows() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	var rows := [HBoxContainer.new(), HBoxContainer.new()]
	for r in rows:
		r.add_theme_constant_override(&"separation", 4)
		box.add_child(r)
	for key in ["skin", "hair", "style"]:
		var grid: HBoxContainer = rows[0] if key != "style" else rows[1]
		var name_l := Label.new()
		name_l.text = {"skin": "Skin", "hair": "Hair", "style": "Style"}[key]
		name_l.add_theme_font_size_override(&"font_size", 13)
		name_l.custom_minimum_size = Vector2(40, 0)
		grid.add_child(name_l)
		var prev := Button.new()
		prev.text = "<"
		prev.custom_minimum_size = Vector2(28, 0)
		prev.pressed.connect(cycle_look.bind(key, -1))
		grid.add_child(prev)
		var val := Label.new()
		val.custom_minimum_size = Vector2(66, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override(&"font_size", 13)
		grid.add_child(val)
		_look_labels[key] = val
		var next := Button.new()
		next.text = ">"
		next.custom_minimum_size = Vector2(28, 0)
		next.pressed.connect(cycle_look.bind(key, 1))
		grid.add_child(next)
	_beard.text = "Beard"
	_beard.toggled.connect(func(on: bool) -> void:
		look.beard = on
		look_edited = true
		_apply_look())
	rows[1].add_child(_beard)
	var rnd := Button.new()
	rnd.text = "Random"
	rnd.tooltip_text = "Random look"
	rnd.pressed.connect(randomize_look)
	rows[1].add_child(rnd)
	return box


func select_class(id: StringName) -> void:
	var c := ClassRegistry.get_class_data(id)
	if c == null:
		return
	selected_class = id
	for cid in _class_buttons:
		_class_buttons[cid].button_pressed = cid == id
	if not look_edited or look.is_empty():
		look = CharacterLook.default_for(id)
	_title.text = "%s — %s" % [c.display_name, c.role_summary]
	var eq := starting_equipment(c)
	# Stat bars: starting skill + what the starting outfit adds.
	for child in _bars.get_children():
		child.queue_free()
	for s in Skill.ALL:
		var base := c.starting_skill(s)
		var bonus := int(eq.total(s))
		var n := Label.new()
		n.text = Skill.NAMES[s]
		n.add_theme_font_size_override(&"font_size", 12)
		n.custom_minimum_size = Vector2(88, 0)
		_bars.add_child(n)
		var bar := ProgressBar.new()
		bar.max_value = BAR_MAX
		bar.value = base + bonus
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(90, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bars.add_child(bar)
		var v := Label.new()
		v.text = "%d%s" % [base, " +%d" % bonus if bonus > 0 else ""]
		v.add_theme_font_size_override(&"font_size", 12)
		_bars.add_child(v)
	var st := starting_stats(c)
	_derived.text = "Health %d · Mana %d · Armor %d\nTalent: %s" % [st.health, st.mana, st.armor, talent_text(c)]
	_title.tooltip_text = "%s\n\n%s" % [c.description, c.backstory]
	var kit := PackedStringArray()
	for item_id in c.starting_equipment:
		var it: ItemData = ItemDB.get_item(StringName(item_id))
		if it:
			kit.append(it.display_name)
	var supplies := PackedStringArray()
	for item_id in c.starting_items:
		var it: ItemData = ItemDB.get_item(StringName(item_id))
		if it:
			supplies.append("%d %s" % [int(c.starting_items[item_id]), it.display_name])
	_kit.text = "Kit: %s" % ", ".join(kit)
	var sets := eq.set_counts()
	for set_id in sets:
		_kit.text += " (%s %d/%d)" % [GearSets.display_name(set_id), sets[set_id], GearSets.full_size(set_id)]
	if not supplies.is_empty():
		_kit.text += "\nSupplies: %s" % ", ".join(supplies)
	for b in _class_buttons.values():
		b.tooltip_text = ClassRegistry.get_class_data((_class_buttons.find_key(b) as StringName)).description
	_model.set_appearance(c)
	var w := eq.weapon()
	_model.set_weapon(w.weapon_type if w else &"unarmed", eq.has_shield())
	_model.set_outfit(eq.outfit_ids(), w.id if w else &"")
	_apply_look()
	changed.emit()


## The class's starting kit worn on a scratch Equipment.
static func starting_equipment(c: ClassData) -> Equipment:
	var eq := Equipment.new()
	for item_id in c.starting_equipment:
		var it: ItemData = ItemDB.get_item(StringName(item_id))
		if it:
			eq.equip(it)
	return eq


## Health, mana and armour a new character of class `c` starts with.
static func starting_stats(c: ClassData) -> Dictionary:
	var eq := starting_equipment(c)
	var def := c.starting_skill(Skill.DEFENSE) + int(eq.total(Skill.DEFENSE))
	var mc := c.starting_skill(Skill.MANA_CONTROL) + int(eq.total(Skill.MANA_CONTROL))
	return {
		"health": roundi(Skill.max_health(def, c.base_health, c.health_per_defense) + eq.total(&"max_health")),
		"mana": roundi(Skill.max_mana(mc, c.base_mana, c.mana_per_point) + eq.total(&"max_mana")),
		"armor": roundi(c.base_armor + Skill.skill_armor(def, c.efficiency(Skill.DEFENSE)) + eq.total(&"armor")),
	}


## The class's lasting talent (Option A): what it keeps whatever it wears.
static func talent_text(c: ClassData) -> String:
	var best_skill: StringName = Skill.ALL[0]
	for s in Skill.ALL:
		if c.efficiency(s) > c.efficiency(best_skill):
			best_skill = s
	var best_weapon := ""
	var best_prof := 0.0
	for w in c.weapon_proficiency:
		if float(c.weapon_proficiency[w]) > best_prof:
			best_prof = float(c.weapon_proficiency[w])
			best_weapon = String(w)
	return "%s %d%% more effective · +%d%% with %ss · abilities: %s" % [Skill.NAMES[best_skill],
		roundi((c.efficiency(best_skill) - 1.0) * 100.0), roundi((best_prof - 1.0) * 100.0), best_weapon,
		", ".join(c.abilities.map(func(a: AbilityData) -> String: return a.display_name))]


func cycle_look(key: String, dir: int) -> void:
	var sizes := {"skin": CharacterLook.SKINS.size(), "hair": CharacterLook.HAIRS.size(), "style": CharacterLook.STYLES.size()}
	look[key] = posmod(int(look.get(key, 0)) + dir, int(sizes[key]))
	look_edited = true
	_apply_look()


func randomize_look() -> void:
	look = {"skin": randi() % CharacterLook.SKINS.size(), "hair": randi() % CharacterLook.HAIRS.size(),
		"style": randi() % CharacterLook.STYLES.size(), "beard": randi() % 2 == 0}
	look_edited = true
	_apply_look()


func _apply_look() -> void:
	look = CharacterLook.sanitize(look, selected_class)
	_look_labels.skin.text = CharacterLook.SKIN_NAMES[look.skin]
	_look_labels.hair.text = CharacterLook.HAIR_NAMES[look.hair]
	_look_labels.style.text = CharacterLook.STYLE_NAMES[look.style]
	_beard.set_pressed_no_signal(look.beard)
	_model.set_body(look)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotation.y += delta * 0.6
		_model.set_locomotion(0.0, delta)
