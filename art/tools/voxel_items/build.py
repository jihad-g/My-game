"""
Builds the held-item voxel art for Shardlands.

    python3 art/tools/voxel_items/build.py            # preview sheet + src/art/voxel_item_data.gd
    python3 art/tools/voxel_items/build.py --only=sword,bow   # quick preview, no export

Needs: pip install numpy pillow
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from voxkit import render, add_glow   # noqa: E402
import shard_items as S               # noqa: E402
import export_gd                      # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DATA = os.path.join(REPO, "src", "art", "voxel_item_data.gd")
OUT_PREVIEW = os.path.join(REPO, "art", "previews", "voxel_items.png")
FONT_B = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
FONT_M = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"

# Sample tints so the preview looks like the game (metal, accent).
PREVIEW_TINTS = {
    "staff": {2: (0.6, 0.4, 1.0)},
    "wand": {2: (0.6, 0.75, 1.0)},
    "bow": {2: (0.5, 0.32, 0.18)},
    "buckler": {2: (0.55, 0.36, 0.2)},
    "kite_shield": {2: (0.7, 0.72, 0.78)},
    "aegis": {2: (1.0, 0.85, 0.4)},
    "tome": {2: (0.85, 0.35, 0.2)},
    "shield_round": {2: (0.75, 0.25, 0.2)},
}


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def sheet(fns, out, ppv=9, per_row=8, gap=34, label_h=30):
    rendered = []
    for fn in fns:
        v = fn()
        v.bake(seed=sum(map(ord, v.name)))
        img, glow = render(v, ppv=ppv, tints=PREVIEW_TINTS.get(v.name))
        rendered.append((v, img, glow))
    rows = [rendered[i:i + per_row] for i in range(0, len(rendered), per_row)]
    row_w = [sum(r[1].width for r in row) + gap * (len(row) - 1) for row in rows]
    row_h = [max(r[1].height for r in row) + label_h for row in rows]
    W = max(row_w) + 120
    top = 130
    H = top + sum(row_h) + gap * (len(rows) - 1) + 70
    yy, xx = np.mgrid[0:H, 0:W]
    k = np.clip(1.0 - np.sqrt(((xx - W / 2) / (W / 1.6)) ** 2 + ((yy - H / 2) / (H / 1.6)) ** 2), 0, 1)[..., None]
    canvas = Image.fromarray((np.array([25, 24, 30]) + np.array([15, 15, 16]) * k).astype(np.uint8), "RGB")
    glow_c = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(canvas)
    d.text((60, 44), "SHARDLANDS  ·  HELD ITEMS", font=font(FONT_B, 36), fill=(226, 221, 208))
    d.text((62, 90), "Voxel style (Milestone 39) — metal and accent parts are recoloured per item in the game",
           font=font(FONT_M, 18), fill=(140, 136, 128))
    fs = font(FONT_M, 15)
    y = top
    for row, rw, rh in zip(rows, row_w, row_h):
        x = (W - rw) // 2
        base = y + rh - label_h
        for v, img, glow in row:
            px, py = x, base - img.height
            canvas.paste(img, (px, py), img)
            glow_c.paste(glow, (px, py))
            tw = d.textlength(v.label, font=fs)
            d.text((px + (img.width - tw) / 2, base + 6), v.label, font=fs, fill=(150, 146, 138))
            x += img.width + gap
        y += rh + gap
    canvas = add_glow(canvas, glow_c, ppv)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.save(out)
    print("saved", out, canvas.size)


def main():
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a.split("=", 1)[1].split(","))
    fns = [f for f in S.ITEMS if only is None or f.__name__ in only]
    sheet(fns, OUT_PREVIEW if only is None else os.path.join(REPO, "art", "previews", "_voxel_quick.png"))
    if only is None:
        assert export_gd.decode_check(S.ITEMS), "RLE round-trip failed"
        export_gd.export_all(S.ITEMS, OUT_DATA)


if __name__ == "__main__":
    main()
