# Changelog

All notable changes to this project. Format loosely follows *Keep a Changelog*.

## [0.23.0] — Milestone 18c: Flow of Battle - spells that look like magic, and Creative mode

### Added
- **VFX library v2** (`src/fx/fx.gd`, `FX`): soft glowing particles instead of cubes (GPU particles, with CPU
  particles on the compatibility renderer used by the browser build), **pooled** emitters, ground marks that
  fade, **branching lightning** that flickers, beams of light from the sky, swirls and short light flashes.
- **A look for every element**: fire (rising embers, scorch marks), frost (falling shards, cold mist, frost
  marks), lightning (forked bolts, sparks), arcane (swirling motes, turning runes on the ground), holy (beams
  from the sky, golden motes), poison (bubbles and a low cloud), shadow (smoke that pulls inward).
- **Every ability and spell** gets the new look at once, because the shared pieces were upgraded:
  - casting magic makes the hands **glow and gather** the element, with the element's sound;
  - projectiles leave a glowing **trail** and hit with their element's impact;
  - areas on the ground glow softly and send up motes;
  - bursts throw soft sparks and light; lightning-coloured bolts become real lightning, and golden bolts from the
    sky become beams of light;
  - frozen enemies are wrapped in an **ice shell** that shatters when they thaw.
- **Ultimates feel special**: a short slow-motion moment (only when playing alone), a screen flash, a big mark on
  the ground and a sound for each class.
