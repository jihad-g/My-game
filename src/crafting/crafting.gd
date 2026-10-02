class_name Crafting
## Crafting rules: availability checks and the craft action itself.


## Station ids within `radius` of `pos` (always includes &"hand").
static func stations_near(tree: SceneTree, pos: Vector3, radius: float = 4.0) -> Dictionary:
	var out := {&"hand": true}
	for s in tree.get_nodes_in_group(&"crafting_stations"):
		var n := s as Node3D
		if n and n.is_visible_in_tree() and n.global_position.distance_to(pos) <= radius:
			out[n.get_meta(&"station_id", &"")] = true
	return out


## "" if the player can craft `recipe` now, otherwise the reason.
static func check(player: Player, recipe: RecipeData, stations: Dictionary, times: int = 1) -> String:
	if not player.recipes.knows(recipe.id):
		return "Unknown recipe" + (" (%s)" % recipe.source_hint if recipe.source_hint != "" else "")
	var crafting := player.character.skill_level(Skill.CRAFTING)
	if crafting < recipe.required_crafting():
		return "Requires Crafting %d" % recipe.required_crafting()
	if not stations.has(recipe.station_id()):
		return "Requires a %s nearby" % recipe.station_name()
	var cost := recipe.cost_at(crafting)
	for item in cost:
		if player.inventory.count_of(item) < int(cost[item]) * times:
			var d: ItemData = ItemDB.get_item(item)
			return "Missing %s" % (d.display_name if d else String(item))
	return ""


## The item a craft gives: gear may come out Fine or Masterwork (Milestone 15).
static func quality_result(recipe: RecipeData, crafting: int, rng: RandomNumberGenerator = null) -> StringName:
	var item: ItemData = ItemDB.get_item(recipe.result_item)
	if not ItemQuality.can_have_quality(item):
		return recipe.result_item
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return ItemQuality.with_quality(recipe.result_item, ItemQuality.roll(crafting, rng))


## Crafts `times` copies. Returns how many were crafted.
static func craft(player: Player, recipe: RecipeData, stations: Dictionary, times: int = 1) -> int:
	var made := 0
	for i in times:
		if check(player, recipe, stations, 1) != "":
			break
		var cost := recipe.cost_at(player.character.skill_level(Skill.CRAFTING))
		for item in cost:
			player.inventory.remove_item(item, int(cost[item]))
		var count := recipe.result_count
		if recipe.station == RecipeData.Station.CAMPFIRE and randf() < player.character.cooking_bonus_chance():
			count += 1
		var result := quality_result(recipe, player.character.skill_level(Skill.CRAFTING))
		if ItemQuality.quality_of(result) != ItemQuality.NORMAL:
			Events.toast.emit("%s!" % ItemDB.get_item(result).display_name, UITheme.GOLD)
		player.give_or_drop(result, count)
		made += 1
		Events.item_crafted.emit(recipe.result_item, maxi(1, recipe.xp / 4))
	return made
