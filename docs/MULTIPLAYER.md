# Multiplayer (Milestone 11 — foundation)

Shardlands supports co-op sessions of up to 8 players over ENet (UDP), using Godot's high-level
multiplayer API. This document describes the architecture, the protocol and what is (and is not)
synchronised yet.

## Roles

| Role | How | Notes |
|---|---|---|
| **Listen server (host)** | Main menu → tick *Host the world I play* → create/load a world, or `--host[=port]` with `--world=`/`--seed=` | The host plays normally; its game is the server. |
| **Dedicated server** | `godot --headless --path . -- --server[=port] [--world=<id> \| --seed=N]` | No local player (the hidden "player" is only the streaming focus). Without a world argument it loads or creates the world `server`. Saves like any world (autosave every 2 min). |
| **Client (guest)** | Main menu → *Join* (address `IP` or `IP:port`), or `--connect=IP[:port] [--name=X] [--class=wizard]` | Generates the world locally from the host's seed. |

Default port: **24565** (UDP). `NetProtocol.MAX_PLAYERS` = 8.

## Authority model

- **Server-authoritative world state.** The host owns: every inventory and equipment, the world's
  changes (felled trees, mined ores, gathered plants), buildings (placement, removal, doors),
  dropped items (pickups), placed objects (campfires), time of day and world time.
- **Client-authoritative movement, server-validated.** Each player simulates their own character
  and sends a state packet 20×/s (position, facing, velocity, animation blend, flags, layer, health
  ratio). The server rejects steps faster than `MAX_SPEED` (32 m/s) and puts the player back
  (`s2c_correct`); legitimate jumps (respawn, cave travel, corrections) carry the `TELEPORT` flag.
- **Character progression is client-reported** (level, skills, XP, recipes, coins). The server
  stores the guest's profile (sent every 30 s) and uses its level for equipment and building
  requirements. Hardening this is future work (see *Not implemented*).

## Multiplayer-safe world generation

World generation is a pure function of the seed (hashes and noise, no shared RNG state), so the
terrain, biomes, props, caves, settlements and POIs are **generated locally on every machine** and
never sent. Only *changes* travel. To guarantee both sides really produce the same world:

- The welcome carries `NetProtocol.world_checksum()`: a hash over generated chunks at five places
  (including far away), two settlement regions, the item and build-piece catalogues. The client
  computes it from the seed **before loading** and refuses to join on a mismatch
  ("This world generates differently on your game").
- The protocol version must match (`NetProtocol.VERSION`).
- The session test generates a terrain sample on both processes and compares them.

## Session flow

```
client                                   server
  connect (ENet)  ───────────────────────►
  c2s_hello {version, name, class} ──────►  validate version / capacity / name (renamed if taken)
                  ◄──────────────────────── s2c_welcome {seed, checksum, time, day/hour, position,
                                              inventory, equipment, profile, buildings,
                                              nearby region changes, pickups, placed objects, players}
  verify checksum, load world from seed,
  apply welcome (World._ready → NetClient.setup_world)
  c2s_ready ─────────────────────────────►  create puppet, tell the others
  c2s_state 20 Hz ───────────────────────►  speed check → s2c_states 20 Hz to everyone
  c2s_request(id, action, args) ─────────►  validate against server state → apply → broadcast
                  ◄──────────────────────── s2c_reply(id, ok, msg, extra) + s2c_inventory snapshot
```

## Messages (`src/net/net.gd`)

All RPCs are on the `Net` autoload. `authority` = only the server may send; `any_peer` messages
are validated by `NetServer` (malformed values, unknown actions, out-of-range slots are rejected).