- **Creative mode for testing** (the ` key, under Esc): you can't be hurt, health/mana/stamina/Rage/food stay
  full, every active ability and spell can be used for free with no cooldown. Tools: fast move, level 30/64/100,
  learn every spell, a test kit (one of each weapon type, 99 arrows, a tome), spawn a training dummy (50 000
  health, never fights back), a minion pack, an elite or a boss, clear enemies, day/night, reset cooldowns.
  Single player only; achievements are off for the rest of the session once it is used.
- Tests (written, not run yet): `test_m18c_fx`, `test_m18c_casting`, `test_m18c_creative`.

### Changed
- "Reduce flashing" also softens light flashes, lightning flicker and the ultimate's screen flash; "Reduce
  motion" turns the slow motion off; "Hit & dust particles" also turns the new particles off.

## [0.22.0] — Milestone 18b: Flow of Battle - hack and slash

### Added
- **Combo chains with finishers**: every melee weapon's light combo now ends in a strong **finisher** with a ring,
  a bigger shake and a longer hit-stop. Sword: slash, back-slash, thrust, then a spinning finisher. Axe: two chops
  and an overhead cleave. Dagger: four stabs and a lunge. War hammer: two smashes and a ground slam that stuns.
  Spear: two thrusts and a wide sweep. Halberd: a whirl. Greatsword: two arcs and a **leaping slam**. Staff: an
  arcane burst. Unarmed: two punches and a kick (`AttackData.finisher`, `knockdown`, `hitstop`).
- **Hold attack to keep attacking** (on by default): the chain keeps going while the button is held. It only
  follows a press that started in the game world, never a click on a menu.
- **Aim assist** (on by default): each swing turns to the nearest enemy in a 60° cone in front of you. Locking on
  or using a bow turns it off.
- **Hit-stop**: the swing and the enemies it hits freeze for 45–120 ms (longer for heavy, charged and finisher
  hits). Settings slider, 0 = off. It is local to the fight, so co-op players are not slowed.
- **Enemy reactions**: enemies flinch away from the side they were hit on (humanoids lean, beasts rock).
- **Knock-downs**: finishers and fully charged heavy attacks knock enemies down; they fall, lie on the ground and
  get up. Bosses only fall right after their guard (poise) breaks; stun-immune elites never fall.
- **Crowds**: three new weak pack enemies - **Skeleton Minions**, **Bandit Recruits** and **Cultist Acolytes** - in
  packs of 4–10 across 8 biomes. Big packs stand in two rings. Up to 60 enemies can be active (was 30).
- **Death puffs**: a fallen enemy goes up in a puff of dust.
- **Clear danger**: every heavy enemy attack shows the red ground warning that fills up before it hits.
- **Elites** are outlined in their affix colour and roar when they see you.
- Settings → Gameplay: Aim assist, Hold attack to keep attacking, Hit-stop.
- Tests (written, not run yet): `test_m18b_data`, `test_m18b_combat`.

### Changed
- Enemies far from every player (over 42 m) and not fighting think only every 4th frame (AI level of detail).
- Older tests now expect the longer combos (sword 4, staff 3, dagger 5 attacks).

## [0.21.0] — Milestone 18a: Flow of Battle - animation system and smooth movement

### Added
- **A compact animation system** (`src/anim/`): `AnimClip` (keyframe tracks for every body part, eases including
  a small overshoot, events on exact times) and `AnimLibrary` (attacks, ability poses, spells, the dodge, hit
  flinches and landings built as clips).
  - `HumanoidModel` now mixes **three layers** every frame: the body on its own (idle, walk, run, air, swim,
    block, weapon stance), the **action** clip on top, and small **additive** clips (flinch, landing).
  - **Cross-fades**: a new move starts from the pose the body shows, and a stopped move fades back. Nothing
    snaps any more.
  - **Body mask**: while you run, an attack or spell only moves the upper body and the legs keep running;
    standing still, attacks use a lunge stance with a small step and dip.
  - Attacks have a wind-up, a strike that overshoots a little and a recovery; the free arm swings for balance.
    The 17 ability poses became clips with an anticipation, a hold and a release; kneeling and crouching poses
    bend the legs. The dodge tucks the body into a ball.
  - Clip events (`clip_event`: "hit", "trail_on", "trail_off", "release", "peak").
  - Everyone that uses the hero body gets it: the player, NPCs, humanoid monsters and co-op players.
- **Smooth locomotion**: the legs swing further and faster with the real speed, and one step covers the
  distance moved, so feet don't slide. The body leans forward when speeding up, back when stopping, and into
  turns; turning on the spot shuffles the feet. Stepping up a block glides instead of popping.
- **Movement feel** setting (Gameplay): *Snappy* (new default, about twice as quick to start, stop and turn) or
  *Weighty* (the old feel).
- **Dodge v2**: a roll can cancel any part of an attack's recovery, works with at least half the stamina it
  costs, and ends in a short slide.
- **Camera**: looks a little ahead in the direction you walk, shakes with a smooth wobble instead of random
  jumps, and a new **fixed isometric camera** option (Gameplay) locks the classic action-RPG angle.
- Tests (written, not run yet): `test_m18a_clips`, `test_m18a_model`, `test_m18a_movement`.

## [0.20.0] — Milestone 17d: Heroes' Arsenal - abilities 66-100, ultimates and upgrades

### Added
- **72 new class abilities for levels 66–100** (18 per class, 24 of them passives). Every class now has its full
  book of 53 abilities (levels 1–100):
  - Barbarian: Blood Price, Storm of Steel, Mountain's Endurance, Javelin Hurl, Battle Trance, Ancestral Spirits,
    Bloodthirst, Juggernaut, Wounding Strikes, Rend, Thunder Clap, Avatar of War, Last Stand, Earth Splitter, Rage
    Overflow, Warlord's Challenge, Fury of the Clans.
  - Knight: Lance Charge, Sanctuary, Spreading Light, Vengeance, Heavenly Ward, Righteous Fury, Royal Guard,
    Cleansing Light, Iron Will, Pillar of Light, Knight's Resolve, Guardian Angel, Phalanx, Martyr, Judgement
    Day, Champion's Presence, Wings of Light.
  - Wizard: Gravity Well, Elemental Dance, Chain Frost, Arcane Beam, Living Bomb, Counterspell, Permafrost, Summon
    Elemental, Arcane Mastery, Sunfire, Time Stop, Clearcasting, Black Hole, Steam Blast, Mana Overflow, Starfall,
    Ascension.
  - Assassin: Hunter's Net, Lethality, Vendetta, Shadow Realm, Venom Arrow, Swift Death, Blade Dance, Phantom
    Blades, Cold Blood, Rain of Arrows, Deadly Precision, Umbral Leap, Living Shadow, Neurotoxin, Ghost, Thousand
    Cuts, Eclipse.
- **Four ultimates at level 100** (5-minute cooldown): Wrath of the Ancients (Barbarian), Paladin's Oath (Knight),
  Shard Nova (Wizard) and Night's Embrace (Assassin). They show in gold in the ability book.
- **Ability upgrades from level 30** (idea 5i): every active ability can get one of two upgrades, chosen in the
  ability book (L) at a bed or a campfire, saved with the character (`AbilityUpgrades`).
  - The 12 starting abilities have special upgrades, e.g. Firebolt: *Split Bolt* (3 bolts) or *Burning Ground*;
    Chain Lightning: *Forked* or *Overcharge*; Vanish: *Deep Shadows* or *Smoke Escape*.
  - Every other active ability: *Empowered* (+30% damage, +25% duration, +15% area) or *Swift* (-30% cooldown,
    -25% cost).
- **New summons**: ghost warriors, a spirit knight, an elemental beast and your living shadow fight for you.
- **New poses**: beam, wings, summon and ultimate (17 in total).
- Tests: `test_m17d_data`, `test_m17d_abilities`, `test_m17d_upgrades`, `test_m17d_passives`.

### Changed
- Rage can go up to 150 (Rage Overflow); the HUD bar follows it.
- Armour from abilities (Royal Guard, Juggernaut, Paladin's Oath); critical damage from Lethality.
- Areas that follow a summon end when the summon is gone; areas that follow an enemy stay where it died.

### Fixed
- Explosive Trap never exploded (the trap could not find itself).
- Comet Shower could miss a single enemy completely: the first comet now always lands on the aimed spot.

## [0.19.0] — Milestone 17c: Heroes' Arsenal - abilities 32-64, shared spells and animations

### Added
- **68 new class abilities for levels 32–64** (17 per class, 20 of them passives), from the ability plan: e.g.
  Avalanche, Execute, Earthquake, Undying Rage and Crushing Blow (Barbarian); Smite, Banner of the Realm, Divine
  Shield, Hold the Line and Aegis (Knight); Flame Pillar, Comet Shower, Lightning Rod, Absolute Zero, Mirror
  Image and Fire Tornado (Wizard); Shadow Dance, Explosive Trap, Assassinate, Blade Chain and Sniper Shot
  (Assassin). Every class now has 35 abilities (levels 1–64).
- **20 shared spells** any class can learn from tomes: Light, Haste, Gust, Root Snare, Stone Skin, Rejuvenate,
  Feather Fall, Frost Path, Earth Spike, Spark Shield, Detect Treasure, Tame Beast, Summon Spirit Wolf, Fire
  Ring, Lightning Dash, Drain Life, Earth Wall, Silence, Recall and Shardfall. Their tomes are sold in villages,
  found in towers, temples, ruins, camps, shipwrecks, caches and dungeons, given by royal errands (Earth Wall)
  and the main quest (Recall, when the Shard Keepers fall), and dropped by the Starborn Colossus (Shardfall).
- **Animations**: 13 body poses for abilities and spells (roar, pray, cast up, push, stomp, crouch, channel,
  guard, throw, kneel, leap, flex, point), sent to other players in co-op; **both hands** on greatswords and
  war hammers (ready stance, swings, guard); **bows held in the left hand** with the right hand drawing the string.
- **Tamed beasts and pets**: Tame Beast and the Spirit Wolf fight the enemies near you.
- Tests: `test_m17c_data`, `test_m17c_spells`, `test_m17c_passives_and_poses`; screenshot runner `--only=poses`.

### Changed
- Spells and mana abilities can echo (Arcane Echo), overload (Overload) and have shorter cooldowns (Discipline,
  Quick Cast). Chests are in a `loot_chests` group (Detect Treasure).

## [0.18.0] — Milestone 17b: Heroes' Arsenal - the ability book

### Added
- **Ability book (L)** with two pages: Abilities and Spells. Every class learns a **new ability every two levels**
  (levels 2–30 in this milestone): 15 new abilities per class, 60 in total (`AbilityBook`, `data/abilities/<class>/`).
  - Barbarian: Cleave, Thick Skin, Rage Fuel, Leap Slam, Ground Stomp, Intimidating Shout, Hamstring, Reckless
    Swing, Earthshatter, Bloodlust, Savage Throw, Skull Crack, Blood Frenzy, Unstoppable, Second Wind.
  - Knight: Shield Wall, Steadfast, Lunge, Judgement, Taunting Shout, Shield Throw, Heavy Armour Training,
    Riposte Master, Holy Light, Spear Wall, Valor, Consecrate, Pommel Strike, Bulwark, Charge of the Order.
  - Wizard: Arcane Orb, Mana Flow, Flame Wave, Ice Lance, Time Warp, Spark, Fire Wall, Frost Armour, Mana Shield,
    Static Field, Elemental Focus, Polymorph, Ice Wall, Ignite, Ball Lightning.
  - Assassin: Smoke Bomb, Light Feet, Death Mark, Throwing Knives, Backstab Mastery, Garrote, Caltrops, Evasion,
    Venom Mastery, Fan of Knives, Opportunist, Grappling Hook, Blind Powder, Shadow Clone, Twin Fangs.
- **Passive abilities** (15) that are always on: more health, block, parry window, mana regeneration, backstab
  damage, elemental damage, longer burns, more poison stacks, cheaper dodges and blocks, and more.
- **A 6-slot ability bar** on Z, X, C, T, V and U. New abilities fill empty slots by themselves; to change the bar,
  rest next to a **bed or a campfire**. The bar is saved with your character.
- **Third spell slot (N)** while a tome with a spell slot (the Tome of Embers) is in your off hand.
- Ground areas for abilities (`AbilityZone`), marks (Judgement, Death Mark), a Shadow Clone decoy that draws
  monsters, blinding (monsters lose you), an Ice Wall that blocks the way.
- Level-up messages name every ability you learned.
- Tests: `test_m17b_data`, `test_m17b_book`, `test_m17b_abilities` (every new ability fires and has an effect).
  Screenshot runner `--only=book`.

### Changed
- **Keys:** abilities 5 and 6 are V and U, spell 3 is N; *camera recenter* moved from V to Home and the
  *Blueprints* screen from N to P. (U still repairs in build mode.)
- The Temperature Shield is a normal ability on the bar (T by default) and can be moved.
- Barbarian abilities that cost Rage now take their Rage when used.
- The Spellbook is now the Spells page of the ability book.

## [0.17.1] — The character faces the mouse

### Changed
- The character now always faces the mouse: also while sprinting, during attack wind-ups, while drawing a bow
  and while charging a heavy attack (the attack goes where the mouse is when it lands). Turning is faster.
  New setting: *Character always faces the mouse* (on by default; gamepads still face the stick).

## [0.17.0] — Milestone 17a: Heroes' Arsenal (weapons and new attacks)

### Added
- **Six new weapon types**: bows (hold attack to draw, release to shoot; a full draw hits hardest, a quick
  tap shoots at once), spears (long reach), war hammers (slow, big poise damage, stuns), greatswords (wide
  swings), and wands and tomes for the off hand (spell power and mana for casters).
- **20 new weapons**: Wooden Shortbow, Copper Staff, Ash Spear, Apprentice's Wand, Copper War Axe, Stone Maul,
  Iron Staff, Recurve Bow, Iron Pike, Iron Warhammer, Iron Greatsword, Tome of Embers, Mithril Staff, Mithril
  Longbow, Mithril Halberd, Frostbite Warhammer, Stormcaller Wand, Greatsword of the Fallen King, and the
  legendary **Starfall Bow** and **Shardbreaker**. Each has a recipe, a shop, chest loot or a boss drop.
- **Arrows** (wooden, copper, fire, iron, mithril), crafted 5–10 at a time at a workbench; a bow always uses
  the best arrows in your bag; fire arrows set enemies on fire. The HUD shows your arrows while you hold a bow.
- **Two-handed weapons**: bows, greatswords and war hammers take off your shield (it goes back into your bag);
  equipping a shield, wand or tome takes off a two-handed weapon.
- **New attacks**: charged heavy attack (hold heavy: up to +75% damage and double poise), sprint attack (a
  long lunge out of a sprint), plunging attack (attack while falling; the slam grows with the fall) and
  riposte (attack right after a perfect parry: x2.5 and always a critical hit).
- **Weapon powers** (`ItemData.weapon_params`): stun on the last combo hit, ward breaking, chill on hit,
  extra Chain Lightning jumps, healing from undead, falling stars, ground shockwaves. The old legendaries got
  powers too: Sunforged Blade burns, Starfall Blade calls stars, Shadowfang's crits poison, Titan's Greataxe
  heals on kills, the Staff of the Archmage adds a Chain Lightning jump.
- **Weaponsmith's Folio** (iron weapons and arrows) and **Master Weaponsmith's Folio** (mithril weapons and
  arrows); the Arcane Codex also teaches the Tome of Embers.
- Every class has a talent for the new weapons (Assassins shoot best, Barbarians love hammers, Knights love
  spears and greatswords).
- New poses: a spinning sweep, aiming a bow and a plunge; drawings for greatswords, the player's war hammer,
  wands and tomes; pixel icons for bows, arrows, spears, hammers, greatswords and wands.
- Co-op: guests use up arrows through the host (`ammo` request).
- Tests: `test_m17a_data`, `test_m17a_combat`.

### Changed
- The guide's Combat page explains the new attacks and weapons.
- Shield Bash only counts real shields (a wand or tome is not a shield).

## [0.16.0] — Milestone 16: The Lost Shards

### Added
- **Quest system** (`QuestLog`, `QuestBook`): multi-step quests with goals (talk, collect, defeat bosses,
  use an altar, deliver, hunt, clear a dungeon, report back), rewards (XP, coins, items, titles) and saving.
- **Main quest "The Lost Shards"** (starts in every world): ask villagers about the falling stars, recover
  three Shard Fragments from the chests of ruins, towers and temples, defeat the three Shard Keepers (the Bone
  King, the Arcane Colossus and the Elder Thornmaw) for their Great Shards, join the shards on an Arcane
  Altar, and defeat the Starborn Colossus that answers. Reward: the title **Shardbearer**, the Shardheart
  Amulet, XP and coins, and an ending page.
- **Royal errands** (one per kingdom): the ruler asks for goods, a hunt and a cleared dungeon, then knights
  you (Knight of <kingdom>).
- **Dialogue choices**: answers in quest conversations; asking a ruler for half the gold up front gives coins
  now but costs reputation and half the final reward.
- **Lore** (`LoreBook`): 12 pages of history - the Shattering, the Ancients, the guardians, the tower order,
  the Great Shards, every Shard Keeper, the Starborn, the bandit brotherhood, the tundra clans, the first
  kingdoms. Found in POI chests and buried caches, from facing bosses, and every kingdom's ruler tells its
  history (founder, banner, old rival).
- **Class backstories** for the Knight, Barbarian, Assassin and Wizard (intro page, class picker tooltip,
  journal).
- **Chronicle**: your big moments with the day they happened - first visits, bosses, cleared dungeons,
  raids repelled, titles, level milestones, quests.
- **Journal (O)** with Quests, Lore, Chronicle and Your story tabs; a **quest tracker** on the HUD that says
  how far and in which direction the next goal is; **story pages** for the intro and the ending.
- The Arcane Altar can be used (interact) for the main quest.
- Tests: `test_m16_data`, `test_m16_story`. Screenshot runner `--only=story`.

### Changed
- Kingdom recognition announces titles to the chronicle (`Events.title_granted`).

## [0.15.0] — Milestone 15: Living Wilds

### Added
- **Wild life in every land biome** (`WildSpawns`): 2–4 wild creatures per biome on top of the boar - deer
  and rabbits in meadows and forests, thorn crawlers and cultists in the jungle, crawlers, will-o'-wisps
  and skeletons in the swamp, crabs and bandits on beaches, scorpions and sand bandits in the desert,
  frost wolves in the tundra, taiga and mountains, wisps and sentinels in crystal glades. Spawn rules can
  place groups (packs and herds). Monsters still get tougher with distance from spawn.
- **Frost Wolf**: fast pack hunter; when one spots you it howls and the whole pack comes. Bites chill;
  weak to fire.
- **Sand Scorpion**: waits buried in the sand (only a little moving sand gives it away) and bursts out
  when you step close; poison sting; armoured, weak to frost.
- **Shore Crab**: armoured beach critter, weak to lightning.
- **Peaceful animals**: Deer and Rabbits run away from you and never fight. Hunting them gives raw meat
  and the new **Wild Hide** (2 hides = 1 leather at the tailoring table).
- New beast models: wolf, deer, rabbit (four-legged gallop, grazing nod), scorpion (curled tail, sting
  strike) and crab; a howl animation.
- **Wild treasure** (`TreasureSpots`): abandoned camps (tent, cold fire pit), shipwrecks on beaches and
  buried caches (mound with a cross of sticks), each with a chest that opens once per world; three new
  loot tables. About one spot every 80 chunks.
- **More points of interest near spawn**: up to 92% of the cells within 3 km now hold a ruin, tower,
  temple, dungeon or grove (60% before), so the early game has many more E/D/C places. Only adds POIs:
  older worlds keep the ones they had.
- **Item quality**: crafted gear can come out **Fine** (+10% stats, +2 weapon damage) or **Masterwork**
  (+20%, +4 weapon damage, +1 to every skill bonus) - chance grows with Crafting from 20; Masterwork from
  Crafting 90 (the Grandmaster perk). Crafting still never fails. Quality items are ids like
  `iron_sword@fine`, so they save, trade and sync like any item.
- **Draught of Forgetting** (alchemy table, found by picking up a dreamcap): resets your skills and gives
  every point back.
- **New gear**: Mithril Gauntlets, Mithril Greaves, Wanderer's Boots, Ring of Embers, Ring of Swiftness.
- Tests: `test_m15_data`, `test_m15_wilds_ingame`. Screenshot runner `--only=wilds`.

### Changed
- Up to 30 wild enemies at once (was 24).
- The inventory's use button says "Use" for non-food items such as the Draught of Forgetting.

## [0.14.0] — Milestone 14: Outfits & Gear Makes the Hero

Two sessions built this milestone in parallel; this release combines both.

### Added
- **One body for every class.** All player characters share the same blocky body; what you wear decides how
  you look. Head, chest, hands, feet, off-hand and amulet items each have a look (27 looks: helms, hoods,
  hats, robes, vests, chainmail, plate, cloaks, fur mantle, gloves, gauntlets, bracers, wraps, boots,
  greaves, three shield styles, pendants), coloured by the item.
- **Choose your body** (`CharacterLook`): skin tone (6), hair colour (8), hair style (short, long, topknot,
  bald) and beard, picked at character creation and saved; helmets and hoods hide the hair, masks the beard.
- **Character creation screen** (`ClassPicker`), souls-like: a turning 3D preview in the class's starting
  kit, skill bars with gear bonuses, health/mana/armour, the class talent and abilities, kit and supplies,
  and the body options.
- **Armour weight** (`ItemData.armor_weight`): Light, Medium or Heavy. Each light piece makes enemies notice
  you 6% later and a dodge 4% cheaper; each heavy piece makes them notice you 8% sooner and a dodge 6%
  dearer (notice range ×0.6–×1.5, dodge cost ×0.7–×1.5). Only idle or wandering enemies use the notice range.
- **Gear sets** (`GearSets`) with 2- and 4-piece bonuses: Squire's Kit (Knight), Raider's Furs (Barbarian),
  Shadowstalker's Garb (Assassin), Apprentice's Vestments (Wizard). New gear stats: physical damage %,
  backstab damage %, parry window. Set lines in tooltips.
- **Full starting kits**: every class starts with a weapon, its complete 4-piece set and its own supplies
  (Knight: bandages, bread; Barbarian: cooked meat, a warming draught; Assassin: antidotes, a healing draught;
  Wizard: mana tonics).
- **+1 / +2 skill bonuses** on everyday gear and set pieces.
- **New armour**: Squire's Helm / Breastplate / Gauntlets / Greaves, Horned Helm, Raider's Fur Harness /
  Bracers / Fur Boots, Shadow Hood, Shadowstalker's Garb / Wraps / Soft Boots, Wizard's Hat, Apprentice's
  Wraps / Shoes, Iron Great Helm, Iron Gauntlets, Iron Greaves, Soft Leather Boots. Set pieces have starting
  recipes (any class can craft any set), are sold in villages and drop in E-rank loot.
- Character screen line: outfit style, notice range and dodge cost. Item tooltips show weight and set.
- Multiplayer: other players see your outfit and body; players who join later get everyone's current look
  (this also fixed late joiners not seeing other players' weapons).
- Tests: `test_m14_outfit_data`, `test_m14_outfits_ingame`, `test_m14_gear_data`, `test_m14_gear_in_game`,
  `test_m14_character_creation`. The test runner takes `-- --only=<name part>`. Screenshot runner
  `--only=outfits` and `--only=gear`.

### Changed
- **Classes (Option A)**: the class is its starting kit plus a small talent (its best skill grows more
  effective, class power, best weapon, its abilities). Off-class weapons are ×0.85–0.95 (were down to ×0.5),
  weak skills are 0.75–0.9 effective (were down to 0.35), Wizard physical power 0.88 (was 0.7), Knight and
  Barbarian spell power 0.75 / 0.7. **A Wizard never equals a Knight**: with 100 Strength in full iron with
  a sword a Wizard hits ×0.66 of a max-Strength Knight (tested, limit ×0.9).
- `ClassData` shirt/pants/hair colours no longer change the body (kept in the data for now).
- The main menu's create panel is wider to fit character creation.


## [0.13.0] — Milestone 13: Beta / Release preparation

### Added
- **Tutorial** (`Tutorial` autoload, `TutorialCard`): 16 contextual hints that appear when the situation
  comes up and clear when you do the thing, with the real key names for keyboard or gamepad; progress is
  kept per player profile. Settings → Gameplay turns them off or replays them.
- **Guide** (F1, `GuidePanel`): all controls with current bindings, and pages on survival, combat, the
  character, crafting and building, the world and saving.
- **Settings** (`SettingsPanel`, tabbed): difficulty (Story / Normal / Hard), autosave interval, damage
  numbers, camera rotation speed, frame-rate cap, FPS counter.
- **Controls**: rebinding of every gameplay action for keyboard/mouse and gamepad separately, conflict
  warnings, resets; default gamepad layout with stick aiming; toggle sprint.
- **Accessibility** (`AccessibilityLayer`): interface scale, colour-vision filters (protanopia,
  deuteranopia, tritanopia), high-contrast UI, directional sound captions, reduced flashing, reduced motion.
- **Save recovery**: checksummed save files, rotating world snapshots including region files, automatic
  fallback (save → previous save → newest good snapshot) with a notice, and a Recover screen with restore
  and undo.
- **Crash handling** (`CrashHandler`): unclean exits produce a crash report (session, system, log tail)
  and a main-menu notice; an engine crash writes an emergency snapshot.
- **Platform layer** (`Platform`, `SteamBackend`): 20 achievements and lifetime stats, an Achievements
  screen, rich presence and overlay pause; Steam through GodotSteam when installed; Steamworks config
  generated from game data (`tools/export_steam_config.gd`, `platform/steam/`).
- **Release tooling**: export presets (Windows, Linux, Web), `tools/build_release.sh`,
  `tools/fetch_export_templates.py`, browser build with launcher page, `docs/RELEASE.md`.
- Tests for all of it (rebinding, settings and accessibility, tutorial and guide, save recovery, crash
  reports, platform with a stand-in Steam, release config).

### Changed
- Browser builds stream in a single-threaded mode (one generation job per frame, no prefetch, smaller
  detail ring) instead of stalling.
- The UI theme is shared by all screens so the high-contrast setting updates them live.
- The corner cheat sheet is built from the current bindings and points to the guide.

### Fixed
- The first save of a new world could skip its backup snapshot.
- The base-raid test could fail when arrow towers killed a whole wave before it reached the walls.
- UI symbols (✕, arrows, stars, ⚠) showed as empty boxes where no system font has them (browsers):
  DejaVu Sans now ships as a fallback font (`assets/fonts/`, Bitstream Vera licence).
- Browser build: no errors from layout-aware key names or process ids (crash locks use a fixed name).

## [0.12.0] — Milestone 12: Alpha

### Added
- **Full gameplay loop bot** (`tests/playthrough.gd`, `tools/playthrough.tscn`, `test_m12_gameplay_loop`):
  a fresh character plays the core loop with the real systems — gather, stone tools, workbench, floors and
  walls, campfire, five fights, hunting and cooking, levelling and spending points, selling and buying in the
  nearest village, crafting and equipping a sword, clearing E-rank ruins and looting the chest. All four
  classes finish it (~11 simulated minutes).
- **Balance model and report** (`BalanceModel`, `tools/balance_report.tscn` → `docs/BALANCE.md`): class
  builds, best gear per level, time-to-kill/time-to-die against level-appropriate monsters, XP pacing,
  recipe values and shop arbitrage. `test_m12_balance` enforces the same numbers.
- **World-generation stress test and benchmarks** (`tests/stress.gd`, `tools/stress_test.tscn` →
  `docs/PERFORMANCE.md`, `test_m12_worldgen_stress`, `test_m12_performance`): 20 seeds checked for spawn,
  reachable towns and ruins, valid meshes (centre, far points, world edge, caves), determinism and dungeon
  layouts; frame-time budgets for idle, a 40-monster fight, a 300-piece base, particle storms and long
  teleports.
- Mid-tier weapons: Iron Dirk (Smithing Manual), Mithril Sword, Mithril Dirk, Mithril War Axe (discovered
  with mithril ingots; also in rank C-B loot).

### Changed
- **Classes**: Firebolt 24 damage / 9 mana (was 16 / 12); Wizard 72 base health (65), spell power ×1.45 (×1.3).
- **Gear tiers** now unlock at levels 1 / 5 / 15 / 22 / 30 / 38 / 48 (Legendary was 30), so every dungeon
  rank has gear to chase.
- **XP**: curve 100 + 30·n^1.5 + 0.05·n³ (~1 h to level 10, ~20 h to 50, ~400 h to 100); monsters give full
  XP within 5 levels of the player, then −5% per level down to 10%.
- **Dungeon ranks**: health ×1 / 1.6 / 2.6 / 4.2 / 6.5 / 10, damage ×1 → ×4.6, +0 → +54 levels, XP ×1 → ×12;
  POI rank steps every 1.2 km (was 700 m); wild monsters now scale with distance from spawn too.
- **Item values**: ingots, leather and rope are worth at least their materials; iron/copper/mithril gear
  and tools are worth more than their inputs; a few craft-and-sell exploits removed (Sun Hat, Copper Dagger,
  Leather Jerkin, rings, Cooling Salad). Regional "dear" prices ×1.3 (×1.35).
- Sun Hat recipe needs a rope.

### Fixed
- Monster crowds: enemies ran up to four physics queries per tick looking for stair steps whenever another
  character blocked them (40 monsters: 34 ms frames → 9 ms). They now only probe when last tick's movement
  hit terrain or a building.
- Projectiles from monsters and arrow towers that were destroyed mid-flight logged "Lambda capture was freed".
- A novice crafter needed two of every single ingredient (two raw meat for one cooked meal).

## [0.11.0] — Milestone 11: Multiplayer Foundation

### Added
- **Networking** (`Net` autoload, `NetServer`, `NetClient`, `NetProtocol`): ENet sessions for up to 8
  players; listen server (menu *Host*, `--host`) and dedicated headless server (`--server`); join from the
  menu or `--connect=IP[:port]`; protocol version and world checksum checks. See `docs/MULTIPLAYER.md`.
- **Player sync** (`RemotePlayer`): 20 Hz state, interpolation, replicated animations and weapon looks,
  nameplates, server speed checks and corrections, join/leave messages, chat (Enter), who's-online bar.
- **Authoritative inventories**: guests' inventories/equipment live on the server; harvesting, gathering,
  pickups, dropping, moving, using, equipping, crafting and placing objects are validated requests.
- **World & building sync**: prop removals, region snapshots, networked pickups and placed objects;
  building placement/removal/doors through the server with ownership.
- **Persistence**: guests' characters saved with the host's world (`net_players`) and restored on rejoin.
- Tests: protocol unit tests and a two-process host/guest session test, including a dedicated-server rejoin.

### Changed
- `Inventory.remote` (read-only mirror for guests), `Chunk.hide_prop/refresh_removed`,
  `RegionStore.export_region/import_region`, `HumanoidModel.anim_event`, `Pickup.net_id`,
  building entries carry an `owner`. Monsters, raids and rare events pause while a session is online.

## [0.10.0] — Milestone 10: Art & Polish

### Added
- **Audio** (`Audio` autoload, `tools/gen_audio.py`): 71 synthesized sound effects, 10 ambience loops and
  7 music tracks (all generated, no samples); Music/SFX/Ambience/UI buses; positional sound pool with pitch
  variation and rate limits; cave reverb; music director (menu, day, night, town, combat, dungeon, boss);
  ambience mixer; sounds for combat, footsteps (grass/stone/sand/snow/wood), harvesting, magic by element,
  eating/drinking, crafting, chests, raids, bosses, thunder and every UI button.
- **Sky & day/night**: sky shader (sun, moon with 8-day phases, stars, clouds), sun/moon arcs, dawn and dusk
  colours, moonlight by phase.
- **Weather** (`WeatherSystem`): clear, cloudy, rain, thunderstorms with lightning and thunder, snow, fog,
  sandstorms; deterministic per 5-minute spell, shaped by the local climate; particles with roof collision;
  dimmer light, fog, colder air, Wet status; F2 debug key.
- **Environmental effects** (`AmbientEffects`): fireflies, leaves, pollen, dust, crystal sparkles, swamp
  mist, drifting snow, cave motes; foliage wind-sway shader; animated water shader.
- **Animation**: knees/elbows, idle breathing and glances, run lean, jump/fall, landing squash, swimming,
  casting, death; boar and crawler idle/gait polish; footstep events.
- **VFX**: weapon trails (`WeaponTrail`), voxel debris/dust/sparks/splash/motes particles (`VFX`).
- **UI**: pixel-art item icons (`ItemIcons`), panel pop-in with sounds (`UIFx`), low-health vignette, weather
  and moon phase on the clock, settings screen (`SettingsPanel`, `Settings` autoload, `user://settings.cfg`).
- Terrain: baked per-corner ambient occlusion.
- Tests: audio coverage of every referenced sound, icons, weather rules, shaders and AO, settings,
  animation states, particles, weather/sky/ambient/music in the running game. Screenshot runner `--only=polish`.

### Changed
- Water and foliage use shaders (global shader parameters `wind_strength`, `wind_dir`, `rain_amount`).
- Surface fog is driven by weather; the sun light follows a real arc and is clamped above 18°.

## [0.9.0] — Milestone 9: Massive World

### Added
- **World bounds**: chunks −866..+866 on both axes = **3,003,289 chunks** (27.7 × 27.7 km).
  Continents sink into an edge ocean from 12.8 km; the player is kept inside ±13,856 m.
- **Horizon LOD** (`FarTerrain`): 64 m super-tiles with 8 m columns out to 512 m (terrain, water,
  ice and biome colours), sampled and meshed on workers, cached height grids, cut out under the
  chunk rings. Fog 150 → 470 m, camera far plane 640 m.
- **Streaming** (`ChunkManager`): worker count from the CPU, 4 ms/frame build budget, LRU
  chunk-data cache with a 48 MB budget, velocity tracking and prefetch of the rings around where
  the player is heading, queue biased towards the direction of travel.
- **Background generation**: settlements and POIs within 1.5 km of the predicted position are laid
  out on a worker (`TerrainGenerator.prewarm`).
- **Region files** (`RegionStore`): removed props and killed spawn slots are stored in ZSTD
  region files of 32 × 32 chunks under `user://worlds/<id>/regions/`, loaded lazily, flushed on
  save, evicted LRU. Save version 2; version 1 saves migrate on load.
- **World survey** (`tools/world_survey.tscn` → `docs/WORLD_SURVEY.md`): whole-world biome/height
  statistics, every settlement and POI, generation benchmark.
- Debug overlay (F3): cache, prefetch, speed, build time, far tiles, regions.
- Tests: large-world bounds and determinism, random world sampling, far tiles, region store,
  save/load with regions and migration, a fast 1.8 km journey with bounded memory.
  Screenshot runner `--only=massive`.

### Changed
- Terrain mesh building is ~30% faster (no temporary arrays, one colour per column).
- `generator_version` 3 (terrain differs only beyond 12.8 km, where the edge ocean begins).
- `GameState.removed_props` / `enemy_deaths` replaced by `GameState.regions`.
- `delete_world` also removes region folders.

## [0.8.0] — Milestone 8: Blueprint System

### Added
- **Blueprint format** (`Blueprint`): versioned JSON shared with the web designer; validation,
  quarter-turn rotation, bounds, build order, total cost, missing materials, required level, capture.
- **Blueprint library** (`BlueprintLibrary`): built-in designs in `data/blueprints/` (Starter Hut,
  Stone Cottage, Watch Post, Farmstead; generated by `tools/gen_blueprints.py`) and your own in
  `user://blueprints/`; save, import, export, delete.
- **Construction sites** (`ConstructionSite`, `BlueprintHologram`, `BlueprintManager`): holograms
  for unbuilt pieces; manual building with F; auto-build within 30 m using your bag and nearby
  chests; saved with the world.
- **Placement preview** (`BlueprintPlacer`): whole-design holograms at the cursor, R to rotate.
- **Blueprint screen** (`BlueprintPanel`, `BlueprintPreview`, key N).
- **Web blueprint designer** (`web/blueprint-designer/`, built by `tools/build_designer.py` from
  the game's data): grid editor with bill of materials, roof checks, undo/redo, examples, JSON
  import/export.
- Tests: 756 checks (+43). Screenshot runner `--only=blueprint`.

## [0.7.0] — Milestone 7: Advanced Gameplay

### Added
- **Status effects** (`StatusEffects`, now on the player too): bleed, shock, wet, weakened,
  slowed, silenced, regen and haste join burn, poison, chill, freeze, stun and taunt.
  Elemental interactions: Steam, Doused, Deep Freeze, Shatter, Conducted and Combustion.
  Water makes you wet. HUD status chips. Cures: bandages now stop bleeding; new antidote, purifying
  draught and Troll's Brew.
- **Advanced enemy AI**: attack tokens (`CombatDirector`, max 2 melee attackers, others circle),
  pack alerts, dodging, fleeing, separation, feeler-ray steering, ledge hops and detours,
  support casters (heal / ward / haste).
- **Elites** (`EliteAffixes`): 9 affixes, champions with 2, auras, name prefixes, elite loot.
- **Boss mechanics**: phases with transitions, arena hazards and new move lists; poise break;
  ward pylons (`WardPylon`); moves spikes, nova, beam, meteor rain, teleport, pull, roar, bomb
  (`GroundHazard` telegraphed area attacks). Phases for all four M6 bosses.
- **New monsters**: bandit cutthroat, archer, brute, hexer, bomber; **Grimtusk the Warlord**
  (raid boss), **Treasure Goblin**, **Starborn Colossus** (meteor world boss).
- **Advanced magic** (`SpellBook`, `SpellbookPanel`): 8 spells from tomes (Blink, Healing Light,
  Miasma, Arcane Barrier, Arcane Missiles, Blizzard, Meteor, Storm Call), 2 spell slots (Y/H),
  spellbook (L), Mana Control requirements; tomes in loot and at the Arcane Altar.
- **Raids** (`RaidManager`): base raids with warnings, waves, siege, spoils or plunder; town
  raids announced by riders; defend for reputation and coins, or towns may be plundered.
- **Building health**: hit points by material, damage overlay, destruction, repair (U / Shift+U).
  New pieces: Log Palisade, Reinforced Door, Arrow Tower, Alarm Bell.
- **Rare events** (`WorldEvents`, `MeteorCrater`): Blood Moon, Meteor Shower (star metal +
  Starborn Colossus), Aurora, Treasure Goblin, Eclipse; sky tint and eclipse darkness in
  `DayNightCycle`; saved.
- Star metal crafting (ingots, Starmetal Amulet, Starfall Blade, Tome: Meteor); Warlord's Cleaver.
- New physics layer `npc` (8). Debug keys F4 (raid) and F12 (next event).
- Tests: 713 checks (+151). Screenshot runner `--only=advanced`.

### Changed
- `Monster` AI rewritten around targets (player, townsfolk, buildings) and the new behaviours;
  dungeon elites now roll affixes instead of a flat buff.
- Enemies wait instead of falling when their terrain collision isn't loaded yet.
- Defense skill perk "Iron Skin" (30% shorter harmful effects) now works for the player.
- The boss bar closes when a boss is despawned/pooled.

## [0.6.0] — Milestone 6: Exploration

### Added
- **Points of interest** (`src/exploration`): `Exploration` places ruins, wizard towers, temples,
  dungeon entrances and hidden groves per 256 m cell (weighted by biome), clear of towns,
  on flattened ground; rank E→S grows with distance from the world centre. `PoiLayout` +
  `PoiSite` build them near the player; `ExplorationManager` handles discovery and saved state.
- **Ruins** with skeleton guardians, a chest and sometimes a hidden vault under a cracked floor.
- **Wizard towers** (3 storeys, door, roof hides inside) with a Tower Warden, wisps, a lectern
  tome and a chest.
- **Temples** with a dormant Temple Guardian boss, a sealed golden chest (guaranteed legendary
  recipe) and an altar blessing (+10% damage, −10% damage taken, 20 min, daily).
- **Hidden groves**: secret glades with an ancient tree, rune stones and regrowing magical plants.
- **Dungeons E→S** (`DungeonPlan`, `DungeonInstance`): procedural floors (1–3 by rank) of rooms
  and corridors built far above the world; themed monsters and elites, spike-trap rooms,
  treasure rooms, a secret room behind a cracked wall, stairs, and a boss arena whose gate
  seals until the boss dies; boss chest + exit portal; dungeons repopulate after 3 days;
  dungeon map; saving inside stores the entrance; dying carries you out.
- **Monsters** (`Monster`, `MonsterData`, `MonsterModel`, `BeastModel`): data-driven melee,
  ranged and caster AI; 7 monsters (skeleton warrior/archer, arcane sentinel/wisp, thorn
  crawler, grotto cultist, tower warden) and 4 **bosses** (Bone King, Arcane Colossus, Elder
  Thornmaw, Temple Guardian) with cleave, slam (ground danger zone), volley, charge, summon,
  enrage and a boss health bar. Per-instance rank scaling of health, damage, level and XP.
  Guards' kills still give no XP.
- **Player afflictions**: burning, poison (damage over time) and chill (slow) from monsters.
- **Rare resources**: mithril ore (high peaks, the Deeps; iron pickaxe) → ingots → tier-4 mithril
  tools; void shards, sunstones, thorn hearts and royal bone from bosses; monster materials.
- **Magical plants**: sunbloom, frost lotus, emberroot, dreamcap (biome props) and the starlight
  orchid (hidden groves only).
- **Alchemy Table** station and 7 potions/elixirs (heal, mana, warming, cooling, might,
  stoneskin, starlight) with timed buffs.
- **Legendary items** (7) and **Legendary Recipe** scrolls from temples, A/S bosses and far vaults.
- Map: dungeon/ruin/tower/temple markers (groves only once found); gossip about nearby places.
- Tests: 562 checks (+84). Screenshot runner `--only=explore`.

### Changed
- Version 0.6.0. Projectiles have a collision mask (enemy projectiles hit the player).
- `World` gains a dungeon mode (surface streaming paused). Save data: `world.exploration`.

## [0.5.0] — Milestone 5: Living world

### Added
- **Settlements** (`src/living/settlements.gd`): deterministic villages (one chance per 384 m
  region) and kingdom capitals (one per realm of 4x4 regions), on dry, fairly flat land.
  The terrain is flattened inside (36 m / 50 m radius, blended back to nature); wild props,
  cave entrances and monster spawns are kept out. Names from biome-flavoured syllables;
  villages belong to the nearest capital within 1.4 km and fly its banner colour.
- **Layouts** (`SettlementLayout`): lot grid (villages 5x5, capitals 7x7 of 10 m lots) with a
  plaza (well, stalls, notice board, benches, torches, banner), furnished houses with doors
  and roofs, a shop with a market stall, an open smithy with a working forge and workbench,
  fenced farms with crops, and for capitals a keep with throne and carpet, barracks,
  royal market stalls, stone houses and a perimeter wall with four gates and towers.
- **Sites** (`SettlementSite`): streamed in within 170 m; thousands of pieces merged into a few
  meshes on a worker thread (BlockMesh now supports a placement transform), shared collision
  boxes, interactive doors and stations, lights; roofs hide when you walk inside.
- **NPCs** (`NPC`): merchants, royal merchant, blacksmith/armorer, farmers, villagers, guards,
  the ruler and the travelling trader, with role outfits and tools. Hourly routines (work, lunch
  and evening at the plaza, sleep at home), walking on a street graph along lot boundaries,
  through doors and farm gates. Work animations. Guards attack monsters near the capital.
- **Dialogue** (F): greetings by role, hours and standing; "What's new?" gossip generated from
  the world (undiscovered villages are added to the map, caves, the capital, trader days,
  scarce goods, bounties); "Tell me about …"; guards; rulers grant **titles**.
- **Economy** (`Economy`): coins (copper/silver/gold; new characters get 40c), shop stock tables
  per role, reputation-gated items, regional supply & demand by biome, capital demand for gear,
  reputation discounts, market saturation per item, finite shop money, daily restock.
  Buying is always dearer than selling back. **Trade window**.
- **Travelling trader**: every third day 08:00–18:00 with a wagon and rotating exotic stock.
- **Reputation** (`Reputation`, J screen): per settlement, kingdoms get half of village gains;
  tiers Stranger/Acquainted/Friendly/Honored/Revered with 0–15 % better prices; earned by
  trading, requests and killing monsters near towns. Titles Friend/Knight/Champion of <kingdom>
  with coin gifts and the **Royal Signet** amulet.
- **Requests** (`Requests`): daily delivery requests and boar hunts on each notice board.
- **Farming** (`Farming`): wheat/carrot/pumpkin seeds, **Farm Plot** build piece, growth by world
  time in 4 visible stages, harvest with seeds back; Bread and Vegetable Stew recipes.
- World map shows discovered and heard-of settlements; HUD shows coins and the current town.
- Tests: 478 checks (+77). Screenshot runner `--only=town`.

### Changed
- Version 0.5.0. You can't build inside towns. Guard kills give no XP.
- Save data: `player.coins`, `player.reputation`, `world.living` (shops, requests); discovered
  settlements live in `GameState.discovered_places`.

## [0.4.0] — Milestone 4: Building & crafting

### Added
- **Crafting** (`src/crafting`): `RecipeData` (data/recipes, 43 recipes), `RecipeBook`
  (per character, saved), `Crafting` (checks + craft). Crafting **never fails**: the
  Crafting skill only changes the material cost (×1.59 at 1 → ×0.80 at 100, min 1 each)
  and gates recipe tiers (Common 10, Uncommon 25, Rare 45, Magical 70). Crafting XP.
- **Recipe learning**: starting recipes; discovery (first copper ore → copper recipes,
  boar hide → leather, boar tusk → tusk charm); recipe books (Smithing Manual,
  Leatherworker's Notes, Arcane Codex, Cook's Journal) used from the inventory.
- **Stations**: Workbench, Forge, Tailoring Table, Arcane Altar (buildable) and the
  Campfire (cooking). A station counts when you stand within 4 m.
- **Crafting screen (G)**: station tabs, nearby-station indicator, recipe list with locked
  recipes and how to unlock them, item stats, have/need at your skill, Craft / Craft ×5.
- **Tools**: stone, copper and iron hatchets & pickaxes (tiers 1–3). The best tool in your
  inventory is used automatically: each tier adds a hit of power; copper/coal veins need
  tier 1, iron tier 2, crystal tier 3 ("Too hard" otherwise). Trees/rocks work bare-handed.
- **New items** (22): plant fiber, rope, plank, leather, copper/iron ingots, arcane dust,
  6 tools, flint knife, copper sword, hearty stew, cooling salad, fiber bandage, 4 books.
  Every existing gear item is now craftable.
- **Gathering**: reeds and dead bushes give plant fiber; berry bushes and cacti sometimes do.
  **Forgotten Caches** in The Deeps hold recipe books and ores; boars may carry a Cook's Journal.
- **Grid building** (`src/building`): `BuildPieceData` (data/build_pieces, 22 pieces),
  `BuildingManager` (1 m grid, floor/object/roof slots + shared cell edges, placement
  rules, refunds, claims, shelter, save), `BuildPiece` (behaviours), `BuildMode` (B: ghost
  preview green/red with the reason, LMB place, RMB deconstruct, R rotate), build palette UI.
  Pieces: wood/stone floors and walls, door, window wall, fence, thatch/shingle roofs,
  table, chair, bed, storage chest, standing torch, 4 stations, spike barricade, spike trap,
  claim flag, claim totem. Collision layer `BUILDING` (7) blocks players, enemies and projectiles.
- **Placement rules**: one piece per slot, within 9 m, level requirements, not on yourself,
  not in water, not through trees/rocks/ores, roofs need a wall or roof next to them,
  materials. Deconstructing refunds 100 % on your land, 50 % elsewhere; full chests
  can't be removed. Items that don't fit in the inventory drop at your feet.
- **Doors** open/close (F); **chests** (16 slots) with a transfer window; **beds** set the
  respawn point and let you sleep until 07:00 at night when no monsters are within 20 m;
  **torches** light and warm (+6 °C up close); **spikes** hurt monsters (charging ×3 + stagger).
- **Land claims**: flag 8 m / totem 16 m, at most 5, no overlap; monsters never spawn on
  claimed land; HUD shows "Your land".
- **Shelter**: under a roof the air is pulled up to 10 °C toward the comfort band (never
  past it); HUD shows "Sheltered"; roofs near you hide while you are inside.
- Tests: 401 checks (+91), including a data-reachability check that every ingredient and
  build cost can be obtained in the world. Screenshot runner `--only=build`.

### Changed
- Version 0.4.0. Campfires are also the cooking crafting station.
- Chopping/mining speed depends on tools; copper/coal/iron/crystal veins require tools.
- Save data: `world.buildings` and `player.recipes` (older saves load with starting recipes).

## [0.3.0] — Milestone 3: RPG foundation

### Added
- **Four classes** (`data/classes/*.tres`, `ClassData`): Barbarian, Knight, Wizard, Assassin —
  exactly 50 starting skill points each, class base health/stamina/mana, per-skill
  efficiency (a max-Strength Wizard still hits softer than a starting Knight), weapon
  proficiencies, block/parry/backstab/crit passives, Barbarian Rage, starter gear,
  class look (horns & fur, helmet & plume, wizard hat & robe, hood & mask).
  Class is chosen when creating a world (menu) or with `-- --class=<id>`.
- **Levels 1–100 & XP** (`Progression`): curve 100 → ~368k XP per level (≈9.8M total),
  2 skill points per level (+1 every 5th), full heal on level-up, level-difference XP
  scaling. XP sources: kills, biome discovery, new caves, harvesting/gathering, cooking;
  boss/dungeon/quest/trading/farming hooks.
- **Five skills 1–100** (`Skill`): Strength, Mana Control, Defense, Crafting, Dexterity with
  continuous effects and 4–5 milestone perks each (all implemented in the formulas).
  Crafting already boosts harvest yield and cooking; material-cost, recipe-tier and
  quality formulas are ready for the crafting milestone.
- **Equipment** (`Equipment`, `ItemData` equip fields): 8 slots (main/off hand, head,
  chest, hands, feet, ring, amulet), stat bonuses (armor, damage, spell power, crit,
  speeds, max health/mana/stamina, regen, temperature protection, skill bonuses), level
  requirements, weapon movesets (sword, axe, dagger, staff, unarmed), shields.
  25 gear items; boars can drop gear.
- **Armor & damage pipeline**: armor → damage reduction (capped 75%), class/weapon/skill
  multipliers, crit chance/damage, backstab multiplier, poise and knockback scaling.
- **Mana** (`ManaComponent`) with Mana Control–based max/regen.
- **Class abilities** (`PlayerAbilities`, `AbilityData`), keys Z/X/C, unlocked at levels 1/5/15:
  Barbarian Whirlwind, Battle Cry, Berserk · Knight Shield Bash, Guardian Stance,
  Rallying Charge · Wizard Firebolt, Frost Nova, Chain Lightning · Assassin Shadow Step,
  Poison Blade, Vanish.
- **Magic Temperature Shield** (T) for every class: 10 minutes, mana cost per class
  (Wizard cheapest), requires Mana Control 2 above the class's starting value.
- **Status effects** (`StatusEffects`): burn, stacking poison, chilled, frozen, stunned;
  taunt; spell combos (Firebolt shatters frozen enemies ×2, lightning ×1.5 in water);
  stealth-aware enemy perception.
- Swept-sphere projectiles, code-built VFX (rings, bursts, lightning).
- UI: mana, XP (level) and Rage bars, ability bar with cooldowns/lock states, buff list,
  level-up banner, XP toasts, **character screen (K)** with skill allocation, effects,
  next perks, attributes and equipment slots. Class picker in the main menu; world list
  shows class and level.
- Saves: class, level, XP, skills, unspent points, equipment, mana, rage, active
  Temperature Shield.
- Debug: F10 gives a sample of all gear tiers, F11 grants one level of XP.
- Docs generated from code: `docs/XP_TABLE.md`, `docs/CLASSES_AND_SKILLS.md`
  (`tools/gen_rpg_tables.gd`).
- Tests: 308 checks (class data, XP curve, skill balance, equipment, every ability in the
  live game, RPG save/load).

### Changed
- `PlayerCombat` damage now flows through `CharacterStats` (class, skills, weapon,
  proficiency, buffs); attacks come from the equipped weapon's moveset.
- `Enemy.receive_hit()` returns damage dealt; enemies have `StatusEffects` and a level.

## [0.2.0] — Milestone 2: World generation

### Added
- **Continuous climate-driven terrain** (`TerrainGenerator` rewrite): continentalness,
  hills, ridged mountains (up to ~60 m), island noise, temperature & moisture fields,
  swamp flattening, desert dunes, lakes, and meandering domain-warped **rivers** that
  fade out in high mountains. Terrain shape never depends on the biome, so there are no seams.
- **11 surface biomes + 1 underground biome**, chosen data-driven from climate
  (`BiomeData.role`, temperature/moisture ranges): Deep Ocean, Sandy Beach, Stonecrown
  Mountains (snow-capped peaks), Crystal Glade (rare magical biome), Murk Swamp,
  Sunscorch Desert, Emerald Jungle, Snowy Tundra (frozen, walkable lakes), Frostpine
  Taiga, Whispering Forest, Verdant Meadows, and The Deeps (caves).
- `WorldGenSettings` resource (`data/worldgen/default_worldgen.tres`) holding every
  generation parameter and the biome list.
- **Caves**: a streamed underground layer (`TerrainGenerator.Layer.UNDERGROUND`) under the
  whole world — noise tunnels + caverns, rooms guaranteed under every entrance.
  Deterministic **cave entrances** on the surface and matching **rope-ladder exits**
  below (`CavePassage`), layer travel with loading screen, dark cave lighting, player
  lantern, steady 12 °C cave climate.
- **Procedural vegetation** per biome (22 new props): jungle, palm, snowy pine, swamp
  willow and dead trees, cacti, reeds, lily pads (float on water), giant toadstools,
  mushrooms, glowcaps, crystal clusters, moonpetals, frostberry bushes, snowy and
  sandstone rocks, stalagmites, clay deposits. Props can glow (`PropData.glow`).
- **Resource spawning**: copper, iron and coal veins (mountains, hills, caves),
  crystal clusters (Crystal Glade, caves), clay (rivers, swamps), rare magical plants
  (Moonpetal, Glowcap); all regrow after data-defined times.
- 11 new items: copper ore, iron ore, coal, crystal shard, clay, cactus fruit (cooling),
  coconut (cooling), brown mushroom, glowcap, frostberries, moonpetal.
- **Swimming** in deep water (buoyancy, slower, costs stamina, climb out onto banks).
- Per-position **climate temperature** (continuous, deserts swing hot/cold day-night,
  mountains cold by altitude), replacing per-biome constants.
- **World seeds & save system**: main menu (create world with name + seed or random,
  quick play, world list with play/delete, open saves folder), `SaveManager` autoload,
  JSON saves in `user://worlds/<id>/` (crash-safe temp file + `.bak` fallback, save
  version + migration hook), autosave every 2 min, F5 quick save, save on quit/menu.
  Saved: seed, world time, time of day, layer, player position/spawn/stats/buffs/inventory,
  world changes (both layers), killed spawn slots, discovered biomes, placed campfires.
  Command line: `-- --seed=<x>` (quick play) and `-- --world=<id>` (load).
- **World map** (M): rendered on a worker thread from the generator — biome colours,
  height shading, water, cave entrances; cave layout when underground.
- Biome name in the HUD, "Discovered: <biome>" toasts (persisted).
- Tests: terrain statistics, biome distribution, climate continuity, caves,
  swimming, layer travel, full save/load round trip incl. corrupt-save fallback (191 checks).

### Changed
- Removed-prop records are keyed by chunk **and layer**; enemy spawn slots use the
  biome at the chunk centre; props pick rules from the biome of their own column.
- `World.place_object()` returns the placed node (or null).
- Main scene is now the main menu (`scenes/menu/main_menu.tscn`).

## [0.1.0] — Phase 1: Playable prototype

### Added
- Godot 4.4 project with autoloads: `InputSetup` (code-defined input map), `Events`
  (signal bus), `GameState` (seed, world time, world modifications, serialization),
  `ItemDB` (data-driven item registry).
- Deterministic procedural terrain (`TerrainGenerator`): layered noise, block columns,
  lakes and hills, per-column colour variation, `--seed=` command-line option.
- Chunk streaming (`ChunkManager`, `Chunk`): worker-thread generation, main-thread apply
  budget, 3 LOD rings, edge skirts, chunk pooling, stale result discarding.
- Verdant Meadows biome with data-driven prop rules (oak, pine, boulder, berry bush,
  flowers, grass, stick piles, stone piles) rendered with MultiMesh.
- Harvesting (trees, rocks), gathering (bushes, loose items), persistent removal with
  regrow timers, loot pickups with magnet/auto-collect (pooled).
- Player: movement, sprint, step-up, wading, dodge roll with i-frames, block & parry,
  lock-on, interaction, hotbar use, drop, death & respawn.
- Combat: `AttackData` resources, 3-hit light combo, heavy attack, input buffering,
  cancel windows, crits, backstab bonus, knockback, poise & stagger, damage types.
- Enemy framework (`Enemy`, `EnemyData`, `LootEntry`, `EnemySpawner`) with pooling and
  deterministic per-chunk spawn slots that remember kills; Thornback Boar AI.
- Survival: `HealthComponent`, `StaminaComponent`, `HungerComponent`,
  `TemperatureComponent` (never damages), `StatBlock` modifier aggregation.
- Day/night cycle with temperature swing; campfire (heat, light, cooking).
- Tactical camera rig (rotate, tilt, zoom, pan, recenter, shake, near-camera tree fade).
- HUD (bars, temperature gauge + debuff list, hotbar, inventory window, target frame,
  prompts, toasts, clock, help, debug overlay, pause, death & loading screens).
- 10 items, 6 attacks, 1 enemy, 8 props, 1 biome as `.tres` data.
- Test suite (`tests/test_runner.tscn`, 111 checks) and screenshot runner.
