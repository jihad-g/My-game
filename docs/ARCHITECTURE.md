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
- `ChunkManager` (streaming, reworked in Milestone 9):
  - LOD rings (default 3/6/9 chunks) around the focus; worker-thread generation with
    `OS.get_processor_count() - 1` tasks in flight (2–8).
  - **Time-budgeted apply**: generated data is turned into nodes within `apply_budget_ms`
    (4 ms) per frame, at least one chunk per frame, at most `max_applies_per_frame`.
  - **Data cache**: every generated `ChunkData` is kept in an LRU cache keyed by
    (coord, LOD, layer) with a memory budget (`cache_budget_mb`, 48 MB, sizes from
    `ChunkData.estimate_bytes()`); data of loaded chunks is never evicted. Returning to an area,
    LOD changes back and forth, and layer switches reuse it instead of regenerating.
  - **Prefetch**: the focus velocity is tracked (teleports reset it); the work queue is sorted
    by distance to a point nudged towards where the focus is heading, and with spare workers the
    rings around the *predicted* centre (3 s ahead) are generated into the cache.
  - **Background pre-warming**: `TerrainGenerator.prewarm()` lays out settlements and POIs
    within 1.5 km of where the focus is heading on a worker, so chunk tasks don't stall on them.
  - Chunk pool, stale-result discarding (including results for the previous layer after
    `set_layer()`).
- `FarTerrain` (horizon LOD, Milestone 9): 64 m super-tiles (4×4 chunks) with one 8 m column per
  cell, out to 32 chunks (512 m). Heights are sampled and meshed on workers (terrain + water,
  no collision/props/shadows); height grids are cached so moving only re-meshes tiles along the
  edge of the "hole" left for the chunk rings (cells within r_max − 1 chunks are cut out; tiles
  sit 1 m lower so the outermost chunk ring always wins where they overlap). Surface fog runs
  150 → 470 m; the camera's far plane is 640 m.
- `Chunk`: terrain mesh, concave collision (LOD0), water, one MultiMesh per prop type,
  `PropBody` proxies for harvest/gather (LOD0), feature scenes (`CavePassage`).
- **World size**: chunks −866..+866 on both axes = 1733² = **3,003,289 chunks** (27.7 km square,
  `TerrainGenerator.WORLD_*`). From 12.8 km (max of |x|, |z|) continents sink into an edge ocean;
  `World` keeps the player within ±13,856 m. float32 still resolves 1 mm there, so there is no
  floating origin. `tools/world_survey.tscn` samples the whole world and benchmarks generation
  ([`WORLD_SURVEY.md`](WORLD_SURVEY.md)).

## Save system (`SaveManager` autoload)

- `user://worlds/<id>/world.json` (metadata), `save.json` (state) and `regions/` (per-chunk
  changes, see below). JSON files are written via a
  `.tmp` file; the previous save is kept as `.bak` and used if the main file is corrupt.
- `save.json` = `{save_version, game_state: GameState.to_dict(), player: Player.to_save(),
  world: World.to_save()}`. `World.to_save()` stores layer, day/time and every node under
  `Placed` (scene path, transform, and `save_data()` if the node implements it).
