#!/usr/bin/env bash
# Run AlphaPose pose estimation on a single video.
#
# Usage:
#   bash scripts/run_alphapose.sh --video <path/to/video.mp4> [options]
#
# Options:
#   --video <path>       Path to input video (required)
#   --keypoints 136|133  Number of keypoints (default: 136)
#   --track              Enable pose tracking (--pose_track)
#   --outdir <path>      Output directory (default: data/output/keypoints)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose.sif"

# Defaults
VIDEO=""
KEYPOINTS="136"
TRACK=0
OUTDIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --video)
            VIDEO="$2"
            shift 2
            ;;
        --keypoints)
            KEYPOINTS="$2"
            shift 2
            ;;
        --track)
            TRACK=1
            shift
            ;;
        --outdir)
            OUTDIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: bash scripts/run_alphapose.sh --video <path> [--keypoints 136|133] [--track] [--outdir <path>]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$VIDEO" ]; then
    echo "ERROR: --video is required."
    echo "Usage: bash scripts/run_alphapose.sh --video <path/to/video.mp4>"
    exit 1
fi

if [ ! -f "$VIDEO" ]; then
    echo "ERROR: Video file not found: $VIDEO"
    exit 1
fi

if [ ! -f "$SIF" ]; then
    echo "ERROR: Container not found: $SIF"
    echo "Build it first: bash scripts/build_container.sh"
    exit 1
fi

# Set output directory
if [ -z "$OUTDIR" ]; then
    OUTDIR="$REPO_DIR/data/output/keypoints"
fi
mkdir -p "$OUTDIR"

# Select model config and checkpoint based on keypoints
case "$KEYPOINTS" in
    136)
        CFG="configs/halpe_coco_wholebody_136/resnet/256x192_res50_lr1e-3_2x-dcn-combined.yaml"
        MODEL="multi_domain_fast50_dcn_combined_256x192"
        ;;
    133)
        CFG="configs/coco_wholebody/resnet/256x192_res50_lr1e-3_2x-dcn-combined.yaml"
        MODEL="wholebody133_dcn_combined"
        ;;
    *)
        echo "ERROR: --keypoints must be 136 or 133 (got: $KEYPOINTS)"
        exit 1
        ;;
esac

# Check model files exist
YOLO_WEIGHTS="$REPO_DIR/data/models/yolov3-spp.weights"
POSE_WEIGHTS="$REPO_DIR/data/models/pretrained_models/${MODEL}.pth"

if [ ! -f "$YOLO_WEIGHTS" ]; then
    echo "ERROR: YOLO weights not found: $YOLO_WEIGHTS"
    echo "Run: bash scripts/download_models.sh"
    exit 1
fi

if [ ! -f "$POSE_WEIGHTS" ]; then
    echo "ERROR: Pose model not found: $POSE_WEIGHTS"
    echo "Run: bash scripts/download_models.sh"
    exit 1
fi

# Resolve absolute paths for bind mounts
VIDEO_ABS="$(realpath "$VIDEO")"
VIDEO_DIR="$(dirname "$VIDEO_ABS")"
VIDEO_NAME="$(basename "$VIDEO_ABS")"
OUTDIR_ABS="$(realpath "$OUTDIR")"

echo "=== Running AlphaPose ==="
echo "Video:     $VIDEO_ABS"
echo "Keypoints: $KEYPOINTS"
echo "Config:    $CFG"
echo "Model:     $MODEL"
echo "Outdir:    $OUTDIR_ABS"
echo ""

# Build optional args
EXTRA_ARGS=""
if [ "$TRACK" -eq 1 ]; then
    EXTRA_ARGS="$EXTRA_ARGS --pose_track"
fi

# Try apptainer first, fall back to singularity
if command -v apptainer &>/dev/null; then
    SIF_CMD="apptainer run --nv"
elif command -v singularity &>/dev/null; then
    SIF_CMD="singularity run --nv"
else
    echo "ERROR: Neither apptainer nor singularity found in PATH."
    exit 1
fi

$SIF_CMD \
    --env "LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLdispatch.so.0:/usr/lib/x86_64-linux-gnu/libGLX.so.0:/usr/lib/x86_64-linux-gnu/libGL.so.1" \
    --bind "$SCRIPT_DIR/sitecustomize.py":/opt/conda/lib/python3.10/site-packages/sitecustomize.py \
    --bind "$VIDEO_DIR":/input \
    --bind "$OUTDIR_ABS":/output \
    --bind "$YOLO_WEIGHTS":/opt/alphapose/detector/yolo/data/yolov3-spp.weights \
    --bind "$REPO_DIR/data/models/pretrained_models":/opt/alphapose/pretrained_models \
    "$SIF" \
    --cfg /opt/alphapose/"$CFG" \
    --checkpoint /opt/alphapose/pretrained_models/"${MODEL}".pth \
    --video /input/"$VIDEO_NAME" \
    --outdir /output \
    --format coco \
    --save_video \
    --gpus 0 \
    $EXTRA_ARGS

echo ""
echo "=== AlphaPose complete ==="
echo "Output: $OUTDIR_ABS"
echo ""
ls -lh "$OUTDIR_ABS/" 2>/dev/null || true
