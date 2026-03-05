#!/usr/bin/env bash
# Build the AlphaPose Singularity container from source.
# This is NOT a simple pull — it compiles AlphaPose inside the container.
# Expected build time: 30–60 minutes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose.sif"
DEF="$REPO_DIR/alphapose.def"

echo "=== AlphaPose container build ==="

if [ ! -f "$DEF" ]; then
    echo "ERROR: Definition file not found: $DEF"
    exit 1
fi

if [ -f "$SIF" ]; then
    echo "Container already exists: $SIF"
    echo "Delete it first if you want to rebuild:"
    echo "  rm $SIF"
    exit 0
fi

echo "WARNING: Building AlphaPose from source takes 30–60 minutes."
echo "The build requires internet access and ~10 GB of disk space."
echo ""

# Try apptainer first, fall back to singularity
if command -v apptainer &>/dev/null; then
    BUILD_CMD="apptainer build"
elif command -v singularity &>/dev/null; then
    BUILD_CMD="singularity build --fakeroot"
else
    echo "ERROR: Neither apptainer nor singularity found in PATH."
    exit 1
fi

echo "Using: $BUILD_CMD"
echo "Output: $SIF"
echo ""

cd "$REPO_DIR"
$BUILD_CMD "$SIF" "$DEF"

echo ""
echo "=== Build complete: $SIF ==="
