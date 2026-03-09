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

# Check available disk space — build needs ~35 GB free (uncompressed sandbox
# can be 3-4x the final .sif size of ~9 GB)
AVAIL_GB=$(df --output=avail -BG "$REPO_DIR" | tail -1 | tr -d 'G ')
REQUIRED_GB=35
if [ "$AVAIL_GB" -lt "$REQUIRED_GB" ]; then
    echo "WARNING: Only ${AVAIL_GB} GB free on the filesystem containing $REPO_DIR."
    echo "         The build needs at least ${REQUIRED_GB} GB. It may fail at the"
    echo "         final squashfs step. Consider freeing space first."
    echo "         Leftover /tmp/build-temp-* directories from previous failed"
    echo "         builds are a common culprit:"
    echo "           du -sh /tmp/build-temp-* 2>/dev/null"
    echo "           rm -rf /tmp/build-temp-*"
    echo ""
else
    echo "Disk space: ${AVAIL_GB} GB available (need ~${REQUIRED_GB} GB) — OK"
    echo ""
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
echo ""

cd "$REPO_DIR"
$BUILD_CMD "$SIF" "$DEF"

echo ""
echo "=== Build complete: $SIF ==="
echo ""
echo "Next step: push the base image to GHCR so it can be used as a build base:"
echo "  bash scripts/push_to_ghcr.sh"
