class_name HumanoidModel
extends Node3D
## Blocky, cartoon-proportioned humanoid built from coloured boxes, with
## procedural animation (walk cycle, attack swings, dodge roll, block pose,
## hit flash). No external model or animation files needed.
##
## The public API (set_locomotion, play_attack, play_dodge, set_blocking, flash)
## is what a future skeletal/AnimationTree model must also provide.

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
var _weapon: Node3D
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


## Class look: colours + class-specific headgear/clothing.
func set_appearance(c: ClassData) -> void:
	if c == null:
		return
	_class_id = c.id
	shirt_color = c.shirt_color
	pants_color = c.pants_color
	hair_color = c.hair_color
	_accent = c.accent_color
	_build()


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
	# Legs (pivot at hip)
	_leg_l = _pivot(_root, Vector3(-0.14, 0.72, 0))
	_part(_leg_l, Vector3(0, -0.3, 0), Vector3(0.22, 0.5, 0.24), pants_color)
	_part(_leg_l, Vector3(0, -0.63, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	_leg_r = _pivot(_root, Vector3(0.14, 0.72, 0))
	_part(_leg_r, Vector3(0, -0.3, 0), Vector3(0.22, 0.5, 0.24), pants_color)
	_part(_leg_r, Vector3(0, -0.63, 0.03), Vector3(0.24, 0.18, 0.3), boot_color)
	# Torso
	_torso = _pivot(_root, Vector3(0, 0.72, 0))
	_part(_torso, Vector3(0, 0.3, 0), Vector3(0.56, 0.6, 0.32), shirt_color)
	_part(_torso, Vector3(0, 0.03, 0), Vector3(0.58, 0.1, 0.34), Color(0.4, 0.28, 0.16))  # belt
	# Head
	_head = _pivot(_torso, Vector3(0, 0.62, 0))
	_part(_head, Vector3(0, 0.24, 0), Vector3(0.46, 0.46, 0.44), skin_color)
	_part(_head, Vector3(0, 0.49, -0.02), Vector3(0.5, 0.12, 0.48), hair_color)
	_part(_head, Vector3(0, 0.33, -0.2), Vector3(0.5, 0.3, 0.1), hair_color)
	_part(_head, Vector3(-0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))  # eyes
	_part(_head, Vector3(0.1, 0.26, 0.225), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.1, 0.15))
	# Arms (pivot at shoulder)
	_arm_l = _pivot(_torso, Vector3(-0.36, 0.54, 0))
	_part(_arm_l, Vector3(0, -0.22, 0), Vector3(0.18, 0.46, 0.2), shirt_color * 0.92)
	_part(_arm_l, Vector3(0, -0.5, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_arm_r = _pivot(_torso, Vector3(0.36, 0.54, 0))
	_part(_arm_r, Vector3(0, -0.22, 0), Vector3(0.18, 0.46, 0.2), shirt_color * 0.92)
	_part(_arm_r, Vector3(0, -0.5, 0), Vector3(0.16, 0.14, 0.16), skin_color)
	_build_class_gear()
	_weapon = _pivot(_arm_r, Vector3(0, -0.52, 0.05))
	_shield = _pivot(_arm_l, Vector3(-0.1, -0.35, 0.08))
	_build_weapon()
	if _ghost:
		set_ghost(true)


func _build_class_gear() -> void:
	var a := _accent
	match _class_id:
		&"barbarian":
			_part(_head, Vector3(0.27, 0.52, 0), Vector3(0.1, 0.22, 0.1), Color(0.95, 0.92, 0.82))  # horns
			_part(_head, Vector3(-0.27, 0.52, 0), Vector3(0.1, 0.22, 0.1), Color(0.95, 0.92, 0.82))
			_part(_torso, Vector3(0, 0.62, -0.02), Vector3(0.7, 0.14, 0.4), a)  # fur mantle
			_part(_head, Vector3(0, 0.08, 0.2), Vector3(0.36, 0.14, 0.08), hair_color)  # beard
		&"knight":
			_part(_head, Vector3(0, 0.36, 0), Vector3(0.52, 0.34, 0.5), Color(0.72, 0.74, 0.8))  # helm
			_part(_head, Vector3(0, 0.26, 0.24), Vector3(0.36, 0.06, 0.04), Color(0.2, 0.2, 0.25))  # visor slit
			_part(_head, Vector3(0, 0.6, -0.05), Vector3(0.08, 0.14, 0.34), a)  # plume
			_part(_torso, Vector3(0, 0.32, 0.17), Vector3(0.44, 0.44, 0.04), Color(0.78, 0.8, 0.86))  # breastplate
			_part(_torso, Vector3(-0.4, 0.6, 0), Vector3(0.24, 0.12, 0.26), Color(0.72, 0.74, 0.8))  # pauldrons
			_part(_torso, Vector3(0.4, 0.6, 0), Vector3(0.24, 0.12, 0.26), Color(0.72, 0.74, 0.8))
		&"wizard":
			_part(_head, Vector3(0, 0.52, 0), Vector3(0.62, 0.06, 0.6), shirt_color * 0.8)  # hat brim
			_part(_head, Vector3(0, 0.68, 0), Vector3(0.36, 0.28, 0.36), shirt_color * 0.85)
			_part(_head, Vector3(0.03, 0.88, -0.03), Vector3(0.2, 0.2, 0.2), shirt_color * 0.9)
			_part(_head, Vector3(0.06, 1.02, -0.06), Vector3(0.1, 0.12, 0.1), a)
			_part(_head, Vector3(0, 0.02, 0.2), Vector3(0.3, 0.26, 0.08), Color(0.9, 0.9, 0.92))  # beard
			_part(_torso, Vector3(0, -0.12, 0), Vector3(0.6, 0.36, 0.36), shirt_color * 0.9)  # robe skirt
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
		&"assassin":
			_part(_head, Vector3(0, 0.36, -0.03), Vector3(0.54, 0.4, 0.5), shirt_color * 0.8)  # hood
			_part(_head, Vector3(0, 0.1, 0.23), Vector3(0.44, 0.16, 0.04), Color(0.12, 0.12, 0.15))  # mask
			_part(_torso, Vector3(0, 0.3, -0.19), Vector3(0.5, 0.56, 0.06), a)  # cape


func _build_weapon() -> void:
	for holder in [_weapon, _shield]:
		for c in holder.get_children():
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
			_part(_weapon, Vector3(0, 0, 1.12), Vector3(0.18, 0.18, 0.18), _accent)
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
	if _has_shield:
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
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_attack_pose, Vector3(_attack_arm.x, _attack_arm.y, _attack_torso), ready_pose, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_method(_set_attack_pose, ready_pose, strike_pose, maxf(active, 0.05)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_method(_set_attack_pose, strike_pose, Vector3.ZERO, recovery).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _set_attack_pose(v: Vector3) -> void:
	_attack_arm = Vector2(v.x, v.y)
	_attack_torso = v.z


func cancel_attack() -> void:
	if _attack_tween:
		_attack_tween.kill()
	_attack_arm = Vector2.ZERO
	_attack_torso = 0.0


func play_dodge(duration: float) -> void:
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
	cancel_attack()
	var tw := create_tween()
	tw.tween_property(_root, "rotation:z", PI * 0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "position:y", 0.25, 0.5)


func reset_pose() -> void:
	cancel_attack()
	_root.rotation = Vector3.ZERO
	_root.position = Vector3.ZERO
	_torso.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			for p in _parts:
				p.material_overlay = null
	var swing := sin(_walk_phase) * 0.9 * minf(_move_amount, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	var bob := absf(sin(_walk_phase)) * 0.06 * minf(_move_amount, 1.0)
	_torso.position.y = 0.72 + bob
	_torso.rotation.y = _attack_torso
	_torso.rotation.z = 0.0
	_arm_l.rotation.x = -swing * 0.8
	_arm_l.rotation.y = 0.0
	if _blocking:
		_arm_l.rotation = Vector3(-1.4, 0.6, 0.0)
		_arm_r.rotation = Vector3(-1.2, -0.9, 0.0)
		_weapon.rotation = Vector3(0.0, -1.2, 0.0)
	elif _attack_arm != Vector2.ZERO:
		_arm_r.rotation = Vector3(_attack_arm.x, _attack_arm.y, 0.0)
		_weapon.rotation = Vector3.ZERO
	else:
		_arm_r.rotation = Vector3(swing * 0.8 - 0.25, 0.0, 0.0)
		_weapon.rotation = Vector3(-0.9, 0.0, 0.0)
