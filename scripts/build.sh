#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="NtfyBar"
BUNDLE_ID="dev.kaiserlich.NtfyBar"
DIST="$ROOT/dist/$APP_NAME.app"
BIN_DIR="$DIST/Contents/MacOS"
RES_DIR="$DIST/Contents/Resources"

echo "==> building $APP_NAME"
swift build -c release --product "$APP_NAME"

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
test -x "$BIN"

rm -rf "$DIST"
mkdir -p "$BIN_DIR" "$RES_DIR"

cp "$BIN" "$BIN_DIR/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
echo "APPL????" > "$DIST/Contents/PkgInfo"

ICON_SRC="$ROOT/Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
  ICONSET="$ROOT/dist/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
  rm -rf "$ICONSET"
fi

codesign --force --deep --sign - \
  --entitlements "$ROOT/Resources/NtfyBar.entitlements" \
  --identifier "$BUNDLE_ID" \
  "$DIST" >/dev/null

echo "==> built $DIST"
