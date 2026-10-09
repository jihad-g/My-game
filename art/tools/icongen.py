"""Item icons, 32 x 32, for every item in data/items/*.tres.

    python3 art/tools/icongen.py

Output:
  art/icons/items/<item_id>.png      one icon per item (215)
  art/icons/shapes/<shape>.png       each of the 68 drawings in neutral colours (reference)
  art/icons/icon_atlas.png           all item icons, 32 x 32 cells, 16 per row (512 wide)
  art/icons/icon_atlas.json          item id -> cell, shape, colours
  art/previews/item_icons_sheet.png  labelled sheet, 2x size

Same rules as ItemIcons (src/ui/item_icons.gd): which drawing an item uses is
decided by its id / category / slot, metal tools use the material colour. Only
the drawings and the shading are new:

  * every drawing is made of MATERIAL SLOTS (main colour, metal, wood, gold...)
  * shading per slot: 4 tones (shadow, mid-shadow, base, light). A pixel whose
    up/left neighbour is another slot or empty is lit; down/right is shaded;
    the top-left third of the item is one step lighter (one sun, top-left)
  * shadows lean cool, lights lean warm (same rule as the textures)
  * outline: 1 px, coloured (darkest neighbour x 0.35), not black
  * 1-2 px empty margin, held objects point to the top-right
"""
from __future__ import annotations

import colorsys
import json
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ITEMS = os.path.join(ROOT, "data", "items")
OUT = os.path.join(ROOT, "art", "icons")
PREV = os.path.join(ROOT, "art", "previews")
S = 32

CAT = ["MATERIAL", "FOOD", "TOOL", "WEAPON", "ARMOR", "PLACEABLE", "MISC"]
SLOT = ["NONE", "MAIN_HAND", "OFF_HAND", "HEAD", "CHEST", "HANDS", "FEET", "RING", "AMULET"]
RARE = 3


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# Fixed material colours (sRGB)
WOOD = hexc("#8C5A32"); WOOD_D = hexc("#5E3B22"); GOLD = hexc("#F2C24A"); PAPER = hexc("#EEE3C2")
LEATHER = hexc("#7A4E2E"); STRING = hexc("#E8DCC0"); RED = hexc("#C8392E"); WHITE = hexc("#F2EEE6")
DARK = hexc("#2E2A30"); LEAF = hexc("#4F9A3A"); GLASS = hexc("#CFE8F2"); STONE = hexc("#8E8A86")
FLAME = hexc("#FF9A2E"); FLAME_Y = hexc("#FFE066"); BONE = hexc("#EDE4CC"); ORANGE = hexc("#F08A2A")


# ---------------------------------------------------------------- item data
def read_items():
    items = []
    for f in sorted(os.listdir(ITEMS)):
        if not f.endswith(".tres"):
            continue
        txt = open(os.path.join(ITEMS, f)).read()
        def field(name, default=None):
            m = re.search(rf"^{name} = (.+)$", txt, re.M)
            return m.group(1).strip() if m else default
        iid = field("id", f[:-5]).replace('&"', "").replace('"', "")
        col = field("icon_color", "Color(0.7, 0.7, 0.7, 1)")
        rgb = np.array([float(v) for v in re.findall(r"[-\d.]+", col)[:3]])
        items.append({
            "id": iid, "name": (field("display_name", '""') or '""').strip('"'),
            "category": int(field("category", "0")), "slot": int(field("equip_slot", "0")),
            "rarity": int(field("rarity", "0")), "color": np.clip(rgb, 0, 1),
        })
    return items


RULES = [
    ["seeds", "seeds"], ["mushroom", "mushroom"], ["glowcap", "mushroom"], ["dreamcap", "mushroom"],
    ["scroll_", "scroll"], ["tome_", "book"], ["grimoire", "book"], ["codex", "book"], ["manual", "book"],
    ["journal", "book"], ["notes", "book"], ["folio", "book"], ["embers_tome", "book"],
    ["_arrow", "arrow"], ["bow", "bow"], ["spear", "spear"], ["pike", "spear"], ["halberd", "spear"],
    ["maul", "hammer"], ["hammer", "hammer"], ["shardbreaker", "hammer"], ["greatsword", "greatsword"],
    ["_wand", "wand"],
    ["pickaxe", "pickaxe"], ["hatchet", "hatchet"], ["handaxe", "hatchet"], ["waraxe", "axe"], ["greataxe", "axe"],
    ["cleaver", "axe"], ["dagger", "dagger"], ["knife", "dagger"], ["shadowfang", "dagger"], ["staff", "staff"],
    ["sword", "sword"], ["blade", "sword"], ["shield", "shield"], ["buckler", "shield"], ["aegis", "shield"],
    ["crown", "crown"], ["helm", "helmet"], ["greaves", "boots"], ["shoes", "boots"], ["gauntlets", "gloves"],
    ["bracers", "gloves"], ["wraps", "gloves"], ["harness", "armor"], ["garb", "robe"], ["cap", "helmet"], ["hood", "hood"], ["hat", "hat"], ["boots", "boots"], ["gloves", "gloves"],
    ["jerkin", "armor"], ["vest", "armor"], ["chainmail", "armor"], ["plate", "armor"], ["robe", "robe"],
    ["cloak", "robe"], ["ring", "ring"], ["signet", "ring"], ["amulet", "amulet"], ["pendant", "amulet"],
    ["charm", "amulet"], ["insignia", "badge"],
    ["draught", "potion"], ["elixir", "potion"], ["tonic", "potion"], ["antidote", "potion"], ["brew", "potion"],
    ["venom", "vial"],
    ["raw_meat", "meat"], ["cooked_meat", "meat_cooked"], ["frostberries", "berries"], ["berries", "berries"],
    ["bread", "bread"], ["stew", "bowl"], ["salad", "bowl"], ["carrot", "carrot"], ["pumpkin", "pumpkin"],
    ["coconut", "coconut"], ["cactus_fruit", "fruit"], ["wheat", "wheat"],
    ["moonpetal", "flower"], ["sunbloom", "flower"], ["frost_lotus", "flower"], ["orchid", "flower"],
    ["emberroot", "root"], ["thorn_heart", "heart"], ["star_core", "orb"], ["essence", "orb"],
    ["_ore", "ore"], ["_ingot", "ingot"], ["nugget", "nugget"], ["gemstone", "gem"], ["sunstone", "gem"],
    ["crystal_shard", "crystal"], ["void_shard", "crystal"], ["shard", "crystal"], ["dust", "dust"],
    ["plank", "plank"], ["wood", "log"], ["stick", "stick"], ["flint", "flint"], ["stone", "stone"],
    ["clay", "lump"], ["coal", "coal"], ["plant_fiber", "fiber"], ["rope", "rope"], ["leather", "hide"],
    ["hide", "hide"], ["tusk", "tusk"], ["bone", "bone"], ["campfire", "campfire"], ["bandage", "bandage"],
]


