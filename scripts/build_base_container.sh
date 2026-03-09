#!/usr/bin/env bash
# Build the AlphaPose base Singularity container from source.
#
# This compiles AlphaPose from source and takes 30–60 minutes.
# The resulting alphapose-base.sif is pushed to GHCR and used as the
# foundation for the lightweight alphapose.sif (see build_container.sh).
#
# Only needs to be re-run if the AlphaPose source, CUDA base image, or
# core Python dependencies change.
#
# Usage:
#   bash scripts/build_base_container.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose-base.sif"
DEF="$REPO_DIR/alphapose-base.def"

echo "=== AlphaPose base container build ==="

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
echo "Tip: If the build fails repeatedly, leftover /tmp/build-temp-* directories"
echo "from previous attempts may have exhausted disk space. Check with:"
echo "  du -sh /tmp/build-temp-*"
echo "and remove any stale directories before retrying."
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
echo ""
echo "Next step: push the base image to GHCR so it can be used as a build base:"
echo "  bash scripts/push_to_ghcr.sh"
