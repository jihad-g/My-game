"""Plants, bushes, flowers (sprites) and building-block textures.

Called by texgen.py main(); uses its helpers so the rules stay the same:
16 px per metre, 4-6 shades, light from the top-left, tiling where it tiles.

Two kinds of output here:
  * block/box textures (16x16, tile in both directions), like the terrain ones
  * plant SPRITES (16x16, alpha cut-out, do NOT tile): drawn on two crossed
    vertical cards 1 m wide x 1 m tall, bottom row = ground. face = "sprite".
"""
from __future__ import annotations

import numpy as np

import texgen as T
from texgen import N, rng, pnoise, rank_levels, clean_lonely, scatter, stamp, voronoi, bevel, to_rgb, save


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# ===========================================================================
# Bushes and plant blocks (tile)
# ===========================================================================
S_LEAF = T.S_LEAF


def bush_leaves_lv(seed=2201):
    """Smaller, denser clumps than oak leaves, so a 1 m bush reads as 'bush'."""
    r = rng(seed)
    pts = [(1.5, 2.0), (6.0, 1.0), (11.0, 2.5), (14.5, 7.0), (3.0, 7.0), (8.5, 6.5),
           (1.0, 12.0), (6.0, 11.5), (11.5, 11.0), (8.0, 15.5)]
    idx, crack = voronoi(pts)
    lv = np.full((N, N), 3)
    lv = bevel(lv, crack, 4, None, 1)
    hi = np.roll(np.roll(crack, 1, axis=0), 2, axis=1) & ~crack
    lv[hi & (lv == 3)] = 5
    # a few deep holes between clumps
    for (x, y) in scatter(r, 3, 6, 1, 1, margin=1):
        if crack[y, x]:
            lv[y, x] = 0
    return lv


def berry_bush(seed, leaf_hex, berry_hex, berry_light_hex):
    lv = bush_leaves_lv(seed)
    base = hexc(leaf_hex)
    rgb = to_rgb(lv, S_LEAF) * base * T.TEX_GAIN
    r = rng(seed + 9)
    b, bl = hexc(berry_hex), hexc(berry_light_hex)
    for (x, y) in scatter(r, 6, 4.2, 2, 2, margin=1):
        rgb[y, x] = bl; rgb[y, (x + 1) % N] = b
        rgb[(y + 1) % N, x] = b; rgb[(y + 1) % N, (x + 1) % N] = b * 0.7
    return np.clip(rgb, 0, 1)


