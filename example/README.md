# Example

This folder contains example input and output for the full pipeline run on a short sign language video.

## Input

See [`input/README.md`](input/README.md) for the source video and how to download it.

## Output

| File | Description |
|------|-------------|
| `output/keypoints/alphapose-results.json` | Raw AlphaPose keypoint output (COCO-format JSON). One entry per frame, 136 keypoints per person. Produced by `scripts/run_alphapose.sh`. |
| `output/keypoints/AlphaPose_test.mp4` | Annotated video rendered by AlphaPose itself (skeleton overlaid on original frames). Produced by `scripts/run_alphapose.sh --save-video`. |
| `output/test.pose` | Keypoints converted to [pose-format](https://github.com/sign-language-processing/pose). Produced by `scripts/convert_to_pose.sh`. |
| `output/test_viz.mp4` | Visualization of `test.pose` rendered by our own script (keypoints drawn on original frames). Produced by `scripts/visualize_pose.sh`. |
