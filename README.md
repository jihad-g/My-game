# Shardlands (working title)

A stylized, blocky low-poly **open-world survival RPG** built with **Godot 4.4**.
Top-down/isometric tactical camera, real-time manual combat, deterministic procedural
world streamed in chunks, survival systems (health, hunger, temperature), and a long-term
roadmap toward classes, skills, crafting, dungeons, settlements, building and a massive world.

> Status: **Milestone 16 — The Lost Shards (v0.16.0)**: the Shardlands now have a story. Every world starts the
> main quest - ask about the falling stars, recover Shard Fragments, defeat the three Shard Keepers, join the
> Great Shards on an Arcane Altar and face the Starborn Colossus. Kingdom rulers give royal errands that end in
> a knighthood, conversations have choices, 12 lore pages and kingdom histories wait to be found, and a
> journal (O) keeps your quests, lore and the chronicle of your adventure.
>
> Before that, **Milestone 15 — Living Wilds (v0.15.0)**: every land biome now has wild life - frost wolf packs
> that howl for each other, sand scorpions hiding under the desert, crabs on the beaches, and deer and
> rabbits to hunt for meat and hide. Abandoned camps, shipwrecks and buried caches hide treasure, the area
> around spawn holds many more low-rank ruins and dungeons, crafted gear can come out Fine or Masterwork,
> and a Draught of Forgetting lets you re-spend your skill points.
>
> Before that, **Milestone 14 — Outfits & Gear Makes the Hero (v0.14.0)**: every class shares one body and you
> look like what you wear. Create your character like a souls-like starting class - its starting stats,
> a full outfit set, a weapon and supplies - and choose skin, hair and beard. Armour and clothes add +1/+2
> to skills, full sets (Squire's Kit, Raider's Furs, Shadowstalker's Garb, Apprentice's Vestments) give set
> bonuses, and armour weight matters: light armour keeps you hidden, heavy armour protects you but gets you
> noticed. A Knight in shadow clothes with daggers plays like an Assassin; the class keeps a small talent, so
> a Wizard is never a Knight's equal. Built on the beta (Milestone 13: tutorial, guide, settings and
> accessibility, save recovery, crash reports, achievements, release builds - [`docs/RELEASE.md`](docs/RELEASE.md)).
> Download a Windows build from [`releases/`](releases/) (v0.13.0). Balance: [`docs/BALANCE.md`](docs/BALANCE.md),
> performance: [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md), co-op: [`docs/MULTIPLAYER.md`](docs/MULTIPLAYER.md),
> design: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md). See [`docs/TODO.md`](docs/TODO.md) for the honest status of every system and
> [`docs/CHANGELOG.md`](docs/CHANGELOG.md) for history.

| **A new world begins** | **The journal (O)** |
|---|---|
| ![Intro](docs/screenshots/story_intro.png) | ![Journal](docs/screenshots/journal.png) |

![Wild creatures](docs/screenshots/wild_creatures.png)

| **Starting outfits on one shared body** | **Character creation** |
|---|---|
| ![Outfits](docs/screenshots/gear_outfits.png) | ![Class picker](docs/screenshots/class_picker.png) |

![Village](docs/screenshots/village_overview.png)

![Outfits](docs/screenshots/outfits_lineup.png)
*Milestone 14: one body, many outfits - the four starting outfits, a Knight in light leather, the same Knight in iron, and end-game gear.*

| **Co-op: a guest in your world** | **Chat & who's online** | |
|---|---|---|
| ![Guest](docs/screenshots/coop_guest.png) | ![Chat](docs/screenshots/coop_chat.png) | |

| **Dawn** | **Dusk** | **Fireflies at night** |
|---|---|---|
| ![Dawn](docs/screenshots/sky_dawn.png) | ![Dusk](docs/screenshots/sky_dusk.png) | ![Night](docs/screenshots/night_fireflies.png) |
| **Thunderstorm** | **Fog** | **Sandstorm** |
| ![Storm](docs/screenshots/weather_storm.png) | ![Fog](docs/screenshots/weather_fog.png) | ![Sand](docs/screenshots/weather_sandstorm.png) |
| **Pixel-art item icons** | **Settings** | **Swing trail + sparks** |
| ![Icons](docs/screenshots/inventory_icons.png) | ![Settings](docs/screenshots/settings.png) | ![Trail](docs/screenshots/swing_trail.png) |

