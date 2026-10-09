"""Shardlands texture generator.

Makes every block / prop texture as a 16x16 pixel-art PNG, exactly and
repeatably (fixed seeds). Run from the repo root:

    python3 art/tools/texgen.py

Output: art/textures/<name>.png  +  art/textures/textures.json (metadata).

Tint modes
----------
"tinted"      grey-ish (lightly warm/cool) texture. The game multiplies it with the
              block colour:  final = vertex_colour * texture * TEX_GAIN (1.25).
              A stored value of 0.8 (204) means "no change".
"tinted_edge" like "tinted", but alpha is a mask: alpha 255 = top part (grass,
              snow, moss) tinted with the TOP colour, alpha 0 = side part, where the
              shader shows the side texture tinted with the SIDE colour.
"full"        real colours (ores). Use with a white vertex colour.

Rules kept by every texture: tiles left/right and top/bottom; 4-6 shades; big
shapes; no lonely single pixels in the base layer; variants of one family share
the same outer 2-pixel ring so any variant can sit next to any other.
"""
from __future__ import annotations

import json
import os
import numpy as np
from PIL import Image

N = 16
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures")
TEX_GAIN = 1.25          # shader multiplies tinted textures by this
TARGET_MEAN = 0.80       # mean of a tinted texture (so it does not change the colour)

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def pnoise(cx: int, cy: int, seed: int) -> np.ndarray:
    """Periodic value noise (tiles on 16x16). cx, cy = lattice cells per axis."""
    g = rng(seed).random((cy, cx))
    def axis(cells):
        t = (np.arange(N) + 0.5) * cells / N
        i0 = np.floor(t).astype(int)
        f = t - i0
        f = f * f * (3 - 2 * f)
        return i0 % cells, (i0 + 1) % cells, f
    x0, x1, fx = axis(cx)
    y0, y1, fy = axis(cy)
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]; d = g[np.ix_(y1, x1)]
    fx = fx[None, :]; fy = fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(seed: int, big=2, small=4, w_small=0.35, sx=1.0, sy=1.0) -> np.ndarray:
    """Two octaves; sx/sy stretch (e.g. sy=3 gives horizontal layers)."""
    n = pnoise(max(1, int(big * sx)), max(1, int(big * sy)), seed)
    n += w_small * pnoise(max(1, int(small * sx)), max(1, int(small * sy)), seed + 1)
    return n


def rank_levels(field: np.ndarray, shares: list[float]) -> np.ndarray:
    """Turn a field into level indices 0..k-1, each level covering `shares` of the area."""
    order = np.argsort(field, axis=None, kind="stable")
    idx = np.empty(N * N, dtype=int)
    cuts = np.round(np.cumsum(shares) / np.sum(shares) * N * N).astype(int)
    start = 0
    for lvl, end in enumerate(cuts):
        idx[order[start:end]] = lvl
        start = end
    return idx.reshape(N, N)


def clean_lonely(lv: np.ndarray, passes: int = 2) -> np.ndarray:
    """Remove pixels that share their level with none of their 4 neighbours."""
    lv = lv.copy()
    for _ in range(passes):
        nb = [np.roll(lv, s, axis=a) for a in (0, 1) for s in (1, -1)]
        same = sum((n == lv).astype(int) for n in nb)
        lonely = same == 0
        if not lonely.any():
            break
        stack = np.stack(nb)
        for y, x in zip(*np.nonzero(lonely)):
            vals, counts = np.unique(stack[:, y, x], return_counts=True)
            lv[y, x] = vals[np.argmax(counts)]
    return lv


def wrap_dist(a, b):
    d = abs(a - b) % N
    return min(d, N - d)


def scatter(r: np.random.Generator, count: int, min_dist: float, w: int, h: int,
            margin: int = 2, tries: int = 400) -> list[tuple[int, int]]:
    """Positions (top-left) for motifs of size w x h, kept inside [margin, N-margin)."""
    pts: list[tuple[int, int]] = []
    for _ in range(tries):
        if len(pts) >= count:
            break
        x = int(r.integers(margin, N - margin - w + 1))
        y = int(r.integers(margin, N - margin - h + 1))
        if all((wrap_dist(x, px) ** 2 + wrap_dist(y, py) ** 2) ** 0.5 >= min_dist for px, py in pts):
            pts.append((x, y))
    return pts


def stamp(lv: np.ndarray, x: int, y: int, shape: list[str], key: dict[str, int]):
    for j, row in enumerate(shape):
        for i, ch in enumerate(row):
            if ch in key:
                lv[(y + j) % N, (x + i) % N] = key[ch]


