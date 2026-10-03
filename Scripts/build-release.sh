#!/bin/bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

VERSION="${1:-0.1.4}"
BUILD_NUMBER="${2:-5}"
ARCH="$(uname -m)"

APP_NAME="Testudo"
APP_PATH="dist/Testudo.app"

DIST_DIR="dist"

DMG_NAME="Testudo-${VERSION}-macOS-${ARCH}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

RW_DMG="${DIST_DIR}/Testudo-${VERSION}-rw.dmg"

VOLNAME="Testudo ${VERSION}"

echo
echo "============================================================"
echo "  TESTUDO — RELEASE BUILD"
echo "============================================================"
echo
echo "Version:      ${VERSION}"
echo "Build:        ${BUILD_NUMBER}"
echo "Architecture: ${ARCH}"
echo


# ============================================================
# BUILD APP
# ============================================================

echo "Building Testudo.app..."
echo

./Scripts/build-app.sh \
    release \
    "$VERSION" \
    "$BUILD_NUMBER"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH was not created."
    exit 1
fi

EXECUTABLE="$APP_PATH/Contents/MacOS/Testudo"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: Testudo executable was not found."
    exit 1
fi

echo
echo "Application binary:"
file "$EXECUTABLE"

echo
echo "Verifying application bundle..."

plutil -lint \
    "$APP_PATH/Contents/Info.plist"

echo "✓ Info.plist valid."


# ============================================================
# CLEAN PREVIOUS TEMP IMAGE
# ============================================================

rm -f \
    "$RW_DMG" \
    "$DMG_PATH"

rm -rf \
    "$DIST_DIR/dmg-mount"


# ============================================================
# CREATE WRITABLE BLANK IMAGE
# ============================================================

echo
echo "Creating writable installer image..."

hdiutil create \
    -size 100m \
    -fs HFS+ \
    -volname "$VOLNAME" \
    "$RW_DMG" \
    >/dev/null


# ============================================================
# MOUNT NORMALLY UNDER /Volumes
# ============================================================

echo "Mounting installer image..."

ATTACH_INFO="$(
    hdiutil attach \
        "$RW_DMG" \
        -readwrite \
        -noverify \
        -noautoopen \
        -plist \
    | python3 -c '
import plistlib
import sys

data = plistlib.loads(
    sys.stdin.buffer.read()
)

for entity in data.get("system-entities", []):
    mount = entity.get("mount-point")
    device = entity.get("dev-entry")

    if mount and device:
        print(device)
        print(mount)
        break
else:
    raise SystemExit("Could not find mounted volume in hdiutil plist.")
'
)"

DEVICE="$(
    printf '%s\n' "$ATTACH_INFO" \
    | sed -n '1p'
)"

MOUNT_DIR="$(
    printf '%s\n' "$ATTACH_INFO" \
    | sed -n '2p'
)"

if [ -z "$DEVICE" ] || [ -z "$MOUNT_DIR" ]; then
    echo "ERROR: Could not determine mounted DMG information."
    exit 1
fi

echo "Device:     $DEVICE"
echo "Mount point: $MOUNT_DIR"

if [ ! -d "$MOUNT_DIR" ]; then
    echo "ERROR: Mounted volume directory does not exist."
    exit 1
fi


cleanup() {
    hdiutil detach \
        "$DEVICE" \
        >/dev/null 2>&1 \
        || true

    rm -f \
        "$RW_DMG"
}

trap cleanup EXIT


# ============================================================
# COPY INSTALLER CONTENT
# ============================================================

echo
echo "Copying Testudo.app..."

ditto \
    "$APP_PATH" \
    "$MOUNT_DIR/Testudo.app"

ln -s \
    /Applications \
    "$MOUNT_DIR/Applications"

sync


# ============================================================
# FINDER WINDOW LAYOUT
# ============================================================

echo
echo "Applying Finder layout..."

FINDER_DISK_NAME="$(
    basename "$MOUNT_DIR"
)"

osascript - "$FINDER_DISK_NAME" <<'APPLESCRIPT'
on run argv

    set volumeName to item 1 of argv

    tell application "Finder"

        tell disk volumeName

            open

            delay 1

            set current view of container window to icon view

            set toolbar visible of container window to false
            set statusbar visible of container window to false

            set bounds of container window to {300, 220, 980, 640}

            set viewOptions to icon view options of container window

            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 112
            set text size of viewOptions to 14

            set position of item "Testudo.app" to {175, 190}
            set position of item "Applications" to {505, 190}

            update without registering applications

            delay 2

            close container window

        end tell

    end tell

end run
APPLESCRIPT

sync
sleep 2

echo "✓ Finder layout saved."


# ============================================================
# DETACH WRITABLE IMAGE
# ============================================================

echo
echo "Detaching writable image..."

hdiutil detach \
    "$DEVICE" \
    >/dev/null

trap - EXIT


# ============================================================
# CONVERT TO FINAL COMPRESSED DMG
# ============================================================

echo
echo "Creating final compressed DMG..."

hdiutil convert \
    "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" \
    >/dev/null

rm -f \
    "$RW_DMG"


# ============================================================
# VERIFY FINAL IMAGE
# ============================================================

echo
echo "Verifying DMG..."

hdiutil verify \
    "$DMG_PATH"

echo
echo "SHA-256:"

shasum -a 256 \
    "$DMG_PATH"

echo
echo "============================================================"
echo "  RELEASE BUILD COMPLETE"
echo "============================================================"
echo
echo "Artifact:"
echo "$DMG_PATH"
echo
