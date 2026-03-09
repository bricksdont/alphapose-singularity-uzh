#!/usr/bin/env bash
# Build the AlphaPose Singularity container from the base image on GHCR.
#
# This is fast (~2 minutes) — it pulls the pre-built alphapose-base image
# from GHCR and adds any extra Python dependencies defined in alphapose.def.
#
# Prerequisites:
#   - alphapose-base image must be available on GHCR (pushed via push_to_ghcr.sh)
#   - Apptainer ≥ 1.1 or Singularity with ORAS support
#
# If the base image is not on GHCR yet, build it first:
#   bash scripts/build_base_container.sh
#   bash scripts/push_to_ghcr.sh
#
# Usage:
#   bash scripts/build_container.sh

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
echo "Base:   oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose-base:latest"
echo ""

cd "$REPO_DIR"
$BUILD_CMD "$SIF" "$DEF"

echo ""
echo "=== Build complete: $SIF ==="
