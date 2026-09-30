# Architecture

Godot 4.4, GDScript, typed. Guiding rules:

- **Data-driven content.** Items, attacks, enemies, props and biomes are `Resource` files in
  `data/`. Adding content usually means adding a `.tres`, not code.
- **Composition over inheritance.** Characters are assembled from small components
  (`HealthComponent`, `StaminaComponent`, `HungerComponent`, `TemperatureComponent`,
  `StatBlock`). Enemy behaviour uses a thin base class (`Enemy`) with virtual hooks.
- **Signals for decoupling.** Cross-system events go through the `Events` autoload
  (damage numbers, pickups, toasts, lock-on, camera shake).
- **Deterministic world, persistent changes.** Terrain, props and spawn slots are pure
  functions of `(seed, coordinates)`. Only modifications are stored in `GameState`.
- **Everything testable headless.** Generation and components run without a scene; the
  integration test boots the real main scene.

## Main scene (`scenes/main.tscn`)

```
World (world.gd)                 wires systems, world services (temperature, pickups, placing)
├─ WorldEnvironment / Sun         stylized lighting, depth fog hides the streaming edge
├─ DayNightCycle                  20-min day; sun/sky colours; temperature swing
├─ ChunkManager                   streams Chunk nodes around the player (threads + budget)
├─ EnemySpawner                   spawns pooled enemies into LOD0 chunks
├─ PickupPool (NodePool)          dropped items
├─ Placed                         player-placed objects (campfires)
├─ DamageNumbers                  pooled Label3D combat text
├─ Player (player.tscn)           CharacterBody3D + components + PlayerCombat + HumanoidModel
├─ CameraRig                      yaw/pitch/zoom/pan tactical camera
└─ HUD (CanvasLayer)              code-built UI
```

## World generation & streaming

- `TerrainGenerator` (RefCounted, thread-safe) + `WorldGenSettings` (all parameters).
  `sample_column(wx, wz)` is the single source of truth for a surface column; it returns
  height (blocks) and biome index packed in one int.
  - **Shape** comes from continuous fields only: continentalness (oceans → coasts → land),
    island noise, hills, a mountain mask × ridged noise, swamp flattening
    (warm + wet), desert dunes (hot + dry), lake noise, and river channels
    (|domain-warped noise| < width, sloped valleys, faded out in mountains). Because the
    fields are continuous, biome borders never create cliffs or seams.
  - **Biomes** classify columns: ocean (deep + low continentalness), beach (coastal,
    not arctic), mountain (high or very mountainous), rare biomes (rarity noise above
    `rare_threshold`), then LAND biomes by temperature/moisture ranges in list order;
    the last LAND biome is the fallback. All defined in `data/biomes/*.tres`.
  - **Climate**: `get_climate(pos)` gives sea-level °C and day/night swing from the same
    temperature/moisture fields; `World` adds time of day, altitude lapse and water chill.
- **Layers**: `SURFACE` and `UNDERGROUND`. The underground is a heightmap of floors and
  5-block walls: open where tunnel noise (two |noise| bands) or cavern noise allows, plus
  a guaranteed room under every cave entrance. Entrances sit on a 64-block grid (hash
  chance), only on dry, flat, non-coastal land, and are shared by both layers, so the
  entrance above and the exit below are always at the same XZ.
- `generate_chunk(coord, lod, layer)` returns pure-data `ChunkData`: surface mesh arrays
  (visible faces only, edge skirts hide LOD seams), collision triangles (LOD0), water or
  **ice** quads (frozen biomes, part of collision), prop placements, features (cave
  passages) and enemy spawn slots.
- **Props**: each biome has `PropRule`s over world-aligned cells; a candidate is kept only
  if its own column belongs to that biome, so vegetation follows biome borders exactly.
  Prop index = `rule_uid(biome, rule) * 4096 + cell` → stable ids for persistence (append
  new biomes/rules at the end of lists to keep old saves valid). Lily pads use `on_water`.
- `ChunkManager`: LOD rings (default 3/6/9 chunks), worker-thread generation (max 4 in
  flight), main-thread apply budget (3/frame), chunk pool, stale-result discarding
  (including results for the previous layer after `set_layer()`).
- `Chunk`: terrain mesh, concave collision (LOD0), water, one MultiMesh per prop type,
  `PropBody` proxies for harvest/gather (LOD0), feature scenes (`CavePassage`).
- Large world: there is no world border; ±14 km at the 3M-chunk target is fine for floats.

## Save system (`SaveManager` autoload)

- `user://worlds/<id>/world.json` (metadata) and `save.json` (state), written via a
  `.tmp` file; the previous save is kept as `.bak` and used if the main file is corrupt.
- `save.json` = `{save_version, game_state: GameState.to_dict(), player: Player.to_save(),
  world: World.to_save()}`. `World.to_save()` stores layer, day/time and every node under
  `Placed` (scene path, transform, and `save_data()` if the node implements it).
