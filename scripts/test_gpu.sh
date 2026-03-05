#!/usr/bin/env bash
# Test GPU access inside the AlphaPose Singularity container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SIF="$REPO_DIR/alphapose.sif"

if [ ! -f "$SIF" ]; then
    echo "ERROR: Container not found: $SIF"
    echo "Build it first: bash scripts/build_container.sh"
    exit 1
fi

echo "=== Testing GPU access in container ==="
echo ""

# Try apptainer first, fall back to singularity
if command -v apptainer &>/dev/null; then
    RUN_CMD="apptainer exec --nv"
elif command -v singularity &>/dev/null; then
    RUN_CMD="singularity exec --nv"
else
    echo "ERROR: Neither apptainer nor singularity found in PATH."
    exit 1
fi

echo "--- nvidia-smi ---"
$RUN_CMD "$SIF" nvidia-smi || echo "WARNING: nvidia-smi not available (GPU driver issue?)"

echo ""
echo "--- PyTorch CUDA check ---"
$RUN_CMD "$SIF" python -c "
import torch
print('PyTorch version:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('CUDA version:', torch.version.cuda)
    print('GPU count:', torch.cuda.device_count())
    for i in range(torch.cuda.device_count()):
        print(f'  GPU {i}:', torch.cuda.get_device_name(i))
else:
    print('WARNING: CUDA not available. Check GPU drivers and --nv flag.')
"

echo ""
echo "=== GPU test complete ==="
