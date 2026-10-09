# Shardlands — Art Bible (blocks and textures)

Version 2 · 2026-10-09 (v2: plants, building blocks, item icons) · Direction: **balanced mix** of Minecraft Dungeons and Hytale, **low-medium detail**,
palette freely redesigned.

Everything here is made by code and can be rebuilt exactly:

```
python3 art/tools/texgen.py          # 113 textures -> art/textures/*.png (+ textures.json); uses texgen_extra.py
python3 art/tools/icongen.py         # 215 item icons -> art/icons/ (+ icon_atlas.png/json)
python3 art/tools/render_village.py  # art/previews/village.png (buildings, bushes, flowers, crops)
python3 art/tools/build_atlas.py     # atlas.png, atlas_array.png, atlas.json
python3 art/tools/render_previews.py # art/previews/<biome>.png, all_biomes.png, far_view_test.png
python3 art/tools/sheet.py           # art/previews/texture_sheet.png
```

Only Python 3 + Pillow + numpy are needed. No game code was changed.

---

## 1. The look in 10 rules

1. **16 pixels per metre.** One block top = 16 x 16 pixels. A block side is 0.5 m = 8 pixels tall. Never mix
   pixel sizes (no 32 px textures next to 16 px ones).
2. **Big shapes first.** Each texture has 2-4 big soft shapes (patches, slabs, clumps) plus 2-5 small accents
   (tufts, pebbles, sparkles). No single-pixel noise everywhere.
3. **4-6 shades per texture.** Edge bands have 4-5 shades in the grass part. Ores have up to 8 because the
   nugget colour is extra.
4. **Light comes from the top-left.** Lit edges are light pixels on the top/left of a shape; dark pixels sit
   under/right of it. All textures agree, so the world looks lit by one sun.
5. **Warm light, cool shade.** Light shades lean a few percent warm (yellow), dark shades a few percent cool
   (blue). In the renderer: tops get warm sun, walls get cool shade.
6. **Colour lives in the vertex colour, detail lives in the texture.** Textures are almost grey; the biome
   colour (and per-block variation) tints them. This keeps one texture useful for many biomes.
7. **Walls are darker than tops** (game already does 0.74 / 0.62), and the dirt under the grass band is
   darker again (x0.92). Keep this — it is what makes the world chunky, even with no ambient occlusion.
8. **Saturation:** grass and magic biomes saturated, earth and stone medium, swamp and caves low. Never
   pure grey (always a little warm or cool) and never pure black.
9. **Strong silhouettes beat texture detail.** If a texture fights the block shape from 16 m away, it is too
   busy: lower its contrast, not the block's.
10. **Original only.** No shapes copied from any game. Our motifs: 3-pixel tufts with a shadow line,
    top-left-lit Voronoi slabs, round leaf clumps, 4-row sandstone layers, rounded snow caps.

### What we take from each game

| | Minecraft Dungeons | Hytale | Shardlands |
|---|---|---|---|
| Camera | high isometric, far | third person, close | high isometric, 16 m → design for far |
| Colour | warm, saturated, painterly light | cleaner, a bit cooler | **Dungeons colour + warm/cool light** |
| Texture | soft, low contrast, colour does the work | crisper pixel detail, clear block edges | **Hytale's crisp 16 px pixels, but Dungeons' low contrast** |
| Shapes | chunky, soft gradients | strong top-left bevel on stones | **bevelled stones and slabs, soft grass** |
| Avoid | blurry mush when far | too much detail for our distance | — |

### Things to avoid

- High-contrast single pixels (they sparkle when the camera moves).
- Lines that run across the full texture (they show the 1 m grid as stripes).
- Big dark areas in tinted textures (they turn the biome colour muddy).
- Full-colour textures on terrain (they break per-biome tinting).
- Different texel sizes on props and terrain (props use the same 16 px per metre).

---

## 2. Final biome palette

Hex is sRGB. "Rock/peak/ice" only where the biome uses them. The old values are kept in
`art/textures/atlas.json` → `biomes.<id>.old_colours` and shown in the left panel of each preview.

