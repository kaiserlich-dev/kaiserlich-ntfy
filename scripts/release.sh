#!/bin/bash
# Builds a universal, Developer ID–signed, notarized ntfy DMG: scripts/release.sh 1.1.0 [--publish]
# Needs, once, the app-specific password in the keychain (shared with Pastefast):
#   security add-generic-password -s pastefast-notarize -a julian@kaiserlich.dev -w
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:?usage: scripts/release.sh X.Y.Z}"
APP_NAME="NtfyBar"
BUNDLE_ID="dev.kaiserlich.NtfyBar"
IDENTITY="Developer ID Application: Julian Kaiser (XJ92F6A382)"
APPLE_ID="julian@kaiserlich.dev"
TEAM_ID="XJ92F6A382"
OUT="$ROOT/dist/release"
APP="$OUT/$APP_NAME.app"
DMG="$ROOT/dist/NtfyBar-$VERSION.dmg"

PASSWORD="$(security find-generic-password -s pastefast-notarize -w)"

echo "==> building universal $APP_NAME $VERSION"
swift build -c release --arch arm64 --arch x86_64 --product "$APP_NAME"
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

rm -rf "$OUT" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
echo "APPL????" > "$APP/Contents/PkgInfo"
bash scripts/build.sh >/dev/null  # refreshes dist/NtfyBar.app's icon
cp dist/$APP_NAME.app/Contents/Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R dist/$APP_NAME.app/Contents/Frameworks "$APP/Contents/"

echo "==> signing"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --timestamp \
  --entitlements Resources/NtfyBar.entitlements \
  --identifier "$BUNDLE_ID" --sign "$IDENTITY" "$APP"

echo "==> disk image"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ntfy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --timestamp --sign "$IDENTITY" "$DMG"

echo "==> notarizing (minutes)"
xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$PASSWORD" --wait
xcrun stapler staple "$DMG"

echo "==> verifying"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
echo "==> update feed"
# EdDSA key lives in the login keychain (generate_keys --account ntfy-bar).
SPARKLE_BIN="$(find .build/artifacts -type d -name bin -path "*Sparkle*" | head -n 1)"
SIG="$("$SPARKLE_BIN/sign_update" --account ntfy-bar "$DMG")"
URL="https://github.com/kaiserlich-dev/kaiserlich-ntfy/releases/download/v$VERSION/$(basename "$DMG")"
BUILD="$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")"
cat > "$ROOT/dist/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ntfy</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$URL" $SIG type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML

if [[ "${2:-}" == "--publish" ]]; then
  gh release create "v$VERSION" "$DMG" "$ROOT/dist/appcast.xml" \
    --repo kaiserlich-dev/kaiserlich-ntfy --title "NtfyBar $VERSION" --generate-notes --latest
fi
echo "==> $DMG"
