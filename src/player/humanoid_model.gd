class_name HumanoidModel
extends Node3D
## Blocky, cartoon-proportioned humanoid built from coloured boxes, with
## procedural animation (walk cycle, attack swings, dodge roll, block pose,
## hit flash). No external model or animation files needed.
##
## The public API (set_locomotion, play_attack, play_dodge, set_blocking, flash)
## is what a future skeletal/AnimationTree model must also provide.
##
## Milestone 10: knees and elbows, idle breathing and glances, running lean,
## jump/fall, swimming strokes, landing squash, spell-casting pose, weapon
## swing trails and a `footstep` signal on every foot contact.

signal footstep(left: bool)
## Animation started (multiplayer replicates these): "attack" [anim, windup,
## active, recovery], "dodge" [duration], "cast" [duration], "death", "respawn".
signal anim_event(ev: String, args: Array)

@export var skin_color := Color(0.96, 0.78, 0.62)
@export var hair_color := Color(0.42, 0.26, 0.14)
@export var shirt_color := Color(0.25, 0.48, 0.85)
@export var pants_color := Color(0.28, 0.24, 0.3)
@export var boot_color := Color(0.35, 0.22, 0.14)
@export var weapon_color := Color(0.78, 0.8, 0.86)

var _root: Node3D  # rotated for rolls/tilts
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _weapon: Node3D
var _tip: Node3D
var _trail: WeaponTrail
var _time := 0.0
var _airborne := false
var _swimming := false
var _swim_blend := 0.0
var _air_blend := 0.0
var _cast_t := 0.0
var _cast_len := 0.0
var _last_step_sign := 0.0
var _look := 0.0
var _was_swimming := false
var _parts: Array[MeshInstance3D] = []

var _walk_phase := 0.0
var _move_amount := 0.0
var _blocking := false
var _attack_tween: Tween
var _dodge_tween: Tween
var _flash_time := 0.0
## Arm swing override while attacking (x = shoulder pitch, y = shoulder yaw).
var _attack_arm := Vector2.ZERO
var _attack_torso := 0.0


var _class_id: StringName = &""
var _accent := Color(0.75, 0.6, 0.25)
var _weapon_type: StringName = &"sword"
var _has_shield := false
var _shield: Node3D
var _ghost := false


func _ready() -> void:
	_build()


## Milestone 14 (Outfits): every player character has the same body. The class
## only decides the starting gear; what you wear decides how you look.
const PLAYER_SKIN := Color(0.96, 0.78, 0.62)
const PLAYER_HAIR := Color(0.42, 0.26, 0.14)
const PLAYER_SHIRT := Color(0.66, 0.6, 0.5)   # plain linen tunic
const PLAYER_PANTS := Color(0.36, 0.3, 0.24)
const PLAYER_BOOTS := Color(0.35, 0.22, 0.14)

## Outfit items being drawn (ItemData), in ItemData.OUTFIT_SLOTS order.
var _outfit: Array = []
var _weapon_item: ItemData


## The chosen body: {skin, hair, style, beard} (CharacterLook). Empty = defaults.
var _body: Dictionary = {}


## Player look: the shared body. The class only suggests a default body (until
## set_body() is called); call set_outfit() to dress the character.
func set_appearance(c: ClassData = null) -> void:
	_class_id = &"player"
	if _body.is_empty():
		_body = CharacterLook.default_for(c.id if c else &"knight")
	skin_color = CharacterLook.skin_color(_body)
	hair_color = CharacterLook.hair_color(_body)
	shirt_color = PLAYER_SHIRT
	pants_color = PLAYER_PANTS
	boot_color = PLAYER_BOOTS
	_accent = Color(0.75, 0.6, 0.25)
	_build()


## Body chosen at character creation (Milestone 14): skin tone, hair colour,
## hair style and beard - see CharacterLook. Same for every class.
func set_body(look: Dictionary) -> void:
	_body = CharacterLook.sanitize(look)
	set_appearance()


## Dresses the player in these items (ids of head/chest/hands/feet/off-hand/
## amulet pieces; unknown ids are ignored) and colours the weapon after `weapon_id`.
func set_outfit(ids: PackedStringArray, weapon_id: StringName = &"") -> void:
	_outfit.clear()
	for id in ids:
		var item: ItemData = ItemDB.get_item(StringName(id)) if ItemDB.has_item(StringName(id)) else null
		if item and item.is_equippable():
			_outfit.append(item)
	_weapon_item = ItemDB.get_item(weapon_id) if weapon_id != &"" and ItemDB.has_item(weapon_id) else null
	weapon_color = ItemIcons.metal_of(_weapon_item) if _weapon_item else Color(0.78, 0.8, 0.86)
	if _root:
		_build()


## Outfit looks currently drawn (tests and multiplayer).
func outfit_looks() -> Array:
	var out := []
	for item: ItemData in _outfit:
		if item.outfit_look != &"":
			out.append(item.outfit_look)
	return out


## Townsperson look (Milestone 5): seeded colours + role clothing and tool.
func set_npc_look(role: StringName, seed: int, accent: Color) -> void:
	const SKINS := [Color(0.96, 0.78, 0.62), Color(0.85, 0.64, 0.48), Color(0.66, 0.46, 0.32), Color(0.45, 0.3, 0.2), Color(0.98, 0.85, 0.72)]
	const HAIRS := [Color(0.42, 0.26, 0.14), Color(0.15, 0.12, 0.1), Color(0.85, 0.7, 0.35), Color(0.6, 0.25, 0.12), Color(0.75, 0.75, 0.75)]
	const SHIRTS := [Color(0.6, 0.35, 0.25), Color(0.35, 0.5, 0.3), Color(0.3, 0.4, 0.6), Color(0.7, 0.6, 0.4), Color(0.55, 0.3, 0.45), Color(0.8, 0.75, 0.6)]
	skin_color = SKINS[seed % SKINS.size()]
	hair_color = HAIRS[(seed / 7) % HAIRS.size()]
	shirt_color = SHIRTS[(seed / 13) % SHIRTS.size()]
	pants_color = Color(0.3, 0.26, 0.22) if (seed / 5) % 2 == 0 else Color(0.25, 0.28, 0.35)
	_accent = accent
	_class_id = StringName("npc_%s" % role)
	match role:
		&"guard":
			shirt_color = Color(0.55, 0.57, 0.62)
			_weapon_type = &"spear"
			_has_shield = true
		&"blacksmith":
			shirt_color = Color(0.4, 0.35, 0.32)
			_weapon_type = &"hammer"
		&"farmer":
			_weapon_type = &"hoe"
		&"noble":
			shirt_color = accent.darkened(0.2)
			pants_color = Color(0.2, 0.18, 0.22)
			_weapon_type = &"unarmed"
		_:
			_weapon_type = &"unarmed"
	_build()


