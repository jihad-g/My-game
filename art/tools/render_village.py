"""Village / garden preview: building pieces, bushes, flowers and crops, from the
game camera.  Left = today (flat colours), right = with textures.

    python3 art/tools/render_village.py   -> art/previews/village.png
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import render_previews as RP  # noqa: E402
from render_previews import Canvas, sample, hexrgb, label, SUN, SHADE, GAIN, BH, OUT  # noqa: E402
import json  # noqa: E402

META = RP.META
WOOD = np.array([0.62, 0.43, 0.26]); WOOD_DARK = np.array([0.48, 0.32, 0.19])
STONE = np.array([0.6, 0.6, 0.63]); THATCH = np.array([0.82, 0.7, 0.38]); IRON = np.array([0.5, 0.5, 0.55])
ROOF = np.array([0.55, 0.28, 0.22]); SOIL = np.array([0.36, 0.24, 0.15]); CLOTH = np.array([0.85, 0.35, 0.3])
GRASS_TOP, GRASS_ALT = hexrgb("#5A9A34"), hexrgb("#7AAE3E")
SIZE = 16


def tex_mul(name, u, v):
    t = sample(name, u, v)
    if META[name]["tint"] == "full":
        return t[:, :3], t[:, 3]
    return t[:, :3] * GAIN, t[:, 3]


class Scene:
    def __init__(self, textured, scale=64, ss=2):
        self.textured = textured
        s = scale * ss
        self.ss = ss
        self.w, self.h = int(SIZE * 1.45 * s), int(SIZE * 1.3 * s)
        self.cv = Canvas(self.w, self.h, s, (self.w / 2, self.h * 0.42))
        self.off = -SIZE / 2

    # box with world-space UVs (16 px per metre) on top, +X and +Z faces
    def box(self, x0, y0, z0, sx, sy, sz, colour, tex=None, top_tex=None):
        x0 += self.off; z0 += self.off
        x1, y1, z1 = x0 + sx, y0 + sy, z0 + sz
        tt = top_tex or tex
        def mk(shade, light, name, hor, ver, top=False):
            def sh(u, v, wd):
                c = np.repeat((colour * shade * light)[None], len(u), 0)
                if self.textured and name:
                    vv = wd[:, 2] if top else -wd[:, 1]
                    t, _ = tex_mul(name, wd[:, hor], vv)
                    c = c * t
                return c
            return sh
        self.cv.face((x0, y1, z0), (sx, 0, 0), (0, 0, sz), mk(1.0, SUN, tt, 0, 2, True))
        self.cv.face((x1, y1, z0), (0, 0, sz), (0, -sy, 0), mk(0.74, SHADE, tex, 2, 1))
        self.cv.face((x0, y1, z1), (sx, 0, 0), (0, -sy, 0), mk(0.62, SHADE, tex, 0, 1))

    def sprite(self, x, y, z, name, tint=None, size=1.0, flat_colour=None):
        """Two crossed cards (alpha cut-out). flat_colour = what the game shows today."""
        x += self.off; z += self.off
        tint = tint if tint is not None else np.ones(3)
        for (p0, e1) in (((x - size / 2, y + size, z), (size, 0, 0)), ((x, y + size, z - size / 2), (0, 0, size))):
            def sh(u, v, wd, tint=tint):
                t = sample(name, u, v)
                rgb = t[:, :3] * (GAIN if META[name]["tint"] == "tinted" else 1.0) * tint * 0.95
                return rgb, t[:, 3] > 0.5
            if self.textured:
                self.face_alpha(p0, e1, (0, -size, 0), sh)
        if not self.textured and flat_colour is not None:
            # today: tiny coloured boxes; approximate with a few small boxes
            for (dx, dz, hgt, col) in flat_colour:
                self.box(x - self.off + dx - 0.06, y, z - self.off + dz - 0.06, 0.12, hgt, 0.12, col)

    def face_alpha(self, p0, e1, e2, shader):
        cv = self.cv
        def wrapped(u, v, wd):
            return shader(u, v, wd)
        # re-implement the masked raster: call Canvas.face with a shader that hides cut-out pixels
        s0, d0 = cv.proj(p0)
        s1 = cv.proj(np.add(p0, e1))[0] - s0
        s2 = cv.proj(np.add(p0, e2))[0] - s0
        L = RP.L
        dd1 = float(np.asarray(e1) @ L); dd2 = float(np.asarray(e2) @ L)
        pts = np.array([s0, s0 + s1, s0 + s2, s0 + s1 + s2])
        x0, y0 = np.floor(pts.min(0)).astype(int); x1, y1 = np.ceil(pts.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, cv.w), min(y1, cv.h)
        if x0 >= x1 or y0 >= y1:
            return
        M = np.array([s1, s2]).T
        if abs(np.linalg.det(M)) < 1e-6:
            return
        Mi = np.linalg.inv(M)
        ys, xs = np.mgrid[y0:y1, x0:x1]
        uv = np.stack([xs + 0.5 - s0[0], ys + 0.5 - s0[1]], -1) @ Mi.T
        u, v = uv[..., 0], uv[..., 1]
        inside = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
        depth = d0 + u * dd1 + v * dd2
        zb = cv.dep[y0:y1, x0:x1]
        ok = inside & (depth < zb - 1e-4)
        if not ok.any():
            return
        uu, vv = u[ok], v[ok]
        wd = np.asarray(p0)[None] + uu[:, None] * np.asarray(e1)[None] + vv[:, None] * np.asarray(e2)[None]
        rgb, mask = shader(uu, vv, wd)
        idx = np.argwhere(ok)
        sel = idx[mask]
        cb = cv.col[y0:y1, x0:x1]
        cb[sel[:, 0], sel[:, 1]] = rgb[mask]
        zb[sel[:, 0], sel[:, 1]] = depth[ok][mask]

    def image(self):
        img = self.cv.col.copy()
        img[np.isinf(self.cv.dep)] = np.array([0.13, 0.14, 0.17])
        im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        return im.resize((self.w // self.ss, self.h // self.ss), Image.BOX)


def build(sc: Scene):
    T = sc.textured
    rnd = np.random.default_rng(5)
    g = 1.0  # ground top y (two blocks)
    # ground: meadow grass blocks, a gravel path
    for x in range(SIZE):
        for z in range(SIZE):
            path = (x == 9) or (z == 9 and x < 9)
            t = rnd.random()
            col = hexrgb("#9A948A") * (0.95 + 0.1 * t) if path else (GRASS_TOP + (GRASS_ALT - GRASS_TOP) * t)
            tops = ["gravel_top_0", "gravel_top_1"] if path else ["grass_meadow_top_0", "grass_meadow_top_1", "grass_meadow_top_2"]
            name = tops[int(t * len(tops)) % len(tops)]
            sc.box(x, 0.0, z, 1, g, 1, col, "dirt_side" if not path else "gravel_side", top_tex=name)

    # --- wooden house (4 x 4) with stone floor, plank walls, beams, shingle roof
    hx, hz, H = 1, 1, 2.5
    for x in range(hx, hx + 4):
        for z in range(hz, hz + 4):
            sc.box(x, g, z, 1, 0.12, 1, STONE, "stone_tiles")
    sc.box(hx, g, hz, 4, H, 0.2, WOOD, "planks_wall")                 # back wall (north)
    sc.box(hx, g, hz, 0.2, H, 4, WOOD, "planks_wall")                 # back wall (west)
    sc.box(hx + 3.8, g, hz, 0.2, H, 4, WOOD, "planks_wall")           # east wall
    sc.box(hx, g, hz + 3.8, 1.5, H, 0.2, WOOD, "planks_wall")         # south wall, left part
    sc.box(hx + 2.5, g, hz + 3.8, 1.5, H, 0.2, WOOD, "planks_wall")   # south wall, right part
    sc.box(hx + 1.5, g + 2.1, hz + 3.8, 1.0, H - 2.1, 0.2, WOOD, "planks_wall")
    sc.box(hx + 1.6, g, hz + 3.85, 0.8, 2.1, 0.1, WOOD * 1.05, "planks_vertical")   # door leaf
    for yy in (0.6, 1.5):
        sc.box(hx + 1.6, g + yy, hz + 3.92, 0.8, 0.08, 0.06, IRON, "iron_plate")
    # window on the east wall
    sc.box(hx + 3.82, g + 1.0, hz + 1.4, 0.2, 0.8, 1.0, np.array([0.75, 0.88, 0.95]) if not T else np.ones(3), "glass")
    for (bx, bz) in [(hx, hz), (hx + 3.8, hz), (hx, hz + 3.8), (hx + 3.8, hz + 3.8)]:
        sc.box(bx - 0.04, g, bz - 0.04, 0.28, H + 0.1, 0.28, WOOD_DARK, "wood_beam")
    # roof: stepped shingle layers
    for k in range(4):
        inset = k * 0.55
        sc.box(hx - 0.3 + inset, g + H + k * 0.35, hz - 0.3 + inset, 4.6 - 2 * inset, 0.35, 4.6 - 2 * inset, ROOF, "roof_shingles")

    # --- small stone hut with thatch roof
    sx, sz, h2 = 11, 1, 1.8
    sc.box(sx, g, sz, 3, h2, 0.25, STONE, "stone_bricks")
    sc.box(sx, g, sz, 0.25, h2, 3, STONE, "stone_bricks")
    sc.box(sx + 2.75, g, sz, 0.25, h2, 3, STONE, "stone_bricks")
    sc.box(sx, g, sz + 2.75, 3, h2, 0.25, STONE, "stone_bricks")
    for k in range(3):
        inset = k * 0.5
        sc.box(sx - 0.25 + inset, g + h2 + k * 0.3, sz - 0.25 + inset, 3.5 - 2 * inset, 0.3, 3.5 - 2 * inset, THATCH, "thatch")

    # --- farm plot with wheat at four stages
    for i in range(4):
        for j in range(2):
            fx, fz = 11 + j, 6 + i
            sc.box(fx, g, fz, 1, 0.1, 1, SOIL, "tilled_soil")
            st = (i + j) % 4
            if T:
                sc.sprite(fx + 0.5, g + 0.1, fz + 0.5, f"wheat_{st}")
            else:
                sc.sprite(fx + 0.5, g + 0.1, fz + 0.5, "", flat_colour=[(dx, dz, 0.15 + 0.15 * st, np.array([0.35, 0.65, 0.25]) * (1 - st / 4) + np.array([0.9, 0.78, 0.35]) * st / 4) for dx in (-0.25, 0.25) for dz in (-0.25, 0.25)])

    # --- palisade along the back with iron bands
    for x in range(6, 10):
        for k in range(4):
            sc.box(x + k * 0.25, g, 0.0, 0.24, 2.2, 0.28, WOOD_DARK * (0.95 + 0.08 * (k % 2)), "palisade")
        sc.box(x, g + 0.6, 0.28, 1.0, 0.12, 0.06, IRON * 0.8, "iron_plate")
        sc.box(x, g + 1.7, 0.28, 1.0, 0.12, 0.06, IRON * 0.8, "iron_plate")

    # --- fence along the front of the garden
    for x in range(1, 9):
        sc.box(x - 0.06, g, 13.94, 0.12, 1.0, 0.12, WOOD_DARK, "wood_beam")
        sc.box(x, g + 0.4, 13.97, 1.0, 0.1, 0.06, WOOD, "planks_wall")
        sc.box(x, g + 0.75, 13.97, 1.0, 0.1, 0.06, WOOD, "planks_wall")

    # --- stations: chest, workbench, bed (outside, so they can be seen)
    sc.box(6.2, g, 6.2, 0.8, 0.6, 0.55, WOOD, "planks_vertical")
    sc.box(6.2, g + 0.5, 6.2, 0.8, 0.08, 0.57, IRON, "iron_plate")
    sc.box(5.5, g + 0.72, 3.0, 1.4, 0.14, 0.8, WOOD, "planks_vertical")
    for (lx, lz) in [(5.55, 3.05), (6.75, 3.05), (5.55, 3.65), (6.75, 3.65)]:
        sc.box(lx, g, lz, 0.12, 0.72, 0.12, WOOD_DARK, "wood_beam")
    sc.box(7.5, g, 4.5, 0.9, 0.35, 1.9, WOOD_DARK, "wood_beam")
    sc.box(7.53, g + 0.35, 4.75, 0.84, 0.14, 1.6, CLOTH, "cloth")
    sc.box(7.65, g + 0.35, 4.55, 0.6, 0.18, 0.32, np.array([0.95, 0.93, 0.88]), "cloth")

    # --- bushes, flowers, tufts, herbs
    leaf = np.array([0.25, 0.55, 0.25])
    sc.box(2.0, g, 6.5, 1.0, 0.7, 1.0, leaf if not T else np.ones(3), "berry_bush")
    sc.box(2.15, g + 0.7, 6.65, 0.7, 0.3, 0.7, leaf * 1.1 if not T else np.ones(3), "berry_bush")
    sc.box(4.0, g, 11.0, 1.0, 0.7, 1.0, leaf, "bush_leaves")
    sc.box(4.15, g + 0.7, 11.15, 0.7, 0.3, 0.7, leaf * 1.1, "bush_leaves")
    flowers = [(1.5, 10.5, "flowers_mixed"), (2.5, 12.0, "flowers_yellow"), (6.5, 11.5, "flowers_pink"),
               (7.5, 12.5, "flowers_violet"), (13.5, 12.5, "flowers_mixed"), (14.5, 13.5, "sunbloom"),
               (12.5, 13.5, "moonpetal"), (5.5, 13.0, "mushroom_patch")]
    flat = {"flowers_mixed": [np.array([1, 0.85, 0.3]), np.array([0.95, 0.5, 0.75])],
            "flowers_yellow": [np.array([1, 0.85, 0.3])], "flowers_pink": [np.array([0.95, 0.5, 0.75])],
            "flowers_violet": [np.array([0.65, 0.55, 1.0])], "sunbloom": [np.array([1, 0.75, 0.2])],
            "moonpetal": [np.array([0.92, 0.95, 1.0])], "mushroom_patch": [np.array([0.6, 0.4, 0.25])]}
    for (x, z, n) in flowers:
        cols = flat[n]
        sc.sprite(x, g, z, n, flat_colour=[(dx, dz, 0.33, cols[k % len(cols)]) for k, (dx, dz) in enumerate([(0, 0), (0.3, 0.2), (-0.25, 0.3)])])
    for (x, z) in [(3.5, 9.6), (10.5, 12.5), (15.3, 10.5), (0.6, 14.5), (8.3, 10.8), (14.4, 5.5)]:
        sc.sprite(x, g, z, "grass_tuft", tint=GRASS_TOP * 1.15, flat_colour=[(0, 0, 0.3, np.array([0.32, 0.66, 0.24]))])
    sc.sprite(15.2, g, 15.0, "fern", tint=GRASS_TOP, flat_colour=[(0, 0, 0.4, np.array([0.3, 0.6, 0.25]))])


def main():
    a = Scene(False); build(a)
    b = Scene(True); build(b)
    ia = label(a.image(), "village now (flat colours)")
    ib = label(b.image(), "village + building, bush and flower textures")
    w, h = ia.size
    row = Image.new("RGB", (w * 2 + 4, h), (20, 20, 24))
    row.paste(ia, (0, 0)); row.paste(ib, (w + 4, 0))
    row.save(os.path.join(OUT, "village.png"))
    ib.save(os.path.join(OUT, "village_textured.png"))
    print("saved village.png")


if __name__ == "__main__":
    main()
