#!/usr/bin/env bash
# Single SLURM job script: processes a chunk of videos via batch_to_pose.sh.
# Called by slurm_submit.sh — do not run directly.
#
# Arguments:
#   $1  chunk file (list of video paths, one per line)
#   $2  output directory
#   $3  keypoints (136 or 133)
#   $4  optional flags (e.g. "--track")

#SBATCH --job-name=alphapose
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32000
#SBATCH --time=04:00:00

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CHUNK_FILE="${1:?chunk file required}"
OUTPUT_DIR="${2:?output dir required}"
KEYPOINTS="${3:-136}"
EXTRA_FLAGS="${4:-}"

if [ ! -f "$CHUNK_FILE" ]; then
    echo "ERROR: Chunk file not found: $CHUNK_FILE"
    exit 1
fi

echo "=== SLURM AlphaPose job ==="
echo "Host:       $(hostname)"
echo "Job ID:     ${SLURM_JOB_ID:-local}"
echo "Chunk:      $CHUNK_FILE"
echo "Output:     $OUTPUT_DIR"
echo "Keypoints:  $KEYPOINTS"
echo "Date:       $(date)"
echo ""

FAILED=()

while IFS= read -r VIDEO; do
    [ -z "$VIDEO" ] && continue

    BASENAME="$(basename "$VIDEO" | sed 's/\.[^.]*$//')"
    VIDEO_OUT_DIR="$OUTPUT_DIR/$BASENAME"
    KEYPOINTS_DIR="$VIDEO_OUT_DIR/keypoints"
    POSE_FILE="$VIDEO_OUT_DIR/${BASENAME}.pose"

    echo "--- $BASENAME ---"
    mkdir -p "$KEYPOINTS_DIR"

    # Step 1: AlphaPose
    if ! bash "$SCRIPT_DIR/run_alphapose.sh" \
            --video "$VIDEO" \
            --keypoints "$KEYPOINTS" \
            --outdir "$KEYPOINTS_DIR" \
            $EXTRA_FLAGS; then
        echo "ERROR: AlphaPose failed: $BASENAME"
        FAILED+=("$BASENAME")
        continue
    fi

    # Step 2: Convert
    JSON_FILE=$(find "$KEYPOINTS_DIR" -name "alphapose-results.json" | head -1)
    if [ -z "$JSON_FILE" ]; then
        echo "ERROR: No JSON found for $BASENAME"
        FAILED+=("$BASENAME")
        continue
    fi

    if ! bash "$SCRIPT_DIR/convert_to_pose.sh" \
            -i "$JSON_FILE" \
            -o "$POSE_FILE" \
            --original-video "$VIDEO"; then
        echo "ERROR: Conversion failed: $BASENAME"
        FAILED+=("$BASENAME")
        continue
    fi

    echo "Done: $POSE_FILE"
done < "$CHUNK_FILE"

echo ""
echo "=== Job complete: $(date) ==="

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "FAILED: ${FAILED[*]}"
    exit 1
fi
