# Changelog

All notable changes to this project. Format loosely follows *Keep a Changelog*.

## [0.3.0] — Milestone 3: RPG foundation

### Added
- **Four classes** (`data/classes/*.tres`, `ClassData`): Barbarian, Knight, Wizard, Assassin —
  exactly 50 starting skill points each, class base health/stamina/mana, per-skill
  efficiency (a max-Strength Wizard still hits softer than a starting Knight), weapon
  proficiencies, block/parry/backstab/crit passives, Barbarian Rage, starter gear,
  class look (horns & fur, helmet & plume, wizard hat & robe, hood & mask).
  Class is chosen when creating a world (menu) or with `-- --class=<id>`.
- **Levels 1–100 & XP** (`Progression`): curve 100 → ~368k XP per level (≈9.8M total),
  2 skill points per level (+1 every 5th), full heal on level-up, level-difference XP
  scaling. XP sources: kills, biome discovery, new caves, harvesting/gathering, cooking;
  boss/dungeon/quest/trading/farming hooks.
- **Five skills 1–100** (`Skill`): Strength, Mana Control, Defense, Crafting, Dexterity with
  continuous effects and 4–5 milestone perks each (all implemented in the formulas).
  Crafting already boosts harvest yield and cooking; material-cost, recipe-tier and
  quality formulas are ready for the crafting milestone.
- **Equipment** (`Equipment`, `ItemData` equip fields): 8 slots (main/off hand, head,
  chest, hands, feet, ring, amulet), stat bonuses (armor, damage, spell power, crit,
  speeds, max health/mana/stamina, regen, temperature protection, skill bonuses), level
  requirements, weapon movesets (sword, axe, dagger, staff, unarmed), shields.
  25 gear items; boars can drop gear.
- **Armor & damage pipeline**: armor → damage reduction (capped 75%), class/weapon/skill
  multipliers, crit chance/damage, backstab multiplier, poise and knockback scaling.
- **Mana** (`ManaComponent`) with Mana Control–based max/regen.
- **Class abilities** (`PlayerAbilities`, `AbilityData`), keys Z/X/C, unlocked at levels 1/5/15:
  Barbarian Whirlwind, Battle Cry, Berserk · Knight Shield Bash, Guardian Stance,
  Rallying Charge · Wizard Firebolt, Frost Nova, Chain Lightning · Assassin Shadow Step,
  Poison Blade, Vanish.
- **Magic Temperature Shield** (T) for every class: 10 minutes, mana cost per class
  (Wizard cheapest), requires Mana Control 2 above the class's starting value.
- **Status effects** (`StatusEffects`): burn, stacking poison, chilled, frozen, stunned;
  taunt; spell combos (Firebolt shatters frozen enemies ×2, lightning ×1.5 in water);
  stealth-aware enemy perception.
- Swept-sphere projectiles, code-built VFX (rings, bursts, lightning).
- UI: mana, XP (level) and Rage bars, ability bar with cooldowns/lock states, buff list,
  level-up banner, XP toasts, **character screen (K)** with skill allocation, effects,
  next perks, attributes and equipment slots. Class picker in the main menu; world list
  shows class and level.
- Saves: class, level, XP, skills, unspent points, equipment, mana, rage, active
  Temperature Shield.
- Debug: F10 gives a sample of all gear tiers, F11 grants one level of XP.
- Docs generated from code: `docs/XP_TABLE.md`, `docs/CLASSES_AND_SKILLS.md`
  (`tools/gen_rpg_tables.gd`).
- Tests: 308 checks (class data, XP curve, skill balance, equipment, every ability in the
  live game, RPG save/load).

### Changed
- `PlayerCombat` damage now flows through `CharacterStats` (class, skills, weapon,
  proficiency, buffs); attacks come from the equipped weapon's moveset.
- `Enemy.receive_hit()` returns damage dealt; enemies have `StatusEffects` and a level.

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
