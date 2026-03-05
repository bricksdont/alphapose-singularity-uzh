#!/usr/bin/env bash
# Submit parallel SLURM jobs for batch AlphaPose processing.
# Videos in the input directory are split into chunks and each chunk
# is processed by a separate SLURM job.
#
# Usage:
#   bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]
#
# Options:
#   --chunk-size N       Videos per job (default: 5)
#   --keypoints 136|133  Keypoints (default: 136)
#   --track              Enable pose tracking
#   --partition <name>   SLURM partition (default: gpu)
#   --time <HH:MM:SS>    Time limit per job (default: 04:00:00)
#   --mem <MB>           Memory per job (default: 32000)
#   --cpus N             CPUs per job (default: 4)
#   --gres <spec>        GPU resource spec (default: gpu:1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
INPUT_DIR=""
OUTPUT_DIR=""
CHUNK_SIZE=5
KEYPOINTS="136"
TRACK_FLAG=""
PARTITION="gpu"
TIME_LIMIT="04:00:00"
MEM="32000"
CPUS=4
GRES="gpu:1"

# Parse args
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --chunk-size)   CHUNK_SIZE="$2"; shift 2 ;;
        --keypoints)    KEYPOINTS="$2"; shift 2 ;;
        --track)        TRACK_FLAG="--track"; shift ;;
        --partition)    PARTITION="$2"; shift 2 ;;
        --time)         TIME_LIMIT="$2"; shift 2 ;;
        --mem)          MEM="$2"; shift 2 ;;
        --cpus)         CPUS="$2"; shift 2 ;;
        --gres)         GRES="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]"
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [ ${#POSITIONAL[@]} -lt 2 ]; then
    echo "ERROR: input_dir and output_dir required."
    exit 1
fi

INPUT_DIR="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]}"

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Find videos
mapfile -t VIDEOS < <(find "$INPUT_DIR" -maxdepth 1 -type f \( \
    -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \
\) | sort)

if [ ${#VIDEOS[@]} -eq 0 ]; then
    echo "No videos found in: $INPUT_DIR"
    exit 0
fi

echo "=== SLURM batch submission ==="
echo "Videos:     ${#VIDEOS[@]}"
echo "Chunk size: $CHUNK_SIZE"
echo "Partition:  $PARTITION"
echo ""

LOGS_DIR="$REPO_DIR/logs"
CHUNKS_DIR="$REPO_DIR/data/chunks"
mkdir -p "$LOGS_DIR" "$CHUNKS_DIR"

# Split videos into chunks
CHUNK_IDX=0
CHUNK_FILE=""
JOB_IDS=()

for i in "${!VIDEOS[@]}"; do
    if (( i % CHUNK_SIZE == 0 )); then
        CHUNK_IDX=$(( i / CHUNK_SIZE ))
        CHUNK_FILE="$CHUNKS_DIR/chunk_${CHUNK_IDX}.txt"
        > "$CHUNK_FILE"
    fi
    echo "${VIDEOS[$i]}" >> "$CHUNK_FILE"
done

TOTAL_CHUNKS=$(( (${#VIDEOS[@]} + CHUNK_SIZE - 1) / CHUNK_SIZE ))
echo "Submitting $TOTAL_CHUNKS jobs..."
echo ""

for (( c=0; c<TOTAL_CHUNKS; c++ )); do
    CHUNK_FILE="$CHUNKS_DIR/chunk_${c}.txt"

    JOB_ID=$(sbatch \
        --partition="$PARTITION" \
        --time="$TIME_LIMIT" \
        --mem="$MEM" \
        --cpus-per-task="$CPUS" \
        --gres="$GRES" \
        --output="$LOGS_DIR/alphapose_chunk${c}_%j.out" \
        --error="$LOGS_DIR/alphapose_chunk${c}_%j.err" \
        --job-name="alphapose_c${c}" \
        "$SCRIPT_DIR/slurm_job.sh" \
            "$CHUNK_FILE" \
            "$OUTPUT_DIR" \
            "$KEYPOINTS" \
            "$TRACK_FLAG" \
        | awk '{print $NF}')

    echo "  Submitted chunk $c: job $JOB_ID ($(wc -l < "$CHUNK_FILE") videos)"
    JOB_IDS+=("$JOB_ID")
done

echo ""
echo "=== All jobs submitted ==="
echo "Job IDs: ${JOB_IDS[*]}"
echo ""
echo "Monitor with:"
echo "  squeue -u $USER"
echo "  tail -f $LOGS_DIR/alphapose_chunk0_*.out"
