# Shardlands — handoff for a new chat

## The project
- **Shardlands** is a voxel open-world survival RPG built with **Godot 4.4.1** in GDScript.
- Repository: `jihad-g/My-game`. Branch: `claude/survival-rpg-foundation-tu1eqk`. All work is on this branch.
- Current version: **v0.38.0** (Milestone 30: storeys in `src/building/building_manager.gd`, stairs/ladders/foundations in `build_piece.gd`, multi-level pathfinding in `src/enemies/nav_grid.gd`). Before that, v0.37.0 (Milestone 29: travel - `src/travel/`: waystones, horses, boats; riding in `Player._physics_mounted`). Before that, v0.36.0 (Milestone 28: weather that matters and seasons; `src/world/seasons.gd`, `src/world/tree_fire.gd`, season colours in `assets/shaders/block_texture.gdshaderinc`). The Windows build is `releases/Shardlands-v0.38.0-windows.zip`. Earlier: M27 new mobs and gear (`src/enemies/beast_model.gd`), M26 Rich World textures, M25 monster pathfinding (`src/enemies/nav_grid.gd`).
- **The owner's current plan (asked on 2026-10-17):** build 10 milestones in a row, M28-M37, without waiting between them:
  M28 weather + seasons (done), M29 travel (waystones, horses, boats), M30 multi-storey building, M31 dungeons (fog of war,
  keys, levers, plates, hidden rooms), M32 monster animations, M33 more mobs from the sheets, M34 textures (sand, snow, ice,
  cave stone, stairs/paths, water ripples), M35 icons and item uses, M36 performance, M37 release polish. For each one:
  tests (new + related groups), docs, version bump, Windows build, commit, push, a screenshot and a short report.
- Test frames: `_frames(n)` waits physics ticks; use `_pframes(n)` when a check needs `_process` to have run (weather, HUD).
- Textures: edit `art/tools/texgen.py` / `texgen_extra.py`, then run `texgen.py`, `build_atlas.py`, `export_game.py` (needs `pip install numpy pillow`).
- The owner's reference sheets were used for M27 (our own designs in that style, never copies). More mobs from those sheets are listed as NOT IMPLEMENTED in TODO.
- Tests that boot a world must end with `world.queue_free()` and `await _frames(5)`, or the old hero stays in the "player" group and confuses later tests.
- The owner wants the art to look like Blockbench-style pixel art (16 px per metre, hand-placed pixels). `src/art/pixel_art.gd` does this; skeletons and the Tuskers use it. Next art steps: weapons/shields, other monsters, player classes, villagers. Use our own designs in that style, not pixel copies of other artists' models.
- The owner asked to do the 10 next steps one by one: 1 M18d (done), 2 M19 co-op combat (done), 3 monster pathfinding (done, M25), 4 weather + seasons, 5 waystones/horses/boats, 6 multi-storey building, 7 map fog of war + dungeon keys, 8 monster animations + capes/hair, 9 performance + testing pass, 10 release polish.
- Read next: `docs/TODO.md` (done and NOT IMPLEMENTED), `docs/CHANGELOG.md`, `docs/M18_PLAN.md` (current milestone) and `docs/ART_BIBLE.md` (art rules).
- Keys changed in v0.24.0: **Space = jump**, **Left Alt = dodge roll**.
- **Creative mode** for testing in the game: the ` key (under Esc), or tick "Creative world" when creating a world.
  Six tabs (Player, Items, Monsters, World, Dungeons, Debug). Debug → "Check the game" runs `SelfCheck`
  (`src/core/self_check.gd`): run it after adding items, recipes, monsters or loot to catch broken ids.

## How to work with the owner
- Act as a technical co-founder. Write complete, working code, and every milestone must run.
- Mark anything unfinished as **NOT IMPLEMENTED** in the docs.
- After each milestone, report what changed, how to run and test it, known limitations and the next step. Then wait for the owner to say "do it".
- Use **simple English**. English is not the owner's first language.
- **Never run any tests without the owner's permission.** Ask first. When allowed, only run the test groups that match what you changed (the whole suite is about 1,800 tests, 5+ minutes).
- After each milestone:
  - update `docs/TODO.md`, `docs/CHANGELOG.md`, `README.md`, `docs/GAME_DESIGN.md` and `docs/ARSENAL_PLAN.md`;
  - bump `config/version` in `project.godot` and the version check in `tests/test_runner.gd` (`test_m13_release`);
  - build Windows: `tools/build_release.sh windows`;
  - replace the zip in `releases/` (git rm the old one) and update `releases/README.md`;
  - commit and push.
- Game rules:
  - A Wizard is never as strong physically as a Knight or Barbarian. Classes keep a small talent (Option A).
  - Crafting never fails.
  - Temperature never kills.

## Git
- Commit: `git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit`.
- Push: `git push -u origin claude/survival-rpg-foundation-tu1eqk`. Fetch and fast-forward first, because other sessions push to this branch too.
- No pull requests unless asked. Never force-push.

## Commands
- Tests: `godot --headless --path . res://tests/test_runner.tscn -- --only=<part of a test name>`. For example `--only=m18c` or `--only=v026`.
- Known failure: `test_m9_streaming` (prefetch) fails on a 2-thread machine; it failed before v0.26 too.
- After adding a new `class_name`: `godot --headless --editor --quit --path .`
- Screenshots: `xvfb-run -a godot --path . --rendering-method gl_compatibility res://tests/screenshot_runner.tscn -- --only=<arsenal|book|poses|style|gear|story|...> --out=DIR`
- Docs: `godot --headless --path . res://tools/balance_report.tscn -- --out=docs/BALANCE.md` and `godot --headless --path . -s tools/gen_rpg_tables.gd`
- Art (Python, `art/tools/`): `texgen.py` and `texgen_extra.py` (block textures), `build_atlas.py`, `icongen.py` (item icons), `export_game.py` (copies them into the game).

