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
- [x] Building durability, monsters breaking buildings, raids (Milestone 7)
- [ ] NOT IMPLEMENTED: multi-storey buildings (one wall height; roofs sit on top of it), stairs, foundations on steep slopes
- [x] Blueprints / auto-build and the companion web designer (Milestone 8)
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
- [ ] NOT IMPLEMENTED: buying houses, renting beds at an inn, kingdom wars/politics (raids on settlements: Milestone 7)
- [ ] NOT IMPLEMENTED: crop watering, seasons, animals/livestock; village crops can't be harvested by the player
- [ ] Known limitation: approaching a kingdom capital costs one ~40 ms frame on the main thread (collision nodes); geometry merges on a worker
- [ ] Known limitation: NPCs don't collide with each other or the player (they walk through people, not through walls)

## Milestone 18c — Flow of Battle: spells that look like magic, Creative mode  ✅

- [x] VFX library v2: soft particles (GPU, CPU fallback), pooling, ground marks, branching lightning, sky beams, light flashes
- [x] A look for each element (fire, frost, lightning, arcane, holy, poison, shadow)
- [x] Cast glow and element sound for every magic ability and spell; projectile trails and element impacts; glowing ground areas; ice shell on frozen enemies
- [x] Ultimate moments: slow motion (alone only), screen flash, ground mark, a sound per class
- [x] Creative mode for testing (` key): god mode, free and instant abilities, levels, spells, test kit, spawns, clear enemies, day/night
- [~] Tests `test_m18c_*` are written but have not been run yet
- [ ] NOT IMPLEMENTED: a hand-picked effect for every single one of the 240 abilities and spells - they share the element looks; most look different by element, shape and colour
- [ ] NOT IMPLEMENTED: Creative mode in co-op, and saving Creative mode (it is off after loading)
- [ ] Known limitation: the colour of older effects decides their element (a few may pick a near element)
- [ ] Next: M18d — smoother world generation (no pop-in, smoother hills, blended biome borders, smooth streaming)

## Milestone 18b — Flow of Battle: hack and slash  ✅

- [x] Combo chains ending in finishers for every melee weapon (9 finisher attacks), hold attack to keep chaining, aim assist
- [x] Hit-stop (setting, 0 = off), directional enemy flinches, knock-downs and getting up (bosses only after their poise breaks)
- [x] Three fodder enemies in packs of 4–10 in 8 biomes; up to 60 active enemies; death puffs
- [x] Heavy enemy attacks show a filling red ground warning; elites are outlined and roar
- [x] AI level of detail: idle enemies far from players think every 4th frame
- [~] Tests `test_m18b_*` (and the updated combo-length checks) are written but have not been run yet
- [ ] NOT IMPLEMENTED: damage on the animation's "hit" event (combat keeps its own clock; both start the strike at the end of the wind-up)
- [ ] NOT IMPLEMENTED: crowd performance measured (60 enemies at 60 fps is a goal, not yet measured with the stress tool)
- [ ] NOT IMPLEMENTED: simple models for distant enemies and a pool for death effects (from the plan)
- [ ] Known limitation: knocked-down humanoids tip backwards as a whole (no separate fall animation); boars and other old-style beasts don't flinch
- [x] M18c done (v0.23.0)

## Milestone 18a — Flow of Battle: animation system and smooth movement  ✅

- [x] Compact animation system: keyframe clips, three layers (base, action, additive), cross-fades, a leg mask while running, clip events
- [x] Attacks, the 17 ability poses, spells, the dodge, flinches and landings are clips; used by the player, NPCs, humanoid monsters and co-op players
- [x] Locomotion: stride matches the speed (no foot sliding), lean when speeding up and turning, foot shuffle when turning on the spot, glide up block steps
- [x] Movement feel setting (Snappy default / Weighty); dodge v2 (cancels attack recovery, works with half the stamina, ends in a slide)
- [x] Camera lead, smooth shake, fixed isometric camera option
- [~] Tests `test_m18a_*` are written but have not been run yet (run them only with the owner's permission)
- [ ] NOT IMPLEMENTED: root motion that moves the body (attacks still move you with the old lunge; the clip step is only visual)
- [ ] NOT IMPLEMENTED: damage on the clip's "hit" event (the event exists; combat still uses its own timer, which matches the wind-up) - M18b
- [x] Hit reactions by direction, knock-downs, combo chains and hit-stop (done in M18b)
- [ ] Known limitation: monsters with their own bodies (wolves, boars, golems...) still use their old animation
- [x] M18b done (v0.22.0)

## Milestone 17d — Heroes' Arsenal: abilities 66–100, ultimates, upgrades  ✅

- [x] 72 new class abilities for levels 66–100 (18 per class, 24 passives); every class has 53 abilities
- [x] Four ultimates at level 100 (Wrath of the Ancients, Paladin's Oath, Shard Nova, Night's Embrace)
- [x] Ability upgrades from level 30: two choices per active ability, chosen at a bed or campfire, saved
- [x] 12 special upgrades for the starting abilities; Empowered / Swift for the others
- [x] New summons (ghost warriors, spirit knight, elemental beast, living shadow) and 4 new poses
- [x] Fixed: Explosive Trap now explodes; Comet Shower's first comet hits the aimed spot
- [ ] NOT IMPLEMENTED: Cleansing Light and other abilities helping friends (real co-op is M19)
- [ ] NOT IMPLEMENTED: Arcane Beam you hold down (it fires for 3 s by itself); Summon Elemental lets you pick the element (it uses the last element you cast)
- [ ] NOT IMPLEMENTED: real hit-by-hit copies for Living Shadow (it repeats your hits as damage; the shadow only follows you)
- [ ] Known limitation: summons use existing monster bodies with a coloured glow (ghost warriors are brute bodies, the elemental is a wolf body)
- [ ] Known limitation: ultimates and the strongest passives are not balance-tested in long fights yet
- [x] M18a started "Flow of Battle" (plan: `docs/M18_PLAN.md`)

## Milestone 17c — Heroes' Arsenal: abilities 32–64, shared spells, animations  ✅

- [x] 68 new class abilities for levels 32–64 (17 per class, 20 passives)
- [x] 20 shared spells with tomes, and places to find every tome
- [x] Ability and spell poses (13), sent to co-op players; two-handed weapon stances and swings; bows in the left hand
- [x] Tamed beasts and a summoned spirit wolf that fight for you
- [x] Abilities for levels 66–100 and the ultimates (done in M17d)
- [ ] NOT IMPLEMENTED: abilities that help friends (Oath of Protection link, Banner and Rejuvenate on friends) - co-op combat is M19
- [ ] NOT IMPLEMENTED: Light keeping night-only creatures away
- [ ] Known limitation: Tame Beast works on wolves, deer, rabbits and crabs (the Thornback Boar uses an older enemy type)
- [ ] Known limitation: poses are blended key poses, not full animations; a pet's or a decoy's targets are only recalculated by monsters near it
- [x] M17d done (v0.20.0)

## Milestone 17b — Heroes' Arsenal: the ability book  ✅

- [x] Ability book (L) with Abilities and Spells pages; 15 new abilities per class (levels 2–30), 60 in total
- [x] 15 passive abilities (always on)
- [x] 6-slot ability bar (Z X C T V U), changed at a bed or a campfire, saved with the character
- [x] Third spell slot (N) with the Tome of Embers
- [x] Abilities for levels 32–64 and the 20 shared spells (done in M17c)
- [x] Ability upgrades at level 30 (done in M17d)
- [ ] NOT IMPLEMENTED: Holy Light healing friends, Taunting Shout protecting friends (co-op combat is M19)
- [x] Ability poses (done in M17c)
- [ ] Known limitation: Polymorph shrinks the enemy and stuns it instead of drawing a real chicken

## Milestone 17a — Heroes' Arsenal: weapons and new attacks  ✅

- [x] Six new weapon types: bow, spear, war hammer, greatsword, wand and tome (off hand)
- [x] 20 new weapons (two legendary), 5 kinds of arrows, two weapon recipe books; shops, chests and boss drops
- [x] Two-handed weapons (bow, greatsword, war hammer) and caster off-hands
- [x] Charged heavy attack, sprint attack, plunging attack, riposte after a perfect parry
- [x] Weapon powers and legendary powers (stun, ward break, chill, burn, poison, undead healing, falling stars, shockwave, heal on kill)
- [x] The Tome of Embers' extra spell slot (done in Milestone 17b)
- [ ] NOT IMPLEMENTED: arrows that fall with gravity, arrows you can pick up again, crossbows and throwing weapons
- [ ] NOT IMPLEMENTED: a jump key (plunging attacks only happen when you walk off a ledge or a cliff)
- [x] Two-handed body animations (both arms on the weapon) - done in M17c
- [ ] Known limitation: in co-op, a guest's arrows and new attacks only hit enemies on the guest's own screen (shared combat is Milestone 18)

## Milestone 16 — The Lost Shards  ✅

- [x] Quest system and journal (O): multi-step quests, goals, rewards, tracker with distance and direction, saved with the world
- [x] Main quest "The Lost Shards" (5 steps, 3 Shard Keepers, the altar, the Starborn Colossus, title Shardbearer)
- [x] Royal errands: one per kingdom (deliver, hunt, dungeon, report) ending in a knighthood
- [x] Dialogue choices in quest conversations (with consequences for the royal errand)
- [x] Lore: 12 history pages, boss pages, generated kingdom histories; class backstories; intro and ending pages
- [x] Chronicle of the player's big moments
- [ ] NOT IMPLEMENTED: map markers for quest goals (the tracker gives distance and direction instead)
- [ ] NOT IMPLEMENTED: voiced or branching dialogue trees; quest choices that change the story's ending
- [ ] NOT IMPLEMENTED: quests for guests in co-op (quest progress is stored in the host's world; guests see their own local journal but it is not saved)
- [ ] Known limitation: the Shard Keepers are the dungeon bosses, so the main quest needs one dungeon of each theme (crypt, sanctum, grotto); the tracker points to the nearest one of the right theme
- [ ] Known limitation: lore pages only come from chests opened after Milestone 16

## Milestone 15 — Living Wilds  ✅

- [x] Wild spawns for every land biome (2–4 creatures each, `WildSpawns`), groups for packs and herds
- [x] Frost Wolf (pack hunter, howl calls the pack, chilling bite, weak to fire)
- [x] Sand Scorpion (buried until you come close, moving-sand tell, poison sting)
- [x] Shore Crab; peaceful Deer and Rabbits that flee and drop meat and Wild Hide
- [x] Wild treasure: abandoned camps, shipwrecks, buried caches with once-per-world chests
- [x] More POIs within 3 km of spawn (E/D/C content for the early game)
- [x] Item quality: Fine / Masterwork crafted gear (fixes the Grandmaster perk text)
- [x] Respec: Draught of Forgetting
- [x] More gloves, boots and rings (Mithril Gauntlets/Greaves, Wanderer's Boots, Ring of Embers, Ring of Swiftness)
- [ ] NOT IMPLEMENTED: wild spawns in caves (The Deeps) - the spawner only fills surface chunks
- [ ] NOT IMPLEMENTED: birds and fish (3h lists them); night-only creatures; bandit camps with prisoners
- [ ] NOT IMPLEMENTED: digging - buried caches are opened like a chest (no shovel needed)
- [ ] Known limitation: quality only comes from crafting (loot and shops sell Normal items)
- [ ] Known limitation: shipwrecks are rare because beaches are thin strips

## Milestone 14 — Outfits & Gear Makes the Hero  ✅

- [x] One shared body for all classes; looks come from the equipped head, chest, hands, feet, off-hand and amulet (27 code-built looks, tinted by the item); helmets and hoods hide the hair
- [x] Character customisation: skin tone (6), hair colour (8), hair style (short, long, topknot, bald) and beard; saved per character, older saves get a class default
- [x] Souls-like character creation screen: 3D preview in the starting kit, skill bars with gear bonuses, health/mana/armour, class talent and abilities, kit and supplies, body options
- [x] Full starting kits: weapon + complete 4-piece set + class supplies (Squire's Kit, Raider's Furs, Shadowstalker's Garb, Apprentice's Vestments)
- [x] Gear sets with 2- and 4-piece bonuses (`GearSets`); new gear stats physical damage %, backstab %, parry window
- [x] Armour weight (Light / Medium / Heavy) on every armour piece and shield: changes how far away idle enemies notice you and the stamina cost of a dodge
- [x] +1 / +2 skill bonuses on everyday armour, clothes and set pieces
- [x] New armour with recipes any class can craft (set pieces, class starting hats, iron helm/gauntlets/greaves, soft leather boots); set pieces in shops and E-rank loot
- [x] Option A class talent: classes keep skill efficiency, class power, best weapon and abilities; off-class weapons ×0.85–0.95; a Wizard never equals a Knight (×0.66 of a max Knight in full iron with a sword; tested)
- [x] Character screen and tooltips show armour weight and sets; outfits and bodies are synced in multiplayer (also for late joiners)
- [ ] NOT IMPLEMENTED: ability ranks that level up with use, or learning another class's abilities (class abilities stay per class, unlocked at levels 1 / 5 / 15)
- [ ] NOT IMPLEMENTED: a different starting place per class (everyone starts at the world spawn)
- [ ] NOT IMPLEMENTED: higher-tier versions of the four sets (only the starting tier exists, plus the Shadow Cloak as a level-15 Shadowstalker piece)
- [ ] NOT IMPLEMENTED: dyes / colouring your own gear; face options; changing the body after creation; ring looks (rings are not drawn)
- [ ] Known limitation: weight only affects noticing and dodging (no swim or sprint penalty); ranged and raiding enemies that are already fighting ignore it
- [ ] Known limitation: with the crash notice showing, the menu is taller than a 900-pixel-high window (Quick play can be cut off)


## Milestone 13 — Beta / Release preparation  ✅

- [x] Tutorial: 16 contextual hints (moving, camera, gathering, bag, crafting, chopping, combat, hunger, cold, levelling, building, night, villages, points of interest, collapsing, guide) shown when the situation comes up, with the real key names; progress per player profile; turn off or replay in Settings
- [x] Guide (F1): every control with current keyboard and gamepad bindings, plus pages on survival, combat, the character, crafting and building, the world and saving
- [x] Settings: tabbed screen (Gameplay, Controls, Audio, Display & graphics, Accessibility); difficulty (Story / Normal / Hard: damage taken and hunger), autosave interval or off, damage numbers, camera rotation speed, frame-rate cap, FPS counter
- [x] Controls: rebinding for keyboard/mouse and gamepad separately, conflict warnings, per-action and full reset, saved in settings.cfg; default gamepad layout; aiming follows the left stick on a pad; toggle sprint
- [x] Accessibility: interface scale 75-150%, colour-vision filters (protanopia, deuteranopia, tritanopia), high-contrast interface, sound captions with direction, reduced flashing (lightning, hit flashes, low-health pulse), reduced motion (panel animations, camera shake)
- [x] Save recovery: SHA-256 checksums on save files, the previous save kept as .bak, up to 6 snapshots per world (with region files) on load, every 10 minutes of play and on crashes; loading falls back save → .bak → newest good snapshot and tells the player; Recover screen in the menu (health check, restore with undo)
- [x] Crash handling: per-process session locks; an unclean exit produces a crash report (session, system, log tail) and a notice in the main menu; an engine crash writes an emergency snapshot of the world; file logging on
- [x] Platform layer: achievements (20) and lifetime stats in the player profile, Achievements screen, rich presence, overlay pause; Steam backend through GodotSteam (activates when the extension and an app id are present), Steamworks config generated from game data (platform/steam/), SteamPipe build scripts
- [x] Release tooling: export presets (Windows, Linux, Web), tools/build_release.sh, tools/fetch_export_templates.py, a browser build with a launcher page; docs/RELEASE.md
- [x] Optimization: single-threaded streaming mode for the browser build (one generation job per frame, no prefetch, smaller detail ring); benchmarks re-run (docs/PERFORMANCE.md)
- [x] Fixed: UI symbols missing in the browser (DejaVu Sans fallback font bundled); achievement progress read the wrong column; the first save of a new world skipped its backup when another world had been saved in the same session; the base-raid test could fail when arrow towers killed a whole wave early
- [ ] NOT IMPLEMENTED: languages other than English (all text is in code, ready for TranslationServer but not extracted)
- [ ] NOT IMPLEMENTED: menus with a gamepad (the game plays with a pad; menus and panels still need the mouse)
- [ ] NOT IMPLEMENTED: screen-reader support; captions cover important sounds only (not footsteps, ambience or music)
- [ ] NOT IMPLEMENTED: tested against real Steam (the backend is tested with a stand-in; GodotSteam and the Steamworks SDK are not bundled - see docs/RELEASE.md), achievement icons, Steam Cloud (configured on Steamworks as Auto-Cloud, documented)
- [ ] NOT IMPLEMENTED: code signing (Windows SmartScreen warns), macOS build, installer
- [ ] Known limitation: GDScript errors don't crash the game, so they only appear in the log (and in a crash report if the game later dies); a hard freeze is reported on the next start

## Milestone 12 — Alpha  ✅

- [x] Full gameplay loop, played by a bot with the real systems (`tests/playthrough.gd`, `tools/playthrough.tscn`): gather → stone tools → workbench → floors/walls → campfire → fight 5 monsters → hunt and cook → level up and spend points → sell/buy in the nearest village → craft and equip a sword → clear E-rank ruins and loot the chest; all four classes finish it in ~11 minutes of simulated play
- [x] Balance model (`BalanceModel`) and report (`tools/balance_report.tscn` → docs/BALANCE.md): per-class builds, best gear by level, time-to-kill / time-to-die against level-appropriate monsters, XP pacing, recipe value, shop arbitrage — the balance tests enforce the same numbers
- [x] Classes: Firebolt 16→24 damage / 12→9 mana, Wizard health 65→72 and spell power ×1.45; class power spread ≤ ×2.3 at every level; a max-Strength Wizard still hits ~45% as hard as a Knight
- [x] Gear tiers stretched to level 48 (Common 5, Uncommon 15, Rare 22, Very Rare 30, Magical 38, Legendary 48) so dungeons of every rank have gear to chase; new mid-tier weapons: Iron Dirk, Mithril Sword, Mithril Dirk, Mithril War Axe
- [x] XP: new curve (100 + 30·n^1.5 + 0.05·n³) — ~1 h to level 10, ~20 h to 50, ~400 h to 100; full XP within 5 levels of a monster; dungeon ranks scale ×1→×10 health, ×1→×4.6 damage, +0→+54 levels; wild monsters scale with distance from spawn (one rank per 1.2 km)
- [x] Crafting/economy: processed materials keep their value (ingots, leather, rope, planks ≥ ×1.0), gear is worth more than its materials, no recipe or town-to-town trade makes money from shop purchases (worst ×0.85); a single ingredient is never scaled up by low Crafting skill
- [x] World generation stress test across 20 seeds (spawn on land, towns and E-rank ruins in reach, valid meshes at the centre, far points, world edge and in caves, determinism, every dungeon floor) — 0 problems (docs/PERFORMANCE.md)
- [x] Performance benchmarks with budgets enforced by the tests: idle, 40-monster fight, 300+ building pieces, particle storms, 700 m teleports (docs/PERFORMANCE.md)
- [x] Fixed: monsters in a crowd ran 4 physics queries each per tick looking for stair steps (34 ms frames with 40 monsters → 9 ms)
- [x] Fixed: projectiles from monsters/arrow towers that died mid-flight logged errors (weak references)
- [x] Fixed: a novice needed 2 raw meat to cook 1 meal (and 2 of every "×1" ingredient)
- [ ] NOT IMPLEMENTED: frame-time budgets with rendering (the benchmarks run headless = CPU only; run `tools/stress_test.tscn` without `--headless` on target hardware)
- [ ] Known limitation: levels 75-100 rely on S-rank content only (the slowest stretch: ~550 min per level at 80); end-game content beyond S rank would smooth it
- [ ] Known limitation: the early game is forgiving (a level 1-10 character can take ~15-25 hits from a matching monster); packs and elites are the real threat

## Milestone 11 — Multiplayer Foundation  ✅

- [x] Networking architecture: `Net` autoload over ENet (UDP), one authoritative server, up to 8 players; listen server (host plays) and dedicated headless server (`--server`); join from the menu or `--connect=IP[:port]`; protocol version check; full protocol in docs/MULTIPLAYER.md
- [x] Server/client structure: `NetServer` (peers, validation, authoritative state, broadcasts) and `NetClient` (welcome, world setup, requests, applying server state); every guest action is a request validated against the server's state
- [x] Player synchronisation: 20 Hz state packets, 100 ms interpolation buffer with short extrapolation, puppets with class look, weapon, nameplate and replicated animations (attacks, dodges, casts, deaths, swimming, blocking, jumping); server speed check with corrections; join/leave notices; chat (Enter)
- [x] Multiplayer-safe world generation: terrain, biomes, props, caves, towns and POIs are generated locally from the seed (never sent); a world checksum in the welcome stops mismatched versions; world time/day/hour synchronised (weather follows)
- [x] World changes: felled/gathered props broadcast live and sent per 32×32-chunk region on join and while travelling
- [x] Inventory synchronisation: guests' inventories and equipment are owned by the server (read-only mirror on the guest); harvest, gather, pick up, drop, move, use, equip/unequip, craft and place objects are server-validated requests; networked pickups
- [x] Building synchronisation: place/remove/door through the server (reach, level, rules, materials), owners (guests can't remove others' buildings), host building/raids broadcast, full building list on join
- [x] Persistence: guests' characters (inventory, equipment, position, profile) saved with the host's world and restored when they rejoin (also on a dedicated server)
- [x] Tests: protocol/validation unit tests and a real two-process session (host + headless guest over localhost): join, checksum, puppets both ways, gather, build, ownership, drop/pickup, host changes reaching the guest, identical terrain, time sync, cheat correction, chat, records, dedicated server rejoin
- [ ] NOT IMPLEMENTED: combat in shared sessions (monsters, raids and rare events pause while online), PvP, shared bosses
- [ ] NOT IMPLEMENTED for guests: chests, NPC trading, village requests, farming, sleeping, campfire cooking, blueprints, dungeons (they get a message)
- [ ] NOT IMPLEMENTED: server-side character progression (level/skills/XP are client-reported), accounts/authentication, encryption, NAT traversal, lobby/server browser
- [ ] Known limitation: NPCs and settlement life are simulated per machine (same layouts, different NPC positions)

## Milestone 10 — Art & Polish  ✅ (Phase 6)

- [x] Sound: 71 effects (combat, footsteps on 5 surfaces, harvesting, magic by element, UI, thunder, horns...) generated by `tools/gen_audio.py` (pure-Python synthesis: oscillators, noise, filters, plucked strings, FM bells, reverb); positional 3D sound pool, pitch variation, rate limiting, cave reverb underground; every button clicks
- [x] Music: 7 generated looping tracks (menu, day, night, town, combat, dungeon, boss) with a music director that crossfades by situation
- [x] Ambience: 10 seamless loops (wind, strong wind, rain, heavy rain, birds, crickets, sea, caves, fire, town) mixed by biome, time, weather and place
- [x] Day/night: sky shader with sun and moon arcs, dawn/dusk colours, 8-day moon phases, twinkling stars, drifting blocky clouds; moonlight scales with the phase; light never comes from below the horizon
- [x] Weather: clear, cloudy, rain, thunderstorms (lightning bolts, flashes, delayed thunder), snow in the cold, fog, sandstorms in deserts; seeded per 5-minute spell and decided by the local climate; particles stop on roofs/terrain (heightfield collision); darker overcast light, closer fog, colder air (never lethal), Wet status in the rain; F2 cycles weather
- [x] Environmental effects: fireflies, falling leaves, pollen, desert dust, crystal sparkles, swamp mist, drifting snow, cave motes; foliage sways with the wind (shader); animated water (waves, ripples, glints, rain rings)
- [x] Final low-poly/voxel look: baked per-corner ambient occlusion on terrain, foliage and water shaders, voxel-debris particles
- [x] Animations: knees and elbows, idle breathing and glances, run lean, jump/fall pose, landing squash, swimming strokes, casting pose, knee-buckling death; boar idle sniffing and head bob; crawler leg lifts and sway; footstep events
- [x] VFX: weapon swing trails, hit and parry sparks, wood/stone chips, dust puffs on landing and sprinting, water splashes, healing and level-up motes, explosion debris
- [x] UI polish: pixel-art icons for all 135 items (45 drawings, material tints, auto shading and outline), rarity glow in slots, panels pop in with sound, low-health vignette and hit flash, clock shows weather and moon phase
- [x] Settings (main menu + pause): 5 volume sliders, fullscreen, V-Sync, render scale, shadows off/low/high, horizon terrain, weather/ambient/hit particles, screen shake; saved to user://settings.cfg
- [ ] NOT IMPLEMENTED: hand-authored models, textures or skeletal animation (everything stays code-built by design)
- [ ] NOT IMPLEMENTED: voice, per-enemy unique sounds beyond growls/bones, dynamic music layering (tracks crossfade as a whole)
- [x] Key rebinding and colour-vision filters (Milestone 13); gamepad menu navigation NOT IMPLEMENTED
- [ ] NOT IMPLEMENTED: weather effects on crops/fires (rain doesn't water farms or put out campfires), seasons
- [ ] Known limitation: the music and sound are synthesized; good placeholders with a consistent style, but a composer/sound designer pass would lift them

## Milestone 9 — Massive World  ✅ (Phase 7)

- [x] World size: chunks −866..+866 = 1733 × 1733 = **3,003,289 chunks** (27.7 × 27.7 km); continents sink into an edge ocean from 12.8 km; the player is kept inside ±13,856 m
- [x] Aggressive chunk streaming: worker count from the CPU (cores − 1, 2–8), main-thread build budget in milliseconds (4 ms/frame) instead of a fixed count
- [x] Chunk data cache: LRU with a 48 MB memory budget; going back, LOD flips and layer switches reuse generated data
- [x] Prefetch: velocity tracking, queue biased towards the direction of travel, rings around the predicted position (3 s ahead) generated with spare workers
- [x] Horizon LOD (FarTerrain): 64 m tiles, 8 m columns, out to 512 m, terrain + water + biome colours, generated on workers, cut out under the chunk rings; fog 150 → 470 m, camera far 640 m
- [x] World persistence: region files (32 × 32 chunks, ZSTD, lazy load, dirty flush on save, LRU eviction, atomic writes); v1 saves migrate automatically; delete_world removes region folders
- [x] Background generation: towns and POIs within 1.5 km of where you're heading are laid out on a worker
- [x] Optimization: terrain quad building ~30% faster (no temporary arrays, top colour computed once per column); benchmark numbers in docs/WORLD_SURVEY.md
- [x] Very large world testing: bounds, edge ocean all around, corner-chunk determinism, 1,500 random columns + 24 random LOD0 chunks anywhere, far tiles, region store (round trip, eviction, corruption, migration), save/load with regions, a 1.8 km fast journey with bounded chunks/nodes/cache/objects, the world edge
- [x] World survey tool (`tools/world_survey.tscn`): biomes, land/sea, heights, every settlement and POI in the world, generation benchmark → docs/WORLD_SURVEY.md
- [x] Debug overlay (F3): cache, prefetch, speed, build ms, far tiles, regions
- [ ] NOT IMPLEMENTED: fast travel / mounts / boats (the streaming handles 70 m/s, but nothing in the game moves that fast yet)
- [ ] NOT IMPLEMENTED: buildings, placed objects and construction sites are still in save.json (fine for bases; would move to regions for thousands of structures)
- [ ] NOT IMPLEMENTED: far-terrain impostors for trees, towns and POIs (the horizon shows terrain and water only)
- [ ] NOT IMPLEMENTED: off-screen simulation (settlements, raids and farms only advance near the player)
- [x] POI rank steps stretched from 700 m to 1.2 km (Milestone 12); most of the outer world is still rank S by design (see WORLD_SURVEY.md)
- [ ] Known limitation: the first chunk containing a new scene type (cave entrance, POI) can take ~20 ms to build once (scene load); later ones are ~1 ms

## Milestone 8 — Blueprint System  ✅ (this milestone, Phase 5)

- [x] Blueprint format: versioned JSON (`shardlands-blueprint` v1) shared by the game and the web designer; pieces at grid addresses relative to an anchor; validation with warnings (unknown pieces, wrong slots, duplicates, size limit)
- [x] Rotation of whole designs in 90° steps (edges stay edges, piece rotation follows); bounds, build order (floors → walls → furniture → roofs)
- [x] Resource calculation: total bill of materials, what you have (bag + chests nearby) and what's missing, required level, piece counts
- [x] Blueprint library: 4 built-in designs (Starter Hut, Stone Cottage, Watch Post, Farmstead) + your own in user://blueprints; save (never overwrites), import/export via clipboard, delete
- [x] Capture: save the buildings on your claim (or within 10 m) as a blueprint
- [x] Blueprint screen (N): list, top-down plan, materials need/have, warnings, place, export, delete, construction sites with progress, auto-build toggle and remove
- [x] Placement preview: the whole design follows the cursor as holograms, red where blocked, R rotates, left click lays out a site
- [x] Construction sites: holograms for every unbuilt piece (furniture rises onto floors), saved with the world, up to 8 at once
- [x] Manual construction: F on a hologram builds that piece
- [x] Automatic construction: one piece every 0.3 s while you're within 30 m, from your bag and chests within 18 m of the site; pauses with what's missing; skips blocked pieces; finishes and removes the site
- [x] External building-design website (first version): `web/blueprint-designer/index.html`, single file, offline; palette from the game's data (tools/build_designer.py), paint/erase/pan, edge snapping like the game, piece rotation, turn design, anchor tool, roof support check, bill of materials, undo/redo, examples, JSON import/export, local draft
- [ ] NOT IMPLEMENTED: hosting the designer on a public website with accounts and sharing (today it's a file in the repo; a private Artifact copy exists)
- [ ] NOT IMPLEMENTED: builder NPCs / workers (auto-build is "magic" construction near you), multi-storey blueprints (the building grid has one storey)
- [ ] NOT IMPLEMENTED: 3D preview in the web designer (it's a top-down plan)
- [ ] Known limitation: built-in .json blueprints need `*.json` in an export filter when the game is exported (the editor and tests read them directly)

## Milestone 7 — Advanced Gameplay  ✅

- [x] Status effects shared by player and enemies (`StatusEffects`): burn, poison (3 stacks), bleed (5 stacks), chill, freeze, stun, shock (+20% damage taken), wet, weakened (−25% damage), slowed, silenced, taunt; buffs regen and haste; immunities; HUD status chips
- [x] Elemental interactions: Steam (fire on wet), Doused (water puts out fire), Deep Freeze (chill a chilled/wet target), Shatter (fire on frozen ×2), Conducted (lightning on wet ×1.5), Combustion (fire ignites Miasma)
- [x] Water makes you (and enemies) wet; Defense 50 "Iron Skin" now really shortens harmful effects by 30%
- [x] Cures: bandages now also stop bleeding, antidotes (poison), purifying draught (everything), Troll's Brew (regeneration)
- [x] Advanced enemy AI: attack tokens (max 2 melee attackers, the rest circle you), pack alerts, flanking ranged strafing, dodging your swings, fleeing when badly hurt, separation, feeler-ray steering around walls/cliffs, hopping up ledges and detouring when stuck
- [x] Support casters: heal (Grotto Cultist, Bandit Hexer), ward (Tower Warden), haste
- [x] Elite affixes (9): vampiric, frenzied, molten, glacial, shielded, thorned, blinking, juggernaut, venomous; champions with 2; auras, name prefixes, ×2.2 health, elite loot table; in dungeons, raids, blood moons and eclipses
- [x] Boss mechanics: phases at 66%/33% (roar + invulnerable transition, new move lists, arena hazards: falling rocks, fire rain, poison pools, frost shards), poise break ("Broken!", exposed), ward shields powered by destructible pylons, new moves: spikes, nova, beam, meteor rain, teleport, pull, roar, bomb
- [x] All 4 M6 bosses got two extra phases; new bosses: Grimtusk the Warlord (raids), Starborn Colossus (meteor world boss)
- [x] Advanced magic: 8 spells learned from tomes (Blink, Healing Light, Miasma, Arcane Barrier, Arcane Missiles, Blizzard, Meteor, Storm Call), 2 spell slots (Y/H), spellbook (L), Mana Control requirements, any class can learn; tomes from towers, dungeons, elites, goblins and the Arcane Altar
- [x] Bandits: cutthroat (bleed), archer, brute (siege ×3), hexer (weakens, heals), bomber (exploding fire bombs, siege)
- [x] Building hit points by material, damage visuals, destruction (chests spill), repair in build mode (U / Shift+U) for 30% of the cost
- [x] Defenses: Log Palisade (700 HP), Reinforced Door (1200 HP), Arrow Tower (auto-shoots enemies), Alarm Bell (+45 s warning, ring to start the fight)
- [x] Base raids: at night once your claim has 8+ pieces; warning + countdown, 2–4 waves from one walkable side, raiders smash what's in their way, spoils + XP for winning, plunder of your chests if you abandon it; undead raid on blood moons
- [x] Settlement defense: riders warn of attacks on nearby towns; be there to defend (villagers hide, guards fight and can be knocked down) for reputation + coins; otherwise the guards hold or the town is plundered for 2 days (+25% prices); map markers and gossip
- [x] Rare events: Blood Moon, Meteor Shower (crater with star metal, sometimes the Starborn Colossus), Aurora (×2 mana regen, +15% spell damage), Treasure Goblin, Eclipse; sky tints; saved
- [x] Star metal: ore → ingots → Starmetal Amulet, Starfall Blade, Tome: Meteor
- [x] Debug keys: F4 raid (base or nearest town), F12 next rare event
- [ ] NOT IMPLEMENTED: real pathfinding (navmesh/A*) - monsters steer with feeler rays, hop and detour; complex terrain can still trap them
- [ ] NOT IMPLEMENTED: raiders don't open/burn doors specially or climb walls; they break through
- [ ] NOT IMPLEMENTED: raids against other player structures outside a claim, sieges with ladders/rams, raid difficulty settings
- [ ] NOT IMPLEMENTED: weather (rain making everyone wet), spell upgrades/talents, spell combos beyond the listed six
- [ ] NOT IMPLEMENTED: villagers dying or settlements being destroyed (plunder is economic only); kingdom-wide wars
- [ ] Known limitation: town raids only play out while you are near the town (otherwise the outcome is rolled)
- [ ] Known limitation: the active raid/event monsters are not saved (a raid in progress ends when you quit; announced town raids and events are saved)

## Milestone 6 — Exploration  ✅ (Phases 3–4)

- [x] Points of interest per 256 m cell, deterministic, ranked by distance (E near spawn → S far), kept clear of towns, flattened ground
- [x] Ruins: broken walls, pillars, skeleton guardians, chest, hidden vault under a cracked floor
- [x] Wizard towers: three-storey stone tower, door, roof hides inside, Tower Warden + wisps, lectern tome, chest
- [x] Temples: raised platform, pillars, braziers, statue, altar; dormant Temple Guardian boss; sealed golden chest with a guaranteed legendary recipe; altar blessing
- [x] Hidden groves: not on the map until found; ancient tree, rune stones, mushroom ring, magical plants that regrow
- [x] Dungeons E→S: entrances with rank signs, 1–3 floors, rooms + corridors, monsters and elites, spike-trap rooms, treasure rooms, secret room behind a cracked wall, stairs, boss arena with sealing gate, boss chest, exit portal, 3-day repopulation, dungeon map
- [x] Three dungeon themes with their own monsters and bosses: Crypt (Bone King), Arcane Sanctum (Arcane Colossus), Thornwild Grotto (Elder Thornmaw)
- [x] Monster framework: data-driven melee, ranged and caster AI; bosses with cleave/slam/volley/charge/summon, enrage, boss bar; rank scaling of health/damage/level/XP
- [x] Player afflictions from monsters: burning, poison, chill
- [x] Rare resources: mithril (ore, ingots, tier-4 tools), void shards, sunstones, thorn hearts, royal bone, wisp essence, thorn venom, ancient bone
- [x] Magical plants: sunbloom, frost lotus, emberroot, dreamcap, starlight orchid (groves only)
- [x] Alchemy table + 7 potions/elixirs (healing, mana, warming, cooling, might, stoneskin, starlight)
- [x] 7 legendary items with legendary recipe scrolls (temples, A/S bosses, far vaults/towers)
- [x] Gossip points you to dungeons, ruins, towers, temples and hints at hidden groves; map markers; save/load of all progress
- [ ] NOT IMPLEMENTED: dungeon fog of war (the floor map shows every room except the secret one), keys/locked doors, puzzles beyond cracked walls
- [ ] NOT IMPLEMENTED: multi-storey tower interiors (only the ground floor is walkable), climbing
- [~] World bosses: the Starborn Colossus guards meteor craters (M7); roaming world bosses, dungeon modifiers and party/co-op NOT IMPLEMENTED
- [ ] NOT IMPLEMENTED: unique legendary effects (legendaries are strong stat items, no special procs)
- [ ] Known limitation: dungeons are built in the sky (y = 800) with the surface paused; a short load when entering
- [~] Monsters steer around walls with feeler rays and hop/detour when stuck (M7); still no full pathfinding

## Phase 2 — Core RPG (remaining)

- [x] Crafting system (Milestone 4)
- [x] Recipe sources — books (cave caches, boars), discovery, shops (M5), dungeons, bosses, temples, towers, vaults (M6)
- [x] More abilities per class and ability upgrades (Milestone 17b–d: 53 abilities per class, upgrades from level 30)
- [x] Item quality (Fine/Masterwork, Milestone 15); gear drops from monsters, chests and bosses (M6)
- [x] Basic NPCs (dialogue, shops) (Milestone 5)
- [x] Respec (Draught of Forgetting, Milestone 15)

## Phase 3 — World (remaining)

- [~] Chunk system & procedural terrain — heightmap columns on two layers; no overhangs / multi-level caves
- [x] Villages (houses, farms, market, blacksmith, shops, NPCs, traders) (Milestone 5)
- [x] Structures: ruins, towers, temples, hidden groves (Milestone 6)
- [ ] Mines (abandoned mine structures in caves); caves currently have ore-rich areas but no built mines
- [x] Biome-specific enemies (Milestones 6-7: undead, magical, beasts, bandits, elites per biome)
- [ ] Underground water, lava and deeper cave levels

## Phase 4 — Content

- [x] Kingdoms (castle, advanced blacksmith, rare shops, guards, reputation) — Milestone 5; royal errands (Milestone 16)
- [x] Dungeons ranks E–S with scaling enemies, traps, secrets, loot, bosses (Milestone 6)
- [x] Bosses with unique mechanics (Milestone 6: 4 bosses; Milestone 7: phases, wards, beams, 2 new bosses)
- [x] More enemy categories — undead, magical, beasts (M6); bandits, elites with affixes, treasure goblin (M7)
- [~] Farming (seeds, planting, harvesting) — Milestone 5; magical plants in groves (M6); watering, seasons, planting magical plants NOT IMPLEMENTED
- [x] Trading & economy (per-settlement inventories and prices) (Milestone 5)
- [x] Raids with warnings, reputation/popularity rewards (Milestone 7)
- [~] NPC routines and reputation (Milestone 5); relationships and reactions not yet

## Phase 5 — Building

- [x] Land claims (Claim Totem / Claim Flag) (Milestone 4)
- [x] Grid building: floors, walls, doors, windows, fences, spike walls, roofs, furniture, storage, workstations, defenses (Milestone 4)
- [x] Shelter affecting temperature (Milestone 4)
- [x] Blueprint system (requirements, missing resources, auto-build) + companion web designer (Milestone 8)

## Phase 6 — Polish

- [x] Save/load system (Milestone 2)
- [~] Save backups and recovery (Milestone 13); cloud saves via Steam Auto-Cloud documented, not tested; save thumbnails NOT IMPLEMENTED
- [~] Animations (procedural: knees/elbows, idle, run lean, jump, swim, cast, landing — Milestone 10; keyframe clips with layers and cross-fades — Milestone 18a); skeletal/authored animations NOT IMPLEMENTED (by design)
- [x] VFX, sound & music (Milestone 10, all generated)
- [x] UI polish: pixel-art item icons, panel transitions, settings screen (Milestone 10); key rebinding (Milestone 13)
- [x] Main menu with seed entry / world selection (Milestone 2)
- [x] Settings menu: audio, display, graphics, comfort (Milestone 10); gameplay, controls and accessibility (Milestone 13)
- [~] Optimization pass: CPU profiling and budgets (Milestone 12); GPU profiling on real hardware, occlusion and instancing everywhere NOT IMPLEMENTED

## Phase 7 — Large world

- [x] Deterministic world of 3,003,289 chunks with bounds and an edge ocean (Milestone 9)
- [x] Region files for modified chunks, compressed saves (Milestone 9)
- [x] Horizon LOD, streaming tuning for fast travel (Milestone 9)
- [ ] Floating origin (only needed beyond the ±14 km world; not needed at the current size)
- [ ] Efficient off-screen NPC/settlement simulation

## Known issues / tech debt

- Dropped loot pickups are not saved (they despawn after 5 minutes anyway). Enemies are not saved (killed spawn slots are).
- Swimming never drowns you; with no stamina you just swim slowly.
- Class colours in ClassData (shirt/pants/hair) are no longer used for players since Milestone 14 (only the accent colour is).
- Class abilities share the generic swing/cast poses (each has its own sound and VFX since Milestone 10).
- Monster stats scale by dungeon rank and, in the wild, by distance from spawn (Milestone 12) - not by the player's level (by design).
- The world map reveals everything (no fog-of-war yet).
- Placed objects on the other layer stay in memory (harmless, but not culled).
- Debug-spawned enemies (F8) are not tied to a chunk and never despawn unless killed.
- Enemy perception is distance-only (no line-of-sight); stealth exists for the Assassin (Vanish).
- Terrain is a heightmap of block columns per layer: no overhangs or multi-level caves.
- The Compatibility (OpenGL) renderer shows brighter colours than Forward+.
- Art is code-built (voxel boxes, generated pixel icons, synthesized audio): consistent and complete, but not hand-authored.
