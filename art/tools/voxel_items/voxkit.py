"""
voxkit — small voxel-art kit for Jihad's Godot games.

How it works (simple version):
  1. You build an item from boxes/balls/lines, each with a MATERIAL name
     ("steel", "wood", "leather", "fire" ...).
  2. bake() colours every voxel automatically with the house style:
       - each material has a colour ramp (dark -> light)
       - top/left edges get one step lighter, bottom/right edges one step darker
       - wood gets grain streaks, stone gets speckles, metal a little noise
     This is what makes every item look like it belongs to the same set.
  3. render() makes a preview picture (AO + shadows + glow).
  4. export_gd.py writes the items as GDScript data, so the game builds the
     meshes in code (no model or texture files).

Coordinates: x = left/right, y = front/back (front is y=0), z = up.
"""
import math
import numpy as np
from PIL import Image, ImageFilter

# ----------------------------------------------------------------------------
# PALETTE — sampled from the reference sheets, then cleaned into ramps.
# Rule: shadows shift to blue/purple, lights shift to warm. Metal and stone
# are low-saturation; wood/leather mids are saturated red-brown; only accents
# (gems, cloth wraps) and glows are strongly saturated.
# ----------------------------------------------------------------------------
RAMPS = [
    # name        dark -> light                                                       emissive
    ("steel",   ["#1e1d27", "#2c2b37", "#3c3b4a", "#4d4e5c", "#5f646e", "#747b80",
                 "#8e9696", "#aeb6b2", "#d8ded6"], False),
    ("wood",    ["#22120f", "#331a16", "#47241c", "#5c2f23", "#733d2b", "#8c5036",
                 "#a76845", "#c2875e"], False),
    ("leather", ["#2a1113", "#3e191a", "#55221f", "#6e2d26", "#883c2e", "#a3513a"], False),
    ("cloth_g", ["#142c18", "#1f3f20", "#2c5429", "#3c6c33", "#528742"], False),
    ("cloth_r", ["#3b0f12", "#591619", "#7a1f1c", "#9d2e23", "#bf4632"], False),
    ("cloth_p", ["#22132d", "#341c45", "#48285e", "#5f377a", "#794d97"], False),
    ("gold",    ["#3a2109", "#5c3811", "#84541a", "#ad7527", "#d19a38", "#edc160",
                 "#fde19a"], False),
    ("bone",    ["#4d4034", "#6c5b49", "#8d7961", "#ad987b", "#cab898", "#e4d6b8",
                 "#f6efd9"], False),
    ("stone",   ["#1c1a19", "#292624", "#373330", "#48433e", "#5b554f", "#706962",
                 "#888177", "#a29b90"], False),
    ("glass",   ["#2a434d", "#3c5f6b", "#56838f", "#7ba9b4", "#a6cdd5", "#d3ecf0",
                 "#f5fcfd"], False),
    ("rope",    ["#473420", "#61462a", "#7c5c37", "#997749", "#b69661", "#d1b680"], False),
    ("gem_r",   ["#380910", "#5a1019", "#821824", "#ad2631", "#d5443d", "#f0765e",
                 "#ffb39f"], False),
    ("gem_b",   ["#0f1a42", "#152766", "#1d3b90", "#2a56b9", "#4277da", "#71a1ee",
                 "#b2d0fa"], False),
    ("fire",    ["#7a1c0c", "#a8300f", "#d24c17", "#ef7421", "#ffa236", "#ffcd5c",
                 "#ffeb9e", "#fffbe5"], True),
    ("magic",   ["#135c26", "#1f8236", "#33a845", "#55cc5a", "#86e678", "#bdf6a6",
                 "#ecffdf"], True),
    ("arcane",  ["#153f73", "#1f5f9e", "#2f84c6", "#4caee6", "#7fd2f7", "#b9ecfd",
                 "#effcff"], True),
    ("teal",    ["#0f3532", "#16504a", "#1f6d63", "#2b8c7e", "#40ab98", "#66c9b3"], False),
    # Neutral ramps the GAME tints per item (item.icon_color). Grey here, coloured in-game.
    ("accent",  ["#2a2a2a", "#424242", "#5c5c5c", "#777777", "#949494", "#b3b3b3",
                 "#d4d4d4"], False),
    ("accent_glow", ["#5a5a5a", "#7a7a7a", "#9a9a9a", "#bbbbbb", "#dadada", "#f0f0f0",
                     "#ffffff"], True),
]

