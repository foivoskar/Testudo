#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
VERSION="${2:-0.1.3}"
BUILD_NUMBER="${3:-4}"

echo "Building Testudo ${VERSION} (${BUILD_NUMBER}) [$CONFIG]..."
echo

swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/Testudo"

if [ ! -f "$BIN" ]; then
    BIN="$(find "$ROOT/.build" -type f -path "*/$CONFIG/Testudo" -print -quit)"
fi

if [ -z "${BIN:-}" ] || [ ! -f "$BIN" ]; then
    echo "ERROR: Testudo executable was not found after build."
    exit 1
fi

APP="$ROOT/dist/Testudo.app"

rm -rf "$APP"

mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Testudo"

# ------------------------------------------------------------
# Testudo application icon
# ------------------------------------------------------------

TESTUDO_APP_ICON_SOURCE="$ROOT/Sources/Testudo/Resources/TestudoIcon.png"
TESTUDO_APP_ICONSET="$ROOT/.build/TestudoIcon.iconset"
TESTUDO_APP_ICNS="$APP/Contents/Resources/TestudoIcon.icns"

if [ ! -f "$TESTUDO_APP_ICON_SOURCE" ]; then
    echo "ERROR: Missing Testudo application icon:"
    echo "$TESTUDO_APP_ICON_SOURCE"
    exit 1
fi

rm -rf "$TESTUDO_APP_ICONSET"
mkdir -p "$TESTUDO_APP_ICONSET"

sips -z 16 16 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_16x16.png" \
    >/dev/null

sips -z 32 32 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_16x16@2x.png" \
    >/dev/null

sips -z 32 32 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_32x32.png" \
    >/dev/null

sips -z 64 64 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_32x32@2x.png" \
    >/dev/null

sips -z 128 128 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_128x128.png" \
    >/dev/null

sips -z 256 256 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_128x128@2x.png" \
    >/dev/null

sips -z 256 256 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_256x256.png" \
    >/dev/null

sips -z 512 512 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_256x256@2x.png" \
    >/dev/null

sips -z 512 512 \
    "$TESTUDO_APP_ICON_SOURCE" \
    --out "$TESTUDO_APP_ICONSET/icon_512x512.png" \
    >/dev/null

cp \
    "$TESTUDO_APP_ICON_SOURCE" \
    "$TESTUDO_APP_ICONSET/icon_512x512@2x.png"

iconutil \
    -c icns \
    "$TESTUDO_APP_ICONSET" \
    -o "$TESTUDO_APP_ICNS"

rm -rf "$TESTUDO_APP_ICONSET"

TESTUDO_ICON="$ROOT/Sources/Testudo/Resources/testudo_icon_blue.png"

if [ ! -f "$TESTUDO_ICON" ]; then
    echo "ERROR: Missing Testudo visual asset:"
    echo "$TESTUDO_ICON"
    exit 1
fi

cp     "$TESTUDO_ICON"     "$APP/Contents/Resources/testudo_icon_blue.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleExecutable</key>
    <string>Testudo</string>

    <key>CFBundleIdentifier</key>
    <string>com.testudo.Testudo</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>Testudo</string>

    <key>CFBundleDisplayName</key>
    <string>Testudo</string>

    <key>CFBundleIconFile</key>
    <string>TestudoIcon.icns</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>

    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.testudo.environment</string>

            <key>UTTypeDescription</key>
            <string>Testudo Work Environment</string>

            <key>UTTypeConformsTo</key>
            <array>
                <string>com.apple.package</string>
            </array>

            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>testudoenv</string>
                </array>
            </dict>
        </dict>
    </array>

    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Testudo Work Environment</string>

            <key>CFBundleTypeRole</key>
            <string>Editor</string>

            <key>LSHandlerRank</key>
            <string>Owner</string>

            <key>LSItemContentTypes</key>
            <array>
                <string>com.testudo.environment</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

chmod +x "$APP/Contents/MacOS/Testudo"

codesign \
    --force \
    --deep \
    --sign - \
    "$APP" >/dev/null 2>&1 || true

echo
echo "Application created:"
echo "$APP"
