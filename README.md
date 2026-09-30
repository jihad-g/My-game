# Shardlands (working title)

A stylized, blocky low-poly **open-world survival RPG** built with **Godot 4.4**.
Top-down/isometric tactical camera, real-time manual combat, deterministic procedural
world streamed in chunks, survival systems (health, hunger, temperature), and a long-term
roadmap toward classes, skills, crafting, dungeons, settlements, building and a massive world.

> Status: **Milestone 5 — Living world** (villages, kingdoms, townsfolk with daily routines, shops,
> blacksmiths, travelling traders, farms, economy, reputation and kingdom titles) on top of the
> Phase 1 prototype, world generation (M2), RPG foundation (M3) and building & crafting (M4). See [`docs/TODO.md`](docs/TODO.md) for the
> honest status of every system and [`docs/CHANGELOG.md`](docs/CHANGELOG.md) for history.

![Village](docs/screenshots/village_overview.png)

| **Village plaza** | **Talking to townsfolk** | **Trading** |
|---|---|---|
| ![Plaza](docs/screenshots/village_plaza.png) | ![Dialogue](docs/screenshots/dialogue.png) | ![Trade](docs/screenshots/trade.png) |
| **Kingdom capital** | **The court** | **Village at night** |
| ![Kingdom](docs/screenshots/kingdom_overview.png) | ![Court](docs/screenshots/kingdom_court.png) | ![Night](docs/screenshots/village_night.png) |
| **Notice board** | **Map with settlements** | **Reputation (J)** |
| ![Board](docs/screenshots/notice_board.png) | ![Map](docs/screenshots/map_settlements.png) | ![Reputation](docs/screenshots/reputation.png) |
| **Sunscorch Desert** | **Stonecrown Mountains** | **Crystal Glade** |
| ![Desert](docs/screenshots/biome_desert.png) | ![Mountains](docs/screenshots/biome_mountains.png) | ![Crystal](docs/screenshots/biome_crystal_glade.png) |
| **Murk Swamp** | **The Deeps (caves)** | **World map (M)** |
| ![Swamp](docs/screenshots/biome_swamp.png) | ![Cave](docs/screenshots/cave_inside.png) | ![Map](docs/screenshots/world_map.png) |
| **Wizard: Frost Nova → Firebolt "Shatter"** | **Barbarian: Whirlwind + Rage** | **Assassin: Vanish** |
| ![Wizard](docs/screenshots/class_wizard.png) | ![Barbarian](docs/screenshots/class_barbarian.png) | ![Assassin](docs/screenshots/class_assassin.png) |
| **Character screen (K)** | **Main menu** | **Boar charge telegraph** |
| ![Character](docs/screenshots/character_screen.png) | ![Menu](docs/screenshots/main_menu.png) | ![Charge](docs/screenshots/04a_boar_charge_telegraph.png) |
| **Build mode (B)** | **Crafting (G)** | **Storage chest** |
| ![Build](docs/screenshots/build_mode.png) | ![Crafting](docs/screenshots/crafting_screen.png) | ![Chest](docs/screenshots/chest.png) |
| **Base at night** | **Base** | **Overview** |
| ![Night](docs/screenshots/base_night.png) | ![Base](docs/screenshots/base_overview.png) | ![Overview](docs/screenshots/03_zoomed_out_rotated.png) |

## Requirements

- **Godot 4.4.x** (standard build, not .NET). Download: <https://godotengine.org/download>
- A GPU with Vulkan support for the default **Forward+** renderer.
  (The Compatibility/OpenGL renderer also runs, but colours look noticeably brighter there.)

## Run the game

**Editor:** open Godot → *Import* → select this folder's `project.godot` → press **F5**.

The game opens on the **main menu**: create a world (name + seed, or leave the seed
empty for a random one), continue a saved world, delete worlds, or quick-play a
temporary world that is never saved. The same seed always generates the same world.

**Command line:**

```bash
godot --path .                          # main menu
godot --path . -- --seed=12345          # quick-play a temporary world with this seed (number or any text)
godot --path . -- --world=my_world      # load a saved world by its folder id
```

**Where saves live:** `user://worlds/<world_id>/` — on Windows
`%APPDATA%\Godot\app_userdata\Shardlands\worlds`, on Linux
`~/.local/share/godot/app_userdata/Shardlands/worlds`, on macOS
`~/Library/Application Support/Godot/app_userdata/Shardlands/worlds`
(the menu has an "Open saves folder" button). Each world has `world.json` (name, seed,
play time) and `save.json` (+ `.bak` backup). The game autosaves every 2 minutes, on F5,
and when you quit through the pause menu or close the window.