def shape_of(it):
    s = it["id"]
    for k, v in RULES:
        if k in s:
            return v
    c = CAT[it["category"]]
    if c == "FOOD":
        return "fruit"
    if c == "WEAPON":
        return "sword"
    if c == "TOOL":
        return "hatchet"
    if c == "ARMOR":
        return {"HEAD": "helmet", "HANDS": "gloves", "FEET": "boots"}.get(SLOT[it["slot"]], "armor")
    if c == "PLACEABLE":
        return "crate"
    return "lump"


METALS = [["copper", "#E0854D"], ["iron", "#C2C7D6"], ["mithril", "#99E0FA"], ["star", "#D1B8FF"], ["sun", "#FFD159"],
          ["rusty", "#9E6B4D"], ["flint", "#6B6B7A"], ["stone", "#9E9EA3"], ["rough", "#99999E"], ["shadow", "#6B4D99"],
          ["titan", "#B3B3CC"], ["warlord", "#8C8080"], ["squire", "#C2C7D6"], ["crystal", "#A6E6FF"]]


def metal_of(it):
    for k, h in METALS:
        if k in it["id"]:
            return hexc(h)
    return it["color"]


# ---------------------------------------------------------------- canvas
class Icon:
    def __init__(self):
        self.slot = np.full((S, S), -1, int)
        self.cols: list[np.ndarray] = []
        self.flat: set[int] = set()       # slots that should not be shaded (glints, eyes)

    def mat(self, c, flat=False):
        for i, e in enumerate(self.cols):
            if np.allclose(e, c) and ((i in self.flat) == flat):
                return i
        self.cols.append(np.asarray(c, float))
        if flat:
            self.flat.add(len(self.cols) - 1)
        return len(self.cols) - 1

    # primitives (coordinates in pixels, centre of pixel = +0.5)
    def poly(self, pts, c, flat=False):
        k = self.mat(c, flat)
        im = Image.new("L", (S * 4, S * 4), 0)
        ImageDraw.Draw(im).polygon([(x * 4, y * 4) for x, y in pts], fill=255)
        m = np.asarray(im.resize((S, S), Image.BOX)) > 110
        self.slot[m] = k

    def line(self, p0, p1, w, c, flat=False):
        k = self.mat(c, flat)
        im = Image.new("L", (S * 4, S * 4), 0)
        ImageDraw.Draw(im).line([(p0[0] * 4, p0[1] * 4), (p1[0] * 4, p1[1] * 4)], fill=255, width=max(1, int(w * 4)))
        for p in (p0, p1):
            r = w * 2
            ImageDraw.Draw(im).ellipse([p[0] * 4 - r, p[1] * 4 - r, p[0] * 4 + r, p[1] * 4 + r], fill=255)
        m = np.asarray(im.resize((S, S), Image.BOX)) > 100
        self.slot[m] = k

    def polyline(self, pts, w, c):
        for a, b in zip(pts, pts[1:]):
            self.line(a, b, w, c)

    def disc(self, cx, cy, r, c, flat=False):
        k = self.mat(c, flat)
        ys, xs = np.mgrid[0:S, 0:S]
        m = (xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2 <= r * r
        self.slot[m] = k

    def ellipse(self, cx, cy, rx, ry, c, flat=False):
        k = self.mat(c, flat)
        ys, xs = np.mgrid[0:S, 0:S]
        m = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2 <= 1
        self.slot[m] = k

    def rect(self, x0, y0, x1, y1, c, flat=False):
        self.slot[y0:y1, x0:x1] = self.mat(c, flat)

    def px(self, x, y, c, flat=True):
        self.slot[y, x] = self.mat(c, flat)

    def erase_disc(self, cx, cy, r):
        ys, xs = np.mgrid[0:S, 0:S]
        self.slot[(xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2 <= r * r] = -1

    # ------------------------------------------------------------ render
    def render(self):
        sl = self.slot
        op = sl >= 0
        if not op.any():
            return np.zeros((S, S, 4), np.uint8)
        ys, xs = np.nonzero(op)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        def nb(dx, dy):
            return np.roll(np.roll(sl, dy, axis=0), dx, axis=1)
        lit = (nb(1, 0) != sl) | (nb(0, 1) != sl)          # neighbour up or left differs
        dim = (nb(-1, 0) != sl) | (nb(0, -1) != sl)        # neighbour down or right differs
        Y, X = np.mgrid[0:S, 0:S]
        t = ((X - x0) / max(1, x1 - x0) + (Y - y0) / max(1, y1 - y0)) / 2   # 0 top-left .. 1 bottom-right
        tone = 2 + lit.astype(int) - dim.astype(int) + (t < 0.28) - (t > 0.78)
        tone = np.clip(tone, 0, 3)
        rgb = np.zeros((S, S, 3))
        for k, c in enumerate(self.cols):
            m = sl == k
            if not m.any():
                continue
            if k in self.flat:
                rgb[m] = c
                continue
            ramp = ramp_of(c)
            rgb[m] = ramp[tone[m]]
        # outline
        out = np.zeros((S, S, 4), np.uint8)
        out[op, :3] = np.clip(rgb[op] * 255, 0, 255)
        out[op, 3] = 255
        edge = ~op & (np.roll(op, 1, 0) | np.roll(op, -1, 0) | np.roll(op, 1, 1) | np.roll(op, -1, 1))
        for y, x in zip(*np.nonzero(edge)):
            cs = [rgb[yy % S, xx % S] for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)) if op[yy % S, xx % S]]
            d = min(cs, key=lambda c: c.sum())
            oc = darken_cool(d, 0.32)
            out[y, x, :3] = np.clip(oc * 255, 0, 255); out[y, x, 3] = 255
        return out


