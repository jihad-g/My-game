# Project TODO

Legend: `[x]` completed (implemented + tested) · `[~]` in progress / partial (details given) · `[ ]` not started

Nothing below is marked `[x]` unless it runs in the game today.

## v0.49.0 — First-person view (option) and full key control

- [x] First-person view: End key or Settings > Gameplay, saved; top-down stays the default
- [x] Camera at the hero's eyes; mouse look (±85°), gamepad/keys look, own field of view, mouse speed, invert up/down
- [x] Mouse captured while playing, freed when a window or menu is open; crosshair in the centre
- [x] Hero's head/body hidden from the camera (still casts shadows; others see you); arms + weapon show
- [x] Attacks, spells, bow and building aim at the crosshair; lock-on turns the view
- [x] No tree/wall fade and roofs stay on in first person; smaller camera shake
- [x] Controls: every key can be changed (testing keys too), "what it does" line per action, search,
      key finder (press a key to see what it does), "All keys" list sorted by key
- [x] Tests `test_v49_keys`, `test_v49_first_person` (written, NOT run yet - waiting for permission)
- [ ] NOT IMPLEMENTED: hands-only animations made for first person (normal arm animations are used)
- [ ] NOT IMPLEMENTED: head bob setting
- [ ] NOT IMPLEMENTED: first person on a horse or boat checked
- [ ] NOT IMPLEMENTED: screenshots of first person (`screenshot_runner`)

## Milestone 40 — Village Architecture (v0.48.0)

