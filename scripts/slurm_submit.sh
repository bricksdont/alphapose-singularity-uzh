#!/usr/bin/env bash
# Submit parallel SLURM jobs for batch AlphaPose processing.
#
# Videos in the input directory are distributed across N chunks.
# Each chunk is processed by a separate GPU job via run_alphapose_api.sh,
# which loads the model once and processes all videos in the chunk.
#
# Usage:
#   bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]
#
# Options:
#   --chunks N           Number of parallel jobs (default: 1)
#   --keypoints 136|133  Keypoints (default: 136)
#   --partition <name>   SLURM partition (default: gpu)
#   --time <HH:MM:SS>    Time limit per job (default: 24:00:00)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
NUM_CHUNKS=1
KEYPOINTS="136"
PARTITION="gpu"
TIME_LIMIT="24:00:00"

# Parse args
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --chunks)     NUM_CHUNKS="$2"; shift 2 ;;
        --keypoints)  KEYPOINTS="$2"; shift 2 ;;
        --partition)  PARTITION="$2"; shift 2 ;;
        --time)       TIME_LIMIT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash scripts/slurm_submit.sh <input_dir> <output_dir> [--chunks N] [--keypoints 136|133] [--partition <name>] [--time <HH:MM:SS>]"
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [ ${#POSITIONAL[@]} -lt 2 ]; then
    echo "ERROR: input_dir and output_dir are required."
    echo "Usage: bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]"
    exit 1
fi

INPUT_DIR="$(realpath "${POSITIONAL[0]}")"
OUTPUT_DIR="$(realpath -m "${POSITIONAL[1]}")"

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

if ! command -v sbatch &>/dev/null; then
    echo "ERROR: sbatch not found. This script must be run on a SLURM cluster."
    exit 1
fi

# Collect video files
shopt -s nullglob
VIDEO_FILES=("$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mov "$INPUT_DIR"/*.mkv)
shopt -u nullglob

if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "ERROR: No video files (*.mp4, *.avi, *.mov, *.mkv) found in $INPUT_DIR"
    exit 1
fi

TOTAL=${#VIDEO_FILES[@]}

# Cap chunks to number of videos
if [ "$NUM_CHUNKS" -gt "$TOTAL" ]; then
    NUM_CHUNKS=$TOTAL
fi

echo "=== AlphaPose SLURM batch submission ==="
echo "Input:     $INPUT_DIR"
echo "Output:    $OUTPUT_DIR"
echo "Videos:    $TOTAL"
echo "Chunks:    $NUM_CHUNKS"
echo "Partition: $PARTITION"
echo "Time:      $TIME_LIMIT"
echo ""

# Create staging and log directories
STAGING_DIR="$OUTPUT_DIR/.slurm_chunks"
LOG_DIR="$OUTPUT_DIR/.slurm_logs"
mkdir -p "$LOG_DIR"

# Clean up any previous staging
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    mkdir -p "$STAGING_DIR/chunk_$i"
done

# Distribute videos round-robin via symlinks
IDX=0
for VIDEO_FILE in "${VIDEO_FILES[@]}"; do
    CHUNK=$((IDX % NUM_CHUNKS))
    ln -s "$VIDEO_FILE" "$STAGING_DIR/chunk_$CHUNK/$(basename "$VIDEO_FILE")"
    IDX=$((IDX + 1))
done

# Report distribution
for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    COUNT=$(find "$STAGING_DIR/chunk_$i" -type l | wc -l)
    echo "  Chunk $i: $COUNT video(s)"
done
echo ""

# Submit SLURM jobs
JOB_IDS=()
for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    CHUNK_DIR="$STAGING_DIR/chunk_$i"
    JOB_ID=$(sbatch \
        --partition="$PARTITION" \
        --time="$TIME_LIMIT" \
        --output="$LOG_DIR/job_%j.out" \
        --error="$LOG_DIR/job_%j.err" \
        --job-name="alphapose_$i" \
        "$SCRIPT_DIR/slurm_job.sh" "$CHUNK_DIR" "$OUTPUT_DIR" "$KEYPOINTS" \
        | grep -o '[0-9]*')
    JOB_IDS+=("$JOB_ID")
    echo "Submitted chunk $i -> SLURM job $JOB_ID"
done

echo ""
echo "=== All jobs submitted ==="
echo "Job IDs: ${JOB_IDS[*]}"
echo ""
echo "Monitor with:"
echo "  squeue -u \$USER"
echo "  tail -f $LOG_DIR/job_*.out"
