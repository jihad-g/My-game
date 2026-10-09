"""Isometric biome previews with the game camera (yaw 45 deg, looking down 50 deg).

Small software renderer (numpy z-buffer, orthographic). It copies the game's
colour rules from terrain_generator.gd (per-block variation, darker sides,
grass-edge band, corner AO) and adds the textures the way the shader will.

    python3 art/tools/render_previews.py            -> art/previews/*.png
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from palette import BIOMES, PROPS, TEXTURE_GROUPS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEXDIR = os.path.join(ROOT, "art", "textures")
OUT = os.path.join(ROOT, "art", "previews")
GAIN = 1.25
BH = 0.5            # block height
SIZE = 14           # scene is SIZE x SIZE blocks
WATER_Y = -0.15

# ---------------------------------------------------------------- textures
META = json.load(open(os.path.join(TEXDIR, "textures.json")))["textures"]
TEX = {}
for name, m in META.items():
    a = np.asarray(Image.open(os.path.join(TEXDIR, m["file"])).convert("RGBA")).astype(np.float32) / 255
    TEX[name] = a


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def hsh(*v):
    x = 0
    for k in v:
        x = (x * 73856093) ^ (int(k) * 19349663 + 83492791)
        x &= 0xFFFFFFFF
    x ^= x >> 13
    x = (x * 1274126177) & 0xFFFFFFFF
    return (x & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- camera
YAW, PITCH = math.radians(45), math.radians(50)
L = np.array([-math.sin(YAW) * math.cos(PITCH), -math.sin(PITCH), -math.cos(YAW) * math.cos(PITCH)])
R = np.cross(L, [0, 1, 0]); R /= np.linalg.norm(R)
U = np.cross(R, L)


class Canvas:
    def __init__(self, w, h, scale, origin):
        self.w, self.h, self.s = w, h, scale
        self.ox, self.oy = origin
        self.col = np.zeros((h, w, 3), np.float32)
        self.dep = np.full((h, w), np.inf, np.float32)

    def proj(self, p):
        p = np.asarray(p, np.float32)
        return np.array([p @ R * self.s + self.ox, -(p @ U) * self.s + self.oy]), float(p @ L)

    def face(self, p0, e1, e2, shader, blend=None):
        """Parallelogram p0 + u*e1 + v*e2, u,v in [0,1). shader(u, v, world) -> rgb."""
        s0, d0 = self.proj(p0)
        s1 = self.proj(np.add(p0, e1))[0] - s0
        s2 = self.proj(np.add(p0, e2))[0] - s0
        dd1 = float(np.asarray(e1) @ L); dd2 = float(np.asarray(e2) @ L)
        pts = np.array([s0, s0 + s1, s0 + s2, s0 + s1 + s2])
        x0, y0 = np.floor(pts.min(0)).astype(int); x1, y1 = np.ceil(pts.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, self.w), min(y1, self.h)
        if x0 >= x1 or y0 >= y1:
            return
        M = np.array([s1, s2]).T
        if abs(np.linalg.det(M)) < 1e-6:
            return
        Mi = np.linalg.inv(M)
        ys, xs = np.mgrid[y0:y1, x0:x1]
        rel = np.stack([xs + 0.5 - s0[0], ys + 0.5 - s0[1]], -1)
        uv = rel @ Mi.T
        u, v = uv[..., 0], uv[..., 1]
        inside = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
        if not inside.any():
            return
        depth = d0 + u * dd1 + v * dd2
        zb = self.dep[y0:y1, x0:x1]
        ok = inside & (depth < zb - 1e-4)
        if not ok.any():
            return
        uu, vv = u[ok], v[ok]
        world = (np.asarray(p0, np.float32)[None] + uu[:, None] * np.asarray(e1, np.float32)[None]
                 + vv[:, None] * np.asarray(e2, np.float32)[None])
        rgb = shader(uu, vv, world)
        cb = self.col[y0:y1, x0:x1]
        if blend is None:
            cb[ok] = rgb
            zb[ok] = depth[ok]
        else:
            cb[ok] = cb[ok] * (1 - blend) + rgb * blend


def sample(name, us, vs):
    t = TEX[name]
    xi = np.floor(us * 16).astype(int) % 16
    yi = np.floor(vs * 16).astype(int) % 16
    return t[yi, xi]


# ---------------------------------------------------------------- scenes
SCENES = {   # base height, amplitude (blocks), seed, rock_at, peak_at, props
    "verdant_meadow":       dict(base=3, amp=5, seed=1, props=[("oak", 4, 9), ("oak", 9, 4), ("boulder", 10, 10)]),
    "whispering_forest":    dict(base=4, amp=6, seed=2, props=[("oak", 3, 4), ("oak", 8, 9), ("pine", 10, 3), ("oak", 4, 11)]),
    "emerald_jungle":       dict(base=3, amp=6, seed=3, props=[("jungle", 4, 4), ("jungle", 9, 9), ("boulder", 11, 4)]),
    "frostpine_taiga":      dict(base=3, amp=6, seed=4, props=[("pine", 3, 5), ("pine", 8, 9), ("pine", 10, 4), ("boulder", 5, 10)]),
    "murk_swamp":           dict(base=1, amp=3, seed=5, props=[("oak", 4, 5), ("boulder", 9, 9)]),
    "sandy_beach":          dict(base=1, amp=4, seed=6, props=[("boulder", 8, 8)]),
    "sunscorch_desert":     dict(base=3, amp=8, seed=7, rock_at=8, props=[]),
    "snowy_tundra":         dict(base=2, amp=6, seed=8, props=[("pine", 4, 8), ("boulder", 9, 5)]),
    "stonecrown_mountains": dict(base=4, amp=14, seed=9, rock_at=9, peak_at=15, props=[("pine", 3, 10), ("ore_iron", 9, 3)]),
    "crystal_glade":        dict(base=3, amp=5, seed=10, props=[("oak", 4, 5), ("boulder", 9, 9)]),
    "deep_ocean":           dict(base=-3, amp=6, seed=11, props=[]),
    "the_deeps":            dict(base=2, amp=7, seed=12, props=[("ore_copper", 4, 4), ("ore_coal", 9, 8), ("ore_silver", 4, 10), ("ore_iron", 10, 3)]),
}


def heightfield(cfg):
    r = np.random.default_rng(cfg["seed"])
    g = r.random((5, 5))
    xs = np.linspace(0, 3.999, SIZE)
    hf = np.zeros((SIZE, SIZE))
    for i, x in enumerate(xs):
        for j, z in enumerate(xs):
            x0, z0 = int(x), int(z); fx, fz = x - x0, z - z0
            fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
            a = g[x0, z0] * (1 - fx) + g[x0 + 1, z0] * fx
            b = g[x0, z0 + 1] * (1 - fx) + g[x0 + 1, z0 + 1] * fx
            hf[i, j] = a * (1 - fz) + b * fz
    hf = (hf - hf.min()) / (hf.max() - hf.min() + 1e-6)
    h = np.round(cfg["base"] - 3 + hf * cfg["amp"]).astype(int)
    return h


def group_of(texkey):
    return texkey if texkey in TEXTURE_GROUPS else None


def side_tex_name(key):
    return TEXTURE_GROUPS[key][1] if key in TEXTURE_GROUPS else key


def surface_kind(bio, cfg, h):
    if bio.get("cave"):
        return "top"
    if h < 0:
        return "underwater"
    if h <= 1:
        return "shore"
    if "peak_at" in cfg and h >= cfg["peak_at"]:
        return "peak"
    if "rock_at" in cfg and h >= cfg["rock_at"]:
        return "rock"
    return "top"


def colours(bio, use_old):
    c = dict(bio)
    if use_old:
        c.update(bio["old"])
    out = {k: hexrgb(v) for k, v in c.items() if isinstance(v, str) and v.startswith("#")}
    out.setdefault("rock", hexrgb("#8C847C"))
    out.setdefault("peak", hexrgb("#F2F5FA"))
    out.setdefault("ice", hexrgb("#A9D6EE"))
    return out


def top_colour(col, kind, wx, wz):
    t = hsh(wx, wz, 3); patch = hsh(wx >> 3, wz >> 3, 911)
    spread = 0.08
    if kind == "underwater":
        c = col["underwater"].copy()
    elif kind == "shore":
        c = col["shore"].copy(); spread = 0.05
    elif kind == "peak":
        c = col["peak"].copy(); spread = 0.04
    elif kind == "rock":
        c = col["rock"] * (0.9 + hsh(wx >> 2, 37) * 0.16); spread = 0.1
    else:
        c = col["top"] + (col["top_alt"] - col["top"]) * min(max(t * t * 0.7 + patch * 0.55, 0), 1)
        hue = hsh(wx, wz, 5) - 0.5
        c = c * np.array([1 + hue * 0.14, 1, 1 - hue * 0.14])
        c = c * (0.94 + patch * 0.1)
    return c * (1 - spread * 0.5 + hsh(wz, wx, 77) * spread)


def side_colour(col, kind, cfg, h):
    if kind == "rock" or kind == "peak":
        return col["rock"] * 0.9
    if kind in ("shore", "underwater"):
        return col["shore"] * 0.85
    return col["side"]


def tex_for(bio, kind):
    key = bio["tex"].get(kind, bio["tex"]["top"])
    return key


SUN = np.array([1.0, 0.98, 0.93], np.float32)      # warm light on tops
SHADE = np.array([0.95, 0.97, 1.04], np.float32)   # cool shade on walls


def render(biome, textured=True, use_old=False, scale=72, ss=2):
    bio = BIOMES[biome]; cfg = SCENES[biome]
    col = colours(bio, use_old)
    H = heightfield(cfg)
    s = scale * ss
    w, h = int(SIZE * 1.45 * s), int(SIZE * 1.25 * s)
    cv = Canvas(w, h, s, (w / 2, h * 0.47))
    off = -SIZE / 2
    frozen = bio.get("frozen_water", False)
    hmin = H.min() - 2

    def hat(x, z):
        if 0 <= x < SIZE and 0 <= z < SIZE:
            return H[x, z]
        return -999

    for x in range(SIZE):
        for z in range(SIZE):
            hh = H[x, z]; wx, wz = x + 7, z + 3
            kind = surface_kind(bio, cfg, hh)
            tkey = tex_for(bio, kind)
            top_c = top_colour(col, kind, wx, wz)
            tops = TEXTURE_GROUPS[tkey][0] if tkey in TEXTURE_GROUPS else [tkey]
            tname = tops[int(hsh(wx, wz, 41) * len(tops)) % len(tops)]
            # corner AO (same rule as the game): corners a(-,-) b(+,-) c(+,+) d(-,+)
            def ao(sa, sb, cn):
                return 0.66 if (sa and sb) else 1 - 0.12 * (sa + sb + cn)
            up = lambda dx, dz: hat(x + dx, z + dz) > hh
            aos = [ao(up(-1, 0), up(0, -1), up(-1, -1)), ao(up(1, 0), up(0, -1), up(1, -1)),
                   ao(up(1, 0), up(0, 1), up(1, 1)), ao(up(-1, 0), up(0, 1), up(-1, 1))]
            ty = hh * BH
            px, pz = x + off, z + off

            def top_shader(u, v, wd, tc=top_c, tn=tname, a=aos):
                aov = (a[0] * (1 - u) * (1 - v) + a[1] * u * (1 - v) + a[2] * u * v + a[3] * (1 - u) * v)
                c = tc[None] * aov[:, None] * SUN
                if textured:
                    c = c * sample(tn, wd[:, 0], wd[:, 2])[:, :3] * GAIN
                return c
            cv.face((px, ty, pz), (1, 0, 0), (0, 0, 1), top_shader)

            # walls facing +X and +Z (the two the camera sees)
            sc = side_colour(col, kind, cfg, hh)
            if kind == "top":
                side_key = bio["tex"]["side"]
            elif kind in ("rock", "peak"):
                side_key = bio["tex"]["rock"]
            else:
                side_key = tex_for(bio, kind)
            sname = side_tex_name(side_key)
            ename = TEXTURE_GROUPS[tkey][2] if tkey in TEXTURE_GROUPS else sname
            if kind in ("rock", "peak"):
                ename = side_tex_name(bio["tex"]["rock"]) if kind == "rock" else "snow_edge"
            for (nx, nz, shade) in ((1, 0, 0.74), (0, 1, 0.62)):
                nh = hat(x + nx, z + nz)
                bottom = nh if nh > -999 else hmin
                if bottom >= hh:
                    continue
                if nx:
                    p0 = (px + 1, ty, pz); e1 = (0, 0, 1)
                    hor = 2
                else:
                    p0 = (px, ty, pz + 1); e1 = (1, 0, 0)
                    hor = 0
                band_bottom = max(bottom, hh - 1)

                def edge_shader(u, v, wd, sh=shade, tc=top_c, sc_=sc, en=ename, sn=sname, hor=hor, tyy=ty):
                    c_top = tc[None] * sh * SHADE
                    if not textured:
                        return np.repeat(c_top, len(u), 0)
                    e = sample(en, wd[:, hor], (tyy - wd[:, 1]))
                    m = e[:, 3:4]
                    sd = sample(sn, wd[:, hor], -wd[:, 1])[:, :3]
                    return (m * c_top * e[:, :3] + (1 - m) * sc_[None] * sh * 0.92 * SHADE * sd) * GAIN
                hb = (hh - band_bottom) * BH
                cv.face(p0, e1, (0, -hb, 0), edge_shader)
                if band_bottom > bottom:
                    def body_shader(u, v, wd, sh=shade, sc_=sc, sn=sname, hor=hor):
                        c = sc_[None] * sh * 0.92 * SHADE
                        if textured:
                            c = c * sample(sn, wd[:, hor], -wd[:, 1])[:, :3] * GAIN
                        return c
                    cv.face((p0[0], band_bottom * BH, p0[2]), e1, (0, -(band_bottom - bottom) * BH, 0), body_shader)

    # props (boxes)
    for (ptype, x, z) in cfg["props"]:
        base = H[x, z] * BH
        cx, cz = x + off + 0.5, z + off + 0.5
        for box in prop_boxes(ptype):
            (bx, by, bz), (sx, sy, sz), colour, tex, tint = box
            draw_box(cv, (cx + bx, base + by, cz + bz), (sx, sy, sz), colour, tex if textured else None, tint)

    # water
    if biome != "the_deeps":
        for x in range(SIZE):
            for z in range(SIZE):
                if H[x, z] < 0:
                    px, pz = x + off, z + off
                    if frozen:
                        ic = col["ice"]
                        def ice_shader(u, v, wd, ic=ic):
                            c = ic[None] * SUN
                            return c * sample("ice_top", wd[:, 0], wd[:, 2])[:, :3] * GAIN if textured else c
                        cv.face((px, WATER_Y, pz), (1, 0, 0), (0, 0, 1), ice_shader)
                    else:
                        wc = np.array([0.22, 0.52, 0.72], np.float32)
                        cv.face((px, WATER_Y, pz), (1, 0, 0), (0, 0, 1), lambda u, v, wd, wc=wc: np.repeat(wc[None], len(u), 0), blend=0.62)

    bg = np.array([0.13, 0.14, 0.17], np.float32)
    img = cv.col.copy()
    img[np.isinf(cv.dep)] = bg
    img = np.clip(img, 0, 1)
    im = Image.fromarray((img * 255).astype(np.uint8)).resize((w // ss, h // ss), Image.BOX)
    return im


def prop_boxes(ptype):
    t = hexrgb(PROPS["trunk"]); lo = hexrgb(PROPS["leaf_oak"]); ll = hexrgb(PROPS["leaf_oak_light"])
    if ptype == "oak":
        return [((0, 1.1, 0), (0.5, 2.2, 0.5), t, "bark", True),
                ((0, 2.6, 0), (2.4, 1.2, 2.4), lo, "leaves_oak", True),
                ((0, 3.5, 0), (1.7, 0.9, 1.7), ll, "leaves_oak", True),
                ((0.9, 2.3, 0.5), (0.9, 0.8, 0.9), ll, "leaves_oak", True),
                ((0, 4.1, 0), (0.8, 0.5, 0.8), lo, "leaves_oak", True)]
    if ptype == "pine":
        n1 = hexrgb(PROPS["needle"]); n2 = hexrgb(PROPS["needle_light"])
        return [((0, 1.0, 0), (0.45, 2.0, 0.45), t * 0.9, "bark", True),
                ((0, 1.8, 0), (2.2, 0.8, 2.2), n1, "leaves_pine", True),
                ((0, 2.6, 0), (1.7, 0.8, 1.7), n2, "leaves_pine", True),
                ((0, 3.4, 0), (1.2, 0.8, 1.2), n1, "leaves_pine", True),
                ((0, 4.1, 0), (0.7, 0.7, 0.7), n2, "leaves_pine", True)]
    if ptype == "jungle":
        j = hexrgb(PROPS["leaf_jungle"])
        return [((0, 2.0, 0), (0.6, 4.0, 0.6), t * 0.9, "bark", True),
                ((0, 0.3, 0), (1.0, 0.6, 1.0), t * 0.8, "bark", True),
                ((0, 4.2, 0), (3.0, 0.8, 3.0), j, "leaves_jungle", True),
                ((0, 4.9, 0), (1.8, 0.6, 1.8), j * 1.2, "leaves_jungle", True)]
    if ptype == "boulder":
        b = hexrgb(PROPS["boulder"])
        return [((0, 0.35, 0), (1.2, 0.7, 1.0), b, "boulder", True),
                ((0.15, 0.8, 0), (0.7, 0.3, 0.6), b * 1.05, "boulder", True)]
    if ptype.startswith("ore_"):
        return [((0, 0.4, 0), (1.2, 0.8, 1.1), np.ones(3, np.float32), ptype, False),
                ((0.2, 0.9, 0), (0.7, 0.3, 0.6), np.ones(3, np.float32) * 0.9, ptype, False)]
    return []


def draw_box(cv, centre, size, colour, tex, tinted):
    cx, cy, cz = centre; sx, sy, sz = size
    x0, x1 = cx - sx / 2, cx + sx / 2; y0, y1 = cy - sy / 2, cy + sy / 2; z0, z1 = cz - sz / 2, cz + sz / 2
    gain = GAIN if tinted else 1.0
    if tex is None and not tinted:      # untextured ore rock: show the old grey stone
        colour = hexrgb(PROPS["ore_stone"])
    def mk(shade, hor, vert, tint_light):
        def sh(u, v, wd):
            c = colour[None] * shade * tint_light
            if tex is not None:
                c = c * sample(tex, wd[:, hor], -wd[:, vert] if vert == 1 else wd[:, vert])[:, :3] * gain
            return c
        return sh
    cv.face((x0, y1, z0), (sx, 0, 0), (0, 0, sz), mk(1.0, 0, 2, SUN))
    cv.face((x1, y1, z0), (0, 0, sz), (0, -sy, 0), mk(0.74, 2, 1, SHADE))
    cv.face((x0, y1, z1), (sx, 0, 0), (0, -sy, 0), mk(0.62, 0, 1, SHADE))


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 18), fill=(0, 0, 0))
    d.text((5, 3), text, fill=(235, 235, 235))
    return im


def main(only=None):
    os.makedirs(OUT, exist_ok=True)
    thumbs = []
    for biome in BIOMES:
        if only and biome not in only:
            continue
        a = label(render(biome, textured=False, use_old=True), f"{biome}: now (flat colour, old palette)")
        b = label(render(biome, textured=False), "new palette, no textures")
        c = label(render(biome, textured=True), "new palette + textures")
        w, h = a.size
        row = Image.new("RGB", (w * 3 + 8, h), (20, 20, 24))
        row.paste(a, (0, 0)); row.paste(b, (w + 4, 0)); row.paste(c, (2 * w + 8, 0))
        row.save(os.path.join(OUT, f"{biome}.png"))
        thumbs.append((biome, c))
        print("rendered", biome)
    if not only:
        tw, th = thumbs[0][1].size
        cols = 4
        sheet = Image.new("RGB", (cols * tw, ((len(thumbs) + cols - 1) // cols) * th), (20, 20, 24))
        for i, (n, im) in enumerate(thumbs):
            sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
        sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
        sheet.save(os.path.join(OUT, "all_biomes.png"))


def far_view():
    """Distance test: the same meadow at ~14 px per metre.
    left  = nearest, no mipmaps (worst case: sparkle/shimmer while moving)
    mid   = nearest + mipmaps (approximated by 4x supersampling)
    right = no texture.  Saved as art/previews/far_view_test.png"""
    a = label(render("verdant_meadow", textured=True, scale=14, ss=1), "far: nearest, NO mipmaps")
    b = label(render("verdant_meadow", textured=True, scale=14, ss=4), "far: with mipmaps")
    c = label(render("verdant_meadow", textured=False, scale=14, ss=4), "far: no texture")
    w, h = a.size
    row = Image.new("RGB", (w * 3 + 8, h), (20, 20, 24))
    row.paste(a, (0, 0)); row.paste(b, (w + 4, 0)); row.paste(c, (2 * w + 8, 0))
    row = row.resize((row.width * 2, row.height * 2), Image.NEAREST)
    row.save(os.path.join(OUT, "far_view_test.png"))


if __name__ == "__main__":
    if sys.argv[1:] == ["far"]:
        far_view()
    else:
        main(sys.argv[1:] or None)
        far_view()
