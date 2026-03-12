#!/usr/bin/bash -l
#SBATCH --job-name=alphapose_build
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=slurm_build_%j.out

# Build (or pull) the AlphaPose container as a SLURM job.
# By default, tries to pull the pre-built image from GHCR first;
# falls back to building from source if the pull fails.
#
# Usage:
#   sbatch scripts/slurm_build_container.sh [--force-rebuild]
#
# Options:
#   --force-rebuild   Skip the GHCR pull and always build from source

set -euo pipefail

FORCE_REBUILD=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force-rebuild) FORCE_REBUILD=1; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# SLURM copies job scripts to a temp directory; use SLURM_SUBMIT_DIR for paths.
SCRIPT_DIR="$SLURM_SUBMIT_DIR/scripts"
SIF="$SLURM_SUBMIT_DIR/alphapose.sif"
GHCR_URI="oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest"

echo "=== AlphaPose container setup ==="
echo "Node: $(hostname)"
echo "SIF:  $SIF"
echo ""

module load apptainer

if [ "$FORCE_REBUILD" -eq 1 ]; then
    echo "--force-rebuild: skipping GHCR pull, building from source."
    echo ""
    rm -f "$SIF"
    bash "$SCRIPT_DIR/build_container.sh"
elif [ -f "$SIF" ]; then
    echo "Container already exists: $SIF"
    echo "Nothing to do. Use --force-rebuild to overwrite."
else
    echo "Attempting to pull from GHCR..."
    echo "URI: $GHCR_URI"
    echo ""
    if apptainer pull "$SIF" "$GHCR_URI"; then
        echo ""
        echo "=== Pull complete: $SIF ==="
    else
        echo ""
        echo "Pull failed. Removing any partial file and building from source..."
        rm -f "$SIF"
        echo ""
        bash "$SCRIPT_DIR/build_container.sh"
    fi
fi
