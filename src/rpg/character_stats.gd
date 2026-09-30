class_name CharacterStats
extends Node
## A character's class, level, experience, skills and every derived stat.
##
## Owns progression (XP -> levels -> skill points -> skills) and recalculates
## derived values whenever something changes: max health/stamina/mana, armor,
## damage multipliers, crit, attack/move speed, temperature protection.
## Gameplay code asks this node for numbers instead of computing its own.

signal xp_changed(xp_into_level: int, xp_needed: int, level: int)
signal leveled_up(level: int)
signal skills_changed
signal recalculated

@export var stats: StatBlock
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var mana: ManaComponent
@export var temperature: TemperatureComponent

var class_data: ClassData
var level: int = 1
## XP collected towards the next level.
var xp: int = 0
var total_xp: int = 0
## Base skill levels (without equipment bonuses).
var skills: Dictionary = {}
var unspent_points: int = 0
## Progression.Source -> XP earned (statistics).
var xp_by_source: Dictionary = {}
var equipment: Equipment
## Extra temperature protection from abilities (Magic Temperature Shield).
var ability_insulation: float = 0.0
var ability_cooling: float = 0.0

# Derived values (read-only for other systems; refreshed by recalculate()).
var armor: float = 0.0
var damage_reduction: float = 0.0
var physical_mult: float = 1.0
var spell_mult: float = 1.0
var crit_chance: float = 0.05
var crit_mult: float = 1.5
var attack_speed: float = 1.0
var move_speed: float = 1.0
var backstab_mult: float = 1.5
var block_reduction: float = 0.7
var parry_window: float = 0.2


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.biome_discovered.connect(func(_id: StringName) -> void: grant_xp(60, Progression.Source.DISCOVERY))
	Events.place_discovered.connect(func(_key: String) -> void: grant_xp(40, Progression.Source.EXPLORATION))
	Events.resource_harvested.connect(_on_resource_harvested)
	Events.item_crafted.connect(func(_id: StringName, n: int) -> void: grant_xp(4 * n, Progression.Source.CRAFTING))


## Sets the class. `fresh` = brand-new character (starting skills, level 1).
func setup(p_class: ClassData, fresh: bool) -> void:
	class_data = p_class
	if fresh or skills.is_empty():
		level = 1
		xp = 0
		total_xp = 0
		unspent_points = 0
		xp_by_source.clear()
		for s in Skill.ALL:
			skills[s] = class_data.starting_skill(s)
	recalculate(true)


func base_skill(skill: StringName) -> int:
	return int(skills.get(skill, 1))


## Skill level including equipment bonuses, capped at 100.
func skill_level(skill: StringName) -> int:
	var bonus := equipment.total(skill) if equipment else 0.0
	return clampi(base_skill(skill) + int(bonus), 1, Skill.MAX_LEVEL)


func eff(skill: StringName) -> float:
	return class_data.efficiency(skill) if class_data else 1.0


# --- Experience -------------------------------------------------------------------------

func xp_needed() -> int:
	return Progression.xp_to_next(level)


## Adds XP and handles any number of level-ups. Returns levels gained.
func grant_xp(amount: int, source: int = Progression.Source.OTHER) -> int:
	if amount <= 0 or level >= Progression.MAX_LEVEL:
		return 0
	xp_by_source[source] = int(xp_by_source.get(source, 0)) + amount
	total_xp += amount
	xp += amount
	Events.xp_gained.emit(amount, source)
	var gained := 0
	while level < Progression.MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
		unspent_points += Progression.skill_points_for_level(level)
	if level >= Progression.MAX_LEVEL:
		xp = 0
	if gained > 0:
		recalculate()
		if health:
			health.heal(health.max_health)
		if mana:
			mana.refill()
		leveled_up.emit(level)
		Events.level_up.emit(level)
	xp_changed.emit(xp, xp_needed(), level)
	return gained