- Seeds are stored as strings (64-bit ints don't survive JSON doubles).
- `SaveManager._migrate()` is the hook for future format changes; `generator_version`
  in `WorldGenSettings` documents when generation changes would alter existing worlds.
- Flow: menu → `create_world()` / `load_world()` / `start_transient()` → main scene →
  `World._ready()` consumes `SaveManager.pending`.

## Persistence model (`GameState`)

`world_seed`, `world_time`, `removed_props[Vector3i(chunk.x, chunk.y, layer)][prop_index]
= time` (with optional regrow time per prop type), `enemy_deaths[slot_key] = time`
(respawn time per enemy type), `discovered_biomes[id] = time`.

## Combat

- `AttackData` resources define damage, type, stamina, windup/active/recovery timings,
  cancel window, reach/arc, knockback, poise damage, lunge, crit bonus, animation id.
- `PlayerCombat`: 3-hit light combo + heavy, input buffering, cancel into dodge/next attack
  late in recovery, crits, **backstab** bonus from behind, lock-on aiming.
- `Player.receive_hit`: dodge i-frames → parry window → frontal block (stamina cost,
  guard break) → damage, knockback, stagger by poise damage.
- `Enemy.receive_hit`: type multipliers (weakness/resistance), **exposed** windows,
  knockback, poise → stagger. `ThornbackBoar` is a state machine (idle, wander, alert,
  chase, bite, charge windup/charge, recover/exposed, return+leash).

## RPG (Milestone 3)

- `ClassData` (data/classes) → `CharacterStats` (player node `Character`): class, level, XP,
  base skills, unspent points. `recalculate()` derives max health/stamina/mana, armor and
  damage reduction, physical/spell multipliers, crit, attack/move speed, backstab, block,
  parry and temperature protection from class + skills + equipment, and pushes them into
  the components and the `StatBlock` (`&"character"` source). All skill formulas live in
  `Skill` (static, tested, exported to docs); the XP curve in `Progression`.
- `Equipment` (RefCounted on the player): slot → item id; `ItemData` carries `equip_slot`,
  `weapon_type`, `moveset` (`WeaponMoveset` = light combo + heavy `AttackData`),
  `required_level`, `stat_bonuses`. Equipping swaps the combat moveset and model weapon.
- Damage: `PlayerCombat.build_physical()` = (attack + weapon bonus) × physical_mult ×
  proficiency × ability buffs × survival modifiers × variance → backstab → crit. Incoming:
  i-frames → parry → block (class/Defense/shield) → armor DR × ability modifiers.
- `PlayerAbilities`: 3 class `AbilityData` + Temperature Shield; costs (mana/stamina/rage),
  cooldowns (Mana Control perk), buffs, Rage; each ability is `_ability_<effect>()` with
  tuning from its .tres. Hooks: `on_hit_dealt`, `on_damage_taken`, `consume_attack_bonus`.
- `StatusEffects` (enemies): DoTs, slows, stun (→ stagger), with `Enemy.apply_status()`,
  `taunt()`, `lose_target()`. Fire vs frozen = Shatter.
- XP flows through `Events` (`enemy_killed`, `biome_discovered`, `place_discovered`,
  `resource_harvested`, `item_crafted`) into `CharacterStats.grant_xp()`.

## Survival

- `StatBlock` aggregates multiplicative modifiers per source (`&"hunger"`,
  `&"temperature"`; future: equipment, skills, buffs). Gameplay reads `get_mult(stat)`.
- `HungerComponent`: drains over time (× activity, × cold), states with modifiers,
  starvation damage at 0.
- `TemperatureComponent`: felt temperature drifts toward effective ambient
  (air + heat sources + food buffs + insulation/cooling). 7 exposure levels with a debuff
  table. **Contains no damage code path at all.**
- `World.get_air_temperature`: biome base + day/night swing + regional noise − altitude
  lapse − water chill. Heat sources (`heat_sources` group) add warmth, capped at 28 °C.

## Adding content

| Want | Do |
|---|---|
| New item | Add `data/items/<id>.tres` (`ItemData`). Food fields make it edible. |
| New prop | Add `data/props/<id>.tres` (`PropData`) + a `_build_<name>` mesh function in `PropLibrary`; reference it from a biome `PropRule`. |
| New enemy | Create `EnemyData` + `AttackData`s, a scene with an `Enemy` subclass script, and add an `EnemySpawnRule` to a biome. |
| New biome | Add a `BiomeData` (role + climate ranges + colours + prop rules) and append it to `data/worldgen/default_worldgen.tres`. |
| New class | Add `data/classes/<id>.tres` (50 starting points), add its id to `ClassRegistry.ORDER`, give it 3 `AbilityData`. |
| New ability | Add an `AbilityData` .tres and a `_ability_<effect>()` method in `PlayerAbilities`. |
| New weapon/armor | Add an `ItemData` with `equip_slot`, `stat_bonuses`, (weapons) `weapon_type` + `moveset`. |
| Save a new placeable | Put it under `World.placed_root` (via `place_object`) and implement `save_data()` / `load_data()`. |
| New input | Add to `InputSetup.KEY_BINDINGS`. |