def cactus_lv(seed=2301):
    lv = np.full((N, N), 3)
    xs = np.arange(N)
    for x in xs:
        k = x % 4
        lv[:, x] = [1, 4, 3, 2][k]          # ribs: groove, lit edge, face, shade
    r = rng(seed)
    for (x, y) in scatter(r, 6, 3.6, 1, 1, margin=0):   # spines sit on the lit ridge
        xx = (x // 4) * 4 + 1
        lv[y, xx] = 5
        lv[(y + 1) % N, xx] = 2
    return lv


def palm_frond_lv(seed=2401):
    """Leaflets as diagonal strokes from a horizontal rib (2 ribs per tile)."""
    lv = np.full((N, N), 1)
    for rib in (3, 11):
        for x in range(N):
            for d in range(1, 5):
                if (x + d) % 3 == 0:
                    continue
                lv[(rib - d) % N, (x + d) % N] = 4 if d < 3 else 3
                lv[(rib + d) % N, (x + d) % N] = 3 if d < 3 else 2
            lv[rib, x] = 5
    return lv


def mushroom_cap(seed=2501):
    red = [hexc("#7A1E1E"), hexc("#A82A26"), hexc("#C8392E"), hexc("#E25A43")]
    lv = rank_levels(T.fbm(seed, 2, 4, 0.3), [1, 3, 4, 2])
    rgb = np.array(red)[lv]
    r = rng(seed)
    spot = [".WW.", "WWWw", ".Ww."]
    for (x, y) in scatter(r, 3, 6.5, 4, 3, margin=1):
        for j, row in enumerate(spot):
            for i, ch in enumerate(row):
                if ch == "W":
                    rgb[(y + j) % N, (x + i) % N] = hexc("#FFF8EC")
                elif ch == "w":
                    rgb[(y + j) % N, (x + i) % N] = hexc("#D9CCC0")
    return rgb


def crystal_lv(seed=2601):
    """Big flat facets with bright edges; reads as cut gem from far."""
    pts = [(3, 3), (12, 2), (8, 9), (2, 13), (14, 12)]
    idx, crack = voronoi([(float(a), float(b)) for a, b in pts], sx=1.2, sy=0.8)
    lv = np.array([2, 4, 3, 1, 3])[idx]
    lv[crack] = 5
    under = np.roll(crack, 1, axis=0) & ~crack
    lv[under] = 0
    return lv


def hanging_moss_lv(seed=2701):
    lv = np.full((N, N), 3)
    r = rng(seed)
    length = (pnoise(4, 1, seed)[0] * 10 + 4).astype(int)
    for x in range(N):
        for y in range(N):
            if (y + int(r.integers(0, 2))) % 16 >= length[x]:
                lv[y, x] = 1
        lv[0, x] = 4
    return clean_lonely(lv, 1)


# ===========================================================================
# Sprites (alpha cut-out, crossed cards). y = 15 is the ground.
# ===========================================================================

class Sprite:
    def __init__(self):
        self.rgb = np.zeros((N, N, 3)); self.a = np.zeros((N, N), np.uint8)

    def px(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.rgb[y, x] = c; self.a[y, x] = 255

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for t in np.linspace(0, 1, n):
            self.px(int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), c)

    def shape(self, x, y, rows, key):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in key:
                    self.px(x + i, y + j, key[ch])


GREEN = [hexc("#2C5E26"), hexc("#3F7F30"), hexc("#5FA040"), hexc("#86C058")]   # stems/leaves (full)


def flower_clump(seed, heads, sizes=None):
    """heads: list of (petal_dark, petal, petal_light, centre). 3-4 flowers."""
    s = Sprite(); r = rng(seed)
    xs = [2, 6, 10, 13][:len(heads)]
    for k, (pd, p, pl, cc) in enumerate(heads):
        x = xs[k] + int(r.integers(-1, 1))
        top = int(r.integers(6, 10))
        lean = int(r.integers(-1, 2))
        s.line(x, 15, x + lean, top + 2, GREEN[1])
        # one small leaf
        lx = x + (1 if k % 2 == 0 else -1)
        s.px(lx, 13, GREEN[2]); s.px(lx + (1 if k % 2 == 0 else -1), 12, GREEN[3])
        hx = x + lean - 1
        s.shape(hx, top - 1, [".L.", "PCp", ".d."], {"L": pl, "P": p, "p": p, "C": cc, "d": pd})
    # ground grass
    for x in range(1, 15, 3):
        s.px(x, 15, GREEN[0]); s.px(x + 1, 14, GREEN[2])
    return s


def tuft_sprite(seed=3101, grey=True):
    s = Sprite(); r = rng(seed)
    shades = [np.full(3, v) for v in (0.62, 0.74, 0.86, 0.98)] if grey else GREEN
    for x0 in range(1, 15, 2):
        h = int(r.integers(5, 11)); lean = int(r.integers(-2, 3))
        s.line(x0, 15, x0 + lean, 15 - h, shades[1])
        s.px(x0 + lean, 15 - h, shades[3])
        s.px(x0, 15, shades[0]); s.px(x0, 14, shades[0])
        if h > 7:
            s.px(x0 + lean // 2, 15 - h // 2, shades[2])
    return s


def fern_sprite(seed=3201):
    s = Sprite(); g = [np.full(3, v) for v in (0.6, 0.74, 0.88, 1.0)]
    for (bx, tx, ty) in [(7, 1, 4), (8, 14, 5), (7, 4, 1), (8, 11, 2), (7, 7, 0)]:
        s.line(bx, 15, tx, ty, g[1])
        n = max(abs(tx - bx), 15 - ty)
        for t in range(1, n, 2):
            x = int(round(bx + (tx - bx) * t / n)); y = int(round(15 + (ty - 15) * t / n))
            s.px(x - 1, y, g[3]); s.px(x + 1, y + 1, g[2])
        s.px(tx, ty, g[3])
    s.px(7, 15, g[0]); s.px(8, 15, g[0])
    return s


def reeds_sprite():
    s = Sprite()
    st = [hexc("#4F6E2E"), hexc("#73973F"), hexc("#9CBE5C")]
    head = [hexc("#4A2F1A"), hexc("#6E4526"), hexc("#94643A")]
    for (x, h, lean) in [(3, 12, 0), (6, 14, 1), (9, 11, -1), (12, 13, 0)]:
        s.line(x, 15, x + lean, 15 - h, st[1])
        s.px(x, 15, st[0])
        hy = 15 - h + 1
        s.shape(x + lean, hy, ["L", "M", "M", "D"], {"L": head[2], "M": head[1], "D": head[0]})
    for (x, y) in [(2, 9), (11, 8)]:
        s.line(x, 15, x - 1, y, st[2])
    return s


def dead_bush_sprite():
    s = Sprite(); c = [hexc("#4E3824"), hexc("#7A5A3A"), hexc("#A07A52")]
    s.line(8, 15, 8, 10, c[1])
    for (x1, y1) in [(3, 5), (13, 4), (6, 3), (11, 8), (2, 10)]:
        s.line(8, 11, x1, y1, c[1]); s.px(x1, y1, c[2])
    s.line(8, 13, 13, 11, c[0])
    s.px(7, 15, c[0]); s.px(9, 15, c[0])
    return s


def sunbloom_sprite():
    s = Sprite()
    s.line(8, 15, 8, 7, GREEN[1]); s.shape(5, 11, ["LL...", ".LL..", "...LL"], {"L": GREEN[2]})
    s.shape(9, 10, ["..LL", "LL.."], {"L": GREEN[2]})
    y0, o, yl, br, dk = hexc("#C86A10"), hexc("#F2A21C"), hexc("#FFD84A"), hexc("#7A3E14"), hexc("#5A2A0E")
    s.shape(4, 1, ["..yYy..", ".yYYYy.", "yYBBBYy", "YYBDBYY", "yYBBBYy", ".oYYYo.", "..oYo.."],
            {"y": o, "Y": yl, "B": br, "D": dk, "o": y0})
    return s


def moonpetal_sprite():
    s = Sprite(); w, b, c, g = hexc("#F4F7FF"), hexc("#B9CCF2"), hexc("#DDF0FF"), hexc("#8FC9B0")
    s.line(8, 15, 8, 9, g)
    s.shape(5, 5, ["..W..", ".bWb.", "WWCWW", ".bWb.", "..W.."], {"W": w, "b": b, "C": c})
    s.shape(3, 10, ["W.", ".b"], {"W": w, "b": b}); s.px(6, 12, g); s.px(10, 12, g)
    return s


def frost_lotus_sprite():
    s = Sprite(); a, b, c, d = hexc("#E8F6FF"), hexc("#9ED8F4"), hexc("#5AA8D8"), hexc("#2F6E9A")
    s.shape(3, 9, ["...aa...", "..abba..", "a.abba.a", "abbccbba", ".bcccc b".replace(" ", "."), "..dddd.."],
            {"a": a, "b": b, "c": c, "d": d})
    s.shape(1, 15, ["dddddddddddd"], {"d": hexc("#3A7B5A")})
    return s


def orchid_sprite():
    s = Sprite(); p, pl, w, g = hexc("#7A3FB8"), hexc("#B07AE8"), hexc("#FFF2FF"), hexc("#3F7F30")
    s.line(7, 15, 9, 4, g)
    for (x, y) in [(6, 3), (9, 6), (5, 8)]:
        s.shape(x, y, [".w.", "pPp", ".p."], {"w": w, "P": pl, "p": p})
    s.shape(4, 13, ["GG..GG", "..GG.."], {"G": hexc("#5FA040")})
    return s


def emberroot_sprite():
    s = Sprite(); r_, o, y, br = hexc("#B8321C"), hexc("#F06A24"), hexc("#FFC04A"), hexc("#5A2E1A")
    for (x, h) in [(5, 7), (8, 9), (11, 6)]:
        s.line(x, 15, x, 15 - h, r_)
        s.px(x, 15 - h, y); s.px(x, 16 - h, o)
        s.px(x - 1, 17 - h, o)
    s.shape(3, 14, ["BBBBBBBBBB", ".BBBBBBBB."], {"B": br})
    return s


def mushroom_patch_sprite(cap_dark, cap, cap_light, stem="#EDE3CF"):
    s = Sprite(); st = hexc(stem); cd, cm, cl = hexc(cap_dark), hexc(cap), hexc(cap_light)
    for (x, y, big) in [(2, 10, True), (9, 8, True), (12, 12, False)]:
        if big:
            s.shape(x, y, [".LLM.", "LMMMD", "DDDDD", "..S..", "..S..", "..S.."][: 15 - y + 1],
                    {"L": cl, "M": cm, "D": cd, "S": st})
        else:
            s.shape(x, y, ["LM.", "MD.", ".S."], {"L": cl, "M": cm, "D": cd, "S": st})
    return s


def wheat_sprite(stage):
    s = Sprite()
    young, ripe = hexc("#6FB043"), hexc("#E6C25A")
    t = stage / 3
    stalk = young * (1 - t) + hexc("#C9A646") * t
    grain = young * (1 - t) + ripe * t
    h = [3, 6, 10, 12][stage]
    for x in (2, 5, 8, 11, 14):
        hh = h - (x % 3)
        s.line(x, 15, x, 15 - hh, stalk)
        if stage >= 2:                 # grain ear: 2 px wide, 3-4 px tall, lit on the left
            ear = ["Gg", "Gg", "gG", "Gg"][: 1 + stage]
            s.shape(x, 15 - hh - len(ear) + 1, ear, {"G": np.minimum(grain * 1.15, 1), "g": grain * 0.78})
    return s


# ===========================================================================
# Building blocks (tile)
# ===========================================================================
S_WOOD = T.S_WOOD


def planks_wall_lv(seed=4001):
    """Horizontal boards 4 px (0.25 m) tall, staggered butt joints, nails."""
    r = rng(seed)
    grain = rank_levels(T.fbm(seed, 1, 4, 0.5, sx=1, sy=4), [2, 4, 2]) + 2    # 2..4
    lv = grain.copy()
    joints = [4, 12, 8, 0]
    for b in range(4):
        y0 = b * 4
        lv[y0] = np.minimum(lv[y0] + 1, 5)       # lit top edge of each board
        lv[y0 + 3] = 1                           # shadow gap under the board
        j = joints[b]
        lv[y0:y0 + 3, j] = 1                     # butt joint
        lv[y0 + 1, (j + 2) % N] = 0              # nails next to the joint
        lv[y0 + 1, (j - 2) % N] = 0
    return lv


def planks_vertical_lv(seed=4011):
    """Boards 4 px wide running along v (floors, doors). Matches 0.25 m floor boards."""
    lv = planks_wall_lv(seed).T.copy()
    return lv


def beam_lv(seed=4021):
    """Dense dark frame wood: fine vertical grain, no joints."""
    n = pnoise(4, 1, seed)[0]                    # one value per column
    lv = rank_levels(np.tile(n, (N, 1)) + 0.3 * pnoise(4, 4, seed + 1), [1, 2, 3, 2]) + 1
    lv = clean_lonely(lv)
    return lv


def palisade_lv(seed=4031):
    """Vertical logs 4 px wide: lit left, shaded right, dark gap, bark marks."""
    lv = np.zeros((N, N), int)
    for x in range(N):
        lv[:, x] = [4, 3, 2, 0][x % 4]
    r = rng(seed)
    for (x, y) in scatter(r, 5, 4, 1, 2, margin=0):
        xx = (x // 4) * 4 + 1
        lv[y, xx] = 1; lv[(y + 1) % N, xx] = 2
    return lv


def shingles_lv(seed=4041):
    """Roof shingles: rows 4 px tall, tiles 4 px wide, staggered; shadow under each row."""
    lv = np.full((N, N), 3)
    r = rng(seed)
    for row in range(4):
        y0 = row * 4
        off = 2 * (row % 2)
        for t in range(4):
            x0 = (t * 4 + off) % N
            tone = 3 if (row + t) % 3 else 2
            for dx in range(4):
                for dy in range(3):
                    lv[y0 + dy, (x0 + dx) % N] = tone
            lv[y0, (x0 + 1) % N] = 4; lv[y0, (x0 + 2) % N] = 4       # lit top
            lv[y0:y0 + 3, (x0 + 3) % N] = 1                          # side gap
        lv[y0 + 3] = 0                                               # row shadow
    return lv


def thatch_lv(seed=4051):
    """Straw: short vertical strokes in rows, darker gaps between rows."""
    r = rng(seed)
    lv = np.full((N, N), 3)
    for row in range(4):
        y0 = row * 4
        for x in range(N):
            v = int(r.integers(2, 5))
            lv[y0:y0 + 3, x] = v
        lv[y0 + 3] = 1
        for (x, _) in scatter(r, 3, 4, 1, 1, margin=0):
            lv[y0 + 3, x] = 3                       # straws hanging over the gap
    return clean_lonely(lv, 1)


def stone_bricks_lv(seed=4061):
    """Bricks 8 x 4 px (0.5 x 0.25 m), staggered, lit from top-left."""
    lv = np.full((N, N), 3)
    r = rng(seed)
    for row in range(4):
        y0 = row * 4; off = 4 * (row % 2)
        for b in range(2):
            x0 = b * 8 + off
            tone = int(r.integers(2, 4))
            for dy in range(3):
                for dx in range(7):
                    lv[y0 + dy, (x0 + dx) % N] = tone
            for dx in range(7):
                lv[y0, (x0 + dx) % N] = tone + 1          # lit top
            lv[y0:y0 + 3, (x0 + 7) % N] = 0               # mortar
        lv[y0 + 3] = 0
    for (x, y) in scatter(r, 2, 6, 2, 1, margin=1):        # chips
        lv[y, x] = 1
    return lv


def stone_tiles_lv(seed=4071):
    """Floor tiles 8 x 8 px (0.5 m, matches the stone floor mesh)."""
    lv = np.full((N, N), 3)
    r = rng(seed)
    for ty in range(2):
        for tx in range(2):
            tone = 3 if (tx + ty) % 2 == 0 else 2
            x0, y0 = tx * 8, ty * 8
            lv[y0:y0 + 8, x0:x0 + 8] = tone
            lv[y0, x0:x0 + 7] = 4; lv[y0:y0 + 7, x0] = 4
            lv[y0 + 7, x0:x0 + 8] = 0; lv[y0:y0 + 8, x0 + 7] = 0
            lv[y0 + 6, x0 + 1:x0 + 7] = np.minimum(lv[y0 + 6, x0 + 1:x0 + 7], 2)
    for (x, y) in scatter(r, 2, 6, 2, 1, margin=2):
        lv[y, x] = 1; lv[y, x + 1] = 1
    return lv


def iron_plate_lv(seed=4081):
    lv = np.full((N, N), 3)
    lv[:, :] = 3
    lv[pnoise(1, 4, seed) > 0.6] = 2            # soft brushed bands
    for y0 in (0, 8):
        lv[y0] = 4; lv[y0 + 7] = 1              # plate edges
        for x in (2, 13):
            lv[y0 + 2, x] = 5; lv[y0 + 3, x] = 1     # rivets
            lv[y0 + 5, x] = 5; lv[y0 + 6, x] = 1
    return lv


def cloth_lv(seed=4091):
    ys, xs = np.mgrid[0:N, 0:N]
    lv = np.where(((xs // 2) + (ys // 2)) % 2 == 0, 3, 2)
    lv[ys % 8 == 7] = 1                         # a stitched seam every 0.5 m
    lv[(ys % 8 == 7) & (xs % 2 == 0)] = 4
    return lv


def tilled_soil_lv(seed=4101):
    lv = np.full((N, N), 2)
    for row in range(4):
        y0 = row * 4
        lv[y0] = 4; lv[y0 + 1] = 3; lv[y0 + 2] = 2; lv[y0 + 3] = 0    # ridge -> furrow
    r = rng(seed)
    for (x, y) in scatter(r, 4, 4, 2, 1, margin=0):
        lv[(y // 4) * 4 + 1, x] = 4; lv[(y // 4) * 4 + 1, (x + 1) % N] = 1   # clods
    return lv


def glass_rgba():
    ys, xs = np.mgrid[0:N, 0:N]
    rgb = np.tile(hexc("#BFE3F2"), (N, N, 1))
    a = np.full((N, N), 110, np.uint8)
    glint = ((xs + ys) % 16 == 4) | ((xs + ys) % 16 == 5) | ((xs + ys) % 16 == 12)
    rgb[glint] = hexc("#F4FCFF"); a[glint] = 200
    return rgb, a


# ===========================================================================

def build():
    tinted = T.tinted
    # ---- bushes / plant blocks
    save("bush_leaves", tinted(bush_leaves_lv(), S_LEAF), "tinted",
         "Bush leaves: small dense clumps (all bush boxes; tint with the bush colour).", "prop", group="bush")
    save("berry_bush", berry_bush(2211, "#3F8C3F", "#C8203F", "#FF7A8E"), "full",
         "Berry bush with red berries painted in (use on the main bush box; white vertex colour).", "prop", group="bush")
    save("frostberry_bush", berry_bush(2221, "#3F7268", "#4F86E0", "#BFE0FF"), "full",
         "Frostberry bush: teal leaves, blue berries.", "prop", group="bush")
    save("cactus", tinted(cactus_lv(), S_LEAF), "tinted", "Cactus: vertical ribs every 4 px with light spines.", "prop", group="plant")
    save("palm_frond", tinted(palm_frond_lv(), S_LEAF), "tinted", "Palm fronds: leaflets from a centre rib.", "prop", group="plant")
    save("mushroom_cap", mushroom_cap(), "full", "Giant mushroom cap: red with cream spots.", "prop", group="plant")
    save("crystal", tinted(crystal_lv(), T.G6), "tinted", "Crystal: big facets with bright edges (crystal clusters, altar).", "prop", group="plant")
    save("hanging_moss", tinted(hanging_moss_lv(), S_LEAF), "tinted", "Swamp-tree hanging moss strands.", "prop", group="plant")

    # ---- sprites
    sprites = {
        "flowers_mixed": (flower_clump(3001, [
            (hexc("#C98A12"), hexc("#F4C430"), hexc("#FFE680"), hexc("#B5541A")),
            (hexc("#B04878"), hexc("#EE82B4"), hexc("#FFC4DE"), hexc("#FFE680")),
            (hexc("#6A55C0"), hexc("#A796F4"), hexc("#D9D0FF"), hexc("#FFE680")),
            (hexc("#B9B3A6"), hexc("#F4F1EA"), hexc("#FFFFFF"), hexc("#F4C430"))]), "full",
            "Meadow flowers, four colours (the 'flowers' prop)."),
        "flowers_yellow": (flower_clump(3011, [(hexc("#C98A12"), hexc("#F4C430"), hexc("#FFE680"), hexc("#B5541A"))] * 3), "full", "Yellow flower clump."),
        "flowers_pink": (flower_clump(3021, [(hexc("#B04878"), hexc("#EE82B4"), hexc("#FFC4DE"), hexc("#FFE680"))] * 3), "full", "Pink flower clump."),
        "flowers_violet": (flower_clump(3031, [(hexc("#6A55C0"), hexc("#A796F4"), hexc("#D9D0FF"), hexc("#FFE680"))] * 3), "full", "Violet flower clump."),
        "grass_tuft": (tuft_sprite(), "tinted", "Grass tuft (tint with the biome top colour)."),
        "fern": (fern_sprite(), "tinted", "Fern (forest/jungle floor; tint green)."),
        "reeds": (reeds_sprite(), "full", "Reeds with cattail heads (shores)."),
        "dead_bush": (dead_bush_sprite(), "full", "Dry desert bush."),
        "sunbloom": (sunbloom_sprite(), "full", "Sunbloom herb (meadow)."),
        "moonpetal": (moonpetal_sprite(), "full", "Moonpetal herb (glows at night - add emission)."),
        "frost_lotus": (frost_lotus_sprite(), "full", "Frost lotus herb (tundra)."),
        "starlight_orchid": (orchid_sprite(), "full", "Starlight orchid herb (crystal glade)."),
        "emberroot": (emberroot_sprite(), "full", "Emberroot herb (desert)."),
        "mushroom_patch": (mushroom_patch_sprite("#4A2E1A", "#7A4A2A", "#A87048"), "full", "Brown mushroom patch."),
        "glowcap": (mushroom_patch_sprite("#1E7A8C", "#3CCFE6", "#B4F6FF", "#BFE9EE"), "full", "Glowcap mushrooms (caves, emission)."),
        "dreamcap": (mushroom_patch_sprite("#5A2E8C", "#9A5AE0", "#E0C4FF", "#E8DDF0"), "full", "Dreamcap mushrooms (caves)."),
    }
    for st in range(4):
        sprites[f"wheat_{st}"] = (wheat_sprite(st), "full", f"Wheat crop, growth stage {st} (farm plot).")
    for name, (sp, tint, desc) in sprites.items():
        rgb = sp.rgb
        if tint == "tinted":
            m = rgb[sp.a > 0].mean()
            rgb = np.clip(rgb * (T.TARGET_MEAN / m), 0, 1)
        save(name, rgb, tint, desc + " Sprite: alpha cut-out on 2 crossed cards, 1 m x 1 m, bottom row = ground.",
             "sprite", alpha=sp.a, group="sprite")

    # ---- building
    save("planks_wall", tinted(planks_wall_lv(), S_WOOD), "tinted",
         "Wood wall: horizontal boards 0.25 m, staggered joints, nails. Tint WOOD.", "building", group="building_wood")
    save("planks_vertical", tinted(planks_vertical_lv(), S_WOOD), "tinted",
         "Boards running along v, 0.25 m wide: wood floor (matches the floor-board mesh), doors, chests.", "building", group="building_wood")
    save("wood_beam", tinted(beam_lv(), S_WOOD), "tinted", "Dark frame wood: posts, beams, door frames. Tint WOOD_DARK.", "building", group="building_wood")
    save("palisade", tinted(palisade_lv(), S_WOOD), "tinted", "Palisade / spike wall: vertical logs 0.25 m.", "building", group="building_wood")
    save("roof_shingles", tinted(shingles_lv(), S_WOOD), "tinted", "Wood roof shingles, staggered rows.", "building", group="building_roof")
    save("thatch", tinted(thatch_lv(), S_WOOD), "tinted", "Thatch roof straw rows. Tint THATCH.", "building", group="building_roof")
    save("stone_bricks", tinted(stone_bricks_lv(), T.S_STONE, warm=0.02), "tinted", "Stone wall bricks 0.5 x 0.25 m, staggered.", "building", group="building_stone")
    save("stone_tiles", tinted(stone_tiles_lv(), T.S_STONE, warm=0.02), "tinted", "Stone floor tiles 0.5 m (matches the floor mesh).", "building", group="building_stone")
    save("iron_plate", tinted(iron_plate_lv(), T.S_STONE, warm=0.0), "tinted", "Iron plate with rivets: reinforced door, traps, forge, chest bands.", "building", group="building_metal")
    save("cloth", tinted(cloth_lv(), T.G6, warm=0.02), "tinted", "Woven cloth with a seam every 0.5 m: bed, tailoring, banners, rugs. Tint the cloth colour.", "building", group="building_cloth")
    save("tilled_soil", tinted(tilled_soil_lv(), T.G6), "tinted", "Farm plot soil: furrows every 0.25 m. Tint SOIL.", "building", group="building_farm")
    g_rgb, g_a = glass_rgba()
    save("glass", g_rgb, "full", "Window glass (alpha 110, glints 200). Not used by the current window mesh (it has no pane).",
         "building", alpha=g_a, group="building_glass")