- Seeds are stored as strings (64-bit ints don't survive JSON doubles).
- `SaveManager._migrate()` is the hook for future format changes; `generator_version`
  in `WorldGenSettings` documents when generation changes would alter existing worlds.
- Flow: menu → `create_world()` / `load_world()` / `start_transient()` → main scene →
  `World._ready()` consumes `SaveManager.pending`.

## Persistence model (`GameState` + `RegionStore`)

`world_seed`, `world_time`, `discovered_biomes[id] = time`, `discovered_places[key] = time`
live in `save.json`. Per-chunk changes live in a `RegionStore` (Milestone 9):

- removed props: chunk → prop index → time removed (optional regrow time per prop type),
  per layer; killed spawn slots: slot key → time (respawn time per enemy type).
- Regions of 32×32 chunks, one ZSTD-compressed `var_to_bytes` file each:
  `user://worlds/<id>/regions/r.<rx>.<rz>.<layer>.dat` (POI guardian slots: `misc.dat`).
- Lazy loading on first query, dirty tracking, `flush()` on every save (before `save.json`,
  atomic `.tmp` + rename, empty regions delete their file), LRU eviction of clean regions
  (`max_loaded` 64) so memory stays bounded however far the player travels.
- Transient worlds keep everything in memory (and inline in `to_dict()`); save version 1 files
  (changes inline in `save.json`) are imported on load and written to region files on the
  next save (save version 2).

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

## Building & crafting (Milestone 4)

- **Crafting** (`src/crafting`): `RecipeData` resources in `data/recipes` (result, ingredients,
  station, tier, source). `RecipeBook` (RefCounted on the player) caches all recipes and
  tracks known ids; `Player.give_item()` → `discover_from()` learns DISCOVERY recipes,
  `Player.read_recipe_book()` learns BOOK recipes from `ItemData.teaches_recipes`.
  `Crafting.stations_near()` reads nodes in group `crafting_stations` (meta `station_id`)
  within 4 m; `Crafting.check()/craft()` apply `Skill.material_cost_mult` (never fails) and
  emit `Events.item_crafted` (XP). UI: `CraftingPanel` (G).
- **Tools**: `ItemData.tool_kind/tool_tier`; `PropData.tool_kind/tool_tier`;
  `PropBody.receive_hit()` asks `Player.best_tool_tier()` — too low = no damage, otherwise
  power = 1 + tier hits.
- **Building** (`src/building`): `BuildPieceData` in `data/build_pieces`; meshes are code-built
  in `BuildMeshes.build_<mesh>()`. `BuildingManager` (child of World) owns all pieces in a
  dictionary keyed `"x,z,slot,layer"`. Slots: `floor`, `object`, `roof`, and `edge_n`/`edge_w`
  (a cell's south/east edges are the neighbours' north/west edges, so each edge has one
  address). `check_place()` returns "" or the reason; `place()/remove()` pay/refund;
  `is_claimed()`, `is_sheltered()`; `to_save()/from_save()`. Pieces are global world objects
  (not chunk-bound), shown only on their layer. `BuildPiece` implements behaviours
  (door, chest `Inventory`, bed → `World.use_bed`, spikes Area3D vs ENEMY, station group,
  torch heat source, claim group). `BuildMode` drives the ghost and input; `BuildPalette`
  and `ContainerPanel` are the UI.
- Integration points: `EnemySpawner._try_spawn` skips claimed land;
  `World.get_temperature_at` applies shelter; physics layer `BUILDING` (64) is in the
  player, enemy and projectile masks.

## Living world (Milestone 5)

- **Generation**: `TerrainGenerator.settlements` (`Settlements`) decides villages/capitals per
  region from raw terrain (`_sample_raw`), cached behind a mutex (worker threads call it).
  `sample_column()` flattens columns inside a settlement; chunk generation looks settlements up
  once per chunk. Props, cave entrances and spawn slots skip towns.
- **Layout → Site**: `SettlementLayout.build(info, day)` returns pure data (static pieces with
  transforms and collision boxes, roofs per building, doors, stations, lights, farms, waypoints,
  NPC roster). `SettlementManager` (child of World) streams `SettlementSite`s; a site merges the
  statics into BlockMesh arrays on a worker thread and attaches meshes/collision on the main
  thread, then spawns `NPC`s. Nothing about sites is saved (they are deterministic).
- **NPCs**: `NPC.schedule(hour)` → activity → target point; `_go()` plans door/gate + street
  graph (`SettlementSite.find_path`, Dijkstra over lot-boundary streets, segments blocked by
  building/farm rectangles). Far NPCs update 4x/s. Talking emits `Events.npc_talk`.
- **Economy/reputation**: `Economy` (static prices, stock tables), `SettlementManager` keeps shop
  states (`"<id>|<role>"`), requests and hunt progress (saved in `world.living`); `Reputation`
  and `coins` live on the Player. `Gossip` builds dialogue lines from world queries.
- **Farming**: `BuildPiece` behaviour FARM + `Farming` rules; growth uses `GameState.world_time`.

## Exploration (Milestone 6)

- **Placement**: `TerrainGenerator.pois` (`Exploration`) decides one POI per 256 m cell from raw
  terrain (cached, thread-safe). `PoiInfo` extends `SettlementInfo`, so `sample_column()`
  flattens POIs with the same code as towns; props, caves and spawns skip them.
- **POI sites**: `PoiLayout.build(poi)` → statics/boxes/roofs, chests, cracked blocks, objects
  (lectern, altar, entrance, plants), lights, guardians. `PoiSite` builds it with
  `StaticGeometry` (merge into BlockMesh arrays + attach), spawns guardians from the monster
  pool and wires temple logic. `ExplorationManager.state` (saved) records opened chests,
  vaults, cleansed temples, tomes, plants and dungeon clears.
- **Dungeons**: `DungeonPlan.generate(poi, floor)` (rooms on a slot grid, spanning tree +
  loops, room roles, secret corridor) → `DungeonInstance` at `ORIGIN` (y = 800): floor/wall
  geometry with merged wall-run collision, monsters (rank-scaled), traps, chests, doors,
  boss arena gate. `World.enter_dungeon / next_dungeon_floor / exit_dungeon` pause chunk
  streaming, route ground height/temperature to the dungeon and restore the surface.
- **Monsters**: `Monster` (generic AI over `MonsterData`) shares Enemy's pooling, hits,
  status effects and loot. Bosses emit `Events.boss_started/boss_ended` for the HUD bar.
- **Loot**: `LootTables` (rank-gated entries, gear bands, legendary scrolls); `LootChest`.

## Advanced gameplay (Milestone 7)

- **Status effects** – `StatusEffects` (src/combat) is one component used by enemies (scene
  node) and the player (created in `Player._ready`). `apply()` handles elemental interactions
  and immunities; `incoming()` / `outgoing_mult()` / `speed_mult()` are read by
  `Enemy.receive_hit`, `Player.receive_hit`, `PlayerAbilities` and `Monster`.
- **GroundHazard** (src/combat) – every telegraphed area attack: danger circle → blast (or a
  lingering pool). Flags decide who it hurts (player / enemies / townsfolk + buildings).
  Boss spikes and meteors, bandit bombs, elite death bursts, Miasma/Blizzard/Meteor spells.
- **Monster AI** – `_pick_target()` (player; for raiders also NPCs and building pieces), a state
  machine (`AI` enum) with boss specials, phases (`MonsterData.phases`), ward pylons, support
  casting and elite affixes (`EliteAffixes`). `CombatDirector` hands out melee attack tokens
  and circle slots; `_move_dir()` steers with feeler rays, hops and detours.
- **Spells** – `data/spells/*.tres` are `AbilityData` with `required_mana_control`; `SpellBook`
  (on the player, saved) holds known spells and 2 slots; `PlayerAbilities._spell_<effect>()`
  implements them.
- **Raids** – `RaidManager` (World child) rolls raids hourly from the world seed, runs the
  warning → waves → result flow, spawns raiders as untracked pooled `Monster`s with
  `set_raid(objective)`, and saves plundered/defended/pending state. Building pieces
  (`BuildPiece`) have hit points (`BuildPieceData.get_max_health()`), `receive_hit()`,
  repair costs; turrets and bells are piece behaviours. `NPC` guards have hit points and
  get knocked down; `SettlementSite.under_attack` makes villagers hide.
- **Rare events** – `WorldEvents` (World child) rolls events hourly, applies sky tints via
  `DayNightCycle.sky_tint`/`eclipse`, spawns hordes, goblins, meteors (`MeteorCrater`) and the
  Starborn Colossus, exposes `xp_mult()` / `spell_mult()`, and saves active events and craters.

## Blueprints (Milestone 8)

- **Format** – `Blueprint` (src/blueprints) holds pieces at grid addresses (`x`, `z`, `slot`, `rot`)
  relative to the anchor cell. `to_json()` / `from_json()` read and write the shared
  `shardlands-blueprint` JSON; `rotate_entry()` turns an address by 90° (edges map n↔w).
- **Library** – `BlueprintLibrary` reads `res://data/blueprints/*.json` (built-in) and
  `user://blueprints/*.json` (yours).
- **Sites** – `BlueprintManager` (World child) owns `ConstructionSite`s and the `BlueprintPlacer`
  preview. A site keeps its plan in build order, shows `BlueprintHologram`s (interactable, no
  collision with movement) for unbuilt pieces, checks each with `BuildingManager.check_place`
  (no player reach limit), pays from the player's inventory then nearby chests, and places through
  `BuildingManager.place`. Sites save their pending pieces in the world save (`blueprint_sites`).
- **Web designer** – `web/blueprint-designer/designer.src.html` + the catalog that
  `tools/build_designer.py` extracts from `data/build_pieces`, `data/items` and `data/blueprints`
  → `index.html`. Its address and rotation rules mirror `BuildingManager.address_for` and
  `Blueprint.rotate_entry`; a test checks the catalog matches the game.

## Art, audio & polish (Milestone 10)

- **Audio** (`src/autoload/audio.gd`): files under `assets/audio/` are generated by `tools/gen_audio.py`
  (deterministic synthesis; re-run after changing a sound). `Audio.play(name)` (2D), `play_at(name, pos)` (3D),
  `play_ui(name)`; `name_0..name_N` files are random variations. Per-sound rate limit, random pitch, bus
  volumes from `Settings`. `set_music(track)` crossfades two players; `AmbientEffects` calls
  `Audio.pick_music(context)` every second. `set_ambience(layer, volume)` fades loop players; a reverb
  effect on the SFX bus is enabled underground. Gameplay hooks: the `Events` bus (hits, kills, level ups,
  discoveries, crafting, raids, bosses, abilities) plus direct calls (swings, dodges, blocks, props,
  projectiles, blasts, footsteps, splashes).
- **Sky** (`assets/shaders/sky.gdshader`): `DayNightCycle` sets the uniforms (sun/moon direction, colours,
  moon phase, night, cloud cover, storm, lightning flash). The cubemap pass draws only the gradient so the
  radiance map stays cheap.
- **Weather** (`WeatherSystem`, child of World): `roll(time, temperature01, moisture01, biome)` is a pure
  function of the world seed and 300 s spell number; the system eases its values (intensity, clouds, wind,
  fog) towards that target and pushes them to `DayNightCycle.weather_*`, the global shader parameters and
  the ambience mixer. Rain/snow/sand are GPU particles around the camera with a heightfield collider.
  `World.get_air_temperature` adds `weather.temperature_offset()`.
- **Ambient effects** (`AmbientEffects`): GPU particle emitters whose `amount_ratio` eases to
  `targets()` (biome/time/weather/layer); also the music context and ambience beds.
- **Materials**: `Materials.foliage(sway, fade_near)` (wind sway + optional camera dither fade) for the props
  listed in `PropLibrary.SWAY`; `Materials.water()` is `assets/shaders/water.gdshader`. Terrain top faces
  carry per-corner AO in vertex colours (`TerrainGenerator._quad_ao`).
- **Animation** (`HumanoidModel`): hip→knee and shoulder→elbow pivots; `set_air_state()`, `play_land()`,
  `play_cast()`, `footstep` signal; weapon trails (`WeaponTrail`, a top-level ImmediateMesh ribbon).
- **VFX** (`VFX`): one-shot CPU particles of small cubes (`debris`, `dust`, `sparks`, `splash`, `motes`);
  `VFX.enabled` follows the settings.
- **UI**: `ItemIcons` draws 32×32 icons from primitives (shape by item id/category, material tint, shading
  and outline passes), cached per item; `UIFx.attach(panel)` pop-in + sounds; `SettingsPanel` +
  `Settings` autoload (`user://settings.cfg`, `apply()` / `apply_to_world()`).

## Multiplayer (Milestone 11)

Full protocol and rules: [`MULTIPLAYER.md`](MULTIPLAYER.md). In short: the `Net` autoload holds the
ENet peer and every RPC; `NetServer` validates guests' requests against the host's state (its own
`Inventory`/`Equipment` per guest, the generator for prop existence, `BuildingManager.check_place`
for buildings) and broadcasts results; `NetClient` loads the same world from the seed (verified by
`NetProtocol.world_checksum`) and applies the server's snapshots. Single-player code paths are
unchanged offline; online, small hooks reroute guest actions (`Inventory.remote`, `PropBody`,
`Pickup`, `BuildMode`, `BuildPiece`, `CraftingPanel`, `Player`) and broadcast host actions
(`Chunk.harvest_prop`, `BuildingManager.place/remove/destroy`, `World.spawn_pickup/place_object`).

## Balance, playtesting & performance (Milestone 12)

- `src/rpg/balance_model.gd` (`BalanceModel`): pure functions over the game's own data — a class's build
  at a level (`BUILDS` skill shares), the best gear it may wear, its moveset DPS (and Firebolt for the
  Wizard, mana-limited), effective HP; the level-appropriate reference monster (Skeleton Warrior scaled by
  `PoiLayout` rank tables); duels (time to kill / time to die), minutes per level, recipe value and the
  best shop arbitrage (craft-and-sell, town-to-town). `tools/balance_report.gd` turns it into
  docs/BALANCE.md; `test_m12_balance` enforces limits on the same numbers.
- `tests/playthrough.gd` (`Playthrough`): a bot that drives the real systems (props, `Crafting`,
  `BuildingManager`, `PlayerCombat.build_damage`, `SettlementManager.buy/sell`, `PoiSite` guardians and
  chests) through the core loop and logs simulated play time. Used by `test_m12_gameplay_loop` and
  `tools/playthrough.tscn`.
- `tests/stress.gd` (`Stress`): `worldgen_seed()` (spawn, reachable towns/ruins, mesh validation at the
  centre/far/edge/caves, determinism, dungeon plans) and `benchmark()` (frame-time scenarios in a booted
  world) plus the budgets (`BUDGET_*`). Used by `test_m12_worldgen_stress`, `test_m12_performance` and
  `tools/stress_test.tscn` (docs/PERFORMANCE.md).
- Wild monsters: `EnemySpawner.wild_rank(pos)` (one rank per `Exploration.RANK_STEP` = 1.2 km) and
  `scale_for_distance()` configure spawns like dungeon ranks.
- Movement cost: `Enemy._blocked_by_world()` gates `GroundMotion.try_step_up()` (which also ignores other
  characters), so crowds don't run stair-step physics queries every tick.

## Release preparation (Milestone 13)

Autoload order: InputSetup, Events, GameState, ItemDB, SaveManager, Audio, Settings, Tutorial, Net,
CrashHandler, Platform.

- **Input** (`InputSetup`): defaults for keyboard/mouse (`KEY_BINDINGS`, `MOUSE_BINDINGS`) and gamepad
  (`PAD_BINDINGS`) are applied with `reset_all()`; `rebind()` replaces the binding of one device kind and
  returns conflicts; `custom_bindings()`/`apply_custom_bindings()` (strings like `key:70`, `axis:1:-`) are
  what Settings saves in the `[input]` section. `using_gamepad` flips on the last input device and
  `action_label()` gives hint text. `Player.get_aim_direction()` uses the stick on a pad.
- **Settings** (`Settings` autoload): `DEFAULTS` + typed loading (bad values fall back), `apply()` for
  engine/window/theme/accessibility, `apply_to_world()` for world nodes. Derived values used by systems:
  `damage_taken_mult()` (Player.receive_hit), `hunger_mult()` (HungerComponent), `autosave_interval()`
  (World), `reduce_flashing()` (WeatherSystem lightning, HUD vignette), `reduce_motion()` (UIFx, camera).
  `AccessibilityLayer` (a CanvasLayer child) holds the colour-vision shader, captions and FPS label;
  `Audio.caption_hook` feeds it every sound. `UITheme.build()` returns one shared Theme so
  `set_high_contrast()` restyles every screen.
- **Tutorial** (autoload): `STEPS` with `show`/`done` conditions evaluated in `_condition()` against the
  world plus flags from Events and UI (`Tutorial.notify(&"inventory_opened")`); one hint at a time
  (`hint_changed` → HUD `TutorialCard`); progress in `user://profile.cfg [tutorial]`. `GuidePanel` (F1)
  builds its Controls page from `InputSetup.REBINDABLE`.
- **Save recovery** (`SaveManager`): `_write_json` prefixes a `#shardlands-save sha256=` header line and
  checks the write; `_read_json` verifies it (header-less files still load). `load_world` falls back
  save → .bak → `list_backups()` and records `last_load`. Snapshots (`backups/<stamp>/` with save, meta,
  regions, `snapshot.json`) come from `_snapshot_files` (load, every `SNAPSHOT_INTERVAL` of play) and
  `snapshot_world` (live state, used for crashes); `restore_backup` snapshots the current files first;
  `verify_world` feeds the menu's `RecoveryPanel`.
- **Crash handling** (`CrashHandler`): `user://sessions/<pid>.lock` with a heartbeat (scene, world,
  position); stale locks of dead processes become `crash_reports/<stamp>/report.txt` + `log_tail.txt`
  (previous rotated log). `NOTIFICATION_CRASH` → `emergency_save()` → `SaveManager.snapshot_world(…,
  "crash")`. The main menu shows `crashed_last_time`.
- **Platform** (`Platform` autoload, `src/platform/`): `Achievements.LIST`/`STATS` define everything;
  Events update stats (`add_stat`) and unlock achievements; the profile (`[achievements]`, `[stats]`)
  is the source of truth and is mirrored to the backend. `PlatformBackend` is the local platform;
  `SteamBackend` wraps the GodotSteam singleton with `has_method` guards (tests inject a fake).
- **Release**: `export_presets.cfg` (Windows, Linux, Web), `tools/build_release.sh`,
  `tools/fetch_export_templates.py`, `tools/web/shardlands.html` (launcher that reassembles the split
  engine), `tools/export_steam_config.gd` → `platform/steam/`. `ChunkManager.single_threaded` (no
  `threads` feature, i.e. the web build) limits streaming to one job per frame.

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
| New recipe | Add `data/recipes/<id>.tres` (`RecipeData`); for books add the id to an item's `teaches_recipes`. |
| New settlement building | Add a builder in `SettlementLayout` (use `_building()` for walled buildings) and give NPC roles a `work` point. |
| New shop item | Add it to `Economy.STOCK[role]` with a reputation tier (or `TRADER_POOL`). |
| New monster | Add `data/enemies/<id>.tres` (`MonsterData`: style, look, attacks, projectile, boss moves). Use it in `PoiLayout.THEME_MONSTERS` or a POI layout. |
| New POI kind | Add a `PoiInfo.Kind`, weights in `Exploration.WEIGHTS`, a builder in `PoiLayout`. |
| New loot | Add entries to `LootTables.TABLES` (with a minimum rank). |
| New crop | Add to `Farming.CROPS` + seed/produce items + `BuildMeshes.build_crop` visuals. |
| New build piece | Add `data/build_pieces/<id>.tres` (`BuildPieceData`) + `build_<mesh>()` in `BuildMeshes`. |
| New crafting station | A build piece with behaviour STATION and a `station_id`, plus the id in `RecipeData.STATION_IDS`. |
| New prop `data/props/<id>.tres` (`PropData`) + a `_build_<name>` mesh function in `PropLibrary`; reference it from a biome `PropRule`. |
| New enemy | Create `EnemyData` + `AttackData`s, a scene with an `Enemy` subclass script, and add an `EnemySpawnRule` to a biome. |
| New biome | Add a `BiomeData` (role + climate ranges + colours + prop rules) and append it to `data/worldgen/default_worldgen.tres`. |
| New class | Add `data/classes/<id>.tres` (50 starting points), add its id to `ClassRegistry.ORDER`, give it 3 `AbilityData`. |
| New ability | Add an `AbilityData` .tres and a `_ability_<effect>()` method in `PlayerAbilities`. |
| New weapon/armor | Add an `ItemData` with `equip_slot`, `stat_bonuses`, (weapons) `weapon_type` + `moveset`. |
| Save a new placeable | Put it under `World.placed_root` (via `place_object`) and implement `save_data()` / `load_data()`. |
| New input | Add to `InputSetup.KEY_BINDINGS`. |