## Monster look (Milestone 6): skeletons, cultists, golems and their bosses.
func set_monster_look(look: StringName, tint: Color, accent: Color) -> void:
	_accent = accent
	_class_id = StringName("mon_%s" % look)
	_has_shield = false
	match look:
		&"skeleton", &"skeleton_archer", &"bone_king":
			skin_color = tint
			hair_color = tint * 0.9
			shirt_color = tint * 0.85
			pants_color = tint * 0.8
			boot_color = tint * 0.7
			_weapon_type = &"bow" if look == &"skeleton_archer" else (&"axe" if look == &"bone_king" else &"sword")
			_has_shield = look == &"skeleton"
		&"cultist", &"warden":
			skin_color = Color(0.75, 0.62, 0.55)
			hair_color = Color(0.15, 0.1, 0.12)
			shirt_color = tint
			pants_color = tint * 0.7
			boot_color = Color(0.2, 0.15, 0.15)
			_weapon_type = &"staff"
		&"bandit", &"bandit_archer", &"bandit_brute", &"bandit_hexer", &"bandit_bomber", &"warlord":
			skin_color = Color(0.85, 0.64, 0.48) if look != &"bandit_brute" else Color(0.66, 0.46, 0.32)
			hair_color = Color(0.2, 0.14, 0.1)
			shirt_color = tint
			pants_color = Color(0.3, 0.25, 0.2)
			boot_color = Color(0.25, 0.17, 0.1)
			match look:
				&"bandit_archer":
					_weapon_type = &"bow"
				&"bandit_brute", &"warlord":
					_weapon_type = &"axe"
				&"bandit_hexer":
					_weapon_type = &"staff"
					pants_color = tint * 0.7
				&"bandit_bomber":
					_weapon_type = &"unarmed"
				_:
					_weapon_type = &"sword"
					_has_shield = true
		&"goblin":
			skin_color = Color(0.45, 0.7, 0.3)
			hair_color = Color(0.3, 0.45, 0.2)
			shirt_color = tint
			pants_color = Color(0.35, 0.28, 0.2)
			boot_color = Color(0.25, 0.18, 0.12)
			_weapon_type = &"dagger"
		_:  # golems: golem, arcane_colossus, temple_guardian, starborn
			skin_color = tint
			hair_color = tint * 0.8
			shirt_color = tint * 0.95
			pants_color = tint * 0.85
			boot_color = tint * 0.7
			_weapon_type = &"unarmed"
	_build()


func set_weapon(weapon_type: StringName, has_shield: bool) -> void:
	_weapon_type = weapon_type
	_has_shield = has_shield
	if _root:
		_build_weapon()