## Controls

| Action | Key |
|---|---|
| Move (camera-relative) | W A S D |
| Sprint | Shift (costs stamina, more hunger) |
| Dodge roll (i-frames, rolls through enemies) | Space |
| Light attack (3-hit combo) | Left mouse |
| Heavy attack | Right mouse |
| Block (hold) / **Parry** (block right before a hit) | Ctrl |
| Aim | Mouse (your character faces the cursor) |
| Lock-on / cycle targets | Tab |
| Interact / gather / cook / pick up | F |
| Inventory | I |
| Use hotbar item (eat, place campfire) | 1 – 8 |
| Rotate camera | Q / E, or hold middle mouse and drag |
| Tilt camera | Page Up / Page Down, or middle-mouse drag vertically |
| Zoom | Mouse wheel |
| Pan camera freely / recenter | Arrow keys / V |
| Class abilities | Z / X / C |
| Magic Temperature Shield | T |
| Character screen (skills, stats, equipment) | K |
| Crafting screen | G |
| Build mode on / off | B |
| Build mode: place / deconstruct / rotate | Left mouse / Right mouse / R |
| Open doors & chests, sleep in beds | F |
| Talk to townsfolk, read notice boards, plant & harvest crops | F |
| Reputation screen | J |
| World map | M |
| Quick save | F5 |
| Pause | Esc |
| Respawn after death | R |
| Help overlay / debug overlay | F1 / F3 |
| **Debug:** air temperature −10 / +10 °C | F6 / F7 |
| **Debug:** spawn a Thornback Boar in front of you | F8 |
| **Debug:** skip 2 hours | F9 |
| **Debug:** get a sample of every gear tier / gain a level | F10 / F11 |

## Things to try (manual test script)

1. **Camera** – rotate (Q/E), tilt (PgUp/PgDn), zoom (wheel), pan (arrows), recenter (V).
   Trees between the camera and you dither out so they never hide the action.
2. **Terrain streaming** – press F3, sprint in one direction and watch chunk counts: LOD0
   (collision + props) near you, LOD1/LOD2 further away; chunks behind you unload.
3. **Gathering** – walk to berry bushes / fallen sticks / loose stones and press F.
4. **Harvesting** – hit trees and boulders (LMB) to get wood / stone / flint. Walk away
   ~200 m and come back: felled trees stay felled (only world *changes* are stored).
5. **Combat** – find a Thornback Boar (or press F8). It telegraphs a charge with a red glow
   and ground scraping: dodge sideways (Space) or parry it (tap Ctrl right before impact).
   After a charge it pants and is **Exposed** (+50 % damage). Hitting it from behind is a
   **Backstab** (+50 %). Make it charge into a tree and it gets **Dazed**. Loot flies to you.
6. **Survival** – eat (1-8 or right-click in inventory). Hunger drains faster while
   sprinting and in the cold; at 0 you starve slowly.
7. **Temperature** – nights and hills are colder. Press F6 a few times to simulate a
   freezing place: debuffs appear under the temperature bar (slower, weaker, hungrier),
   but **temperature never damages you**. Place a campfire (hotbar key) to warm up, then
   press F on it to cook raw meat. Cooked meat also gives a temporary warmth buff.
8. **Death** – die to boars or starvation, then press R to respawn.
9. **Biomes** – press M for the map, then travel: deserts are hot by day (cactus fruit
   and coconuts cool you), tundra and mountain tops are freezing (campfires!), frozen
   lakes are walkable, swamps are half water. The Crystal Glade (purple on the map) is
   rare and holds crystals and Moonpetals. First visits show "Discovered: …".
10. **Rivers & swimming** – walk into deep water to swim (costs stamina); walk against a
    bank to climb out.
11. **Caves** – black dots on the map are cave entrances (rocky mounds with a dark hole).
    Press F to descend into The Deeps: tunnels and caverns with ores (copper, coal, iron),
    crystals, glowcaps and stalagmites; always 12 °C. Climb the rope ladder to return.
12. **Resources** – mine copper/iron/coal veins in mountains and caves, dig clay at
    riverbanks, pick moonpetals and glowcaps. Mined veins regrow after a while.
13. **Classes** – create four worlds with different classes (main menu → class buttons).
    Barbarian: Whirlwind (Z) groups of boars, build Rage, Berserk (C, level 15).
    Knight: Shield Bash (Z) stuns and taunts, Guardian Stance halves damage.
    Wizard: Firebolt (Z) burns; Frost Nova (X) then Firebolt = **Shatter** (double damage).
    Assassin: Shadow Step (Z) behind a boar → guaranteed crit backstab; Vanish (C) → Ambush.