## What is done (milestones 1–20 + art passes)
- **M1–M13:** world generation and streaming, survival, 4 classes and skills, crafting and building, villages and kingdoms with NPCs, shops and reputation, POIs and E–S dungeons, bosses, status effects, raids, blueprints, art and audio, co-op multiplayer (host plus guests), balance, tutorial, settings, save recovery, beta release.
- **M14 Outfits:** one shared body for every class; the look comes from gear; gear sets; a souls-like character creation screen.
- **M15 Living Wilds:** wild creatures in every biome, treasure spots, item quality, respec.
- **M16 The Lost Shards:** quests and journal (O), the main quest, royal errands, lore.
- **M17a weapons:**
  - bow, spear, war hammer, greatsword, wand and tome; 20 weapons and 5 kinds of arrows; two-handed weapons;
  - charged heavy, sprint, plunging attacks and riposte;
  - weapon and legendary powers in `ItemData.weapon_params`.
- **v0.17.1:** the character always faces the mouse (it can be turned off in Settings).
- **M17b ability book (L):**
  - `AbilityBook` with abilities in `data/abilities/<class>/`;
  - a 6-slot bar on Z X C T V U, changed only at a bed or campfire (`rest_spots` group);
  - passives through `PlayerAbilities.passive_power(effect)`;
  - a 3rd spell slot (N) with the Tome of Embers;
  - new keys: camera recenter moved to Home, blueprints moved to P.
- **M17c:**
  - abilities for levels 32–64, so each class has 35 abilities;
  - 20 shared spells in `data/spells/` with `tome_*` items and their sources;
  - animations: `HumanoidModel.play_pose` with 13 `POSES`, set by `AbilityData.animation`, replayed in co-op through the "pose" anim event;
  - two-handed stances and swings, and bows held in the left hand;
  - tamed beasts and pets (`Enemy.tame()`, `Monster._player()`), decoys, `AbilityZone` ground areas.

- **M17d:**
  - abilities for levels 66–100 and four level-100 ultimates (`AbilityData.ultimate`), so each class has 53;
  - ability upgrades from level 30 in `src/rpg/ability_upgrades.gd` (`PlayerAbilities.choose_upgrade`,
    `effective()`, `upgrade_tag()`), chosen in the book at a bed or campfire and saved;
  - summons tinted with `_tint`, 4 new poses (beam, wings, summon, ultimate), `AbilityZone.end_with_follow`.