func _build() -> void:
	if _attack_tween:
		_attack_tween.kill()
	if _dodge_tween:
		_dodge_tween.kill()
	if _root:
		_root.free()
	_parts.clear()
	_root = Node3D.new()
	add_child(_root)
	# Legs: hip -> thigh, knee -> shin + boot.
	_leg_l = _pivot(_root, Vector3(-0.14, 0.72, 0))
	_part(_leg_l, Vector3(0, -0.17, 0), Vector3(0.22, 0.36, 0.24), pants_color)
	_shin_l = _pivot(_leg_l, Vector3(0, -0.34, 0))
	_part(_shin_l, Vector3(0, -0.12, 0), Vector3(0.21, 0.26, 0.23), pants_color * 0.95)
	_part(_shin_l, Vector3(0, -0.29, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	_leg_r = _pivot(_root, Vector3(0.14, 0.72, 0))
	_part(_leg_r, Vector3(0, -0.17, 0), Vector3(0.22, 0.36, 0.24), pants_color)
	_shin_r = _pivot(_leg_r, Vector3(0, -0.34, 0))
	_part(_shin_r, Vector3(0, -0.12, 0), Vector3(0.21, 0.26, 0.23), pants_color * 0.95)
	_part(_shin_r, Vector3(0, -0.29, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	# Torso
	_torso = _pivot(_root, Vector3(0, 0.72, 0))
	_part(_torso, Vector3(0, 0.3, 0), Vector3(0.56, 0.6, 0.32), shirt_color)
	_part(_torso, Vector3(0, 0.03, 0), Vector3(0.58, 0.1, 0.34), Color(0.4, 0.28, 0.16))  # belt
	# Head
	_head = _pivot(_torso, Vector3(0, 0.62, 0))
	_part(_head, Vector3(0, 0.24, 0), Vector3(0.46, 0.46, 0.44), skin_color)
	if _class_id == &"player":
		_build_hair()
	else:
		_part(_head, Vector3(0, 0.49, -0.02), Vector3(0.5, 0.12, 0.48), hair_color)
		_part(_head, Vector3(0, 0.33, -0.2), Vector3(0.5, 0.3, 0.1), hair_color)
	_part(_head, Vector3(-0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))  # eyes
	_part(_head, Vector3(0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))
	# Arms: shoulder -> upper arm, elbow -> forearm + hand.
	_arm_l = _pivot(_torso, Vector3(-0.36, 0.54, 0))
	_part(_arm_l, Vector3(0, -0.13, 0), Vector3(0.18, 0.28, 0.2), shirt_color * 0.92)
	_fore_l = _pivot(_arm_l, Vector3(0, -0.26, 0))
	_part(_fore_l, Vector3(0, -0.09, 0), Vector3(0.17, 0.2, 0.19), shirt_color * 0.88)
	_part(_fore_l, Vector3(0, -0.24, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_arm_r = _pivot(_torso, Vector3(0.36, 0.54, 0))
	_part(_arm_r, Vector3(0, -0.13, 0), Vector3(0.18, 0.28, 0.2), shirt_color * 0.92)
	_fore_r = _pivot(_arm_r, Vector3(0, -0.26, 0))
	_part(_fore_r, Vector3(0, -0.09, 0), Vector3(0.17, 0.2, 0.19), shirt_color * 0.88)
	_part(_fore_r, Vector3(0, -0.24, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_build_class_gear()
	_weapon = _pivot(_fore_r, Vector3(0, -0.26, 0.05))
	_shield = _pivot(_fore_l, Vector3(-0.1, -0.09, 0.08))
	_build_weapon()
	if _ghost:
		set_ghost(true)


func _build_class_gear() -> void:
	var a := _accent
	match _class_id:
		&"player":
			for item: ItemData in _outfit:
				_build_outfit_piece(item.outfit_look, item.icon_color)
		&"mon_skeleton", &"mon_skeleton_archer", &"mon_bone_king":
			_part(_head, Vector3(-0.1, 0.26, 0.23), Vector3(0.1, 0.1, 0.02), a)  # glowing eyes
			_part(_head, Vector3(0.1, 0.26, 0.23), Vector3(0.1, 0.1, 0.02), a)
			_part(_head, Vector3(0, 0.08, 0.2), Vector3(0.3, 0.08, 0.06), Color(0.15, 0.12, 0.1))  # jaw gap
			for k in 3:
				_part(_torso, Vector3(0, 0.15 + k * 0.15, 0.17), Vector3(0.46, 0.04, 0.02), Color(0.2, 0.18, 0.16))  # ribs
			if _class_id == &"mon_skeleton_archer":
				_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.52, 0.38, 0.5), Color(0.3, 0.25, 0.22))  # hood
			if _class_id == &"mon_bone_king":
				var gold := Color(0.95, 0.75, 0.2)
				_part(_head, Vector3(0, 0.56, 0), Vector3(0.5, 0.12, 0.48), gold)
				for cx in [-0.2, 0.0, 0.2]:
					_part(_head, Vector3(cx, 0.68, 0.2), Vector3(0.09, 0.14, 0.06), gold)
				_part(_torso, Vector3(0, 0.25, -0.2), Vector3(0.66, 0.9, 0.06), Color(0.45, 0.1, 0.12))  # cape
		&"mon_cultist", &"mon_warden":
			_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.54, 0.42, 0.5), shirt_color * 0.8)  # hood
			_part(_head, Vector3(-0.1, 0.26, 0.23), Vector3(0.08, 0.06, 0.02), a)
			_part(_head, Vector3(0.1, 0.26, 0.23), Vector3(0.08, 0.06, 0.02), a)
			_part(_torso, Vector3(0, -0.12, 0), Vector3(0.62, 0.4, 0.38), shirt_color * 0.9)  # robe skirt
			_part(_torso, Vector3(0, 0.3, 0.17), Vector3(0.14, 0.5, 0.02), a)  # sash
			if _class_id == &"mon_warden":
				_part(_head, Vector3(0, 0.62, 0), Vector3(0.66, 0.06, 0.64), shirt_color * 0.7)
				_part(_head, Vector3(0, 0.8, 0), Vector3(0.3, 0.3, 0.3), shirt_color * 0.75)
		&"mon_golem", &"mon_arcane_colossus", &"mon_temple_guardian":
			_part(_torso, Vector3(0, 0.3, 0.18), Vector3(0.24, 0.24, 0.04), a)  # glowing core
			_part(_torso, Vector3(-0.42, 0.6, 0), Vector3(0.34, 0.26, 0.4), skin_color * 0.9)  # boulder shoulders
			_part(_torso, Vector3(0.42, 0.6, 0), Vector3(0.34, 0.26, 0.4), skin_color * 0.9)
			_part(_head, Vector3(0, 0.26, 0.23), Vector3(0.34, 0.06, 0.02), a)  # eye slit
			if _class_id == &"mon_arcane_colossus":
				for k in 3:
					_part(_torso, Vector3(-0.2 + k * 0.2, 0.9 + (k % 2) * 0.1, -0.1), Vector3(0.1, 0.3, 0.1), a)
			if _class_id == &"mon_temple_guardian":
				_part(_torso, Vector3(0, 0.75, -0.15), Vector3(0.7, 0.7, 0.05), Color(0.95, 0.78, 0.3))  # sun disk
		&"mon_bandit", &"mon_bandit_archer", &"mon_bandit_brute", &"mon_bandit_hexer", &"mon_bandit_bomber", &"mon_warlord":
			_part(_torso, Vector3(0, 0.3, 0.17), Vector3(0.5, 0.5, 0.04), Color(0.45, 0.3, 0.18))  # leather vest
			_part(_torso, Vector3(0.12, 0.3, 0.19), Vector3(0.08, 0.56, 0.02), Color(0.3, 0.2, 0.12))  # strap
			match _class_id:
				&"mon_bandit", &"mon_bandit_bomber":
					_part(_head, Vector3(0, 0.46, 0), Vector3(0.5, 0.12, 0.48), a)  # bandana
					_part(_head, Vector3(0, 0.12, 0.22), Vector3(0.44, 0.16, 0.04), a * 0.8)  # face cloth
					if _class_id == &"mon_bandit_bomber":
						_part(_torso, Vector3(0, 0.2, -0.22), Vector3(0.4, 0.4, 0.16), Color(0.4, 0.3, 0.2))  # bomb satchel
						_part(_torso, Vector3(0.12, 0.45, -0.25), Vector3(0.14, 0.14, 0.14), Color(0.15, 0.15, 0.15))
				&"mon_bandit_archer":
					_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.52, 0.38, 0.5), a * 0.7)  # hood
					_part(_torso, Vector3(0.15, 0.35, -0.22), Vector3(0.16, 0.5, 0.14), Color(0.45, 0.3, 0.18))  # quiver
				&"mon_bandit_brute":
					_part(_head, Vector3(0, 0.08, 0.2), Vector3(0.36, 0.16, 0.08), hair_color)  # beard
					_part(_torso, Vector3(-0.4, 0.6, 0), Vector3(0.26, 0.14, 0.3), Color(0.5, 0.5, 0.55))  # pauldron
				&"mon_bandit_hexer":
					_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.54, 0.42, 0.5), shirt_color * 0.75)  # hood
					_part(_head, Vector3(-0.1, 0.26, 0.23), Vector3(0.08, 0.06, 0.02), a)
					_part(_head, Vector3(0.1, 0.26, 0.23), Vector3(0.08, 0.06, 0.02), a)
					_part(_torso, Vector3(0, -0.12, 0), Vector3(0.6, 0.38, 0.36), shirt_color * 0.85)  # robe skirt
				&"mon_warlord":
					var iron := Color(0.45, 0.45, 0.5)
					_part(_head, Vector3(0, 0.38, 0), Vector3(0.54, 0.32, 0.52), iron)  # helm
					_part(_head, Vector3(0.3, 0.56, 0), Vector3(0.1, 0.26, 0.1), Color(0.95, 0.92, 0.82))  # horns
					_part(_head, Vector3(-0.3, 0.56, 0), Vector3(0.1, 0.26, 0.1), Color(0.95, 0.92, 0.82))
					_part(_torso, Vector3(0, 0.62, -0.02), Vector3(0.74, 0.16, 0.42), Color(0.35, 0.25, 0.18))  # fur mantle
					_part(_torso, Vector3(0, 0.25, -0.2), Vector3(0.66, 0.9, 0.06), a)  # war cape
		&"mon_goblin":
			_part(_head, Vector3(0.3, 0.3, 0), Vector3(0.2, 0.08, 0.06), skin_color)  # pointy ears
			_part(_head, Vector3(-0.3, 0.3, 0), Vector3(0.2, 0.08, 0.06), skin_color)
			_part(_head, Vector3(-0.1, 0.26, 0.23), Vector3(0.08, 0.08, 0.02), Color(1, 0.9, 0.2))
			_part(_head, Vector3(0.1, 0.26, 0.23), Vector3(0.08, 0.08, 0.02), Color(1, 0.9, 0.2))
			_part(_torso, Vector3(0, 0.45, -0.32), Vector3(0.56, 0.6, 0.4), Color(0.6, 0.48, 0.3))  # loot sack
			_part(_torso, Vector3(0, 0.8, -0.32), Vector3(0.2, 0.1, 0.2), Color(0.95, 0.78, 0.25))  # gold peeking out
		&"mon_starborn":
			_part(_torso, Vector3(0, 0.3, 0.18), Vector3(0.28, 0.28, 0.04), a)  # star core
			_part(_torso, Vector3(-0.42, 0.6, 0), Vector3(0.34, 0.26, 0.4), skin_color * 0.9)
			_part(_torso, Vector3(0.42, 0.6, 0), Vector3(0.34, 0.26, 0.4), skin_color * 0.9)
			_part(_head, Vector3(0, 0.26, 0.23), Vector3(0.34, 0.06, 0.02), a)
			for k in 5:
				var ang := k * TAU / 5.0
				_part(_head, Vector3(cos(ang) * 0.3, 0.62, sin(ang) * 0.3), Vector3(0.08, 0.22, 0.08), a)  # star crown
		&"npc_farmer":
			_part(_head, Vector3(0, 0.52, 0), Vector3(0.74, 0.06, 0.72), Color(0.9, 0.78, 0.4))  # straw hat
			_part(_head, Vector3(0, 0.62, 0), Vector3(0.4, 0.16, 0.4), Color(0.85, 0.72, 0.35))
		&"npc_blacksmith":
			_part(_torso, Vector3(0, 0.2, 0.18), Vector3(0.5, 0.62, 0.04), Color(0.35, 0.22, 0.14))  # apron
			_part(_head, Vector3(0, 0.08, 0.2), Vector3(0.36, 0.16, 0.08), hair_color)  # beard
		&"npc_merchant", &"npc_royal_merchant":
			_part(_head, Vector3(0, 0.54, 0), Vector3(0.5, 0.14, 0.48), a if _class_id == &"npc_royal_merchant" else Color(0.55, 0.2, 0.2))  # cap
			_part(_torso, Vector3(0, 0.2, 0.18), Vector3(0.44, 0.4, 0.04), Color(0.9, 0.88, 0.8))  # apron
		&"npc_guard":
			_part(_head, Vector3(0, 0.38, 0), Vector3(0.52, 0.3, 0.5), Color(0.6, 0.62, 0.68))  # helm
			_part(_torso, Vector3(0, 0.3, 0.17), Vector3(0.46, 0.5, 0.04), a)  # tabard
		&"npc_noble":
			var gold := Color(0.95, 0.78, 0.25)
			_part(_head, Vector3(0, 0.56, 0), Vector3(0.46, 0.1, 0.44), gold)  # crown
			for cx in [-0.18, 0.0, 0.18]:
				_part(_head, Vector3(cx, 0.65, 0.18), Vector3(0.08, 0.1, 0.06), gold)
			_part(_torso, Vector3(0, 0.25, -0.2), Vector3(0.62, 0.8, 0.06), a)  # cape
		&"npc_trader":
			_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.52, 0.38, 0.5), Color(0.45, 0.35, 0.25))  # hood
			_part(_torso, Vector3(0, 0.35, -0.3), Vector3(0.44, 0.56, 0.3), Color(0.55, 0.4, 0.25))  # backpack
			_part(_torso, Vector3(0, 0.7, -0.3), Vector3(0.5, 0.16, 0.32), Color(0.8, 0.75, 0.6))  # bedroll


