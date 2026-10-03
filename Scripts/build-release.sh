#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/Scripts/version.sh"

VERSION="${1:-$TESTUDO_VERSION}"
BUILD_NUMBER="${2:-$TESTUDO_BUILD_NUMBER}"
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
# DETERMINE INSTALLER IMAGE SIZE
# ============================================================

APP_SIZE_KIB="$(
    du -sk "$APP_PATH"     | awk '{print $1}'
)"

if [ -z "$APP_SIZE_KIB" ]; then
    echo "ERROR: Could not determine Testudo.app size."
    exit 1
fi

APP_SIZE_MIB="$(
    awk -v kib="$APP_SIZE_KIB"         'BEGIN { printf "%d", (kib + 1023) / 1024 }'
)"

# Give the writable installer image enough space for:
# - Testudo.app
# - filesystem metadata
# - Finder metadata
# - future application growth
#
# Never create an image smaller than 100 MiB.

DMG_SIZE_MIB=$((APP_SIZE_MIB + 64))

if [ "$DMG_SIZE_MIB" -lt 100 ]; then
    DMG_SIZE_MIB=100
fi

echo
echo "Application size: approximately ${APP_SIZE_MIB} MiB"
echo "Writable DMG size: ${DMG_SIZE_MIB} MiB"


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
    -size "${DMG_SIZE_MIB}m" \
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
        -nobrowse \
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
# INSTALLER CONTENT COMPLETE
# ============================================================

# No Finder or AppleScript window is opened here.
#
# The writable installer image remains hidden while it is being
# prepared. The user will see only the final DMG opened by
# build-local-dmg.sh after the complete build has finished.

sync


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
