#!/usr/bin/env bash
# Runs the automated test suite headlessly.
# Usage: tools/run_tests.sh [path/to/godot]
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
# Make sure the class cache / imports exist (first run after clone).
if [ ! -d .godot ]; then
  timeout 180 "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
fi
timeout 300 "$GODOT" --headless --path . res://tests/test_runner.tscn