## Every outfit look a piece of gear can have (ItemData.outfit_look).
const OUTFIT_LOOKS := [
	&"hood_padded", &"sun_hat", &"fur_cap", &"wizard_hat", &"helm_plume", &"horned_helm", &"hood_mask",
	&"great_helm", &"crown_stars",
	&"vest", &"robe", &"jerkin", &"chainmail", &"cloak", &"plate",
	&"fur_mantle",
	&"gloves", &"gauntlets", &"bracers", &"wraps",
	&"boots", &"fur_boots", &"greaves",
	&"buckler", &"kite", &"aegis",
	&"pendant",
]


## Draws one piece of gear on the shared body, tinted with the item colour `c`.
## Overlays are a little bigger than the body parts they cover.
func _build_outfit_piece(look: StringName, c: Color) -> void:
	var dark := c.darkened(0.25)
	var light := c.lightened(0.25)
	var slit := Color(0.12, 0.12, 0.15)
	match look:
		# --- Head ---
		&"hood_padded":
			_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.53, 0.4, 0.5), c)
			_part(_head, Vector3(0, 0.08, 0.0), Vector3(0.5, 0.08, 0.48), dark)  # collar
		&"sun_hat":
			_part(_head, Vector3(0, 0.52, 0), Vector3(0.74, 0.06, 0.72), c)
			_part(_head, Vector3(0, 0.62, 0), Vector3(0.4, 0.16, 0.4), dark)
		&"fur_cap":
			_part(_head, Vector3(0, 0.5, -0.02), Vector3(0.52, 0.16, 0.5), c)
			_part(_head, Vector3(0, 0.42, 0), Vector3(0.56, 0.08, 0.54), light)  # fur rim
			_part(_head, Vector3(0.27, 0.3, 0), Vector3(0.06, 0.2, 0.18), c)  # ear flaps
			_part(_head, Vector3(-0.27, 0.3, 0), Vector3(0.06, 0.2, 0.18), c)
		&"wizard_hat":
			_part(_head, Vector3(0, 0.52, 0), Vector3(0.62, 0.06, 0.6), c * 0.8)  # brim
			_part(_head, Vector3(0, 0.68, 0), Vector3(0.36, 0.28, 0.36), c * 0.85)
			_part(_head, Vector3(0.03, 0.88, -0.03), Vector3(0.2, 0.2, 0.2), c * 0.9)
			_part(_head, Vector3(0.06, 1.02, -0.06), Vector3(0.1, 0.12, 0.1), Color(0.4, 0.85, 1.0))  # glowing tip
		&"helm_plume":
			_part(_head, Vector3(0, 0.36, 0), Vector3(0.52, 0.34, 0.5), c)
			_part(_head, Vector3(0, 0.26, 0.24), Vector3(0.36, 0.06, 0.04), slit)  # visor slit
			_part(_head, Vector3(0, 0.6, -0.05), Vector3(0.08, 0.14, 0.34), Color(0.75, 0.2, 0.2))  # plume
		&"horned_helm":
			_part(_head, Vector3(0, 0.42, 0), Vector3(0.52, 0.22, 0.5), c)
			_part(_head, Vector3(0, 0.34, 0.24), Vector3(0.08, 0.2, 0.04), dark)  # nose guard
			_part(_head, Vector3(0.3, 0.56, 0), Vector3(0.1, 0.24, 0.1), Color(0.95, 0.92, 0.82))  # horns
			_part(_head, Vector3(-0.3, 0.56, 0), Vector3(0.1, 0.24, 0.1), Color(0.95, 0.92, 0.82))
		&"hood_mask":
			# Open at the front so the eyes show between hood and mask.
			_part(_head, Vector3(0, 0.36, -0.07), Vector3(0.54, 0.42, 0.5), c)
			_part(_head, Vector3(0, 0.52, 0.2), Vector3(0.54, 0.1, 0.08), dark)  # brow
			_part(_head, Vector3(0, 0.1, 0.23), Vector3(0.44, 0.16, 0.04), slit)  # face mask
		&"great_helm":
			_part(_head, Vector3(0, 0.27, 0), Vector3(0.54, 0.54, 0.52), c)
			_part(_head, Vector3(0, 0.28, 0.265), Vector3(0.38, 0.05, 0.02), slit)  # eye slit
			_part(_head, Vector3(0, 0.15, 0.265), Vector3(0.05, 0.14, 0.02), slit)  # breathing slit
			_part(_head, Vector3(0, 0.56, 0), Vector3(0.1, 0.06, 0.5), dark)  # crest
		&"crown_stars":
			_part(_head, Vector3(0, 0.54, 0), Vector3(0.5, 0.1, 0.48), c)
			for k in 5:
				var ang := k * TAU / 5.0
				_part(_head, Vector3(cos(ang) * 0.24, 0.66, sin(ang) * 0.24), Vector3(0.07, 0.16, 0.07), Color(0.65, 0.8, 1.0))
		# --- Chest ---
		&"vest":
			_part(_torso, Vector3(0, 0.32, 0), Vector3(0.6, 0.56, 0.36), c)
			for k in 3:
				_part(_torso, Vector3(0, 0.16 + k * 0.16, 0.185), Vector3(0.5, 0.03, 0.01), dark)  # quilting
		&"robe":
			_part(_torso, Vector3(0, 0.31, 0), Vector3(0.6, 0.62, 0.36), c)
			_part(_torso, Vector3(0, -0.14, 0), Vector3(0.62, 0.4, 0.38), c * 0.9)  # skirt
			_part(_torso, Vector3(0, 0.3, 0.185), Vector3(0.12, 0.56, 0.01), Color(0.95, 0.8, 0.35))  # trim
			_sleeves(c)
		&"jerkin":
			_part(_torso, Vector3(0, 0.3, 0.0), Vector3(0.6, 0.54, 0.36), c)
			_part(_torso, Vector3(0.12, 0.3, 0.185), Vector3(0.08, 0.56, 0.01), dark)  # strap
			_part(_torso, Vector3(0, 0.62, 0), Vector3(0.62, 0.08, 0.38), dark)  # collar
		&"chainmail":
			_part(_torso, Vector3(0, 0.3, 0), Vector3(0.6, 0.62, 0.36), c)
			_part(_torso, Vector3(0, -0.08, 0), Vector3(0.62, 0.22, 0.38), c * 0.92)  # skirt
			_sleeves(c)
			for k in 4:
				_part(_torso, Vector3(0, 0.08 + k * 0.15, 0.185), Vector3(0.52, 0.02, 0.01), dark)  # rings
		&"cloak":
			_part(_torso, Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.36), c.darkened(0.15))  # dark tunic under the cape
			_sleeves(c.darkened(0.15))
			_part(_torso, Vector3(0, 0.22, -0.2), Vector3(0.62, 0.86, 0.06), c)  # cape
			_part(_torso, Vector3(0, 0.62, 0), Vector3(0.64, 0.1, 0.4), c)  # collar
			_part(_torso, Vector3(0, 0.62, 0.21), Vector3(0.1, 0.08, 0.02), Color(0.8, 0.8, 0.85))  # clasp
		&"plate":
			_part(_torso, Vector3(0, 0.32, 0.0), Vector3(0.6, 0.6, 0.36), c * 0.9)
			_part(_torso, Vector3(0, 0.36, 0.185), Vector3(0.46, 0.42, 0.02), light)  # breastplate
			_part(_torso, Vector3(-0.4, 0.6, 0), Vector3(0.26, 0.14, 0.28), c)  # pauldrons
			_part(_torso, Vector3(0.4, 0.6, 0), Vector3(0.26, 0.14, 0.28), c)
			_part(_torso, Vector3(0, -0.08, 0), Vector3(0.62, 0.18, 0.38), c * 0.85)  # faulds
		&"fur_mantle":  # Raider's Fur Harness (Milestone 14 sets)
			_part(_torso, Vector3(0, 0.62, -0.02), Vector3(0.7, 0.14, 0.4), light)  # fur mantle
			_part(_torso, Vector3(0, 0.3, 0.17), Vector3(0.44, 0.36, 0.04), dark)  # harness
			_part(_torso, Vector3(-0.12, 0.3, 0.19), Vector3(0.08, 0.56, 0.02), c.darkened(0.45))  # strap
		# --- Hands ---
		&"gloves":
			_part(_fore_l, Vector3(0, -0.23, 0), Vector3(0.19, 0.17, 0.19), c)
			_part(_fore_r, Vector3(0, -0.23, 0), Vector3(0.19, 0.17, 0.19), c)
		&"gauntlets":
			for fore in [_fore_l, _fore_r]:
				_part(fore, Vector3(0, -0.23, 0), Vector3(0.21, 0.18, 0.21), c)
				_part(fore, Vector3(0, -0.11, 0), Vector3(0.21, 0.12, 0.22), dark)  # cuff
		&"bracers":
			for fore in [_fore_l, _fore_r]:
				_part(fore, Vector3(0, -0.11, 0), Vector3(0.2, 0.14, 0.21), c)
				_part(fore, Vector3(0, -0.11, 0.1), Vector3(0.08, 0.06, 0.03), Color(0.75, 0.75, 0.8))  # stud
		&"wraps":
			for fore in [_fore_l, _fore_r]:
				_part(fore, Vector3(0, -0.23, 0), Vector3(0.18, 0.15, 0.18), c)
				_part(fore, Vector3(0, -0.14, 0), Vector3(0.18, 0.05, 0.2), light)
		# --- Feet ---
		&"boots":
			_part(_shin_l, Vector3(0, -0.28, 0.03), Vector3(0.27, 0.22, 0.33), c)
			_part(_shin_r, Vector3(0, -0.28, 0.03), Vector3(0.27, 0.22, 0.33), c)
		&"fur_boots":
			for shin in [_shin_l, _shin_r]:
				_part(shin, Vector3(0, -0.28, 0.03), Vector3(0.27, 0.22, 0.33), c)
				_part(shin, Vector3(0, -0.15, 0.0), Vector3(0.27, 0.08, 0.27), light)  # fur rim
		&"greaves":
			for shin in [_shin_l, _shin_r]:
				_part(shin, Vector3(0, -0.28, 0.03), Vector3(0.27, 0.22, 0.33), dark)
				_part(shin, Vector3(0, -0.1, 0.0), Vector3(0.25, 0.24, 0.26), c)  # shin plate
		# --- Amulet ---
		&"pendant":
			_part(_torso, Vector3(0, 0.5, 0.18), Vector3(0.08, 0.08, 0.03), c)
		# Shields (buckler / kite / aegis) are drawn by _build_weapon().


