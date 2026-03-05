#!/usr/bin/env python3
"""
Convert AlphaPose JSON output to .pose format using pose-format library.

Usage:
    python scripts/convert_to_pose.py \
        -i data/output/keypoints/alphapose-results.json \
        -o data/output/result.pose \
        [--original-video data/input/video.mp4]
"""

import argparse
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert AlphaPose JSON to .pose format"
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Path to AlphaPose JSON output file"
    )
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Path to output .pose file"
    )
    parser.add_argument(
        "--original-video",
        default=None,
        help="Path to original video (optional; used for fps/resolution metadata)"
    )
    return parser.parse_args()


def get_video_metadata(video_path):
    """Extract fps and resolution from video file using OpenCV."""
    try:
        import cv2
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            print(f"WARNING: Could not open video: {video_path}", file=sys.stderr)
            return None, None, None
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()
        return fps, width, height
    except ImportError:
        print("WARNING: OpenCV not available, skipping video metadata.", file=sys.stderr)
        return None, None, None


def main():
    args = parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Get video metadata if provided
    fps = None
    if args.original_video:
        video_path = Path(args.original_video)
        if video_path.exists():
            fps, width, height = get_video_metadata(video_path)
            if fps:
                print(f"Video metadata: {width}x{height} @ {fps:.2f} fps")
        else:
            print(f"WARNING: Video not found: {video_path}", file=sys.stderr)

    print(f"Loading AlphaPose JSON: {input_path}")

    try:
        from pose_format.utils.alphapose import load_alphapose_wholebody_from_json
    except ImportError as e:
        print(f"ERROR: Could not import pose_format: {e}", file=sys.stderr)
        print("Install dependencies: bash scripts/setup_venv.sh", file=sys.stderr)
        sys.exit(1)

    with open(input_path, "r") as f:
        import json
        data = json.load(f)

    print("Converting to pose format...")

    pose = load_alphapose_wholebody_from_json(data, fps=fps)

    print(f"Writing .pose file: {output_path}")

    with open(output_path, "wb") as f:
        pose.write(f)

    print(f"Done. Output: {output_path}")


if __name__ == "__main__":
    main()
