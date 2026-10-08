# Shardlands — Game Design Document

Version of the game: **0.14.0 beta** (Milestones 1–14 done) · Engine: Godot 4.4.1, GDScript
Document written: 2 October 2026, from the real code on branch `claude/survival-rpg-foundation-tu1eqk`.
Updated for Milestone 14 (Outfits) on the same day.

This document describes the game **as it is in the code today**, then lists what is missing and what
could come next. When the older docs and the code disagree, this document follows the code and says
so (see [Differences between the docs and the code](#differences-between-the-docs-and-the-code)).

**Rules that must never break**

1. A Wizard is never as physically strong as a Knight or a Barbarian.
2. Crafting never fails.
3. Temperature never kills.

How the code protects them today: the Wizard has physical power ×0.7 and Strength efficiency ×0.35,
so at 100 Strength his physical multiplier is ×1.09 against ×2.42 (Knight) and ×2.88 (Barbarian), and
a balance test checks it. Since Milestone 14 a test also dresses a 100-Strength Wizard in full iron with a
sword: he hits ×0.66, less than a starting Knight (×1.28). `Crafting.craft()` has no failure path: if you have the materials, the item is
made. `TemperatureComponent` has no damage code at all, and its debuff table never touches health.

## Contents

1. [Game overview](#1-game-overview)
2. [World and story](#2-world-and-story)
3. [Systems](#3-systems)
4. [Content catalogue](#4-content-catalogue)
5. [Art and animation](#5-art-and-animation)
6. [Status of everything](#6-status-of-everything)
7. [To-do list](#7-to-do-list)
8. [New ideas](#8-new-ideas)
9. [Suggested next milestones](#9-suggested-next-milestones)

---

## 1. Game overview

| | |
|---|---|
| **Name** | Shardlands (working title) |
| **Genre** | Open-world 3D survival RPG with action combat, crafting, base building and co-op |
| **Camera** | Top-down / isometric tactical camera you can rotate, tilt, zoom and pan |
| **Look** | Blocky low-poly voxel world. Everything (characters, terrain, icons, sound, music) is made by code |
| **Platforms** | Windows, Linux, web browser. Steam support is ready but not tested on real Steam. No macOS build |
| **Players** | Single player, or co-op with up to 8 players (one host or a dedicated server) |
| **Version** | 0.14.0 beta |
| **Size of the code** | about 32,600 lines of GDScript in `src/` + 7,800 lines of tests; 386 data files in `data/` |

**Pitch.** You start alone in a huge, seed-generated world (27.7 × 27.7 km). You gather sticks and
stones, craft tools, build a home, and grow from a level 1 survivor into a level 100 hero. You pick one
of four classes, fight with timing-based combat (dodge, block, parry, combos), learn spells, trade in
villages, defend your base from bandit raids, and clear dungeons from rank E to rank S for legendary
gear.

**Tone.** Friendly and cosy on the surface (bright colours, fireflies, villages with daily routines),
with real danger at night and far from home (blood moons, raids, bosses). Survival is gentle: cold and
heat make you weaker but never kill you; only hunger and enemies can kill.

**Core loop.** Gather → craft tools → build a base → fight and level up → trade and get recipes →
explore points of interest and dungeons → get better gear → go further out (harder ranks) → repeat.

---

## 2. World and story

### What exists today

- **The world** is a square continent area surrounded by an endless ocean. Land sinks into the sea
  12.8 km from the centre and you cannot go past 13.86 km.
- **Eleven surface biomes and one underground biome** (see the catalogue).
- **Kingdoms and villages** with generated names (e.g. "Kingdom of Valdoria", capital "Valdor"). The
  survey of seed 20250101 finds 229 capitals and 658 villages. Each kingdom has a ruler on a throne who
  gives titles: *Friend of …*, *Knight of …*, *Champion of …*.
- **Small bits of folk lore**, only in villager gossip:
  - "When the moon turns red, the dead walk" (Blood Moon).
  - A little green fellow with a sack of gold (Treasure Goblin).
  - Fallen stars are made of a metal no smith has worked (star metal).
  - A hidden grove where starlight orchids grow.
- **"The Ancients"**: temples give the *Blessing of the Ancients*. Nothing else explains who they were.
- **Boss lines**: each boss has two short shouts at its phase changes (e.g. "The Bone King raises a ward
  of souls!", "Grimtusk bellows: Burn it all down!").
- The top achievement is called *Legend of the Shardlands*.

### What is missing

- **(Fixed in Milestone 16)** No main story, no intro, no ending. The player has no reason to be in the world except to survive
  and grow.
- **The name "Shardlands" is never explained.** There are crystal shards and void shards as items, but no
  "shard" event, place or history.
- No history of the kingdoms, no wars, no named heroes or villains (except Grimtusk).
- No reason why the Bone King, the Arcane Colossus or the Elder Thornmaw exist.
- No quests with steps or choices, no dialogue trees, no books you can read for lore.
- No backstory for the four classes and no character creation beyond picking a class.

Section 8d has ideas for a story that fits the existing content.

---

## 3. Systems

Each system has a short "how it works" note. Key numbers come from the code and data.

### 3.1 Movement
- WASD moves relative to the camera. Shift sprints (costs stamina and makes you hungry faster; can be a
  toggle in settings). You step up 1-block ledges automatically and slow down when wading.
- **Dodge roll** (Space): a roll with invulnerability frames (0.04 s → 0.32 s, longer with Dexterity).
  You roll through enemies.
- **Jumping off ledges** is automatic (fall pose, landing squash and dust). There is no jump key.
- **Swimming** in deep water costs stamina; with no stamina you swim slowly. You never drown. Walk against a
  bank to climb out.
- Frozen lakes in the tundra are walkable ice.
- No mounts, boats or fast travel.

### 3.2 Camera
- Follows the player. Rotate (Q/E or middle mouse), tilt (Page Up/Down), zoom (wheel), free pan (arrow
  keys), recenter (V). Gamepad: right stick.
- Trees between the camera and you fade out (dither). Roofs above you hide so you can see inside.
- Camera shake on hits (can be turned off). Far plane 640 m; horizon terrain out to 512 m.

### 3.3 Combat
- **Light attacks**: a combo per weapon type — sword 3 hits, dagger 4 hits, axe 2 hits, staff 2 hits,
  unarmed 2 punches. **Heavy attack**: one strong hit (sword overhead, axe cleave, dagger lunge, staff
  sweep, kick).
- Each attack has windup / active / recovery times, reach, poise damage and knockback (`AttackData`).
  Input is buffered, and you can cancel late recovery into a dodge or the next attack.
- **Block** (hold Ctrl): frontal block, costs stamina; a guard break happens when stamina runs out.
  Block strength depends on the class (Knight 80%, Barbarian 60%, Assassin 55%, Wizard 50%) and the shield.
- **Parry**: block just before a hit (window 0.15–0.25 s by class).
- **Lock-on** (Tab) cycles targets.
- **Critical hits**, **backstab** from behind (×1.3–×2.0 by class), **Exposed** windows (e.g. a boar
  after its charge takes +50%), **poise and stagger**, damage types and resistances (fire, frost,
  lightning, poison, arcane, holy, physical).
- **Status effects** (shared by the player and enemies): burn, poison (3 stacks), bleed (5 stacks),
  chill, freeze, stun, shock (+20% damage taken), wet, weakened (−25% damage), slowed, silenced, taunt;
  buffs: regen, haste. Water makes you wet.
- **Elemental combos**: Steam (fire on wet), Doused (water puts out fire), Deep Freeze (chill twice),
  Shatter (fire on frozen ×2), Conducted (lightning on wet ×1.5), Combustion (fire ignites Miasma).
- Damage numbers, hit sparks, weapon trails and hit sounds.

### 3.4 Classes and abilities
- Four classes, each with **exactly 50 starting skill points**, its own starting outfit, weapon proficiencies,
  starting gear and three abilities (unlocked at levels 1, 5 and 15). Abilities: Z / X / C.
- Barbarian has **Rage** (built by fighting, spent by Berserk).
- Every class can use the **Magic Temperature Shield** (T): 10 minutes of cold/heat protection, needs
  Mana Control +2 above the class start; the Wizard pays the least mana.
- Respec with the Draught of Forgetting (Milestone 15). Since Milestone 17b–d every class learns a new ability every
  two levels (53 in total, a level-100 ultimate at the end), and from level 30 every active ability can get one of
  two upgrades (Milestone 17d). See the catalogue and ARSENAL_PLAN.md for every ability.
- **What a class is (Milestone 14):** every class has the same body. A class decides its starting outfit and
  weapon, its starting skill points, how fast each skill grows (skill efficiency), its physical and spell
  power, its weapon skill and its three abilities. Anything you wear can be worn by any class, so a Knight in
  light leather with daggers plays like an Assassin but keeps Knight abilities and Knight growth.
- **Option A talent (chosen with the player):** the class gap is small - off-class weapons ×0.85–0.95, weak
  skills 0.75–0.9 effective. A Wizard with 100 Strength in full iron with a sword reaches ×0.66 of a
  max-Strength Knight: close, never equal (tested, limit ×0.9).
- **Character creation (souls-like):** pick a class to see its starting kit on a turning 3D preview, its skill
  bars (with gear bonuses), health/mana/armour, talent, abilities and supplies; choose skin (6), hair colour
  (8), hair style (short, long, topknot, bald) and beard. Every class starts in its complete set:
  Knight — Squire's Kit + sword and buckler + bandages, bread; Barbarian — Raider's Furs + handaxe + meat, a
  warming draught; Assassin — Shadowstalker's Garb + dagger + antidotes, a healing draught; Wizard —
  Apprentice's Vestments + staff + mana tonics.

### 3.5 Spells and mana
- **Mana** pool and regeneration grow with Mana Control.
- 8 **spells** learned from **tomes** (found in wizard towers, dungeons, elites, treasure goblins, or
  crafted at the Arcane Altar). Any class can learn them, but each needs a Mana Control level (10–60).
- Two spell slots (Y / H); the **Spellbook** (L) assigns them and lists the combos.
- Spell power = class spell power (Wizard ×1.45, Knight ×0.6, Barbarian ×0.5, Assassin ×0.7) × skill
  × gear. The Aurora event gives +15% spell damage and double mana regen.

### 3.6 Levelling and skills
- Levels 1–100. XP curve `100 + 30·n^1.5 + 0.05·n³` → about 1 hour to level 10, 20 hours to 50, 400 hours to 100.
- XP from kills (full XP within 5 levels of the monster), discoveries (biomes, places, caves),
  harvesting, gathering, cooking, crafting, requests, raids. Blood Moon gives +50% XP.
- **Five skills, 1–100**: Strength, Mana Control, Defense, Crafting, Dexterity. Each class spends points
  with a different efficiency (e.g. Wizard Strength ×0.35, Mana Control ×1.3).
- **Milestone perks** at 25 / 50 / 75 / 100 (Crafting at 10/25/45/70/90), for example *Iron Skin*
  (Defense 50: harmful effects 30% shorter) or *Evasion* (Dexterity 75: dodge i-frames +50%).
- Character screen (K) shows every stat change live.

### 3.7 Survival
- **Health** regenerates after a short delay. Death → respawn (R) at your bed or spawn.
- **Stamina** for sprint, dodge, heavy attacks, blocking and most class abilities.
- **Hunger** 100 → 0. Drains faster when sprinting and in cold or heat. States give buffs/debuffs. At
  0 you starve slowly (0.5 HP/s) — **starvation can kill**.
- **Temperature**: felt temperature drifts toward the air temperature (biome, time of day, altitude,
  water, weather, regional noise), plus heat sources (campfires, torches, max 28 °C), food warmth,
  clothing insulation/cooling, and shelter under a roof (up to 10 °C closer to comfortable). Seven levels:
  Freezing, Cold, Chilly, Comfortable (10–26 °C), Warm, Hot, Scorching. Bad levels slow you, weaken
  attacks, stop health regen and raise hunger. **Temperature never deals damage.**
- Story difficulty halves damage taken; Hard raises damage and hunger.

### 3.8 Gathering
- **Press F** on bushes, sticks, stones, reeds, dry shrubs, plants and clay.
- **Hit** trees and rocks (left mouse). Tools in your bag are used automatically: better tools break
  things faster, and ores need a tier (copper/coal: stone pickaxe, iron: copper pickaxe, mithril and
  crystal: iron pickaxe).
- Removed props are saved; plants, bushes and ore veins regrow (10–60 minutes). Trees and boulders do not.
- Loot flies to you (magnet).

### 3.9 Crafting
- 76 recipes at 7 places: by hand, Workbench, Forge, Tailoring Table, Arcane Altar, Campfire (cooking)
  and Alchemy Table. Stand within 4 m of a station and press G.
- Recipes are learned three ways: **starting**, **discovery** (the first time you get an ingredient,
  e.g. copper ore teaches copper recipes) and **books** (recipe books, legendary scrolls).
- **Crafting never fails.** Low Crafting skill makes recipes cost more materials; higher skill makes them
  cheaper. Crafting skill also unlocks recipe tiers (10 / 25 / 45 / 70 / 90).
- Cooking at higher skill can give a bonus item. Crafting is instant (no queue, no fuel).

### 3.10 Inventory and equipment
- Bag of 24 slots with stacks, hotbar 1–8, move/merge/use/drop. Storage chests have 16 slots.
- **Eight equipment slots**: main hand, off hand, head, chest, hands, feet, ring, amulet.
- Gear has level requirements and stat bonuses (damage, armor, crit, spell power, mana, insulation,
  cooling, move/attack speed, skills). Swapping weapons changes your combo and your model's weapon.
- Rarity: Basic, Common, Uncommon, Rare, Very Rare, Magical, Legendary (glow in slots).
- **Outfits (Milestone 14):** every head, chest, hands, feet and off-hand piece is drawn on your character
  (27 looks) and has an **armour weight**:
  - **Light** (cloth, leather, cloaks, robes, hats): each piece makes idle enemies notice you 6% later and a
    dodge 4% cheaper. A full light outfit: noticed at 76% range, dodges cost 84%.
  - **Medium** (padded cloth, squire's and horned helms, buckler): no change.
  - **Heavy** (chainmail, iron, plate, big shields): each piece makes enemies notice you 8% sooner and a dodge
    6% dearer. A full heavy outfit: noticed at 140% range, dodges cost 130%.
  - Everyday armour gives small **+1 / +2 skill bonuses** (e.g. gloves +1 Dexterity, chainmail +2 Defense).
    Skill bonuses still pass through your class's skill growth, so a Wizard gets little from Strength gear.
  - The character screen shows your outfit style, notice range and dodge cost.
  - **Gear sets** (2 and 4 pieces): Squire's Kit (+15 health / +50 ms parry, +5% block, +2 Defense),
    Raider's Furs (+5% physical damage / +20 stamina, +2 Strength), Shadowstalker's Garb (+15% backstab /
    +5% crit, +2 Dexterity), Apprentice's Vestments (+5% spell power / +15% mana regen, +2 Mana Control).
    Every set piece has a starting recipe, so any class can make any set.

### 3.11 Building and blueprints
- **Build mode** (B): grid of 1 m cells with floor, object, roof and edge slots. Green ghost = OK, red =
  the reason it can't be placed. R rotates, right click removes (100% refund on your land, 50% elsewhere).
- 28 build pieces: floors, walls, doors, windows, fences, roofs, furniture, chest, stations, defenses,
  torch, land claims and farm plots.
- **Land claims** (flag 8 m, totem 16 m, max 5): no monster spawns, full refunds.
- **Building health**: pieces can be damaged and destroyed in raids; repair in build mode (U / Shift+U)
  for 30% of the cost.
- **Blueprints** (N): 4 built-in designs (Starter Hut, Stone Cottage, Watch Post, Farmstead) plus your
  own. Shows the plan, the bill of materials (bag + chests within 18 m) and what is missing. Place a
  design as holograms, build by hand (F) or switch on **auto-build** (a piece every 0.3 s while you are
  within 30 m). Up to 8 construction sites. Save your base as a blueprint; import/export JSON; an
  offline **web designer** (`web/blueprint-designer/index.html`).
- One storey only (no stairs, no second floor).

### 3.12 Settlements and NPCs
- **Villages** (one decision per 384 m region) and **kingdom capitals** (one per realm of 4×4 regions),
  flattened, with no wild props, caves or monster spawns. You cannot build inside towns.
- Villages: furnished houses, shop, smithy, farms, plaza with a well, stalls, notice board. Capitals add
  walls, gates, towers, a keep with a throne, barracks and a royal market.
- **NPC roles**: merchant, royal merchant, blacksmith/armorer, farmer, villager, guard, ruler (noble),
  travelling trader. Each has a daily routine (work, lunch, evening at the plaza, sleep at home) and walks
  along streets and through doors.
- **Dialogue**: greeting by role and reputation, "What's new?" gossip built from the real world (adds
  villages, caves, dungeons and other places to your map).
- Guards fight monsters near capitals.

### 3.13 Economy
- Coins: copper, silver, gold. Prices depend on the region (wood is dear in the desert, food in the
  tundra), your reputation, and saturation (selling many of the same item pays less, recovers daily).
- Shops have limited stock and money, restock every morning; better stock unlocks with reputation.
- A travelling trader visits every third day with rare goods.
- Notice boards post daily delivery requests and boar hunts.
- **Reputation** per village and kingdom (villages share half with their kingdom): Stranger →
  Acquainted → Friendly → Honored → Revered. Better prices at each tier; kingdom titles and gifts (Royal
  Signet) from the ruler.
- The balance tests make sure no recipe or town-to-town trade makes money from shop purchases.

### 3.14 Farming
- Buy seeds (wheat, carrot, pumpkin), build Farm Plots outside towns, press F to plant and harvest.
- Crops grow with world time (also while you sleep): carrot 10 min, wheat 15 min, pumpkin 24 min.
- Wheat → bread; pumpkins teach Vegetable Stew. Village farms are worked by farmers.
- No watering, seasons or animals.

### 3.15 Enemies and AI
- **Thornback Boar**: its own state machine (wander, alert, chase, bite, telegraphed charge, exposed
  recovery, dazed after hitting a tree, leash back home).
- **Monster** framework (`MonsterData`): melee, ranged, caster and boss styles, data-driven attacks,
  projectiles, loot and looks.
- **Smarter AI**: attack tokens (only 2 melee attackers at once, others circle), pack alerts, flanking
  archers, dodging your swings, fleeing when badly hurt, separation, feeler-ray steering around walls,
  hopping ledges, detours. Healers and warders support allies.
- **Elites** (×2.2 health, glowing ring) with 9 affixes: vampiric, frenzied, molten, glacial, shielded,
  thorned, blinking, juggernaut, venomous. Champions have two.
- **Scaling**: by dungeon rank, and in the wild by distance from spawn (one rank per 1.2 km). Not by the
  player's level.
- Perception is distance only (no line of sight). No navmesh pathfinding.
- **Important:** in the open world only the Thornback Boar spawns on its own, and only in 4 biomes
  (Verdant Meadows, Whispering Forest, Frostpine Taiga, Emerald Jungle). All other monsters appear only at
  points of interest, in dungeons, in raids and in events.

### 3.16 Bosses
- Six bosses: Bone King, Arcane Colossus, Elder Thornmaw (dungeon bosses), Temple Guardian (temples),
  Grimtusk the Warlord (strong raids), Starborn Colossus (meteor craters, world boss).
- Boss bar, enrage at half health, two **phases** (66% and 33%) with a roar (briefly invulnerable), new
  move lists and arena hazards (falling rocks, fire rain, poison pools, frost shards).
- Boss moves: cleave, slam, volley, charge, summon, spikes, nova, beam, meteor rain, teleport, pull,
  roar, bomb, shield (ward with destructible pylons). Breaking poise gives a "Broken!" window.

### 3.17 Dungeons
- Dungeons are one kind of point of interest. **Rank E → S** grows with distance from the centre: one
  rank per 1.2 km, with a random shift of −1, 0 or +1 rank. So rank S starts at about 6 km (4.8–7.2 km).
- Enter at the archway (F). 1–3 floors of rooms and corridors (spanning tree + loops), monsters and
  elites, spike-trap rooms, treasure rooms, a secret room behind a cracked wall, stairs down, and a boss
  arena that seals shut. The boss drops a chest and opens a portal home.
- Three themes, chosen by the biome: **Crypt** (skeletons, Bone King) in tundra, taiga and mountains;
  **Arcane Sanctum** (sentinels, wisps, Arcane Colossus) in desert and crystal glade; **Thornwild Grotto**
  (crawlers, cultists, Elder Thornmaw) in forest, jungle and swamp; other biomes pick Crypt or Sanctum.
- Rank scales health ×1 → ×10, damage ×1 → ×4.6, +0 → +54 levels, XP ×1 → ×12. Cleared dungeons refill
  after 3 in-game days. Dungeon floor map. Dungeons are built high in the sky (y = 800) while the surface
  pauses.

### 3.18 Points of interest
- One POI decision per 256 m cell. Five kinds: **Ruins** (skeleton guardians, chest, sometimes a cracked
  floor with a hidden vault), **Wizard towers** (Tower Warden + wisps, lectern with a recipe tome,
  chest), **Temples** (dormant Temple Guardian, golden chest with a legendary recipe, altar blessing once
  a day), **Hidden groves** (not on the map until found; ancient tree, rune stones, rare plants),
  **Dungeons**.
- Seed 20250101 has 1,831 POIs: Ruins 525, Wizard Tower 378, Temple 162, Dungeon 528, Hidden Grove 238.
  By rank: E 18, D 40, C 69, B 89, A 95, **S 1,520** (83% of all POIs are S rank).

### 3.19 Raids
- **Base raids**: once your claim holds 8+ pieces, bandits may attack at night while you are near. A
  warning with a countdown (Alarm Bell adds 45 s, or ring it to start now), then 2–4 waves from one side.
  Cutthroats, archers, hexers, brutes (smash walls) and bombers (fire bombs). Strong raids are led by
  Grimtusk. Win → spoils and XP; leave → survivors loot your chests. Blood moons bring an undead raid.
- **Town raids**: a rider warns that a nearby town will be attacked. If you defend it, villagers hide,
  guards fight (they get knocked down, never killed), and you get reputation, coins and XP. If not, the
  outcome is rolled: guards hold, or the town is plundered for 2 days (prices +25%).
- Defenses: Log Palisade, Reinforced Door, Arrow Tower (shoots by itself), Spike Barricade, Spike Trap,
  Alarm Bell.

### 3.20 Events
- Rare world events rolled each hour from the world seed: **Blood Moon** (red night, undead hordes, +50% XP,
  more elites, base raid), **Meteor Shower** (a crater with star metal, sometimes the Starborn Colossus),
  **Aurora** (cold biomes, double mana regen, +15% spell damage), **Treasure Goblin** (catch it in 45 s for
  gold, gems and tomes), **Eclipse** (dark at noon, undead roam). Sky tints, saved with the world.

### 3.21 Weather and day/night
- A day is 20 minutes. Sun and moon arcs, dawn/dusk colours, stars, drifting blocky clouds, an 8-day
  moon phase that changes moonlight.
- Weather: clear, cloudy, rain, thunderstorm (lightning, thunder), snow (cold places), fog, sandstorm
  (deserts). Decided per 5-minute spell from the seed and the local climate. Rain makes you Wet (roofs keep
  you dry), lowers the air temperature and stops on roofs.
- Ambient effects: fireflies, leaves, pollen, desert dust, crystal sparkles, swamp mist, snow, cave
  motes. Foliage sways in the wind; water ripples.

### 3.22 Audio
- All sound is synthesized by `tools/gen_audio.py`: 71 sound effects, 10 ambience loops, 7 music tracks
  (menu, day, night, town, combat, dungeon, boss).
- 3D positional sound pool, pitch variation, rate limiting, cave reverb. A music director crossfades
  tracks by situation; ambience mixes by biome, time, weather and place. Five volume sliders.

### 3.23 User interface
- Code-built HUD: health, stamina, mana, hunger, temperature gauge with debuff chips, status chips, XP
  bar, clock with weather and moon phase, target frame, boss bar, hotbar, ability bar, prompts, toasts,
  damage numbers, low-health vignette.
- Panels: inventory, character (K), crafting (G), build palette (B), chest, spellbook (L), blueprints
  (N), dialogue, trade, notice board requests, reputation (J), world map (M) with markers, dungeon map,
  guide (F1), settings, achievements, main menu, save recovery, multiplayer bar and chat.
- 32×32 pixel-art icons drawn by code for every item. Panels pop in with sound.
- Menus need the mouse (no gamepad menu navigation yet). English only.

### 3.24 Tutorial
- 16 contextual hints that appear when they matter (moving, camera, gathering, bag, crafting, chopping,
  combat, hunger, cold, levelling, building, night, villages, points of interest, collapsing, guide) and
  show your real keys. Progress is kept per player profile; turn off or replay in Settings.
- Guide (F1) with all controls and pages on survival, combat, character, crafting, building, the world
  and saving.

### 3.25 Settings and accessibility
- Tabs: Gameplay, Controls, Audio, Display & graphics, Accessibility.
- Difficulty (Story / Normal / Hard), autosave interval, damage numbers, camera speed, frame cap, FPS
  counter, fullscreen, V-Sync, render scale, shadows, horizon terrain, particles, screen shake.
- Rebinding for keyboard/mouse and gamepad separately, with conflict warnings; toggle sprint.
- Accessibility: interface scale 75–150%, colour-vision filters (protanopia, deuteranopia,
  tritanopia), high-contrast UI, directional sound captions, reduced flashing, reduced motion.

### 3.26 Saving and backups
- Worlds in `user://worlds/<id>/`: `world.json`, `save.json` (+ `.bak`) and compressed region files for
  changed chunks. Autosave every 2 minutes (configurable), F5, and on quit.
- SHA-256 checksums; load falls back save → .bak → newest good snapshot and tells you. Up to 6 snapshots
  per world (on load, every 10 minutes, on crash). Recover screen with restore and undo.
- Crash reports with a log tail; an emergency snapshot on engine crashes.
- Not saved: dropped loot (despawns after 5 min), living enemies, an active raid or event wave.

### 3.27 Multiplayer
- ENet (UDP), up to 8 players, one authoritative server. Host from the menu or run a dedicated headless
  server. Join by IP. Protocol version + world checksum check.
- Synced: player movement and animations (20 Hz), outfits and weapons (also for late joiners), chat, gathering, harvesting, crafting, building,
  doors, item drop and pickup, world time. Guests' characters are saved with the host's world.
- **Not synced yet**: combat with monsters (monsters, raids and events **pause** while a session is
  online), PvP, bosses, dungeons, chests, trading, requests, farming, sleeping, cooking, blueprints.
  Character progression is reported by the client (can be cheated).

### 3.28 Achievements and Steam
- 20 achievements with progress bars and lifetime stats (monsters defeated, trees felled, km walked…).
- `Platform` layer with a local backend and a Steam backend through GodotSteam (rich presence, overlay
  pause, stats). Steamworks config files are generated from the game data. Not tested on real Steam;
  no achievement icons yet.

---

## 4. Content catalogue

Counts from `data/` (October 2026, after Milestone 14):

| Folder | Files | | Folder | Files |
|---|---:|---|---|---:|
| classes | 4 | | items | 147 |
| abilities | 13 (12 class + Temperature Shield) | | recipes | 84 |
| spells | 8 | | build_pieces | 28 |
| enemies | 20 (19 monsters + the boar) | | props | 37 |
| attacks | 39 | | biomes | 12 |
| movesets | 5 | | blueprints | 4 |

### 4.1 Classes

| Class | Role | Start skills (Str / MC / Def / Craft / Dex) | Health | Physical / Spell power | Block / Parry / Backstab | Start gear |
|---|---|---|---:|---|---|---|
| **Barbarian** | Brute force, rage, crowds | 18 / 3 / 12 / 5 / 12 | 139 | ×1.10 / ×0.50 | 60% / 0.18 s / ×1.5 | Rough Hand Axe, Horned Helm, Padded Vest |
| **Knight** | Sword and shield, defense, control | 14 / 4 / 18 / 6 / 8 | 135 | ×1.00 / ×0.60 | 80% / 0.25 s / ×1.3 | Squire's Sword, Squire's Helm, Wooden Buckler, Padded Vest |
| **Wizard** | Ranged elemental magic | 4 / 22 / 6 / 8 / 10 | 82 | ×0.70 / ×1.45 | 50% / 0.15 s / ×1.4 | Apprentice Staff, Wizard's Hat, Apprentice Robe |
| **Assassin** | Stealth, mobility, crits | 9 / 5 / 6 / 6 / 24 | 86 | ×0.95 / ×0.70 | 55% / 0.20 s / ×2.0 | Rusty Dagger, Shadow Hood, Leather Gloves, Worn Boots |

Best weapons: Barbarian axe ×1.15, Knight sword ×1.10, Wizard staff ×1.00, Assassin dagger ×1.15. Since Milestone 14
the fighters use their other weapons at ×0.9 (staff ×0.5); the Wizard keeps dagger ×0.8, sword ×0.6, axe ×0.5.

### 4.2 Abilities (per class)

| Class | Level | Ability | Cost | Cooldown | What it does |
|---|---:|---|---|---:|---|
| Barbarian | 1 | Whirlwind | 30 stamina | 6 s | Spin, hit every enemy around you (3.2 m) twice, 14 damage per hit |
| Barbarian | 5 | Battle Cry | 20 stamina | 25 s | +25% damage for 8 s, +40 Rage, nearby enemies flinch |
| Barbarian | 15 | Berserk | all Rage (min 50) | 30 s | +40% attack speed, 10% lifesteal for Rage/10 s, take +15% damage |
| Knight | 1 | Shield Bash | 20 stamina | 6 s | 12 damage, 1.5 s stun and taunt in front (half without a shield) |
| Knight | 5 | Guardian Stance | 25 stamina | 20 s | 6 s: take 50% less damage, taunt enemies in 10 m, move slower |
| Knight | 15 | Rallying Charge | 35 stamina | 14 s | Charge 8 m through enemies (20 damage each), heal 15% |
| Wizard | 1 | Firebolt | 9 mana | 0.8 s | 24 fire damage + burn; Shatter on frozen (×2) |
| Wizard | 5 | Frost Nova | 25 mana | 10 s | 14 frost damage in 5.5 m, freeze 3 s (65% slower) |
| Wizard | 15 | Chain Lightning | 30 mana | 6 s | 26 damage jumping between up to 4 enemies, +50% on wet |
| Assassin | 1 | Shadow Step | 15 stamina | 7 s | Blink behind the target (10 m); next hit in 3 s is a sure crit |
| Assassin | 5 | Poison Blade | 15 stamina | 20 s | 12 s: hits poison (3 stacks, 3 dmg/s per stack for 5 s) |
| Assassin | 15 | Vanish | 25 stamina | 25 s | Nearly invisible for 6 s; next hit is an Ambush (×2) |
| All | — | Magic Temperature Shield | mana (Wizard cheapest) | — | 10 minutes of cold and heat protection; needs Mana Control +2 |

### 4.3 Spells (any class)

| Spell | Mana Control needed | Mana | Cooldown | Element | What it does | Tome |
|---|---:|---:|---:|---|---|---|
| Blink | 10 | 15 | 6 s | arcane | Teleport 9 m toward the cursor, short invulnerability | craftable (Arcane Altar) |
| Healing Light | 15 | 30 | 14 s | holy | Heal 35%, cure all harmful effects, regen 8 s | craftable |
| Miasma (`poison_cloud`) | 20 | 25 | 10 s | poison | Poison cloud (3.5 m) at the cursor for 6 s; fire ignites it | craftable |
| Arcane Barrier | 25 | 35 | 25 s | arcane | Absorbs damage for 12 s (scales with spell power) | loot only |
| Arcane Missiles | 30 | 30 | 8 s | arcane | 5 homing missiles, 9 damage each | loot only |
| Blizzard | 35 | 40 | 16 s | frost | Ice storm (4.5 m) for 5 s, chill; twice = Deep Freeze | loot only |
| Meteor | 50 | 60 | 22 s | fire | 90 fire damage + burn after a delay (4 m); Shatters frozen | craftable (star metal) |
| Storm Call | 60 | 70 | 30 s | lightning | 8 strikes around you (12 m) over 4 s, 28 each; shock; +50% on wet | loot only |

### 4.4 Enemies and bosses

| Enemy | Type | Style | Level | Health | XP | Weak to / resists | Where it spawns |
|---|---|---|---:|---:|---:|---|---|
| Thornback Boar | Wildlife | own AI (charge) | 3 | 70 | 15 | fire ×1.5 / poison ×0.75 | Wild: Verdant Meadows, Whispering Forest, Frostpine Taiga, Emerald Jungle |
| Skeleton Warrior | Undead | melee (sword + shield) | 4 | 70 | 18 | fire ×1.25 / poison immune | Ruins, Crypt dungeons, Blood Moon/Eclipse hordes, undead raids |
| Skeleton Archer | Undead | ranged (bow) | 4 | 45 | 18 | fire ×1.25 / poison immune | Same as Skeleton Warrior |
| Thorn Crawler | Monster | melee beast | 5 | 55 | 16 | fire ×1.4 | Thornwild Grotto dungeons |
| Grotto Cultist | Monster | caster, heals allies | 6 | 55 | 22 | — | Thornwild Grotto dungeons |
| Arcane Sentinel | Magical | melee golem | 7 | 130 | 32 | physical ×0.8 / poison immune | Arcane Sanctum dungeons |
| Arcane Wisp | Magical | caster orb | 6 | 40 | 20 | physical ×1.1 / poison immune | Arcane Sanctum dungeons, wizard towers |
| Tower Warden | Elite | caster, wards allies | 10 | 220 | 90 | arcane ×0.7 | Wizard towers |
| Bandit Cutthroat | Bandit | melee, bleed | 5 | 75 | 20 | — | Base and town raids |
| Bandit Archer | Bandit | ranged | 5 | 50 | 20 | — | Raids |
| Bandit Hexer | Bandit | caster, weakens, heals | 7 | 60 | 35 | — | Raids |
| Bandit Bomber | Bandit | ranged fire bombs, siege | 7 | 55 | 35 | — | Raids |
| Bandit Brute | Bandit | melee, siege ×3 | 8 | 170 | 45 | — | Raids |
| Treasure Goblin | Monster | runs away | 6 | 140 | 80 | — | Treasure Goblin event |
| **Temple Guardian** | Boss | boss | 11 | 750 | 350 | fire ×0.6 / poison immune | Temples (dormant until you reach the altar) |
| **Bone King** | Boss | boss | 12 | 900 | 400 | fire ×1.2 / poison immune | Crypt dungeon arena |
| **Elder Thornmaw** | Boss | boss beast | 13 | 1000 | 450 | fire ×1.3 | Thornwild Grotto dungeon arena |
| **Arcane Colossus** | Boss | boss | 14 | 1100 | 500 | physical ×0.85 / poison immune | Arcane Sanctum dungeon arena |
| **Grimtusk the Warlord** (`bandit_warlord`) | Boss | boss | 14 | 1100 | 550 | — | Leads strong base raids |
| **Starborn Colossus** | Boss | world boss | 18 | 1700 | 900 | lightning ×0.8 / poison immune | Sometimes guards a meteor crater |

Levels and health above are the base (rank E) values; ranks and distance scale them up.

### 4.5 Biomes

| Biome | Role | Notes | Wild enemies |
|---|---|---|---|
| Verdant Meadows | land | grass, oaks, berry bushes, flowers, sunbloom | Boar, deer, rabbits, bandit thugs |
| Whispering Forest | land | dense forest; the usual spawn biome | Boar, deer, rabbits, thorn crawlers, bandit archers |
| Frostpine Taiga | land | cold pine forest | Boar, frost wolf packs, deer, rabbits |
| Snowy Tundra | land | freezing, frozen lakes, frost lotus, frostberries | Frost wolf packs, rabbits |
| Sunscorch Desert | land | hot by day, dunes, cactus, sandstorms | Sand scorpions, bandit archers and thugs |
| Emerald Jungle | land | hot and wet, jungle trees | Boar, thorn crawlers, grotto cultists, deer |
| Murk Swamp | land | half water, mire willows, giant toadstools, glowcaps, clay | Thorn crawlers, wisps, skeleton warriors |
| Sandy Beach | coast | palms, coconuts; shipwrecks | Shore crabs, bandit thugs |
| Stonecrown Mountains | mountain | up to ~60 m, rock and snow caps, ores, emberroot, mithril on peaks | Frost wolf packs, arcane sentinels, skeleton archers |
| Crystal Glade | rare | purple, crystals, moonpetals | Arcane wisps, arcane sentinels, rabbits |
| Deep Ocean | ocean | open water | none |
| The Deeps | underground | caves under entrances; ores, crystals, glowcaps, dreamcaps, Forgotten Caches; always 12 °C | none |

World share (seed 20250101): ocean 36.8%, meadows 13.7%, mountains 10.0%, tundra 7.5%, taiga 7.4%,
swamp 6.3%, forest 5.1%, desert 4.6%, jungle 3.9%, beach 3.8%, crystal glade 0.9%.

### 4.6 Items by type (147 items)

**Weapons (20)**

| Weapon | Type | Tier (rarity) | Level | Stats | How to get |
|---|---|---|---:|---|---|
| Rough Hand Axe | axe | Basic | 1 | — | Barbarian start, by hand |
| Squire's Sword | sword | Basic | 1 | — | Knight start, Workbench |
| Rusty Dagger | dagger | Basic | 1 | — | Assassin start |
| Flint Knife | dagger | Basic | 1 | +1 damage, +2% crit | by hand |
| Apprentice Staff | staff | Basic | 1 | +5 spell power, +10 mana | Wizard start, Workbench |
| Copper Sword | sword | Common | 5 | +3 damage | Forge (discovery) |
| Copper Dagger | dagger | Common | 6 | +3 damage, +3% crit | Forge (discovery) |
| Iron Longsword | sword | Common | 10 | +5 damage | Forge (Smithing Manual) |
| Iron Dirk | dagger | Common | 10 | +5 damage, +5% crit | Forge (Smithing Manual) |
| Iron War Axe | axe | Common | 10 | +7 damage | Forge (Smithing Manual) |
| Crystal Staff | staff | Uncommon | 15 | +20 spell power, +30 mana, +15 mana regen, +2 damage | Arcane Altar (Arcane Codex) |
| Mithril Sword | sword | Rare | 22 | +12 damage | Forge (discovery) |
| Mithril Dirk | dagger | Rare | 22 | +8 damage, +7% crit | Forge (discovery) |
| Mithril War Axe | axe | Rare | 22 | +14 damage | Forge (discovery) |
| Warlord's Cleaver | axe | Very Rare | 30 | +18 damage, +3 Strength | loot only (Grimtusk) |
| Sunforged Blade | sword | Legendary | 48 | +22 damage, +8% crit, +4 Strength | Forge (Legendary scroll) |
| Starfall Blade | sword | Legendary | 48 | +26 damage, +10% crit, +10 spell power, +3 Dexterity | Forge (star metal) |
| Titan's Greataxe | axe | Legendary | 48 | +28 damage, +6 Strength, +20 stamina | Forge (Legendary scroll) |
| Shadowfang | dagger | Legendary | 48 | +14 damage, +15% crit, +12% attack speed, +4 Dexterity | Forge (Legendary scroll) |
| Staff of the Archmage | staff | Legendary | 48 | +6 damage, +45 spell power, +60 mana, +30 mana regen | Arcane Altar (Legendary scroll) |

Gear tier unlock levels: Basic 1 · Common 5 · Uncommon 15 · Rare 22 · Very Rare 30 · Magical 38 · Legendary 48.

**Shields (3)** — off hand

| Shield | Weight | Tier | Level | Stats |
|---|---|---|---:|---|
| Wooden Buckler | Medium | Basic | 1 | armor 6, block 5, Defense +1 |
| Iron Kite Shield | Heavy | Common | 10 | armor 14, block 10, move −3, Defense +2 |
| Aegis of Dawn | Heavy | Legendary | 48 | armor 30, block 20, health +40, Defense +3 |

**Armour (21)** — weight decides how soon enemies notice you and how much a dodge costs

| Slot | Item | Weight | Tier | Level | Stats | How to get |
|---|---|---|---|---:|---|---|
| Head | Padded Hood | Medium | Basic | 1 | armor 3, insulation 3, Defense +1 | Tailoring |
| Head | Straw Sun Hat | Light | Basic | 1 | cooling 8, Crafting +1 | by hand |
| Head | Wizard's Hat | Light | Basic | 1 | mana +10, Mana Control +1 | Wizard start; Tailoring |
| Head | Shadow Hood | Light | Basic | 1 | armor 1, Dexterity +1, crit 1% | Assassin start; Tailoring (boar hide) |
| Head | Squire's Helm | Medium | Basic | 1 | armor 4, Defense +1 | Knight start; Forge (copper) |
| Head | Horned Helm | Medium | Basic | 1 | armor 3, Strength +1 | Barbarian start; Tailoring (boar tusk) |
| Head | Fur Cap | Light | Common | 4 | armor 2, insulation 8, Strength +1 | Tailoring (Leatherworker's Notes) |
| Head | Iron Great Helm | Heavy | Common | 10 | armor 10, Defense +2 | Forge (Smithing Manual) |
| Head | Crown of Stars | Light | Legendary | 48 | spell power 20, mana 40, Mana Control 5, cooling 5 | Legendary scroll |
| Chest | Padded Vest | Medium | Basic | 1 | armor 6, insulation 4, Defense +1 | Tailoring |
| Chest | Apprentice Robe | Light | Basic | 1 | armor 2, mana 15, mana regen 10, Mana Control +1 | Tailoring |
| Chest | Boar-hide Jerkin | Light | Common | 6 | armor 10, insulation 3, Dexterity +1 | Tailoring (Leatherworker's Notes) |
| Chest | Chainmail Hauberk | Heavy | Common | 12 | armor 22, move −5, Defense +2 | Forge (Smithing Manual) |
| Chest | Shadow Cloak | Light | Uncommon | 15 | armor 5, Dexterity 3, move +3 | Tailoring (Leatherworker's Notes) |
| Chest | Mithril Plate | Heavy | Legendary | 48 | armor 45, health 60, insulation 8, Defense 4 | Legendary scroll |
| Hands | Leather Gloves | Light | Basic | 1 | armor 3, attack speed 3, Dexterity +1 | Tailoring |
| Hands | Iron Gauntlets | Heavy | Common | 12 | armor 6, Strength +2, attack speed −2 | Forge (Smithing Manual) |
| Feet | Worn Boots | Light | Basic | 1 | armor 2, move +3, Dexterity +1 | Tailoring |
| Feet | Fur-lined Boots | Light | Common | 4 | armor 3, insulation 6, Strength +1 | Tailoring (Leatherworker's Notes) |
| Feet | Soft Leather Boots | Light | Common | 8 | armor 3, Dexterity +2, move +4 | Tailoring (Leatherworker's Notes) |
| Feet | Iron Greaves | Heavy | Common | 12 | armor 7, Defense +1, move −2 | Forge (Smithing Manual) |

**Accessories (6)**

| Slot | Item | Tier | Level | Stats |
|---|---|---|---:|---|
| Ring | Copper Ring | Common | 5 | crit 3% |
| Ring | Crystal Ring | Rare | 22 | spell power 10, Mana Control 3 |
| Amulet | Tusk Charm | Uncommon | 1 | Strength 3, health 10 |
| Amulet | Royal Signet | Rare | 1 | health 20, mana 15, armor 3 (ruler's gift) |
| Amulet | Moonpetal Pendant | Magical | 38 | Mana Control 5, mana 25, insulation 5, cooling 5 |
| Amulet | Starmetal Amulet | Magical | 38 | spell power 18, mana 40, health 25 |

**Tools (8)** — used from the bag automatically

| Tier | Hatchet | Pickaxe | Can mine |
|---:|---|---|---|
| 1 | Stone Hatchet | Stone Pickaxe | copper, coal |
| 2 | Copper Hatchet | Copper Pickaxe | + iron |
| 3 | Iron Hatchet | Iron Pickaxe | + mithril, crystal |
| 4 | Mithril Hatchet | Mithril Pickaxe | everything, fastest |

**Food (12)**

| Food | Hunger | Health | Warmth (°C) | How to get |
|---|---:|---:|---:|---|
| Wild Berries | 10 | 2 | — | berry bushes |
| Frostberries | 9 | 4 | — | frostberry bushes (tundra) |
| Brown Mushroom | 7 | — | — | mushroom patches |
| Carrot | 10 | 2 | — | farming |
| Cactus Fruit | 10 | 3 | −8 (cools) | cactus |
| Coconut | 16 | 4 | −4 | palm trees |
| Raw Meat | 8 | — | — | boars |
| Cooked Meat | 32 | 10 | +8 | Campfire |
| Bread | 30 | 6 | +3 | Campfire (wheat) |
| Vegetable Stew | 45 | 15 | +6 | Campfire (learned from pumpkins) |
| Hearty Stew | 55 | 25 | +12 | Campfire (Cook's Journal) |
| Cooling Salad | 20 | 5 | −10 | Campfire (Cook's Journal) |

**Potions and medicine (11)**

| Item | Effect | Where |
|---|---|---|
| Fiber Bandage | +30 health, stops bleeding | by hand |
| Healing Draught | +70 health | Alchemy Table |
| Mana Tonic | +60 mana | Alchemy Table |
| Warming Draught | +14 °C for a while | Alchemy Table |
| Cooling Draught | −14 °C for a while | Alchemy Table |
| Antidote | +10 health, cures poison | Alchemy Table |
| Purifying Draught | +20 health, cures everything | Alchemy Table |
| Troll's Brew | regenerate 6 health/s | Alchemy Table |
| Elixir of Might | "might" buff, 5 min | Alchemy Table (Alchemist's Grimoire) |
| Stoneskin Elixir | "stoneskin" buff, 5 min | Alchemy Table (Alchemist's Grimoire) |
| Elixir of Starlight | "starlight" buff, 5 min | Alchemy Table (Alchemist's Grimoire) |

**Materials (44)**

| Group | Items |
|---|---|
| Basic | Wood, Stick, Stone, Flint, Plant Fiber, Clay |
| Processed | Wooden Plank, Rope, Leather, Copper Ingot, Iron Ingot, Mithril Ingot, Star Metal Ingot, Arcane Dust |
| Ores and gems | Copper Ore, Coal, Iron Ore, Mithril Ore, Star Metal Ore, Crystal Shard, Gemstone, Gold Nugget |
| Monster parts | Boar Hide, Boar Tusk, Ancient Bone, Wisp Essence, Thorn Venom |
| Boss materials | Royal Bone (Bone King), Void Shard (Arcane Colossus), Thorn Heart (Elder Thornmaw), Sunstone (Temple Guardian), Star Core (Starborn Colossus) |
| Magic plants | Sunbloom, Frost Lotus, Emberroot, Dreamcap, Glowcap, Moonpetal, Starlight Orchid |
| Farming | Wheat, Pumpkin, Wheat Seeds, Carrot Seeds, Pumpkin Seeds |

**Books, scrolls and tomes (20)** — Smithing Manual, Leatherworker's Notes, Arcane Codex, Cook's Journal,
Alchemist's Grimoire; 7 Legendary Recipe scrolls (Aegis of Dawn, Crown of Stars, Mithril Plate,
Shadowfang, Staff of the Archmage, Sunforged Blade, Titan's Greataxe); 8 spell tomes (one per spell).

**Other (2)** — Campfire Kit (placeable), Bandit Insignia (sells to guards and merchants).

### 4.7 Crafting stations and recipes (84)

| Station | How to get it | Recipes |
|---|---|---:|
| By hand | always | 8 — bandage, campfire kit, flint knife, rope, rough hand axe, stone hatchet, stone pickaxe, sun hat |
| Workbench | build piece (wood 8, stone 4) | 5 — planks, apprentice staff, squire's sword, wooden buckler, tusk charm |
| Forge | build piece, level 3 (stone 15, clay 4, wood 4) | 31 — copper/iron/mithril/star metal ingots, tools, weapons, squire's helm, chainmail, iron helm/gauntlets/greaves, kite shield, 6 legendaries |
| Tailoring Table | build piece (planks 6, rope 3) | 14 — robe, hood, vest, leather, gloves, boots, fur cap, fur boots, jerkin, shadow cloak, wizard's hat, shadow hood, horned helm, soft leather boots |
| Arcane Altar | build piece, level 5 | 11 — arcane dust, crystal staff/ring, moonpetal pendant, starmetal amulet, 4 tomes, 2 legendaries |
| Campfire | Campfire Kit (placed) | 5 — cooked meat, bread, vegetable stew, hearty stew, cooling salad |
| Alchemy Table | build piece, level 2 | 10 — all potions and elixirs |

Village forges and workbenches also work as stations.

### 4.8 Build pieces (28)

| Group | Pieces |
|---|---|
| Floors | Wood Floor (wood 2), Stone Floor (stone 3, lv 3) |
| Walls | Wood Wall (wood 4), Stone Wall (stone 5, clay 1, lv 5), Log Palisade (700 HP, lv 4), Window Wall |
| Doors | Wooden Door, Reinforced Door (1200 HP, lv 8) |
| Roofs | Thatch Roof, Shingle Roof (lv 5) |
| Fence | Wooden Fence |
| Furniture | Table, Chair, Bed (respawn point, sleep) |
| Storage | Storage Chest (16 slots) |
| Stations | Workbench, Forge, Tailoring Table, Arcane Altar, Alchemy Table |
| Defense | Spike Barricade, Spike Trap, Arrow Tower (lv 6), Alarm Bell (lv 3) |
| Light | Standing Torch (light + a little warmth) |
| Land | Claim Flag (8 m), Claim Totem (16 m, lv 8) |
| Farming | Farm Plot |

The Campfire is not a build piece: it is placed from the Campfire Kit item.

### 4.9 Props (37)

| Group | Props |
|---|---|
| Trees (axe) | Oak, Pine, Snowy Pine, Palm, Jungle Tree, Dead Tree, Mire Willow, Giant Toadstool |
| Rocks (pickaxe) | Boulder, Snowy Boulder, Sandstone, Stalagmite |
| Ores (pickaxe tier) | Coal Seam (1), Copper Vein (1), Iron Vein (2), Mithril Vein (3), Crystal Cluster (3) |
| Gather (F) | Berry Bush, Frostberry Bush, Mushrooms, Fallen Sticks, Loose Stones, Reeds, Dry Shrub, Clay Deposit, Cactus (hit) |
| Magic plants | Sunbloom, Frost Lotus, Emberroot, Dreamcap, Glowcaps, Moonpetal, Starlight Orchid |
| Decoration only | Grass, Wildflowers, Lily Pad |
| Special | Forgotten Cache (cave loot with recipe books) |

POIs and towns also use their own code-built pieces (pillars, statues, altars, lecterns, rune stones,
ancient tree, wells, stalls, banners…), which are not in `data/props`.

### 4.10 Blueprints (4)
Starter Hut, Stone Cottage, Watch Post, Farmstead.

---

## 5. Art and animation

### How art is made today

There are **no texture, model or animation files**. Everything is built by code at runtime:

| What | How it is made |
|---|---|
| Characters | Coloured boxes (`MeshInstance3D` cubes) on pivot nodes: hips → knees, shoulders → elbows, a neck pivot for the head (`HumanoidModel`, `BeastModel`, `BoarModel`) |
| Terrain | Flat-coloured voxel block columns per biome (top / side / shore / underwater colours), baked per-corner ambient occlusion in vertex colours |
| Props, buildings, POIs, towns | Boxes merged into meshes by code (`PropLibrary`, `BuildMeshes`, `SettlementLayout`, `PoiLayout`) |
| Sky, water, foliage | Three shaders: sky (sun, moon phases, stars, clouds), water (waves, ripples, glints, rain rings), foliage (wind sway + camera dither fade) |
| Item icons | 32×32 pixel art drawn from primitives per item id/category, tinted by material, shaded and outlined (`ItemIcons`), 45 base drawings |
| Effects | One-shot particles of small cubes (debris, dust, sparks, splash, motes), weapon trail ribbons, GPU particles for weather and ambience |
| Sound and music | Synthesized in Python (`tools/gen_audio.py`): oscillators, noise, filters, plucked strings, FM bells, reverb |
| UI | Code-built panels with one shared theme; DejaVu Sans as fallback font |

### What each model looks like

| Model | Look |
|---|---|
| Player (all classes, Milestone 14) | One shared box humanoid: head, torso, arms with elbows, legs with knees; plain linen tunic, brown pants and boots. Everything else is drawn from the gear |
| Head gear | Padded hood, straw sun hat, fur cap with ear flaps, tall wizard's hat with glowing tip, squire's helm with red plume, horned helm with nose guard, shadow hood with face mask, iron great helm with eye slit, crown of stars |
| Chest gear | Quilted vest, robe with skirt, sleeves and gold trim, leather jerkin with strap, chainmail with rings and skirt, cloak with clasp, plate with breastplate, pauldrons and faulds |
| Hands / feet | Gloves, iron gauntlets with cuffs; boots, fur boots with fur rim, iron greaves with shin plates |
| Shields / amulets | Round buckler with a metal boss, kite shield with a red cross, golden Aegis with a sun; a small pendant on the chest |
| Starting looks | Barbarian: horned helm + padded vest + axe. Knight: plumed squire's helm + vest + buckler + sword. Wizard: wizard's hat + purple robe + staff (orb coloured by the staff). Assassin: shadow hood + gloves + boots + dagger |
| Villager / merchant / farmer / blacksmith | Random skin, hair and shirt colours; farmer straw hat, blacksmith apron, merchant cap and apron |
| Guard / ruler / trader | Guard helm and tabard; ruler gold crown and cape; trader hood, backpack and bedroll |
| Skeleton Warrior / Archer | Pale bones, glowing eyes, ribs, jaw gap; sword + shield, or bow with a hood |
| Bone King | Big skeleton with a dark red cape and an axe |
| Grotto Cultist / Tower Warden | Hood, robe skirt, glowing sash; staff |
| Bandits | Human with a weapon per role (sword, bow, axe, staff, bombs); brute is bigger and darker; Grimtusk has helm, horns, fur mantle and war cape |
| Treasure Goblin | Small, pointy ears, a big loot sack with gold peeking out |
| Arcane Sentinel, Arcane Colossus, Temple Guardian, Starborn Colossus | Stone golem humanoid with a glowing core; the Starborn has a star core and a star crown |
| Arcane Wisp | A glowing floating cube with a glowing cross and three orbiting cubes |
| Thorn Crawler | Six-legged blocky bug with thorns |
| Elder Thornmaw | A giant crawler with a jaw |
| Thornback Boar | Box body, thorny back ridge, pink snout, tusks, ears, four legs |

### Animations (all tween-based)

| Animation | What it looks like |
|---|---|
| Idle | Breathing, small glances (player); sniffing and head bob (boar); leg lifts and sway (crawler) |
| Run | Body leans forward, knees and elbows swing, footstep dust, footstep sounds by surface |
| Attack | One arm moves between a "ready" and a "strike" pose: `slash_r`, `slash_l`, `thrust`, `overhead` (+ `bite`, `charge` for beasts), with a weapon trail |
| Block | Arm raised in front |
| Dodge | The whole body does a forward flip |
| Cast | Hands raised |
| Spin | Whole-body spin (Whirlwind) |
| Jump / fall / land | Arms up in the air, squash and dust on landing |
| Swim | Arm strokes |
| Stagger | Torso snaps back |
| Hit | White flash on every part |
| Death | Knees buckle, then the body topples sideways |
| Ghost | See-through look (Vanish) |
| Boar charge | Red telegraph glow, head lowered, ground scraping |

**Weak spots:** only one arm animates attacks; class abilities reuse the generic swing and cast poses;
monsters reuse the player's poses; no two-handed or bow-draw animation for the player; there are no
textures on any surface, so large areas look flat up close.

---

## 6. Status of everything

✅ Done · 🟡 Partly done · ❌ Not implemented

| Area | Status | Notes |
|---|---|---|
| Movement, sprint, dodge, swimming | ✅ | No jump key, no climbing, no drowning |
| Camera | ✅ | |
| Melee combat (combos, block, parry, lock-on, crits, backstab, poise) | ✅ | |
| Ranged weapons for the player (bows, crossbows, throwing) | 🟡 | Bows and 5 kinds of arrows (M17a); no crossbows or throwing weapons yet |
| Weapon types (sword, axe, dagger, staff, shield, bow, spear, war hammer, greatsword, wand, tome) | ✅ | M17a: two-handed weapons, caster off-hands |
| Charged heavy, sprint, plunging attacks and ripostes | ✅ | M17a |
| Status effects and elemental combos | ✅ | Weather doesn't make everyone wet (only the player in rain) |
| Classes (4) and abilities (3 each) | ✅ | |
| More abilities / ability upgrades / talents | ✅ | M17b–d: ability book, 50 new abilities per class (levels 2–100), passives, ultimates, upgrades from level 30, 6-slot bar, 20 shared spells; no talent trees |
| Respec (reset skill points) | ✅ | Draught of Forgetting (Milestone 15) |
| Spells (8), spellbook, tomes | ✅ | No spell upgrades |
| Levels 1–100, skills, perks | ✅ | Levels 75–100 are very slow (only S-rank content) |
| Hunger, health, stamina, mana | ✅ | |
| Temperature (never kills) | ✅ | |
| Gathering, tools, tiers, regrowth | ✅ | |
| Crafting (never fails) | ✅ | |
| Item quality (Fine / Masterwork) | ✅ | Milestone 15; only from crafting |
| Crafting time, queues, fuel, station upgrades | ❌ | |
| Crafting/building from nearby chests | 🟡 | Blueprints use chests; normal crafting and build mode do not |
| Inventory and 8 equipment slots | ✅ | |
| Outfits: gear-driven looks, armour weight, skill bonuses on gear | ✅ | Milestone 14. No character customisation, dyes or ring looks |
| Building grid, defenses, repair, land claims | ✅ | |
| Multi-storey buildings, stairs, slopes | ❌ | |
| Blueprints, auto-build, web designer | ✅ | Designer not hosted online; no builder NPCs |
| Villages, capitals, NPC routines, dialogue, gossip | ✅ | |
| Crime, theft, NPC relationships, families | ❌ | |
| Multi-step quests and story | ✅ | Milestone 16: main quest, royal errands, journal |
| Roads and travelling traders that really travel | ❌ | |
| Economy, shops, reputation, titles | ✅ | |
| Farming | 🟡 | 3 crops; no watering, seasons or animals |
| Wild enemies across biomes | ✅ | Milestone 15: 2–4 per land biome, packs, peaceful animals; none in caves yet |
| Monster framework, elites, smart AI | ✅ | No navmesh, no line of sight |
| Bosses (6) with phases | ✅ | No roaming world bosses; legendaries have no special effects |
| Dungeons E–S, 3 themes | ✅ | No fog of war, keys or puzzles |
| POIs: ruins, towers, temples, groves | ✅ | Tower upper floors not walkable |
| POI rank spread | 🟡 | 83% of POIs are rank S; early ranks are rare |
| Base raids and town raids | ✅ | Active raids aren't saved |
| Rare world events (5) | ✅ | |
| Weather, day/night, moon | ✅ | Weather doesn't water crops or put out fires; no seasons |
| Audio and music | ✅ | Synthesized placeholders; no voice; no layered music |
| UI, icons, HUD | ✅ | |
| Gamepad menus | ❌ | |
| Languages other than English | ❌ | |
| Screen-reader support | ❌ | |
| Tutorial and guide | ✅ | |
| Settings and accessibility | ✅ | |
| Saving, backups, crash reports | ✅ | No save thumbnails |
| Massive world, streaming, horizon | ✅ | No far impostors for trees/towns; no off-screen simulation |
| Mounts, boats, fast travel | ❌ | |
| Multiplayer: movement, building, gathering, chat | ✅ | |
| Multiplayer: combat, monsters, bosses, dungeons | ❌ | Monsters pause while online |
| Server-side progression, accounts, encryption | ❌ | |
| Achievements (20) and Steam layer | 🟡 | Not tested on real Steam; no icons |
| Code signing, macOS build, installer | ❌ | |
| Main story, lore, class backstories | ✅ | Milestone 16 |
| Textures, authored models, skeletal animation | ❌ | Code-built by design |

---

## 7. To-do list

All open items from `docs/TODO.md`, plus problems found while writing this document (marked **NEW**).

### High priority — these hurt the game the most

1. **FIXED in Milestone 15 — The open world was almost empty of enemies.** Only the Thornback Boar spawns in the wild, and
   only in 4 of 11 surface biomes. Deserts, tundra, swamps, mountains, beaches, crystal glades and caves
   have no wild enemies at all. Every other monster only appears at a POI, in a dungeon, in a raid or in
   an event.
2. **NEW — Most of the world is end-game.** 83% of points of interest are rank S (rank S starts about
   6 km out, and the world is 13.8 km in each direction). There are only 18 E-rank and 40 D-rank POIs in
   the whole survey world, so new players can run out of fitting content fast.
3. **Combat does not work in multiplayer.** Monsters, raids and events pause while a session is online,
   and guests can't use chests, trade, farm, cook, sleep or enter dungeons. Co-op is "build together"
   only.
4. **No story, quests or goal.** No main quest, no multi-step quests, no dialogue choices; the name
   "Shardlands" is never explained.
5. **NEW — The Crafting 90 perk text promises "Masterwork" items, but item quality is not implemented.**
   Either build quality or change the text.
6. **FIXED in Milestone 15 — No respec.** A player who spends points badly can't fix it.
7. **Few class abilities.** Only three per class (levels 1, 5, 15); nothing new from level 15 to 100.
8. **No ranged weapons for the player.** Non-Wizards must always close the distance to archers and casters.

### Medium priority

9. Levels 75–100 rely only on S-rank content (about 550 minutes per level at 80); end-game content
   beyond S rank is needed.
10. Ability animations: all abilities reuse the generic swing/cast poses.
11. Legendary items have no unique effects (just bigger stats).
12. Gamepad menu navigation (the game plays with a pad, but menus need the mouse).
13. Multi-storey buildings, stairs and foundations on slopes.
14. Using materials from nearby chests when crafting and in build mode.
15. Crafting time / queues, forge fuel, station upgrades.
16. Server-side character progression, accounts, encryption, NAT traversal, server browser.
17. Real pathfinding (navmesh/A*); monsters can still get stuck in complex terrain. Line of sight for
    enemy perception.
18. Dungeon fog of war, keys and locked doors, puzzles beyond cracked walls.
19. Roaming world bosses, dungeon modifiers, party/co-op dungeons.
20. Farming: watering, seasons, animals/livestock; harvesting village crops.
21. Weather effects on crops and fires; rain making everyone wet.
22. Crime/theft, attacking NPCs, losing reputation, guards chasing the player.
23. NPC relationships, families, weekday schedules, reactions to weather and combat.
24. Roads between settlements and traders that really travel.
25. Mounts, boats or fast travel (streaming already handles 70 m/s).
26. Raids: raiders don't open/burn doors or climb walls; no raid difficulty setting; raids on structures
    outside a claim; active raids are not saved.
27. Few ring items and no mid/late hand items besides Iron Gauntlets (Milestone 14 added gauntlets, greaves and
    soft boots; rings are still thin).
27b. Face options, dyes and changing your body after creation (skin, hair and beard done in Milestone 14).
28. Tested release on real Steam, achievement icons, Steam Cloud test.
29. Code signing (Windows SmartScreen warning), macOS build, installer.
30. Languages other than English (text is in code, not extracted).
31. Settlement destruction / villagers dying (plunder is economic only); kingdom wars.

### Low priority

32. Known limitation: the bed mesh (1.9 m) can overlap the next cell's furniture.
33. Known limitation: entering a kingdom capital costs one ~40 ms frame.
34. Known limitation: NPCs don't collide with each other or the player.
35. Known limitation: the first chunk with a new scene type (cave entrance, POI) takes ~20 ms once.
36. Known limitation: dungeons are built in the sky with the surface paused; a short load when entering.
37. Known limitation: town raids only play out near you (otherwise the result is rolled).
38. Dropped loot and living enemies are not saved.
39. Swimming never drowns you.
40. Debug-spawned enemies (F8) never despawn.
41. The world map reveals everything (no fog of war).
42. Placed objects on the other layer stay in memory.
43. Buildings and construction sites live in `save.json`, not region files (fine until thousands of pieces).
44. Far-terrain impostors for trees, towns and POIs; off-screen simulation of settlements and farms.
45. Floating origin (only needed if the world grows past ±14 km).
46. Multi-storey tower interiors and climbing.
47. Mines (built mine structures in caves); underground water, lava and deeper cave levels; overhangs.
48. Hosting the web blueprint designer online with sharing; a 3D preview in the designer.
49. Built-in blueprint `.json` files need `*.json` in an export filter.
50. Spell upgrades and more spell combos.
51. Voice, more per-enemy sounds, layered music; a composer/sound pass.
52. Screen-reader support; captions for footsteps/ambience/music.
53. Save thumbnails.
54. GPU profiling on real hardware; frame budgets with rendering.
55. GDScript errors only appear in the log (they don't crash the game).
56. The Compatibility (OpenGL) renderer shows brighter colours.
57. NEW — Small naming mismatches: the Miasma spell's id is `poison_cloud`; the raid boss shows as
    "Bandit Warlord" but its lines and the docs call it "Grimtusk".

### Differences between the docs and the code

| Doc says | Code says |
|---|---|
| README: dungeon rank S "beyond ~3.5 km" | Rank step is 1.2 km since Milestone 12 (± one rank), so S starts at about 6 km. The 3.5 km figure is from the old 700 m step |
| TODO Phase 3: "Biome-specific enemies" marked done | Biome spawn lists contain only the boar, in 4 biomes. Other monsters are tied to POIs, dungeons, raids and events, not biomes |
| TODO M10 / README: icons for "135 items" | `data/items` has 139 items (all get icons; the number is just old) |
| TODO M4: "Recipes (43)" | 76 recipes today (more were added in later milestones; the M4 line is history) |
| Crafting 90 perk: "crafted gear can roll Masterwork" | `Skill.quality_chance()` exists but nothing uses it; crafted items are always normal |
| README Phase 1: "One biome: Verdant Meadows" | True for Phase 1; today players usually spawn in Whispering Forest (all 20 stress-test seeds) |

---

## 8. New ideas

Sizes: **S** = a day or two · **M** = about a week · **L** = several weeks. Every idea keeps the three
rules: Wizards stay physically weak, crafting never fails, temperature never kills.

### 1 — Textures (made by code, no image files)

- **1a. Procedural pixel textures on terrain (M).** Generate small 16×16 textures in code at start-up
  (grass speckles, sand ripples, stone cracks, snow sparkle) per biome, and use them in the terrain
  shader with world-space UVs. Keeps the voxel look but removes the flat-colour feeling up close.
- **1b. Wood grain and stone bricks on build pieces (S).** A small shader that draws plank lines on wood
  and brick lines on stone walls, based on world position.
- **1c. Wet and snowy surfaces (S).** Darker, shinier ground in rain; white tops on terrain and roofs in
  snow, fading in and out with the weather.
- **1d. Glowing rune patterns (S).** Animated emissive lines on temple floors, wizard towers, golems and
  boss arenas.
- **1e. Cloth patterns for people (S).** Stripes, checks and trims on shirts, capes and tabards per
  kingdom colour, so villages look less alike.
- **1f. Ore sparkle (S).** Small twinkling pixels on ore veins and crystals so they are easy to spot.

### 2 — Animations

- **2a. One pose set per ability (M).** Whirlwind spin with arms out, Shield Bash shove, Frost Nova
  ground slam, Shadow Step crouch-and-vanish, Battle Cry chest-out roar, Rallying Charge lean-in run.
- **2b. Two-handed and off-hand animations (M).** Both arms on axes and staffs, shield arm raised while
  blocking, dual-dagger strikes alternating hands for the Assassin.
- **2c. Hit reactions by direction (S).** Lean away from where the hit came; small knock-down on heavy
  hits.
- **2d. Work animations for NPCs (S).** Hammering at the forge, hoeing fields, sweeping, sitting on
  chairs, sleeping in beds.
- **2e. Monster-specific moves (M).** Skeletons rattle and reassemble, golems stomp with screen shake,
  wisps pulse before casting, crawlers rear up before a bite.
- **2f. Emotes (S).** Wave, sit, cheer, point — useful in co-op.
- **2g. Gathering animations (S).** Kneel to pick berries, swing a pickaxe overhead at ore, pull reeds.

### 3 — Enemies

- **3a. Wild spawns for every biome (M).** Use existing monsters and a few new ones so each biome has
  2–4 wild enemies: desert (scorpions, sand bandits), tundra (frost wolves), swamp (bog crawlers, will-o'-
  wisps), mountains (rock golems, mountain goats), beach (crabs), caves (cave bats, skeletons), crystal
  glade (crystal wisps). Mostly data work.
- **3b. Frost Wolf pack (S).** Fast pack hunters that howl to call others; weak to fire.
- **3c. Sand Scorpion (S).** Burrows under the sand, pops out with a poison sting; telegraphed by moving
  sand.
- **3d. Bandit camps (M).** Small camps in the open world with a chief, tents, loot chest and prisoners
  to free (reputation).
- **3e. Mimic chest (S).** A chest in dungeons that bites when opened; a fair "tell" like breathing.
- **3f. Swamp Hag (M, boss).** A new mini-boss in swamps that curses (weakness) and summons bog crawlers.
- **3g. Night-only creatures (M).** Shadow stalkers that only come out at night outside lit areas, which
  gives torches and campfires a second use.
- **3h. Peaceful animals (S).** Deer, rabbits, birds, fish: food and leather without combat, and life in
  the world.

### 4 — Backstories and world lore

- **4a. The Shattering (M).** Long ago a great star crystal broke over the land; its **shards** are why
  magic exists, why meteors still fall, and why the land is called the Shardlands. Crystal shards, void
  shards and star metal already fit this.
- **4b. The Ancients (S).** The people who built the temples and guardians to keep the shards safe. The
  Temple Guardians still follow their old orders; the "Blessing of the Ancients" is their gift.
- **4c. Class origins (S).** Barbarian: from the northern tundra clans who survived the Shattering's
  winter. Knight: sworn to a kingdom's ruler (ties to titles). Wizard: student of the tower order that
  studies shards (ties to wizard towers). Assassin: a former member of the bandit brotherhood (ties to
  raids and Grimtusk).
- **4d. Villain lore (S).** The Bone King was a ruler who used a shard to live forever; the Arcane
  Colossus is a shard-powered machine that went mad; the Elder Thornmaw grew from a shard that fell into
  the grotto; Grimtusk wants shards to rule the bandits.
- **4e. Readable lore books and notes (S).** Short pages found in ruins, towers and caches that tell this
  history, collected in a journal.
- **4f. Kingdom histories (S).** Each generated kingdom gets a founder, a symbol and an old rival
  kingdom, told by its ruler.

### 5 — Class abilities

New abilities at levels 25, 40 and 60, plus an upgrade choice for each old ability at level 30.

- **5a. Barbarian — Earthshatter (M).** Slam the ground: a line of rocks erupts forward and knocks enemies
  up. Costs Rage.
- **5b. Barbarian — Bloodlust (S).** Each kill in 10 s heals and adds attack speed.
- **5c. Knight — Shield Wall (S).** Raise the shield: block every frontal hit, allies behind you take less
  damage (good for co-op).
- **5d. Knight — Judgement (M).** A holy overhead strike that marks the target; marked enemies take more
  damage from everyone.
- **5e. Wizard — Arcane Orb (M).** A slow orb that pierces enemies and explodes. All magic damage — the
  Wizard stays physically weak.
- **5f. Wizard — Time Warp (M).** A circle that slows enemies and their projectiles for 5 s.
- **5g. Assassin — Smoke Bomb (S).** Blind enemies in an area (they lose you), drop threat.
- **5h. Assassin — Death Mark (M).** Mark a target; after 6 s it takes a share of all damage it took again.
- **5i. Ability upgrades (M).** At level 30, pick one of two upgrades per ability (e.g. Firebolt: "splits
  into 3" or "leaves burning ground").

### 6 — Shared spells (any class, from tomes)

- **6a. Stone Skin (S).** +armor for 10 s but slower movement.
- **6b. Chain Heal / Rejuvenate (S).** Heal over time for you and nearby allies (co-op).
- **6c. Gust (S).** Push enemies back and put out burning; combo: Gust into Miasma spreads the cloud.
- **6d. Summon Spirit Wolf (M).** A short-lived spirit ally that taunts enemies.
- **6e. Light (S).** A floating light that follows you in caves and at night (also keeps night-only
  creatures away).
- **6f. Frost Path (S).** Freeze water in front of you to walk over lakes and rivers.
- **6g. Recall (M).** Teleport home to your bed after a 5 s channel (a first fast-travel step).

### 7 — Attacks (for weapons and enemies)

- **7a. Charged heavy attack (S).** Hold the heavy button to charge for more damage and poise.
- **7b. Sprint attack (S).** A lunge when attacking out of a sprint.
- **7c. Plunging attack (S).** A strong hit when falling onto an enemy from a ledge.
- **7d. Riposte (S).** After a perfect parry, a special counter-attack for big damage.
- **7e. Shield throw (M).** Knight heavy attack variant: throw the shield, it bounces back.
- **7f. Enemy grab (M).** Brutes and bosses grab the player; mash to break free.
- **7g. Ground sweep for bosses (S).** A low spinning sweep you must dodge through.

### 8 — Items

- **8a. Item quality (M).** Fine / Masterwork crafted items with small bonus stats. Crafting still never
  fails: quality only ever adds, a "normal" item is the minimum.
- **8b. More gloves, boots and rings (S).** Partly done in Milestone 14 (Iron Gauntlets, Iron Greaves, Soft
  Leather Boots). Still open: Mithril Greaves, Ring of Embers, Ring of Swiftness, etc.
- **8c. Set bonuses (M).** Wearing 3 pieces of a set gives a bonus (e.g. Fur set: extra insulation).
- **8d. Legendary effects (M).** Each legendary gets one special power (Shadowfang: crits make you
  invisible for 1 s; Aegis of Dawn: parries heal).
- **8e. Trinkets / consumable tools (S).** Torch you can hold, fishing rod, grappling hook, smoke bombs,
  throwing knives.
- **8f. Respec potion (S).** "Draught of Forgetting" from the Alchemy Table resets your skill points.
- **8g. Food with buffs (S).** Fish stew (+stamina regen), spicy jerky (+warmth), honey bread (+XP).

### 9 — Weapons

- **9a. Bow (L).** A new ranged weapon type: hold to draw, release to shoot, arrows as ammo. Gives the
  player an answer to archers and fliers.
- **9b. Spear (M).** Long reach, thrust combo, a sweeping heavy; good for the Knight.
- **9c. War Hammer (M).** Slow, huge poise damage, stuns; for the Barbarian.
- **9d. Greatsword (M).** Two-handed, wide arcs, no shield.
- **9e. Wands and tomes as off-hand for casters (S).** Bonus spell power or a free extra spell slot; all
  magic damage.
- **9f. Weapon tiers to fill gaps (S).** Copper Axe, Copper/Iron Staff, a Very Rare and Magical tier for
  every weapon type (today there is only one Very Rare weapon).
- **9g. Elemental enchanting (M).** At the Arcane Altar, add fire/frost/lightning to a weapon (never
  fails, just costs materials).

### 10 — World life and the early game (weak area)

- **10a. Rebalance POI ranks near spawn (S).** Make the first 2–3 km hold many more E/D/C POIs, for
  example by a softer distance curve or more POIs per cell close to the centre.
- **10b. Rank "S+" and beyond (M).** Ranks S1–S5 for levels 60–100 with better loot, to fix the slow
  late game.
- **10c. Wild loot and treasure spots (S).** Buried chests, abandoned camps and shipwrecks on beaches.
- **10d. Fishing (M).** Rod, fish per biome, cooking recipes.
- **10e. Seasons (L).** A seasonal cycle that changes colours, crops and temperature (still never lethal).

### 11 — Story and quests (weak area)

- **11a. Quest system and journal (L).** Multi-step quests with goals, map markers and rewards.
- **11b. Main quest "The Lost Shards" (L).** Find shard fragments in temples, defeat the three dungeon
  bosses who hold great shards, then face a final boss.
- **11c. Kingdom quests (M).** Each ruler gives a short chain that ends in a title.
- **11d. Dialogue choices (M).** Simple choices that change reputation or rewards.
- **11e. Hero's chronicle (S).** The journal also logs your big moments (first boss, titles, raids won),
  so each world tells its own story.

### 12 — Building (weak area)

- **12a. Second storey and stairs (L).** Floors on walls, stairs pieces, ladders.
- **12b. Craft and build from nearby chests (S).** Already done for blueprints; reuse it for G and B.
- **12c. Decoration pieces (S).** Rugs, shelves, banners, plants in pots, lanterns.
- **12d. Workers (M).** Hire a villager to auto-build or tend farms.
- **12e. Stone and tile roofs, gates and wall corners (S).** More pieces for castles and stronger raid
  defense.

### 13 — Multiplayer (weak area)

- **13a. Shared combat (L).** Server-run monsters and damage; raids and events on in co-op.
- **13b. Party dungeons (L).** Enter a dungeon together; shared boss loot.
- **13c. Server-side progression (M).** XP and levels checked on the server.
- **13d. Guest access to chests, trading and farming (M).** Remove the "not for guests" messages one
  system at a time.
- **13e. Server browser / invite codes (M).** Join friends without typing IPs or forwarding ports.

### 14 — Travel (weak area)

- **14a. Horse (M).** A rideable mount bought in capitals.
- **14b. Rowing boat (M).** Cross lakes and the sea to islands.
- **14c. Waystones (S).** Activated stones at villages for fast travel between them.
- **14d. Roads (M).** Dirt roads between villages and capitals, with travelling traders walking them.
- **14e. Glider from high places (S).** Glide down from mountain tops; fits the big vertical world.

### 15 — Flow of battle (feel) — Milestone 18, see M18_PLAN.md

- **15a. Compact animation system (L).** Keyframe clips, three blended layers (legs, upper body, extras), body
  masks, cross-fades, events on exact frames and root motion.
- **15b. Locomotion blend (M).** Walk, run and sprint by speed with no foot sliding, leaning and turning in place.
- **15c. Snappy movement and dodge v2 (S).** Quick speed-up and stop, dodge that cancels attack recovery.
- **15d. Combo chains and finishers (M).** 3–4 different swings per weapon, hold to chain, aim assist.
- **15e. Hit-stop, hit reactions and knockdowns (M).** Freeze frames, directional flinch, knock-down and get-up.
- **15f. Crowds of fodder enemies (M).** Packs of weak enemies, topple deaths, loot bursts, AI level of detail.
- **15g. VFX library v2 (L).** Particles, trails, ground marks, lightning arcs, light flashes and one look per element.
- **15h. Smooth world (L).** Fade-in chunks and props, horizon impostors, smoother hills, blended biome
  borders, camera-first streaming.

---

## 9. Suggested next milestones

**Done: Milestone 14 — "Outfits".** Every class shares one body; gear decides looks, armour weight and small
skill bonuses; gear sets, full starting kits and a character creation screen with body options; classes keep
a small talent (Option A). It also covers part of idea 8b.

**Done: Milestone 15 — "Living Wilds".** Wild creatures in every land biome (frost wolf packs, sand
scorpions, crabs, deer, rabbits), wild treasure spots, more POIs near spawn, item quality, respec and new
gloves, boots and rings.

### Milestone 15 — "Living Wilds" (fill the world) — done
**Goal:** every biome has life and danger, and new players have enough level-fitting content.
**Ideas:** 3a (wild spawns for every biome), 3b, 3c, 3h (peaceful animals), 10a (POI ranks near spawn),
10c, 8f (respec), 8a (item quality, fixes the perk text), 8b.
**Why first:** this is the biggest hole in the game today — the world is beautiful but empty of
enemies, and most POIs are end-game. It is mostly data work on systems that already exist (monster
framework, spawn rules, POI ranks), so it is cheap and makes every other system more fun.

**Done: Milestone 17a — "Heroes' Arsenal" part 1.** Six new weapon types (bow, spear, war hammer, greatsword,
wand, tome), 20 new weapons, arrows, two-handed weapons, charged heavy / sprint / plunging attacks, ripostes,
and weapon and legendary powers (ideas 9a–9f, 7a–7d, part of 8d).

**Done: Milestone 17b — "Heroes' Arsenal" part 2.** The ability book (L): 60 new class abilities for levels 2–30
(ideas 5a–5h and the list in ARSENAL_PLAN.md), 15 passives, a 6-slot bar changed at a bed or a campfire, and a
third spell slot with a tome.

**Done: Milestone 17d — "Heroes' Arsenal" part 4.** 72 abilities for levels 66–100, the four ultimates and the
level-30 upgrades (5i). Every class now has 53 abilities. Next: Milestone 18 "Flow of Battle" (plan in M18_PLAN.md).

**Done: Milestone 17c — "Heroes' Arsenal" part 3.** 68 abilities for levels 32–64, the 20 shared spells
(ideas 6a–6g and more), ability poses, two-handed stances and bows in the left hand (ideas 2a–2b). Next: M17d,
abilities for levels 66–100, the ultimates and level-30 upgrades (5i).

**Done: Milestone 16 — "The Lost Shards".** Quest system and journal, the main quest, royal errands with
dialogue choices, 12 lore pages, kingdom histories, class backstories and the chronicle.

### Milestone 16 — "The Lost Shards" (story and quests) — done
**Goal:** give the player a reason to explore and a sense of a real place.
**Ideas:** 4a–4f (lore and backstories), 11a (quest system and journal), 11b (main quest), 11c, 11d.
**Why second:** once the world has life, a story can send players to places that are now worth visiting.
The quest system is also needed for later content (kingdom quests, events).

### Milestone 17 — "Heroes' Arsenal" (combat depth)
**Full list:** [ARSENAL_PLAN.md](ARSENAL_PLAN.md) — 50 new abilities per class, 20 weapons, 20 shared spells (plan only).
**Goal:** more ways to fight from level 15 to level 100.
**Ideas:** 5a–5i (new abilities and upgrades), 6a–6g (shared spells), 7a–7d (new attacks), 9a (bow),
9b–9d (spear, hammer, greatsword), 9f, 8d (legendary effects), 2a–2b (ability and two-handed animations).
**Why third:** new abilities and weapons are more valuable when there are more enemy types to use them
on (M15) and story goals to reach (M16). Animations come together with the moves they show.

### Milestone 18 — "Flow of Battle" (movement, animation, hack and slash, smoother worlds)
**Full plan:** [M18_PLAN.md](M18_PLAN.md).
**Goal:** the game should feel smooth and fun in the first 10 seconds: fast, fluid movement, readable and
punchy hack-and-slash combat (combo chains, hit-stop, crowds of enemies that fall over), animations that blend
instead of snapping, spell effects that look like magic, and a world that streams in without pops or seams.
**Ideas:** 2c and 2e (hit reactions, monster moves), 15a–15h (new, below).
**Why now:** after M17 the game has a huge amount of content, but it is all played through the same basic
movement and simple key poses. Making every step, swing and spell feel good multiplies the value of the 212
abilities, every weapon and every enemy. It is also needed before co-op: M19 syncs the final animation and combat
events once, instead of twice.

### Milestone 19 — "Together in Danger" (real co-op)
**Goal:** friends can fight, raid, and clear dungeons together.
**Ideas:** 13a, 13b, 13c, 5c (Shield Wall), 6b (group heal), 2f (emotes).
**Why fourth:** shared combat is a large networking job. It is better to do it after combat content has
grown (M17), so the sync work covers the final set of abilities, enemies and bosses at once.

### Milestone 20 — "World Polish" (look, feel and reach)
**Goal:** a richer look and a bigger audience.
**Ideas:** 1a–1f (code-made textures), 2f–2g (more animations; 2c–2e move to M18), 12a–12c (multi-storey building,
decorations), 14a–14c (horse, boat, waystones), gamepad menus, translations, Steam release checks.
**Why last:** visual polish and travel are best done when content is stable, and the release work
(Steam, gamepad menus, languages) should happen right before a 1.0 launch.
