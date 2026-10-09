"""Pack art/textures/*.png into:

  art/textures/atlas.png        256x256, 18x18 cells (16x16 texture + 1 px gutter on
                                every side copied from the opposite edge = wrap),
                                14 x 14 cells. Texture k sits at cell (k % 14, k // 14).
  art/textures/atlas_array.png  16 x (16*N) vertical strip, one texture per layer, for
                                Godot "Texture2DArray" import (recommended, see ART_BIBLE).
  art/textures/atlas.json       name -> cell, pixel rect, uv rect, layer, tint, face...
                                plus the biome -> texture map and the final palette.

    python3 art/tools/build_atlas.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from palette import BIOMES, TEXTURE_GROUPS, PROPS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "art", "textures")
ATLAS, CELL, PAD, COLS = 256, 18, 1, 14


def main():
    meta = json.load(open(os.path.join(TEX, "textures.json")))
    texs = meta["textures"]
    names = list(texs)
    assert len(names) <= COLS * COLS
    atlas = np.zeros((ATLAS, ATLAS, 4), np.uint8)
    strip = np.zeros((16 * len(names), 16, 4), np.uint8)
    out = {}
    for k, n in enumerate(names):
        t = np.asarray(Image.open(os.path.join(TEX, texs[n]["file"])).convert("RGBA"))
        padded = np.pad(t, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="wrap")
        cx, cy = k % COLS, k // COLS
        x0, y0 = cx * CELL, cy * CELL
        atlas[y0:y0 + CELL, x0:x0 + CELL] = padded
        strip[k * 16:(k + 1) * 16] = t
        px, py = x0 + PAD, y0 + PAD
        out[n] = {
            **texs[n],
            "layer": k,
            "cell": [cx, cy],
            "px": [px, py, 16, 16],
            "uv": [px / ATLAS, py / ATLAS, (px + 16) / ATLAS, (py + 16) / ATLAS],
        }
    Image.fromarray(atlas, "RGBA").save(os.path.join(TEX, "atlas.png"))
    Image.fromarray(strip, "RGBA").save(os.path.join(TEX, "atlas_array.png"))

    groups = {g: {"top": tops, "side": side, "edge": edge} for g, (tops, side, edge) in TEXTURE_GROUPS.items()}

    def side_of(key):
        return TEXTURE_GROUPS[key][1] if key in TEXTURE_GROUPS else key

    biomes = {}
    for b, d in BIOMES.items():
        tex = d["tex"]
        top_g = tex["top"]
        entry = {
            "colours": {k: v for k, v in d.items() if isinstance(v, str) and v.startswith("#")},
            "old_colours": d["old"],
            "why": d["why"],
            "surfaces": {
                "top": {"top": groups[top_g]["top"], "edge": groups[top_g]["edge"], "side": side_of(tex["side"])},
                "shore": {"top": groups[tex["shore"]]["top"], "edge": groups[tex["shore"]]["edge"], "side": side_of(tex["shore"])},
                "underwater": {"top": groups[tex["underwater"]]["top"], "side": side_of(tex["underwater"])},
                "rock": {"top": groups[tex["rock"]]["top"], "edge": side_of(tex["rock"]), "side": side_of(tex["rock"])},
            },
        }
        if "peak" in tex:
            entry["surfaces"]["peak"] = {"top": groups["snow"]["top"], "edge": "snow_edge", "side": side_of(tex["rock"])}
        if d.get("frozen_water"):
            entry["surfaces"]["ice"] = {"top": ["ice_top"], "side": "ice_side"}
        for k in ("rock_height", "peak_height", "frozen_water", "cave"):
            if k in d:
                entry[k] = d[k]
        biomes[b] = entry

    doc = {
        "version": 1,
        "atlas": {"file": "atlas.png", "size": ATLAS, "cell": CELL, "padding": PAD, "columns": COLS,
                  "texture_size": 16, "padding_mode": "wrap (gutter copies the opposite edge)"},
        "array": {"file": "atlas_array.png", "layers": len(names), "layer_size": 16,
                  "import": "Godot: Import As 'Texture2DArray', Horizontal 1, Vertical %d" % len(names)},
        "tint_modes": {
            "tinted": "final = vertex_colour * tex.rgb * tex_gain",
            "tinted_edge": "mask = tex.a; final = mix(side_colour * side_tex(world v), top_colour * tex.rgb, mask) * tex_gain; rows 0-7 only",
            "full": "final = tex.rgb (vertex colour white; light and AO still apply)",
        },
        "tex_gain": meta["tex_gain"],
        "texels_per_metre": 16,
        "side_tile_height_m": 1.0,
        "textures": out,
        "groups": groups,
        "biomes": biomes,
        "props": {
            "tree_oak": {"trunk": "bark", "leaves": "leaves_oak"},
            "tree_pine": {"trunk": "bark", "leaves": "leaves_pine"},
            "tree_jungle": {"trunk": "bark", "leaves": "leaves_jungle"},
            "rock": {"all": "boulder"}, "sandstone_rock": {"all": "sandstone_side"},
            "stalagmite": {"all": "cave_stone_side"},
            "ore_copper": {"stone": "ore_copper"}, "ore_iron": {"stone": "ore_iron"},
            "ore_coal": {"stone": "ore_coal"}, "ore_silver": {"stone": "ore_silver"},
            "berry_bush": {"main": "berry_bush", "top": "berry_bush"},
            "frostberry_bush": {"main": "frostberry_bush"},
            "bush (generic)": {"all": "bush_leaves"},
            "cactus": {"all": "cactus"}, "tree_palm": {"trunk": "bark", "fronds": "palm_frond"},
            "tree_swamp": {"trunk": "bark", "leaves": "bush_leaves", "moss": "hanging_moss"},
            "tree_snowy_pine": {"trunk": "bark", "leaves": "leaves_pine", "snow": "snow_top_0"},
            "tree_dead": {"all": "bark"}, "mushroom_giant": {"cap": "mushroom_cap", "stem": "cloth"},
            "crystal_cluster": {"all": "crystal"},
            "colours_unchanged": PROPS,
        },
        "sprites": {   # crossed cards replacing today's tiny boxes
            "flowers": ["flowers_mixed", "flowers_yellow", "flowers_pink", "flowers_violet"],
            "grass_tuft": "grass_tuft", "reeds": "reeds", "dead_bush": "dead_bush",
            "sunbloom": "sunbloom", "moonpetal": "moonpetal", "frost_lotus": "frost_lotus",
            "starlight_orchid": "starlight_orchid", "emberroot": "emberroot",
            "mushroom_patch": "mushroom_patch", "glowcap": "glowcap", "dreamcap": "dreamcap",
            "fern (new)": "fern", "farm_plot crop stages": ["wheat_0", "wheat_1", "wheat_2", "wheat_3"],
        },
        "building": {  # build piece -> texture per part (vertex colour stays WOOD / STONE / ...)
            "wood_wall": {"wall": "planks_wall", "frame": "wood_beam"},
            "wood_floor": {"top": "planks_vertical", "base": "wood_beam"},
            "wood_door": {"frame": "wood_beam", "leaf": "planks_vertical", "bands": "iron_plate"},
            "reinforced_door": {"frame": "wood_beam", "leaf": "planks_vertical", "plates": "iron_plate"},
            "wood_window": {"wall": "planks_wall", "frame": "wood_beam", "pane": "glass"},
            "wood_fence": {"posts": "wood_beam", "rails": "planks_wall"},
            "wood_roof": {"all": "roof_shingles"}, "thatch_roof": {"all": "thatch"},
            "stone_wall": {"all": "stone_bricks"}, "stone_floor": {"top": "stone_tiles", "base": "stone_bricks"},
            "palisade_wall": {"logs": "palisade", "bands": "iron_plate"},
            "spike_wall": {"beam": "wood_beam", "spikes": "palisade", "tips": "iron_plate"},
            "spike_trap": {"base": "wood_beam", "spikes": "iron_plate"},
            "arrow_tower": {"wood": "planks_wall", "frame": "wood_beam", "roof": "roof_shingles"},
            "storage_chest": {"body": "planks_vertical", "bands": "iron_plate"},
            "workbench": {"top": "planks_vertical", "legs": "wood_beam"}, "table": {"top": "planks_vertical", "legs": "wood_beam"},
            "chair": {"all": "planks_vertical"}, "bed": {"frame": "wood_beam", "blanket": "cloth", "pillow": "cloth"},
            "tailoring": {"wood": "planks_vertical", "cloth": "cloth"}, "forge": {"body": "stone_bricks", "metal": "iron_plate"},
            "alchemy_table": {"top": "planks_vertical", "legs": "wood_beam"}, "arcane_altar": {"base": "stone_bricks", "crystal": "crystal"},
            "farm_plot": {"soil": "tilled_soil", "crops": "wheat_0..3"},
            "torch": {"stick": "wood_beam"}, "alarm_bell": {"frame": "wood_beam", "bell": "iron_plate"},
            "claim_flag": {"pole": "wood_beam", "flag": "cloth"}, "claim_totem": {"all": "wood_beam"},
        },
    }
    with open(os.path.join(TEX, "atlas.json"), "w") as f:
        json.dump(doc, f, indent=1)
    print(f"atlas: {len(names)} textures, {((len(names) - 1) // COLS) + 1} rows used")


if __name__ == "__main__":
    main()
