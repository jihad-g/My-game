"""
Shardlands held items in the voxel style (docs/ART_BIBLE.md section 6).

Every function builds one item. x = left/right, y = front/back (thin side),
z = up (the blade/head end). The anchor is the middle of the grip: that point
sits in the fist in the game.

Materials "steel"/"dsteel" are recoloured in the game by the item's metal
(copper, mithril, sun...). "accent" and "glow" are recoloured by the item's
icon colour (staff crystal, bow limbs, shield paint, book cover).

All designs are our own. Hand items: 32 voxels per metre.
"""
import numpy as np
from voxkit import Vox

ITEMS = []


def item(fn):
    ITEMS.append(fn)
    return fn


HAND = 1.0 / 32.0


def hv(name, sx, sy, sz, anchor, label, view=(26, 14)):
    v = Vox(name, sx, sy, sz, kind="hand", view=view, anchor=anchor, label=label)
    v.meters = HAND
    return v


# ---------------------------------------------------------------- motifs
def wrap(v, x0, x1, y0, y1, z0, z1, mat, period=2):
    for z in range(z0, z1 + 1):
        v.box(x0, x1, y0, y1, z, z, mat, off=(0 if (z - z0) % period == 0 else -1))


def ring(v, x0, x1, y0, y1, z0, z1=None, mat="dsteel", off=0):
    v.box(x0 - 1, x1 + 1, y0 - 1, y1 + 1, z0, z0 if z1 is None else z1, mat, off)


def rivet(v, x, y, z, mat="steel"):
    v.v(x, y, z, mat, off=3, lock=True)


def gem(v, x0, x1, y0, y1, z0, z1, mat="gem_r"):
    v.box(x0, x1, y0, y1, z0, z1, mat)
    v.v(x0, y0, z1, mat, off=3, lock=True)


def _erode2d(S):
    P = np.pad(S, 1)
    return P[1:-1, 1:-1] & P[:-2, 1:-1] & P[2:, 1:-1] & P[1:-1, :-2] & P[1:-1, 2:]


def bevel_plate(v, msk, rim=+1, inner=-1):
    S = msk.any(axis=1)
    E = _erode2d(S)
    E2 = _erode2d(E)
    v.shade(msk & (S & ~E)[:, None, :], rim)
    v.shade(msk & (E & ~E2)[:, None, :], inner)


def pommel(v, cx, y0, y1, z, mat="steel", gem_mat="gem_r"):
    """Diamond-ish pommel: 4x4 block with cut corners and a gem on the front."""
    v.box(cx - 2, cx + 1, y0, y1, z, z + 2, mat)
    for x in (cx - 2, cx + 1):
        for zz in (z, z + 2):
            v.box(x, x, y0, y1, zz, zz, None)
    v.box(cx - 1, cx, y0 + 1, y1 - 1, z - 1, z - 1, mat, off=1)
    if gem_mat:
        gem(v, cx - 1, cx, y0, y0, z + 1, z + 1, gem_mat)


def blade(v, cx, y0, y1, z0, z1, half, tip=3):
    """Straight two-tone blade, centre column cx-1..cx, width 2*half, pointed tip."""
    v.box(cx - half, cx + half - 1, y0, y1, z0, z1 - tip, "steel")
    for k in range(tip):
        w = max(1, half - 1 - k)
        v.box(cx - w, cx + w - 1, y0, y1, z1 - tip + 1 + k, z1 - tip + 1 + k, "steel")
    v.shade_box(cx - half, cx - 1, 0, 99, z0, z1, +1)          # lit left half
    v.shade_box(cx, cx + half - 1, 0, 99, z0, z1, -1)          # shaded right half
    v.shade_box(cx - half, cx - half, 0, 99, z0, z1 - tip, +1)  # bright edge
    v.shade_box(cx - 1, cx, 0, 99, z0, z0 + 1, -1)              # shadow under the guard