def voronoi(points, sx=1.0, sy=1.0):
    """Periodic Voronoi: returns (cell index map, crack mask)."""
    ys, xs = np.mgrid[0:N, 0:N]
    best = np.full((N, N), 1e9); idx = np.zeros((N, N), int)
    for k, (px, py) in enumerate(points):
        dx = np.abs(xs + 0.5 - px); dx = np.minimum(dx, N - dx)
        dy = np.abs(ys + 0.5 - py); dy = np.minimum(dy, N - dy)
        d = (dx * sx) ** 2 + (dy * sy) ** 2
        m = d < best
        best[m] = d[m]; idx[m] = k
    crack = (idx != np.roll(idx, -1, axis=1)) | (idx != np.roll(idx, -1, axis=0))
    return idx, crack


def bevel(lv: np.ndarray, crack: np.ndarray, light: int, dark: int, crack_lv: int):
    """Light from top-left: pixels below/right of a crack get `light`, pixels
    above/left of a crack get `dark`. Cracks themselves get `crack_lv`."""
    out = lv.copy()
    below = np.roll(crack, 1, axis=0) | np.roll(crack, 1, axis=1)
    above = np.roll(crack, -1, axis=0) | np.roll(crack, -1, axis=1)
    if dark is not None:
        out[above & ~crack] = dark
    out[below & ~crack] = light
    out[crack] = crack_lv
    return out


def lock_border(img: np.ndarray, ref: np.ndarray, width: int = 2) -> np.ndarray:
    out = img.copy()
    out[:width] = ref[:width]; out[-width:] = ref[-width:]
    out[:, :width] = ref[:, :width]; out[:, -width:] = ref[:, -width:]
    return out


# ---------------------------------------------------------------------------
# Colour of a level
# ---------------------------------------------------------------------------

def to_rgb(lv: np.ndarray, shades: list[float], warm: float = 0.035) -> np.ndarray:
    """Level map -> float RGB. Light shades lean warm, dark shades lean cool
    (warm light / cool shade rule), only a few percent so tinting still works."""
    v = np.asarray(shades)[lv]
    t = np.clip((v - TARGET_MEAN) / 0.2, -1.0, 1.0)
    rgb = np.stack([v * (1 + warm * t), v * (1 + warm * 0.25 * t), v * (1 - warm * 1.3 * t)], axis=-1)
    return rgb


def normalise_mean(rgb: np.ndarray, target=TARGET_MEAN) -> np.ndarray:
    m = rgb.mean()
    return np.clip(rgb * (target / m), 0, 1)


def normalise_family(imgs: list[np.ndarray], target=TARGET_MEAN) -> list[np.ndarray]:
    """One shared factor for all variants, so their shared edge ring stays identical."""
    m = float(np.mean([i.mean() for i in imgs]))
    return [np.clip(i * (target / m), 0, 1) for i in imgs]


TEXTURES: dict[str, dict] = {}


def save(name: str, rgb: np.ndarray, tint: str, desc: str, face: str,
         alpha: np.ndarray | None = None, group: str | None = None):
    a = np.full((N, N), 255, np.uint8) if alpha is None else alpha.astype(np.uint8)
    px = np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8)
    img = np.dstack([px, a])
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, f"{name}.png"))
    shades = len({tuple(p) for p in px.reshape(-1, 3)})
    TEXTURES[name] = {
        "file": f"{name}.png", "tint": tint, "face": face, "group": group or name,
        "shades": shades, "mean": round(float(rgb.mean()), 3), "desc": desc,
    }
    return px


# ---------------------------------------------------------------------------
# Motifs (L = light, M = mid, D = dark, W = brightest)
# ---------------------------------------------------------------------------
TUFTS = [
    ["L.L", "LLL", "DDD"],
    [".L.", "LLL", "DD."],
    ["L..L", ".LL.", "DDDD"],
    ["L.", "LL", "DD"],
]
PEBBLE = ["LM", "MD"]
PEBBLE_W = ["LLM", "MMD"]
CLOVER = [".L.", "LML", ".D."]
LEAF_BIG = ["LLL.", "LMLL", ".DDD"]
NEEDLE = ["D..", ".D.", "..D"]
SPARK = [".L.", "LWL", ".L."]


def family(n_var: int, make, ring=2):
    """Build variants; v1.. share the outer ring of v0 (seam-free mixing)."""
    imgs = [make(0)]
    for k in range(1, n_var):
        imgs.append(lock_border(make(k), imgs[0], ring))
    return imgs


# ---------------------------------------------------------------------------
# Grass tops (one style per green biome)
# ---------------------------------------------------------------------------
G6 = [0.62, 0.70, 0.78, 0.86, 0.94, 1.0]   # generic 6-shade ramp (index 0..5)


def grass_base(seed, shares=(1, 3, 4, 2)):
    lv = rank_levels(fbm(seed, 2, 4, 0.4), list(shares)) + 1   # levels 1..4
    return clean_lonely(lv)


