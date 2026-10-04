#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/Scripts/version.sh"

echo
echo "============================================================"
echo "  TESTUDO — BUILD LOCALLY"
echo "============================================================"
echo


# ------------------------------------------------------------
# Platform checks
# ------------------------------------------------------------

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: Testudo currently builds only on macOS."
    exit 1
fi

ARCH="$(uname -m)"

if [ "$ARCH" != "arm64" ]; then
    echo "ERROR: This Testudo release currently targets Apple Silicon."
    echo "Detected architecture: $ARCH"
    exit 1
fi

echo "✓ macOS detected."
echo "✓ Apple Silicon detected."


# ------------------------------------------------------------
# Developer tools
# ------------------------------------------------------------

REQUIRED_COMMANDS=(
    xcode-select
    xcrun
    codesign
    hdiutil
    iconutil
    sips
    shasum
)

for command_name in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo
        echo "ERROR: Required tool not found:"
        echo "  $command_name"
        echo
        echo "Install Xcode or the Apple Command Line Tools and try again."
        exit 1
    fi
done

if ! xcode-select -p >/dev/null 2>&1; then
    echo
    echo "ERROR: Apple developer tools are not configured."
    echo
    echo "You can request installation with:"
    echo
    echo "  xcode-select --install"
    exit 1
fi

echo "✓ Apple developer tools available."

echo

APPLE_SWIFT="$(
    /usr/bin/xcrun --find swift 2>/dev/null || true
)"

if [ -z "$APPLE_SWIFT" ] || [ ! -x "$APPLE_SWIFT" ]; then
    echo "ERROR: Apple Swift could not be located through xcrun."
    exit 1
fi

echo "Apple Swift:"
echo "  $APPLE_SWIFT"
echo

SWIFT_VERSION_OUTPUT="$("$APPLE_SWIFT" --version)"
echo "$SWIFT_VERSION_OUTPUT"
echo

SWIFT_VERSION="$(
    printf '%s\n' "$SWIFT_VERSION_OUTPUT" \
    | sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' \
    | head -n 1
)"

if [ -z "$SWIFT_VERSION" ]; then
    echo "ERROR: Could not determine the installed Swift version."
    exit 1
fi

SWIFT_MAJOR="${SWIFT_VERSION%%.*}"

if [ "$SWIFT_MAJOR" -lt 6 ]; then
    echo "ERROR: Testudo requires Swift 6.0 or later."
    echo "Detected Swift version: $SWIFT_VERSION"
    exit 1
fi

echo "✓ Swift $SWIFT_VERSION satisfies the Testudo requirement."
echo

VERSION="$TESTUDO_VERSION"
BUILD_NUMBER="$TESTUDO_BUILD_NUMBER"

echo "Testudo version: $VERSION"
echo "Build number:    $BUILD_NUMBER"
echo


# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "BUILDING TESTUDO"
echo "------------------------------------------------------------"
echo

# SwiftPM workspace metadata is not necessarily compatible
# between toolchain versions. A source-first user installation
# therefore starts from a fresh build cache.

echo "Cleaning previous SwiftPM build cache..."
rm -rf "$ROOT/.build"
echo "✓ SwiftPM build cache cleared."
echo

./Scripts/build-release.sh \
    "$VERSION" \
    "$BUILD_NUMBER"


# ------------------------------------------------------------
# Verify result
# ------------------------------------------------------------

DMG="dist/Testudo-${VERSION}-macOS-${ARCH}.dmg"

if [ ! -f "$DMG" ]; then
    echo
    echo "ERROR: Expected DMG was not created:"
    echo "$DMG"
    exit 1
fi

echo
echo "------------------------------------------------------------"
echo "VERIFYING LOCAL DMG"
echo "------------------------------------------------------------"
echo

hdiutil verify "$DMG"

SHA256="$(
    shasum -a 256 "$DMG" \
    | awk '{print $1}'
)"

echo
echo "============================================================"
echo "  LOCAL BUILD COMPLETE"
echo "============================================================"
echo
echo "DMG:"
echo "$DMG"
echo
echo "SHA-256:"
echo "$SHA256"
echo
echo "The application was compiled and signed locally on this Mac."
echo

# ------------------------------------------------------------
# Close older mounted Testudo installer images
# ------------------------------------------------------------
#
# Repeated development builds can otherwise leave several older
# Testudo DMGs mounted under /Volumes, which results in multiple
# installer windows or volume names such as:
#
#   Testudo 0.1.4
#   Testudo 0.1.4 1
#   Testudo 0.1.4 2
#
# Before opening the newly built installer, detach only mounted
# volumes matching the current Testudo installer name.

echo "Checking for older mounted Testudo installer images..."

FOUND_OLD_VOLUME=0

while IFS= read -r mounted_volume; do

    if [ -n "$mounted_volume" ]; then
        FOUND_OLD_VOLUME=1

        echo "Detaching old installer:"
        echo "  $mounted_volume"

        hdiutil detach "$mounted_volume" >/dev/null 2>&1 || true
    fi

done < <(
    find /Volumes         -maxdepth 1         -type d         -name "Testudo ${VERSION}*"         -print         2>/dev/null     || true
)

if [ "$FOUND_OLD_VOLUME" -eq 0 ]; then
    echo "✓ No older Testudo installer is mounted."
else
    echo "✓ Older Testudo installer volumes cleared."
fi

echo
echo "Opening the finished Testudo installer..."
echo

open "$DMG"
