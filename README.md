# alphapose-singularity-uzh

Singularity/Apptainer container pipeline for running [AlphaPose](https://github.com/MVIG-SJTU/AlphaPose) whole-body pose estimation on videos at UZH.

Mirrors the structure and conventions of [openpose-singularity-uzh](https://github.com/bricksdont/openpose-singularity-uzh).

## Features

- **136 keypoints** (HALPE_136, default) or **133 keypoints** (COCO WholeBody)
- Whole-body pose: face, hands, body, feet
- Output: JSON keypoints, annotated video, `.pose` format (pose-format library)
- SLURM support for batch processing on HPC clusters
- Post-processing via [GerrySant/pose](https://github.com/GerrySant/pose/tree/1ed292b03ff627fa9e2594b944c853ec7172aa74)

## Requirements

- Singularity ≥ 3.x or Apptainer ≥ 1.x
- NVIDIA GPU with CUDA drivers (for inference)
- Python 3.8+ (for post-processing venv)
- Internet access for model download

---

## Quick Start

### 1. Build the container

> **Note:** Building compiles AlphaPose from source and takes 30–60 minutes.

```bash
bash scripts/build_container.sh
```

On a SLURM cluster, submit as a job instead:
```bash
bash scripts/slurm_build_container.sh
```

### 2. Test GPU access

```bash
bash scripts/test_gpu.sh
```

### 3. Download model weights

```bash
bash scripts/download_models.sh
```

Downloads YOLO detector and pose models to `data/models/`.

### 4. Get a test video

```bash
bash scripts/download_test_video.sh
```

Downloads a short sample video to `data/input/test.mp4`.

### 5. Run AlphaPose

```bash
bash scripts/run_alphapose.sh --video data/input/test.mp4
```

Output: `data/output/keypoints/`

### 6. Set up post-processing venv

```bash
bash scripts/setup_venv.sh
```

### 7. Convert to .pose format

```bash
bash scripts/convert_to_pose.sh \
    -i data/output/keypoints/alphapose-results.json \
    -o data/output/test.pose \
    --original-video data/input/test.mp4
```

### 8. Visualize

```bash
bash scripts/visualize_pose.sh \
    -i data/output/test.pose \
    -o data/output/test_viz.mp4 \
    --video data/input/test.mp4
```

---

## Directory Structure

```
alphapose-singularity-uzh/
├── alphapose.def          # Singularity definition file
├── requirements.txt       # Python deps for post-processing venv
├── README.md
├── CLAUDE.md              # Notes for Claude
├── .gitignore
├── scripts/
│   ├── build_container.sh
│   ├── download_models.sh
│   ├── test_gpu.sh
│   ├── download_test_video.sh
│   ├── run_alphapose.sh
│   ├── convert_to_pose.sh
│   ├── convert_to_pose.py
│   ├── visualize_pose.sh
│   ├── visualize_pose.py
│   ├── setup_venv.sh
│   ├── batch_to_pose.sh
│   ├── slurm_submit.sh
│   ├── slurm_job.sh
│   └── slurm_build_container.sh
└── data/                  # gitignored
    ├── input/             # input videos
    ├── output/            # keypoints JSON, .pose files, videos
    └── models/            # downloaded weights
        ├── yolov3-spp.weights
        └── pretrained_models/
            ├── multi_domain_fast50_dcn_combined_256x192.pth
            ├── multi_domain_fast50_regression_256x192.pth
            └── wholebody133_dcn_combined.pth
```

---

## Script Reference

### `scripts/run_alphapose.sh`

```
Usage: bash scripts/run_alphapose.sh --video <path> [options]

Options:
  --video <path>       Input video (required)
  --keypoints 136|133  Keypoint format (default: 136)
  --track              Enable pose tracking
  --outdir <path>      Output directory (default: data/output/keypoints)
```

### `scripts/batch_to_pose.sh`

Process all videos in a directory:

```bash
bash scripts/batch_to_pose.sh data/input data/output [--keypoints 136] [--track]
```

### `scripts/slurm_submit.sh`

Submit parallel SLURM jobs:

```bash
bash scripts/slurm_submit.sh data/input data/output \
    --chunk-size 5 \
    --partition gpu \
    --time 04:00:00
```

---

## Models

| Model | Keypoints | AP | Speed | GDrive |
|-------|-----------|-----|-------|--------|
| Multi-domain DCN Combined (default) | 136 | 49.8 | 10.35 iter/s | `1wX1Z2ZOoysgSNovlgiEtJKpbR8tUBWYR` |
| Multi-domain Symmetric Integral | 136 | 50.1 | 16.28 iter/s | `1Bb3kPoFFt-M0Y3ceqNO8DTXi1iNDd4gI` |
| COCO WholeBody DCN Combined | 133 | — | — | `1aP0nYujw32H-VoJBVsXS-DsBBY-UwI8Y` |

The default 136-kpt model (Multi-domain DCN Combined) is trained on both HALPE and COCO WholeBody datasets with deformable convolutions for strong whole-body accuracy.

---

## Post-Processing

Post-processing uses the [GerrySant/pose](https://github.com/GerrySant/pose/tree/1ed292b03ff627fa9e2594b944c853ec7172aa74) fork's `load_alphapose_wholebody_from_json` function, which converts AlphaPose JSON output to the `.pose` binary format.

Install:
```bash
bash scripts/setup_venv.sh
```

Convert:
```python
from pose_format.utils.alphapose import load_alphapose_wholebody_from_json
```

---

## Troubleshooting

**Build fails with CUDA errors:**
Check that the base Docker image `pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel` is compatible with your cluster's CUDA driver version (requires driver ≥ 530).

**`gdown` rate-limit / download fails:**
Download models manually from Google Drive and place them in `data/models/` following the paths in `CLAUDE.md`.

**`singularity: command not found`:**
Load the Singularity/Apptainer module: `module load singularity` or `module load apptainer`.

**Out of memory during inference:**
Reduce batch size or use a smaller input resolution. Edit the config YAML inside the container at `/opt/alphapose/configs/`.

---

## References

- [MVIG-SJTU/AlphaPose](https://github.com/MVIG-SJTU/AlphaPose)
- [GerrySant/pose PR#191](https://github.com/sign-language-processing/pose/pull/191)
- [openpose-singularity-uzh](https://github.com/bricksdont/openpose-singularity-uzh)
- [GerrySant install script](https://github.com/GerrySant/multimodalhugs-pipelines/blob/multiple_support/scripts/environment/install-scripts/install_alphapose.sh)
