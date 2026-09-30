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

- `TerrainGenerator` (RefCounted, thread-safe): layered `FastNoiseLite` (continent, hills,
  ridges, detail) seeded via `HashUtils` → integer column heights (1 m × 0.5 m blocks).
  `generate_chunk(coord, lod)` returns a pure-data `ChunkData`: surface mesh arrays
  (only visible faces, edge skirts hide LOD seams), collision triangles (LOD0),
  water quads, prop placements and enemy spawn slots.
- Props use **world-aligned cells** (`PropRule.cell_size`) and hashed randomness, so the same
  prop appears regardless of chunk load order or LOD.
- `ChunkManager`: desired LOD rings (default radii 3/6/9 chunks → LOD0/1/2). Missing or
  wrong-LOD chunks are queued nearest-first and generated on `WorkerThreadPool`
  (max 4 in flight). Results are applied on the main thread (max 3 per frame). Chunks
  beyond the outer radius + margin return to a node pool. Stale results are discarded.
- `Chunk`: terrain `ArrayMesh`, `ConcavePolygonShape3D` collision (LOD0), water mesh,
  one `MultiMeshInstance3D` per prop type, and lightweight `PropBody` physics proxies
  (LOD0 only) for harvesting/gathering.
- LOD: LOD1/LOD2 sample every 2nd/4th column, no collision, LOD2 has no props or shadows.
  Props have visibility ranges; trees dither out near the camera.
- Large world: there is no world border. At the 3,000,000-chunk target (~1,732 chunks per
  side ≈ 27.7 km) coordinates stay within ±14 km of the origin — fine for 32-bit floats.
  Beyond that a floating origin would be required (not needed for the target).

## Persistence model (`GameState`)

`world_seed`, `world_time`, `removed_props[chunk][prop_index] = time` (with optional regrow
time per prop type), `enemy_deaths[slot_key] = time` (respawn time per enemy type).
`to_dict()/from_dict()` exist and are tested; the save system (files, player data, UI) is
not implemented yet.

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
| New biome | Add a `BiomeData`; implement biome selection in `TerrainGenerator.get_biome()` (Phase 3). |
| New input | Add to `InputSetup.KEY_BINDINGS`. |
