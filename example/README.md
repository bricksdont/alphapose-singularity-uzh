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
| `output/test_viz.mp4` | Visualization of `test.pose` rendered by `scripts/visualize_pose.sh` (legs hidden, thickness=1). |
| `output/keypoints_api/test.json` | Raw AlphaPose keypoint output from API mode. Produced by `scripts/run_alphapose_api.sh`. |
| `output/test_api.pose` | API-mode keypoints converted to [pose-format](https://github.com/sign-language-processing/pose). Produced by `scripts/convert_to_pose.sh`. |
| `output/test_api_viz.mp4` | Visualization of `test_api.pose` rendered by `scripts/visualize_pose.sh` (legs hidden, thickness=1). |