# ================================================================ swords
@item
def sword():
    v = hv("sword", 12, 4, 33, (6.0, 2.0, 7.5), "Sword")
    pommel(v, 6, 0, 3, 1)
    wrap(v, 5, 6, 1, 2, 4, 10, "leather")
    v.box(4, 7, 0, 3, 11, 11, "gold")
    v.box(4, 7, 0, 3, 12, 14, "steel")
    v.box(2, 9, 1, 2, 12, 13, "steel")
    v.box(1, 1, 1, 2, 13, 14, "steel")
    v.box(10, 10, 1, 2, 13, 14, "steel")
    v.box(0, 0, 1, 2, 14, 15, "steel", off=1)
    v.box(11, 11, 1, 2, 14, 15, "steel", off=1)
    v.box(5, 6, 0, 0, 13, 13, "gold")
    blade(v, 6, 1, 2, 15, 32, 2, tip=3)
    return v


@item
def greatsword():
    v = hv("greatsword", 18, 4, 50, (9.0, 2.0, 7.0), "Greatsword")
    pommel(v, 9, 0, 3, 1)
    wrap(v, 8, 9, 1, 2, 4, 12, "leather")
    ring(v, 8, 9, 1, 2, 8, mat="dsteel")
    # wide crossguard with drooping ends
    v.box(2, 15, 0, 3, 13, 15, "dsteel")
    v.box(1, 1, 1, 2, 12, 14, "dsteel")
    v.box(16, 16, 1, 2, 12, 14, "dsteel")
    v.box(0, 0, 1, 2, 11, 12, "dsteel", off=1)
    v.box(17, 17, 1, 2, 11, 12, "dsteel", off=1)
    gem(v, 8, 9, 0, 0, 14, 14, "gem_r")
    # ricasso then a broad blade with a fuller
    v.box(7, 10, 1, 2, 16, 18, "steel", off=-1)
    blade(v, 9, 1, 2, 19, 49, 3, tip=4)
    v.shade_box(8, 9, 0, 99, 20, 43, -2)               # fuller
    return v


@item
def dagger():
    v = hv("dagger", 8, 4, 22, (4.0, 2.0, 5.0), "Dagger")
    v.box(3, 4, 1, 2, 0, 0, "gold", off=1)
    v.box(2, 5, 0, 3, 1, 2, "dsteel")
    gem(v, 3, 4, 0, 0, 1, 2, "gem_r")
    wrap(v, 3, 4, 1, 2, 3, 7, "cloth_p")
    v.box(1, 6, 1, 2, 8, 9, "dsteel")
    v.box(2, 5, 0, 3, 8, 8, "dsteel")
    v.box(0, 0, 1, 2, 9, 10, "dsteel", off=1)
    v.box(7, 7, 1, 2, 9, 10, "dsteel", off=1)
    v.box(3, 4, 1, 2, 10, 11, "steel")
    v.box(2, 5, 1, 2, 12, 17, "steel")
    v.box(3, 4, 1, 2, 18, 20, "steel")
    v.box(3, 3, 1, 2, 21, 21, "steel", off=1)
    v.shade_box(3, 4, 0, 3, 11, 17, -2)
    v.shade_box(2, 2, 0, 3, 12, 17, +1)
    return v