| **Horizon terrain (512 m)** | **From a mountain top** | **12.5 km from spawn** |
|---|---|---|
| ![Horizon](docs/screenshots/horizon_spawn.png) | ![Mountain](docs/screenshots/horizon_mountain.png) | ![Far](docs/screenshots/far_reaches.png) |
| **Where the world ends** | **Streaming stats (F3)** | |
| ![Edge](docs/screenshots/world_edge.png) | ![Debug](docs/screenshots/streaming_debug.png) | |

| **Blueprint screen (N)** | **Construction site (holograms)** | **Auto-build in progress** |
|---|---|---|
| ![Blueprints](docs/screenshots/blueprint_screen.png) | ![Site](docs/screenshots/construction_site.png) | ![Auto](docs/screenshots/auto_building.png) |
| **Placement preview** | **Built from blueprints** | **Web blueprint designer** |
| ![Preview](docs/screenshots/blueprint_preview.png) | ![Built](docs/screenshots/blueprints_built.png) | ![Designer](docs/screenshots/web_designer.png) |
| **Raid on your base** | **Bandits besiege the walls** | **Defending a village** |
| ![Raid](docs/screenshots/raid_attack.png) | ![Siege](docs/screenshots/raid_siege.png) | ![Town raid](docs/screenshots/town_raid.png) |
| **Elites & champions** | **Boss ward + pylons** | **Bone spikes** |
| ![Elites](docs/screenshots/elites.png) | ![Ward](docs/screenshots/boss_ward.png) | ![Spikes](docs/screenshots/boss_spikes.png) |
| **Sun beam** | **Blizzard + Meteor** | **Storm Call + Arcane Missiles** |
| ![Beam](docs/screenshots/boss_beam.png) | ![Blizzard](docs/screenshots/spells_blizzard_meteor.png) | ![Storm](docs/screenshots/spells_storm_missiles.png) |
| **Spellbook (L)** | **Blood Moon** | **Meteor + Starborn Colossus** |
| ![Spellbook](docs/screenshots/spellbook.png) | ![Blood moon](docs/screenshots/blood_moon.png) | ![Meteor](docs/screenshots/meteor_colossus.png) |
| **Dungeon entrance (Rank E)** | **Inside a dungeon** | **Boss: The Elder Thornmaw** |
| ![Entrance](docs/screenshots/dungeon_entrance.png) | ![Dungeon](docs/screenshots/dungeon_start.png) | ![Boss](docs/screenshots/dungeon_boss.png) |
| **Temple & its guardian** | **Wizard tower** | **Hidden grove** |
| ![Temple](docs/screenshots/poi_temple.png) | ![Tower](docs/screenshots/poi_tower.png) | ![Grove](docs/screenshots/poi_grove.png) |
| **Ruins** | **Dungeon map** | **Dungeon room** |
| ![Ruins](docs/screenshots/poi_ruins.png) | ![Map](docs/screenshots/dungeon_map.png) | ![Room](docs/screenshots/dungeon_room.png) |
| **Village plaza** | **Talking to townsfolk** | **Trading** |
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