| Message | Dir | Mode | Content |
|---|---|---|---|
| `c2s_hello` / `s2c_welcome` / `s2c_reject` | ↔ | reliable | handshake |
| `c2s_ready`, `s2c_player_joined/left` | ↔ | reliable | presence |
| `c2s_state` / `s2c_states` | ↔ | unreliable ordered | `[x,y,z,yaw,vx,vz,move,flags,layer,hp]` |
| `c2s_anim` / `s2c_anim` | ↔ | reliable | `attack`, `dodge`, `cast`, `death`, `respawn`, `look` (weapon/shield) |
| `s2c_correct` | → | reliable | position fix after a rejected move |
| `c2s_profile` | ← | reliable | character save without inventory/equipment (≤256 KB) |
| `c2s_request` / `s2c_reply` | ↔ | reliable | actions below |
| `s2c_inventory` | → | reliable | full inventory + equipment snapshot |
| `s2c_props_removed` | → | reliable | `[[chunk, layer, prop index], ...]` |
| `s2c_region` | → | reliable | one 32×32-chunk region of world changes (on join and when entering new regions) |
| `s2c_build` | → | reliable | `add` / `remove` / `state` with a building entry (incl. owner) |
| `s2c_pickup` | → | reliable | `add` / `remove` / `count` of networked pickups |
| `s2c_placed` | → | reliable | a placed object (campfire...) |
| `s2c_time` | → | unreliable | world time, day, hour (every 2 s) |
| `c2s_chat` / `s2c_chat` | ↔ | reliable | chat lines (≤200 characters) |

### Request actions (server checks)

| Action | Server validation |
|---|---|
| `harvest [chunk, layer, index, gather]` | prop exists in the generated chunk, not already removed, within 8 m, right interaction, tool tier in the guest's server inventory → drops go to that inventory |
| `pickup [net_id]` | pickup exists, within 8 m, space in inventory |
| `drop [slot, count]` | slot holds items → networked pickup at the guest's feet |
| `move [from, to]` | valid slots |
| `use [slot]` | consumable / recipe book / spell tome (effects apply on the guest) |
| `equip [slot]` / `unequip [slot]` | level requirement, free space |
| `craft [recipe, times, skill]` | recipe exists, its station within 4.5 m of the guest on the server, skill requirement, materials in the server inventory |
| `place [piece, cell, slot, rot, layer]` | slot type, within 10 m, level, `BuildingManager.check_place` on the server, materials → piece owned by the guest |
| `remove [cell, slot, layer]` | piece exists, within 10 m, **owned by the guest**, chest empty → refund to the guest |
| `door [cell, slot, layer]` | a door within 10 m |
| `place_object [slot, position]` | placeable item, within 8 m |

## Persistence

Guests' characters are stored in the host's world save (`world.net_players`, keyed by player
name): inventory, equipment, position, layer, class and profile. A returning player (same name)
gets everything back — also from a dedicated server.

## Code map

| File | Role |
|---|---|
| `src/net/net.gd` (autoload `Net`) | sessions (host / join / leave), RPC endpoints, chat |
| `src/net/net_server.gd` | peers, validation, authoritative inventories, broadcasts, records |
| `src/net/net_client.gd` | welcome, world setup, requests/replies, applying server state |
| `src/net/remote_player.gd` | other players: interpolation buffer (100 ms), nameplate, animation events |
| `src/net/net_protocol.gd` | constants, packet encoding, input validation, world checksum |
| `src/ui/multiplayer_hud.gd` | who's online, chat (Enter), disconnect handling |
| Hooks | `Inventory.remote`, `Chunk.harvest_prop/hide_prop`, `PropBody`, `Pickup`, `BuildingManager`, `BuildMode`, `BuildPiece.interact`, `CraftingPanel`, `Player` (use/equip/drop/place), `World` (setup, pickups, placed objects, online rules, records) |

## Not implemented yet (honest list)

- **Combat in shared sessions**: monsters, raids and rare events are paused while online (host and
  guests); enemy synchronisation, PvP and shared boss fights are future work.
- **Guests can't**: open chests, trade with NPCs, take village requests, farm, sleep, cook at a
  campfire (crafting at a campfire works), use blueprints, enter dungeons. They get a clear
  message instead.
- **NPCs and settlements** are simulated on each machine (deterministic layouts, but NPC positions
  differ between players).
- **Character progression is trusted** from the client; no server-side combat/XP authority.
- **No NAT traversal, lobby or server browser**: join by IP (port-forward UDP 24565 to host over
  the internet). No encryption or authentication beyond the protocol version (names are not
  accounts).
- Weather intensity is computed locally from the shared world time and the local climate, so two
  players in the same place see the same weather, but debug-forced weather (F2) isn't shared.