def ramp_of(c):
    """4 tones: shadow (cool, darker), mid shadow, base, light (warm)."""
    h, l, s = colorsys.rgb_to_hls(*np.clip(c, 0, 1))
    def hls(dl, dh, ds, mul=1.0):
        hh = (h + dh) % 1.0
        return np.array(colorsys.hls_to_rgb(hh, np.clip(l * mul + dl, 0, 1), np.clip(s + ds, 0, 1)))
    # hue shift towards blue in shadows, towards yellow in lights
    toward_blue = 0.03 if (0.15 < h < 0.62) else -0.03
    toward_yel = -0.02 if (0.17 < h < 0.65) else 0.02
    return np.array([
        hls(-0.02, toward_blue, 0.05, 0.62),
        hls(0.0, toward_blue * 0.5, 0.02, 0.8),
        np.clip(c, 0, 1),
        hls(0.06, toward_yel, -0.04, 1.12),
    ])


def darken_cool(c, f):
    return np.clip(c * f * np.array([0.95, 0.97, 1.12]), 0, 1)


# ---------------------------------------------------------------- drawings
def handle(ic, a, b, w=2, c=WOOD):
    ic.line(a, b, w, c)


def glint(ic, x, y):
    ic.px(x, y, np.array([1.0, 1.0, 0.96]))


