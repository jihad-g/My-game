#!/usr/bin/env python3
"""Generates the built-in blueprints in data/blueprints/ (Milestone 8).
Same JSON format as the game and the web designer (see src/blueprints/blueprint.gd)."""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..")


class Design:
    def __init__(self, name, desc):
        self.name, self.desc, self.pieces, self.used = name, desc, [], set()

    def add(self, pid, x, z, slot, rot=0):
        key = (x, z, slot)
        if key in self.used:
            # Later pieces (doors, windows) replace walls in the same spot.
            self.pieces = [p for p in self.pieces if (p["x"], p["z"], p["slot"]) != key]
        self.used.add(key)
        self.pieces.append({"id": pid, "x": x, "z": z, "slot": slot, "rot": rot})

    def rect_cells(self, pid, x0, z0, w, d, slot):
        for x in range(x0, x0 + w):
            for z in range(z0, z0 + d):
                self.add(pid, x, z, slot)

    def walls(self, pid, x0, z0, w, d, skip=()):
        """Edges around cells x0..x0+w-1, z0..z0+d-1. `skip`: (x, z, slot) left open."""
        for x in range(x0, x0 + w):
            for e in [(x, z0, "edge_n"), (x, z0 + d, "edge_n")]:
                if e not in skip:
                    self.add(pid, *e)
        for z in range(z0, z0 + d):
            for e in [(x0, z, "edge_w"), (x0 + w, z, "edge_w")]:
                if e not in skip:
                    self.add(pid, *e)

    def save(self, fname):
        data = {"format": "shardlands-blueprint", "version": 1, "name": self.name, "author": "Shardlands",
                "description": self.desc, "pieces": self.pieces}
        with open(os.path.join(ROOT, "data/blueprints", fname), "w") as f:
            json.dump(data, f, indent=1)


# Starter Hut: 4x4 wooden hut with a door on the south side.
d = Design("Starter Hut", "A cosy 4 x 4 wooden hut: floor, walls, a door and a window, thatch roof, bed, chest, table and torches.")
d.rect_cells("wood_floor", -2, -2, 4, 4, "floor")
d.walls("wood_wall", -2, -2, 4, 4)
d.add("wood_door", 0, 2, "edge_n")
d.add("wood_window", 2, -1, "edge_w")
d.add("bed", -2, -2, "object", 0)
d.add("storage_chest", 1, -2, "object", 0)
d.add("table", 1, 0, "object", 0)
d.add("chair", 0, 0, "object", 1)
d.add("torch", -2, 1, "object", 0)
d.add("torch", 1, 3, "object", 0)
d.rect_cells("thatch_roof", -2, -2, 4, 4, "roof")
d.save("starter_hut.json")

# Stone Cottage: 6x5 stone house with workshop corner.
d = Design("Stone Cottage", "A sturdy 6 x 5 stone cottage with a reinforced door, wooden roof, workbench, forge, alchemy table, bed and storage.")
d.rect_cells("stone_floor", -3, -2, 6, 5, "floor")
d.walls("stone_wall", -3, -2, 6, 5)
d.add("reinforced_door", 0, 3, "edge_n")
d.add("wood_window", -3, 0, "edge_w")
d.add("wood_window", 3, 0, "edge_w")
d.add("bed", -3, -2, "object", 0)
d.add("storage_chest", -2, -2, "object", 0)
d.add("storage_chest", -1, -2, "object", 0)
d.add("workbench", 2, -2, "object", 2)
d.add("forge", 2, 0, "object", 3)
d.add("alchemy_table", -3, 2, "object", 1)
d.add("torch", 2, 2, "object", 0)
d.add("torch", -1, 4, "object", 0)
d.rect_cells("wood_roof", -3, -2, 6, 5, "roof")
d.save("stone_cottage.json")

# Watch Post: palisade ring with arrow towers, a bell and spike traps at the gate.
d = Design("Watch Post", "A 9 x 9 log palisade with a reinforced gate, two arrow towers, an alarm bell, torches and spike traps outside the gate. Built to survive raids.")
d.walls("palisade_wall", -4, -4, 9, 9)
d.add("reinforced_door", 0, 5, "edge_n")
d.add("arrow_tower", -3, -3, "object")
d.add("arrow_tower", 3, -3, "object")
d.add("arrow_tower", 3, 3, "object")
d.add("alarm_bell", -3, 3, "object")
d.add("storage_chest", 0, -3, "object")
d.add("torch", -1, 4, "object")
d.add("torch", 1, 4, "object")
for x in (-1, 0, 1):
    d.add("spike_trap", x, 6, "floor")
d.save("watch_post.json")

# Farmstead: fenced field with farm plots and a small shed.
d = Design("Farmstead", "A fenced 8 x 6 field with 18 farm plots (leave the gap in the south fence as your gate) and a tool shed with a chest.")
d.walls("wood_fence", -4, -3, 8, 6, skip={(0, 3, "edge_n")})
for x in range(-3, 3):
    for z in (-2, -1, 1):
        d.add("farm_plot", x, z, "floor")
d.walls("wood_wall", 5, -2, 2, 2, skip={(5, -1, "edge_w")})
d.add("wood_door", 5, -1, "edge_w")
d.add("storage_chest", 6, -2, "object")
d.rect_cells("thatch_roof", 5, -2, 2, 2, "roof")
d.add("torch", 4, 1, "object")
d.save("farmstead.json")
print("ok")
