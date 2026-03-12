#!/usr/bin/bash -l
# Single SLURM job: process a chunk of videos end-to-end via batch_to_pose.sh.
# Called by slurm_submit.sh — do not run directly.
#
# Arguments:
#   $1  chunk directory (symlinks to video files)
#   $2  output directory (.pose files written here)
#   $3  keypoints (136 or 133, default: 136)

#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=24:00:00

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHUNK_DIR="${1:?chunk dir required}"
OUTPUT_DIR="${2:?output dir required}"
KEYPOINTS="${3:-136}"

echo "=== SLURM AlphaPose job ==="
echo "Host:      $(hostname)"
echo "Job ID:    ${SLURM_JOB_ID:-local}"
echo "GPU:       $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'unknown')"
echo "Chunk dir: $CHUNK_DIR"
echo "Output:    $OUTPUT_DIR"
echo "Keypoints: $KEYPOINTS"
echo "Date:      $(date)"
echo ""

module load apptainer

bash "$SCRIPT_DIR/batch_to_pose.sh" \
    "$CHUNK_DIR" \
    "$OUTPUT_DIR" \
    --keypoints "$KEYPOINTS"

# Clean up chunk dir (contains only symlinks)
rm -rf "$CHUNK_DIR"
echo "Cleaned up chunk dir: $CHUNK_DIR"

echo ""
echo "=== Job complete: $(date) ==="