def grass_top(style: str, seed: int, n_var=3):
    base = grass_base(seed)
    def make(k):
        r = rng(seed * 31 + k * 7 + 1)
        lv = base.copy()
        if style == "meadow":       # soft blobs + light tufts
            for (x, y) in scatter(r, 5, 4.2, 3, 3):
                stamp(lv, x, y, TUFTS[int(r.integers(0, 3))], {"L": 4, "D": 1})
        elif style == "forest":     # clover leaves + dark leaf-litter specks
            for (x, y) in scatter(r, 4, 4.5, 3, 3):
                stamp(lv, x, y, CLOVER, {"L": 4, "M": 3, "D": 1})
            for (x, y) in scatter(r, 3, 4.0, 2, 1):
                stamp(lv, x, y, ["DD"], {"D": 0})
        elif style == "jungle":     # big broad leaves
            for (x, y) in scatter(r, 3, 6.0, 4, 3):
                stamp(lv, x, y, LEAF_BIG, {"L": 5, "M": 3, "D": 0})
        elif style == "taiga":      # fallen needles + few tufts
            for (x, y) in scatter(r, 4, 4.0, 3, 3):
                stamp(lv, x, y, NEEDLE if r.random() < 0.5 else [r_[::-1] for r_ in NEEDLE], {"D": 0})
            for (x, y) in scatter(r, 2, 6.0, 2, 3):
                stamp(lv, x, y, TUFTS[3], {"L": 4, "D": 1})
        elif style == "swamp":      # moss with dark wet puddles and glints
            wet = pnoise(3, 3, seed + 50 + k * 3) > 0.70
            wet &= ~np.zeros_like(wet)
            lv[wet] = 0
            glint = wet & ~np.roll(wet, 1, axis=0)
            lv[glint] = 4
            for (x, y) in scatter(r, 3, 5.0, 3, 3):
                stamp(lv, x, y, TUFTS[1], {"L": 4, "D": 1})
        elif style == "alpine":     # short sparse tufts, bare darker patches
            bare = pnoise(2, 2, seed + 70) > 0.72
            lv[bare] = np.maximum(lv[bare] - 1, 1)
            for (x, y) in scatter(r, 3, 5.0, 2, 3):
                stamp(lv, x, y, TUFTS[3], {"L": 4, "D": 1})
        elif style == "crystal":    # violet moss with little sparkles
            for (x, y) in scatter(r, 3, 5.0, 3, 3):
                stamp(lv, x, y, SPARK, {"L": 4, "W": 5})
        return lv
    return [to_rgb(lv, G6) for lv in family(n_var, make)]


# ---------------------------------------------------------------------------
# Sides: dirt, sand, sandstone, stone, mountain rock, mud, cave, gravel, crystal
# 16x16 covers TWO blocks (1 m). World-space v = y / 1 m.
# ---------------------------------------------------------------------------

def dirt_side(seed=101):
    lv = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.4, sy=1.5), [1, 3, 4, 2]) + 1)
    r = rng(seed)
    for (x, y) in scatter(r, 4, 5.0, 2, 2, margin=1):
        stamp(lv, x, y, PEBBLE, {"L": 4, "M": 3, "D": 0})
    return lv


def dirt_top(seed=111):
    lv = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.5), [1, 3, 4, 2]) + 1)
    r = rng(seed)
    for (x, y) in scatter(r, 3, 5.5, 2, 2):
        stamp(lv, x, y, PEBBLE, {"L": 4, "M": 3, "D": 0})
    for (x, y) in scatter(r, 2, 6.0, 2, 1):
        stamp(lv, x, y, ["DD"], {"D": 0})
    return lv


S_SAND = [0.66, 0.72, 0.78, 0.84, 0.90, 0.96]


def sand_top(seed=201, n=3):
    base = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.3), [2, 4, 3]) + 2)   # 2..4 calm
    def make(k):
        r = rng(seed + 13 * k)
        lv = base.copy()
        for (x, y) in scatter(r, 3 + k % 2, 5.0, 2, 1):
            stamp(lv, x, y, ["LD"] if r.random() < 0.5 else ["DL"], {"L": 5, "D": 1})
        if k == 2:  # a tiny shell
            for (x, y) in scatter(r, 1, 8, 2, 2):
                stamp(lv, x, y, ["WL", "LD"], {"W": 5, "L": 4, "D": 1})
        return lv
    return [to_rgb(lv, S_SAND) for lv in family(n, make)]


def sand_side(seed=211):
    lv = clean_lonely(rank_levels(fbm(seed, 1, 2, 0.5, sx=1, sy=4), [1, 3, 4, 2]) + 1)
    r = rng(seed)
    for (x, y) in scatter(r, 3, 5.0, 2, 1, margin=1):
        stamp(lv, x, y, ["LD"], {"L": 5, "D": 0})
    return lv


def desert_top(seed=301, n=3):
    """Wind ripples. Phase uses whole-number frequencies so it tiles."""
    ys, xs = np.mgrid[0:N, 0:N]
    warp = (pnoise(2, 2, seed) - 0.5) * 2.2
    def make(k):
        phase = 2 * np.pi * (1 * xs + 2 * ys) / N + warp
        w = np.sin(phase)
        lv = np.full((N, N), 2)
        lv[w > 0.35] = 3
        lv[w > 0.80] = 4
        lv[w < -0.55] = 1
        lv = clean_lonely(lv)
        r = rng(seed + 17 * k + 3)
        for (x, y) in scatter(r, 2 + k, 6.0, 2, 1):
            stamp(lv, x, y, ["LD"], {"L": 5, "D": 0})
        return lv
    return [to_rgb(lv, S_SAND, warm=0.05) for lv in family(n, make)]