- [x] Settlement buildings are voxel shells in the reference style (`VillageArchitecture`); every building in a settlement looks different
- [x] Bigger houses (7x6), elder's manor and inn (8x6, three floors)
- [x] Job buildings + workers: bakery/baker, lumber camp/lumberjack, alchemy/alchemist, fishery/fisher, mine/miner, windmill/miller, watchtower/guard
- [x] Job shops (baker, innkeeper, alchemist, miner, lumberjack, miller) with items other shops already sell
- [~] Checked with screenshots (`--only=village40`); the test `test_m40_villages` is written but NOT RUN yet (waiting for the owner's OK)
- [ ] NOT IMPLEMENTED: Windows build for v0.48.0 (the zip in `releases/` is still v0.47.0)
- [ ] NOT IMPLEMENTED: job buildings in kingdom capitals, and a distinct style per kingdom (all capitals use the same stone style)
- [ ] NOT IMPLEMENTED: fish items for the fisher (the fisher has no shop), flour for the miller
- [ ] NOT IMPLEMENTED: walking up to the upper floors (they are only outside walls; rooms are one storey inside)
- [ ] NOT IMPLEMENTED: windmill sails that turn, smoke from chimneys
- [ ] NOT IMPLEMENTED: the elder gives quests (talks only)
- [ ] NOT IMPLEMENTED: far-away town impostors (`FarImpostors`) still show the old simple houses

## Milestone 39 — Voxel Arsenal (v0.47.0)

- [x] All held weapons, shields, wands and tomes are voxel models in the reference style (`VoxelItems`)
- [x] Named weapons have their own models (Prismheart Blade, Sporecrown Staff, Gilded Greatsword, Gilded Halberd, Starlance)
- [x] Metal and accent colours per item; dropped weapons/shields show their model
- [ ] NOT IMPLEMENTED: armour and clothes (helmets, plate, robes, boots) in the same voxel style - they are still painted boxes (PixelAuto)
- [ ] NOT IMPLEMENTED: item icons (2D) redrawn from the voxel models - icons still come from `art/tools/icongen.py`
- [ ] NOT IMPLEMENTED: dropped food, materials and potions as voxel models (still a coloured cube)
- [ ] NOT IMPLEMENTED: own models for every named weapon (e.g. Shadowfang, Sunforged Blade, Titan's Greataxe use the shared sword/axe model with their metal colour)
- [ ] NOT IMPLEMENTED: checked on Forward+ with a real GPU (only the Compatibility renderer was checked)

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
- [x] Fixed in Milestone 37: a bed takes two cells (its own and the one at its foot), so it no longer overlaps a neighbour cell's furniture

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
- [ ] NOT IMPLEMENTED: crop watering, animals/livestock; village crops can't be harvested by the player (seasons: M28)
- [x] Fixed in Milestone 36: approaching a kingdom capital no longer stutters (the site is built in small steps over ~20 frames)
- [x] Fixed in Milestone 37: townsfolk keep out of people's way (they still have no wall collision)

## Milestone 38 — Combat feel from the reference clip  ✅ (v0.46.0)

- [x] Measured the clip frame by frame (30 fps); every number in `CombatFeel` (`src/combat/combat_feel.gd`)
- [x] Swing shape for all humanoids (`AnimLibrary.attack`): anticipation, 2-frame strike (heavy 3), follow-through,
      settle; heavy wind-ups hang at the top - weapon times, combos and hit frames unchanged
- [x] Beasts and crawlers (`BeastModel.play_attack`): the same shape (big attacks rear back early and hang)
- [x] Hit-stop 3 frames on heavy hits and finishers; light pop + square sparks where every melee hit lands
- [x] Camera kick in the measured pattern on heavy hits (`CameraRig.kick`), no shake on light hits
- [x] Flashes: enemy white 2 + fade 2 frames; hero warm 1, white 4, fade 1 with a halo (`HumanoidModel.hurt_flash`)
- [x] Damage numbers: sideways pop, 115% → 100%, hold, fade (1.1 s); dark outline; crits red
- [x] Death: tip over, pale poof at 0.7 s
- [x] Blasts (`BlastFX`): fire blast, magic burst (per element), poison cloud, fire pillar, beam, ground rings,
      screen brightness pops (`DayNightCycle.blast_flash`); old `VFX.burst`/`VFX.ring`/`VFX.bolt`/`FX.impact`
      calls use them, so every ability gets the new look
- [x] Dungeon camera: 50° down, 45° turned, 30° lens, locked follow; Settings toggle; fog follows the zoom
- [x] Tests `test_m38_*`
- [ ] NOT IMPLEMENTED: the clip's red outline on the enemy you are about to hit (elites keep their affix outline)
- [ ] NOT IMPLEMENTED: the dodge roll keeps its own timing (0.42 s, ~3.9 m); the clip's roll is 0.33 s, ~3 m.
      Not changed, because it would change dodging balance and i-frames
- [ ] NOT IMPLEMENTED: the dungeon look (dark teal walls, warm floor light) - only the camera changed; colours and
      lights of the dungeons are as before
- [ ] NOT IMPLEMENTED: new sounds for the blasts (the old sounds play)
- [ ] NOT CHECKED: the new effects were tested playing alone, not in a co-op game (the effects are local, the
      game rules did not change)

## Milestone 37 — Release polish  ✅ (v0.45.0)

- [x] Settings: graphics quality presets (Low / Medium / High; "Custom" once you change one of their settings),
      field of view slider (30-75°), anti-aliasing (off / 2x / 4x); key rebinding and volume were already there (M13)
- [x] Biome music: 7 new tunes (desert, snow, jungle, swamp, mountain, coast, crystal glade) while exploring by day;
      meadows and forests keep the old tune; nights, towns, dungeons, fights and bosses keep theirs
- [x] New sounds: horse hooves (every stride) and neighing, boat oars, dungeon levers, pressure plates, gates and
      caged chests opening, waystones (unlock and travel)
- [x] "First steps" tutorial: offered to a new player (Start / No thanks); walk, gather 3 things, open the bag,
      craft, chop, build - a checklist on the left of the HUD, ticked in any order; the hints that say the same thing
      stay quiet; Skip any time; Settings → Replay the tutorial offers it again
- [x] Title screen: moving pixel-art landscape (dusk sky, stars, sun, floating shard islands, mountains, pines, a
      castle, sparks), our own pixel logo, big buttons (Continue, New world, Load world, Multiplayer, Settings,
      Achievements, Quit), version number; creating, loading and multiplayer are pages with a Back button (Esc)
- [x] Bed overlap fixed: a bed takes two cells, nothing else goes on its foot, no wall through its middle, and upstairs
      it needs floor under both cells; old saves with something at the foot keep a one-cell bed
- [x] Townsfolk don't walk through people: they steer around the player, other players and each other (keeping to
      the right), never end a step inside someone, say "Excuse me" when you block the way, step aside when you keep
      walking into them and go back to their spot after; the player bumps into them instead of passing through
- [x] Creative → World: Music, Sounds, Graphics, Townsfolk, Tutorial and Bed rows; tests `test_m37_*`
- [ ] NOT IMPLEMENTED: the music and sounds are made by our generator (tools/gen_audio.py), not recorded by musicians
- [ ] NOT IMPLEMENTED: townsfolk have no wall collision - stepping around someone near a building they can clip a corner
- [ ] NOT IMPLEMENTED: monsters and animals don't step around townsfolk (they push through)
- [ ] NOT IMPLEMENTED: the first-steps tutorial covers the basics only; combat, levels, towns and dungeons still use the hints
- [ ] NOT IMPLEMENTED: graphics presets don't change the view distance (chunk radius) or texture quality

## Milestone 36 — Performance  ✅ (v0.44.0)

- [x] Prefetch bug fixed: while travelling one worker loads the area ahead (unless a full-detail chunk is waiting)
- [x] Heavy builds split over frames: towns and capitals (layout + meshes on a worker, then small steps: one
      mesh tile, 200 collision boxes, the doors, one townsperson per step), ruins/towers/temples the same way;
      terrain chunks make their tree/rock bodies a few at a time (1 ms per frame, nearest chunk first)
- [x] Capital stutter removed: one ~120 ms frame before, now ~20 frames of a few ms; towns are 32 m mesh tiles
- [x] Monster crowds: grid separation, think every other tick when walking about, step-up retry cooldown,
      4 cm collision margins (1 cm for the player), one-sided surface terrain collision, path search budget
- [x] Spawning: raid waves 2 per frame, wild spawns at most 3 per frame, monster looks warmed while loading
- [x] Quest tracker hint searched on a worker thread (up to 54 ms on the main thread before)
- [x] Chunk ring and far-tile queues sorted by the engine (a chunk border cost up to ~15 ms before)
- [x] Stress tool: slowest frame under 25 ms in every scenario (headless); Creative "Perf (M36)" row; tests `test_m36_*`
- [ ] NOT IMPLEMENTED: frame times with rendering on real GPUs (the stress tool measures CPU work, headless)
- [ ] NOT IMPLEMENTED: incremental (multi-frame) path searches - a single long search can still take a few ms
- [ ] NOT IMPLEMENTED: Jolt physics (tried: crowds are faster, but streaming had new spikes - left for later)

## Milestone 35 — Icons and item uses  ✅ (v0.43.0)

- [x] Every item (297) has a pixel icon in the atlas: new drawings for feathers, scales, teeth, ectoplasm, pearls,
      sugar, honeycomb, cake, cloth, spools, keys, saddles, boats, top hats and masks; all M23 and M27 gear and the
      M33 materials now have their own icons
- [x] Ember Feather recipe: 1 Ember Feather + 12 Wooden Arrows -> 12 Fire Arrows (workbench)
- [x] Honey food at the campfire: Honey Bread, Honey Roast, Honey Cake (uses Sugar from cupcake critters)
- [x] Silk at the tailoring table: Silk Cloth, Silk Bandage, Silkweave Robe (+ Ectoplasm), Silkweave Hood (+ Pearl)
- [x] Uses for the M33 drops: Dragonbone Greatsword, Serpentscale Boots, Mimic Tooth Amulet, Pearl Ring,
      Fletched Arrows (Turkey Feathers), Mana Tonic from Ectoplasm
- [x] Creative "New (M35)" row (ingredients, items, learn recipes); tests `test_m35_*` run and pass
- [ ] NOT IMPLEMENTED: the icons are drawn by our icon generator (art/tools/icongen.py), not painted one by one in an editor
- [ ] NOT IMPLEMENTED: new gear has no look of its own on the character (it uses the robe, hood, boots and pendant looks)
- [ ] NOT IMPLEMENTED: honey and silk items in shops and loot tables (crafting only)

## Milestone 34 — Textures  ✅ (v0.42.0)

- [x] Sand, snow (+ snow edge), ice and cave stone restyled like the M26 grass
- [x] Stair tread textures (wood, stone); dirt and cobblestone path tiles (new build pieces)
- [x] Animated pixel water ripples (crests and spreading rings)
- [x] Creative controls; tests `test_m34_*` run and pass
- [ ] NOT IMPLEMENTED: desert sand, mud and gravel keep their M26 textures
- [ ] NOT IMPLEMENTED: villages don't lay path tiles on their streets yet
- [ ] NOT IMPLEMENTED: ripples around the player, boats and swimming creatures (they are world patterns, not splashes)

## Milestone 33 — More mobs  ✅ (v0.41.0)

- [x] Bone Dragon (crypt boss), Shadow Serpent, Door Mimic, Ghost Cat, Diver Zombie, Turkey, Top-Hat Bear, Cupcake Critter, Berry Jelly
- [x] Drops (7 new materials), spawn rules (biomes, dungeon rooms, crypt floors), Self Check look + spawn coverage
- [x] All of them use the M32 animation system (wind-up, hit frame, hurt, death; mimic sleeps as a door)
- [x] Creative "New (M33)" row; tests `test_m33_*` run and pass
- [ ] NOT IMPLEMENTED: night-only spawns (ghost cats and diver zombies also appear by day)
- [x] Done in Milestone 35: uses for the new materials (gear, arrows, food, tonic)
- [ ] NOT IMPLEMENTED: diver zombies coming out of the sea; serpents swimming
- [ ] NOT IMPLEMENTED: a lore page and quest for the Bone Dragon

## Milestone 32 — Monster animations  ✅ (v0.40.0)

- [x] Walk, attack, hurt and death for every monster type (humanoids already had them; beasts got new ones)
- [x] Visible wind-up before big attacks: crouch, shake, red glow (plus the ground warning)
- [x] Damage lands on the hit frame (melee, charges, slams, roars)
- [x] Ears that twitch/prick/flatten, tails that sway, faster wing beats before a dive
- [x] Creative "Animate" row and slow motion; tests `test_m32_*` run and pass
- [ ] NOT IMPLEMENTED: capes and long hair that swing on humanoids (planned with M32 in the old list)
- [ ] NOT IMPLEMENTED: hand-keyed animation clips for beasts (they are procedural poses, not an editor timeline)
- [ ] NOT IMPLEMENTED: different death falls depending on the killing blow (fire, ice, a big hit)
- [ ] Known limitation: ranged attacks (arrows, bolts) fire at the end of their wind-up, but the projectile takes time to arrive, so its "hit" is when it lands

## Milestone 31 — Dungeons: fog of war, keys, puzzles  ✅ (v0.39.0)

- [x] Fog of war over unexplored rooms and corridors; braziers light when a room is found
- [x] Dungeon mini-map that fills in, with exit, stairs/boss, gates, puzzles, Keeper and player markers
- [x] Locked gates on the last room (rank D+), the Keeper mini-boss drops the Dungeon Key
- [x] Lever puzzles (order I-II-III) and pressure-plate puzzles (6 s) guarding caged chests
- [x] Hidden rooms behind cracked walls (M6) stay hidden on the map until found
- [x] Creative controls; tests `test_m31_*` run and pass
- [ ] NOT IMPLEMENTED: explored rooms are not saved - leaving a floor and coming back starts it dark again (dungeons are rebuilt each visit)
- [ ] NOT IMPLEMENTED: in co-op, guests see the host's fog (each player does not have their own)
- [ ] NOT IMPLEMENTED: more puzzle kinds (moving blocks, light beams, riddles), traps that levers switch off
- [ ] Known limitation: monsters can stand on the plate too, but only the player presses it

## Milestone 30 — Multi-storey building  ✅ (v0.38.0)

- [x] Storeys 1-3: upper floors on walls, balconies (2 cells), upper walls/doors/windows/fences, furniture, roofs
- [x] Stairs (wood, stone; 3 cells), ladders, stone foundations that level slopes
- [x] Storey keys in build mode (= / -), support rules, can't remove what holds things up
- [x] NavGrid decks, stair steps and ladder links: monsters climb to upper floors
- [x] Creative demo house; tests `test_m30_*` run and pass
- [ ] NOT IMPLEMENTED: blueprints with upper storeys (blueprints still save and build the ground floor only)
- [ ] NOT IMPLEMENTED: pieces collapsing when their support is destroyed by raiders (they stay up)
- [ ] NOT IMPLEMENTED: a staircase that crosses a 16 m grid tile line only counts the steps in its own tile for pathfinding
- [ ] NOT IMPLEMENTED: trapdoors in floors, spiral stairs, stair railings that block
- [ ] Known limitation: melee monsters below an upper floor can still reach a hero standing right above them

## Milestone 29 — Travel: waystones, horses, boats  ✅ (v0.37.0)

- [x] Waystones in villages, capitals and at dungeon entrances; unlock by touch, travel for coins (saved)
- [x] Wild horse herds, taming with food, names, saddle slot (2 saddles), riding with a gallop bar, whistle
- [x] Craftable rowboat; rowing on deep water; saved horses and boats
- [x] Creative controls; tests `test_m29_*` run and pass
- [ ] NOT IMPLEMENTED: fighting from the saddle (mounted attacks), horse armour, horse health (horses can't be hurt)
- [ ] NOT IMPLEMENTED: waystones in co-op; guests riding horses or boats (only the host)
- [ ] NOT IMPLEMENTED: waystones on the world map (the list is at the waystone); building your own waystone
- [ ] NOT IMPLEMENTED: sailing ships, carrying cargo in boats, fishing from a boat
- [ ] Known limitation: a horse's body is longer than the rider's collision capsule, so its head can poke into walls

## Milestone 28 — Weather that matters, and seasons  ✅ (v0.36.0)

- [x] Four seasons (4 days each) with blended changes: spring blossoms, autumn leaves, winter snow on grass and trees
- [x] Season temperatures (never lethal) and season weather odds (snow in cool lands in winter)
- [x] Crops grow only in their seasons; greenhouses (a roof) grow all year at 60%; rain +60%
- [x] Rain puts out campfires in the open; lightning sets trees on fire (spreads, burns down, rain can save it)
- [x] Fog, sandstorms, storms, snow and rain shorten monster sight
- [x] Creative mode controls; tests `test_m28_*` run and pass
- [ ] NOT IMPLEMENTED: snow that piles up as blocks, frozen lakes you can walk on, puddles, wet-look ground
- [ ] NOT IMPLEMENTED: seasonal animals and events (migrating birds, a harvest festival, winter wolves)
- [ ] NOT IMPLEMENTED: village crops follow the seasons (they only look the same all year)
- [ ] Known limitation: the season look is a colour change in the shaders; flower props don't disappear in winter
      (they get a dusting of snow), and leafy trees keep their leaves (gold in autumn, snowy in winter)

## Milestone 27 — New mobs and gear  ✅ (v0.35.0)

- [x] 10 mobs with new bodies (bee, hedgehog, acorn, frost fox, blossom stag, spider, witch cat, candle skull, pumpkin, phoenix)
- [x] Spawns in 8 biomes and 3 dungeon themes; drops (silk, feather, petal, quill, wax, honeycomb, acorn, pumpkin)
- [x] Explorer's Gear, Gilded Paladin (set + shield + greatsword + halberd), Pilgrim's Vestments
- [x] Prismheart Blade, Sporecrown Staff, Starlance with their own weapon shapes
- [x] Recipes (tailoring, arcane altar) and dungeon loot
- [x] Tests `test_m27_*` run and pass
- [x] Done in Milestone 33: the other mobs on the sheets (bone dragon, shadow serpent, door mimic, ghost cat, diver zombie, cute food
      critters, top-hat bear, turkey)
- [x] Done in Milestone 35: pixel icons for the new items; honey and silk recipes; the Ember Feather recipe

## Milestone 26 — Rich World  ✅ (v0.34.0)

- [x] New grass, soil, grass-lip and stone textures in the style of the owner's references
- [x] Softer greens, darker soil, softer checker, gentler colour grade
- [x] 9 new ground-cover props, denser grass and flowers, cover in 7 biomes
- [x] Tests: terrain, biomes, props, data, m10, m18d, m21, m24, m25 re-run and pass
- [ ] NOT IMPLEMENTED: water with patterned ripples like the diorama reference, grass that overhangs as 3D lips
- [ ] NOT IMPLEMENTED: stairs and path tiles in the terrain (tile-set reference); desert, snow and cave textures were not restyled yet

## Milestone 25 — Monster pathfinding  ✅ (v0.33.0)

- [x] A* on the 1 m grid: terrain heights (climb 1 m, drop 4 m), walls and edges, houses, trees, rocks, deep water, doors
- [x] Dungeon floors use the dungeon plan
- [x] Path smoothing with body-width checks, re-planning, stuck recovery, per-frame search budget
- [x] Unreachable targets: go to the closest spot; raiders plan through player walls and smash them
- [x] Creative mode: show paths, switch pathfinding, stats
- [x] Tests `test_m25_*` run and pass
- [ ] NOT IMPLEMENTED: big monsters (colossi) use the same 1-cell clearance as people; flying monsters fly straight
- [ ] NOT IMPLEMENTED: the Thornback Boar (old animal script) and villagers still walk straight
- [ ] NOT IMPLEMENTED: paths longer than ~56 m are cut at the closest point (monsters re-plan as they walk)

## Milestone 24 — Creative Mode for testing and debugging  ✅ (v0.32.0)

- [x] Creative world option on the main menu (saved with the world)
- [x] Creative panel in 6 tabs: Player, Items, Monsters, World, Dungeons, Debug
- [x] Every item (search, category, amount, quality), kits, give/wear any gear set
- [x] Spawn any monster (normal, elite, dummy, 1-20), freeze enemies, kill with loot, raids of each faction, world events
- [x] Time, weather, air temperature, teleport (town, dungeon, POI kinds, biome, 500 m, centre)
- [x] Test dungeons of any theme and rank, kill floor, jump to last room, next floor, leave, reset cooldowns
- [x] Free building and crafting in Creative mode
- [x] Debug: stats overlay, "Check the game" data scan with a saved report, log errors, performance snapshot
- [x] Fixed: `copper_coin` drop pointed at a missing item (now pays coins); typing in a search box walked the hero
- [x] Tests `test_m24_*` run and pass (42 checks); older groups re-run and pass
- [ ] NOT IMPLEMENTED: Creative mode in co-op (single player only, on purpose for now)
- [ ] NOT IMPLEMENTED: fly / no-clip, place any building piece without unlocking it, collision shape view
- [x] Fixed in Milestone 36: `test_m9_streaming` "prefetch generated chunks ahead" (the prefetch only ran when nothing else was queued, which never happens while travelling)
- [ ] NOT IMPLEMENTED: Creative changes are not undone when you turn it off (levels, items and recipes stay) - use a Creative world

## Milestone 23 — Elemental Armour  ✅ (v0.31.0)

- [x] 8 elemental sets × 4 pieces with their own pixel looks (glowing crystals, lamps, flames, spirit light)
- [x] Elemental resistance and damage stats, set bonuses, 75% resistance cap
- [x] Drops from B+ dungeon bosses and Delver's Caches; Elemental Armoury codex teaches all 32 recipes (Delver's Marks)
- [x] Fixed: crash when towns were built on worker threads while the pixel painter ran
- [x] Tests `test_m23_*` run and pass; `m5`, `m6`, `m7`, `m10`, `m14`, `m15`, `m19`, `m20`, `m21`, `m22`, `m12_balance`, `m17b`, `m18b` re-run and pass
- [ ] NOT IMPLEMENTED: elemental weapons to match the sets; monsters with elemental weakness shown in the UI
- [x] Done in Milestone 35: pixel icons for the 32 pieces
- [ ] Known limitation: element damage counts for hits whose type is that element (spells, fire arrows...); plain weapon hits stay physical

## Milestones 21 + 22 — Pixel World and Deeper Dungeons  ✅ (v0.30.0)

- [x] Every model box pixel painted (`PixelAuto`): characters, monsters, animals, outfits, villagers, weapons
- [x] Skeleton Archer and Bone King on the hand-drawn pixel skeleton
- [x] Dungeon structure audit (2,160 floors) and a live audit in every theme and rank: no faults found
- [x] Fixed: loot left on a floor is gathered on the stairs and the portal (it was lost)
- [x] Fixed: the "dead stir again" hours follow the real day length
- [x] Delver's Cache per cleared floor, first-clear bonus (XP ×2, coins, Delver's Marks), chests in trap rooms
- [x] Better dungeon loot: more coins and gear, Fine/Masterwork gear, legendary gear from S-rank bosses
- [x] Tests `test_m21_*`, `test_m22_*` run and pass; `m4_data`, `m5`, `m6`, `m7`, `m10`, `m12`, `m14`, `m15`, `m16`,
  `m17c`, `m18a`, `m18b`, `m18c`, `m19`, `m20` re-run and pass