14. **Progression** – kill boars, discover biomes and caves, harvest: watch the XP bar.
    Press K to spend skill points and see every stat change live. F11 levels you up quickly.
15. **Equipment** – right-click gear in the inventory to equip (F10 for test gear); level
    requirements apply; swapping weapons changes your combo; K shows the slots.
16. **Temperature Shield** – raise Mana Control by 2 (K), press T: 10 minutes of cold/heat
    protection. Wizards pay the least mana.
17. **Save/load** – create a named world, harvest some trees, place a campfire, quit to
    menu (Esc → "Save & quit to menu"), load it again: everything is where you left it.
18. **Gathering for crafting** – cut reeds and dead bushes (F) for **plant fiber**; bushes
    and cacti sometimes give fiber too. Press **G**: the crafting screen lists every recipe,
    where it is crafted and how to unlock it. Craft Rope, then a **Stone Pickaxe** and
    **Stone Hatchet**. Tools work from your inventory automatically: trees and rocks break
    faster, and copper/coal veins now *need* a tier 1 pickaxe (iron tier 2, crystal tier 3).
19. **Crafting never fails** – at low Crafting skill recipes cost more (the screen shows
    "have / need (base N)"); raise Crafting (K) and the same recipe gets cheaper.
20. **Build a hut** – press **B**, pick Wood Floor / Wood Wall / Wooden Door / Thatch Roof
    in the palette, move the mouse (green ghost = OK, red = see the reason), left-click
    to place, R to rotate, right-click to deconstruct. Walls sit on cell edges, roofs need
    a wall or roof next to them. Stand under the roof: roofs above you hide so you can see
    inside, the HUD says "Sheltered", and the air feels up to 10 °C closer to comfortable.
21. **Stations** – build a Workbench (planks, shields, staves), Forge (ingots, metal
    tools/weapons/armor, needs level 3), Tailoring Table (leather, cloth and hide armor)
    and Arcane Altar (dust, crystal gear). Stand within 4 m and press G. Campfires are the
    cooking station. Mining copper ore teaches the copper recipes (discovery); boar hide
    teaches leather.
22. **Recipe books** – search **Forgotten Caches** in The Deeps (caves) for the Smithing
    Manual, Leatherworker's Notes, Arcane Codex and Cook's Journal (boars sometimes carry
    the journal). Use a book from the inventory to learn its recipes.
23. **Home** – place a **Bed** (sets your respawn point; at night with no monsters within
    20 m you sleep until 07:00), a **Storage Chest** (F to open, click stacks to move them),
    **Standing Torches** (light and a little warmth), furniture and fences.
24. **Defense & land** – place a **Claim Flag** (8 m) or **Claim Totem** (16 m): the HUD
    shows "Your land", monsters never spawn there, and deconstructing refunds 100 %
    (50 % elsewhere). **Spike Barricades** and **Spike Traps** hurt monsters that touch
    them; a charging boar takes triple damage and is staggered.
25. **Find a village** – the default seed has a kingdom capital ~300 m from spawn and
    villages around it. Walk in: "Discovered: Village of …", XP and a little standing.
    Towns are flat, cleared of wild trees and monster-free; you can't build inside them.
26. **Townsfolk** – everyone has a job and a daily routine: merchants at their stall 8–19,
    blacksmiths at the forge, farmers in the fields, villagers wander and gather at the well
    at lunch and in the evening, and everyone goes home to sleep (press F9 to skip hours and
    watch). Press F to talk: "What's new?" gives real gossip (unfound villages get added to
    your map, nearby caves, the capital, trader days).
27. **Trade** – talk to a merchant, blacksmith, farmer or royal merchant during work hours →
    Trade. Prices depend on the region (wood is dear in the desert, food in the tundra),
    your reputation, and saturation (selling many of the same thing pays less; recovers
    daily). Shops have limited stock and coins, restocked every morning. Better stock unlocks
    with reputation. Every third day a travelling trader parks a wagon in the square.
28. **Work** – the notice board by the well posts daily delivery requests (and boar bounties
    near farm villages). Hand them in for coins, reputation and XP.
29. **Reputation** (J) – Stranger → Acquainted → Friendly → Honored → Revered, earned by trading,
    requests and killing monsters near towns. Villages share half with their kingdom.
    Better prices at each tier. At Friendly/Honored/Revered kingdom standing, ask the ruler
    in the capital's keep for recognition: titles plus coins and a Royal Signet.
