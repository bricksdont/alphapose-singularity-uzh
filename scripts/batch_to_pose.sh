#!/usr/bin/env bash
# Process a folder of videos through AlphaPose and convert to .pose format.
#
# AlphaPose is run on the whole input directory at once (model loads once).
# JSON keypoints are written to a temporary directory and deleted after
# conversion. Output is one .pose file per input video.
#
# Usage:
#   bash scripts/batch_to_pose.sh <input_dir> <output_dir> [options]
#
# Options:
#   --keypoints 136|133  Number of keypoints (default: 136)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose.sif"
VENV_DIR="$REPO_DIR/venv"

# Defaults
KEYPOINTS="136"

# Parse args
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keypoints)  KEYPOINTS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash scripts/batch_to_pose.sh <input_dir> <output_dir> [--keypoints 136|133]"
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [ ${#POSITIONAL[@]} -lt 2 ]; then
    echo "Usage: bash scripts/batch_to_pose.sh <input_dir> <output_dir> [--keypoints 136|133]"
    exit 1
fi

INPUT_DIR="$(realpath "${POSITIONAL[0]}")"
OUTPUT_DIR="$(realpath -m "${POSITIONAL[1]}")"

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

if [ ! -f "$SIF" ]; then
    echo "ERROR: Container not found: $SIF"
    echo "Build it first: bash scripts/build_container.sh"
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo "ERROR: Virtual environment not found: $VENV_DIR"
    echo "Run: bash scripts/setup_venv.sh"
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
mkdir -p "$OUTPUT_DIR"
source "$VENV_DIR/bin/activate"

echo "=== AlphaPose batch processing ==="
echo "Input:     $INPUT_DIR ($TOTAL video(s))"
echo "Output:    $OUTPUT_DIR"
echo "Keypoints: $KEYPOINTS"
echo ""

# Step 1: Run AlphaPose on the whole directory (model loads once for all videos)
TEMP_JSON="$(mktemp -d)"
trap 'rm -rf "$TEMP_JSON"' EXIT

echo "--- Step 1/2: Running AlphaPose ---"
bash "$SCRIPT_DIR/run_alphapose_api.sh" \
    --video "$INPUT_DIR" \
    --outdir "$TEMP_JSON" \
    --keypoints "$KEYPOINTS"
echo ""

# Step 2: Convert each JSON to .pose
echo "--- Step 2/2: Converting to .pose ---"
SUCCESS=0
FAILED=0
FAILED_FILES=()

for VIDEO_FILE in "${VIDEO_FILES[@]}"; do
    BASENAME="$(basename "${VIDEO_FILE%.*}")"
    JSON_FILE="$TEMP_JSON/${BASENAME}.json"
    POSE_FILE="$OUTPUT_DIR/${BASENAME}.pose"

    echo "  $(basename "$VIDEO_FILE") -> $(basename "$POSE_FILE")"

    if [ ! -f "$JSON_FILE" ]; then
        echo "  ERROR: JSON not found for $(basename "$VIDEO_FILE")"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$(basename "$VIDEO_FILE")")
        continue
    fi

    if bash "$SCRIPT_DIR/convert_to_pose.sh" \
            -i "$JSON_FILE" \
            -o "$POSE_FILE" \
            --original-video "$VIDEO_FILE"; then
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ERROR: Conversion failed for $(basename "$VIDEO_FILE")"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$(basename "$VIDEO_FILE")")
    fi
done

echo ""
echo "=== Done: $SUCCESS succeeded, $FAILED failed ==="

if [ $FAILED -gt 0 ]; then
    echo "Failed files:"
    for f in "${FAILED_FILES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
