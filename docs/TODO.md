# Project TODO

Legend: `[x]` completed (implemented + tested) · `[~]` in progress / partial (details given) · `[ ]` not started

Nothing below is marked `[x]` unless it runs in the game today.

## Phase 1 — Playable prototype  ✅

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

## Milestone 2 — World generation  ✅ (this milestone, part of Phase 3)

- [x] Multiple biomes (11 surface + 1 underground), data-driven climate selection
- [x] Oceans, islands, beaches
- [x] Rivers (meandering, sea-level channels with sloped banks) and lakes; frozen lakes in the tundra
- [x] Mountains (ridged, up to ~60 m, rock and snow caps) and altitude cooling
- [x] Caves: streamed underground layer with tunnels and caverns, surface entrances and exits
- [x] Procedural vegetation per biome (22 new props, glowing magical plants)
- [x] Resource spawning: copper/iron/coal veins, crystals, clay, rare plants, regrowth
- [x] World seeds: create worlds from any number/text seed, random seeds, quick play, `--seed=`
- [x] Save/load generated worlds (menu, world list, autosave, crash-safe files, versioned format)
- [x] Swimming, world map (M), biome discovery tracking

## Milestone 3 — RPG foundation  ✅ (this milestone, Phase 2)

- [x] Four classes with distinct identities, 50 starting skill points each, class looks
- [x] Levels 1–100, XP curve and XP table (`docs/XP_TABLE.md`)
- [x] XP from combat (level-scaled), discovery, caves, harvesting, gathering, cooking
- [x] Strength, Mana Control, Defense, Crafting, Dexterity 1–100 with effects + milestone perks
- [x] Mana
- [x] Class-specific abilities (3 per class) + Barbarian Rage
- [x] Magic Temperature Shield (10 min, per-class cost, Wizard cheapest, MC +2 requirement)
- [x] Equipment slots, stat system, level requirements, weapon movesets & proficiencies
- [x] Status effects (burn, poison, freeze, stun), taunt, stealth, spell combinations
- [x] Character screen, ability bar, class selection

## Phase 2 — Core RPG (remaining)

- [ ] Crafting system (recipes, stations, material tiers; skill formulas already exist and are tested)
- [ ] Recipe sources (villages, kingdoms, books, scrolls, dungeons, bosses)
- [ ] More abilities per class / ability upgrades at higher levels (current unlocks: 1, 5, 15)
- [ ] Item quality (Fine/Masterwork) and gear drops from more sources (only boars drop gear today)
- [ ] Basic NPCs (dialogue, shops)
- [ ] Respec (reset skill points)

## Phase 3 — World (remaining)

- [~] Chunk system & procedural terrain — heightmap columns on two layers; no overhangs / multi-level caves
- [ ] Villages (houses, farms, market, bakery, blacksmith, shops, NPCs, traders)
- [ ] Structures: ruins, towers, temples, ancient structures, landmarks, hidden locations
- [ ] Mines (abandoned mine structures in caves); caves currently have ore-rich areas but no built mines
- [ ] Biome-specific enemies (only the Thornback Boar exists; it spawns in meadow, forest, jungle and taiga)
- [ ] Underground water, lava and deeper cave levels

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

- [x] Save/load system (Milestone 2)
- [ ] Cloud saves / save slots per character, save thumbnails
- [ ] Skeletal/authored animations, VFX, sound & music
- [ ] UI polish (real icons instead of coloured glyph tiles), settings & key rebinding menu
- [x] Main menu with seed entry / world selection (Milestone 2)
- [ ] Settings menu (graphics, audio, key rebinding)
- [ ] Optimization pass (profiling on real hardware, occlusion, GPU instancing everywhere)

## Phase 7 — Large world

- [~] Deterministic, borderless world addressing (verified generation at ±13 km)
- [ ] Region files for modified chunks, compressed saves (today: one JSON file per world; fine for thousands of changes)
- [ ] Far-distance impostors / horizon LOD, streaming tuning for fast travel
- [ ] Floating origin (only needed beyond the ~±14 km target)
- [ ] Efficient off-screen NPC/settlement simulation

## Known issues / tech debt

- Dropped loot pickups are not saved (they despawn after 5 minutes anyway). Enemies are not saved (killed spawn slots are).
- Swimming never drowns you; with no stamina you just swim slowly.
- Most higher-tier gear can only be obtained with the F10 debug key until crafting exists.
- Abilities have no dedicated animations/sounds yet (procedural model poses + simple VFX).
- Enemies have a level but no level-based stat scaling yet (only one enemy type exists).
- The world map reveals everything (no fog-of-war yet).
- Placed objects on the other layer stay in memory (harmless, but not culled).
- Debug-spawned enemies (F8) are not tied to a chunk and never despawn unless killed.
- Enemy perception is distance-only (no line-of-sight or stealth yet).
- Terrain is a heightmap of block columns per layer: no overhangs or multi-level caves.
- The Compatibility (OpenGL) renderer shows brighter colours than Forward+.
- Placeholder art: all meshes are code-built boxes, item icons are coloured tiles with a glyph.
