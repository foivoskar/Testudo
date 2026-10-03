#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

VERSION="${1:-0.1.1}"
BUILD_NUMBER="${2:-2}"
ARCH="$(uname -m)"

APP_NAME="Testudo"
APP_PATH="dist/Testudo.app"

DIST_DIR="dist"
STAGING_DIR="${DIST_DIR}/dmg-staging"

DMG_NAME="Testudo-${VERSION}-macOS-${ARCH}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo
echo "============================================================"
echo "  TESTUDO — RELEASE BUILD"
echo "============================================================"
echo
echo "Version:      ${VERSION}"
echo "Build:        ${BUILD_NUMBER}"
echo "Architecture: ${ARCH}"
echo

rm -rf "${STAGING_DIR}"

mkdir -p \
    "${DIST_DIR}" \
    "${STAGING_DIR}"

echo "Building Testudo.app..."
echo

./Scripts/build-app.sh release "$VERSION" "$BUILD_NUMBER"

if [ ! -d "${APP_PATH}" ]; then
    echo
    echo "ERROR: ${APP_PATH} was not created."
    exit 1
fi

EXECUTABLE="${APP_PATH}/Contents/MacOS/Testudo"

if [ ! -f "${EXECUTABLE}" ]; then
    echo
    echo "ERROR: Testudo executable was not found."
    exit 1
fi

echo
echo "Application binary:"
file "${EXECUTABLE}"

echo
echo "Verifying application bundle..."

plutil -lint \
    "${APP_PATH}/Contents/Info.plist"

echo "✓ Info.plist valid."

echo
echo "Preparing DMG staging area..."

ditto \
    "${APP_PATH}" \
    "${STAGING_DIR}/${APP_NAME}.app"

ln -s \
    /Applications \
    "${STAGING_DIR}/Applications"

rm -f \
    "${DMG_PATH}"

echo
echo "Creating:"
echo "${DMG_PATH}"
echo

hdiutil create \
    -volname "Testudo" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo
echo "Verifying DMG..."

hdiutil verify \
    "${DMG_PATH}"

echo
echo "SHA-256:"
shasum -a 256 \
    "${DMG_PATH}"

rm -rf \
    "${STAGING_DIR}"

echo
echo "============================================================"
echo "  RELEASE BUILD COMPLETE"
echo "============================================================"
echo
echo "Artifact:"
echo "${DMG_PATH}"
echo
