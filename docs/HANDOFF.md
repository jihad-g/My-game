# Shardlands — handoff for a new chat

## The project
- **Shardlands** is a voxel open-world survival RPG built with **Godot 4.4.1** in GDScript.
- Repository: `jihad-g/My-game`. Branch: `claude/survival-rpg-foundation-tu1eqk`. All work is on this branch.
- Current version: **v0.19.0** (Milestone 17c). The Windows build is `releases/Shardlands-v0.19.0-windows.zip`.

## How to work with the owner
- Act as a technical co-founder. Write complete, working code, and every milestone must run.
- Mark anything unfinished as **NOT IMPLEMENTED** in the docs.
- After each milestone, report what changed, how to run and test it, known limitations and the next step. Then wait for the owner to say "do it".
- Use **simple English**. English is not the owner's first language.
- **Don't run the whole test suite** (about 1,600 tests, 5+ minutes). Only run the test groups that match what you changed (the owner asked for this).
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

## What is done (milestones 1–17c)
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

## Main code locations
- Combat: `src/player/player_combat.gd`, `src/player/player.gd`
- Abilities, spells and their effects: `src/rpg/player_abilities.gd` (`_ability_<effect>`, `_spell_<effect>`)
- Ability data: `src/rpg/ability_book.gd`, `src/rpg/ability_data.gd`, `src/rpg/spell_book.gd`
- Ability book panel: `src/ui/spellbook_panel.gd`
- Model and animations: `src/player/humanoid_model.gd`
- Items, loot and shops: `src/inventory/item_data.gd`, `src/exploration/loot_tables.gd`, `src/living/economy.gd`
- Full list of abilities, weapons and spells: `docs/ARSENAL_PLAN.md`

## Next step: M17d (last part of "Heroes' Arsenal")
- Abilities for levels **66–100**: 18 per class, listed in `docs/ARSENAL_PLAN.md`.
- The four **ultimates** at level 100.
- **Ability upgrades at level 30:** pick one of two upgrades per ability (idea 5i).

## After that
- **M18 "Together in Danger":** real co-op combat, plus abilities that help friends.
- **M19 "World Polish":** textures, more animations, horses, boats and waystones, gamepad menus, translations, Steam.