# Which ramps the game recolours: 1 = metal (weapon_color), 2 = accent (icon colour).
TINT_GROUP = {"steel": 1, "accent": 2, "accent_glow": 2}

# material name -> (ramp, base level, light-edge bonus, dark-edge penalty, noise, texture)
MATERIALS = {
    "steel":   ("steel",   5, 1, 1, 0.14, "metal"),
    "dsteel":  ("steel",   3, 1, 1, 0.14, "metal"),   # dark iron
    "wood":    ("wood",    4, 1, 1, 0.00, "grain"),
    "dwood":   ("wood",    3, 1, 1, 0.00, "grain"),
    "lwood":   ("wood",    5, 1, 1, 0.00, "grain"),
    "leather": ("leather", 3, 1, 1, 0.12, "none"),
    "cloth_g": ("cloth_g", 2, 1, 1, 0.10, "none"),
    "cloth_r": ("cloth_r", 3, 1, 1, 0.10, "none"),
    "cloth_p": ("cloth_p", 3, 1, 1, 0.10, "none"),
    "gold":    ("gold",    4, 1, 1, 0.05, "metal"),
    "bone":    ("bone",    4, 1, 1, 0.12, "none"),
    "stone":   ("stone",   4, 1, 1, 0.00, "speckle"),
    "glass":   ("glass",   3, 1, 1, 0.00, "none"),
    "rope":    ("rope",    3, 1, 1, 0.08, "none"),
    "gem_r":   ("gem_r",   3, 1, 1, 0.00, "none"),
    "gem_b":   ("gem_b",   3, 1, 1, 0.00, "none"),
    "fire":    ("fire",    4, 0, 0, 0.00, "none"),
    "magic":   ("magic",   3, 0, 0, 0.00, "none"),
    "arcane":  ("arcane",  3, 0, 0, 0.00, "none"),
    "teal":    ("teal",    3, 1, 1, 0.08, "none"),
    "accent":  ("accent",  3, 1, 1, 0.08, "none"),
    "glow":    ("accent_glow", 3, 0, 0, 0.00, "none"),
}


def _hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Palette:
    def __init__(self):
        self.rgb = [(0, 0, 0)]          # index 0 = empty
        self.emissive = [False]
        self.tint = [0]
        self.names = ["empty"]
        self.ramp = {}
        for name, cols, em in RAMPS:
            idx = []
            for i, h in enumerate(cols):
                self.rgb.append(_hex(h))
                self.emissive.append(em)
                self.tint.append(TINT_GROUP.get(name, 0))
                self.names.append(f"{name}_{i}")
                idx.append(len(self.rgb) - 1)
            self.ramp[name] = idx
        assert len(self.rgb) <= 256

    def rgb_array(self):
        return np.array(self.rgb, float) / 255.0

    def emissive_array(self):
        return np.array(self.emissive, bool)


PAL = Palette()
MAT_NAMES = ["empty"] + list(MATERIALS.keys())
MAT_ID = {n: i for i, n in enumerate(MAT_NAMES)}
AXIS = {"x": 0, "y": 1, "z": 2}