def draw(shape, it):
    ic = Icon()
    c = it["color"]; m = metal_of(it); rare = it["rarity"] >= RARE
    trim = GOLD if rare else hexc("#7A6A55")
    light = np.minimum(c * 1.25 + 0.1, 1)
    if shape == "sword":
        ic.poly([(9, 21), (24, 6), (27, 4), (26, 8), (11, 23)], m)
        ic.line((10, 19), (14, 23), 1.6, m * 0.75)          # fuller near the guard
        ic.line((6, 19), (13, 26), 1.8, trim)
        handle(ic, (4.5, 27.5), (9, 23), 2, LEATHER)
        ic.disc(4, 28, 1.7, trim)
        glint(ic, 24, 6)
    elif shape == "greatsword":
        ic.poly([(9, 19), (25, 3), (29, 2), (28, 6), (12, 22)], m)
        ic.line((12, 18), (24, 6), 1, np.minimum(m * 1.2, 1))
        ic.line((5, 16), (15, 26), 2.2, trim)
        handle(ic, (3.5, 28.5), (9, 23), 2.2, LEATHER)
        ic.disc(3, 29, 2, trim)
        glint(ic, 26, 3)
    elif shape == "dagger":
        ic.poly([(12, 19), (22, 9), (25, 7), (23, 11), (13, 21)], m)
        ic.line((9, 17), (15, 23), 1.6, trim)
        handle(ic, (6.5, 25.5), (10.5, 21.5), 2, LEATHER)
        ic.disc(6, 26, 1.5, trim)
        glint(ic, 22, 9)
    elif shape in ("axe", "hatchet"):
        big = shape == "axe"
        handle(ic, (6, 28), (21, 7), 2.2)
        if big:
            ic.poly([(14, 5), (19, 7), (27, 2), (30, 10), (27, 18), (20, 12), (16, 13)], m)
            ic.poly([(11, 12), (15, 9), (16, 14)], m * 0.85)
            glint(ic, 28, 6)
        else:
            ic.poly([(16, 6), (20, 8), (25, 4), (27, 11), (24, 15), (19, 12)], m)
            glint(ic, 25, 6)
    elif shape == "pickaxe":
        handle(ic, (7, 28), (20, 8), 2.2)
        ic.polyline([(6, 12), (11, 7), (17, 5), (22, 5), (28, 9), (30, 13)], 2.2, m)
        ic.rect(17, 4, 22, 9, m * 0.85)
        glint(ic, 12, 6)
    elif shape == "hammer":
        handle(ic, (7, 28), (19, 11), 2.2)
        ic.poly([(12, 8), (19, 1), (29, 11), (22, 18)], m)
        ic.poly([(14, 8), (19, 3), (21, 5), (16, 10)], np.minimum(m * 1.15, 1))
        glint(ic, 19, 3)
    elif shape == "spear":
        handle(ic, (3, 29), (22, 10), 1.8)
        ic.poly([(19, 10), (23, 6), (30, 2), (26, 9), (22, 13)], m)
        ic.line((18, 12), (21, 15), 1.4, trim)
        ic.line((20, 9), (17, 6), 1.4, trim)
        glint(ic, 27, 4)
    elif shape == "staff":
        handle(ic, (6, 29), (20, 10), 2)
        ic.polyline([(17, 10), (19, 6), (23, 3), (27, 5), (28, 10), (25, 13), (21, 12)], 1.4, WOOD_D)
        ic.disc(23, 8, 3.6, c)
        ic.px(22, 7, np.array([1, 1, 1.0]))
        ic.px(23, 7, light)
    elif shape == "wand":
        handle(ic, (7, 26), (20, 13), 1.6, WOOD_D)
        ic.line((8, 25), (11, 22), 2, trim)
        ic.disc(22, 10, 3, c)
        ic.px(21, 9, np.array([1, 1, 1.0]))
        for (x, y) in [(27, 6), (26, 14), (18, 5)]:
            ic.px(x, y, light)
    elif shape == "bow":
        b = lambda t: 6.5 * math.sin(math.pi * t)                 # bulge away from the string (to the top-left)
        pts = [(5 + 22 * t - b(t), 27 - 22 * t - b(t)) for t in np.linspace(0, 1, 11)]
        ic.polyline(pts, 2.2, WOOD if "mithril" not in it["id"] and "star" not in it["id"] else m)
        ic.line(pts[0], pts[-1], 0.9, STRING)
        ic.line((9.5, 12.5), (12.5, 15.5), 2.6, LEATHER)
    elif shape == "arrow":
        ic.line((6, 26), (24, 8), 1.2, WOOD)
        ic.poly([(22, 7), (28, 3), (26, 10)], m)
        ic.poly([(4, 24), (8, 25), (7, 29), (4, 28)], c)
        ic.poly([(6, 22), (8, 26), (11, 25), (8, 21)], np.minimum(c * 1.2, 1))
    elif shape == "shield":
        rim = m if it["id"] != "wooden_buckler" else WOOD_D
        face = c
        ic.poly([(16, 2), (28, 6), (27, 18), (16, 30), (5, 18), (4, 6)], rim)
        ic.poly([(16, 4.5), (25.5, 7.5), (24.8, 17.5), (16, 27.5), (7.2, 17.5), (6.5, 7.5)], face)
        ic.line((16, 6), (16, 26), 1.4, rim)
        ic.line((8, 13), (24, 13), 1.4, rim)
        ic.disc(16, 13, 2.6, trim)
    elif shape == "crown":
        ic.poly([(4, 24), (4, 11), (9, 17), (16, 6), (23, 17), (28, 11), (28, 24)], GOLD)
        ic.rect(4, 22, 28, 26, GOLD * 0.85)
        for (x, col) in [(10, RED), (16, c), (22, RED)]:
            ic.disc(x, 21, 1.8, col)
        ic.disc(16, 6, 1.6, c)
        ic.disc(4, 11, 1.3, c); ic.disc(28, 11, 1.3, c)
    elif shape == "helmet":
        metal = c if "fur" in it["id"] or "cap" in it["id"] else m
        ic.ellipse(16, 16, 11, 11, metal)
        ic.rect(5, 16, 27, 25, metal)
        ic.rect(5, 23, 27, 26, metal * 0.85)
        if "fur" in it["id"] or "cap" in it["id"]:
            ic.rect(4, 21, 28, 27, hexc("#E8DCC6"))
        else:
            ic.rect(9, 17, 23, 19, DARK)
            ic.rect(15, 17, 17, 23, DARK)
            ic.line((16, 5), (16, 15), 1.2, np.minimum(metal * 1.2, 1))
        if "horned" in it["id"]:
            ic.polyline([(6, 14), (3, 9), (4, 4)], 2.2, BONE)
            ic.polyline([(26, 14), (29, 9), (28, 4)], 2.2, BONE)
        if "squire" in it["id"]:
            ic.polyline([(16, 5), (20, 2), (25, 3)], 2.2, RED)
    elif shape == "hood":
        ic.poly([(16, 3), (25, 8), (28, 20), (26, 28), (6, 28), (4, 20), (7, 8)], c)
        ic.ellipse(16, 18, 6.5, 7.5, DARK)
        ic.ellipse(16, 20, 4, 4, hexc("#1E1A22"))
        ic.px(14, 19, np.array([1.0, 0.9, 0.5])); ic.px(18, 19, np.array([1.0, 0.9, 0.5]))
    elif shape == "hat":
        if "sun" in it["id"]:
            ic.ellipse(16, 21, 14, 5, c)
            ic.ellipse(16, 15, 7, 7, c)
            ic.rect(9, 17, 23, 20, RED)
        else:
            ic.ellipse(16, 25, 14, 4, c)
            ic.poly([(9, 25), (14, 10), (20, 2), (24, 4), (21, 9), (23, 25)], c)
            ic.rect(9, 21, 24, 24, trim)
            ic.disc(13, 16, 1.2, GOLD, flat=True); ic.px(18, 12, np.array([1, 0.95, 0.6]))
    elif shape == "boots":
        mat = m if any(k in it["id"] for k in ("iron", "mithril", "squire")) else c
        ic.poly([(9, 4), (19, 4), (19, 19), (27, 21), (28, 27), (6, 27), (7, 18)], mat)
        ic.rect(8, 4, 20, 7, mat * 0.8)
        ic.rect(6, 25, 28, 28, DARK if mat is c else mat * 0.6)
        ic.line((9, 13), (18, 13), 1, mat * 0.75)
    elif shape == "gloves":
        mat = m if any(k in it["id"] for k in ("iron", "mithril", "squire")) else c
        ic.poly([(8, 28), (8, 14), (10, 6), (13, 6), (13, 12), (14, 4), (17, 4), (17, 12), (18, 5), (21, 5),
                 (21, 13), (22, 8), (25, 9), (24, 18), (27, 15), (29, 17), (23, 26), (22, 28)], mat)
        ic.rect(8, 24, 23, 29, mat * 0.8)
    elif shape == "armor":
        mat = m if any(k in it["id"] for k in ("iron", "mithril", "squire", "chain", "plate")) else c
        ic.poly([(9, 3), (13, 6), (19, 6), (23, 3), (29, 7), (27, 14), (24, 13), (24, 28), (8, 28), (8, 13), (5, 14), (3, 7)], mat)
        ic.poly([(13, 6), (16, 10), (19, 6)], DARK)
        ic.rect(8, 20, 24, 23, LEATHER if mat is c else mat * 0.7)
        ic.rect(15, 20, 18, 23, trim)
        if "chain" in it["id"]:
            for y in range(9, 28, 3):
                for x in range(10 + (y % 2), 23, 3):
                    if ic.slot[y, x] >= 0:
                        ic.px(x, y, mat * 0.7)
    elif shape == "robe":
        ic.poly([(11, 3), (21, 3), (24, 8), (29, 16), (25, 18), (24, 14), (27, 29), (5, 29), (8, 14), (7, 18), (3, 16), (8, 8)], c)
        ic.poly([(13, 3), (16, 9), (19, 3)], DARK)
        ic.rect(9, 15, 23, 17, trim)
        ic.line((16, 17), (16, 28), 1, c * 0.75)
    elif shape == "ring":
        band = GOLD if any(k in it["id"] for k in ("royal", "signet", "ember", "swift")) else m
        ic.ellipse(16, 19, 10, 9, band)
        ic.ellipse(16, 20, 6, 5.5, np.zeros(3))
        ic.slot[ic.slot == ic.mat(np.zeros(3))] = -1
        ic.poly([(12, 11), (16, 6), (20, 11), (16, 14)], c)
        ic.px(15, 8, np.array([1, 1, 1.0]))
    elif shape == "amulet":
        chain = GOLD
        ic.polyline([(6, 4), (8, 12), (12, 17), (16, 19), (20, 17), (24, 12), (26, 4)], 1.2, chain)
        ic.disc(16, 22, 6, GOLD * 0.9)
        ic.disc(16, 22, 4.2, c)
        ic.px(15, 20, np.array([1, 1, 1.0]))
    elif shape == "badge":
        ic.poly([(16, 4), (26, 8), (24, 20), (16, 28), (8, 20), (6, 8)], c)
        ic.poly([(16, 9), (19, 15), (16, 21), (13, 15)], GOLD)
    elif shape in ("potion", "vial"):
        if shape == "potion":
            ic.disc(16, 20, 9, GLASS)
            ic.rect(13, 6, 19, 13, GLASS)
            ys, xs = np.mgrid[0:S, 0:S]
            liquid = ((xs + 0.5 - 16) ** 2 + (ys + 0.5 - 20) ** 2 <= 7.6 ** 2) & (ys >= 16)
            ic.slot[liquid] = ic.mat(c)
            ic.rect(12, 3, 20, 7, WOOD)
            ic.px(11, 18, np.array([1, 1, 1.0])); ic.px(11, 17, np.array([1, 1, 1.0]))
        else:
            ic.poly([(13, 8), (19, 8), (19, 26), (16, 29), (13, 26)], GLASS)
            ic.poly([(14, 15), (18, 15), (18, 26), (16, 28), (14, 26)], c)
            ic.rect(12, 4, 20, 8, DARK)
            ic.px(14, 10, np.array([1, 1, 1.0]))
    elif shape in ("meat", "meat_cooked"):
        meatc = hexc("#E2737A") if shape == "meat" else hexc("#9A5530")
        ic.line((7, 26), (13, 20), 2.4, BONE)
        ic.disc(5.5, 27.5, 2, BONE); ic.disc(8, 29, 1.6, BONE)
        ic.ellipse(19, 13, 10, 8.5, meatc)
        if shape == "meat":
            ic.ellipse(21, 12, 4, 3, hexc("#F6C7C0"))
        else:
            ic.line((14, 9), (19, 14), 1, meatc * 0.7); ic.line((19, 7), (25, 13), 1, meatc * 0.7)
    elif shape == "berries":
        for (x, y) in [(12, 18), (19, 17), (15, 23), (22, 23), (9, 24), (17, 12)]:
            ic.disc(x, y, 4, c)
            ic.px(int(x) - 1, int(y) - 2, np.minimum(c * 1.6 + 0.2, 1))
        ic.poly([(16, 9), (22, 3), (26, 7), (19, 10)], LEAF)
        ic.line((16, 9), (17, 13), 1, WOOD_D)
    elif shape == "bread":
        ic.ellipse(16, 19, 13, 8, hexc("#D99A4E"))
        ic.ellipse(16, 16, 11, 5, hexc("#E8B468"))
        for x in (10, 16, 22):
            ic.line((x - 2, 18), (x + 2, 14), 1.2, hexc("#F6DCA0"))
    elif shape == "bowl":
        ic.poly([(3, 15), (29, 15), (26, 24), (20, 28), (12, 28), (6, 24)], WOOD)
        ic.ellipse(16, 15, 13, 4, c)
        ic.disc(11, 14, 1.6, ORANGE if "stew" in it["id"] else LEAF)
        ic.disc(19, 15, 1.6, hexc("#9A5530") if "stew" in it["id"] else hexc("#E25A43"))
        ic.disc(22, 13, 1.3, LEAF)
    elif shape == "carrot":
        ic.poly([(8, 25), (10, 27), (25, 11), (20, 8)], ORANGE)
        for (a, b) in [((22, 9), (24, 2)), ((23, 10), (29, 5)), ((22, 9), (28, 9))]:
            ic.line(a, b, 1.6, LEAF)
        ic.line((14, 18), (16, 20), 1, ORANGE * 0.7); ic.line((18, 13), (20, 15), 1, ORANGE * 0.7)
    elif shape == "pumpkin":
        ic.ellipse(16, 19, 13, 10, ORANGE)
        for x in (10, 16, 22):
            ic.line((x, 11), (x, 27), 1, ORANGE * 0.72)
        ic.line((16, 10), (18, 5), 2.2, hexc("#4F6E2E"))
        ic.poly([(18, 7), (25, 4), (23, 9)], LEAF)
    elif shape == "coconut":
        ic.disc(16, 17, 11, hexc("#6B4428"))
        ic.disc(13, 13, 1.3, DARK, flat=True); ic.disc(18, 12, 1.3, DARK, flat=True); ic.disc(15.5, 17, 1.3, DARK, flat=True)
    elif shape == "fruit":
        ic.disc(16, 18, 10, c)
        ic.line((16, 8), (17, 4), 1.4, WOOD_D)
        ic.poly([(17, 6), (24, 3), (22, 8)], LEAF)
    elif shape == "wheat":
        gold = hexc("#E6C25A")
        for (bx, tx, ty) in [(13, 9, 4), (16, 17, 3), (19, 25, 5)]:
            ic.line((16, 29), (tx, ty + 6), 1, hexc("#C9A646"))
            for k in range(3):
                ic.ellipse(tx + (16 - tx) * 0.1 * k, ty + 2 + k * 3, 2, 2, gold)
        ic.rect(13, 21, 20, 23, RED)
    elif shape == "flower":
        ic.line((16, 30), (16, 16), 1.4, LEAF)
        ic.poly([(16, 23), (9, 19), (12, 25)], LEAF)
        for a in range(5):
            ang = a / 5 * math.tau - math.pi / 2
            ic.disc(16 + math.cos(ang) * 5.5, 11 + math.sin(ang) * 5.5, 3.8, c)
        ic.disc(16, 11, 2.6, GOLD)
    elif shape == "root":
        ic.polyline([(16, 4), (15, 12), (17, 18), (13, 24), (10, 29)], 2.6, c)
        ic.polyline([(16, 15), (22, 21), (25, 28)], 2, c)
        ic.polyline([(15, 11), (9, 14), (6, 20)], 1.6, c)
        ic.poly([(14, 4), (11, 0.5), (16, 2), (21, 0.5), (18, 4)], LEAF)
    elif shape == "heart":
        ic.disc(11, 12, 6.5, c); ic.disc(21, 12, 6.5, c)
        ic.poly([(4.8, 14), (27.2, 14), (16, 28)], c)
        for (a, b) in [((4, 6), (8, 9)), ((27, 23), (23, 20)), ((26, 4), (23, 8))]:
            ic.line(a, b, 1.4, hexc("#3E6B2A"))
    elif shape == "orb":
        ic.disc(16, 16, 11, np.minimum(c * 0.6, 1))
        ic.disc(16, 16, 8.5, c)
        ic.disc(13, 13, 2.6, np.minimum(c * 1.4 + 0.3, 1), flat=True)
        for (x, y) in [(28, 5), (4, 27), (27, 26)]:
            ic.px(x, y, np.minimum(c * 1.3 + 0.2, 1))
    elif shape == "ore":
        ic.poly([(4, 22), (7, 11), (14, 6), (23, 7), (29, 15), (27, 26), (15, 29), (7, 27)], STONE)
        for (x, y, r) in [(12, 13, 3), (21, 18, 3.5), (13, 23, 2.4), (22, 10, 2)]:
            ic.disc(x, y, r, c)
    elif shape == "ingot":
        ic.poly([(3, 20), (10, 13), (29, 13), (29, 19), (22, 26), (3, 26)], c * 0.78)
        ic.poly([(3, 20), (10, 13), (29, 13), (22, 20)], c)
        ic.line((9, 16), (22, 16), 1, np.minimum(c * 1.25, 1))
        glint(ic, 12, 15)
    elif shape == "nugget":
        for (x, y, r) in [(13, 18, 6), (21, 15, 4.5), (19, 23, 3.5)]:
            ic.disc(x, y, r, c)
        glint(ic, 11, 15); glint(ic, 20, 13)
    elif shape == "gem":
        ic.poly([(8, 11), (12, 6), (20, 6), (24, 11), (16, 27)], c)
        ic.poly([(8, 11), (24, 11), (16, 27)], c * 0.8)
        ic.poly([(12, 6), (16, 11), (20, 6)], np.minimum(c * 1.3, 1))
        glint(ic, 13, 8)
    elif shape == "crystal":
        ic.poly([(13, 28), (10, 12), (16, 3), (22, 11), (20, 28)], c)
        ic.poly([(16, 3), (16, 28), (20, 28), (22, 11)], c * 0.8)
        ic.poly([(21, 28), (24, 17), (28, 20), (26, 28)], c * 0.9)
        glint(ic, 13, 10)
    elif shape == "dust":
        ic.ellipse(16, 25, 11, 4.5, c)
        ic.ellipse(16, 22, 7, 4, np.minimum(c * 1.15, 1))
        for (x, y) in [(9, 12), (21, 9), (15, 6), (25, 15), (7, 18)]:
            ic.px(x, y, np.minimum(c * 1.4 + 0.2, 1))
    elif shape == "plank":
        ic.poly([(3, 20), (20, 3), (25, 8), (8, 25)], WOOD)
        ic.poly([(8, 27), (25, 10), (29, 14), (12, 31)], WOOD * 0.9)
        ic.line((7, 19), (19, 7), 1, WOOD * 0.7)
    elif shape == "log":
        ic.poly([(4, 18), (17, 5), (27, 15), (14, 28)], WOOD_D)
        ic.ellipse(21.5, 21.5, 5.5, 5.5, hexc("#D8A86A"))
        ic.disc(21.5, 21.5, 2.6, hexc("#B07A44"))
        ic.line((9, 15), (18, 7), 1, WOOD_D * 0.7)
    elif shape == "stick":
        ic.line((6, 27), (26, 5), 2, WOOD)
        ic.line((16, 16), (22, 18), 1.4, WOOD)
        ic.poly([(22, 17), (26, 15), (25, 19)], LEAF)
    elif shape == "flint":
        ic.poly([(6, 24), (10, 9), (20, 4), (27, 12), (22, 27)], hexc("#4E4E5C"))
        ic.poly([(10, 9), (20, 4), (18, 14)], hexc("#7A7A8E"))
        glint(ic, 15, 7)
    elif shape == "stone":
        ic.poly([(4, 22), (8, 11), (17, 7), (26, 11), (29, 21), (24, 27), (9, 28)], STONE)
        ic.line((11, 18), (17, 15), 1, STONE * 0.75)
    elif shape == "lump":
        ic.ellipse(16, 19, 12, 9, c)
        ic.ellipse(13, 15, 6, 4, np.minimum(c * 1.12, 1))
    elif shape == "coal":
        for (x, y, r) in [(12, 19, 7), (21, 16, 6), (18, 25, 5)]:
            ic.disc(x, y, r, hexc("#2E2C33"))
        glint(ic, 10, 15); glint(ic, 20, 13)
    elif shape == "fiber":
        for k in range(5):
            ic.polyline([(8 + k * 4, 29), (10 + k * 3, 16), (7 + k * 4.5, 3)], 1.2, c if k % 2 else np.minimum(c * 1.2, 1))
        ic.rect(9, 15, 25, 18, hexc("#C9A646"))
    elif shape == "rope":
        for r in (11, 7.5):
            ic.disc(16, 17, r, STRING)
            ic.disc(16, 17, r - 2.2, np.zeros(3))
        ic.slot[ic.slot == ic.mat(np.zeros(3))] = -1
        ic.line((24, 22), (29, 28), 2, STRING)
    elif shape == "hide":
        ic.poly([(6, 4), (11, 7), (21, 7), (26, 4), (28, 12), (25, 17), (28, 27), (22, 25), (16, 29), (10, 25), (4, 27), (7, 17), (4, 12)], c)
        ic.ellipse(16, 16, 6, 8, np.minimum(c * 1.15, 1))
    elif shape == "tusk":
        ic.polyline([(6, 27), (10, 20), (16, 13), (22, 9), (28, 8)], 3.2, BONE)
        ic.line((5, 28), (9, 24), 3.4, hexc("#B89A70"))
    elif shape == "bone":
        ic.line((8, 24), (24, 8), 3, BONE)
        for (x, y) in [(5.5, 23.5), (8.5, 26.5), (23.5, 5.5), (26.5, 8.5)]:
            ic.disc(x, y, 2.8, BONE)
    elif shape == "campfire":
        ic.line((5, 26), (27, 20), 2.6, WOOD)
        ic.line((5, 20), (27, 26), 2.6, WOOD_D)
        ic.poly([(10, 21), (12, 12), (16, 4), (19, 11), (22, 9), (22, 21)], FLAME)
        ic.poly([(13, 21), (15, 14), (17, 10), (19, 16), (19, 21)], FLAME_Y)
    elif shape == "bandage":
        ic.ellipse(13, 18, 9, 9, WHITE)
        ic.disc(13, 18, 3, hexc("#BFB7A8"))
        ic.poly([(18, 25), (29, 21), (30, 26), (20, 29)], WHITE)
        ic.line((10, 10), (16, 10), 1.6, RED)
    elif shape == "seeds":
        ic.poly([(8, 12), (24, 12), (27, 28), (5, 28)], hexc("#C9A876"))
        ic.rect(9, 9, 23, 13, hexc("#A88A5E"))
        ic.disc(16, 20, 4, c)
        for (x, y) in [(4, 6), (8, 4), (26, 6)]:
            ic.ellipse(x, y, 1.6, 1.2, hexc("#B07A44"))
    elif shape == "mushroom":
        ic.rect(13, 15, 19, 28, hexc("#EDE3CF"))
        ic.ellipse(16, 13, 12, 8, c)
        ic.rect(4, 13, 28, 18, np.zeros(3))
        ic.slot[ic.slot == ic.mat(np.zeros(3))] = -1
        ic.rect(13, 13, 19, 28, hexc("#EDE3CF"))
        ic.disc(11, 9, 1.6, WHITE, flat=True); ic.disc(20, 8, 1.3, WHITE, flat=True)
    elif shape == "scroll":
        ic.rect(6, 7, 26, 25, PAPER)
        ic.ellipse(16, 7, 11, 3, PAPER * 0.85)
        ic.ellipse(16, 25, 11, 3, PAPER * 0.85)
        for y in (12, 15, 18):
            ic.line((10, y), (22, y), 0.8, hexc("#8A7A60"))
        ic.rect(14, 20, 18, 30, c)
    elif shape == "book":
        ic.poly([(6, 5), (24, 3), (27, 25), (9, 28)], c)
        ic.poly([(9, 28), (27, 25), (27, 27.5), (10, 30)], PAPER)
        ic.line((8.5, 6), (10.5, 27.5), 1.6, c * 0.65)
        ic.disc(17.5, 15, 3.4, GOLD)
        ic.disc(17.5, 15, 1.8, np.minimum(c * 1.5 + 0.2, 1))
    elif shape == "crate":
        ic.rect(5, 7, 27, 28, WOOD)
        ic.rect(5, 7, 27, 9, WOOD_D); ic.rect(5, 26, 27, 28, WOOD_D)
        ic.rect(5, 7, 7, 28, WOOD_D); ic.rect(25, 7, 27, 28, WOOD_D)
        ic.line((7, 26), (25, 9), 1.6, WOOD_D)
    else:
        ic.disc(16, 16, 9, c)
    return ic