# ================================================================ axes and hammers
@item
def axe():
    v = hv("axe", 18, 4, 34, (6.0, 2.0, 8.0), "Axe")
    v.box(5, 6, 1, 2, 2, 31, "dwood", grain="z")
    v.box(5, 6, 1, 2, 0, 0, "steel", off=1)
    v.box(4, 7, 0, 3, 1, 2, "dsteel")
    wrap(v, 5, 6, 1, 2, 4, 12, "cloth_r")
    ring(v, 5, 6, 1, 2, 13)
    v.box(4, 7, 0, 3, 21, 28, "dsteel")
    v.box(4, 7, 0, 3, 21, 21, "steel")
    v.box(4, 7, 0, 3, 28, 28, "steel")
    for z in (23, 26):
        rivet(v, 4, 0, z)
        rivet(v, 7, 0, z)
    cols = {8: (22, 27), 9: (21, 28), 10: (20, 29), 11: (18, 30), 12: (17, 31),
            13: (16, 32), 14: (16, 32), 15: (17, 31), 16: (19, 29)}
    bl = np.zeros(v.shape, bool)
    for x, (z0, z1) in cols.items():
        v.box(x, x, 1, 2, z0, z1, "steel")
        bl |= v.region(x, x, 1, 2, z0, z1)
    v.clear(16, 16, 0, 3, 23, 24)
    v.clear(11, 12, 0, 3, 24, 25)
    bl &= v.m > 0
    bevel_plate(v, bl)
    v.shade_box(8, 9, 0, 3, 0, 33, -2)
    v.shade_box(15, 16, 0, 3, 0, 33, +1)
    v.shade_box(10, 13, 0, 3, 23, 26, -1)
    v.box(2, 3, 1, 2, 23, 26, "steel")
    v.box(1, 1, 1, 2, 24, 25, "steel")
    v.box(0, 0, 1, 2, 24, 25, "steel", off=1)
    v.box(5, 6, 1, 2, 29, 33, "steel")
    v.v(5, 1, 33, "steel", off=1)
    return v


@item
def warhammer():
    v = hv("warhammer", 14, 8, 46, (7.0, 4.0, 8.0), "Warhammer", view=(30, 16))
    v.box(6, 7, 3, 4, 2, 39, "dwood", grain="z")
    v.box(6, 7, 3, 4, 0, 0, "steel", off=1)
    v.box(5, 8, 2, 5, 1, 2, "dsteel")
    wrap(v, 6, 7, 3, 4, 4, 13, "leather")
    ring(v, 6, 7, 3, 4, 14)
    ring(v, 6, 7, 3, 4, 26, mat="gold")
    # heavy head
    v.box(2, 11, 2, 5, 36, 41, "dsteel")
    v.box(0, 1, 1, 6, 35, 42, "steel")
    v.box(12, 13, 1, 6, 35, 42, "steel")
    v.box(5, 8, 1, 6, 35, 42, "gold")
    v.shade_box(6, 7, 0, 7, 35, 42, -1)
    for z in (37, 40):
        rivet(v, 5, 1, z)
        rivet(v, 8, 1, z)
    for y in range(1, 7):
        for z in range(35, 43):
            if (y + z) % 2 == 0:
                v.shade_box(0, 0, y, y, z, z, -1)
                v.shade_box(13, 13, y, y, z, z, -1)
    v.box(6, 7, 3, 4, 43, 45, "steel")
    v.v(6, 3, 45, "steel", off=1)
    return v


@item
def mace():
    """Small one-handed hammer for monsters and townsfolk."""
    v = hv("mace", 10, 8, 26, (5.0, 4.0, 6.0), "Mace", view=(30, 16))
    v.box(4, 5, 3, 4, 1, 19, "wood", grain="z")
    v.box(3, 6, 2, 5, 0, 1, "dsteel")
    wrap(v, 4, 5, 3, 4, 3, 9, "leather")
    v.box(2, 7, 1, 6, 18, 23, "dsteel")
    v.box(1, 8, 2, 5, 19, 22, "dsteel")
    v.box(3, 6, 2, 5, 24, 24, "dsteel")
    for (x, y, z) in [(0, 3, 20), (9, 4, 21), (4, 0, 21), (5, 7, 20), (4, 3, 25)]:
        v.v(x, y, z, "steel", off=1)
    v.shade_box(1, 8, 0, 7, 18, 18, -1)
    return v