class Vox:
    """A voxel item. sx, sy, sz = grid size. kind = 'hand' or 'prop'."""

    def __init__(self, name, sx, sy, sz, kind="prop", view=(35, 24), anchor=None, label=None):
        self.name = name
        self.label = label or name.replace("_", " ").title()
        self.kind = kind
        self.view = view
        self.m = np.zeros((sx, sy, sz), np.uint8)    # material id
        self.o = np.zeros((sx, sy, sz), np.int8)     # shade offset (+lighter / -darker)
        self.ga = np.full((sx, sy, sz), 255, np.uint8)  # grain axis for wood
        self.lock = np.zeros((sx, sy, sz), bool)     # True = no auto bevel/noise
        # anchor = pivot point in voxel units (hand items: grip; props: bottom centre)
        self.anchor = anchor if anchor is not None else (sx / 2.0, sy / 2.0, 0.0)
        # real-world size in the game: metres per voxel (hand items are denser)
        self.meters = 1.0 / 24.0 if kind == "hand" else 1.0 / 16.0
        self.g = None

    # ---------------- basic placing ----------------
    @property
    def shape(self):
        return self.m.shape

    def _sl(self, a0, a1, n):
        a0, a1 = (a0, a1) if a0 <= a1 else (a1, a0)
        return max(a0, 0), min(a1, n - 1) + 1

    def region(self, x0, x1, y0, y1, z0, z1):
        sx, sy, sz = self.shape
        X0, X1 = self._sl(x0, x1, sx)
        Y0, Y1 = self._sl(y0, y1, sy)
        Z0, Z1 = self._sl(z0, z1, sz)
        msk = np.zeros(self.shape, bool)
        if X0 < X1 and Y0 < Y1 and Z0 < Z1:
            msk[X0:X1, Y0:Y1, Z0:Z1] = True
        return msk

    def put(self, msk, mat, off=0, grain=None, lock=False):
        """Fill mask with a material. mat=None removes voxels."""
        if mat is None:
            self.m[msk] = 0
            self.o[msk] = 0
            self.ga[msk] = 255
            self.lock[msk] = False
            return
        self.m[msk] = MAT_ID[mat]
        self.o[msk] = off
        self.ga[msk] = AXIS[grain] if grain else 255
        self.lock[msk] = lock

    def box(self, x0, x1, y0, y1, z0, z1, mat, off=0, grain=None, lock=False):
        self.put(self.region(x0, x1, y0, y1, z0, z1), mat, off, grain, lock)

    def v(self, x, y, z, mat, off=0, lock=False):
        sx, sy, sz = self.shape
        if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz:
            if mat is None:
                self.m[x, y, z] = 0
            else:
                self.m[x, y, z] = MAT_ID[mat]
                self.o[x, y, z] = off
                self.lock[x, y, z] = lock

    def clear(self, x0, x1, y0, y1, z0, z1):
        self.put(self.region(x0, x1, y0, y1, z0, z1), None)

    def grid(self):
        sx, sy, sz = self.shape
        return np.meshgrid(np.arange(sx) + 0.5, np.arange(sy) + 0.5, np.arange(sz) + 0.5, indexing="ij")

    def ell(self, cx, cy, cz, rx, ry, rz, mat, off=0, grain=None, lock=False):
        X, Y, Z = self.grid()
        msk = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + ((Z - cz) / rz) ** 2 <= 1.0
        self.put(msk, mat, off, grain, lock)
        return msk

    def cyl_z(self, cx, cy, r, z0, z1, mat, off=0, grain=None, lock=False, ry=None):
        X, Y, Z = self.grid()
        ry = ry or r
        msk = (((X - cx) / r) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0) & (Z >= z0) & (Z <= z1 + 1)
        self.put(msk, mat, off, grain, lock)
        return msk

    def cyl_y(self, cx, cz, r, y0, y1, mat, off=0, grain=None, lock=False):
        X, Y, Z = self.grid()
        msk = ((X - cx) ** 2 + (Z - cz) ** 2 <= r * r) & (Y >= y0) & (Y <= y1 + 1)
        self.put(msk, mat, off, grain, lock)
        return msk

    def line(self, p0, p1, mat, off=0, r=0.0, grain=None, lock=False):
        """Thick 3D line from p0 to p1 (voxel coords)."""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        n = int(np.ceil(np.abs(p1 - p0).max() * 2)) + 1
        msk = np.zeros(self.shape, bool)
        sx, sy, sz = self.shape
        for t in np.linspace(0, 1, n):
            p = p0 + (p1 - p0) * t
            if r <= 0:
                x, y, z = np.round(p).astype(int)
                if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz:
                    msk[x, y, z] = True
            else:
                ri = int(np.ceil(r))
                c = np.round(p).astype(int)
                for dx in range(-ri, ri + 1):
                    for dy in range(-ri, ri + 1):
                        for dz in range(-ri, ri + 1):
                            if dx * dx + dy * dy + dz * dz <= r * r + 0.01:
                                x, y, z = c + (dx, dy, dz)
                                if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz:
                                    msk[x, y, z] = True
        self.put(msk, mat, off, grain, lock)
        return msk

    def shade(self, msk, delta):
        """Make existing voxels in mask lighter (+) or darker (-)."""
        msk = msk & (self.m > 0)
        self.o[msk] = np.clip(self.o[msk].astype(int) + delta, -8, 8)

    def shade_box(self, x0, x1, y0, y1, z0, z1, delta):
        self.shade(self.region(x0, x1, y0, y1, z0, z1), delta)

    def mirror_x(self):
        """Copy the left half onto the right half (for symmetric items)."""
        sx = self.shape[0]
        h = sx // 2
        self.m[sx - h:] = self.m[:h][::-1]
        self.o[sx - h:] = self.o[:h][::-1]
        self.ga[sx - h:] = self.ga[:h][::-1]
        self.lock[sx - h:] = self.lock[:h][::-1]

    # ---------------- auto colouring ----------------
    def bake(self, seed=None):
        """Turn materials + offsets into final palette indices (self.g)."""
        rng = np.random.default_rng(seed if seed is not None else (abs(hash(self.name)) % (2 ** 31)))
        occ = self.m > 0
        P = np.pad(occ, 1)
        exp = {}
        for ax in range(3):
            for s in (-1, 1):
                sl = [slice(1, -1)] * 3
                sl[ax] = slice(1 + s, P.shape[ax] - 1 + s)
                exp[(ax, s)] = occ & ~P[tuple(sl)]
        n_axes = sum(((exp[(a, -1)] | exp[(a, 1)]).astype(int) for a in range(3)))
        edge = n_axes >= 2
        light = edge & (exp[(2, 1)] | exp[(0, -1)])
        dark = edge & (exp[(2, -1)] | exp[(0, 1)])

        lev = np.zeros(self.shape, int)
        hi = np.zeros(self.shape, int)
        for name, (ramp, base, bl, bd, noise, tex) in MATERIALS.items():
            mid = MAT_ID[name]
            msk = self.m == mid
            if not msk.any():
                continue
            free = msk & ~self.lock
            lev[msk] = base
            lev[free & light] += bl
            lev[free & dark] -= bd
            if noise > 0:
                r = rng.random(self.shape)
                lev[free & (r < noise / 2)] -= 1
                lev[free & (r > 1 - noise / 2)] += 1
            if tex == "grain":
                for ax in range(3):
                    gm = free & (self.ga == ax)
                    if not gm.any():
                        continue
                    seedm = rng.random(self.shape) < 0.10
                    streak = seedm.copy()
                    for k in (1, 2):
                        streak |= np.roll(seedm, k, axis=ax)
                    lev[gm & streak] -= 1
                    hl = rng.random(self.shape) < 0.05
                    lev[gm & hl & ~streak] += 1
                    # plain wood with no grain axis gets light noise
                nm = free & (self.ga == 255)
                r = rng.random(self.shape)
                lev[nm & (r < 0.08)] -= 1
                lev[nm & (r > 0.95)] += 1
            if tex == "speckle":
                r = rng.random(self.shape)
                lev[free & (r < 0.14)] -= 1
                lev[free & (r > 0.90)] += 1
            if tex == "metal":
                glint = free & edge & exp[(2, 1)] & exp[(0, -1)]
                lev[glint] += 1
            hi[msk] = len(PAL.ramp[ramp]) - 1
        lev += self.o.astype(int)
        lev = np.clip(lev, 0, hi)
        g = np.zeros(self.shape, np.uint8)
        for name, (ramp, *_rest) in MATERIALS.items():
            mid = MAT_ID[name]
            msk = self.m == mid
            if msk.any():
                g[msk] = np.array(PAL.ramp[ramp])[lev[msk]]
        self.g = g
        return g

    def count(self):
        return int((self.m > 0).sum())