- **M18a:**
  - animation clips in `src/anim/anim_clip.gd` and `src/anim/anim_library.gd`; `HumanoidModel` mixes base,
    action and additive layers (`play_clip`, `play_additive`, `clip_event`), with cross-fades and a leg mask;
  - `set_locomotion_speed`, `set_motion` (leans, turn shuffle), `add_step_offset` (block-step glide);
  - Settings `movement_feel` (Snappy/Weighty) and `fixed_camera`; camera lead; dodge v2 (`can_dodge_cancel`);
  - tests `test_m18a_*` (run and pass since v0.23.1).

- **M23 Elemental Armour:** sets in `GearSets` (`ELEMENTAL`, `ELEMENTS`), items `data/items/<set>_*.tres`, recipes,
  codex `elemental_codex`; stats `<element>_resist`, `all_resist`, `<element>_damage` used by
  `CharacterStats.element_taken_mult` (Player.receive_hit) and `element_damage_mult` (Enemy.receive_hit);
  `LootTables` "elemental" chance; looks in `HumanoidModel._build_outfit_piece`; `_part(..., glow)`.
  `PixelAuto.mesh` is mutex-locked (towns build people on worker threads).

- **M21 Pixel World:** `PixelAuto.mesh(size, color, glow)` paints every `_part` box (HumanoidModel, BeastModel,
  BoarModel) on shared atlas pages; `PixelAuto.enabled` switches back to flat boxes; `kind_for` picks metal/wood/cloth.