- [ ] NOT IMPLEMENTED: hand-drawn faces and details for every monster (they use the automatic painting; skeletons and Tuskers are hand-drawn)
- [ ] NOT IMPLEMENTED: pixel painting for props, pickups, chests, projectiles and buildings' small parts (they keep their old look or block textures)
- [ ] NOT IMPLEMENTED: a shop that trades Delver's Marks for special gear (they sell for coins for now)
- [ ] NOT IMPLEMENTED: dungeon fog of war, keys and puzzles (item 7 of the list); dungeons in co-op
- [ ] Known limitation: monsters still walk straight at you and can get caught on corridor corners (item 3, pathfinding)

## Milestone 20 — The Tuskers: pixel-art monsters  ✅ (v0.29.0)

- [x] Pixel-art model system (`PixelArt`): exact pixel faces, one atlas, see-through and glowing pixels, rotated parts
- [x] Skeleton Minion and Skeleton Warrior redrawn pixel by pixel on the normal rig
- [x] Tusker faction: Grunt, Brute, Chief (boss) with pixel models, attacks, loot, lore page
- [x] Tusker war parties in meadows, forests and desert; Tusker base and town raids led by brutes and the chief
- [x] Tests `test_m20_*` run and pass; `m7`, `m14`, `m15`, `m16`, `m17c`, `m18a_model`, `m18b` re-run and pass
- [ ] NOT IMPLEMENTED: Tusker war camps (a place in the world with tents, a chief and a chest)
- [ ] NOT IMPLEMENTED: pixel art for weapons and shields held by skeletons (still the old flat boxes)
- [ ] NOT IMPLEMENTED: pixel art for the other monsters, the player classes, outfits and villagers (next art steps)
- [x] Done in Milestone 35: icons for Tusker Tusk and War Banner Scrap
- [ ] Known limitation: Skeleton Archers and the Bone King keep the old look (only the "skeleton" look is redrawn)