# ----------------------------------------------------------------------------
# RENDERER — orthographic voxel ray tracer (numpy). Ambient occlusion,
# shadows, glow. Used only for previews; Godot does its own lighting.
# ----------------------------------------------------------------------------
AO_CURVE = [0.50, 0.68, 0.85, 1.0]


def _dda(occ, O, d, tmin_floor=0.0):
    N = np.array(occ.shape)
    inv = 1.0 / d
    t1 = (0 - O) * inv
    t2 = (N - O) * inv
    tmin = np.maximum(np.minimum(t1, t2).max(1), tmin_floor)
    tmax = np.maximum(t1, t2).min(1)
    valid = tmax > tmin
    M = len(O)
    hit = np.zeros(M, bool)
    hv = np.zeros((M, 3), int)
    ha = np.zeros(M, int)
    ht = np.zeros(M)
    ids = np.nonzero(valid)[0]
    if len(ids) == 0:
        return hit, hv, ha, ht
    P = O[ids] + d * (tmin[ids, None] + 1e-5)
    cell = np.clip(np.floor(P).astype(int), 0, N - 1)
    step = np.where(d > 0, 1, -1)
    tdel = np.abs(inv)
    nb = cell + (step > 0)
    tMax = (nb - O[ids]) * inv
    tEnter = tmin[ids].copy()
    axis = np.zeros(len(ids), int)
    active = np.ones(len(ids), bool)
    ar = np.arange(len(ids))
    for _ in range(int(N.sum()) + 4):
        ai = ar[active]
        if len(ai) == 0:
            break
        ax = tMax[ai].argmin(1)
        tEnter[ai] = tMax[ai, ax]
        cell[ai, ax] += step[ax]
        tMax[ai, ax] += tdel[ax]
        axis[ai] = ax
        c = cell[ai]
        out = ((c < 0) | (c >= N)).any(1)
        active[ai[out]] = False
        ii = ai[~out]
        cc = cell[ii]
        oc = occ[cc[:, 0], cc[:, 1], cc[:, 2]]
        hh = ii[oc]
        active[hh] = False
        hit[ids[hh]] = True
        hv[ids[hh]] = cell[hh]
        ha[ids[hh]] = axis[hh]
        ht[ids[hh]] = tEnter[hh]
    return hit, hv, ha, ht


