#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

APP_SRC="$ROOT/dist/NtfyBar.app"
APP_DST="$HOME/Applications/NtfyBar.app"
killall NtfyBar 2>/dev/null || true
sleep 0.3
mkdir -p "$HOME/Applications"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

echo "==> installed $APP_DST"
open "$APP_DST"