## Milestone 19 — Together in Danger: real co-op combat  ✅ (v0.28.0)

- [x] Monsters, bosses, raids and rare events run in co-op; the host simulates them, guests see puppets (NetCombat)
- [x] Puppets follow position, facing, health, death; attacks, telegraphs, flinches, knock-downs, ice shells replay
- [x] Monster bolts and ground warnings drawn for guests; monsters hit guests (block/parry/dodge on the guest)
- [x] Guests' hits, statuses, knock-downs, taunts, parries and blinds reach the host's monster (range, size and rate checked)
- [x] Monsters target the nearest player; full-detail land streams around each guest on the host
- [x] Shared kills (45 m): XP and quest credit for everyone close; loot for everyone
- [x] Support abilities reach friends within 12 m (Holy Light, Rejuvenate, Tundra Howl, Oath of Protection, Cleansing Light)
- [x] Friends' health in the online list; boss bars for guests
- [x] Tests `test_m19_rules`, `test_m19_coop` run and pass; `test_m11` and `test_m18d` re-run and pass
- [ ] NOT IMPLEMENTED: dungeons in co-op (the host can't enter while guests are online; guests never could)
- [ ] NOT IMPLEMENTED: guests taming beasts; pets and summons of guests (they stay on the guest's screen only)
- [ ] NOT IMPLEMENTED: reviving a fallen friend; PvP
- [ ] NOT IMPLEMENTED: guests in caves while the host is on the surface (the host streams one layer: no monsters there for the guest)
- [ ] NOT IMPLEMENTED: chests, trading, village requests, farming, sleeping and blueprints for guests (unchanged from M11)
- [ ] Known limitation: a guest's damage numbers are their own estimate; the host's armour/resistance math decides the real damage
- [ ] Known limitation: monster bolts and ground warnings are visual on guests; the host decides who they hit (with ~0.1 s of delay)
- [ ] Known limitation: puppets glide to the host's position (10 updates per second), so fast monsters can look slightly behind

## Milestone 18d — Flow of Battle: a smoother world  ✅ (v0.27.0)

- [x] Chunks and their props fade in (dither) instead of popping; detail changes cross-fade (fade map, `chunk_fade.gdshaderinc`)
- [x] Far tree clumps in LOD2 chunks and horizon tiles; landmark models for towns and POIs beyond 185 m
- [x] Cave entrance scenes loaded at the loading screen
- [x] Smoother land for new worlds (shape 4): domain-warped hills, gentler lowlands, wide beaches, river valleys
- [x] Biome borders blend over ~32 m (colour mix + dithered biome per block)
- [x] Old saves keep their land exactly (shape 3, proven by `tools/terrain_fingerprint.tscn`); co-op guests get the host's shape
- [x] Streaming: camera-facing chunks first, ~2 ms build budget, one more ring above 12 m/s
- [x] Tests `test_m18d_*` run and pass (with the M19 work)
- [ ] NOT IMPLEMENTED: measured "2-minute sprint across 3 biomes, slowest frame under 25 ms" (needs the stress tool on real hardware)
- [ ] NOT IMPLEMENTED: splitting a chunk build over several frames (one LOD0 chunk with collision can still take a few ms)
- [ ] Known limitation: rare biomes (Crystal Glade...) keep a hard border; water fades a little when its chunk changes detail
- [ ] Known limitation: far tree clumps and landmarks are simple boxes; tree clumps don't sit exactly where the real trees will be
- [ ] Known limitation: characters standing in a chunk that is fading in fade with it for half a second

## Smoother running (v0.25.1, asked for during M18)  ✅

- [x] Arm follow-through, shoulder twist, weight shift, elbow bend, softer bounce, steady head
- [x] Springy lean when starting and stopping
- [x] Prompt for a texture-design session: `docs/TEXTURE_DESIGN_PROMPT.md`
- [ ] NOT IMPLEMENTED: block textures (designed in a separate session first, then added to the game)
- [ ] NOT IMPLEMENTED: cape / hair that sways with movement

## World colour pass (v0.25.0, asked for during M18)  ✅

- [x] Deeper greens, warmer sand, warm stone; calmer tree leaves and boulders
- [x] Per-block colour variation (two tones, 8x8 patches, warm/cool shift; rock bands)
- [x] Block sides darker than tops (chunky look without ambient occlusion)
- [x] Soft see-through fade for trees near the camera and between the camera and the hero (no grainy dither); walls fade softly too
- [~] Test `test_m18_world_colours` is written but has not been run yet
- [ ] Known limitation: a faded tree still casts its full shadow
- [ ] Known limitation: the camera-to-hero fade works on trees and plants (foliage shader), not on walls and houses (they only fade near the camera)
- [ ] NOT IMPLEMENTED: real textures on blocks (blocks are still flat colours with per-block shading)

## Jump and vibrant look (v0.24.0, asked for during M18)  ✅

- [x] Jump on Space (gamepad A when nothing usable is near), coyote time, jump buffer, push-off animation, co-op replay
- [x] Dodge moved to Left Alt
- [x] Art style setting: Vibrant (default) / Classic - saturation, sky, warm sun, lavender shade, glow, filmic tone mapping, soft ambient occlusion
- [~] Test `test_m18c_jump_and_style` is written but has not been run yet
- [ ] Known limitation: ambient occlusion only shows with the normal (Forward+) renderer, not in the browser build
- [x] Recoloured blocks per biome and per block (done in v0.25.0, see below)

## Milestone 18c — Flow of Battle: spells that look like magic, Creative mode  ✅

- [x] VFX library v2: soft particles (GPU, CPU fallback), pooling, ground marks, branching lightning, sky beams, light flashes
- [x] A look for each element (fire, frost, lightning, arcane, holy, poison, shadow)
- [x] Cast glow and element sound for every magic ability and spell; projectile trails and element impacts; glowing ground areas; ice shell on frozen enemies
- [x] Ultimate moments: slow motion (alone only), screen flash, ground mark, a sound per class
- [x] Creative mode for testing (` key): god mode, free and instant abilities, levels, spells, test kit, spawns, clear enemies, day/night
- [x] Tests `test_m18c_*` run and pass (v0.23.1)
- [ ] NOT IMPLEMENTED: a hand-picked effect for every single one of the 240 abilities and spells - they share the element looks; most look different by element, shape and colour
- [ ] NOT IMPLEMENTED: Creative mode in co-op, and saving Creative mode (it is off after loading)
- [ ] Known limitation: the colour of older effects decides their element (a few may pick a near element)
- [x] M18d done (v0.27.0)

## Milestone 18b — Flow of Battle: hack and slash  ✅

- [x] Combo chains ending in finishers for every melee weapon (9 finisher attacks), hold attack to keep chaining, aim assist
- [x] Hit-stop (setting, 0 = off), directional enemy flinches, knock-downs and getting up (bosses only after their poise breaks)
- [x] Three fodder enemies in packs of 4–10 in 8 biomes; up to 60 active enemies; death puffs
- [x] Heavy enemy attacks show a filling red ground warning; elites are outlined and roar
- [x] AI level of detail: idle enemies far from players think every 4th frame
- [x] Tests `test_m18b_*` and the updated combo-length checks run and pass (v0.23.1)
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
- [x] Tests `test_m18a_*` run and pass (v0.23.1)
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
- [x] Combat in shared sessions (Milestone 19); PvP NOT IMPLEMENTED
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
- [~] Animations (procedural: knees/elbows, idle, run lean, jump, swim, cast, landing — Milestone 10; keyframe clips with layers and cross-fades — Milestone 18a; forward-roll dodge with tuck, hop and landing — v0.42.1); skeletal/authored animations NOT IMPLEMENTED (by design)
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