func spend_point(skill: StringName) -> bool:
	if unspent_points <= 0 or base_skill(skill) >= Skill.MAX_LEVEL:
		return false
	skills[skill] = base_skill(skill) + 1
	unspent_points -= 1
	recalculate()
	skills_changed.emit()
	return true


func _on_enemy_killed(enemy: Node, _id: StringName, _pos: Vector3) -> void:
	if not enemy is Enemy or (enemy as Enemy).data == null:
		return
	if enemy.get_meta(&"killed_by_npc", false):
		return  # a town guard got it
	var d := (enemy as Enemy).data
	grant_xp(Progression.combat_xp(d.xp_reward, d.level, level),
		Progression.Source.BOSS if d.category == EnemyData.Category.BOSS else Progression.Source.COMBAT)


func _on_resource_harvested(_prop_id: StringName, xp_value: int) -> void:
	grant_xp(xp_value, Progression.Source.HARVEST)


# --- Derived stats ------------------------------------------------------------------------

## Recomputes everything from class + skills + equipment and pushes the
## results into the components. `reset` fills health/stamina/mana to max.
func recalculate(reset: bool = false) -> void:
	if class_data == null:
		return
	var c := class_data
	var strength := skill_level(Skill.STRENGTH)
	var mc := skill_level(Skill.MANA_CONTROL)
	var def := skill_level(Skill.DEFENSE)
	var dex := skill_level(Skill.DEXTERITY)
	armor = c.base_armor + Skill.skill_armor(def, eff(Skill.DEFENSE)) + _eq(&"armor")
	damage_reduction = Skill.damage_reduction(armor)
	physical_mult = Skill.physical_damage_mult(strength, eff(Skill.STRENGTH), c.physical_power)
	spell_mult = Skill.spell_power_mult(mc, eff(Skill.MANA_CONTROL), c.spell_power) * (1.0 + _eq(&"spell_power") / 100.0)
	crit_chance = Skill.crit_chance(dex, eff(Skill.DEXTERITY)) + c.crit_bonus + _eq(&"crit_chance") / 100.0
	crit_mult = Skill.crit_damage_mult(dex)
	attack_speed = Skill.attack_speed_mult(dex, eff(Skill.DEXTERITY)) * (1.0 + _eq(&"attack_speed") / 100.0)
	move_speed = Skill.move_speed_mult(dex, eff(Skill.DEXTERITY)) * (1.0 + _eq(&"move_speed") / 100.0)
	backstab_mult = c.backstab_multiplier + Skill.backstab_bonus(dex, eff(Skill.DEXTERITY))
	block_reduction = minf(c.block_reduction + Skill.block_bonus(def) + _eq(&"block") / 100.0, 1.0)
	parry_window = c.parry_window

	var new_max_health := Skill.max_health(def, c.base_health, c.health_per_defense) + _eq(&"max_health")
	var new_max_stamina := c.base_stamina + Skill.bonus_stamina(strength, eff(Skill.STRENGTH)) + _eq(&"max_stamina")
	var new_max_mana := Skill.max_mana(mc, c.base_mana, c.mana_per_point) + _eq(&"max_mana")
	if health:
		var grow := new_max_health - health.max_health
		health.max_health = new_max_health
		if reset:
			health.current = new_max_health
		elif grow > 0.0 and not health.is_dead:
			health.current += grow
		health.current = minf(health.current, new_max_health)
		health.health_changed.emit(health.current, health.max_health)
	if stamina:
		stamina.max_stamina = new_max_stamina
		stamina.current = new_max_stamina if reset else minf(stamina.current, new_max_stamina)
		stamina.stamina_changed.emit(stamina.current, stamina.max_stamina)
	if mana:
		mana.regen_per_second = Skill.mana_regen(mc, eff(Skill.MANA_CONTROL)) * (1.0 + _eq(&"mana_regen") / 100.0)
		mana.set_max(new_max_mana)
		if reset:
			mana.refill()
	if temperature:
		temperature.insulation = _eq(&"insulation") + ability_insulation
		temperature.cooling = _eq(&"cooling") + ability_cooling
	if stats:
		stats.set_source(&"character", {Stats.MOVE_SPEED: move_speed, Stats.ATTACK_SPEED: attack_speed})
	recalculated.emit()


