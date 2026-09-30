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

## Milestone 4 — Building & crafting  ✅ (this milestone, Phases 2 + 5)

- [x] Resource gathering for crafting: plant fiber (reeds, dead bushes, bushes, cacti), tool-gated ores
- [x] Tools: stone / copper / iron hatchets & pickaxes (tiers 1–3), used automatically from the inventory
- [x] Recipes (43, data-driven `data/recipes`): materials, tools, weapons, armor, accessories, food
- [x] Recipe learning: starting, discovery (first time you obtain an item), recipe books
- [x] Crafting stations: Workbench, Forge, Tailoring Table, Arcane Altar, Campfire (cooking)
- [x] Crafting never fails; Crafting skill lowers material cost and gates recipe tiers
- [x] Crafting screen (G): station tabs, nearby stations, have/need, craft ×1/×5
- [x] Grid building (1 m cells, floor/object/roof slots, shared edges), ghost preview, rotate, deconstruct
- [x] Floors, walls, doors, windows, fences, roofs (roofs hide when you are inside)
- [x] Furniture: table, chair, bed (respawn point + sleep), storage chest (16 slots), standing torch
- [x] Spike defenses (barricade + floor trap; charging boars take ×3 and are staggered)
- [x] Land claims (flag 8 m / totem 16 m): no monster spawns, full refunds, max 5, no overlap
- [x] Shelter affects temperature; torches give a little warmth
- [x] Buildings, chest contents, door states and known recipes are saved
- [ ] NOT IMPLEMENTED: item quality (Fine/Masterwork) — `Skill.quality_chance` exists, crafted items are always normal
- [ ] NOT IMPLEMENTED: building durability, monsters attacking/breaking buildings, raids
- [ ] NOT IMPLEMENTED: multi-storey buildings (one wall height; roofs sit on top of it), stairs, foundations on steep slopes
- [ ] NOT IMPLEMENTED: blueprints / auto-build, the companion web designer
- [ ] NOT IMPLEMENTED: crafting queues / crafting time (crafting is instant), station upgrades, fuel for forges
- [ ] NOT IMPLEMENTED: using materials straight from nearby chests while crafting or building
- [ ] Known limitation: the bed mesh is 1.9 m long in a 1 m cell and can overlap a neighbour cell's furniture

## Milestone 5 — Living world  ✅ (this milestone, Phases 3–4)

- [x] Villages: deterministic placement per 384 m region, flattened terrain, cleared props, no cave entrances or monster spawns, names
- [x] Kingdoms: one capital per realm (4x4 regions) with perimeter walls, gates, towers, keep & throne, barracks, royal market; villages join the nearest kingdom
- [x] Settlement layouts: houses (furnished, doors, roofs that hide when you're inside), shop, smithy, farms, plaza with well, stalls, notice board, banners, torches
- [x] Buildings merged into a few meshes on a worker thread; collision; streamed in/out around the player
- [x] NPCs: merchant, royal merchant, blacksmith/armorer, farmer, villager, guard, ruler, travelling trader; role looks and tools
- [x] NPC routines by hour (work, lunch, plaza in the evening, sleep at home); walking along a street graph through doors and farm gates
- [x] Guards fight monsters near capitals (no XP for their kills)
- [x] Dialogue: greetings by role and standing, gossip built from the world (unfound villages, caves, the capital, trader days, prices, bounties)
- [x] Shops & economy: coins (copper/silver/gold), regional supply & demand, reputation discounts, market saturation, daily restock and shop money, stock gated by reputation
- [x] Blacksmiths (metal tools, weapons, armor, ingots, smithing manual) and the village forge/workbench usable as crafting stations
- [x] Travelling traders every third day with rotating exotic stock
- [x] Reputation per settlement + kingdom (villages share 50%), 5 tiers, reputation screen (J), kingdom titles with gifts from the ruler
- [x] Notice-board requests: daily deliveries and boar hunts for coins, reputation and XP
- [x] Farming: seeds, farm plots, crop growth by world time, harvest, bread & vegetable stew; village farms worked by farmers
- [x] Map markers for discovered / heard-of settlements; HUD coins and current town
- [x] Save/load: coins, reputation, titles, shop states, requests, discovered towns, crops
- [ ] NOT IMPLEMENTED: crime/theft, attacking NPCs, losing reputation, guards chasing the player
- [ ] NOT IMPLEMENTED: roads between settlements and traders actually travelling between them (the trader appears on trader days)
- [ ] NOT IMPLEMENTED: NPC relationships, families, schedules by weekday, NPCs reacting to weather or combat (other than guards)
- [ ] NOT IMPLEMENTED: full quests (multi-step, story), dialogue trees with choices beyond the fixed options
- [ ] NOT IMPLEMENTED: buying houses, renting beds at an inn, raids on settlements, kingdom wars/politics
- [ ] NOT IMPLEMENTED: crop watering, seasons, animals/livestock; village crops can't be harvested by the player
- [ ] Known limitation: approaching a kingdom capital costs one ~40 ms frame on the main thread (collision nodes); geometry merges on a worker
- [ ] Known limitation: NPCs don't collide with each other or the player (they walk through people, not through walls)

## Phase 2 — Core RPG (remaining)

- [x] Crafting system (Milestone 4)
- [~] Recipe sources — books (cave caches, boars) and discovery done; villages, kingdoms, dungeons, bosses later
- [ ] More abilities per class / ability upgrades at higher levels (current unlocks: 1, 5, 15)
- [ ] Item quality (Fine/Masterwork) and gear drops from more sources (only boars drop gear today)
- [x] Basic NPCs (dialogue, shops) (Milestone 5)
- [ ] Respec (reset skill points)

## Phase 3 — World (remaining)

- [~] Chunk system & procedural terrain — heightmap columns on two layers; no overhangs / multi-level caves
- [x] Villages (houses, farms, market, blacksmith, shops, NPCs, traders) (Milestone 5)
- [ ] Structures: ruins, towers, temples, ancient structures, landmarks, hidden locations
- [ ] Mines (abandoned mine structures in caves); caves currently have ore-rich areas but no built mines
- [ ] Biome-specific enemies (only the Thornback Boar exists; it spawns in meadow, forest, jungle and taiga)
- [ ] Underground water, lava and deeper cave levels

## Phase 4 — Content

- [~] Kingdoms (castle, advanced blacksmith, rare shops, guards, reputation) — done in Milestone 5; kingdom quests not yet
- [ ] Dungeons ranks E–S with scaling enemies, mechanics, loot, bosses
- [ ] Bosses with unique mechanics
- [ ] More enemy categories (monsters, bandits, undead, magical, elites)
- [~] Farming (seeds, planting, harvesting) — Milestone 5; watering, seasons, rare/magical plants not yet
- [x] Trading & economy (per-settlement inventories and prices) (Milestone 5)
- [ ] Raids with warnings, reputation/popularity rewards
- [~] NPC routines and reputation (Milestone 5); relationships and reactions not yet

## Phase 5 — Building

- [x] Land claims (Claim Totem / Claim Flag) (Milestone 4)
- [x] Grid building: floors, walls, doors, windows, fences, spike walls, roofs, furniture, storage, workstations, defenses (Milestone 4)
- [x] Shelter affecting temperature (Milestone 4)
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