@item
def hoe():
    v = hv("hoe", 12, 6, 40, (3.0, 3.0, 8.0), "Hoe")
    v.box(2, 3, 2, 3, 0, 36, "wood", grain="z")
    wrap(v, 2, 3, 2, 3, 4, 10, "leather")
    ring(v, 2, 3, 2, 3, 34, mat="dsteel")
    v.box(2, 9, 2, 3, 36, 37, "dsteel")
    v.box(8, 10, 1, 4, 30, 37, "steel")
    v.box(9, 11, 1, 4, 28, 29, "steel", off=1)
    v.shade_box(8, 8, 0, 5, 30, 37, -1)
    return v


# ================================================================ staffs and polearms
def _crystal(v, cx, cy, cz, rx, ry, rz, mat):
    X, Y, Z = v.grid()
    q = np.abs(X - cx) / rx + np.abs(Y - cy) / ry + np.abs(Z - cz) / rz
    c = q <= 1.0
    v.put(c, mat, off=-1)
    v.shade(c & (q < 0.80), +1)
    v.shade(c & (q < 0.55), +1)
    v.shade(c & (q < 0.30), +2)
    v.shade(c & (Z < cz - 2), -2)
    v.shade(c & (X < cx) & (Z > cz), +1)
    return c


@item
def staff():
    v = hv("staff", 12, 6, 48, (6.0, 3.0, 15.0), "Staff", view=(28, 12))
    v.box(5, 6, 2, 3, 2, 36, "wood", grain="z")
    v.box(5, 6, 2, 3, 0, 0, "steel", off=1)
    v.box(4, 7, 1, 4, 1, 2, "dsteel")
    wrap(v, 5, 6, 2, 3, 12, 18, "leather")
    ring(v, 5, 6, 2, 3, 11, mat="gold")
    ring(v, 5, 6, 2, 3, 19, mat="gold")
    ring(v, 5, 6, 2, 3, 33, mat="dsteel")
    ring(v, 5, 6, 2, 3, 34, 35, mat="gold")
    _crystal(v, 6.0, 3.0, 41.0, 3.6, 2.6, 4.2, "glow")
    path = [(4, 36), (4, 37), (3, 38), (3, 39), (2, 40), (2, 41), (2, 42), (3, 43), (3, 44), (4, 45)]
    for dx, z in path:
        mat = "gold" if z >= 44 else "wood"
        v.box(dx, dx, 2, 3, z, z, mat)
        v.box(11 - dx, 11 - dx, 2, 3, z, z, mat)
    v.v(5, 3, 47, "glow", off=1)
    v.v(7, 2, 46, "glow", off=-1)
    return v


@item
def wand():
    v = hv("wand", 6, 6, 20, (3.0, 3.0, 5.0), "Wand")
    v.box(2, 3, 2, 3, 0, 14, "lwood", grain="z")
    wrap(v, 2, 3, 2, 3, 2, 7, "leather")
    ring(v, 2, 3, 2, 3, 13, mat="gold")
    v.box(2, 3, 2, 3, 15, 18, "glow", off=1)
    v.box(1, 4, 2, 3, 16, 17, "glow")
    v.box(2, 3, 1, 4, 16, 17, "glow")
    v.v(2, 2, 19, "glow", off=3)
    return v


@item
def spear():
    v = hv("spear", 8, 4, 54, (4.0, 2.0, 16.0), "Spear", view=(26, 12))
    v.box(3, 4, 1, 2, 0, 44, "wood", grain="z")
    v.box(3, 4, 1, 2, 0, 0, "dsteel")
    wrap(v, 3, 4, 1, 2, 12, 20, "leather")
    ring(v, 3, 4, 1, 2, 43, 44, mat="dsteel")
    # leaf head
    v.box(3, 4, 1, 2, 45, 46, "steel")
    v.box(2, 5, 1, 2, 47, 50, "steel")
    v.box(1, 6, 1, 2, 48, 49, "steel")
    v.box(3, 4, 1, 2, 51, 52, "steel")
    v.v(3, 1, 53, "steel", off=1)
    v.shade_box(4, 6, 0, 3, 45, 53, -1)
    v.shade_box(1, 2, 0, 3, 45, 53, +1)
    # red tassel under the head
    v.box(5, 5, 1, 2, 38, 42, "cloth_r")
    v.box(2, 2, 1, 2, 39, 42, "cloth_r", off=-1)
    return v