- **M22 Deeper Dungeons:** `World.gather_dungeon_loot()`, `DungeonInstance.floor_cleared` + `_on_floor_cleared()`
  (Delver's Cache, table `dungeon_cache`), first clear (`exploration.is_first_clear`, state `first_clear:<id>`),
  `LootTables.GEAR_BAND` and per-table `quality` chances, item `delvers_mark`; `tests/dungeon_audit.gd`.

- **M20 The Tuskers:**
  - `PixelArt` (`src/art/pixel_art.gd`): boxes with exact pixel faces in one atlas, `paint()` with shading + ASCII
    stamps ("." keep, "_" hole, digits = ramp, letters from a key, `[Color, true]` = glow), rotated parts;
  - `PixelSkeleton`, `PixelTusker` build parts on `HumanoidModel` pivots (`HumanoidModel.PIXEL_BODIES`, `_add_mesh`);
  - Tusker data `data/enemies/tusker_*.tres`, attacks `tusker_*`/`chief_*`, items `tusker_tusk`, `war_banner_scrap`;
  - `WildSpawns` war parties; `RaidManager.TUSKERS`, `pick_faction()`, `FACTION_NAMES`; lore page `tuskers`;
  - tests `test_m20_*`; screenshots `--only=tuskers`, `--only=pixelpilot`, `--only=pixelstyle`.

- **M18b:**
  - finishers (`AttackData.finisher`, `knockdown`, `hitstop`) at the end of every melee moveset in `data/movesets/`;
  - `PlayerCombat.assisted_direction` (aim assist), hold-to-chain in `physics_update` (`Player.input_allowed`),
    `_apply_hitstop`; `Enemy.freeze`, `_flinch`, `knock_down`; AI level of detail in `Enemy._physics_process`;
  - fodder enemies `skeleton_minion`, `bandit_recruit`, `cultist_acolyte` in `WildSpawns.TABLE`; spawner max 60;
  - elite outline (`Materials.outline`, `MonsterModel.set_outline`) and roar; heavy-attack ground warnings;
  - tests `test_m18b_*` (run and pass since v0.23.1).

- **M18c:**
  - `src/fx/fx.gd` (`FX`): pooled soft particles, element looks (`impact`, `cast_glow`, `ultimate`), `lightning`,
    `sky_beam`, `ground_mark`, `light_flash`; `VFX.burst`/`bolt`, `Projectile`, `AbilityZone` use it;
  - `PlayerAbilities._cast_fx`; `Enemy._set_ice_shell`;
  - Creative mode: `src/ui/creative_panel.gd`, `Player.creative`, `Player.creative_used` (blocks achievements); Milestone 24 added `GameState.creative_world`, `World.teleport_to()`, `Enemy.creative_freeze`, free crafting (`Crafting.check`) and building (`BuildingManager.check_place`) when `player.creative`.
  - tests `test_m18a_*`, `test_m18b_*` and `test_m18c_*` were run with the owner's permission and pass (v0.23.1).

- **v0.24.0:** `Player._try_jump` (coyote time, buffer), `HumanoidModel.play_jump`, `AnimLibrary.jump`;
  `DayNightCycle.set_art_style` and Settings `art_style` (0 Vibrant, 1 Classic).
- **v0.25.0:** world colours: biome palettes in `data/biomes/*.tres`, `TerrainGenerator._top_color` (per-block
  variation) and `TerrainGenerator.side_shade`; soft tree fade `assets/shaders/foliage_fade.gdshader`
  (`focus_pos` = hero, set by `Materials.set_camera_fade` from CameraRig). Test `test_m18_world_colours` not run yet.
- **v0.25.1:** smoother run in `HumanoidModel._base_pose` (arm follow-through, twist, sway) and a springy lean in `set_motion`.
- **v0.26.0 block textures:**
  - 16x16 pixel-art textures made by `art/tools/` (rules in `docs/ART_BIBLE.md`), multiplied with the block colours;
  - block material is a shader: `assets/shaders/blocky.gdshader` and `blocky_fade.gdshader`; foliage shaders draw textures too;
  - small plants on crossed cut-out cards (they sway), wheat in 4 growth stages;
  - 215 new item icons (`src/ui/item_icon_atlas.gd`); new biome palette;
  - Setting **Block textures** (Display & graphics) turns them off; textures fade to plain colour far away;
  - test `test_v026_block_textures`; full suite run: 1797 passed.
- **M18d (v0.27.0) smoother world:**
  - terrain shapes: `TerrainGenerator.SHAPE_CLASSIC` (3, old saves, never change it) and `SHAPE_SMOOTH` (4, new worlds);
    stored as `generator_version` in the world meta, `GameState.terrain_shape`, sent to co-op guests as "shape";
    `tools/terrain_fingerprint.tscn` proves shape 3 is unchanged;
  - fade-in: `ChunkManager` fade map (global shader params `chunk_fade`, `chunk_fade_rect`), `Chunk` ghost mesh,
    `assets/shaders/chunk_fade.gdshaderinc` (`fade_channel` 0 ground, 1 props, 2 ghost); `Materials.terrain()`;
  - `src/world/far_impostors.gd`: far tree clumps (LOD2 chunks + far tiles) and landmarks (`FarTerrain._landmarks`);
  - tests `test_m18d_*` written, not run yet.

## Main code locations
- Combat: `src/player/player_combat.gd`, `src/player/player.gd`
- Abilities, spells and their effects: `src/rpg/player_abilities.gd` (`_ability_<effect>`, `_spell_<effect>`), `src/rpg/ability_upgrades.gd`
- Ability data: `src/rpg/ability_book.gd`, `src/rpg/ability_data.gd`, `src/rpg/spell_book.gd`
- Ability book panel: `src/ui/spellbook_panel.gd`; Creative mode: `src/ui/creative_panel.gd`
- Model and animations: `src/player/humanoid_model.gd`, `src/anim/`
- Effects: `src/fx/fx.gd`
- Terrain and look: `src/world/` (terrain generator, streaming), `data/biomes/`, `assets/shaders/`, `art/`
- Items, loot and shops: `src/inventory/item_data.gd`, `src/exploration/loot_tables.gd`, `src/living/economy.gd`
- Full list of abilities, weapons and spells: `docs/ARSENAL_PLAN.md`

- **M19 (v0.28.0) co-op combat:** `src/net/net_combat.gd` (host: ids, per-guest sync at 10/s, hits/calls/support
  checks; guest: puppets, hurt, fx). `Enemy.net_puppet`, `net_id`, `nearest_player()`, `_net_forward()`;
  model `net_event` signals; `RemotePlayer.receive_hit` + `NetHitbox`; `ChunkManager._guest_centers()`;
  `PlayerAbilities.share_support()` / `receive_support()`. Tests `test_m19_*` (guest script `--combat`).
- Testing rule now: the owner allows running only the test groups for what changed (ask if unsure).

## Next step: item 3 - monster pathfinding (A* on the block grid; also fixes monsters caught on dungeon corridor corners), or hand-drawn details for more monsters

## After that
- **M19 "Together in Danger":** real co-op combat, plus abilities that help friends.
- **M20 "World Polish":** horses, boats and waystones, gamepad menus, translations, Steam.