## The player's hair and beard (CharacterLook style). Helmets, hoods and caps
## hide the hair; a face mask hides the beard.
func _build_hair() -> void:
	var looks := outfit_looks()
	var covered := false
	for l in [&"hood_padded", &"fur_cap", &"helm_plume", &"horned_helm", &"hood_mask", &"great_helm"]:
		covered = covered or l in looks
	var style := CharacterLook.hair_style(_body)
	if not covered and style != &"bald":
		_part(_head, Vector3(0, 0.49, -0.02), Vector3(0.5, 0.12, 0.48), hair_color)
		match style:
			&"long":
				_part(_head, Vector3(0, 0.22, -0.21), Vector3(0.52, 0.56, 0.1), hair_color)
				_part(_head, Vector3(-0.24, 0.3, -0.04), Vector3(0.06, 0.34, 0.3), hair_color)
				_part(_head, Vector3(0.24, 0.3, -0.04), Vector3(0.06, 0.34, 0.3), hair_color)
			&"topknot":
				_part(_head, Vector3(0, 0.36, -0.2), Vector3(0.5, 0.24, 0.1), hair_color)
				_part(_head, Vector3(0, 0.62, -0.08), Vector3(0.18, 0.16, 0.18), hair_color)
			_:
				_part(_head, Vector3(0, 0.33, -0.2), Vector3(0.5, 0.3, 0.1), hair_color)
	if bool(_body.get("beard", false)) and not (&"hood_mask" in looks or &"great_helm" in looks):
		var long_beard: bool = style == &"long"
		_part(_head, Vector3(0, 0.04 if long_beard else 0.08, 0.2), Vector3(0.36, 0.24 if long_beard else 0.16, 0.08), hair_color)


