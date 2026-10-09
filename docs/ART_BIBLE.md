# Shardlands — Art Bible (blocks and textures)

Version 1 · 2026-10-09 · Direction: **balanced mix** of Minecraft Dungeons and Hytale, **low-medium detail**,
palette freely redesigned.

Everything here is made by code and can be rebuilt exactly:

```
python3 art/tools/texgen.py          # 73 textures  -> art/textures/*.png (+ textures.json)
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
  starts at pixel `(cx*18 + 1, cy*18 + 1)`. 73 textures use 6 rows; room for 196.
- `art/textures/atlas_array.png` — the same 73 textures as a 16 x 1168 vertical strip (one layer each).
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

**NOT IMPLEMENTED:** a Forward+ (SSAO) version of the previews; previews of props other than trees, boulders
and ore rocks (bushes, flowers, building pieces, stalagmites are not textured yet).

---

## 6. How to add these to the game (note for the coding session)

**Do not change art files by hand — change the Python and re-run.** Steps:

### 6.1 Import

1. Import `art/textures/atlas_array.png` as **Texture2DArray**: Horizontal = 1, Vertical = 73.
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

## 7. Status

| Item | Status |
|---|---|
| Art bible, palette, texture list | done |
| 73 textures (PNG), variants, tiling check | done |
| atlas.png + atlas_array.png + atlas.json | done |
| Biome previews, far-view test, texture sheet | done |
| Palette written into `data/biomes/*.tres` | **NOT IMPLEMENTED** (no game files changed) |
| Shader / mesh changes in the game | **NOT IMPLEMENTED** (coding session) |
| Forward+ (SSAO) previews | **NOT IMPLEMENTED** |
| Textures for bushes, flowers, reeds, building pieces, stalagmite tops, village props | **NOT IMPLEMENTED** |
| Prop colour changes | **NOT IMPLEMENTED** (kept current colours) |
