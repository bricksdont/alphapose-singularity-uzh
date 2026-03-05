#!/usr/bin/env bash
# Download AlphaPose model weights from Google Drive.
# Uses gdown (install via: pip install gdown, or use the venv).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$REPO_DIR/data/models"
PRETRAINED_DIR="$MODELS_DIR/pretrained_models"

mkdir -p "$MODELS_DIR" "$PRETRAINED_DIR"

# Resolve gdown: prefer venv, fall back to system
VENV_GDOWN="$REPO_DIR/venv/bin/gdown"
if [ -f "$VENV_GDOWN" ]; then
    GDOWN="$VENV_GDOWN"
elif command -v gdown &>/dev/null; then
    GDOWN="gdown"
else
    echo "ERROR: gdown not found. Install it with:"
    echo "  pip install gdown"
    echo "  or run: bash scripts/setup_venv.sh"
    exit 1
fi

echo "=== Downloading AlphaPose model weights ==="
echo "Destination: $MODELS_DIR"
echo ""

download_file() {
    local gdrive_id="$1"
    local dest="$2"
    local description="$3"

    if [ -f "$dest" ]; then
        echo "Already exists, skipping: $dest"
        return 0
    fi

    echo "Downloading: $description"
    echo "  -> $dest"

    if ! "$GDOWN" "https://drive.google.com/uc?id=${gdrive_id}" -O "$dest"; then
        echo ""
        echo "WARNING: gdown failed for: $description"
        echo "Manual download:"
        echo "  https://drive.google.com/file/d/${gdrive_id}"
        echo "  Save to: $dest"
        echo ""
        return 1
    fi
    echo "  Done."
    echo ""
}

# YOLOv3-SPP detector weights
download_file \
    "1D47msNOOiJKvPOXlnpyzdKA3k6E97NTC" \
    "$MODELS_DIR/yolov3-spp.weights" \
    "YOLOv3-SPP detector"

# 136-kpt Multi-domain DCN Combined (default, 49.8 AP, 10.35 iter/s)
download_file \
    "1wX1Z2ZOoysgSNovlgiEtJKpbR8tUBWYR" \
    "$PRETRAINED_DIR/multi_domain_fast50_dcn_combined_256x192.pth" \
    "136-kpt multi-domain DCN Combined (default)"

# 136-kpt Multi-domain Symmetric Integral (alternative, 50.1 AP, 16.28 iter/s)
download_file \
    "1Bb3kPoFFt-M0Y3ceqNO8DTXi1iNDd4gI" \
    "$PRETRAINED_DIR/multi_domain_fast50_regression_256x192.pth" \
    "136-kpt multi-domain Symmetric Integral (alternative)"

# 133-kpt COCO WholeBody DCN Combined
download_file \
    "1aP0nYujw32H-VoJBVsXS-DsBBY-UwI8Y" \
    "$PRETRAINED_DIR/wholebody133_dcn_combined.pth" \
    "133-kpt COCO WholeBody DCN Combined"

echo "=== Model download complete ==="
echo ""
echo "Models directory:"
find "$MODELS_DIR" -type f | sort
