# Prompt for a texture-design session

Copy everything inside the box into a new Claude session. When that session is done, bring its files back
to the coding session and say "add the textures".

```text
You are the art director and texture artist for my game "Shardlands". This session is ONLY for designing
the textures and the art rules. Do NOT change any game code. English is not my first language, so use
simple English.

THE GAME
- A voxel open-world survival RPG made in Godot 4.4.1 (GDScript). Repo: jihad-g/My-game,
  branch claude/survival-rpg-foundation-tu1eqk (read docs/GAME_DESIGN.md and docs/CHANGELOG.md for context;
  read data/biomes/*.tres for the current colours; do not edit code).
- Camera: top-down / isometric, about 16 m from the hero, looking down at about 50 degrees. Players see
  the world from far away, so textures must read clearly at small size.
- Style target: Minecraft Dungeons and Hytale. Chunky, colourful, hand-painted pixel look; soft and warm
  light; strong silhouettes; not realistic; not noisy.
- Terrain blocks are 1 m wide and 0.5 m tall (half-height blocks), chunks are 16 x 16 blocks.
- Right now there are NO textures: every block is a flat colour (vertex colour) with per-block colour
  variation, darker sides than tops, and baked shade in corners. The textures you design will be
  multiplied by these colours later, so design them to work with this.
- Two renderers must look good: Forward+ (Windows, with ambient occlusion) and the simple OpenGL /
  web renderer (no ambient occlusion).

CURRENT BIOME COLOURS (top / top alt / side / shore / rock)
- verdant_meadow: #447C30 / #66993A / #7F5433 / #F7D684
- whispering_forest: #336B2D / #498235 / #724C2D / #EFD184
- emerald_jungle: #216B28 / #388730 / #6B4428 / #EACC84
- frostpine_taiga: #3F7551 / #54895E / #6B5138 / #CCC6A5
- murk_swamp: #496633 / #5E7538 / #594C33 / #66603F
- sandy_beach: #F4D389 / #FCE2A0 / #E0B572 / #F4D389
- sunscorch_desert: #F4BF70 / #FCD184 / #DB995E / #F2CC84 / rock #D68C59
- snowy_tundra: #EDF2F9 / #E0EAF7 / #8E7A70 / #D8E0EA
- stonecrown_mountains: #607A47 / #758454 / #726B66 / #99938C / rock #8C847C
- crystal_glade: #7F6BB7 / #707AC1 / #594C72 / #CCBFE5
- deep_ocean: #4C668C / #516D93 / #47597A / #D8CC99
- the_deeps (caves): #5B5660 / #665E66 / #4C4751 / rock #333038

WHAT I WANT FROM THIS SESSION
1. Art bible (a short document): the look in a few rules - pixel size, how much detail, how light and
   shade work, colour rules (saturation, warm light / cool shade), what to avoid. Compare to Minecraft
   Dungeons and Hytale and say what we take from each.
2. Final colour palette for each biome (hex), improved if needed, with a short reason.
3. Texture list and specs. For each block type: top, side, and the "grass edge" band on the side.
   Block types: grass (one per green biome), dirt, sand, desert sand, sandstone, stone, mountain rock,
   snow, ice, swamp mud, crystal ground, cave stone, gravel/riverbed. Also the faces of props: tree bark,
   oak leaves, pine needles, jungle leaves, boulder stone, ore rocks (copper, iron, coal, silver).
4. The textures themselves as real PNG files: 16 x 16 pixels per face (pixel art), made in code
   (Python + Pillow) so they are exact and repeatable. Mostly grey-scale or light-tinted, so the game can
   tint them with the biome colour; say for each texture whether it is "tinted" or "full colour".
   - Each texture must tile seamlessly (left/right and top/bottom edges match).
   - 2-3 variants of the main ones (grass top, stone, sand) so the ground does not repeat visibly.
   - The side texture is for a 1 m x 0.5 m face: design it 16 x 8 pixels, or 16 x 16 covering two blocks.
5. One texture atlas PNG (for example 256 x 256, 16 x 16 cells, 1 pixel padding or a clear plan for
   bleeding) plus a JSON file that maps each texture name to its cell and says tinted / full colour.
6. Preview pictures so I can judge the look: render a small isometric scene of each biome (blocks
   with tops, sides and grass edges, from the game's camera angle) using the textures and the biome
   colours, made with Python. Show the same scene with and without textures side by side.
7. A short "how to add these to the game" note for the coding session: UV plan (world-space UVs on tops
   and sides), how tint and per-block colour variation combine with the texture, texture filter
   (nearest, with mipmaps), and anything that could look bad from far away (shimmer, noise) and how to
   avoid it.

RULES
- Ask me at most 2-3 questions at the start (for example: how much detail, how close to Minecraft
  Dungeons vs Hytale), then work.
- Show me the preview pictures early so I can say "more like this / less like that", then finish.
- Keep textures simple and readable from far away: big shapes, few colours per texture (about 4-6
  shades), no single-pixel noise everywhere.
- Do not copy any real game's textures; make original ones in this style.
- Put all results in one folder: art/textures/ (PNGs), art/textures/atlas.png, art/textures/atlas.json,
  art/previews/ (preview pictures) and docs/ART_BIBLE.md. If you can, commit them to the same branch
  (fetch first, never force-push); if not, send me the files.
- Mark anything you did not finish as NOT IMPLEMENTED.
```