30. **Farming** – buy seeds from farmers or merchants, build **Farm Plots** (B → Farming) outside
    towns, press F to plant and later harvest. Crops grow with world time (also while you sleep).
    Bake bread from wheat at a campfire; pumpkins teach Vegetable Stew.
31. **Kingdom capitals** – walled cities with gates, towers, a keep with a throne, barracks,
    a royal market and guards that attack monsters that come close.

## Run the automated tests

```bash
tools/run_tests.sh            # or: tools/run_tests.sh /path/to/godot
```

or directly: `godot --headless --path . res://tests/test_runner.tscn` (exit code 0 = pass).

The suite (478 checks) covers deterministic generation, chunk meshes/LOD/collision,
inventory rules, hunger, temperature (never damages), world-state persistence, and an
**integration test that boots the real game** and plays it with simulated input:
movement, eating, combat vs. the boar, block/parry/i-frames, loot, tree harvesting,
gathering, campfire warmth & cooking, cold debuffs, streaming after teleport,
death and respawn, swimming, travelling into a cave and back, and a full save → load
round trip (including falling back to the backup when a save file is corrupt).
World-generation tests check determinism, terrain/biome statistics over 10×10 km,
climate continuity, cave layout and data integrity. RPG tests check class data (50
starting points, affordable shields), the XP curve, skill balance (e.g. a max-Strength
Wizard hits softer than a starting Knight), equipment and requirements, every class
ability in the running game, and RPG save/load. Building & crafting tests check that every
recipe and build cost is obtainable in the world, cost scaling, never-fail crafting,
station/skill/level gating, discovery and book learning, tool tiers, grid placement rules
(edges, stacking, distance, roofs, obstacles), walls blocking movement, doors, chests,
refunds, land claims blocking spawns, shelter temperature, torches, beds, spike traps,
build mode, the crafting screen, and a save → load round trip of a base. Living-world tests
check settlement determinism and placement (flat, no wild props/spawns/caves, kingdom
membership), non-overlapping layouts and rosters, prices (no buy/sell loop, saturation,
regional demand, reputation), reputation rules, daily requests, crop growth, and in the running
game: discovery, NPC routines and street paths, dialogue and gossip, buying/selling, requests,
hunts, guards defending a capital, titles, the village forge, farming and save/load.

Balance tables are generated from the code: `godot --headless --path . -s tools/gen_rpg_tables.gd`
→ [`docs/XP_TABLE.md`](docs/XP_TABLE.md), [`docs/CLASSES_AND_SKILLS.md`](docs/CLASSES_AND_SKILLS.md).

Visual check (renders screenshots, needs a display or `xvfb-run`):

```bash
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=build   # base / build / crafting
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=town    # villages, kingdom, trade
tools/make_video.sh /tmp/video     # scripted gameplay video (needs ffmpeg)
```

## Project layout

```
project.godot            Engine config, autoloads, physics layer names
scenes/                  Scenes (.tscn): main menu, main world, player, enemies, pickups, campfire, cave passages
src/
  autoload/              Global singletons: InputSetup, Events (signal bus), GameState, ItemDB
  core/                  Shared utilities: hashing, pooling, block-mesh builder, materials, layers
  components/            Reusable node components: Health, Stamina, Hunger, Temperature, StatBlock
  combat/                AttackData resource, melee hit queries
  camera/                Tactical camera rig
  player/                Player controller, combat, blocky humanoid model
  enemies/               Enemy base class, Thornback Boar AI + model, enemy/loot data
  world/                 Terrain generator, chunks & streaming, biomes, props, caves, spawner, day/night
  world/gen/             WorldGenSettings (all generation parameters + biome list)
  save/                  SaveManager (world list, save/load, backups)
  rpg/                   Classes, skills, progression, character stats, equipment, abilities
  inventory/             ItemData resource, Inventory
  crafting/              Recipes, recipe book, crafting rules
  building/              Build pieces, grid building manager, build mode, piece meshes
  living/                Settlements (generation, layouts, sites), NPCs, economy, reputation, requests, farming, gossip
  ui/                    HUD, theme, slots, temperature gauge
data/                    Data-driven content (.tres): items, attacks, movesets, abilities, classes, enemies, props, biomes, worldgen
tests/                   Automated test suite + screenshot runner
docs/                    TODO, CHANGELOG, architecture notes
tools/                   Helper scripts
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the systems fit together and how
to add new items, props, enemies and biomes without touching engine code.
