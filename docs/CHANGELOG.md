# Changelog

All notable changes to this project. Format loosely follows *Keep a Changelog*.

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
