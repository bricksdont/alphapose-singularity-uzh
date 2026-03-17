#!/usr/bin/env bash
# Push the AlphaPose Singularity image to GitHub Container Registry (GHCR).
#
# Prerequisites:
#   1. Create a GitHub Personal Access Token (PAT) with write:packages scope:
#      https://github.com/settings/tokens
#   2. Export it: export GITHUB_TOKEN=<your_token>
#
# Usage:
#   bash scripts/push_to_ghcr.sh [--tag <tag>] [--user <github_username>] [--repo <repo_name>]
#
# Defaults:
#   --tag   latest
#   --user  bricksdont
#   --repo  alphapose-singularity-uzh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose.sif"

# Defaults
TAG="latest"
GITHUB_USER="bricksdont"
REPO_NAME="alphapose-singularity-uzh"
IMAGE_NAME="alphapose"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)   TAG="$2"; shift 2 ;;
        --user)  GITHUB_USER="$2"; shift 2 ;;
        --repo)  REPO_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash scripts/push_to_ghcr.sh [--tag <tag>] [--user <github_username>] [--repo <repo_name>]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

REGISTRY="oras://ghcr.io/${GITHUB_USER}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"

if [ ! -f "$SIF" ]; then
    echo "ERROR: Container not found: $SIF"
    echo "Build it first: bash scripts/build_container.sh"
    exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "ERROR: GITHUB_TOKEN is not set."
    echo ""
    echo "Create a token at: https://github.com/settings/tokens"
    echo "Required scope: write:packages"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN=<your_token>"
    echo "  bash scripts/push_to_ghcr.sh"
    exit 1
fi

# Try apptainer first, fall back to singularity
if command -v apptainer &>/dev/null; then
    SIF_CMD="apptainer"
elif command -v singularity &>/dev/null; then
    SIF_CMD="singularity"
else
    echo "ERROR: Neither apptainer nor singularity found in PATH."
    exit 1
fi

echo "=== Pushing AlphaPose image to GHCR ==="
echo "Image:    $SIF"
echo "Target:   $REGISTRY"
echo ""

# Authenticate
echo "Authenticating with ghcr.io..."
echo "$GITHUB_TOKEN" | $SIF_CMD registry login \
    --username "$GITHUB_USER" \
    --password-stdin \
    oras://ghcr.io

echo ""
echo "Pushing (this may take a while for a large image)..."
$SIF_CMD push "$SIF" "$REGISTRY"

echo ""
echo "=== Push complete ==="
echo ""
echo "Pull with:"
echo "  singularity pull $REGISTRY"
echo ""
echo "NOTE: If this is a first-time push, the package will be private by default."
echo "To make it public (if not already done), go to:"
echo "  https://github.com/users/${GITHUB_USER}/packages/container/${REPO_NAME}%2F${IMAGE_NAME}/settings"