func _eq(stat: StringName) -> float:
	return equipment.total(stat) if equipment else 0.0


## Damage multiplier for a physical hit with the given weapon type.
func weapon_mult(weapon_type: StringName) -> float:
	if class_data == null:
		return 1.0
	if weapon_type == &"unarmed":
		return 1.0
	return class_data.proficiency(weapon_type)


func harvest_bonus_chance() -> float:
	return Skill.harvest_bonus_chance(skill_level(Skill.CRAFTING), eff(Skill.CRAFTING))


func cooking_bonus_chance() -> float:
	return Skill.cooking_bonus_chance(skill_level(Skill.CRAFTING), eff(Skill.CRAFTING))


func ability_mana_cost(base_cost: float) -> float:
	return base_cost * Skill.mana_cost_mult(skill_level(Skill.MANA_CONTROL))


func can_use_temperature_shield() -> bool:
	return class_data != null and base_skill(Skill.MANA_CONTROL) >= class_data.temperature_shield_requirement()


## Lines describing the current effect of a skill (character screen / docs).
func describe_skill(skill: StringName) -> String:
	var lv := skill_level(skill)
	var e := eff(skill)
	match skill:
		Skill.STRENGTH:
			return "Physical dmg x%.2f · +%d stamina" % [physical_mult, roundi(Skill.bonus_stamina(lv, e))]
		Skill.MANA_CONTROL:
			return "Mana %d (+%.1f/s) · Spell power x%.2f · Costs -%d%%" % [roundi(mana.max_mana if mana else 0.0),
				Skill.mana_regen(lv, e), spell_mult, roundi((1.0 - Skill.mana_cost_mult(lv)) * 100.0)]
		Skill.DEFENSE:
			return "Health %d · Armor %d (-%d%% dmg)" % [roundi(health.max_health if health else 0.0), roundi(armor),
				roundi(damage_reduction * 100.0)]
		Skill.CRAFTING:
			return "Materials x%.2f · +%d%% harvest yield · Tier: %s" % [Skill.material_cost_mult(lv),
				roundi(Skill.harvest_bonus_chance(lv, e) * 100.0), ItemData.RARITY_NAMES[Skill.recipe_tier(lv)]]
		Skill.DEXTERITY:
			return "Attack speed x%.2f · Crit %d%% (x%.2f) · Move x%.2f" % [attack_speed, roundi(crit_chance * 100.0),
				crit_mult, move_speed]
	return ""


# --- Save / load -------------------------------------------------------------------------

func to_save() -> Dictionary:
	var sk := {}
	for s in skills:
		sk[String(s)] = skills[s]
	var src := {}
	for k in xp_by_source:
		src[str(k)] = xp_by_source[k]
	return {
		"class": String(class_data.id) if class_data else "",
		"level": level, "xp": xp, "total_xp": total_xp,
		"skills": sk, "unspent_points": unspent_points, "xp_by_source": src,
	}


func load_progress(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, Progression.MAX_LEVEL)
	xp = int(data.get("xp", 0))
	total_xp = int(data.get("total_xp", 0))
	unspent_points = int(data.get("unspent_points", 0))
	var sk: Dictionary = data.get("skills", {})
	for s in Skill.ALL:
		if sk.has(String(s)):
			skills[s] = clampi(int(sk[String(s)]), 1, Skill.MAX_LEVEL)
	xp_by_source.clear()
	var src: Dictionary = data.get("xp_by_source", {})
	for k in src:
		xp_by_source[int(k)] = int(src[k])
	recalculate()
	xp_changed.emit(xp, xp_needed(), level)
	skills_changed.emit()
