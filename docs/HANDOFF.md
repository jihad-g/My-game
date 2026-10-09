# Shardlands — handoff for a new chat

## The project
- **Shardlands** is a voxel open-world survival RPG built with **Godot 4.4.1** in GDScript.
- Repository: `jihad-g/My-game`. Branch: `claude/survival-rpg-foundation-tu1eqk`. All work is on this branch.
- Current version: **v0.25.0** (Milestone 18c + jump, the Vibrant look and the world colour pass). The Windows build is `releases/Shardlands-v0.25.0-windows.zip`.
- Keys changed in v0.24.0: **Space = jump**, **Left Alt = dodge roll**.
- **Creative mode** for testing in the game: the ` key (under Esc).

## How to work with the owner
- Act as a technical co-founder. Write complete, working code, and every milestone must run.
- Mark anything unfinished as **NOT IMPLEMENTED** in the docs.
- After each milestone, report what changed, how to run and test it, known limitations and the next step. Then wait for the owner to say "do it".
- Use **simple English**. English is not the owner's first language.
- **Never run any tests without the owner's permission.** Ask first. When allowed, only run the test groups that match what you changed (the whole suite is about 1,700 tests, 5+ minutes).
- After each milestone:
  - update `docs/TODO.md`, `docs/CHANGELOG.md`, `README.md`, `docs/GAME_DESIGN.md` and `docs/ARSENAL_PLAN.md`;
  - bump `config/version` in `project.godot` and the version check in `tests/test_runner.gd` (`test_m13_release`);
  - build Windows: `tools/build_release.sh windows`;
  - replace the zip in `releases/` and update `releases/README.md`;
  - commit and push.
- Game rules:
  - A Wizard is never as strong physically as a Knight or Barbarian. Classes keep a small talent (Option A).
  - Crafting never fails.
  - Temperature never kills.

## Git
- Commit: `git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit`.
- Push: `git push -u origin claude/survival-rpg-foundation-tu1eqk`. Fetch first, because another session may push.
- No pull requests unless asked. Never force-push.

## Commands
- Tests: `godot --headless --path . res://tests/test_runner.tscn -- --only=<part of a test name>`. For example `--only=m17c`.
- After adding a new `class_name`: `godot --headless --editor --quit --path .`
- Screenshots: `xvfb-run -a godot --path . --rendering-method gl_compatibility res://tests/screenshot_runner.tscn -- --only=<arsenal|book|poses|gear|story|...> --out=DIR`
- Docs: `godot --headless --path . res://tools/balance_report.tscn -- --out=docs/BALANCE.md` and `godot --headless --path . -s tools/gen_rpg_tables.gd`

## What is done (milestones 1–18c)
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
  - Creative mode: `src/ui/creative_panel.gd`, `Player.creative`, `Player.creative_used` (blocks achievements);
  - tests `test_m18a_*`, `test_m18b_*` and `test_m18c_*` were run with the owner's permission and pass (v0.23.1).

- **v0.24.0:** `Player._try_jump` (coyote time, buffer), `HumanoidModel.play_jump`, `AnimLibrary.jump`;
  `DayNightCycle.set_art_style` and Settings `art_style` (0 Vibrant, 1 Classic).
- **v0.25.0:** world colours: biome palettes in `data/biomes/*.tres`, `TerrainGenerator._top_color` (per-block
  variation) and `TerrainGenerator.side_shade`; soft tree fade `assets/shaders/foliage_fade.gdshader`
  (`focus_pos` = hero, set by `Materials.set_camera_fade` from CameraRig). Test `test_m18_world_colours` not run yet.

## Main code locations
- Combat: `src/player/player_combat.gd`, `src/player/player.gd`
- Abilities, spells and their effects: `src/rpg/player_abilities.gd` (`_ability_<effect>`, `_spell_<effect>`)
- Ability data: `src/rpg/ability_book.gd`, `src/rpg/ability_data.gd`, `src/rpg/spell_book.gd`
- Ability book panel: `src/ui/spellbook_panel.gd`
- Model and animations: `src/player/humanoid_model.gd`
- Items, loot and shops: `src/inventory/item_data.gd`, `src/exploration/loot_tables.gd`, `src/living/economy.gd`
- Full list of abilities, weapons and spells: `docs/ARSENAL_PLAN.md`

## Next step: M18d (plan: `docs/M18_PLAN.md`; the owner's answers are written at the top)
- M18a: done (v0.21.0). M18b: done (v0.22.0).
- M18b: hack and slash: combo chains, finishers, hit-stop, knockdowns, crowds of fodder enemies.
- M18c: spells that look like magic: a VFX library v2 and a look for each element.
- M18d: smoother world generation: no pop-in, smoother hills, blended biome borders, smooth streaming.

## After that
- **M19 "Together in Danger":** real co-op combat, plus abilities that help friends.
- **M20 "World Polish":** textures, horses, boats and waystones, gamepad menus, translations, Steam.
