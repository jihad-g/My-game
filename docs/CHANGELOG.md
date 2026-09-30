# Changelog

All notable changes to this project. Format loosely follows *Keep a Changelog*.

## [0.2.0] — Milestone 2: World generation

### Added
- **Continuous climate-driven terrain** (`TerrainGenerator` rewrite): continentalness,
  hills, ridged mountains (up to ~60 m), island noise, temperature & moisture fields,
  swamp flattening, desert dunes, lakes, and meandering domain-warped **rivers** that
  fade out in high mountains. Terrain shape never depends on the biome, so there are no seams.
- **11 surface biomes + 1 underground biome**, chosen data-driven from climate
  (`BiomeData.role`, temperature/moisture ranges): Deep Ocean, Sandy Beach, Stonecrown
  Mountains (snow-capped peaks), Crystal Glade (rare magical biome), Murk Swamp,
  Sunscorch Desert, Emerald Jungle, Snowy Tundra (frozen, walkable lakes), Frostpine
  Taiga, Whispering Forest, Verdant Meadows, and The Deeps (caves).
- `WorldGenSettings` resource (`data/worldgen/default_worldgen.tres`) holding every
  generation parameter and the biome list.
- **Caves**: a streamed underground layer (`TerrainGenerator.Layer.UNDERGROUND`) under the
  whole world — noise tunnels + caverns, rooms guaranteed under every entrance.
  Deterministic **cave entrances** on the surface and matching **rope-ladder exits**
  below (`CavePassage`), layer travel with loading screen, dark cave lighting, player
  lantern, steady 12 °C cave climate.
- **Procedural vegetation** per biome (22 new props): jungle, palm, snowy pine, swamp
  willow and dead trees, cacti, reeds, lily pads (float on water), giant toadstools,
  mushrooms, glowcaps, crystal clusters, moonpetals, frostberry bushes, snowy and
  sandstone rocks, stalagmites, clay deposits. Props can glow (`PropData.glow`).
- **Resource spawning**: copper, iron and coal veins (mountains, hills, caves),
  crystal clusters (Crystal Glade, caves), clay (rivers, swamps), rare magical plants
  (Moonpetal, Glowcap); all regrow after data-defined times.
- 11 new items: copper ore, iron ore, coal, crystal shard, clay, cactus fruit (cooling),
  coconut (cooling), brown mushroom, glowcap, frostberries, moonpetal.
- **Swimming** in deep water (buoyancy, slower, costs stamina, climb out onto banks).
- Per-position **climate temperature** (continuous, deserts swing hot/cold day-night,
  mountains cold by altitude), replacing per-biome constants.
- **World seeds & save system**: main menu (create world with name + seed or random,
  quick play, world list with play/delete, open saves folder), `SaveManager` autoload,
  JSON saves in `user://worlds/<id>/` (crash-safe temp file + `.bak` fallback, save
  version + migration hook), autosave every 2 min, F5 quick save, save on quit/menu.
  Saved: seed, world time, time of day, layer, player position/spawn/stats/buffs/inventory,
  world changes (both layers), killed spawn slots, discovered biomes, placed campfires.
  Command line: `-- --seed=<x>` (quick play) and `-- --world=<id>` (load).
- **World map** (M): rendered on a worker thread from the generator — biome colours,
  height shading, water, cave entrances; cave layout when underground.
- Biome name in the HUD, "Discovered: <biome>" toasts (persisted).
- Tests: terrain statistics, biome distribution, climate continuity, caves,
  swimming, layer travel, full save/load round trip incl. corrupt-save fallback (191 checks).

### Changed
- Removed-prop records are keyed by chunk **and layer**; enemy spawn slots use the
  biome at the chunk centre; props pick rules from the biome of their own column.
- `World.place_object()` returns the placed node (or null).
- Main scene is now the main menu (`scenes/menu/main_menu.tscn`).

## [0.1.0] — Phase 1: Playable prototype

### Added
- Godot 4.4 project with autoloads: `InputSetup` (code-defined input map), `Events`
  (signal bus), `GameState` (seed, world time, world modifications, serialization),
  `ItemDB` (data-driven item registry).
- Deterministic procedural terrain (`TerrainGenerator`): layered noise, block columns,
  lakes and hills, per-column colour variation, `--seed=` command-line option.
- Chunk streaming (`ChunkManager`, `Chunk`): worker-thread generation, main-thread apply
  budget, 3 LOD rings, edge skirts, chunk pooling, stale result discarding.
- Verdant Meadows biome with data-driven prop rules (oak, pine, boulder, berry bush,
  flowers, grass, stick piles, stone piles) rendered with MultiMesh.
- Harvesting (trees, rocks), gathering (bushes, loose items), persistent removal with
  regrow timers, loot pickups with magnet/auto-collect (pooled).
- Player: movement, sprint, step-up, wading, dodge roll with i-frames, block & parry,
  lock-on, interaction, hotbar use, drop, death & respawn.
- Combat: `AttackData` resources, 3-hit light combo, heavy attack, input buffering,
  cancel windows, crits, backstab bonus, knockback, poise & stagger, damage types.
- Enemy framework (`Enemy`, `EnemyData`, `LootEntry`, `EnemySpawner`) with pooling and
  deterministic per-chunk spawn slots that remember kills; Thornback Boar AI.
- Survival: `HealthComponent`, `StaminaComponent`, `HungerComponent`,
  `TemperatureComponent` (never damages), `StatBlock` modifier aggregation.
- Day/night cycle with temperature swing; campfire (heat, light, cooking).
- Tactical camera rig (rotate, tilt, zoom, pan, recenter, shake, near-camera tree fade).
- HUD (bars, temperature gauge + debuff list, hotbar, inventory window, target frame,
  prompts, toasts, clock, help, debug overlay, pause, death & loading screens).
- 10 items, 6 attacks, 1 enemy, 8 props, 1 biome as `.tres` data.
- Test suite (`tests/test_runner.tscn`, 111 checks) and screenshot runner.
