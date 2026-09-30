# Shardlands (working title)

A stylized, blocky low-poly **open-world survival RPG** built with **Godot 4.4**.
Top-down/isometric tactical camera, real-time manual combat, deterministic procedural
world streamed in chunks, survival systems (health, hunger, temperature), and a long-term
roadmap toward classes, skills, crafting, dungeons, settlements, building and a massive world.

> Status: **Milestone 2 — world generation** (on top of the Phase 1 prototype). See [`docs/TODO.md`](docs/TODO.md) for the
> honest status of every system and [`docs/CHANGELOG.md`](docs/CHANGELOG.md) for history.

![Overview](docs/screenshots/03_zoomed_out_rotated.png)

| Sunscorch Desert | Stonecrown Mountains | Crystal Glade |
|---|---|---|
| ![Desert](docs/screenshots/biome_desert.png) | ![Mountains](docs/screenshots/biome_mountains.png) | ![Crystal](docs/screenshots/biome_crystal_glade.png) |
| **The Deeps (caves)** | **World map** | **Boar charge telegraph** |
| ![Cave](docs/screenshots/cave_inside.png) | ![Map](docs/screenshots/world_map.png) | ![Charge](docs/screenshots/04a_boar_charge_telegraph.png) |

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
| World map | M |
| Quick save | F5 |
| Pause | Esc |
| Respawn after death | R |
| Help overlay / debug overlay | F1 / F3 |
| **Debug:** air temperature −10 / +10 °C | F6 / F7 |
| **Debug:** spawn a Thornback Boar in front of you | F8 |
| **Debug:** skip 2 hours | F9 |

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
13. **Save/load** – create a named world, harvest some trees, place a campfire, quit to
    menu (Esc → "Save & quit to menu"), load it again: everything is where you left it.

## Run the automated tests

```bash
tools/run_tests.sh            # or: tools/run_tests.sh /path/to/godot
```

or directly: `godot --headless --path . res://tests/test_runner.tscn` (exit code 0 = pass).

The suite (191 checks) covers deterministic generation, chunk meshes/LOD/collision,
inventory rules, hunger, temperature (never damages), world-state persistence, and an
**integration test that boots the real game** and plays it with simulated input:
movement, eating, combat vs. the boar, block/parry/i-frames, loot, tree harvesting,
gathering, campfire warmth & cooking, cold debuffs, streaming after teleport,
death and respawn, swimming, travelling into a cave and back, and a full save → load
round trip (including falling back to the backup when a save file is corrupt).
World-generation tests check determinism, terrain/biome statistics over 10×10 km,
climate continuity, cave layout and data integrity.

Visual check (renders screenshots, needs a display or `xvfb-run`):

```bash
godot --path . res://tests/screenshot_runner.tscn -- --out=/tmp/shots
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
  inventory/             ItemData resource, Inventory
  ui/                    HUD, theme, slots, temperature gauge
data/                    Data-driven content (.tres): items, attacks, enemies, props, biomes, worldgen
tests/                   Automated test suite + screenshot runner
docs/                    TODO, CHANGELOG, architecture notes
tools/                   Helper scripts
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the systems fit together and how
to add new items, props, enemies and biomes without touching engine code.