Every gameplay key can be changed in **Settings → Controls** (keyboard/mouse and gamepad separately).
**F1** opens the guide with your current bindings. Gamepad (Xbox layout): left stick move and aim, right
stick camera, X light, Y heavy, B dodge, A interact, LB block, RB/RT/LT abilities, L3 sprint, R3 lock-on,
D-pad spells and hotbar, View bag, Menu pause. Menus still need the mouse.

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
| Build mode: repair piece under cursor / repair everything nearby | U / Shift+U |
| Cast spell slot 1 / 2 | Y / H |
| Spellbook (learned spells, slot assignment, combos) | L |
| Blueprints (designs, materials, construction sites) | N |
| Blueprint preview: rotate / place / cancel | R / Left mouse / Right mouse or Esc |
| Open doors & chests, sleep in beds | F |
| Talk to townsfolk, read notice boards, plant & harvest crops | F |
| Reputation screen | J |
| World map | M |
| Quick save | F5 |
| Pause | Esc |
| Respawn after death | R |
| Guide (all controls, how things work) / debug overlay | F1 / F3 |
| **Debug:** cycle the weather | F2 |
| Chat (multiplayer) | Enter |
| **Debug:** air temperature −10 / +10 °C | F6 / F7 |
| **Debug:** spawn a Thornback Boar in front of you | F8 |
| **Debug:** skip 2 hours | F9 |
| **Debug:** get a sample of every gear tier / gain a level | F10 / F11 |
| **Debug:** start a raid (your base, else the nearest town) / end it | F4 |
| **Debug:** start the next rare world event | F12 |

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
13. **Classes** – create four worlds with different classes (main menu → class buttons). The
    preview shows the class's starting outfit, stats, talent and supplies; change skin, hair
    and beard below it. In game, swap into another class's set (F10 test gear, or craft it at the
    tailoring table / forge) and watch both the look and the stats change.
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
32. **Points of interest** – press M: diamonds mark dungeons (with their rank letter), R ruins,
    W wizard towers, T temples. Townsfolk gossip about nearby ones (they then appear on the map).
    The default seed has a Rank E dungeon ~120 m from spawn and ruins ~200 m away.
33. **Ruins** – skeleton guardians, a chest, and sometimes a **cracked floor**: hit it to open a
    hidden vault with better loot.
34. **Wizard towers** – a Tower Warden (elite caster) and wisps guard it; inside (the roof hides)
    a lectern holds a recipe tome (Alchemist's Grimoire, Arcane Codex, … legendary scrolls far out).
35. **Temples** – a dormant **Temple Guardian** boss wakes when you approach the altar. Defeat it
    to unseal the golden chest (always a **legendary recipe**) and pray at the altar for the
    Blessing of the Ancients (+10% damage, −10% damage taken, 20 min, once per day).
36. **Dungeons E→S** – rank grows with distance from the world's centre (E near spawn, S beyond
    ~3.5 km). Press F at the archway. Floors (1–3) of rooms and corridors: monsters, elites,
    spike-trap rooms (watch the spikes peek before they spring), treasure rooms, stairs down, and a
    secret room behind a **cracked wall** (attack it). The final room is a boss arena: the gate
    slams shut, a boss bar appears and the boss slams, cleaves, charges, fires volleys, summons
    adds and enrages at half health. Its death opens a portal home and a boss chest. Cleared
    dungeons repopulate after 3 in-game days. Saving inside saves you at the entrance; dying
    carries you out. Themes: Crypt (Bone King), Arcane Sanctum (Arcane Colossus), Thornwild
    Grotto (Elder Thornmaw).
37. **Hidden groves** – secret glades (never on the map until found) with an ancient tree,
    glowing rune stones and magical plants including the rare **Starlight Orchid**.
