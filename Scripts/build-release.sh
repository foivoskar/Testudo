#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/Scripts/version.sh"

VERSION="${1:-$TESTUDO_VERSION}"
BUILD_NUMBER="${2:-$TESTUDO_BUILD_NUMBER}"
ARCH="$(uname -m)"

APP_PATH="dist/Testudo.app"
DIST_DIR="dist"

DMG_NAME="Testudo-${VERSION}-macOS-${ARCH}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

RW_IMAGE="${DIST_DIR}/Testudo-${VERSION}-working.raw.dmg"

MOUNT_DIR="${DIST_DIR}/dmg-working-mount"
VERIFY_MOUNT="${DIST_DIR}/dmg-verify-mount"

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
# 1. BUILD APPLICATION
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

if [ ! -x "$EXECUTABLE" ]; then
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

APP_VERSION="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$APP_PATH/Contents/Info.plist"
)"

APP_BUILD="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleVersion' \
        "$APP_PATH/Contents/Info.plist"
)"

if [ "$APP_VERSION" != "$VERSION" ]; then
    echo "ERROR: Application version mismatch."
    echo "Expected: $VERSION"
    echo "Actual:   $APP_VERSION"
    exit 1
fi

if [ "$APP_BUILD" != "$BUILD_NUMBER" ]; then
    echo "ERROR: Application build mismatch."
    echo "Expected: $BUILD_NUMBER"
    echo "Actual:   $APP_BUILD"
    exit 1
fi

echo "✓ Application bundle valid."
echo "✓ Application version: ${APP_VERSION} (${APP_BUILD})"

# ============================================================
# 2. CALCULATE WORKING IMAGE SIZE
# ============================================================

APP_SIZE_KIB="$(
    du -sk "$APP_PATH" |
    awk '{print $1}'
)"

APP_SIZE_MIB="$(
    awk -v kib="$APP_SIZE_KIB" \
        'BEGIN { printf "%d", (kib + 1023) / 1024 }'
)"

IMAGE_SIZE_MIB=$((APP_SIZE_MIB + 64))

if [ "$IMAGE_SIZE_MIB" -lt 100 ]; then
    IMAGE_SIZE_MIB=100
fi

echo
echo "Application size: approximately ${APP_SIZE_MIB} MiB"
echo "Working image size: ${IMAGE_SIZE_MIB} MiB"

# ============================================================
# 3. CLEAN PREVIOUS IMAGE STATE
# ============================================================

rm -f \
    "$RW_IMAGE" \
    "$DMG_PATH"

rm -rf \
    "$MOUNT_DIR" \
    "$VERIFY_MOUNT"

mkdir -p \
    "$MOUNT_DIR" \
    "$VERIFY_MOUNT"

WORKING_ATTACHED=0
VERIFY_ATTACHED=0

cleanup() {
    if [ "$VERIFY_ATTACHED" -eq 1 ]; then
        diskutil eject \
            "$VERIFY_MOUNT" \
            >/dev/null 2>&1 \
            || true
    fi

    if [ "$WORKING_ATTACHED" -eq 1 ]; then
        diskutil eject \
            "$MOUNT_DIR" \
            >/dev/null 2>&1 \
            || true
    fi

    rm -rf \
        "$MOUNT_DIR" \
        "$VERIFY_MOUNT"

    rm -f \
        "$RW_IMAGE"
}

trap cleanup EXIT

# ============================================================
# 4. CREATE BLANK READ/WRITE APFS IMAGE
# ============================================================

echo
echo "Creating working APFS disk image..."

diskutil image create blank \
    --format RAW \
    --size "${IMAGE_SIZE_MIB}MiB" \
    --volumeName "$VOLNAME" \
    --fs APFS \
    "$RW_IMAGE"

if [ ! -s "$RW_IMAGE" ]; then
    echo "ERROR: Working disk image was not created."
    exit 1
fi

echo "✓ Working image created."

# ============================================================
# 5. ATTACH WORKING IMAGE
# ============================================================

echo
echo "Attaching working image..."

diskutil image attach \
    --mountPoint "$MOUNT_DIR" \
    "$RW_IMAGE"

WORKING_ATTACHED=1

