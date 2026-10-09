"""Texture contact sheet: every texture tinted with a sample colour, shown 2x2 tiled
(to prove the seams), enlarged with nearest filter.  python3 art/tools/sheet.py"""
import json
import os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "art", "textures")
OUT = os.path.join(ROOT, "art", "previews")

SAMPLE = {   # group -> sample tint (sRGB hex) just for this sheet
    "grass_meadow": "#5C9C34", "grass_forest": "#3D7B35", "grass_jungle": "#23843E",
    "grass_taiga": "#3F7763", "grass_swamp": "#5E6E36", "grass_alpine": "#6F8B4F",
    "crystal_ground": "#8069C6", "dirt": "#8A5A36", "sand": "#F2D48E", "desert_sand": "#EDB66C",
    "sandstone": "#D9A066", "stone": "#8C877F", "mountain_rock": "#8E867D", "snow": "#EEF3FA",
    "ice": "#A9D6EE", "swamp_mud": "#5A4C34", "cave_stone": "#5E5864", "gravel": "#9A948A",
    "bark": "#6E4A2E", "bush": "#408C40", "plant": "#4C9A44", "sprite": "#5C9C34",
    "building_wood": "#9E6E42", "building_roof": "#D1B261", "building_stone": "#99999F",
    "building_metal": "#80808C", "building_cloth": "#B84A42", "building_farm": "#5C3D26", "building_glass": "#FFFFFF", "leaves": "#3F8A34", "boulder": "#8A847C", "ore": "#FFFFFF",
}
SIDE_SAMPLE = {"grass_swamp": "#4F4330", "crystal_ground": "#54466E", "snow": "#7E6E68"}
GAIN = 1.25


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def shade_tex(name, meta):
    a = np.asarray(Image.open(os.path.join(TEX, meta["file"])).convert("RGBA")).astype(float) / 255
    rgb, alpha = a[..., :3], a[..., 3:]
    if meta["tint"] == "full":
        return rgb
    tint = hexrgb(SAMPLE.get(meta["group"], "#CCCCCC"))
    out = rgb * tint * GAIN
    if meta["tint"] == "tinted_edge":
        side = hexrgb(SIDE_SAMPLE.get(meta["group"], "#8A5A36")) * 0.74
        out = alpha * out * 0.74 + (1 - alpha) * rgb * side * GAIN
    return np.clip(out, 0, 1)


def main():
    meta = json.load(open(os.path.join(TEX, "textures.json")))["textures"]
    names = list(meta)
    cols, scale, pad, lab = 8, 6, 10, 14
    cw = 32 * scale
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cw + pad) + pad, rows * (cw + pad + lab) + pad), (30, 30, 34))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        t = shade_tex(n, meta[n])
        a = np.asarray(Image.open(os.path.join(TEX, meta[n]["file"])).convert("RGBA"))[..., 3:4] / 255
        bgc = np.array([0.55, 0.72, 0.85])
        if meta[n]["face"] == "sprite" or n == "glass":
            t = a * t + (1 - a) * bgc
        tiled = np.tile(t, (2, 2, 1)) if meta[n]["face"] != "sprite" else np.dstack([np.pad(t[..., c], 8, constant_values=bgc[c]) for c in range(3)])
        im = Image.fromarray((tiled * 255).astype(np.uint8)).resize((cw, cw), Image.NEAREST)
        x = pad + (i % cols) * (cw + pad)
        y = pad + (i // cols) * (cw + pad + lab)
        sheet.paste(im, (x, y + lab))
        d.text((x, y), f"{n} [{meta[n]['tint']}]", fill=(220, 220, 220))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "texture_sheet.png"))
    print("saved", os.path.join(OUT, "texture_sheet.png"))


if __name__ == "__main__":
    main()