38. **Rare resources & potions** – Mithril veins on high peaks and in the Deeps (iron pickaxe),
    Sunbloom (deserts/meadows), Frost Lotus (tundra), Emberroot (mountains), Dreamcap (caves).
    Build an **Alchemy Table** for Healing Draughts, Mana Tonics, Warming/Cooling Draughts and
    (with the Alchemist's Grimoire) Elixirs of Might, Stoneskin and Starlight. Bosses drop
    Royal Bone, Void Shards, Thorn Hearts and Sunstones for the 7 **legendary** items (each
    taught by a Legendary Recipe scroll; they need Crafting 90).

39. **Status effects** – monsters (and your spells) inflict burning, poison, bleeding, chill/freeze,
    shock, weakness, slow and silence; chips under your bars show them. Standing in water makes
    you **wet**: fire can't burn you, but lightning hurts 50% more and a chill freezes you. Fiber
    bandages (by hand) now also stop bleeding; antidotes, purifying draughts and Troll's Brew at the
    Alchemy Table. Defense 50 (Iron Skin) shortens harmful effects by 30%.
40. **Smarter enemies** – packs alert each other and surround you: only two swing at once while the
    rest circle for an opening. Bandits sidestep your swings and flee when badly hurt; cultists and
    hexers heal their allies, tower wardens shield them. Enemies steer around walls and hop ledges.
41. **Elites** – glowing rings mark elites ("Vampiric Skeleton Warrior"), champions have two affixes:
    vampiric, frenzied, molten (explodes on death), glacial, shielded, thorned, blinking,
    juggernaut (unstoppable), venomous. More health, extra loot.
42. **Bosses** – every boss now has phases (at 66% and 33%): it roars (briefly invulnerable), learns
    new moves and the arena turns hostile (falling rocks, fire rain, poison pools, frost shards).
    Watch for bone/thorn **spikes** chasing you, **novas** (get out of the big circle), **beams**
    that sweep toward you, **meteor rain**, **teleports** behind you, **pulls** and **roars**.
    The Bone King, Temple Guardian and colossi raise **wards**: destroy the glowing pylons to break
    them (they're exposed afterwards). Break a boss's poise for a "Broken!" window.
43. **Advanced magic** – read **spell tomes** (wizard towers, dungeons, elites, treasure goblins, or
    craft some at the Arcane Altar): Blink, Healing Light, Miasma, Arcane Barrier, Arcane Missiles,
    Blizzard, Meteor, Storm Call. Cast with **Y/H**, manage them in the spellbook (**L**). Any class
    can learn them, but each needs a Mana Control level and power grows with spell power. Combos:
    Shatter (fire on frozen), Conducted (lightning on wet), Deep Freeze (chill twice), Combustion
    (fire into a Miasma cloud).
44. **Raids on your base** – once your claim holds 8+ pieces, bandits may attack at night while you're
    near: a warning with a countdown (an **Alarm Bell** adds 45 s; ring it to start at once), then
    2–4 waves from one side. Cutthroats, archers, hexers, **brutes** (smash walls) and **bombers**
    (fire bombs) break what's in their way. Build **Log Palisades**, **Reinforced Doors**, **Arrow
    Towers** and spike traps; repair damage in build mode with **U**. Win for raid spoils and XP;
    abandon the fight and the survivors loot your chests. Strong raids are led by **Grimtusk the
    Warlord**. Press **F4** to test a raid right away.
45. **Defending towns** – a rider sometimes warns that a nearby town will be attacked in a few hours
    (it's marked on the map). Be there: villagers hide indoors, guards fight (they can be knocked
    down, never killed). Saving the town earns reputation, coins and XP. If you don't come, the
    guards may hold — or the town is plundered for two days (prices +25%).
46. **Rare events** (**F12** to try them): **Blood Moon** (red night, the dead walk, +50% XP, more
    elites, your base will be raided), **Meteor Shower** (a meteor crashes nearby: mine star metal,
    sometimes guarded by the **Starborn Colossus** world boss), **Aurora** (cold biomes: double mana
    regen, stronger spells), **Treasure Goblin** (catch it within 45 s for gold, gems and tomes),
    **Eclipse** (darkness at noon, undead roam). Star metal makes the Starmetal Amulet, the
    Starfall Blade and the Tome of Meteor.

47. **Blueprints** (**N**) – four built-in designs (Starter Hut, Stone Cottage, Watch Post,
    Farmstead) plus your own. Each shows a top-down plan, footprint, pieces, the level it needs and a
    bill of materials (need / have, counting your bag and chests within 18 m) with what's missing.
48. **Placing a blueprint** – press **Place**: the whole design follows your cursor as holograms
    (red where a tree, water or a town is in the way), **R** turns it, left click lays out a
    construction site. Every piece not built yet stays as a hologram.
49. **Manual construction** – walk to a hologram and press **F**: "Build Wood Wall (4 Wood)".
50. **Automatic construction** – in the blueprint screen switch **Auto-build** on for a site: while
    you're within 30 m it builds a piece every 0.3 s (floors, walls, furniture, roofs), taking
    materials from your bag and then from chests near the site. It pauses and tells you what's
    missing when you run out. Sites are saved; you can have 8 at once.
51. **Save your own designs** – stand in your base (on your land claim, or within 10 m) and press
    **Save my buildings here as a blueprint**. **Export to clipboard** copies the JSON;
    **Import from clipboard** brings a design in.
52. **Web designer** – open [`web/blueprint-designer/index.html`](web/blueprint-designer/index.html)
    in any browser (no install, works offline): paint floors, walls, doors, roofs and furniture on a
    1 m grid, turn the design, move its anchor, see the bill of materials and roof checks, then copy
    the JSON and import it in game (or drop the `.json` into the game's `user://blueprints` folder).

53. **Horizon** – zoom out (wheel) and tilt the camera low (PgDn): beyond the streamed chunks the
    terrain continues as coarse 64 m tiles out to ~500 m – coastlines, mountains, lakes and biome
    colours – fading into the fog.
54. **Fast travel stress** – press F3 and sprint (or use the debug teleport in tests): the overlay
    shows worker threads, the chunk-data cache (MB, hits, evictions), prefetch ahead of you, average
    build time and far tiles. Walk away and back: chunks come straight from the cache.
55. **World persistence** – fell trees in a few places, save (Esc → "Save world", or wait for the 2-minute autosave) and look in
    `user://worlds/<world>/regions/`: one small compressed `r.X.Z.L.dat` per 32×32-chunk region
    you changed. Older saves are migrated automatically.
56. **The edge of the world** – the world is 27.7 km across (3,003,289 chunks). From 12.8 km out,
    land gives way to an endless ocean; at 13.86 km you can't go further.
57. **World survey** – `godot --headless --path . res://tools/world_survey.tscn -- --seed=123`
    samples the whole world (biomes, land/sea, every village, kingdom and POI) and benchmarks
    generation into [`docs/WORLD_SURVEY.md`](docs/WORLD_SURVEY.md).

58. **Listen** – every action has a sound (swings, blocks, parries, hits, footsteps that change on
    grass/stone/sand/snow/wood floors, chopping, mining, eating, spells by element, chests, crafting), the
    music follows you (day, night, town, combat, dungeons, bosses) and the ambience changes with the place
    (birds, crickets, wind, sea, caves, town bustle, rain). Volumes are in **Settings**.
59. **Sky & weather** – watch a full day: sunrise, dusk colours, stars and the moon (its phase changes
    over 8 days; the clock shows it). Weather comes and goes on its own (rain, thunderstorms with
    lightning, snow in the cold, fog, desert sandstorms); press **F2** to cycle it. Standing in the rain
    makes you **Wet**; a roof keeps you dry and rain stops on roofs.
60. **Environment** – forest and meadow nights have fireflies, forests shed leaves, meadows have pollen,
    deserts blow dust, crystal glades sparkle, swamps are misty. Trees and grass sway with the wind (more in
    storms); water ripples and glints.
61. **Animation & VFX** – run (lean, knees, footstep dust), jump off a ledge (arms up, landing squash and
    dust), swim (strokes), cast a spell (hands raised), swing (weapon trail, sparks), chop and mine (wood
    and stone chips), drop below 30% health (red pulsing vignette).
62. **Icons & UI** – every item has a pixel-art icon; panels pop in with a sound; **Esc → Settings** (also
    on the main menu): volumes, fullscreen, V-Sync, render scale, shadows, horizon terrain, particle
    options, screen shake. Saved to `user://settings.cfg`.

63. **Multiplayer (host)** – on the main menu type your name, tick **Host the world I play**, then
    create or load a world. Friends on your network join with your IP (over the internet, forward UDP
    port 24565). The top bar shows who's online; **Enter** opens the chat.
64. **Multiplayer (join)** – type the host's address (`192.168.1.20` or `host:port`) and press **Join**:
    you load the same world from the seed (a checksum makes sure it's identical), appear next to the host
    and see each other move, swing, swim and cast. Chop trees, gather, craft, build, drop and pick up items:
    the host's server checks each action and everyone sees the result. You can't remove other players'
    buildings. Monsters pause while a session is online (combat sync comes later).
65. **Dedicated server** – `godot --headless --path . -- --server --world=<id>` (or `--seed=N`; without
    either it plays the world "server"). Guests' characters are saved with the world and come back when
    they rejoin with the same name. Command-line join: `godot --path . -- --connect=127.0.0.1 --name=Ann --class=wizard`.

66. **Gear progression (alpha balance)** – gear unlocks at levels 1 / 5 / 15 / 22 / 30 / 38 / 48: iron
    gear from the Smithing Manual at 10, mithril weapons (sword, dirk, war axe) once you have smelted
    mithril, legendaries at 48. Ruins (rank E) are an easy first trip; each rank further out is a big step up.
67. **Watch the bot play** – `godot --path . res://tools/playthrough.tscn -- --class=wizard` (or
    `--headless` for just the log): a fresh character gathers, crafts tools, builds a little base, fights,
    cooks, levels up, trades in the nearest village, makes a sword and clears the nearest ruins.

68. **Tutorial and guide** – start a new world: tips appear when they matter (an enemy is near, you get
    hungry, night falls, you reach a village) with your real keys. Close one with ✕. **F1** opens the
    guide. Settings → Gameplay → *Replay the tutorial* shows them again.
69. **Settings** – Esc → Settings: try *Difficulty* (Story halves the damage you take), *Controls*
    (click a binding, press a new key; a warning names any action that already uses it), and
    *Accessibility* (colour-vision filter, high contrast, sound captions, interface scale).
70. **Save recovery** – in the main menu, *Recover* on a world lists its backups (made when you load a
    world, every 10 minutes and on crashes). Restoring one keeps the current save as a backup too. If a
    save file is damaged the game loads the newest good copy and tells you.
71. **Crash report** – if the game ever closes unexpectedly, the next start shows a notice with *Open
    report* (system info and the end of the log) and *Recover world*.
72. **Achievements** – main menu or pause menu → *Achievements*: 20 of them with progress bars and your
    lifetime stats (monsters defeated, trees felled, kilometres walked...).

73. **Outfits** – start a Knight and press K: the outfit line shows your armour style. Craft a Shadow Hood
    (Tailoring, after you get boar hide) and Leather Gloves, equip a dagger: you look and play like an
    Assassin, but keep Knight abilities. In light armour idle monsters notice you later; in full iron they
    notice you sooner and dodging costs more stamina. Item tooltips show Light / Medium / Heavy.

## Run the automated tests

```bash
tools/run_tests.sh            # or: tools/run_tests.sh /path/to/godot
```

or directly: `godot --headless --path . res://tests/test_runner.tscn` (exit code 0 = pass).
Run part of the suite with `-- --only=test_m14` (any part of a test name).

The suite (1206 checks) covers deterministic generation, chunk meshes/LOD/collision,
inventory rules, hunger, temperature (never damages), world-state persistence, and an
**integration test that boots the real game** and plays it with simulated input:
movement, eating, combat vs. the boar, block/parry/i-frames, loot, tree harvesting,
gathering, campfire warmth & cooking, cold debuffs, streaming after teleport,
death and respawn, swimming, travelling into a cave and back, and a full save → load
round trip (including falling back to the backup when a save file is corrupt).
World-generation tests check determinism, terrain/biome statistics over 10×10 km,
climate continuity, cave layout and data integrity. RPG tests check class data (50
starting points, affordable shields), the XP curve, skill balance (e.g. a max-Strength
Wizard never equals a max-Strength Knight), equipment and requirements, every class
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
Exploration tests check monster/boss data, legendary scrolls, potions and rare props; POI
determinism, rank growth with distance, distance from towns, flattened and cleared ground,
layouts per kind, dungeon plans for every rank (all rooms connected), rank-gated loot; and in
the running game: melee, archers, poison, rank scaling, a boss fight (boss bar, enrage, summons),
potions, ruins chests and hidden vaults, tower tomes, temple guardian → chest → blessing, hidden
groves, and a full dungeon run (floor, map, save position, secret wall, traps, descending,
sealed arena, boss, portal, exit, cooldown, death, save/load). Advanced-gameplay tests check
status effects and every elemental interaction, cures, Iron Skin, attack tokens and circling,
pack alerts, fleeing, dodging, healers, steering, elite affixes (shield, juggernaut, vampiric,
molten), boss phases, spikes, wards and pylons, beams, teleports, pulls, roars, poise breaks and
bombs, all 8 spells and their combos, tomes and the spellbook, a full base raid (warning,
waves, siege, arrow towers, spoils, plunder, destruction, repair), a town defense (hiding
villagers, downed guards, rewards, plunder prices, rolled outcomes) and every rare event.
Blueprint tests check the built-in designs, the JSON round trip, rotation (edges stay edges,
four turns = identity), validation warnings, cost and missing-material sums, build order, the
blueprint library (save, no overwrite, import, delete), the web designer's catalog staying in sync
with the game, and in the running game: preview, placing a site, building by hand, auto-build
waiting for materials, chests as sources, saving and reloading a half-built site, finishing it
piece for piece, capturing it back, rotated placement, removing a site and the blueprint screen.
Massive-world tests check the 3,003,289-chunk bounds, an ocean all along the world edge, identical
generation of the corner chunks, 1,500 random columns and 24 random full chunks anywhere in the
world, horizon tiles (coverage, cut-out, cached re-meshing), region files (round trip, lazy
loading, eviction, deleting empty regions, corrupt files, v1 migration, save/load), the data
cache on returning, and a 1.8 km journey at 70 m/s with bounded chunks, nodes, cache and objects.
Multiplayer tests check packet encoding and validation, name cleaning, world checksums, the read-only
guest inventory, puppet interpolation and region transfer, and run a **real session in two processes**
(host + headless guest over localhost): joining, identical terrain, puppets moving both ways, items from
the server, gathering, building with server-side costs and ownership, drop and pick up, the host's
building and harvesting reaching the guest, time sync, speed-cheat correction, chat, saved guest
characters and rejoining a dedicated server.
Art & polish tests check that every sound named in the code exists, music and ambience loops, the music
director, rate limiting and bus volumes, an icon for every item (with outline and the right drawing),
weather rules per climate (snow in the cold, sandstorms in deserts, more rain where it is wet), shaders and
terrain AO, settings save/load/apply, animation states (footsteps, knees, jump, swim, cast, trails),
self-cleaning particles, and in the running game: sky, sun and moon, moon phases, rain (particles, colder
air, Wet, ambience), lightning, fog, snow, fireflies by night, combat music, landing and graphics settings.

Beta tests (Milestone 13): rebinding (conflicts, saving, gamepad, the Controls tab), every new setting
in the running game (difficulty, frame cap, interface scale, colour filters, high contrast, captions,
reduced flashing and motion, autosave, toggle sprint, a damaged settings file), the tutorial (first hints,
key names following rebinding, completion, profile progress, guide), save recovery (checksums, silent
damage, fallback to the previous save and to a backup, restore with undo, emergency snapshots, pruning),
crash handling (stale and running sessions, report contents, log tail, emergency save, menu notice), the
platform layer with a stand-in Steam (achievements, stats, presence, overlay pause) and the release config.

Alpha tests (Milestone 12): the balance limits (every class beats level-appropriate monsters with margin
at levels 1-100 and none dominates, a Wizard never matches the fighters physically, gear unlocks into the
late game, XP pacing, no recipe or trade loop makes money, processing keeps value), the **full gameplay
loop** played by a bot in the running game, a world-generation stress test over several seeds (spawn,
towns and ruins in reach, valid meshes at the centre, far away, at the world edge and in caves,
determinism, dungeon layouts) and frame-time budgets (idle, a 24-monster fight, a 200-piece base,
particle storms, long teleports).

Balance tables are generated from the code: `godot --headless --path . -s tools/gen_rpg_tables.gd`
→ [`docs/XP_TABLE.md`](docs/XP_TABLE.md), [`docs/CLASSES_AND_SKILLS.md`](docs/CLASSES_AND_SKILLS.md);
`godot --headless --path . res://tools/balance_report.tscn` → [`docs/BALANCE.md`](docs/BALANCE.md);
`godot --headless --path . res://tools/stress_test.tscn` → [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md)
(add `-- --seeds=50` for a longer run; drop `--headless` to include rendering);
`godot --headless --path . res://tools/playthrough.tscn -- --class=knight --seed=N` prints a bot playthrough.

Visual check (renders screenshots, needs a display or `xvfb-run`):

```bash
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=build   # base / build / crafting
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=town    # villages, kingdom, trade
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=explore # ruins, tower, temple, grove, dungeon
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=advanced # raids, elites, bosses, spells, events
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=blueprint # blueprints and construction
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=massive  # horizon, far reaches, world edge
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=polish   # sky, weather, effects, icons, settings
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=multiplayer # host + headless guest
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots --only=outfits  # one body, many outfits
python3 tools/gen_audio.py        # regenerate all sound effects, ambience and music (needs ffmpeg)
godot --headless --path . res://tools/world_survey.tscn -- --seed=20250101  # whole-world survey -> docs/WORLD_SURVEY.md
python3 tools/build_designer.py   # rebuild the web designer after changing build pieces or built-in blueprints
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
  combat/                AttackData, hit queries, status effects, projectiles, ground hazards, VFX
  camera/                Tactical camera rig
  player/                Player controller, combat, blocky humanoid model
  enemies/               Enemy base class, boar, data-driven Monster AI, elites, combat director, boss ward pylons
  world/                 Terrain generator, chunks & streaming, biomes, props, caves, spawner, day/night
  world/gen/             WorldGenSettings (all generation parameters + biome list)
  save/                  SaveManager (world list, save/load, backups), RegionStore (compressed region files)
  net/                   Multiplayer: Net autoload, NetServer, NetClient, RemotePlayer, NetProtocol
assets/audio/            Generated sound effects, ambience loops and music (tools/gen_audio.py)
assets/shaders/          Sky, foliage (wind sway) and water shaders
  rpg/                   Classes, skills, progression, character stats, equipment, abilities
  inventory/             ItemData resource, Inventory
  crafting/              Recipes, recipe book, crafting rules
  building/              Build pieces, grid building manager, build mode, piece meshes
  blueprints/            Blueprint format, library, construction sites, holograms, placement preview
  living/                Settlements (generation, layouts, sites), NPCs, economy, reputation, requests, farming, gossip
  exploration/           Points of interest, POI sites, dungeons (plans, instances, traps, doors), loot tables, chests
  raids/                 RaidManager: base raids, town raids, plunder
  events/                WorldEvents (blood moon, meteors, aurora, goblins, eclipse), meteor craters
  ui/                    HUD, theme, slots, temperature gauge, map, panels (character, crafting, trade, spellbook...)
data/                    Data-driven content (.tres): items, attacks, movesets, abilities, classes, enemies, props, biomes, worldgen
data/blueprints/         Built-in blueprints (.json, generated by tools/gen_blueprints.py)
web/blueprint-designer/  External blueprint designer (index.html is built by tools/build_designer.py)
tests/                   Automated test suite + screenshot runner
docs/                    TODO, CHANGELOG, architecture notes
tools/                   Helper scripts
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the systems fit together and how
to add new items, props, enemies and biomes without touching engine code.
