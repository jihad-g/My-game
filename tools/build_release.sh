#!/usr/bin/env bash
# Builds release packages (Milestone 13):
#   build/release/Shardlands-v<version>-windows.zip   one .exe with the game inside
#   build/release/Shardlands-v<version>-linux.tar.gz
#   build/release/web/                                 browser build + launcher page
#
#   tools/build_release.sh [windows] [linux] [web]     (default: all three)
#
# Needs the Godot 4.4.1 export templates: python3 tools/fetch_export_templates.py windows linux web
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(windows linux web)
OUT=build/release
mkdir -p "$OUT"
echo "Shardlands $VERSION -> $OUT (${TARGETS[*]})"
timeout 600 "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true

readme() {
	cat <<TXT
Shardlands v$VERSION
====================

1. Unzip anywhere.
2. Start the game: $1
3. The game is not code-signed yet. On Windows, if SmartScreen says "Windows protected
   your PC", click "More info" -> "Run anyway".

Needs a graphics card with Vulkan support (or start with --rendering-driver opengl3).
Saves: Windows %APPDATA%\\Godot\\app_userdata\\Shardlands  ·  Linux ~/.local/share/godot/app_userdata/Shardlands
Press F1 in the game for the guide. If the game ever crashes, a report is written
to the crash_reports folder next to your saves - please send it to us.
TXT
}

for t in "${TARGETS[@]}"; do
	case "$t" in
	windows)
		rm -rf build/windows && mkdir -p build/windows
		"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/Shardlands.exe >/dev/null
		readme "double-click Shardlands.exe" > build/windows/README.txt
		(cd build && rm -f "../$OUT/Shardlands-v$VERSION-windows.zip" && zip -9 -q -r "../$OUT/Shardlands-v$VERSION-windows.zip" windows)
		;;
	linux)
		rm -rf build/linux && mkdir -p build/linux
		"$GODOT" --headless --path . --export-release "Linux" build/linux/Shardlands.x86_64 >/dev/null
		chmod +x build/linux/Shardlands.x86_64
		readme "./Shardlands.x86_64" > build/linux/README.txt
		tar -C build -czf "$OUT/Shardlands-v$VERSION-linux.tar.gz" linux
		;;
	web)
		rm -rf build/web "$OUT/web" && mkdir -p build/web "$OUT/web"
		"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null
		# Hosts that limit file size/type (claude.ai artifacts): the engine in
		# <15 MB parts, the data as .wasm; the launcher page joins them again.
		split -b 14500000 -d -a 1 build/web/index.wasm "$OUT/web/engine.part"
		parts="["
		for f in "$OUT"/web/engine.part?; do mv "$f" "$f.wasm"; parts="$parts\"$(basename "$f").wasm\", "; done
		parts="${parts%, }]"
		cp build/web/index.pck "$OUT/web/game-data.pck.wasm"
		cp build/web/index.js build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js "$OUT/web/"
		sed -e "s/{VERSION}/$VERSION/" -e "s/{PCK_SIZE}/$(stat -c%s build/web/index.pck)/" \
			-e "s/{WASM_SIZE}/$(stat -c%s build/web/index.wasm)/" -e "s/{PARTS}/$parts/" \
			tools/web/shardlands.html > "$OUT/web/shardlands.html"
		;;
	*) echo "unknown target $t"; exit 1 ;;
	esac
done
ls -la "$OUT"