| Biome | top | top alt | side | shore | underwater | extra | why |
|---|---|---|---|---|---|---|---|
| verdant_meadow | #5A9A34 | #7AAE3E | #8A5A36 | #F2D58A | #BC9E66 | - | Home biome: brighter, fresher yellow-green so it feels sunny and inviting; warmer dirt. |
| whispering_forest | #3C7A34 | #4E8C3A | #6E4A2E | #E8CF8C | #A6936A | - | Darker and a bit bluer than the meadow so the border between them is clear; old one was too dark. |
| emerald_jungle | #22813C | #33964A | #6A4226 | #E6C980 | #807048 | - | Pushed toward emerald (blue-green, very saturated) so it is not just 'another forest'. |
| frostpine_taiga | #3E7562 | #4F8770 | #66503C | #C9C6AA | #807E70 | - | Cool teal-green: reads 'cold' next to the warm forest. Gravel shores instead of sand. |
| murk_swamp | #5B6B34 | #6C7A3C | #4F4330 | #6B6440 | #4A4C34 | - | Olive and low saturation: the only 'dirty' green. Mud texture carries the wet look. |
| sandy_beach | #F2D48E | #F8E0A6 | #D9B077 | #F2D48E | #D0B27A | - | Almost unchanged; a touch less yellow so it differs from desert orange. |
| sunscorch_desert | #EDB66C | #F5C780 | #CF8A55 | #F0CB88 | #CCAD74 | rock #C47A4E | More orange than the beach; deeper red-orange mesas so cliffs stand out against the sand. |
| snowy_tundra | #EEF3FA | #E2EBF6 | #7E6E68 | #D6DFEA | #9A9EA8 | ice #A9D6EE | Snow stays near white but cool; darker frozen dirt so snow caps read as a bright lip. |
| stonecrown_mountains | #6E8A4E | #829659 | #6E6660 | #9A948C | #7E7A74 | rock #8E867D, peak #F2F5FA | Sage alpine grass (lighter, greyer); warm grey rock so cliffs are not cold blue-grey. |
| crystal_glade | #8069C6 | #6B7ED0 | #54466E | #CFC2EA | #7E72A6 | - | A bit more saturated violet/blue so the magic biome pops; it is the rare 'wow' place. |
| deep_ocean | #4E6A8E | #557395 | #47597A | #D8CC99 | #5A7290 | - | Kept; seen through water. Small lift so the sea floor is not black on the web renderer. |
| the_deeps | #5E5864 | #69616C | #4A4550 | #666666 | #4C4C4C | rock #3A3640 | Slightly lighter, purple-tinted grey: without ambient occlusion (web) the old cave rock was nearly black. |

**NOT IMPLEMENTED (on purpose):** the new colours are not yet written into `data/biomes/*.tres` (this session
must not change game files). The coding session should copy them over; `atlas.json` has them in one place.
Prop colours (trees, boulders, ores) were not changed.

---

## 3. Texture list and specs

- Size: **16 x 16 pixels** each, PNG RGBA, in `art/textures/`.
- **Tops**: world-space UV, 1 texture per 1 x 1 m.
- **Sides**: one 16 x 16 texture covers **two blocks (1 m)** of wall; v follows world height.
- **Edge band** (the side of the top block, 0.5 m): rows 0-7 of a 16 x 16 `*_edge` texture. Alpha = mask
  (255 = grass/snow/moss part, 0 = dirt part). Rows 8-15 hold dirt only, for safety.
- **Variants**: grass tops x3, sand x3, desert sand x3, stone top x3, stone side x2, other main tops x2. All
  variants of a family share the same outer 2-pixel ring, so any variant can sit next to any other
  without a seam (checked by script).
- **Tiling**: every texture is built from periodic noise / wrapped shapes, so left-right and top-bottom match.
  Edge bands tile left-right only (they never repeat vertically).
- **Mean brightness 0.80** for all tinted textures (texture x 1.25 = 1.0 on average, so the biome colour stays
  the same on average).

