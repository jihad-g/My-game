#!/usr/bin/env python3
"""Cuts the trailer from the raw Movie Maker recording.

  python3 tools/make_trailer.py RAW.avi RECORD.log OUT.mp4

RECORD.log is the output of tests/trailer_runner.tscn; its "TRAILER_CLIP name a b" lines say
which frames to keep. Each clip gets a short fade, the game sounds are kept, and a music
bed made from the game's own tracks (assets/audio/music) is mixed under it.
"""
import os
import re
import subprocess
import sys

FPS = 30
FADE = 6  # frames
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")


def track_for(name: str) -> str:
    if name in ("title", "end"):
        return "menu"
    if name == "village_night":
        return "explore_night"
    if name == "village":
        return "town"
    if name.startswith("fight_"):
        return "combat"
    if name == "dungeon":
        return "dungeon"
    if name == "boss":
        return "boss"
    return "explore_day"


def main() -> None:
    raw, log, out = sys.argv[1], sys.argv[2], sys.argv[3]
    clips = []
    for line in open(log, encoding="utf-8", errors="replace"):
        m = re.match(r"TRAILER_CLIP (\S+) (\d+) (\d+)", line.strip())
        if m and int(m.group(3)) - int(m.group(2)) > FADE * 2:
            clips.append((m.group(1), int(m.group(2)), int(m.group(3))))
    if not clips:
        sys.exit("no clips in the log")
    # Music groups: neighbouring clips with the same track share one piece of music.
    groups = []
    for name, a, b in clips:
        t = track_for(name)
        n = b - a
        if groups and groups[-1][0] == t:
            groups[-1][1] += n
        else:
            groups.append([t, n])
    args = ["ffmpeg", "-y", "-loglevel", "error", "-i", raw]
    tracks = []
    for t, _ in groups:
        if t not in tracks:
            tracks.append(t)
    for t in tracks:
        args += ["-stream_loop", "-1", "-i", os.path.join(MUSIC, t + ".ogg")]
    f = []
    for i, (name, a, b) in enumerate(clips):
        n = b - a
        f.append(f"[0:v]trim=start_frame={a}:end_frame={b},setpts=PTS-STARTPTS,"
                 f"fade=t=in:st=0:d={FADE / FPS:.3f},fade=t=out:st={(n - FADE) / FPS:.3f}:d={FADE / FPS:.3f}[v{i}]")
        f.append(f"[0:a]atrim=start={a / FPS:.4f}:end={b / FPS:.4f},asetpts=PTS-STARTPTS,"
                 f"aformat=sample_rates=48000:channel_layouts=stereo,"
                 f"afade=t=in:st=0:d=0.15,afade=t=out:st={max(n / FPS - 0.15, 0):.3f}:d=0.15[a{i}]")
    f.append("".join(f"[v{i}][a{i}]" for i in range(len(clips))) + f"concat=n={len(clips)}:v=1:a=1[vcat][sfx]")
    offset = {}
    for gi, (t, n) in enumerate(groups):
        k = 1 + tracks.index(t)
        start = offset.get(t, 0.0)
        dur = n / FPS
        offset[t] = start + dur
        f.append(f"[{k}:a]atrim=start={start:.3f}:end={start + dur:.3f},asetpts=PTS-STARTPTS,"
                 f"aformat=sample_rates=48000:channel_layouts=stereo,"
                 f"afade=t=in:st=0:d=0.6,afade=t=out:st={max(dur - 0.8, 0):.3f}:d=0.8[m{gi}]")
    f.append("".join(f"[m{gi}]" for gi in range(len(groups))) + f"concat=n={len(groups)}:v=0:a=1[music]")
    f.append("[music]volume=0.8[mv];[sfx]volume=0.9[sv];[mv][sv]amix=inputs=2:duration=first:normalize=0,"
             "alimiter=limit=0.95[aout]")
    args += ["-filter_complex", ";".join(f), "-map", "[vcat]", "-map", "[aout]",
             "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
             "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    total = sum(b - a for _, a, b in clips) / FPS
    print(f"{len(clips)} clips, {total:.1f} s")
    for name, a, b in clips:
        print(f"  {name:28s} {(b - a) / FPS:5.1f} s")
    subprocess.run(args, check=True)


if __name__ == "__main__":
    main()
