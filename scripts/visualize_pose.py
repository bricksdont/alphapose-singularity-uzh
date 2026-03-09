#!/usr/bin/env python3
"""
Render a .pose file as an annotated video using pose-format visualization utilities.

Usage:
    python scripts/visualize_pose.py \
        -i data/output/result.pose \
        -o data/output/result_viz.mp4 \
        [--video data/input/original.mp4]
"""

import argparse
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Visualize .pose file as annotated video"
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Path to input .pose file"
    )
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Path to output video file (.mp4)"
    )
    parser.add_argument(
        "--video",
        default=None,
        help="Path to original video (optional; used as background)"
    )
    parser.add_argument(
        "--hide-legs",
        action="store_true",
        default=False,
        help="Zero out leg keypoints before rendering"
    )
    parser.add_argument(
        "--thickness",
        type=int,
        default=1,
        help="Line/point thickness for skeleton rendering (default: 1)"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"ERROR: Input .pose file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        import cv2
        from pose_format import Pose
        from pose_format.pose_visualizer import PoseVisualizer
        from pose_format.utils.generic import pose_hide_legs
    except ImportError as e:
        print(f"ERROR: Could not import required library: {e}", file=sys.stderr)
        print("Install dependencies: bash scripts/setup_venv.sh", file=sys.stderr)
        sys.exit(1)

    print(f"Loading .pose file: {input_path}")
    with open(input_path, "rb") as f:
        pose = Pose.read(f.read())

    # The pose-format library truncates FPS to int, but the visualizer
    # requires an exact match with the video FPS. Patch to match the video.
    if args.video:
        video_path = Path(args.video)
        if not video_path.exists():
            print(f"WARNING: Video not found: {video_path}", file=sys.stderr)
            args.video = None
        else:
            cap = cv2.VideoCapture(str(video_path))
            video_fps = cap.get(cv2.CAP_PROP_FPS)
            cap.release()
            pose.body.fps = video_fps

    if args.hide_legs:
        pose = pose_hide_legs(pose)

    print("Rendering visualization...")
    v = PoseVisualizer(pose, thickness=args.thickness)

    if args.video:
        frames = v.draw_on_video(args.video)
    else:
        frames = v.draw()

    v.save_video(str(output_path), frames)

    print(f"Done. Output: {output_path}")


if __name__ == "__main__":
    main()
