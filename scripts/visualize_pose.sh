#!/usr/bin/env bash
# Wrapper: Render .pose file as annotated video using the Python venv.
#
# Usage:
#   bash scripts/visualize_pose.sh \
#       -i data/output/result.pose \
#       -o data/output/result_viz.mp4 \
#       [--video data/input/original.mp4]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PYTHON="$REPO_DIR/venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "ERROR: Virtual environment not found."
    echo "Run: bash scripts/setup_venv.sh"
    exit 1
fi

exec "$VENV_PYTHON" "$SCRIPT_DIR/visualize_pose.py" "$@"