@item
def halberd():
    v = hv("halberd", 18, 4, 56, (8.0, 2.0, 16.0), "Halberd", view=(24, 12))
    v.box(7, 8, 1, 2, 0, 47, "dwood", grain="z")
    v.box(7, 8, 1, 2, 0, 0, "dsteel")
    wrap(v, 7, 8, 1, 2, 12, 20, "leather")
    ring(v, 7, 8, 1, 2, 30)
    ring(v, 7, 8, 1, 2, 38, 39)
    # top spike
    v.box(7, 8, 1, 2, 48, 53, "steel")
    v.v(7, 1, 54, "steel", off=1)
    v.v(7, 2, 55, "steel", off=1)
    # crescent axe blade (right)
    cols = {9: (40, 46), 10: (39, 47), 11: (38, 47), 12: (37, 47), 13: (36, 47), 14: (36, 46), 15: (37, 45)}
    bl = np.zeros(v.shape, bool)
    for x, (z0, z1) in cols.items():
        v.box(x, x, 1, 2, z0, z1, "steel")
        bl |= v.region(x, x, 1, 2, z0, z1)
    bevel_plate(v, bl)
    v.shade_box(14, 15, 0, 3, 0, 55, +1)
    # back hook (left)
    v.box(5, 6, 1, 2, 43, 44, "steel")
    v.box(3, 4, 1, 2, 42, 43, "steel")
    v.box(2, 2, 1, 2, 40, 42, "steel", off=1)
    return v


@item
def bow():
    v = hv("bow", 12, 2, 37, (3.0, 1.0, 18.0), "Bow", view=(22, 10))
    H = 36
    mid = H / 2.0
    for z in range(0, H + 1):
        t = abs(z - mid) / mid
        xc = 2 + int(round(6.0 * t ** 1.7))
        v.box(xc, xc + 1, 0, 1, z, z, "accent")
    v.shade_box(0, 11, 0, 1, 0, 36, 0)
    v.box(9, 9, 0, 1, 2, 34, "rope", off=1)
    v.box(8, 10, 0, 1, 0, 1, "gold")
    v.box(8, 10, 0, 1, 35, 36, "gold")
    wrap(v, 1, 4, 0, 1, 15, 21, "leather")
    v.box(5, 5, 0, 1, 22, 22, "dwood")
    for z in (8, 28):
        t = abs(z - mid) / mid
        xc = 2 + int(round(6.0 * t ** 1.7))
        v.box(xc - 1, xc + 2, 0, 1, z, z, "cloth_g")
    return v


# ================================================================ shields (front = y 0)
def _shield_mask(sx, sz, kind):
    S = np.zeros((sx, sz), bool)
    cx, cz = sx / 2.0, sz / 2.0
    for x in range(sx):
        for z in range(sz):
            px, pz = x + 0.5, z + 0.5
            if kind == "round":
                S[x, z] = (px - cx) ** 2 + (pz - cz) ** 2 <= (sx / 2.0) ** 2
            elif kind == "kite":
                top = sz * 0.45
                if pz >= top:
                    S[x, z] = True
                else:
                    hw = (sx / 2.0) * (pz / top) ** 0.55
                    S[x, z] = abs(px - cx) <= max(hw, 1.0)
            elif kind == "heater":
                S[x, z] = abs(px - cx) <= (sx / 2.0) * min(1.0, 0.25 + (pz / sz) * 1.6)
    return S