| Name | Face | Tint | Atlas cell | Shades | What it is |
|---|---|---|---|---|---|
| `dirt_side` | side | tinted | 0,0 | 5 | Dirt wall: soft blobs + a few pebbles. 16x16 = 1 m (two blocks). |
| `dirt_top` | top | tinted | 1,0 | 5 | Bare dirt from above. |
| `crystal_side` | side | tinted | 2,0 | 6 | Dirt wall with small crystal shards. |
| `mud_side` | side | tinted | 3,0 | 5 | Dark mud wall with hanging roots. |
| `grass_meadow_top_0` | top | tinted | 4,0 | 4 | Soft blobs + light grass tufts (Verdant Meadows). Variant 0. |
| `grass_meadow_top_1` | top | tinted | 5,0 | 4 | Soft blobs + light grass tufts (Verdant Meadows). Variant 1. |
| `grass_meadow_top_2` | top | tinted | 6,0 | 4 | Soft blobs + light grass tufts (Verdant Meadows). Variant 2. |
| `grass_meadow_edge` | edge | tinted_edge | 7,0 | 13 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `grass_forest_top_0` | top | tinted | 8,0 | 5 | Clover leaves + dark leaf litter (Whispering Forest). Variant 0. |
| `grass_forest_top_1` | top | tinted | 9,0 | 5 | Clover leaves + dark leaf litter (Whispering Forest). Variant 1. |
| `grass_forest_top_2` | top | tinted | 10,0 | 5 | Clover leaves + dark leaf litter (Whispering Forest). Variant 2. |
| `grass_forest_edge` | edge | tinted_edge | 11,0 | 15 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `grass_jungle_top_0` | top | tinted | 12,0 | 6 | Big broad leaves (Emerald Jungle). Variant 0. |
| `grass_jungle_top_1` | top | tinted | 13,0 | 6 | Big broad leaves (Emerald Jungle). Variant 1. |
| `grass_jungle_top_2` | top | tinted | 0,1 | 6 | Big broad leaves (Emerald Jungle). Variant 2. |
| `grass_jungle_edge` | edge | tinted_edge | 1,1 | 15 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `grass_taiga_top_0` | top | tinted | 2,1 | 5 | Fallen needles + few tufts (Frostpine Taiga). Variant 0. |
| `grass_taiga_top_1` | top | tinted | 3,1 | 5 | Fallen needles + few tufts (Frostpine Taiga). Variant 1. |
| `grass_taiga_top_2` | top | tinted | 4,1 | 5 | Fallen needles + few tufts (Frostpine Taiga). Variant 2. |
| `grass_taiga_edge` | edge | tinted_edge | 5,1 | 13 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `grass_swamp_top_0` | top | tinted | 6,1 | 5 | Moss with dark wet puddles and glints (Murk Swamp). Variant 0. |
| `grass_swamp_top_1` | top | tinted | 7,1 | 5 | Moss with dark wet puddles and glints (Murk Swamp). Variant 1. |
| `grass_swamp_top_2` | top | tinted | 8,1 | 5 | Moss with dark wet puddles and glints (Murk Swamp). Variant 2. |
| `grass_swamp_edge` | edge | tinted_edge | 9,1 | 15 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `grass_alpine_top_0` | top | tinted | 10,1 | 4 | Short sparse tufts, bare patches (Stonecrown grass). Variant 0. |
| `grass_alpine_top_1` | top | tinted | 11,1 | 4 | Short sparse tufts, bare patches (Stonecrown grass). Variant 1. |
| `grass_alpine_top_2` | top | tinted | 12,1 | 4 | Short sparse tufts, bare patches (Stonecrown grass). Variant 2. |
| `grass_alpine_edge` | edge | tinted_edge | 13,1 | 12 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `crystal_ground_top_0` | top | tinted | 0,2 | 5 | Violet moss with small sparkles (Crystal Glade ground). Variant 0. |
| `crystal_ground_top_1` | top | tinted | 1,2 | 5 | Violet moss with small sparkles (Crystal Glade ground). Variant 1. |
| `crystal_ground_top_2` | top | tinted | 2,2 | 5 | Violet moss with small sparkles (Crystal Glade ground). Variant 2. |
| `crystal_ground_edge` | edge | tinted_edge | 3,2 | 15 | Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), alpha 0 = side part (side colour + side texture). |
| `sand_top_0` | top | tinted | 4,2 | 5 | Beach / shore sand, calm, few grains. Variant 0. |
| `sand_top_1` | top | tinted | 5,2 | 5 | Beach / shore sand, calm, few grains. Variant 1. |
| `sand_top_2` | top | tinted | 6,2 | 5 | Beach / shore sand, calm, few grains. Variant 2. |
| `sand_side` | side | tinted | 7,2 | 6 | Sand wall: soft horizontal layers. |
| `desert_sand_top_0` | top | tinted | 8,2 | 6 | Desert sand with wind ripples (all variants share direction). Variant 0. |
| `desert_sand_top_1` | top | tinted | 9,2 | 6 | Desert sand with wind ripples (all variants share direction). Variant 1. |
| `desert_sand_top_2` | top | tinted | 10,2 | 6 | Desert sand with wind ripples (all variants share direction). Variant 2. |
| `desert_sand_side` | side | tinted | 11,2 | 6 | Desert sand wall. |
| `sandstone_side` | side | tinted | 12,2 | 5 | Sandstone: 4-pixel layers with a lit lip and a shadow line. |
| `sandstone_top` | top | tinted | 13,2 | 4 | Sandstone slabs from above. |
| `stone_top_0` | top | tinted | 0,3 | 4 | Stone: big flat facets, cracks, light from top-left. Variant 0. |
| `stone_top_1` | top | tinted | 1,3 | 4 | Stone: big flat facets, cracks, light from top-left. Variant 1. |
| `stone_top_2` | top | tinted | 2,3 | 4 | Stone: big flat facets, cracks, light from top-left. Variant 2. |
| `stone_side_0` | side | tinted | 3,3 | 4 | Stone wall: wide flat slabs. Variant 0. |
| `stone_side_1` | side | tinted | 4,3 | 4 | Stone wall: wide flat slabs. Variant 1. |
| `mountain_rock_top_0` | top | tinted | 5,3 | 4 | Mountain rock from above: chunky facets. Variant 0. |
| `mountain_rock_top_1` | top | tinted | 6,3 | 4 | Mountain rock from above: chunky facets. Variant 1. |
| `mountain_rock_side` | side | tinted | 7,3 | 5 | Cliff: strong horizontal strata + vertical cracks. |
| `snow_top_0` | top | tinted | 8,3 | 6 | Snow: very soft drifts, rare sparkles. Variant 0. |
| `snow_top_1` | top | tinted | 9,3 | 6 | Snow: very soft drifts, rare sparkles. Variant 1. |
| `snow_edge` | edge | tinted_edge | 10,3 | 14 | Snow cap over dirt: rounded bumps, no thin drips. |
| `snow_side` | side | tinted | 11,3 | 6 | Packed snow wall (for snow blocks deeper than one block). |
| `ice_top` | top | tinted | 12,3 | 5 | Ice sheet: diagonal glints, two small cracks. Tint with ice_color. |
| `ice_side` | side | tinted | 13,3 | 4 | Ice wall: vertical light bands. |
| `swamp_mud_top_0` | top | tinted | 0,4 | 6 | Swamp mud: wet puddles with glints. Variant 0. |
| `swamp_mud_top_1` | top | tinted | 1,4 | 6 | Swamp mud: wet puddles with glints. Variant 1. |
| `cave_stone_top_0` | top | tinted | 2,4 | 5 | Cave floor: rough facets, mineral glints. Variant 0. |
| `cave_stone_top_1` | top | tinted | 3,4 | 5 | Cave floor: rough facets, mineral glints. Variant 1. |
| `cave_stone_side` | side | tinted | 4,4 | 4 | Cave wall: rough tall facets. |
| `gravel_top_0` | top | tinted | 5,4 | 4 | Gravel / riverbed: round pebbles with outlines. Variant 0. |
| `gravel_top_1` | top | tinted | 6,4 | 4 | Gravel / riverbed: round pebbles with outlines. Variant 1. |
| `gravel_side` | side | tinted | 7,4 | 5 | Gravel wall. |
| `bark` | prop | tinted | 8,4 | 5 | Tree bark: three wiggling vertical grooves, plates, one knot. All trunks. |
| `leaves_oak` | prop | tinted | 9,4 | 5 | Oak leaves: round clumps lit from top-left. |
| `leaves_pine` | prop | tinted | 10,4 | 4 | Pine needles: rows of downward chevrons. |
| `leaves_jungle` | prop | tinted | 11,4 | 5 | Jungle leaves: big broad leaves with a rib. |
| `boulder` | prop | tinted | 12,4 | 5 | Boulder / rock props: big facets, a little moss light. |
| `ore_copper` | prop | full | 13,4 | 8 | Ore rock (copper): dark stone with copper nuggets. Full colour - use white vertex colour. |
| `ore_iron` | prop | full | 0,5 | 7 | Ore rock (iron): dark stone with iron nuggets. Full colour - use white vertex colour. |
| `ore_coal` | prop | full | 1,5 | 7 | Ore rock (coal): dark stone with coal nuggets. Full colour - use white vertex colour. |
| `ore_silver` | prop | full | 2,5 | 7 | Ore rock (silver): dark stone with silver nuggets. Full colour - use white vertex colour. |
| `bush_leaves` | prop | tinted | 3,5 | 5 | Bush leaves: small dense clumps (all bush boxes; tint with the bush colour). |
| `berry_bush` | prop | full | 4,5 | 8 | Berry bush with red berries painted in (use on the main bush box; white vertex colour). |
| `frostberry_bush` | prop | full | 5,5 | 8 | Frostberry bush: teal leaves, blue berries. |
| `cactus` | prop | tinted | 6,5 | 5 | Cactus: vertical ribs every 4 px with light spines. |
| `palm_frond` | prop | tinted | 7,5 | 5 | Palm fronds: leaflets from a centre rib. |
| `mushroom_cap` | prop | full | 8,5 | 6 | Giant mushroom cap: red with cream spots. |
| `crystal` | prop | tinted | 9,5 | 6 | Crystal: big facets with bright edges (crystal clusters, altar). |
| `hanging_moss` | prop | tinted | 10,5 | 3 | Swamp-tree hanging moss strands. |
| `flowers_mixed` | sprite | full | 11,5 | 18 | Meadow flowers, four colours (the 'flowers' prop). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `flowers_yellow` | sprite | full | 12,5 | 9 | Yellow flower clump. Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `flowers_pink` | sprite | full | 13,5 | 9 | Pink flower clump. Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `flowers_violet` | sprite | full | 0,6 | 9 | Violet flower clump. Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `grass_tuft` | sprite | tinted | 1,6 | 5 | Grass tuft (tint with the biome top colour). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `fern` | sprite | tinted | 2,6 | 5 | Fern (forest/jungle floor; tint green). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `reeds` | sprite | full | 3,6 | 7 | Reeds with cattail heads (shores). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `dead_bush` | sprite | full | 4,6 | 4 | Dry desert bush. Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `sunbloom` | sprite | full | 5,6 | 8 | Sunbloom herb (meadow). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `moonpetal` | sprite | full | 6,6 | 5 | Moonpetal herb (glows at night - add emission). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `frost_lotus` | sprite | full | 7,6 | 6 | Frost lotus herb (tundra). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `starlight_orchid` | sprite | full | 8,6 | 6 | Starlight orchid herb (crystal glade). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `emberroot` | sprite | full | 9,6 | 5 | Emberroot herb (desert). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `mushroom_patch` | sprite | full | 10,6 | 5 | Brown mushroom patch. Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `glowcap` | sprite | full | 11,6 | 5 | Glowcap mushrooms (caves, emission). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `dreamcap` | sprite | full | 12,6 | 5 | Dreamcap mushrooms (caves). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `wheat_0` | sprite | full | 13,6 | 2 | Wheat crop, growth stage 0 (farm plot). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `wheat_1` | sprite | full | 0,7 | 2 | Wheat crop, growth stage 1 (farm plot). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `wheat_2` | sprite | full | 1,7 | 4 | Wheat crop, growth stage 2 (farm plot). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `wheat_3` | sprite | full | 2,7 | 4 | Wheat crop, growth stage 3 (farm plot). Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground. |
| `planks_wall` | building | tinted | 3,7 | 6 | Wood wall: horizontal boards 0.25 m, staggered joints, nails. Tint WOOD. |
| `planks_vertical` | building | tinted | 4,7 | 6 | Boards running along v, 0.25 m wide: wood floor (matches the floor-board mesh), doors, chests. |
| `wood_beam` | building | tinted | 5,7 | 4 | Dark frame wood: posts, beams, door frames. Tint WOOD_DARK. |
| `palisade` | building | tinted | 6,7 | 5 | Palisade / spike wall: vertical logs 0.25 m. |
| `roof_shingles` | building | tinted | 7,7 | 5 | Wood roof shingles, staggered rows. |
| `thatch` | building | tinted | 8,7 | 4 | Thatch roof straw rows. Tint THATCH. |
| `stone_bricks` | building | tinted | 9,7 | 5 | Stone wall bricks 0.5 x 0.25 m, staggered. |
| `stone_tiles` | building | tinted | 10,7 | 5 | Stone floor tiles 0.5 m (matches the floor mesh). |
| `iron_plate` | building | tinted | 11,7 | 5 | Iron plate with rivets: reinforced door, traps, forge, chest bands. |
| `cloth` | building | tinted | 12,7 | 4 | Woven cloth with a seam every 0.5 m: bed, tailoring, banners, rugs. Tint the cloth colour. |
| `tilled_soil` | building | tinted | 13,7 | 5 | Farm plot soil: furrows every 0.25 m. Tint SOIL. |
| `glass` | building | full | 0,8 | 2 | Window glass (alpha 110, glints 200). Not used by the current window mesh (it has no pane). |

