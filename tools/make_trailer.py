#!/usr/bin/env python3
"""Cuts the trailer from the raw Movie Maker recordings of tests/trailer_runner.tscn.

  python3 tools/make_trailer.py OUT.mp4 RAW1.avi LOG1 [RAW2.avi LOG2 ...]

Each LOG has "TRAILER_CLIP name first last" lines (frames at 30 fps). The clips are cut one
by one (with a short fade), put in the order of ORDER, and a music bed made from the game's
own tracks (assets/audio/music) is mixed under the game sounds.
"""
import os
import re
import subprocess
import sys
import tempfile

FPS = 30
FADE = 6  # frames
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
ORDER = ["title", "explore", "biome_sunscorch_desert", "biome_snowy_tundra", "biome_emerald_jungle",
         "biome_crystal_glade", "cave", "village", "village_night", "kingdom", "ride", "sail", "storm",
         "fight_the_knight", "fight_the_barbarian", "fight_the_wizard", "fight_the_assassin", "dungeon",
         "boss", "end"]


def track_for(name: str) -> str:
    if name in ("title", "end"):
        return "menu"
    if name == "village_night":
        return "explore_night"
    if name in ("village", "kingdom"):
        return "town"
    if name.startswith("fight_"):
        return "combat"
    if name in ("dungeon", "cave"):
        return "dungeon"
    if name == "boss":
        return "boss"
    return "explore_day"


def run(args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def main() -> None:
    out = sys.argv[1]
    pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))
    clips = {}
    for raw, log in pairs:
        for line in open(log, encoding="utf-8", errors="replace"):
            m = re.match(r"TRAILER_CLIP (\S+) (\d+) (\d+)", line.strip())
            if m and int(m.group(3)) - int(m.group(2)) > FADE * 2:
                clips[m.group(1)] = (raw, int(m.group(2)), int(m.group(3)))
    names = [n for n in ORDER if n in clips] + [n for n in clips if n not in ORDER]
    tmp = tempfile.mkdtemp(prefix="trailer_")
    parts = []
    for i, name in enumerate(names):
        raw, a, b = clips[name]
        n = b - a
        d = n / FPS
        part = os.path.join(tmp, f"{i:02d}.mp4")
        run(["-ss", f"{a / FPS:.4f}", "-i", raw, "-t", f"{d:.4f}",
             "-vf", f"fade=t=in:st=0:d={FADE / FPS:.3f},fade=t=out:st={d - FADE / FPS:.3f}:d={FADE / FPS:.3f},format=yuv420p",
             "-af", f"aformat=sample_rates=48000:channel_layouts=stereo,afade=t=in:st=0:d=0.15,afade=t=out:st={max(d - 0.15, 0):.3f}:d=0.15",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", str(FPS), "-c:a", "pcm_s16le", part.replace(".mp4", ".mov")])
        parts.append((name, part.replace(".mp4", ".mov"), d))
    listing = os.path.join(tmp, "list.txt")
    with open(listing, "w") as f:
        for _, p, _ in parts:
            f.write(f"file '{p}'\n")
    joined = os.path.join(tmp, "joined.mov")
    run(["-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined])
    # Music groups: neighbouring clips with the same track share one piece.
    groups = []
    for name, _, d in parts:
        t = track_for(name)
        if groups and groups[0 if False else -1][0] == t:
            groups[-1][1] += d
        else:
            groups.append([t, d])
    tracks = []
    for t, _ in groups:
        if t not in tracks:
            tracks.append(t)
    args = []
    for t in tracks:
        args += ["-stream_loop", "-1", "-i", os.path.join(MUSIC, t + ".ogg")]
    f = []
    used = {}
    for gi, (t, d) in enumerate(groups):
        k = tracks.index(t)
        s = used.get(t, 0.0)
        used[t] = s + d
        f.append(f"[{k}:a]atrim=start={s:.3f}:end={s + d:.3f},asetpts=PTS-STARTPTS,"
                 f"aformat=sample_rates=48000:channel_layouts=stereo,"
                 f"afade=t=in:st=0:d=0.6,afade=t=out:st={max(d - 0.8, 0):.3f}:d=0.8[m{gi}]")
    f.append("".join(f"[m{gi}]" for gi in range(len(groups))) + f"concat=n={len(groups)}:v=0:a=1[music]")
    music = os.path.join(tmp, "music.wav")
    run(args + ["-filter_complex", ";".join(f), "-map", "[music]", music])
    run(["-i", joined, "-i", music, "-filter_complex",
         "[1:a]volume=0.8[mv];[0:a]volume=0.9[sv];[mv][sv]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[aout]",
         "-map", "0:v", "-map", "[aout]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest",
         "-movflags", "+faststart", out])
    total = sum(d for _, _, d in parts)
    print(f"{len(parts)} clips, {total:.1f} s")
    for name, _, d in parts:
        print(f"  {name:28s} {d:5.1f} s")


if __name__ == "__main__":
    main()
