#!/usr/bin/env bash
# Download a sample video for testing AlphaPose.
# Uses a short public domain video clip suitable for pose estimation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INPUT_DIR="$REPO_DIR/data/input"

mkdir -p "$INPUT_DIR"

OUTPUT="$INPUT_DIR/test.mp4"

if [ -f "$OUTPUT" ]; then
    echo "Test video already exists: $OUTPUT"
    exit 0
fi

echo "=== Downloading test video ==="

# Sign language video used as test input in openpose-singularity-uzh
VIDEO_URL="https://www.sgb-fss.ch/signsuisse/fileadmin/signsuisse_ressources/videos/262C81F5-FB9D-759D-08E1CB201ADEB239.mp4"

if command -v wget &>/dev/null; then
    wget -O "$OUTPUT" "$VIDEO_URL"
elif command -v curl &>/dev/null; then
    curl -L -o "$OUTPUT" "$VIDEO_URL"
else
    echo "ERROR: Neither wget nor curl found."
    exit 1
fi

echo ""
echo "Test video saved to: $OUTPUT"
echo ""

# Show basic info if ffprobe is available
if command -v ffprobe &>/dev/null; then
    echo "Video info:"
    ffprobe -v quiet -print_format json -show_streams "$OUTPUT" 2>/dev/null | \
        python3 -c "
import json, sys
d = json.load(sys.stdin)
for s in d.get('streams', []):
    if s.get('codec_type') == 'video':
        print(f'  Resolution: {s[\"width\"]}x{s[\"height\"]}')
        print(f'  Duration:   {float(s.get(\"duration\", 0)):.1f}s')
        print(f'  FPS:        {s.get(\"r_frame_rate\", \"unknown\")}')
" 2>/dev/null || true
fi
