#!/usr/bin/env bash
# Process a folder of videos end-to-end:
#   1. Run AlphaPose (→ JSON keypoints)
#   2. Convert JSON to .pose format
#
# Usage:
#   bash scripts/batch_to_pose.sh <input_dir> <output_dir> [--keypoints 136|133] [--track]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
INPUT_DIR=""
OUTPUT_DIR=""
KEYPOINTS="136"
TRACK_FLAG=""

# Parse positional + optional args
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keypoints)
            KEYPOINTS="$2"
            shift 2
            ;;
        --track)
            TRACK_FLAG="--track"
            shift
            ;;
        -h|--help)
            echo "Usage: bash scripts/batch_to_pose.sh <input_dir> <output_dir> [--keypoints 136|133] [--track]"
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
    echo "Usage: bash scripts/batch_to_pose.sh <input_dir> <output_dir>"
    exit 1
fi

INPUT_DIR="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]}"

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Find all video files
mapfile -t VIDEOS < <(find "$INPUT_DIR" -maxdepth 1 -type f \( \
    -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \
\) | sort)

if [ ${#VIDEOS[@]} -eq 0 ]; then
    echo "No video files found in: $INPUT_DIR"
    exit 0
fi

echo "=== Batch AlphaPose processing ==="
echo "Input dir:  $INPUT_DIR"
echo "Output dir: $OUTPUT_DIR"
echo "Keypoints:  $KEYPOINTS"
echo "Videos:     ${#VIDEOS[@]}"
echo ""

FAILED=()

for VIDEO in "${VIDEOS[@]}"; do
    BASENAME="$(basename "$VIDEO" | sed 's/\.[^.]*$//')"
    VIDEO_OUT_DIR="$OUTPUT_DIR/$BASENAME"
    KEYPOINTS_DIR="$VIDEO_OUT_DIR/keypoints"
    POSE_FILE="$VIDEO_OUT_DIR/${BASENAME}.pose"

    echo "--- Processing: $BASENAME ---"
    mkdir -p "$KEYPOINTS_DIR"

    # Step 1: Run AlphaPose
    echo "  [1/2] Running AlphaPose..."
    if ! bash "$SCRIPT_DIR/run_alphapose.sh" \
            --video "$VIDEO" \
            --keypoints "$KEYPOINTS" \
            --outdir "$KEYPOINTS_DIR" \
            $TRACK_FLAG; then
        echo "  ERROR: AlphaPose failed for $BASENAME"
        FAILED+=("$BASENAME")
        continue
    fi

    # Find the AlphaPose JSON output
    JSON_FILE=$(find "$KEYPOINTS_DIR" -name "alphapose-results.json" | head -1)
    if [ -z "$JSON_FILE" ]; then
        echo "  ERROR: No alphapose-results.json found in $KEYPOINTS_DIR"
        FAILED+=("$BASENAME")
        continue
    fi

    # Step 2: Convert to .pose
    echo "  [2/2] Converting to .pose..."
    if ! bash "$SCRIPT_DIR/convert_to_pose.sh" \
            -i "$JSON_FILE" \
            -o "$POSE_FILE" \
            --original-video "$VIDEO"; then
        echo "  ERROR: Conversion failed for $BASENAME"
        FAILED+=("$BASENAME")
        continue
    fi

    echo "  Done: $POSE_FILE"
    echo ""
done

echo "=== Batch processing complete ==="
echo "Processed: $((${#VIDEOS[@]} - ${#FAILED[@]})) / ${#VIDEOS[@]}"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "Failed videos:"
    for name in "${FAILED[@]}"; do
        echo "  - $name"
    done
    exit 1
fi