def sandstone_side(seed=311):
    """Clean horizontal bands, 4 rows each, thin dark line under each band."""
    lv = np.zeros((N, N), int)
    wob = rank_levels(fbm(seed, 2, 4, 0.3, sy=0.5), [1, 2, 1])   # 0..2 inside band
    band_shade = [3, 2, 3, 2]
    for row in range(N):
        b = row // 4
        lv[row] = band_shade[b] + (wob[row] == 2) - (wob[row] == 0) * 0
        if row % 4 == 0:
            lv[row] = 4                 # lit lip on top of each layer
        if row % 4 == 3:
            lv[row] = 1                 # shadow line under each layer
    r = rng(seed)
    for (x, y) in scatter(r, 2, 7, 2, 1, margin=1):   # small chips in the lip lines
        lv[(y // 4) * 4 + 3, x] = 0
    return lv


def sandstone_top(seed=321):
    pts = [(2.5, 3.0), (10.0, 2.0), (6.0, 9.5), (13.5, 11.0), (1.0, 13.0)]
    idx, crack = voronoi(pts)
    lv = np.array([3, 2, 3, 2, 3])[idx]
    return bevel(lv, crack, 4, None, 1)


S_STONE = [0.58, 0.66, 0.74, 0.82, 0.90, 0.98]


def stone_top(seed=401, n=3):
    r0 = rng(seed)
    border_pts = [(1.0, 1.0), (8.0, 0.5), (15.0, 8.0), (0.5, 12.0), (12.0, 15.0)]
    def make(k):
        r = rng(seed + 50 * k)
        inner = [(float(r.uniform(5, 11)), float(r.uniform(5, 11)))]
        idx, crack = voronoi(border_pts + inner)
        tones = np.array([2, 3, 2, 3, 3, 2])
        lv = tones[idx]
        lv = bevel(lv, crack, 4, None, 1)
        for (x, y) in scatter(r, 1, 6, 2, 1):
            stamp(lv, x, y, ["LL"], {"L": 4})
        return lv
    imgs = family(n, make)
    return [to_rgb(lv, S_STONE, warm=0.02) for lv in imgs]


def stone_side(seed=411, n=2):
    border_pts = [(1.0, 2.0), (9.0, 1.0), (15.5, 9.0), (4.0, 15.0), (12.0, 13.5)]
    def make(k):
        r = rng(seed + 50 * k)
        inner = [(float(r.uniform(4, 12)), float(r.uniform(5, 11)))]
        idx, crack = voronoi(border_pts + inner, sx=0.6, sy=1.4)   # wide flat slabs
        lv = np.array([2, 3, 2, 3, 2, 3])[idx]
        return bevel(lv, crack, 4, None, 1)
    return [to_rgb(lv, S_STONE, warm=0.02) for lv in family(n, make)]


def mountain_rock_side(seed=421):
    """Strong horizontal strata (layers) with a few vertical cracks."""
    layer = rank_levels(fbm(seed, 1, 2, 0.6, sx=1, sy=5), [2, 3, 3, 2]) + 1
    lv = clean_lonely(layer)
    # dark line on every layer boundary going down
    edge = (lv != np.roll(lv, -1, axis=0)) & (lv > np.roll(lv, -1, axis=0))
    lv[edge] = 0
    r = rng(seed)
    for (x, y) in scatter(r, 3, 5, 1, 3, margin=1):
        stamp(lv, x, y, ["D", "D", "M"], {"D": 0, "M": 2})
    return lv


def mountain_rock_top(seed=431, n=2):
    border_pts = [(0.5, 0.5), (7.0, 1.0), (15.0, 6.0), (1.0, 9.0), (10.0, 15.5)]
    def make(k):
        r = rng(seed + 9 * k)
        inner = [(float(r.uniform(5, 11)), float(r.uniform(5, 11)))]
        idx, crack = voronoi(border_pts + inner, sx=1.0, sy=1.0)
        lv = np.array([2, 3, 2, 3, 2, 3])[idx]
        return bevel(lv, crack, 4, None, 0)
    return [to_rgb(lv, S_STONE, warm=0.03) for lv in family(n, make)]


S_SNOW = [0.70, 0.74, 0.78, 0.82, 0.86, 0.92]


def snow_top(seed=501, n=2):
    base = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.3), [1, 3, 4, 2]) + 1)
    def make(k):
        r = rng(seed + 11 * k)
        lv = base.copy()
        for (x, y) in scatter(r, 3, 5, 1, 1):
            lv[y, x] = 5                                  # sparkles (rare singles are OK)
        for (x, y) in scatter(r, 2, 6, 3, 1):
            stamp(lv, x, y, ["DDD"], {"D": 0})            # little drift shadows
        return lv
    return [to_rgb(lv, S_SNOW, warm=0.0) * np.array([0.99, 1.0, 1.02]) for lv in family(n, make)]


