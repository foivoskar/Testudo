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

TESTUDO_ICON="$ROOT/Sources/DReport/Resources/testudo_icon_blue.png"

if [ ! -f "$TESTUDO_ICON" ]; then
    echo "ERROR: Missing Testudo visual asset:"
    echo "$TESTUDO_ICON"
    exit 1
fi

cp     "$TESTUDO_ICON"     "$APP/Contents/Resources/testudo_icon_blue.png"

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

chmod +x "$APP/Contents/MacOS/DReport"

codesign \
    --force \
    --deep \
    --sign - \
    "$APP" >/dev/null 2>&1 || true

echo
echo "Application created:"
echo "$APP"
