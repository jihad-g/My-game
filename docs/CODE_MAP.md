# Code map

Where things live, so a session can open only the files it needs. Short lines; add to it as you go.

## Camera and view
- `src/camera/camera_rig.gd` (`CameraRig`): top-down camera, zoom/yaw/pitch, shake, `kick`, dungeon view.
  First person: `set_first_person(on)`, `first_person_active()`, `_process_first_person`, `fp_pitch`, `fp_fov`.
- `src/player/humanoid_model.gd` (`HumanoidModel`): body, outfit, weapons; `set_first_person_hidden` hides head/body.
  First-person arm size/place: `FP_ARM_SCALE`, `FP_ARM_R`, `FP_ARM_L`, `FP_ARM_R_TWO_HAND`, `FP_BOW_RAISE`, `_apply_first_person_arms`.

## Player and combat
- `src/player/player.gd` (`Player`): `equipment` (`.equip(item)`), `combat.request(&"light")`, `abilities.try_use(slot)`,
  `set_lock_target`, `face_direction`, `equip_from_slot`.
- `src/combat/combat_feel.gd` (`CombatFeel`): hit-stop, kick, blast numbers.

## UI
- `src/ui/hud.gd`: HUD; `hud.story` = intro page, `hud._help` = help box.
- `src/autoload/tutorial.gd` (`Tutorial`): first steps (`skip_first_steps`), hints, `profile_path`.
- `src/ui/creative_panel.gd`: creative mode (` key); Monsters tab spawns monsters / training dummy.

## Tests, screenshots, builds
- `tests/screenshot_runner.gd`: `--only=<name>` showcases. First person: `--only=firstperson` (`_first_person_showcase`).
  Run: `xvfb-run -a godot --path . --rendering-method gl_compatibility res://tests/screenshot_runner.tscn -- --only=firstperson --out=DIR`
- `tools/build_release.sh web`: browser build in `build/release/web/` (launcher `tools/web/shardlands.html`, engine in <15 MB parts).
- New clone: run `godot --headless --import` once before screenshots (otherwise fonts/icons fail to load).