def ice_top(seed=511):
    ys, xs = np.mgrid[0:N, 0:N]
    lv = np.full((N, N), 3)
    streak = ((xs + ys) % 16 == 3) | ((xs + ys) % 16 == 4)
    lv[streak] = 5
    lv[((xs + ys) % 16 == 11)] = 4
    soft = pnoise(2, 2, seed) < 0.3
    lv[soft & ~streak] = 2
    # cracks (two short lines)
    for (x0, y0, dx, dy, ln) in [(3, 9, 1, 0, 4), (11, 3, 0, 1, 3)]:
        for i in range(ln):
            lv[(y0 + i * dy) % N, (x0 + i * dx) % N] = 0
    return lv


def ice_side(seed=521):
    ys, xs = np.mgrid[0:N, 0:N]
    lv = np.full((N, N), 3)
    lv[(xs % 8 == 2) | (xs % 8 == 3)] = 4
    lv[pnoise(2, 3, seed) < 0.28] = 2
    lv[(ys % 8 == 7)] = 1        # faint block layers
    return lv


S_MUD = [0.56, 0.64, 0.72, 0.80, 0.90, 1.0]


def mud_top(seed=601, n=2):
    base = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.4), [2, 3, 3, 2]) + 1)
    def make(k):
        lv = base.copy()
        wet = pnoise(3, 3, seed + 5 + k * 9) > 0.68
        lv[wet] = 0
        lv[wet & ~np.roll(wet, 1, axis=0)] = 5         # wet glint on the top edge of puddles
        r = rng(seed + k)
        for (x, y) in scatter(r, 2, 6, 2, 2):
            stamp(lv, x, y, PEBBLE, {"L": 4, "M": 3, "D": 1})
        return lv
    return [to_rgb(lv, S_MUD) for lv in family(n, make)]


def mud_side(seed=611):
    lv = clean_lonely(rank_levels(fbm(seed, 2, 4, 0.4, sy=2), [2, 3, 3, 2]) + 1)
    r = rng(seed)
    for (x, y) in scatter(r, 2, 7, 1, 4, margin=1):        # hanging roots
        stamp(lv, x, y, ["D", "D", ".D", ".D"], {"D": 0})
    for (x, y) in scatter(r, 2, 6, 2, 1, margin=1):
        stamp(lv, x, y, ["LL"], {"L": 4})
    return lv


S_CAVE = [0.56, 0.64, 0.72, 0.80, 0.88, 1.0]


def cave_top(seed=701, n=2):
    border_pts = [(1, 1), (10, 1.5), (15.5, 9), (3, 13)]
    def make(k):
        r = rng(seed + 3 * k)
        inner = [(float(r.uniform(5, 11)), float(r.uniform(5, 11)))]
        idx, crack = voronoi([(float(a), float(b)) for a, b in border_pts] + inner)
        lv = np.array([2, 3, 2, 3, 2])[idx]
        lv = bevel(lv, crack, 4, None, 0)
        for (x, y) in scatter(r, 2, 6, 1, 1, margin=3):
            lv[y, x] = 5                                     # mineral glints
        return lv
    return [to_rgb(lv, S_CAVE, warm=0.0) * np.array([0.99, 0.98, 1.02]) for lv in family(n, make)]


def cave_side(seed=711):
    pts = [(2, 2), (11, 3), (6, 10), (14, 12)]
    idx, crack = voronoi([(float(a), float(b)) for a, b in pts], sx=0.7, sy=1.3)
    lv = np.array([2, 3, 2, 3])[idx]
    return bevel(lv, crack, 4, None, 0)


def gravel_top(seed=801, n=2):
    def make(k):
        r = rng(seed + 21 * k)
        pts = [(float(r.uniform(0, 16)), float(r.uniform(0, 16))) for _ in range(7)]
        idx, crack = voronoi(pts)
        tones = r.integers(1, 4, size=len(pts))
        lv = tones[idx]
        return bevel(lv, crack, 4, None, 1)
    imgs = family(n, make)
    return [to_rgb(lv, S_STONE, warm=0.03) for lv in imgs]


def gravel_side(seed=811):
    r = rng(seed)
    pts = [(float(r.uniform(0, 16)), float(r.uniform(0, 16))) for _ in range(7)]
    idx, crack = voronoi(pts, sx=0.8, sy=1.2)
    lv = r.integers(1, 4, size=len(pts))[idx]
    return bevel(lv, crack, 4, 1, 0)