METAL_REF = (0.78, 0.80, 0.86)   # the game's default weapon_color = no change


def tinted_palette(tints=None):
    """Palette with the game's tints applied (same maths as voxel_items.gd)."""
    pal = PAL.rgb_array().copy()
    tints = tints or {}
    grp = np.array(PAL.tint)
    if 1 in tints:
        f = np.array(tints[1], float) / np.array(METAL_REF)
        pal[grp == 1] = np.clip(pal[grp == 1] * f, 0, 1)
    acc = np.array(tints.get(2, (0.55, 0.36, 0.2)), float)
    pal[grp == 2] = np.clip(pal[grp == 2] * acc * 1.3, 0, 1)
    return pal


def render(item, ppv=12, ss=2, az=None, el=None, key_dir=None, return_glow=True, tints=None):
    """Render a baked Vox. Returns (RGBA image, glow RGB image or None)."""
    if item.g is None:
        item.bake()
    az = item.view[0] if az is None else az
    el = item.view[1] if el is None else el
    pad = 2
    G = np.pad(item.g, pad)
    occ = G > 0
    N = np.array(G.shape)
    pal = tinted_palette(tints)
    emis = PAL.emissive_array()

    a, e = math.radians(az), math.radians(el)
    c = np.array([math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)])
    f = -c
    up = np.array([0.0, 0.0, 1.0])
    r = np.cross(f, up)
    r /= np.linalg.norm(r)
    u = np.cross(r, f)

    pts = np.argwhere(occ)
    mn, mx = pts.min(0), pts.max(0) + 1
    corners = np.array([[x, y, z] for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])], float)
    pr, pu = corners @ r, corners @ u
    margin = 2.5
    r0, r1 = pr.min() - margin, pr.max() + margin
    u0, u1 = pu.min() - margin, pu.max() + margin
    s = ppv * ss
    W = int(math.ceil((r1 - r0) * s))
    H = int(math.ceil((u1 - u0) * s))
    xs = r0 + (np.arange(W) + 0.5) / s
    ys = u1 - (np.arange(H) + 0.5) / s
    X, Y = np.meshgrid(xs, ys)
    D = float(N.sum()) * 2
    O = X.reshape(-1, 1) * r + Y.reshape(-1, 1) * u + D * c
    d = f.copy()
    d[np.abs(d) < 1e-9] = 1e-9

    hit, hv, ha, ht = _dda(occ, O, d)
    idx = np.nonzero(hit)[0]
    step = np.where(d > 0, 1, -1)
    ax = ha[idx]
    vox = hv[idx]
    n = np.zeros((len(idx), 3))
    n[np.arange(len(idx)), ax] = -step[ax]
    P = O[idx] + d * ht[idx, None]

    # ---- ambient occlusion (Minecraft style, per face corner, interpolated)
    eye = np.eye(3, dtype=int)
    b_ax = (ax + 1) % 3
    c_ax = (ax + 2) % 3
    fu = np.clip(P[np.arange(len(idx)), b_ax] - vox[np.arange(len(idx)), b_ax], 0, 1)
    fv = np.clip(P[np.arange(len(idx)), c_ax] - vox[np.arange(len(idx)), c_ax], 0, 1)
    front = vox + n.astype(int)
    eb = eye[b_ax]
    ec = eye[c_ax]

    def occ_at(p):
        p = np.clip(p, 0, N - 1)
        return occ[p[:, 0], p[:, 1], p[:, 2]].astype(int)

    ao = np.zeros(len(idx))
    for sb in (-1, 1):
        for sc in (-1, 1):
            s1 = occ_at(front + sb * eb)
            s2 = occ_at(front + sc * ec)
            cr = occ_at(front + sb * eb + sc * ec)
            lvl = np.where((s1 == 1) & (s2 == 1), 0, 3 - (s1 + s2 + cr))
            w = (fu if sb > 0 else 1 - fu) * (fv if sc > 0 else 1 - fv)
            ao += lvl * w
    aof = np.interp(ao, [0, 1, 2, 3], AO_CURVE)

    # ---- lights (key from top-left-front, soft fill from right)
    if key_dir is None:
        L = -0.55 * r + 0.85 * up + 0.70 * c
    else:
        L = np.array(key_dir, float)
    L /= np.linalg.norm(L)
    F = 0.85 * r + 0.15 * up + 0.45 * c
    F /= np.linalg.norm(F)
    ndl = np.clip(n @ L, 0, 1)
    ndf = np.clip(n @ F, 0, 1)

    # ---- shadows
    sh = np.ones(len(idx))
    lit = np.nonzero(ndl > 0)[0]
    if len(lit):
        So = P[lit] + n[lit] * 1e-3
        Ld = L.copy()
        Ld[np.abs(Ld) < 1e-9] = 1e-9
        shit, _, _, _ = _dda(occ, So, Ld)
        sh[lit] = np.where(shit, 0.0, 1.0)

    hemi = 0.5 + 0.5 * n[:, 2]
    amb = 0.30 + 0.22 * hemi
    light = amb * aof + 0.62 * ndl * (0.30 + 0.70 * sh) * (0.55 + 0.45 * aof) + 0.20 * ndf * aof
    pidx = G[vox[:, 0], vox[:, 1], vox[:, 2]]
    alb = pal[pidx]
    col = alb * light[:, None]
    em = emis[pidx]
    col[em] = alb[em]
    col = np.clip(col, 0, 1)

    img = np.zeros((H * W, 4))
    img[idx, :3] = col
    img[idx, 3] = 1.0
    glow = np.zeros((H * W, 3))
    glow[idx[em]] = alb[em]
    img = img.reshape(H, W, 4)
    glow = glow.reshape(H, W, 3)

    # downsample (anti-alias) with premultiplied alpha
    Wf, Hf = W // ss, H // ss
    img = img[: Hf * ss, : Wf * ss]
    glow = glow[: Hf * ss, : Wf * ss]
    img = img.reshape(Hf, ss, Wf, ss, 4).mean((1, 3))
    glow = glow.reshape(Hf, ss, Wf, ss, 3).mean((1, 3))
    a_ = img[..., 3:4]
    rgb = np.where(a_ > 0, img[..., :3] / np.maximum(a_, 1e-6), 0)
    out = np.concatenate([rgb, a_], -1)
    rgba = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    g_img = Image.fromarray((np.clip(glow, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB") if return_glow else None
    return rgba, g_img


def add_glow(base_rgb, glow_rgb, ppv):
    """Bloom: blur the emissive layer and add it on top (screen blend)."""
    g = glow_rgb
    b1 = np.asarray(g.filter(ImageFilter.GaussianBlur(ppv * 0.6)), float) / 255
    b2 = np.asarray(g.filter(ImageFilter.GaussianBlur(ppv * 2.0)), float) / 255
    bloom = np.clip(b1 * 0.70 + b2 * 0.75, 0, 1)
    base = np.asarray(base_rgb, float) / 255
    out = 1 - (1 - base) * (1 - bloom)
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
