#!/usr/bin/env bash
# Create Python virtual environment and install dependencies.
# Provides gdown (for model download) and post-processing tools (pose-format).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$REPO_DIR/venv"

echo "=== Setting up Python virtual environment ==="
echo "Location: $VENV_DIR"
echo ""

if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists: $VENV_DIR"
    echo "To reinstall, delete it first: rm -rf $VENV_DIR"
    exit 0
fi

# Check Python 3
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found in PATH."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1)
echo "Using: $PYTHON_VERSION"
echo ""

# Create venv
python3 -m venv "$VENV_DIR"

# Activate and install
source "$VENV_DIR/bin/activate"

echo "Upgrading pip..."
pip install --upgrade pip

echo ""
echo "Installing requirements from requirements.txt..."
pip install -r "$REPO_DIR/requirements.txt"

echo ""
echo "=== Virtual environment ready ==="
echo ""
echo "Activate with:"
echo "  source venv/bin/activate"
