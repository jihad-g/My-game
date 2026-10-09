# Milestone 18 — "Flow of Battle" (plan)

**Status:** **M18a (v0.21.0), M18b (v0.22.0) and M18c (v0.23.0) are done.** Between M18c and M18d the owner asked for jump + the Vibrant look (v0.24.0) and a world colour pass (v0.25.0). M18d is still a plan. Change anything before we build it.

**Owner's answers (8 Oct 2026):** the fixed isometric camera is an *option* (the free camera stays the default);
aim assist and hold-to-chain are *on by default*; bosses can be knocked down, but *only after their guard (poise)
breaks*; new worlds may look a little different (old saves keep their land).

## The goal in one sentence

Shardlands should feel smooth and fun in the first 10 seconds of play: quick, fluid movement, hack-and-slash
combat that hits hard and reads clearly, animations that flow instead of snapping, spells that look like
real magic, and a world that loads without pops, seams or stutter.

**The feel we aim for:** the easy, fast, "pick it up and fight a crowd" feel of isometric action games like
*Minecraft Dungeons* and *Diablo*. We copy the **feel** (timing, flow, feedback), never their art, names or
content. Shardlands keeps its own code-built blocky look.

## Why this milestone now

- After M17 the game has 212 class abilities, 28 spells, more than 20 weapons and dozens of enemies. But all of it
  is played through simple movement and 17 still key poses that snap in and out.
- Making every step, swing and spell feel good makes **all** of that content better at once.
- Real co-op is moved to **M19**. It should sync the final animation and combat events once, not twice.
- World Polish (textures, horses, boats, Steam) moves to **M20**.

## What is wrong today (honest list)