if [ ! -d "$MOUNT_DIR" ]; then
    echo "ERROR: Working image mount point is unavailable."
    exit 1
fi

# ============================================================
# 6. COPY INSTALLER CONTENT
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

if [ ! -d "$MOUNT_DIR/Testudo.app" ]; then
    echo "ERROR: Testudo.app missing from working image."
    exit 1
fi

if [ ! -L "$MOUNT_DIR/Applications" ]; then
    echo "ERROR: Applications link missing from working image."
    exit 1
fi

echo "✓ Installer contents copied."

# ============================================================
# 7. EJECT WORKING IMAGE
# ============================================================

echo
echo "Ejecting working image..."

diskutil eject \
    "$MOUNT_DIR"

WORKING_ATTACHED=0

# ============================================================
# 8. CONVERT EXISTING IMAGE TO COMPRESSED UDZO
# ============================================================

echo
echo "Creating compressed release image..."

diskutil image create from \
    --format UDZO \
    "$RW_IMAGE" \
    "$DMG_PATH"

if [ ! -s "$DMG_PATH" ]; then
    echo "ERROR: Final DMG was not created."
    exit 1
fi

echo "✓ Compressed DMG created."

# ============================================================
# 9. ATTACH FINAL IMAGE READ-ONLY
# ============================================================

echo
echo "Attaching final DMG read-only for verification..."

diskutil image attach \
    --readOnly \
    --mountOptions nobrowse \
    --mountPoint "$VERIFY_MOUNT" \
    "$DMG_PATH"

VERIFY_ATTACHED=1

if [ ! -d "$VERIFY_MOUNT/Testudo.app" ]; then
    echo "ERROR: Testudo.app missing from final DMG."
    exit 1
fi

if [ ! -L "$VERIFY_MOUNT/Applications" ]; then
    echo "ERROR: Applications link missing from final DMG."
    exit 1
fi

LINK_TARGET="$(
    readlink \
        "$VERIFY_MOUNT/Applications"
)"

if [ "$LINK_TARGET" != "/Applications" ]; then
    echo "ERROR: Applications link has wrong target."
    echo "Actual: $LINK_TARGET"
    exit 1
fi

# ============================================================
# 10. VERIFY FINAL DMG APPLICATION
# ============================================================

MOUNTED_INFO="$VERIFY_MOUNT/Testudo.app/Contents/Info.plist"

plutil -lint \
    "$MOUNTED_INFO"

MOUNTED_VERSION="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$MOUNTED_INFO"
)"

MOUNTED_BUILD="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleVersion' \
        "$MOUNTED_INFO"
)"

if [ "$MOUNTED_VERSION" != "$VERSION" ]; then
    echo "ERROR: DMG application version mismatch."
    exit 1
fi

if [ "$MOUNTED_BUILD" != "$BUILD_NUMBER" ]; then
    echo "ERROR: DMG application build mismatch."
    exit 1
fi

SOURCE_HASH="$(
    shasum -a 256 \
        "$APP_PATH/Contents/MacOS/Testudo" |
    awk '{print $1}'
)"

DMG_HASH="$(
    shasum -a 256 \
        "$VERIFY_MOUNT/Testudo.app/Contents/MacOS/Testudo" |
    awk '{print $1}'
)"

if [ "$SOURCE_HASH" != "$DMG_HASH" ]; then
    echo "ERROR: Executable inside DMG does not match built app."
    exit 1
fi

echo "✓ Final DMG application: ${MOUNTED_VERSION} (${MOUNTED_BUILD})"
echo "✓ Applications shortcut verified."
echo "✓ Executable hash verified."

# ============================================================
# 11. EJECT FINAL IMAGE
# ============================================================

echo
echo "Ejecting verified DMG..."

diskutil eject \
    "$VERIFY_MOUNT"

VERIFY_ATTACHED=0

# ============================================================
# 12. CLEAN TEMPORARY WORKING IMAGE
# ============================================================

rm -f \
    "$RW_IMAGE"

rm -rf \
    "$MOUNT_DIR" \
    "$VERIFY_MOUNT"

trap - EXIT

# ============================================================
# 13. FINAL ARTIFACT
# ============================================================

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