ALL_SHAPES = ["sword", "greatsword", "dagger", "axe", "hatchet", "pickaxe", "hammer", "spear", "staff", "wand", "bow",
              "arrow", "shield", "crown", "helmet", "hood", "hat", "boots", "gloves", "armor", "robe", "ring", "amulet",
              "badge", "potion", "vial", "meat", "meat_cooked", "berries", "bread", "bowl", "carrot", "pumpkin",
              "coconut", "fruit", "wheat", "flower", "root", "heart", "orb", "ore", "ingot", "nugget", "gem", "crystal",
              "dust", "plank", "log", "stick", "flint", "stone", "lump", "coal", "fiber", "rope", "hide", "tusk", "bone",
              "campfire", "bandage", "seeds", "mushroom", "scroll", "book", "crate"]


def main():
    items = read_items()
    os.makedirs(os.path.join(OUT, "items"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "shapes"), exist_ok=True)
    for d in ("items", "shapes"):
        for f in os.listdir(os.path.join(OUT, d)):
            os.remove(os.path.join(OUT, d, f))

    neutral = {"id": "neutral", "color": hexc("#7FA6D9"), "rarity": 1, "category": 0, "slot": 0}
    for sh in ALL_SHAPES:
        Image.fromarray(draw(sh, neutral).render(), "RGBA").save(os.path.join(OUT, "shapes", f"{sh}.png"))

    cols = 16
    rows = (len(items) + cols - 1) // cols
    atlas = np.zeros((rows * S, cols * S, 4), np.uint8)
    meta = {}
    for k, it in enumerate(items):
        sh = shape_of(it)
        img = draw(sh, it).render()
        Image.fromarray(img, "RGBA").save(os.path.join(OUT, "items", f"{it['id']}.png"))
        cx, cy = k % cols, k // cols
        atlas[cy * S:(cy + 1) * S, cx * S:(cx + 1) * S] = img
        meta[it["id"]] = {"cell": [cx, cy], "px": [cx * S, cy * S, S, S], "shape": sh,
                          "file": f"items/{it['id']}.png", "category": CAT[it["category"]],
                          "rarity": it["rarity"],
                          "color": "#%02X%02X%02X" % tuple(int(v * 255) for v in it["color"])}
    Image.fromarray(atlas, "RGBA").save(os.path.join(OUT, "icon_atlas.png"))
    json.dump({"icon_size": S, "columns": cols, "count": len(items), "shapes": ALL_SHAPES, "items": meta},
              open(os.path.join(OUT, "icon_atlas.json"), "w"), indent=1)

    # labelled sheet
    sc, cw, lab = 2, 2 * S + 52, 12
    per = 12
    rr = (len(items) + per - 1) // per
    sheet = Image.new("RGB", (per * cw + 8, rr * (S * sc + lab + 10) + 8), (34, 32, 40))
    dr = ImageDraw.Draw(sheet)
    for k, it in enumerate(items):
        im = Image.open(os.path.join(OUT, "items", f"{it['id']}.png")).resize((S * sc, S * sc), Image.NEAREST)
        x = 8 + (k % per) * cw; y = 8 + (k // per) * (S * sc + lab + 10)
        slotbg = Image.new("RGB", (S * sc + 8, S * sc + 8), (58, 54, 66))
        sheet.paste(slotbg, (x - 4 + 22, y - 4))
        sheet.paste(im, (x + 22, y), im)
        dr.text((x, y + S * sc + 2), it["id"][:19], fill=(210, 210, 215))
    os.makedirs(PREV, exist_ok=True)
    sheet.save(os.path.join(PREV, "item_icons_sheet.png"))
    print(f"{len(items)} item icons, {len(ALL_SHAPES)} shapes")


if __name__ == "__main__":
    main()