| Area | Today | Problem |
|---|---|---|
| Movement | Walk/sprint with acceleration, dodge roll, 1-block step-up | Speed-up and turning feel slow and heavy; the model pops up and down on block steps; the dodge can't cancel an attack's end |
| Animation | Procedural limbs (`HumanoidModel`), 17 poses blended by a single weight | No real clips, no layers (legs and arms can't do different things), no blending between moves, feet slide, attacks are one swing shape per weapon |
| Combat feel | Combos, heavy, block, parry, crits, knockback | No hit-stop, enemies don't react to where they were hit, few enemies at once, small knockback, attacks don't snap to the nearest enemy |
| Spells | Simple VFX helpers (`VFX.ring`, `burst`, `bolt`, `motes`) | Every element looks similar: cubes and rings; no glow, no trails, no ground marks, no light |
| World | Chunks stream on threads, 3 LOD levels, far terrain | New chunks and props pop in; LOD changes are visible; 1-block noise steps make bumpy ground; biome borders are hard lines; a first new scene type costs a ~20 ms spike |

---

## The plan: four parts, each one a working game

Like M17, we build it in steps. After each step the game runs, I build the .exe and you can play it.

### M18a — Movement and the new animation system ✅ Done (v0.21.0)

What was built differs from the list below in two places: root motion and damage on the "hit" event are not
done yet (attacks still move you with their old lunge, and combat still times the hit itself). Both come with
M18b, where the combo chains need them.

**1. A compact animation system** (new `src/anim/`)
- `AnimClip`: a short animation made of keyframes for each body part (hips, torso, head, arms, forearms,
  legs, knees, weapon). Each key has a time, a rotation/offset and an ease (in, out, in-out, back, elastic).
  Clips are small data files in `data/anims/` (or code tables), so new moves are data, not code.
- `AnimLayers`: three layers that mix together:
  - **base** — legs and body: idle, walk, run, sprint, jump, fall, land, swim;
  - **action** — the upper body (or the full body for big moves): attacks, abilities, spells, block;
  - **additive** — small extras on top: breathing, hit flinch, recoil, head look.
  A body-part **mask** lets the action layer drive only the arms while the legs keep running.
- **Cross-fades** of 0.06–0.15 s between clips, so nothing snaps.
- **Events** inside clips (`"hit"`, `"step"`, `"spawn_fx"`, `"sound"`) at exact frames. Damage happens on
  the swing's real hit frame instead of a separate timer.
- **Root motion** for attacks: a clip can move the hero forward (a step into each swing).
- The 17 poses from M17c become real clips with a wind-up, a hold and a recovery.
- Co-op: remote players replay clip ids through the existing `anim_event` ("pose" becomes "clip").

**2. Locomotion that looks right**
- Walk → run → sprint blend by speed. The stride length matches the speed, so **feet don't slide**.
- Lean into turns and when speeding up; a small anticipation when starting and a settle when stopping.
- **Turn in place** with a quick foot shuffle instead of spinning on the spot.
- Smooth the model on block steps: the body stays on the ground, but the model glides up over 0.1 s instead of
  popping up.

**3. Movement that feels quick**
- Reach full speed in about 0.1 s and stop in about 0.08 s (tunable in Settings → Gameplay: "Snappy" or
  "Weighty").
- The hero turns fast (about 15 rad/s) but smoothly.
- **Dodge roll v2:**
  - it can cancel the end (recovery) of any attack;
  - it rolls through enemies;
  - it has a short, fixed cooldown instead of being blocked by stamina when you have a little left;
  - it ends with a small slide.
- **Camera:**
  - a slight lead in the direction you move;
  - smoother zoom;
  - an optional fixed isometric angle (like the classic action-RPG view);
  - softer, shorter shake.

**Done when:** you can run, turn, roll and stop without any snap, slide or pop, and attacks, abilities and spells
all play real clips with wind-up and recovery.

### M18b — Hack and slash ✅ Done (v0.22.0)

Built as planned, with these differences: the spear's chain is two thrusts and a sweep (3 hits, not 4); the
packs are 4–10 enemies; simple distant models and a death-effect pool are not done; the 60-enemy frame rate has
not been measured yet; combat still keeps its own clock for the hit (the animation's "hit" event happens at the
same moment).

**1. Combo chains per weapon**
- Every weapon type gets a 3–4 hit chain with **different swings** and a strong **finisher** on the last hit:
  - sword: slash, back-slash, then a spin finisher that pushes enemies back;
  - axe: chop, chop, then an overhead cleave;
  - dagger: a fast 4-hit flurry, then a lunge;
  - war hammer: a sweep, then a ground slam (stun);
  - spear: thrust, thrust, then a wide sweep;
  - greatsword: a big arc, a reverse arc, then a leaping slam;
  - staff and wand: bolt, bolt, then a small blast; unarmed: punch, punch, kick.
- **Hold attack to keep chaining** (no button mashing needed); let go to stop.
- **Attack aim assist:** each swing turns toward the nearest enemy in a 60° cone in front of you (can be
  turned off).
- Movesets stay data (`data/movesets/*.tres`), extended with the chain, the finisher and clip names.

**2. Hits you can feel**
- **Hit-stop:** the game freezes the attacker and target for 40–90 ms on a hit; it is longer on heavy hits,
  crits and finishers (Settings slider, 0 = off).
- **Enemies react:**
  - they flinch away from the side they were hit on;
  - a strong hit knocks them back with a slide;
  - finishers and heavy hits can **knock them down** (they fall, lie on the ground for a moment, get up).
- A white flash on hit, small debris, a bigger damage number pop, and a sound with a little random pitch.
- **Better weapon trails** that follow the real blade arc from the clip.

**3. Crowds**
- New **light "fodder" enemies** in packs of 5–12 (weak skeletons, cultist minions, bandit recruits) so that
  sweeping combos and area abilities have crowds to hit.
- Enemies die with a **topple and a puff** instead of disappearing; loot bursts out and flies to you.
- Performance for 60+ enemies on screen:
  - monster AI thinks less often when it is far away;
  - simple models for distant enemies;
  - shared materials;
  - a pool for death effects.

**4. Clear danger**
- Every big enemy attack shows the **same ground warning** (a red area that fills up before it hits).
- Elites get a colour outline and a short roar when they see you.

**Done when:** a pack of 10 enemies can be cut down with combos in a few seconds, every hit shows hit-stop and a
reaction, and the game still runs at 60 fps on the test machine.

### M18c — Spells and abilities that look like magic ✅ Done (v0.23.0)

Built mostly by upgrading the shared pieces every ability uses (bursts, bolts, projectiles, ground areas, casts),
so all 240 abilities and spells changed at once; abilities with the same shape share a look in their element's
colour. Added on request: **Creative mode for testing** (the ` key).

**1. A VFX library v2** (`src/fx/`)
- Particle effects built with `GPUParticles3D`, with a `CPUParticles3D` fallback for the browser and
  older PCs (`gl_compatibility`).
- Pooled and reused, so casting many spells doesn't stutter.
- Building blocks:
  - glowing projectiles with trails;
  - impact bursts;
  - soft rings and fill-up area markers;
  - **ground marks** (scorch, frost, holy light, poison) that fade out;
  - jagged **lightning arcs** that flicker;
  - beams from the sky;
  - swirls;
  - short **light flashes** (an `OmniLight3D` for 0.1–0.3 s).

**2. A look for each element**

| Element | Look |
|---|---|
| Fire | Orange embers that rise, heat shimmer, scorch marks |
| Frost | Ice shards, cold mist on the ground, a blue frost decal, frozen enemies get an ice shell |
| Lightning | Branching arcs, a white flash, sparks that jump to the ground |
| Arcane | Purple swirls and runes on the ground |
| Holy | Gold beams from the sky and light rays |
| Poison | Green bubbles and a low cloud |
| Shadow | Black smoke that pulls inward |

**3. Every ability and spell gets four things**
- a cast clip from M18a, with a **charge-up glow** on the hands or weapon;
- a travel effect;
- an impact effect;
- a sound.

We go through all 212 class abilities, the 20 shared spells and the 8 advanced spells. Abilities with the same
shape share one effect with a different colour.

**4. Ultimates feel special**
- A short slow-motion moment (0.3 s);
- a screen flash;
- a big ground mark;
- a unique sound.

**Done when:** you can tell every element apart with the sound off, and casting a big spell looks and feels like
the peak of a fight.

### M18d — Smoother world generation

**1. No more pop-in**
- New chunks and props **fade in** (dither) instead of appearing.
- LOD changes cross-fade.
- Trees, towns and points of interest get far-away **impostors** on the horizon (an open item in TODO today).
- All scene types (cave entrances, POIs) are loaded once at the loading screen, which removes the ~20 ms spike.

**2. Smoother land shapes**
- Domain-warped noise for more natural hills.
- Slope smoothing so walking ground doesn't step every block (cliffs only where they are meant to be).
- Valleys carved by rivers.
- Proper beaches.
- **Blended biome borders:**
  - heights and colours mix over about 32 m instead of a hard line;
  - colour variation per block;
  - soft ambient occlusion in the block corners.
- The same seed must still make the same world (determinism tests stay).
- Old saves keep their changed blocks. Chunks you have already visited are not regenerated with the new shape.

**3. Smooth streaming**
- Chunks in front of the camera load first.
- A frame budget of about 2 ms for putting finished chunks into the scene.
- One more ring of chunks is generated before you reach it when you move fast (needed later for horses in M20).

**Done when:**
- a 2-minute sprint across 3 biomes shows no visible pops, seams or stutter;
- the slowest frame stays under 25 ms on the test machine;
- the world statistics tests still pass.

---

## How big is this? (honest estimate)

| Part | Size | Biggest risk |
|---|---|---|
| M18a movement + animation system | Large | Rebuilding `HumanoidModel` animation without breaking 17 milestones of moves; NPCs and monsters use the same model |
| M18b hack and slash | Large | Hit-stop and knockdowns must not break co-op later, AI and balance; performance with crowds |
| M18c spells and VFX | Large (much of it is repetitive work across 240 abilities and spells) | Browser/compatibility build without GPU particles |
| M18d world generation | Medium–Large | Changing terrain shape must keep old saves working |

All four together are about as big as M17 was. I suggest the order **a → b → c → d**: animation first (b and c
use the new clips), world last (it is independent and the riskiest for saves).

## Tests (written, but only run when you say so)

- `test_m18a_*`: clips load, blend weights add up to 1, masks keep the legs running, events fire on the right
  frame, the old poses map to clips.
- `test_m18b_*`: each weapon has a full chain and a finisher, hit-stop timing, knockdown and get-up, aim assist
  picks the nearest enemy in the cone, a crowd of 60 holds 60 fps in the stress tool.
- `test_m18c_*`: every ability and spell has a cast clip, travel/impact effect and sound; effects return to the
  pool.
- `test_m18d_*`: the same seed gives the same terrain; borders blend; streaming frame budget; old saves load.

## Questions for you before we start

1. **Camera:** keep the free-rotate camera as default and add the fixed isometric view as an option, or make
   the fixed view the default?
2. **Aim assist and hold-to-chain:** on by default?
3. **Knockdowns on bosses:** never, or only after their guard (poise) breaks?
4. **World shape:** is it OK if new worlds look a little different from today's? Old saves keep their land.
5. Any weapon combo or spell you want to look a special way?
