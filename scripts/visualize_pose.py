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
    return parser.parse_args()


def main():
    args = parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"ERROR: Input .pose file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Loading .pose file: {input_path}")

    try:
        from pose_format import Pose
    except ImportError as e:
        print(f"ERROR: Could not import pose_format: {e}", file=sys.stderr)
        print("Install dependencies: bash scripts/setup_venv.sh", file=sys.stderr)
        sys.exit(1)

    with open(input_path, "rb") as f:
        pose = Pose.read(f.read())

    print(f"Pose loaded: {pose.body.data.shape}")

    # Load background video frames if provided
    background = None
    if args.video:
        video_path = Path(args.video)
        if video_path.exists():
            try:
                import cv2
                cap = cv2.VideoCapture(str(video_path))
                frames = []
                while True:
                    ret, frame = cap.read()
                    if not ret:
                        break
                    frames.append(frame)
                cap.release()
                background = frames
                print(f"Background video loaded: {len(frames)} frames")
            except ImportError:
                print("WARNING: OpenCV not available, rendering without background.", file=sys.stderr)
        else:
            print(f"WARNING: Video not found: {video_path}", file=sys.stderr)

    print("Rendering visualization...")

    try:
        from pose_format.utils.generic import pose_normalization_info, correct_wrists, reduce_holistic
        import numpy as np
        import cv2

        fps = pose.body.fps
        num_frames = pose.body.data.shape[0]
        height = pose.header.dimensions.height
        width = pose.header.dimensions.width

        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(str(output_path), fourcc, fps, (width, height))

        for frame_idx in range(num_frames):
            # Start from background or blank frame
            if background and frame_idx < len(background):
                frame = background[frame_idx].copy()
                frame = cv2.resize(frame, (width, height))
            else:
                frame = np.zeros((height, width, 3), dtype=np.uint8)

            # Draw keypoints
            frame_data = pose.body.data[frame_idx]  # (people, points, dims)
            frame_conf = pose.body.confidence[frame_idx]  # (people, points)

            for person_idx in range(frame_data.shape[0]):
                for pt_idx in range(frame_data.shape[1]):
                    conf = float(frame_conf[person_idx, pt_idx])
                    if conf < 0.1:
                        continue
                    x = int(frame_data[person_idx, pt_idx, 0])
                    y = int(frame_data[person_idx, pt_idx, 1])
                    if 0 <= x < width and 0 <= y < height:
                        cv2.circle(frame, (x, y), 3, (0, 255, 0), -1)

            writer.write(frame)

        writer.release()

    except Exception as e:
        print(f"ERROR during rendering: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

    print(f"Done. Output: {output_path}")


if __name__ == "__main__":
    main()
