#!/bin/bash
set -euo pipefail

REPOSITORY_URL="https://github.com/foivoskar/Testudo.git"
DEFAULT_SOURCE_DIR="$HOME/Testudo"

SOURCE_DIR="${TESTUDO_SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
CHECK_ONLY=0

usage() {
    cat <<'EOF'

Testudo local installer

Usage:

    ./install.sh
    ./install.sh --check
    ./install.sh --source-dir PATH

Options:

    --check
        Check the Mac and development environment without
        cloning or building Testudo.

    --source-dir PATH
        Use a source checkout location other than ~/Testudo.

The Testudo application is compiled locally on this Mac.
No prebuilt Testudo executable is downloaded.

EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;

        --source-dir)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: --source-dir requires a path."
                exit 1
            fi

            SOURCE_DIR="$2"
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo
echo "============================================================"
echo "  TESTUDO — LOCAL INSTALLATION"
echo "============================================================"
echo

# ------------------------------------------------------------
# Platform
# ------------------------------------------------------------

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: Testudo currently supports macOS only."
    exit 1
fi

ARCH="$(uname -m)"

if [ "$ARCH" != "arm64" ]; then
    echo "ERROR: Testudo currently requires an Apple Silicon Mac."
    echo "Detected architecture: $ARCH"
    exit 1
fi

echo "✓ macOS detected."
echo "✓ Apple Silicon detected."

# ------------------------------------------------------------
# Apple developer tools
# ------------------------------------------------------------

if ! command -v xcode-select >/dev/null 2>&1; then
    echo
    echo "ERROR: xcode-select is unavailable."
    exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
    echo
    echo "Apple developer tools are not installed."
    echo
    echo "Run:"
    echo
    echo "  xcode-select --install"
    echo
    echo "After installation completes, run the Testudo installer again."
    exit 1
fi

echo "✓ Apple developer tools available."

# ------------------------------------------------------------
# Required commands
# ------------------------------------------------------------

for command_name in git swift; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo
        echo "ERROR: Required command not found:"
        echo "  $command_name"
        exit 1
    fi
done

echo "✓ Git available."

# ------------------------------------------------------------
# Swift
# ------------------------------------------------------------

SWIFT_VERSION_OUTPUT="$(swift --version)"
SWIFT_VERSION="$(
    printf '%s\n' "$SWIFT_VERSION_OUTPUT" \
    | sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' \
    | head -n 1
)"

if [ -z "$SWIFT_VERSION" ]; then
    echo
    echo "ERROR: Could not determine the installed Swift version."
    exit 1
fi

SWIFT_MAJOR="${SWIFT_VERSION%%.*}"

if [ "$SWIFT_MAJOR" -lt 6 ]; then
    echo
    echo "ERROR: Testudo requires Swift 6.0 or later."
    echo "Detected Swift version: $SWIFT_VERSION"
    exit 1
fi

echo "✓ Swift $SWIFT_VERSION available."

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo
    echo "============================================================"
    echo "  ✓ THIS MAC CAN BUILD TESTUDO"
    echo "============================================================"
    echo
    exit 0
fi

echo
echo "Source directory:"
echo "  $SOURCE_DIR"
echo

# ------------------------------------------------------------
# Obtain / update source code
# ------------------------------------------------------------

if [ -e "$SOURCE_DIR" ]; then

    if [ ! -d "$SOURCE_DIR/.git" ]; then
        echo "ERROR:"
        echo "  $SOURCE_DIR"
        echo
        echo "already exists but is not a Testudo Git checkout."
        echo "Nothing was modified."
        exit 1
    fi

    cd "$SOURCE_DIR"

    ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"

    case "$ORIGIN_URL" in
        "https://github.com/foivoskar/Testudo.git"|"https://github.com/foivoskar/Testudo"|"git@github.com:foivoskar/Testudo.git")
            ;;
        *)
            echo "ERROR: Existing repository has an unexpected origin:"
            echo "  $ORIGIN_URL"
            echo
            echo "Nothing was modified."
            exit 1
            ;;
    esac

    if [ -n "$(git status --porcelain)" ]; then
        echo "ERROR: Existing Testudo source checkout contains local changes."
        echo
        git status -sb
        echo
        echo "The installer will not overwrite local work."
        exit 1
    fi

    BRANCH="$(git branch --show-current)"

    if [ "$BRANCH" != "main" ]; then
        echo "ERROR: Existing Testudo checkout is on branch:"
        echo "  $BRANCH"
        echo
        echo "Switch to main before using the automatic installer."
        exit 1
    fi

    echo "Updating existing Testudo source checkout..."

    git fetch origin
    git pull --ff-only origin main

    echo
    echo "✓ Testudo source updated."

else

    echo "Downloading Testudo source code..."

    git clone \
        "$REPOSITORY_URL" \
        "$SOURCE_DIR"

    cd "$SOURCE_DIR"

    echo
    echo "✓ Testudo source downloaded."

fi

# ------------------------------------------------------------
# Build locally
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo "BUILDING TESTUDO LOCALLY"
echo "------------------------------------------------------------"
echo
echo "No prebuilt Testudo executable is being downloaded."
echo "The application will be compiled on this Mac."
echo

./Scripts/build-local-dmg.sh

echo
echo "============================================================"
echo "  ✓ TESTUDO LOCAL INSTALLATION BUILD COMPLETE"
echo "============================================================"
echo
echo "The finished installer should now be open."
echo
echo "Drag Testudo.app into Applications."
echo
