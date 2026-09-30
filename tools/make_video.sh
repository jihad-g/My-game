#!/usr/bin/env bash
# Records the scripted gameplay demo (tests/video_runner.gd) and encodes an MP4.
#
#   tools/make_video.sh [out_dir] [godot]
#
# Needs a renderer (a display, or xvfb-run) and ffmpeg. Loading/streaming waits the
# runner logs as "CUT <from> <to>" are removed from the final video.
set -euo pipefail
OUT="${1:-/tmp/shardlands_video}"
GODOT="${2:-godot}"
mkdir -p "$OUT"
cd "$(dirname "$0")/.."

"$GODOT" --path . --resolution 1280x720 --write-movie "$OUT/demo.avi" --fixed-fps 30 \
	res://tests/video_runner.tscn | tee "$OUT/run.log"

# Build an ffmpeg select expression that drops every CUT range.
DROP=$(grep '^CUT ' "$OUT/run.log" | awk '$3 > $2 { printf "%sbetween(n,%d,%d)", (n++ ? "+" : ""), $2, $3 }')
FILTER="scale=1280:720"
if [ -n "$DROP" ]; then
	FILTER="select='not($DROP)',setpts=N/30/TB,$FILTER"
fi
ffmpeg -y -loglevel error -i "$OUT/demo.avi" -an -vf "$FILTER" \
	-c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -movflags +faststart "$OUT/shardlands_gameplay.mp4"
echo "Wrote $OUT/shardlands_gameplay.mp4"
