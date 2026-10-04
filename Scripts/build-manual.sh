#!/bin/bash
set -euo pipefail

ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)"

MANUAL_DIR="$ROOT/Documentation/TestudoManual"
SOURCE="$MANUAL_DIR/Testudo_manual.tex"
CLASS="$MANUAL_DIR/testudomanual.cls"

BUILD_DIR="$ROOT/.build/manual"
BUILT_PDF="$BUILD_DIR/Testudo_manual.pdf"
OUTPUT_PDF="$ROOT/Testudo_manual.pdf"

OPEN_AFTER_BUILD=0
KEEP_BUILD=0

usage() {
    cat <<'USAGE'

Build the Testudo User Manual.

Usage:

    ./Scripts/build-manual.sh
    ./Scripts/build-manual.sh --open
    ./Scripts/build-manual.sh --keep-build

Options:

    --open
        Open the completed PDF after a successful build.

    --keep-build
        Keep LaTeX auxiliary files in .build/manual.

    -h, --help
        Display this help.

Inputs:

    Documentation/TestudoManual/Testudo_manual.tex
    Documentation/TestudoManual/testudomanual.cls

Output:

    Testudo_manual.pdf

USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --open)
            OPEN_AFTER_BUILD=1
            shift
            ;;

        --keep-build)
            KEEP_BUILD=1
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

for REQUIRED in "$SOURCE" "$CLASS"; do
    if [ ! -f "$REQUIRED" ]; then
        echo "ERROR: Required manual source is missing:" >&2
        echo "  $REQUIRED" >&2
        exit 1
    fi
done

if ! command -v xelatex >/dev/null 2>&1; then
    echo "ERROR: XeLaTeX is required." >&2
    exit 1
fi

if ! command -v latexmk >/dev/null 2>&1; then
    echo "ERROR: latexmk is required." >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cleanup() {
    if [ "$KEEP_BUILD" -eq 0 ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

echo "============================================================"
echo " TESTUDO — BUILD USER MANUAL"
echo "============================================================"
echo
echo "Source:"
echo "  $SOURCE"
echo
echo "Class:"
echo "  $CLASS"
echo

(
    cd "$MANUAL_DIR"

    latexmk \
        -xelatex \
        -interaction=nonstopmode \
        -halt-on-error \
        -file-line-error \
        -outdir="$BUILD_DIR" \
        "$(basename "$SOURCE")"
)

if [ ! -s "$BUILT_PDF" ]; then
    echo "ERROR: XeLaTeX completed without producing a PDF." >&2
    exit 1
fi

TMP_OUTPUT="$ROOT/.Testudo_manual.pdf.tmp"

rm -f "$TMP_OUTPUT"

cp \
    "$BUILT_PDF" \
    "$TMP_OUTPUT"

mv \
    "$TMP_OUTPUT" \
    "$OUTPUT_PDF"

if [ ! -s "$OUTPUT_PDF" ]; then
    echo "ERROR: Final Testudo_manual.pdf is missing." >&2
    exit 1
fi

echo
echo "============================================================"
echo " ✓ TESTUDO USER MANUAL BUILT"
echo "============================================================"
echo
echo "Output:"
echo "  $OUTPUT_PDF"
echo
echo "SHA-256:"
shasum -a 256 "$OUTPUT_PDF"

echo
echo "File:"
file "$OUTPUT_PDF"

if command -v mdls >/dev/null 2>&1; then
    PAGES="$(
        mdls \
            -name kMDItemNumberOfPages \
            -raw \
            "$OUTPUT_PDF" \
            2>/dev/null \
            || true
    )"

    if [ -n "$PAGES" ] && [ "$PAGES" != "(null)" ]; then
        echo
        echo "Pages:"
        echo "  $PAGES"
    fi
fi

if [ "$KEEP_BUILD" -eq 1 ]; then
    echo
    echo "Auxiliary build files:"
    echo "  $BUILD_DIR"
fi

if [ "$OPEN_AFTER_BUILD" -eq 1 ]; then
    open "$OUTPUT_PDF"
fi
