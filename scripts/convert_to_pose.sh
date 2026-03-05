#!/usr/bin/env bash
# Wrapper: Convert AlphaPose JSON to .pose format using the Python venv.
#
# Usage:
#   bash scripts/convert_to_pose.sh \
#       -i data/output/keypoints/alphapose-results.json \
#       -o data/output/result.pose \
#       [--original-video data/input/video.mp4]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PYTHON="$REPO_DIR/venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "ERROR: Virtual environment not found."
    echo "Run: bash scripts/setup_venv.sh"
    exit 1
fi

exec "$VENV_PYTHON" "$SCRIPT_DIR/convert_to_pose.py" "$@"
