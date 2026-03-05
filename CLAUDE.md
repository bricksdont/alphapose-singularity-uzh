# CLAUDE.md — Notes for Claude

## Project overview

Singularity/Apptainer pipeline for running AlphaPose pose estimation on videos at UZH.
Mirrors conventions of [openpose-singularity-uzh](https://github.com/bricksdont/openpose-singularity-uzh).

## Key differences from openpose-singularity-uzh

- **No Docker pull**: AlphaPose must be built from source (`alphapose.def`)
- **Model weights**: downloaded separately via `gdown` from Google Drive; not baked into container
- **Keypoints**: 136 (HALPE_136, default) or 133 (COCO WholeBody)
- **Post-processing**: uses `load_alphapose_wholebody_from_json` from `GerrySant/pose` branch

## AlphaPose commit

`c60106d19afb443e964df6f06ed1842962f5f1f7` — known-working, verified by GerrySant install script.

## Model files and Google Drive IDs

| Model | GDrive ID | Destination |
|-------|-----------|-------------|
| YOLOv3-SPP | `1D47msNOOiJKvPOXlnpyzdKA3k6E97NTC` | `data/models/yolov3-spp.weights` |
| 136-kpt DCN Combined (default) | `1wX1Z2ZOoysgSNovlgiEtJKpbR8tUBWYR` | `data/models/pretrained_models/multi_domain_fast50_dcn_combined_256x192.pth` |
| 136-kpt Symmetric Integral | `1Bb3kPoFFt-M0Y3ceqNO8DTXi1iNDd4gI` | `data/models/pretrained_models/multi_domain_fast50_regression_256x192.pth` |
| 133-kpt COCO WholeBody | `1aP0nYujw32H-VoJBVsXS-DsBBY-UwI8Y` | `data/models/pretrained_models/wholebody133_dcn_combined.pth` |

## Config paths inside container

- 136-kpt: `configs/halpe_coco_wholebody_136/resnet/256x192_res50_lr1e-3_2x-dcn-combined.yaml`
- 133-kpt: `configs/coco_wholebody/resnet/256x192_res50_lr1e-3_2x-dcn-combined.yaml`

## Post-processing library

`pose-format` from `GerrySant/pose` branch at commit `1ed292b03ff627fa9e2594b944c853ec7172aa74`.
Install via `requirements.txt` into a venv (`scripts/setup_venv.sh`).

Import path:
```python
from pose_format.utils.alphapose import load_alphapose_wholebody_from_json
```

## Directory structure

```
data/
  input/       # user videos (gitignored)
  output/      # keypoints JSON, videos, .pose files (gitignored)
  models/      # downloaded weights (gitignored)
    yolov3-spp.weights
    pretrained_models/
      multi_domain_fast50_dcn_combined_256x192.pth
      multi_domain_fast50_regression_256x192.pth
      wholebody133_dcn_combined.pth
```

## Typical workflow

```bash
bash scripts/build_container.sh
bash scripts/download_models.sh
bash scripts/download_test_video.sh
bash scripts/run_alphapose.sh --video data/input/test.mp4
bash scripts/setup_venv.sh
bash scripts/convert_to_pose.sh -i data/output/keypoints/alphapose-results.json -o data/output/test.pose
bash scripts/visualize_pose.sh -i data/output/test.pose -o data/output/test_viz.mp4
```