def crystal_side(seed=901):
    lv = dirt_side(seed)
    r = rng(seed + 1)
    for (x, y) in scatter(r, 2, 7, 2, 3, margin=1):          # little crystal shards
        stamp(lv, x, y, [".W", "WL", "LD"], {"W": 5, "L": 4, "D": 0})
    return lv


# ---------------------------------------------------------------------------
# Edge bands (rows 0-7 = the side of the TOP block, 0.5 m). alpha = top mask.
# ---------------------------------------------------------------------------

def edge_band(top_rgb: np.ndarray, side_rgb: np.ndarray, seed: int,
              depth_min=2, depth_max=5, drips=3, lip=1.12, tip=0.78, under=0.84,
              round_tips=False):
    n = pnoise(3, 1, seed)[0]                 # one value per column (periodic)
    depth = np.round(depth_min + n * (depth_max - depth_min)).astype(int)
    r = rng(seed)
    for x in r.choice(N, size=drips, replace=False):
        depth[x] = min(depth[x] + 2, 7)       # a few longer drips
    if round_tips:                            # snow: smooth bumps, no thin drips
        depth = np.maximum(depth, np.roll(depth, 1) - 1)
        depth = np.maximum(depth, np.roll(depth, -1) - 1)
    rgb = side_rgb.copy()
    alpha = np.zeros((N, N), np.uint8)
    flat = top_rgb.reshape(-1, 3)
    lum = flat.mean(1)
    lip_c = np.clip(flat[np.argmax(lum)] * lip / 1.12, 0, 1)      # brightest shade = lit lip
    tip_c = flat[np.argmin(lum)] * (tip / 0.78)                  # darkest shade = drip tip
    for x in range(N):
        d = depth[x]
        for y in range(d):
            c = top_rgb[(y * 2 + 3) % N, x].copy()
            if y == 0:
                c = lip_c
            elif y == d - 1:
                c = tip_c
            rgb[y, x] = c
            alpha[y, x] = 255
        if d < N:
            rgb[d, x] = side_rgb[d, x] * under   # shade under the overhang
    return np.clip(rgb, 0, 1), alpha


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
S_WOOD = [0.56, 0.66, 0.76, 0.84, 0.92, 1.0]


def bark(seed=1001):
    ys, xs = np.mgrid[0:N, 0:N]
    wob = np.round((pnoise(1, 2, seed) - 0.5) * 2).astype(int)
    lv = np.full((N, N), 3)
    for gx in (1, 6, 11):                      # three grooves, wiggling
        col = (gx + wob[:, 0]) % N
        lv[ys[:, 0], col] = 0
        lv[ys[:, 0], (col + 1) % N] = 2
    plates = pnoise(2, 3, seed + 3) > 0.62
    lv[plates & (lv == 3)] = 4
    r = rng(seed)
    for (x, y) in scatter(r, 1, 8, 2, 2, margin=3):      # a small knot
        stamp(lv, x, y, ["DL", "LD"], {"D": 1, "L": 4})
    return lv


S_LEAF = [0.52, 0.62, 0.72, 0.82, 0.92, 1.02]


def leaves_oak(seed=1101):
    """Round leaf clumps: big blobs lit from top-left with dark gaps."""
    pts = [(2, 3), (8, 1.5), (13, 4), (5, 9), (11, 10), (1.5, 14), (8, 15)]
    idx, crack = voronoi([(float(a), float(b)) for a, b in pts])
    lv = np.full((N, N), 3)
    lv = bevel(lv, crack, 4, 2, 0)
    hi = np.roll(np.roll(crack, 2, axis=0), 2, axis=1) & ~crack
    lv[hi & (lv == 3)] = 5
    return lv


def leaves_pine(seed=1201):
    """Rows of downward chevrons (needle sprigs)."""
    lv = np.full((N, N), 2)
    for row0 in (0, 8):
        for x in range(N):
            d = abs((x % 8) - 3.5)
            y = int(row0 + 1 + d * 0.8)
            lv[y % N, x] = 4
            lv[(y + 1) % N, x] = 3
            lv[(y + 3) % N, x] = 0
    lv[pnoise(2, 2, seed) > 0.75] = 1
    return clean_lonely(lv, 1)


