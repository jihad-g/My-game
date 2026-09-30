# Project TODO

Legend: `[x]` completed (implemented + tested) · `[~]` in progress / partial (details given) · `[ ]` not started

Nothing below is marked `[x]` unless it runs in the game today.

## Phase 1 — Playable prototype  ✅ (this milestone)

- [x] Godot 4.4 project architecture (autoloads, components, data resources, scenes)
- [x] Main scene (`scenes/main.tscn`) with loading screen until spawn area is ready
- [x] Player (CharacterBody3D, blocky humanoid model with procedural animation)
- [x] Top-down tactical camera: follow, rotate (Q/E, MMB), tilt, zoom, free pan, recenter, shake
- [x] Trees between camera and player dither out (occlusion fade)
- [x] Camera-relative movement, sprint, step-up onto 1-block ledges, wading slowdown
- [x] Procedural terrain prototype (deterministic from seed, block columns, lakes, hills)
- [x] Chunk loading/unloading on worker threads, per-frame apply budget, chunk node pooling
- [x] 3-level terrain LOD (LOD0 collision+props, LOD1 visual props, LOD2 coarse)
- [x] One biome: Verdant Meadows (grass, oak/pine trees, boulders, berry bushes, flowers, sticks, stones)
- [x] One enemy: Thornback Boar (wander, alert, chase, bite, telegraphed charge, exposed recovery, wall daze, leash/return)
- [x] Real-time combat: 3-hit light combo, heavy attack, input buffer, dodge roll (i-frames), block, parry, lock-on, crits, backstab, knockback, poise/stagger, damage types & resistances
- [x] Health (regen after delay), stamina (sprint/dodge/heavy/block), death & respawn
- [x] Hunger (drain × activity × cold; state modifiers; starvation damage)
- [x] Temperature (air/day-night/altitude/water/regional; campfire heat; food warmth; 7 exposure levels with debuffs; never damages)
- [x] Basic inventory (24 slots, stacking, hotbar 1-8, move/merge, use, drop; UI)
- [x] Harvest trees/rocks, gather bushes/loose items, loot pickups with magnet, persistent removal + regrow
- [x] Campfire placeable (heat source, light, cooking raw → cooked meat)
- [x] Day/night cycle
- [x] HUD: health, stamina, hunger, temperature gauge + active debuffs, clock, target frame, hotbar, prompts, toasts, help, debug overlay, pause, death screen
- [x] Automated tests (111 checks, unit + integration) and screenshot runner

## Phase 2 — Core RPG

- [ ] Four classes: Barbarian, Knight, Wizard, Assassin (distinct kits; 50 starting skill points each)
- [ ] Skills 1–100: Strength, Mana Control, Defense, Crafting, Dexterity (meaningful effects)
- [ ] XP sources (combat, bosses, dungeons, exploration, landmarks, trading, farming, crafting, quests)
- [ ] XP curve 1–100 with unlock table (Level | XP required | Total XP | Unlocks)
- [ ] Mana & mana regen (`Stats.MANA_REGEN` already exists and is modified by temperature)
- [ ] Class abilities, special attacks, status effects (poison, burn, bleed, slow, freeze…)
- [ ] Magic Temperature Shield (10 min, mana cost per class, Wizard cheapest, requires +2 Mana Control)
- [ ] Equipment slots (weapons, shields, helmets, chest, gloves, boots, rings, amulets, special) — `TemperatureComponent.insulation/cooling` hooks ready
- [ ] Weapon categories per class (swords, shields, axes, staffs, wands, daggers…)
- [ ] Crafting (never fails; skill reduces material cost; tiers Basic → Legendary; recipe sources)
- [ ] Basic NPCs (dialogue, shops)

## Phase 3 — World

- [~] Chunk system & procedural terrain — done for heightmap terrain; no 3D voxels yet
- [ ] Multiple biomes: mountains, plains, forests, jungles, deserts, snow, swamps, rare magical biomes, islands (`TerrainGenerator.get_biome()` is the hook)
- [ ] Rivers (lakes exist)
- [ ] Caves, underground areas, mines
- [ ] Structures: ruins, towers, temples, ancient structures, landmarks, hidden locations
- [ ] Villages (houses, farms, market, bakery, blacksmith, shops, NPCs, traders)

## Phase 4 — Content

- [ ] Kingdoms (castle, advanced blacksmith, rare shops, guards, quests, reputation)
- [ ] Dungeons ranks E–S with scaling enemies, mechanics, loot, bosses
- [ ] Bosses with unique mechanics
- [ ] More enemy categories (monsters, bandits, undead, magical, elites)
- [ ] Farming (seeds, planting, watering, harvesting, rare/magical plants)
- [ ] Trading & economy (per-settlement inventories and prices) — items already have `base_value`
- [ ] Raids with warnings, reputation/popularity rewards
- [ ] NPC routines, relationships, reactions, reputation

## Phase 5 — Building

- [ ] Land claims (Claim Totem / Claim Flag)
- [ ] Grid building: floors, walls, doors, windows, fences, spike walls, roofs, furniture, storage, workstations, defenses
- [ ] Shelter affecting temperature
- [ ] Blueprint system (requirements, missing resources, auto-build) + companion web designer

## Phase 6 — Polish

- [ ] Save/load system (GameState + Inventory serialization already exist and are tested; no files/UI yet)
- [ ] Skeletal/authored animations, VFX, sound & music
- [ ] UI polish (real icons instead of coloured glyph tiles), settings & key rebinding menu
- [ ] Main menu with seed entry / world selection
- [ ] Optimization pass (profiling on real hardware, occlusion, GPU instancing everywhere)

## Phase 7 — Large world

- [~] Deterministic, borderless world addressing (verified generation at ±13 km)
- [ ] Region files for modified chunks, compressed saves
- [ ] Far-distance impostors / horizon LOD, streaming tuning for fast travel
- [ ] Floating origin (only needed beyond the ~±14 km target)
- [ ] Efficient off-screen NPC/settlement simulation

## Known issues / tech debt (Phase 1)

- Dropped loot pickups and placed campfires are not persisted when far away / on reload (no save system yet).
- Debug-spawned enemies (F8) are not tied to a chunk and never despawn unless killed.
- Enemy perception is distance-only (no line-of-sight or stealth yet).
- Terrain is a heightmap of block columns: no overhangs/caves until Phase 3.
- The Compatibility (OpenGL) renderer shows brighter colours than Forward+.
- Placeholder art: all meshes are code-built boxes, item icons are coloured tiles with a glyph.
