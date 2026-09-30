extends Node
## Global signal bus for decoupled, cross-system events.
##
## Systems emit here instead of holding references to each other (e.g. the HUD
## listens for damage numbers without knowing about enemies).

## A hit landed. `target_is_player` lets the UI colour the number differently.
signal damage_dealt(position: Vector3, amount: float, is_crit: bool, target_is_player: bool, tag: String)
## An enemy died. `enemy_id` is the EnemyData id (e.g. &"thornback_boar").
signal enemy_killed(enemy: Node, enemy_id: StringName, position: Vector3)
## Items entered the player's inventory.
signal item_picked_up(item_id: StringName, count: int)
## Short on-screen message (pickups, warnings, hints).
signal toast(text: String, color: Color)
signal player_died
signal player_respawned
## Lock-on target changed (null when cleared).
signal target_changed(target: Node)
## Small camera shake request (strength 0..1).
signal camera_shake(strength: float)

# --- RPG ---------------------------------------------------------------------------
signal xp_gained(amount: int, source: int)
signal level_up(level: int)
signal biome_discovered(id: StringName)
## A named place discovered for the first time (cave entrances, later landmarks).
signal place_discovered(key: String)
## A prop was harvested/gathered; `xp` is the XP it is worth.
signal resource_harvested(prop_id: StringName, xp: int)
signal item_crafted(item_id: StringName, count: int)
## An ability was used (for HUD feedback).
signal ability_used(ability_id: StringName)

# --- Crafting & building --------------------------------------------------------------
## A storage container (chest) was opened by the player.
signal open_container(container: Node)
signal recipe_learned(recipe_id: StringName)
signal building_changed