def leaves_jungle(seed=1301):
    """Big broad leaves with a mid line."""
    lv = np.full((N, N), 1)
    for (cx, cy, flip) in [(4, 4, 1), (12, 4, -1), (8, 12, 1), (0, 12, -1)]:
        for y in range(-3, 4):
            w = 4 - abs(y)
            for x in range(-w - 1, w + 2):
                xx, yy = (cx + x) % N, (cy + y) % N
                lv[yy, xx] = 4 if (y < 0 or x * flip < 0) else 3
            lv[(cy + y) % N, (cx + y * flip // 2) % N] = 2          # mid rib
        lv[(cy + 4) % N, cx % N] = 0
    return lv


def boulder(seed=1401):
    pts = [(3, 3), (11, 2), (14, 10), (6, 11), (1, 15)]
    idx, crack = voronoi([(float(a), float(b)) for a, b in pts])
    lv = np.array([3, 2, 3, 2, 3])[idx]
    lv = bevel(lv, crack, 4, None, 1)
    moss = pnoise(2, 2, seed) > 0.8
    lv[moss & (lv >= 2)] = 5
    return lv


ORES = {   # stone base + nugget colours (dark, mid, light) in sRGB
    "copper": [(0.60, 0.31, 0.16), (0.86, 0.50, 0.25), (0.98, 0.72, 0.45), (0.36, 0.66, 0.56)],
    "iron":   [(0.55, 0.40, 0.34), (0.80, 0.62, 0.53), (0.95, 0.82, 0.72), None],
    "coal":   [(0.07, 0.07, 0.08), (0.15, 0.15, 0.17), (0.38, 0.38, 0.42), None],
    "silver": [(0.58, 0.66, 0.78), (0.82, 0.88, 0.96), (1.00, 1.00, 1.00), None],
}


def ore(name: str, seed: int):
    stone_lv = cave_side(seed)
    stone_rgb = to_rgb(stone_lv, [0.36, 0.42, 0.48, 0.54, 0.60, 0.66], warm=0.02)
    dark, mid, light, extra = ORES[name]
    rgb = stone_rgb.copy()
    r = rng(seed + 5)
    shape = [".MM", "MLM", "DMD"] if name != "coal" else ["MM.", "MLM", ".DM"]
    for (x, y) in scatter(r, 4, 5.5, 3, 3, margin=1):
        for j, row in enumerate(shape):
            for i, ch in enumerate(row):
                col = {"M": mid, "L": light, "D": dark}.get(ch)
                if col is not None:
                    rgb[(y + j) % N, (x + i) % N] = col
    if extra is not None:   # copper: a few green patina pixels
        for (x, y) in scatter(r, 2, 6, 1, 1, margin=2):
            rgb[y, x] = extra
    return rgb


# ---------------------------------------------------------------------------
# Build everything
# ---------------------------------------------------------------------------

def tinted(lv_or_rgb, shades=None, warm=0.035):
    rgb = lv_or_rgb if shades is None else to_rgb(lv_or_rgb, shades, warm)
    return normalise_mean(rgb)


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))

    dirt_s = tinted(dirt_side(), G6)
    save("dirt_side", dirt_s, "tinted", "Dirt wall: soft blobs + a few pebbles. 16x16 = 1 m (two blocks).", "side", group="dirt")
    save("dirt_top", tinted(dirt_top(), G6), "tinted", "Bare dirt from above.", "top", group="dirt")

    grass = {
        "meadow": 1, "forest": 2, "jungle": 3, "taiga": 4, "swamp": 5, "alpine": 6, "crystal": 7,
    }
    desc = {
        "meadow": "Soft blobs + light grass tufts (Verdant Meadows).",
        "forest": "Clover leaves + dark leaf litter (Whispering Forest).",
        "jungle": "Big broad leaves (Emerald Jungle).",
        "taiga": "Fallen needles + few tufts (Frostpine Taiga).",
        "swamp": "Moss with dark wet puddles and glints (Murk Swamp).",
        "alpine": "Short sparse tufts, bare patches (Stonecrown grass).",
        "crystal": "Violet moss with small sparkles (Crystal Glade ground).",
    }
    side_for = {"crystal": tinted(crystal_side(), G6), "swamp": tinted(mud_side(), S_MUD)}
    save("crystal_side", side_for["crystal"], "tinted", "Dirt wall with small crystal shards.", "side", group="crystal_ground")
    save("mud_side", side_for["swamp"], "tinted", "Dark mud wall with hanging roots.", "side", group="swamp_mud")
    for style, s in grass.items():
        vs = normalise_family(grass_top(style, 1000 + s * 17))
        grp = "crystal_ground" if style == "crystal" else f"grass_{style}"
        base = "crystal_ground" if style == "crystal" else f"grass_{style}"
        for k, v in enumerate(vs):
            save(f"{base}_top_{k}", v, "tinted", desc[style] + f" Variant {k}.", "top", group=grp)
        side_rgb = side_for.get(style, dirt_s)
        e_rgb, e_a = edge_band(vs[0], side_rgb, 2000 + s)
        save(f"{base}_edge", e_rgb, "tinted_edge",
             "Side band of the top block. Rows 0-7 are used (0.5 m). alpha 255 = top part (top colour), "
             "alpha 0 = side part (side colour + side texture).", "edge", alpha=e_a, group=grp)

    for k, v in enumerate(normalise_family(sand_top())):
        save(f"sand_top_{k}", v, "tinted", f"Beach / shore sand, calm, few grains. Variant {k}.", "top", group="sand")
    save("sand_side", tinted(sand_side(), S_SAND), "tinted", "Sand wall: soft horizontal layers.", "side", group="sand")
    for k, v in enumerate(normalise_family(desert_top())):
        save(f"desert_sand_top_{k}", v, "tinted", f"Desert sand with wind ripples (all variants share direction). Variant {k}.", "top", group="desert_sand")
    save("desert_sand_side", tinted(sand_side(321), S_SAND, warm=0.05), "tinted", "Desert sand wall.", "side", group="desert_sand")
    save("sandstone_side", tinted(sandstone_side(), G6, warm=0.05), "tinted", "Sandstone: 4-pixel layers with a lit lip and a shadow line.", "side", group="sandstone")
    save("sandstone_top", tinted(sandstone_top(), G6, warm=0.05), "tinted", "Sandstone slabs from above.", "top", group="sandstone")

    for k, v in enumerate(normalise_family(stone_top())):
        save(f"stone_top_{k}", v, "tinted", f"Stone: big flat facets, cracks, light from top-left. Variant {k}.", "top", group="stone")
    for k, v in enumerate(normalise_family(stone_side())):
        save(f"stone_side_{k}", v, "tinted", f"Stone wall: wide flat slabs. Variant {k}.", "side", group="stone")
    for k, v in enumerate(normalise_family(mountain_rock_top())):
        save(f"mountain_rock_top_{k}", v, "tinted", f"Mountain rock from above: chunky facets. Variant {k}.", "top", group="mountain_rock")
    save("mountain_rock_side", tinted(mountain_rock_side(), S_STONE, warm=0.03), "tinted", "Cliff: strong horizontal strata + vertical cracks.", "side", group="mountain_rock")

    snow = normalise_family(snow_top())
    for k, v in enumerate(snow):
        save(f"snow_top_{k}", v, "tinted", f"Snow: very soft drifts, rare sparkles. Variant {k}.", "top", group="snow")
    e_rgb, e_a = edge_band(snow[0], dirt_s, 2100, depth_min=3, depth_max=5, drips=0, lip=1.06, tip=0.86, round_tips=True)
    save("snow_edge", e_rgb, "tinted_edge", "Snow cap over dirt: rounded bumps, no thin drips.", "edge", alpha=e_a, group="snow")
    save("snow_side", tinted(sand_side(531), S_SNOW, warm=0.0), "tinted", "Packed snow wall (for snow blocks deeper than one block).", "side", group="snow")
    save("ice_top", tinted(ice_top(), S_SNOW, warm=0.0), "tinted", "Ice sheet: diagonal glints, two small cracks. Tint with ice_color.", "top", group="ice")
    save("ice_side", tinted(ice_side(), S_SNOW, warm=0.0), "tinted", "Ice wall: vertical light bands.", "side", group="ice")

    for k, v in enumerate(normalise_family(mud_top())):
        save(f"swamp_mud_top_{k}", v, "tinted", f"Swamp mud: wet puddles with glints. Variant {k}.", "top", group="swamp_mud")

    for k, v in enumerate(normalise_family(cave_top())):
        save(f"cave_stone_top_{k}", v, "tinted", f"Cave floor: rough facets, mineral glints. Variant {k}.", "top", group="cave_stone")
    save("cave_stone_side", tinted(cave_side(), S_CAVE, warm=0.0), "tinted", "Cave wall: rough tall facets.", "side", group="cave_stone")
    for k, v in enumerate(normalise_family(gravel_top())):
        save(f"gravel_top_{k}", v, "tinted", f"Gravel / riverbed: round pebbles with outlines. Variant {k}.", "top", group="gravel")
    save("gravel_side", tinted(gravel_side(), S_STONE, warm=0.03), "tinted", "Gravel wall.", "side", group="gravel")

    save("bark", tinted(bark(), S_WOOD), "tinted", "Tree bark: three wiggling vertical grooves, plates, one knot. All trunks.", "prop", group="bark")
    save("leaves_oak", tinted(leaves_oak(), S_LEAF), "tinted", "Oak leaves: round clumps lit from top-left.", "prop", group="leaves")
    save("leaves_pine", tinted(leaves_pine(), S_LEAF), "tinted", "Pine needles: rows of downward chevrons.", "prop", group="leaves")
    save("leaves_jungle", tinted(leaves_jungle(), S_LEAF), "tinted", "Jungle leaves: big broad leaves with a rib.", "prop", group="leaves")
    save("boulder", tinted(boulder(), S_STONE, warm=0.03), "tinted", "Boulder / rock props: big facets, a little moss light.", "prop", group="boulder")
    for i, name in enumerate(ORES):
        save(f"ore_{name}", ore(name, 1500 + i * 10), "full", f"Ore rock ({name}): dark stone with {name} nuggets. Full colour - use white vertex colour.", "prop", group="ore")

    import texgen_extra          # plants, sprites, building blocks
    texgen_extra.build()

    with open(os.path.join(OUT, "textures.json"), "w") as f:
        json.dump({"tex_gain": TEX_GAIN, "textures": TEXTURES}, f, indent=1)
    print(f"{len(TEXTURES)} textures written to {OUT}")


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import texgen               # run as module "texgen" so texgen_extra shares TEXTURES
    texgen.main()
