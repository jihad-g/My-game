# Code Map (short)

Where to look first. Keep this file short.

## World / biomes / props
- `data/biomes/*.tres` — one file per biome: colours + `prop_rules` (what grows there, density, size range).
  **Rule order is saved** (`TerrainGenerator.rule_uid`): only ADD new rules at the end, never reorder.
- `src/world/prop_rule.gd` — fields of one placement rule.
- `src/world/terrain_generator.gd` `_place_props` / `_place_rule` — places props from the rules.
- `data/props/*.tres` — one file per prop (name, hits, drops, collision, tool).
- `src/world/prop_library.gd` — builds prop meshes in code (`_build_<mesh_builder>`), wind `SWAY` table.
  Tree variants (Milestone 40) are at the end of the file.
- `src/world/far_impostors.gd` `TREE_LOOK` — far-away tree colour/height/width; add every new tree here.

## Other areas
- Docs for the rest: `docs/ARCHITECTURE.md`, `docs/GAME_DESIGN.md`, `docs/TODO.md`.