### Which texture each block uses

| Block type | Top | Edge band | Side (wall) |
|---|---|---|---|
| Grass (per biome: meadow, forest, jungle, taiga, swamp, alpine) | `grass_<style>_top_0..2` | `grass_<style>_edge` | `dirt_side` (swamp: `mud_side`) |
| Crystal ground | `crystal_ground_top_0..2` | `crystal_ground_edge` | `crystal_side` |
| Dirt | `dirt_top` | `dirt_side` | `dirt_side` |
| Sand (beach, shores, sea floor) | `sand_top_0..2` | `sand_side` | `sand_side` |
| Desert sand | `desert_sand_top_0..2` | `desert_sand_side` | `sandstone_side` |
| Sandstone (mesas, desert rock) | `sandstone_top` | `sandstone_side` | `sandstone_side` |
| Stone | `stone_top_0..2` | `stone_side_0` | `stone_side_0/1` |
| Mountain rock | `mountain_rock_top_0..1` | `mountain_rock_side` | `mountain_rock_side` |
| Snow | `snow_top_0..1` | `snow_edge` | `snow_side` (or the biome's dirt) |
| Ice (frozen water) | `ice_top` | — | `ice_side` |
| Swamp mud | `swamp_mud_top_0..1` | `mud_side` | `mud_side` |
| Cave stone | `cave_stone_top_0..1` | `cave_stone_side` | `cave_stone_side` |
| Gravel / riverbed | `gravel_top_0..1` | `gravel_side` | `gravel_side` |
| Props | tree trunks `bark`; oak `leaves_oak`; pine `leaves_pine`; jungle `leaves_jungle`; rocks `boulder`; ore rocks `ore_copper/iron/coal/silver` (full colour) | | |

The full per-biome map (top / shore / underwater / rock / peak → textures) is in `atlas.json` → `biomes`.

---

## 4. Atlas

- `art/textures/atlas.png` — 256 x 256, cells of **18 x 18** (16 x 16 texture + **1-pixel gutter** that copies
  the opposite edge, i.e. wrap). 14 cells per row; texture *k* is at cell `(k % 14, k / 14)`, its 16 x 16 area
  starts at pixel `(cx*18 + 1, cy*18 + 1)`. 113 textures use 9 rows; room for 196.
- `art/textures/atlas_array.png` — the same 113 textures as a 16 x 1808 vertical strip (one layer each).
- `art/textures/atlas.json` — for each texture: `layer`, `cell`, `px` rect, `uv` rect, `tint`, `face`,
  `group`, `shades`, `desc`; plus `groups`, `biomes` (colours + textures per surface) and `props`.

**Recommendation: use the array, not the atlas, in the game.** A 1-pixel gutter is enough for nearest
sampling at full size, but mipmaps of a packed atlas mix neighbouring textures after 1-2 levels, and repeat
tiling inside an atlas cell needs `fract()` math that causes a seam line at every block edge with mipmaps.
`Texture2DArray` has none of these problems: each layer repeats and mipmaps on its own.

---

## 5. Preview pictures

`art/previews/` — every biome as a 14 x 14 block hill seen from the game camera (yaw 45°, looking down 50°,
orthographic), three panels: **now (old colours, flat)** / **new palette, flat** / **new palette + textures**.
`all_biomes.png` shows the textured version of all 12. `texture_sheet.png` shows every texture tinted and
tiled 2 x 2. `far_view_test.png` shows the meadow at far distance with and without mipmaps.

The renderer copies the game's rules: per-block colour variation, 8x8 patches, warm/cool shift, side shade
0.74 / 0.62, dirt x0.92, one-block grass edge band, baked corner AO, and Vibrant-style warm sun / cool
shade. It does **not** simulate screen-space AO or fog, so it matches the **web/compatibility renderer**;
Forward+ only adds darker inner corners on top.

`village.png` (v2) shows building pieces, bushes, flowers, herbs and wheat stages, today vs textured.

**NOT IMPLEMENTED:** a Forward+ (SSAO) version of the previews.

---

## 6. How to add these to the game (note for the coding session)

**Do not change art files by hand — change the Python and re-run.** Steps:

### 6.1 Import

1. Import `art/textures/atlas_array.png` as **Texture2DArray**: Horizontal = 1, Vertical = 113.
2. Import settings: **Compress = Lossless** (no VRAM compression — it smears 16 px art), **Mipmaps = on**,
   **sRGB off for tinted textures** (we read them as numbers; see 6.4). Ores are "full" colour: either a
   second small array with sRGB on, or convert in the shader with `pow(c, 2.2)`.
3. Material sampler: `filter_nearest_mipmap_linear` (or `filter_nearest_mipmap` if it looks soft), `repeat_enable`.
   Anisotropic filtering x4 on Forward+ helps the 50° slant; harmless on web if unsupported.

### 6.2 UV plan (world space, no UVs in the mesh needed)

- 16 texels per metre → UV = world position in metres (`fract` is done by `repeat`).
- **Top faces** (normal up): `uv = world.xz`.
- **Side faces**: `uv = vec2(world.x or world.z, -world.y)`. Use `x` on faces whose normal is ±Z, `z` on ±X.
  One texture = 1 m, i.e. two block heights.
- **Edge band** (the top quad made in `_side()`, height 0.5 m): `uv_edge = vec2(horizontal, (block_top_y - world.y))`,
  so v runs 0 → 0.5 down the band = rows 0-7. `block_top_y` must reach the shader (e.g. in `UV2.y` or
  `CUSTOM0`).
- Texture **layer** per face: put it in the mesh, e.g. `UV2.x = layer` (or `CUSTOM0.r`). Choose the top
  variant per block with the existing hash: `variant = hash3(wx, wz, 41) % count`.

### 6.3 What the mesh must carry (per vertex)

| Data | Where | Note |
|---|---|---|
| tint colour (biome colour x per-block variation x side shade x AO) | `COLOR` | exactly what the game already writes |
| texture layer | `UV2.x` | from `atlas.json` |
| edge band: block top y | `UV2.y` | only on edge quads |
| edge band: side colour + side layer | `CUSTOM0` (rgb = side colour x shade x 0.92, a = side layer) | edge quads only; needs `ARRAY_CUSTOM0` format |

If `CUSTOM0` is too much work at first: **fallback** — draw the edge quad with the top colour only (alpha mask
ignored); it still looks fine, just without dirt between the grass drips.

### 6.4 Tint and colour variation together (shader sketch)

```glsl
uniform sampler2DArray tex : filter_nearest_mipmap_linear, repeat_enable;  // NOT source_color
const float GAIN = 1.25;

void fragment() {
    vec3 t = texture(tex, vec3(world_uv, layer)).rgb;          // 0..1 "detail factor", mean 0.80
    vec3 detail = pow(t * GAIN, vec3(2.2));                      // same result as multiplying in sRGB
    ALBEDO = COLOR.rgb * detail;                                 // COLOR = linear vertex colour
    // edge band:
    // vec4 e = texture(tex, vec3(edge_uv, layer));
    // vec3 dirt = texture(tex, vec3(world_uv, side_layer)).rgb;
    // ALBEDO = mix(side_col * pow(dirt * GAIN, vec3(2.2)), COLOR.rgb * pow(e.rgb * GAIN, vec3(2.2)), e.a);
}
```

Why `pow(..., 2.2)`: the previews multiply in sRGB (like an image editor). Godot shades in linear space;
raising the factor to 2.2 gives the same picture. Without it the texture looks too weak.

Per-block colour variation stays exactly as it is (`_top_color`). Two small changes are worth trying, because
the texture now adds its own variation: lower `spread` from 0.08 to **0.06** on grass, and keep the 8x8 patch
shading as is (it is what stops repetition at a distance).

### 6.5 Far away: shimmer and noise

- **Mipmaps are a must** (see `far_view_test.png`: without them single pixels sparkle when the camera moves).
- Fade the texture out with distance: `detail = mix(detail, vec3(1.0), smoothstep(30.0, 60.0, dist))` —
  far chunks then look like today's flat colours, which already read well. Far terrain (`far_terrain.gd`, LOD)
  should stay **untextured**.
- Use `textureGrad`/plain `texture` with world UVs **without** your own `fract()` (the sampler repeats);
  `fract()` makes a 1-pixel seam line at every block edge once mipmaps kick in.
- Keep MSAA/FXAA as now; do not add sharpening — it brings back sparkle.
- Leaves fade with the existing foliage dither/ghost shader; multiply the leaf texture before the fade.
- Web/compatibility renderer: no anisotropic filtering, so slanted ground gets blurrier at mid distance. If it
  looks too soft, use `filter_nearest_mipmap` (sharper, a bit more shimmer).

### 6.6 Suggested order

1. Tops only (one shader, `UV2.x` layer) → check meadow and desert.
2. Sides + body walls.
3. Edge band with mask (`CUSTOM0`).
4. Props (box UVs = world position too, same 16 px per metre).
5. Apply the new palette in `data/biomes/*.tres`.


---

## 8. Plants, bushes and flowers (v2)

**Two kinds of plant art:**

1. **Box textures** (tile, 16 px per metre) for plants that are big boxes in the game:
   `bush_leaves` (tinted, every bush), `berry_bush` and `frostberry_bush` (full colour: the berries are
   painted in, so the 5 small berry boxes can stay or go), `cactus`, `palm_frond`, `hanging_moss`, `crystal`
   (tinted) and `mushroom_cap` (full colour). Bush leaves use **smaller clumps than oak leaves**, so a 1 m bush
   does not look like a tree crown that fell down.
2. **Sprites** for small plants: today these are tiny coloured boxes (a 16 cm flower head is 2-3 pixels and
   does not read). New rule: **small plants are drawn on two crossed vertical cards, 1 m wide x 1 m tall**,
   with an alpha cut-out sprite. Still 16 px per metre, bottom row = ground. 20 sprites:
   `flowers_mixed/yellow/pink/violet`, `grass_tuft` (tinted), `fern` (tinted), `reeds`, `dead_bush`,
   the herbs `sunbloom`, `moonpetal`, `frost_lotus`, `starlight_orchid`, `emberroot`, the mushrooms
   `mushroom_patch`, `glowcap`, `dreamcap`, and the crop stages `wheat_0..3`.

Sprite rules: hard alpha (0 or 255), 1-pixel stems, flower heads 3 x 3 with a lit top pixel, no outline
(foliage stays soft like Minecraft Dungeons), max ~12 px tall so they never hide the hero.

**How to use sprites in Godot:** material with `alpha_scissor_threshold = 0.5`, `cull_disabled`, no shadows
for tufts/flowers (too small, they flicker). Mipmaps eat thin stems at distance: either turn mipmaps **off**
for sprite layers (put sprites in their own small `Texture2DArray`) or simply hide sprites beyond ~35 m
(they are `show_in_lod1 = false` already). Add a little wind with the existing foliage sway shader (top
vertices only). `moonpetal` and `glowcap` should get emission (they glow in the game).

## 9. Building blocks (v2)

All tinted, so the existing piece colours (`WOOD`, `WOOD_DARK`, `STONE`, `THATCH`, `IRON`, cloth colours)
keep working. Pattern sizes match the meshes:

| Texture | Pattern | Matches |
|---|---|---|
| `planks_wall` | horizontal boards 4 px (0.25 m), staggered joints, nails | wood wall, fence rails |
| `planks_vertical` | boards 4 px wide along v | wood floor (its boards are 0.25 m), door leaf, chest, tables |
| `wood_beam` | dense vertical grain, no joints | `WOOD_DARK` frames, posts, legs |
| `palisade` | vertical logs 4 px, lit left / dark gap right | palisade (logs are 0.24 m) |
| `roof_shingles` | staggered 4 x 4 px shingles with row shadows | wood roof |
| `thatch` | straw strokes in 4-px rows | thatch roof |
| `stone_bricks` | 8 x 4 px bricks (0.5 x 0.25 m), staggered | stone wall, forge, altar base |
| `stone_tiles` | 8 x 8 px tiles (0.5 m) with bevel | stone floor (its tiles are 0.5 m) |
| `iron_plate` | plates with rivets | door bands, traps, chest bands, forge |
| `cloth` | small weave, seam every 0.5 m | bed, tailoring, flags, rugs |
| `tilled_soil` | furrows every 0.25 m | farm plot |
| `glass` | light blue, alpha 110, glints | window pane (**the window mesh has no pane yet**) |

UVs: **world-space like the terrain** (top: `xz`, sides: horizontal + `-y`). Then boards and bricks line up
from one piece to the next, which is what makes a wall of many pieces look like one wall. The full piece →
texture map is in `atlas.json` → `building`.

## 10. Item icons (v2)

- `art/icons/items/<item_id>.png` — **one 32 x 32 icon for each of the 215 items** in `data/items/`.
- `art/icons/icon_atlas.png` (16 per row) + `icon_atlas.json` (id → cell, shape, colour, rarity).
- `art/icons/shapes/` — the 65 drawings in a neutral colour, for reference.
- `art/previews/item_icons_sheet.png` — all icons on an inventory-slot background.

Made by `art/tools/icongen.py`. It uses **the same rules as the game's `ItemIcons`** to pick a drawing
(id / category / slot) and the colour (`icon_color`, or the metal colour for tools: copper, iron, mithril,
star metal...). So new items added as data still get an icon by running the script again. What is new is the
art:

1. 32 x 32, 1-2 px empty margin; weapons and tools point to the **top-right**, handle bottom-left.
2. Every drawing is built from material slots (main colour, metal, wood, gold, leather, paper, glass...).
3. **4 tones per material**: shadow, mid-shadow, base, light. Pixels at the top/left edge of a material are
   lit, bottom/right edge are shaded, and the top-left third of the item is one step lighter (one sun).
4. Shadows lean **cool**, lights lean **warm** (same rule as the world).
5. **Coloured outline**, 1 px: the darkest neighbouring colour x 0.32, a little blue — never pure black.
6. One white glint on metal, gems and glass.
7. Rare items (rarity ≥ Rare) get **gold** guards / trim, like today.

How to use in the game (coding session): load `icon_atlas.png` once, make an `AtlasTexture` per item from
`icon_atlas.json`, and fall back to `ItemIcons.render()` for any id that is missing. Import with
**filter nearest, no mipmaps, lossless**; draw at 2x or 3x (64 / 96 px) in the UI, never at odd scales.

---

## 11. Status

| Item | Status |
|---|---|
| Art bible, palette, texture list | done |
| 73 terrain textures (PNG), variants, tiling check | done |
| Bushes, plant blocks, 20 plant sprites, 12 building textures | done (v2) |
| 215 item icons (65 drawings) + icon atlas | done (v2) |
| Village preview | done (v2) |
| atlas.png + atlas_array.png + atlas.json | done |
| Biome previews, far-view test, texture sheet | done |
| Palette written into `data/biomes/*.tres` | done (v0.26.0) |
| Shader / mesh changes in the game | done (v0.26.0) — see section 12 |
| Forward+ (SSAO) previews | **NOT IMPLEMENTED** |
| Textures for village NPC props (market stalls, signs), stalagmites (they reuse `cave_stone_side`), more crops than wheat (carrot, pumpkin stages) | **NOT IMPLEMENTED** |
| Item icons in the game | done (v0.26.0): atlas first, `ItemIcons` drawing as fallback |
| Spell-school symbols on tome icons (all tomes share one drawing, only the colour changes, same as today) | **NOT IMPLEMENTED** |
| Prop colour changes | **NOT IMPLEMENTED** (kept current colours) |


---

## 12. In the game (v0.26.0)

How it was built (so the next change knows where to look):

- **Pipeline:** `texgen.py` → `build_atlas.py` → `icongen.py` → **`export_game.py`**. The last one copies
  `assets/textures/block_textures.png` (16 x 16·N strip) and `assets/icons/item_icons.png` into the game and
  writes the generated tables `src/core/block_textures.gd` (`BlockTextures`: layer numbers, biome surfaces)
  and `src/ui/item_icon_atlas.gd` (`ItemIconAtlas`). `art/` has a `.gdignore`: Godot never imports it.
- **Texture array:** `Materials.block_texture_array()` cuts the strip into layers, makes mipmaps per layer and
  builds one `Texture2DArray` (works in Forward+ and Compatibility/web).
- **Shaders:** `assets/shaders/block_texture.gdshaderinc` holds `block_albedo()`. It is used by `blocky`,
  `blocky_fade`, `foliage` and `foliage_fade`. `sprite.gdshader` draws plant cards (alpha scissor, sway,
  optional glow). Global shader parameter `block_textures` (1/0) is the setting.
- **Vertex data:** `UV` = metres (cards: 0..1), `UV2.x` = layer + 1 (+ 256·(wall layer + 1) on grass-edge
  bands), `UV2.y` = 0 tinted / -1 full colour / 1 + packed wall colour on edges. No UV2 = untextured.
- **Terrain:** `TerrainGenerator._surface_kind / _side_key / _top_layer / _tex_quad` choose layers with the
  same rules as `_top_color / _side_color`; `ChunkData.uvs / uv2s`; `Chunk.build` adds them to the mesh.
- **Props / buildings:** `BlockMesh.texture = &"name"` before boxes; `BlockMesh.card()` for plants;
  `BuildMeshes` sets textures by piece colour (`WOOD` → planks, `STONE` → bricks, `IRON` → iron plate ...).
  Merged settlement meshes keep cards as their own "cards_*" meshes.
- **Change a texture:** edit the Python, run the four scripts, done. Layer numbers may move; nothing in the
  game uses raw numbers, only names.