def _shield(v, S, face, rim, back="wood", rim_w=1, rivets=True):
    sx, sy, sz = v.shape
    E = S.copy()
    for _ in range(rim_w):
        E = _erode2d(E)
    rimm = S & ~E
    for x in range(sx):
        for z in range(sz):
            if rimm[x, z]:
                v.box(x, x, 0, 2, z, z, rim)
            elif S[x, z]:
                v.box(x, x, 1, 1, z, z, face)
                v.box(x, x, 2, 2, z, z, back, grain="x")
    if rivets:
        for x in range(sx):
            for z in range(sz):
                if rimm[x, z] and (x * 3 + z) % 5 == 0:
                    rivet(v, x, 0, z, rim if rim in ("steel", "dsteel", "gold") else "steel")
    # handle on the back
    v.box(sx // 2 - 1, sx // 2, 3, 3, sz // 2 - 3, sz // 2 + 2, "leather")
    return rimm


@item
def shield_round():
    """Plain wooden round shield (townsfolk, monsters). The boss takes the accent colour."""
    v = hv("shield_round", 18, 4, 18, (9.0, 3.0, 9.0), "Round Shield", view=(24, 12))
    S = _shield_mask(18, 18, "round")
    for x in range(18):
        for z in range(18):
            if S[x, z]:
                v.box(x, x, 1, 2, z, z, "wood", grain="z")
    rimm = S & ~_erode2d(S)
    for x in range(18):
        for z in range(18):
            if rimm[x, z]:
                v.box(x, x, 0, 2, z, z, "dsteel")
            elif S[x, z] and x % 4 == 0:
                v.shade_box(x, x, 1, 1, z, z, -1)
    v.box(7, 10, 0, 0, 7, 10, "accent")
    v.box(8, 9, 0, 0, 6, 11, "accent")
    v.box(6, 11, 0, 0, 8, 9, "accent")
    v.v(7, 0, 10, "accent", off=2, lock=True)
    v.box(8, 9, 3, 3, 5, 12, "leather")
    return v


@item
def buckler():
    v = hv("buckler", 14, 4, 14, (7.0, 3.0, 7.0), "Buckler", view=(24, 12))
    S = _shield_mask(14, 14, "round")
    _shield(v, S, "accent", "dsteel", rivets=False)
    v.box(5, 8, 0, 0, 5, 8, "steel")
    v.box(6, 7, 0, 0, 4, 9, "steel")
    v.box(4, 9, 0, 0, 6, 7, "steel")
    v.v(5, 0, 8, "steel", off=3, lock=True)
    for (x, z) in [(2, 7), (11, 6), (7, 2), (6, 11)]:
        rivet(v, x, 0, z)
    return v


@item
def kite_shield():
    v = hv("kite_shield", 16, 4, 22, (8.0, 3.0, 11.0), "Kite Shield", view=(24, 12))
    S = _shield_mask(16, 22, "kite")
    rimm = _shield(v, S, "accent", "steel")
    # red cross
    for x in range(16):
        for z in range(22):
            if S[x, z] and not rimm[x, z] and (7 <= x <= 8 or 13 <= z <= 14):
                v.box(x, x, 1, 1, z, z, "cloth_r")
    return v


@item
def gilded_kite():
    v = hv("gilded_kite", 18, 4, 24, (9.0, 3.0, 12.0), "Gilded Kite Shield", view=(24, 12))
    S = _shield_mask(18, 24, "kite")
    rimm = _shield(v, S, "cloth_r", "gold", rim_w=2)
    X, Z = np.meshgrid(np.arange(18) + 0.5, np.arange(24) + 0.5, indexing="ij")
    d = np.sqrt((X - 9) ** 2 + (Z - 14) ** 2)
    for x in range(18):
        for z in range(24):
            if not S[x, z] or rimm[x, z]:
                continue
            if d[x, z] <= 2.6:
                v.box(x, x, 0, 1, z, z, "gold", off=1)
            elif 3.6 <= d[x, z] <= 4.6 and (x + z) % 2 == 0:
                v.box(x, x, 1, 1, z, z, "gold")
    v.v(8, 0, 15, "gold", off=3, lock=True)
    return v


@item
def aegis():
    v = hv("aegis", 20, 4, 22, (10.0, 3.0, 11.0), "Aegis of Dawn", view=(24, 12))
    S = _shield_mask(20, 22, "heater")
    rimm = _shield(v, S, "accent", "gold", rim_w=2)
    X, Z = np.meshgrid(np.arange(20) + 0.5, np.arange(22) + 0.5, indexing="ij")
    d = np.sqrt((X - 10) ** 2 + (Z - 12.5) ** 2)
    ang = np.arctan2(Z - 12.5, X - 10)
    for x in range(20):
        for z in range(22):
            if not S[x, z] or rimm[x, z]:
                continue
            if d[x, z] <= 2.4:
                v.box(x, x, 0, 1, z, z, "fire", off=2)
            elif d[x, z] <= 6.5 and (np.cos(ang[x, z] * 4) > 0.75):
                v.box(x, x, 0, 1, z, z, "fire", off=1)
    return v


@item
def tome():
    v = hv("tome", 10, 12, 14, (5.0, 6.0, 7.0), "Tome", view=(36, 20))
    v.box(0, 9, 0, 11, 0, 13, "accent")
    v.box(1, 9, 1, 10, 1, 12, "bone", off=1)          # pages
    v.box(0, 0, 0, 11, 0, 13, "accent", off=-1)      # spine
    for z in range(1, 13, 2):
        v.shade_box(9, 9, 1, 10, z, z, -1)
    for (y, z) in [(0, 0), (0, 13), (11, 0), (11, 13)]:
        v.box(0, 9, y, y, z, z, "gold")
    v.box(0, 0, 3, 8, 3, 10, "accent", off=-1)
    v.box(0, 0, 5, 6, 5, 8, "gold", off=1)          # clasp emblem on the cover
    return v


# ================================================================ named weapons
@item
def prismheart_blade():
    v = hv("prismheart_blade", 14, 4, 36, (7.0, 2.0, 6.5), "Prismheart Blade")
    v.box(6, 7, 1, 2, 0, 1, "gold")
    for k in range(4):
        v.box(6, 7, 1, 2, 2 + k * 2, 3 + k * 2, "gem_b" if k % 2 == 0 else "gold")
    v.box(3, 10, 0, 3, 10, 12, "cloth_p")
    v.box(6, 7, 0, 3, 10, 12, "arcane", off=1)
    for s, x0 in ((-1, 1), (1, 11)):
        v.box(x0, x0 + 1, 1, 2, 12, 15, "teal")
        v.box(x0 - s, x0 - s, 1, 2, 15, 16, "teal", off=1)
    for k in range(20):
        dx = k // 7
        w = 3 if k < 16 else 2
        v.box(5 + dx, 5 + dx + w - 1, 1, 2, 13 + k, 13 + k, "glass", off=1)
    v.box(8, 9, 1, 2, 33, 34, "glass", off=2)
    v.v(9, 1, 35, "glass", off=3)
    v.shade_box(5, 6, 0, 3, 13, 34, +1)
    v.v(6, 0, 22, "arcane", off=2)
    return v


@item
def sporecrown_staff():
    v = hv("sporecrown_staff", 18, 18, 46, (9.0, 9.0, 14.0), "Sporecrown Staff", view=(30, 18))
    for k in range(18):
        col = ["cloth_p", "gem_b", "gold"][k % 3]
        v.box(8, 9, 8, 9, k * 2, k * 2 + 1, col)
    v.box(7, 10, 7, 10, 36, 37, "fire", off=1)        # glowing gills
    X, Y, Z = v.grid()
    d = np.sqrt((X - 9) ** 2 + (Y - 9) ** 2)
    cap = (Z >= 38) & (Z < 43) & (d <= 8.6 - (Z - 38) * 1.4)
    v.put(cap, "teal")
    v.shade(cap & (Z >= 41), +1)
    v.shade(cap & (Z < 39), -1)
    for (x, y, z) in [(5, 4, 41), (12, 6, 41), (8, 13, 40), (13, 12, 39), (4, 10, 40), (9, 6, 42)]:
        v.box(x, x + 1, y, y + 1, z, z, "fire", off=2)
    return v


@item
def gilded_greatsword():
    v = hv("gilded_greatsword", 18, 4, 50, (9.0, 2.0, 7.0), "Gilded Greatsword")
    pommel(v, 9, 0, 3, 1, mat="gold", gem_mat="gem_r")
    wrap(v, 8, 9, 1, 2, 4, 12, "cloth_r")
    v.box(1, 16, 1, 2, 13, 15, "gold")
    v.box(5, 12, 0, 3, 13, 15, "gold")
    v.box(0, 0, 1, 2, 14, 16, "gold", off=1)
    v.box(17, 17, 1, 2, 14, 16, "gold", off=1)
    gem(v, 8, 9, 0, 0, 14, 14, "gem_r")
    v.box(6, 11, 1, 2, 16, 44, "gold")
    for k in range(4):
        w = 2 - k // 2
        v.box(9 - w, 8 + w, 1, 2, 45 + k, 45 + k, "gold")
    v.shade_box(6, 8, 0, 3, 16, 48, +1)
    v.shade_box(9, 11, 0, 3, 16, 48, -1)
    v.shade_box(8, 9, 0, 3, 18, 42, -1)
    v.shade_box(6, 6, 0, 3, 16, 44, +1)
    return v


@item
def gilded_halberd():
    v = hv("gilded_halberd", 18, 4, 56, (8.0, 2.0, 16.0), "Gilded Halberd", view=(24, 12))
    v.box(7, 8, 1, 2, 0, 47, "cloth_r", off=-1)
    for z in (4, 18, 32, 46):
        ring(v, 7, 8, 1, 2, z, mat="gold")
    v.box(7, 8, 1, 2, 48, 53, "gold")
    v.v(7, 1, 54, "gold", off=1)
    cols = {9: (40, 46), 10: (39, 47), 11: (38, 47), 12: (37, 47), 13: (36, 47), 14: (36, 46), 15: (37, 45)}
    bl = np.zeros(v.shape, bool)
    for x, (z0, z1) in cols.items():
        v.box(x, x, 1, 2, z0, z1, "gold")
        bl |= v.region(x, x, 1, 2, z0, z1)
    bevel_plate(v, bl)
    v.box(3, 6, 1, 2, 42, 43, "gold", off=-1)
    v.box(2, 2, 1, 2, 40, 42, "gold")
    gem(v, 7, 8, 0, 0, 44, 45, "gem_r")
    return v


@item
def starlance():
    v = hv("starlance", 18, 4, 58, (9.0, 2.0, 16.0), "Starlance", view=(24, 12))
    v.box(8, 9, 1, 2, 0, 43, "dsteel", off=-1)
    for z in (10, 30):
        ring(v, 8, 9, 1, 2, z, mat="steel")
    wrap(v, 8, 9, 1, 2, 12, 20, "cloth_p")
    v.box(7, 10, 0, 3, 44, 47, "arcane", off=1)        # star core
    v.box(8, 9, 1, 2, 48, 57, "steel", off=1)
    v.v(8, 1, 57, "steel", off=2)
    v.box(8, 9, 1, 2, 39, 43, "steel")
    v.box(1, 6, 1, 2, 45, 46, "steel", off=1)
    v.box(11, 16, 1, 2, 45, 46, "steel", off=1)
    v.box(0, 0, 1, 2, 45, 45, "steel", off=2)
    v.box(17, 17, 1, 2, 46, 46, "steel", off=2)
    for x in (4, 13):
        v.box(x, x + 1, 1, 2, 40, 41, "steel")
        v.box(x, x + 1, 1, 2, 42, 44, "rope")
    return v