## Long sleeves in colour `c` over the upper arms.
func _sleeves(c: Color) -> void:
	_part(_arm_l, Vector3(0, -0.13, 0), Vector3(0.21, 0.3, 0.23), c * 0.92)
	_part(_arm_r, Vector3(0, -0.13, 0), Vector3(0.21, 0.3, 0.23), c * 0.92)


## The off-hand item's shield look and colour, if the player carries one.
func _shield_item() -> ItemData:
	for item: ItemData in _outfit:
		if item.equip_slot == ItemData.EquipSlot.OFF_HAND:
			return item
	return null


func _build_weapon() -> void:
	for holder in [_weapon, _shield]:
		for c in holder.get_children():
			if c is MeshInstance3D:
				_parts.erase(c as MeshInstance3D)
			c.free()
	var wood := Color(0.42, 0.28, 0.16)
	var steel := weapon_color
	match _weapon_type:
		&"sword":
			_part(_weapon, Vector3(0, 0, 0.12), Vector3(0.08, 0.08, 0.2), Color(0.35, 0.22, 0.12))
			_part(_weapon, Vector3(0, 0, 0.24), Vector3(0.3, 0.06, 0.06), Color(0.75, 0.6, 0.25))
			_part(_weapon, Vector3(0, 0, 0.62), Vector3(0.1, 0.04, 0.7), steel)
		&"axe":
			_part(_weapon, Vector3(0, 0, 0.35), Vector3(0.08, 0.08, 0.85), wood)
			_part(_weapon, Vector3(0.14, 0, 0.66), Vector3(0.28, 0.05, 0.3), steel)
			_part(_weapon, Vector3(0.3, 0, 0.66), Vector3(0.06, 0.05, 0.38), steel * 1.1)
		&"dagger":
			_part(_weapon, Vector3(0, 0, 0.08), Vector3(0.07, 0.07, 0.14), Color(0.2, 0.15, 0.12))
			_part(_weapon, Vector3(0, 0, 0.17), Vector3(0.18, 0.05, 0.04), Color(0.5, 0.5, 0.55))
			_part(_weapon, Vector3(0, 0, 0.36), Vector3(0.07, 0.03, 0.34), steel)
			# Off-hand dagger for dual wield look.
			_part(_shield, Vector3(0.1, -0.1, 0.2), Vector3(0.06, 0.03, 0.3), steel)
		&"staff":
			_part(_weapon, Vector3(0, 0, 0.35), Vector3(0.07, 0.07, 1.5), wood)
			var orb := _weapon_item.icon_color.lightened(0.2) if _weapon_item and _class_id == &"player" else _accent
			_part(_weapon, Vector3(0, 0, 1.12), Vector3(0.18, 0.18, 0.18), orb)
		&"unarmed":
			pass
		&"hammer":
			_part(_weapon, Vector3(0, 0, 0.25), Vector3(0.07, 0.07, 0.5), wood)
			_part(_weapon, Vector3(0, 0, 0.52), Vector3(0.12, 0.3, 0.14), steel * 0.7)
		&"hoe":
			_part(_weapon, Vector3(0, 0, 0.4), Vector3(0.06, 0.06, 1.1), wood)
			_part(_weapon, Vector3(0, -0.1, 0.92), Vector3(0.05, 0.25, 0.14), steel * 0.8)
		&"bow":
			_part(_weapon, Vector3(0, 0.25, 0.15), Vector3(0.05, 0.5, 0.05), wood)
			_part(_weapon, Vector3(0, -0.25, 0.15), Vector3(0.05, 0.5, 0.05), wood)
			_part(_weapon, Vector3(0, 0, 0.3), Vector3(0.04, 0.2, 0.04), wood)
			_part(_weapon, Vector3(0, 0, 0.08), Vector3(0.02, 0.9, 0.02), Color(0.9, 0.9, 0.85))
		&"spear":
			_part(_weapon, Vector3(0, 0, 0.5), Vector3(0.07, 0.07, 1.6), wood)
			_part(_weapon, Vector3(0, 0, 1.36), Vector3(0.08, 0.04, 0.24), steel)
		_:
			_part(_weapon, Vector3(0, 0, 0.5), Vector3(0.1, 0.1, 0.8), steel)
	# Trail anchor at the business end of the weapon.
	const TIPS := {&"sword": 0.95, &"axe": 0.8, &"dagger": 0.52, &"staff": 1.2, &"hammer": 0.6, &"hoe": 0.95, &"spear": 1.45, &"bow": 0.3}
	_tip = Node3D.new()
	_tip.position = Vector3(0, 0, float(TIPS.get(_weapon_type, 0.4)))
	_weapon.add_child(_tip)
	if _has_shield:
		var si := _shield_item() if _class_id == &"player" else null
		var look := si.outfit_look if si else &""
		var c := si.icon_color if si else Color(0.5, 0.32, 0.18)
		match look:
			&"buckler":
				_part(_shield, Vector3(-0.05, 0, 0.1), Vector3(0.08, 0.42, 0.42), c)
				_part(_shield, Vector3(-0.1, 0, 0.1), Vector3(0.04, 0.14, 0.14), Color(0.7, 0.7, 0.75))  # boss
			&"kite":
				_part(_shield, Vector3(-0.05, 0.04, 0.1), Vector3(0.08, 0.62, 0.46), c)
				_part(_shield, Vector3(-0.05, -0.32, 0.1), Vector3(0.08, 0.14, 0.24), c)  # point
				_part(_shield, Vector3(-0.1, 0.04, 0.1), Vector3(0.04, 0.46, 0.08), Color(0.7, 0.2, 0.2))  # cross
				_part(_shield, Vector3(-0.1, 0.12, 0.1), Vector3(0.04, 0.08, 0.32), Color(0.7, 0.2, 0.2))
			&"aegis":
				_part(_shield, Vector3(-0.05, 0, 0.1), Vector3(0.08, 0.62, 0.52), c)
				_part(_shield, Vector3(-0.1, 0, 0.1), Vector3(0.04, 0.26, 0.26), Color(1.0, 0.95, 0.7))  # sun
				for k in 4:
					var ang := k * TAU / 4.0 + PI * 0.25
					_part(_shield, Vector3(-0.1, sin(ang) * 0.2, 0.1 + cos(ang) * 0.2), Vector3(0.03, 0.08, 0.08), Color(1.0, 0.95, 0.7))
			_:
				_part(_shield, Vector3(-0.05, 0, 0.1), Vector3(0.08, 0.55, 0.45), Color(0.5, 0.32, 0.18))
				_part(_shield, Vector3(-0.1, 0, 0.1), Vector3(0.04, 0.2, 0.2), _accent)


