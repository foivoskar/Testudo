#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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
    git
    swift
    xcode-select
    codesign
    hdiutil
    osascript
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
swift --version
echo


# ------------------------------------------------------------
# Read current Testudo release defaults
# ------------------------------------------------------------

VERSION="$(
    sed -n \
        's/^VERSION="${1:-\([^}]*\)}"/\1/p' \
        Scripts/build-release.sh \
    | head -n 1
)"

BUILD_NUMBER="$(
    sed -n \
        's/^BUILD_NUMBER="${2:-\([^}]*\)}"/\1/p' \
        Scripts/build-release.sh \
    | head -n 1
)"

if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
    echo "ERROR: Could not determine the Testudo version/build."
    exit 1
fi

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
echo "Opening the locally built DMG..."
echo

open "$DMG"
