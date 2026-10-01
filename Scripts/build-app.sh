#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"

echo "Building DReport ($CONFIG)..."
echo

swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/DReport"

if [ ! -f "$BIN" ]; then
    BIN="$(find "$ROOT/.build" -type f -path "*/$CONFIG/DReport" -print -quit)"
fi

if [ -z "${BIN:-}" ] || [ ! -f "$BIN" ]; then
    echo "ERROR: DReport executable was not found after build."
    exit 1
fi

APP="$ROOT/dist/DReport.app"

rm -rf "$APP"

mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/DReport"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleExecutable</key>
    <string>DReport</string>

    <key>CFBundleIdentifier</key>
    <string>com.dreport.DReport</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>DReport</string>

    <key>CFBundleDisplayName</key>
    <string>DReport</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

chmod +x "$APP/Contents/MacOS/DReport"

codesign \
    --force \
    --deep \
    --sign - \
    "$APP" >/dev/null 2>&1 || true

echo
echo "Application created:"
echo "$APP"