## Stealth look: parts become translucent.
func set_ghost(on: bool) -> void:
	_ghost = on
	for p in _parts:
		if is_instance_valid(p):
			p.transparency = 0.7 if on else 0.0


func play_spin(duration: float) -> void:
	if _dodge_tween:
		_dodge_tween.kill()
	_dodge_tween = create_tween()
	_dodge_tween.tween_property(_root, "rotation:y", TAU * 2.0, duration).from(0.0)
	_dodge_tween.tween_callback(func() -> void: _root.rotation.y = 0.0)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, size, color)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.position = pos
	parent.add_child(mi)
	_parts.append(mi)
	return mi


## `speed_ratio` 0..1+ (1 = running).
func set_locomotion(speed_ratio: float, delta: float) -> void:
	_move_amount = lerpf(_move_amount, clampf(speed_ratio, 0.0, 1.4), 1.0 - exp(-12.0 * delta))
	_walk_phase += delta * (4.0 + 7.0 * _move_amount) * (1.0 if _move_amount > 0.05 else 0.0)


func set_blocking(value: bool) -> void:
	_blocking = value


func play_attack(anim: StringName, windup: float, active: float, recovery: float) -> void:
	if _attack_tween:
		_attack_tween.kill()
	# Poses: x = arm pitch (negative = raised forward/up), y = arm yaw, torso twist.
	var ready_pose := Vector3(-2.2, 0.9, -0.5)
	var strike_pose := Vector3(-1.3, -1.1, 0.6)
	match anim:
		&"slash_l":
			ready_pose = Vector3(-1.4, -1.2, 0.6)
			strike_pose = Vector3(-1.5, 1.0, -0.6)
		&"thrust":
			ready_pose = Vector3(-0.9, 0.2, -0.3)
			strike_pose = Vector3(-1.7, 0.0, 0.3)
		&"overhead":
			ready_pose = Vector3(-3.0, 0.1, -0.2)
			strike_pose = Vector3(-0.6, 0.0, 0.2)
	anim_event.emit("attack", [String(anim), windup, active, recovery])
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_attack_pose, Vector3(_attack_arm.x, _attack_arm.y, _attack_torso), ready_pose, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_callback(func() -> void: _set_trail(true))
	_attack_tween.tween_method(_set_attack_pose, ready_pose, strike_pose, maxf(active, 0.05)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_callback(func() -> void: _set_trail(false))
	_attack_tween.tween_method(_set_attack_pose, strike_pose, Vector3.ZERO, recovery).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _set_attack_pose(v: Vector3) -> void:
	_attack_arm = Vector2(v.x, v.y)
	_attack_torso = v.z


func cancel_attack() -> void:
	if _attack_tween:
		_attack_tween.kill()
	_set_trail(false)
	_attack_arm = Vector2.ZERO
	_attack_torso = 0.0


func play_dodge(duration: float) -> void:
	anim_event.emit("dodge", [duration])
	if _dodge_tween:
		_dodge_tween.kill()
	_root.rotation.x = 0.0
	_dodge_tween = create_tween()
	_dodge_tween.tween_property(_root, "rotation:x", TAU, duration).set_trans(Tween.TRANS_SINE)
	_dodge_tween.tween_callback(func() -> void: _root.rotation.x = 0.0)


func flash() -> void:
	_flash_time = 0.1
	for p in _parts:
		p.material_overlay = Materials.hit_flash()


func play_stagger() -> void:
	var tw := create_tween()
	tw.tween_property(_torso, "rotation:x", -0.5, 0.08)
	tw.tween_property(_torso, "rotation:x", 0.0, 0.3)


func play_death() -> void:
	anim_event.emit("death", [])
	cancel_attack()
	var tw := create_tween()
	# Knees buckle, then the body topples over.
	tw.tween_property(_root, "position:y", -0.12, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "rotation:z", PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "position:y", 0.25, 0.45)


func reset_pose() -> void:
	cancel_attack()
	_root.rotation = Vector3.ZERO
	_root.position = Vector3.ZERO
	_root.scale = Vector3.ONE
	_torso.rotation = Vector3.ZERO


## Jumping/falling and swimming poses (the player calls this every frame).
func set_air_state(airborne: bool, swimming: bool) -> void:
	_airborne = airborne
	_swimming = swimming


## Squash on landing (strength 0..1 from the fall speed).
func play_land(strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector3(1.0 + 0.12 * s, 1.0 - 0.18 * s, 1.0 + 0.12 * s), 0.06)
	tw.tween_property(_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Both hands raised forward for `duration` seconds (spells).
func play_cast(duration: float = 0.5) -> void:
	anim_event.emit("cast", [duration])
	_cast_len = maxf(duration, 0.2)
	_cast_t = _cast_len


func _set_trail(on: bool) -> void:
	if _tip == null or _weapon_type in [&"unarmed", &"bow"]:
		return
	if _trail == null or not is_instance_valid(_trail):
		_trail = WeaponTrail.new()
		add_child(_trail)
	_trail.base = _weapon
	_trail.tip = _tip
	_trail.color = _accent.lightened(0.3) if _weapon_type == &"staff" else Color(1, 1, 1)
	_trail.active = on


func _process(delta: float) -> void:
	_time += delta
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			for p in _parts:
				p.material_overlay = null
	var m := minf(_move_amount, 1.0)
	_swim_blend = move_toward(_swim_blend, 1.0 if _swimming else 0.0, delta * 4.0)
	_air_blend = move_toward(_air_blend, 1.0 if _airborne and not _swimming else 0.0, delta * 8.0)
	var swing := sin(_walk_phase) * 0.9 * m
	# Footsteps: one per half cycle while moving on the ground.
	var sgn := signf(sin(_walk_phase))
	if m > 0.2 and sgn != _last_step_sign and _air_blend < 0.5 and _swim_blend < 0.5:
		footstep.emit(sgn > 0.0)
	_last_step_sign = sgn
	# Legs with knees: the shin folds back while the leg swings forward.
	var knee_l := (0.08 + maxf(0.0, -cos(_walk_phase)) * 1.0) * m
	var knee_r := (0.08 + maxf(0.0, cos(_walk_phase)) * 1.0) * m
	_leg_l.rotation.x = lerpf(swing, -0.6, _air_blend)
	_leg_r.rotation.x = lerpf(-swing, 0.35, _air_blend)
	_shin_l.rotation.x = lerpf(knee_l, 0.9, _air_blend)
	_shin_r.rotation.x = lerpf(knee_r, 0.25, _air_blend)
	# Body: bob and lean into the run, breathe when idle.
	var bob := absf(sin(_walk_phase)) * 0.06 * m
	var breathe := sin(_time * 2.1) * 0.012 * (1.0 - m)
	_torso.position.y = 0.72 + bob + breathe
	_torso.rotation.x = 0.14 * m * minf(_move_amount, 1.4) + 0.05 * _air_blend
	_torso.rotation.y = _attack_torso
	_torso.rotation.z = 0.0
	# Idle: an occasional glance around.
	_look = lerpf(_look, sin(_time * 0.37) * sin(_time * 0.11) * 0.5 * (1.0 - m), 1.0 - exp(-3.0 * delta))
	_head.rotation.y = _look
	_head.rotation.x = -sin(_time * 2.1) * 0.02 * (1.0 - m)
	_arm_l.rotation.x = lerpf(-swing * 0.8, -2.4, _air_blend)
	_arm_l.rotation.y = 0.0
	_arm_l.rotation.z = lerpf(-0.04 - absf(breathe) * 2.0, -0.5, _air_blend)
	_fore_l.rotation.x = -0.25 - 0.35 * m
	_fore_r.rotation.x = -0.25 - 0.35 * m
	if _blocking:
		_arm_l.rotation = Vector3(-1.4, 0.6, 0.0)
		_arm_r.rotation = Vector3(-1.2, -0.9, 0.0)
		_fore_l.rotation.x = -0.3
		_fore_r.rotation.x = -0.2
		_weapon.rotation = Vector3(0.0, -1.2, 0.0)
	elif _attack_arm != Vector2.ZERO:
		_arm_r.rotation = Vector3(_attack_arm.x, _attack_arm.y, 0.0)
		_fore_r.rotation.x = -0.1
		_weapon.rotation = Vector3.ZERO
	else:
		_arm_r.rotation = Vector3(lerpf(swing * 0.8 - 0.25, -2.4, _air_blend), 0.0, lerpf(0.04, 0.5, _air_blend))
		_weapon.rotation = Vector3(-0.9 + 0.25, 0.0, 0.0)
	# Casting: both hands forward and up, a little shake of power.
	if _cast_t > 0.0:
		_cast_t -= delta
		var c := clampf(minf(_cast_t, _cast_len - _cast_t) / 0.12, 0.0, 1.0)
		var shake := sin(_time * 40.0) * 0.04
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(-1.5 + shake, 0.35, 0.0), c)
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(-1.5 - shake, -0.35, 0.0), c)
		_fore_l.rotation.x = lerpf(_fore_l.rotation.x, -0.5, c)
		_fore_r.rotation.x = lerpf(_fore_r.rotation.x, -0.5, c)
	# Swimming: body flat, crawl strokes, flutter kicks.
	var free_root := _dodge_tween == null or not _dodge_tween.is_running()
	if free_root and (_swim_blend > 0.0 or _was_swimming):
		_root.rotation.x = 1.15 * _swim_blend
		_root.position.y = 0.55 * _swim_blend
	_was_swimming = _swim_blend > 0.0
	if _swim_blend > 0.0:
		var st := _time * 5.0
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(fposmod(st, TAU) - PI, 0.0, -0.2), _swim_blend)
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(fposmod(st + PI, TAU) - PI, 0.0, 0.2), _swim_blend)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, sin(st * 2.0) * 0.4, _swim_blend)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -sin(st * 2.0) * 0.4, _swim_blend)
		_shin_l.rotation.x = lerpf(_shin_l.rotation.x, 0.15, _swim_blend)
		_shin_r.rotation.x = lerpf(_shin_r.rotation.x, 0.15, _swim_blend)
