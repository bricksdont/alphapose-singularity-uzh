# alphapose-singularity-uzh

Singularity/Apptainer container pipeline for running [AlphaPose](https://github.com/MVIG-SJTU/AlphaPose) whole-body pose estimation. Dedicated code for running on the UZH SLURM cluster.

## Features

- **136 keypoints** (HALPE_136, default) or **133 keypoints** (COCO WholeBody)
- Whole-body pose: face, hands, body, feet
- Output: JSON keypoints, annotated video, `.pose` format ([pose-format library](https://github.com/GerrySant/pose/tree/1ed292b03ff627fa9e2594b944c853ec7172aa74))
- SLURM support for batch processing on HPC clusters

## Requirements

- Singularity ≥ 3.x or Apptainer ≥ 1.x
- NVIDIA GPU with CUDA drivers (for inference)
- Python 3.8+ (for post-processing venv)
- Internet access for model download
- For building the container (usually not required): ~ 35GB of disk space

---

## Quick Start

```bash
git clone https://github.com/bricksdont/alphapose-singularity-uzh
cd alphapose-singularity-uzh
```

### 1. Get the container

Pull the pre-built image from GHCR (recommended):

```bash
singularity pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest
```

> If the pull fails or you need to customise the container, see the [Pushing the Container to GHCR](#pushing-the-container-to-ghcr) section for instructions on building from source.

### 2. Test GPU access

```bash
bash scripts/test_gpu.sh
```

### 3. Set up venv

```bash
bash scripts/setup_venv.sh
```

Installs `gdown` (needed for model download) and the post-processing (Step 7) dependencies.

### 4. Download model weights

```bash
bash scripts/download_models.sh
```

Downloads YOLO detector and pose models to `data/pretrained_models/`. Requires `gdown` from the venv.

### 5. Get a test video

```bash
bash scripts/download_test_video.sh
```

Downloads a short sample video to `data/input/test.mp4`.

### 6. Run AlphaPose

There are two scripts; both produce identical keypoint output (default scheme: 136 keypoints per frame, COCO-format JSON).

**Option A — `run_alphapose.sh`** (single video only):

```bash
bash scripts/run_alphapose.sh --video data/input/test.mp4 --outdir data/output/keypoints
```

Optionally save AlphaPose's own skeleton-overlay video alongside the JSON:

```bash
bash scripts/run_alphapose.sh --video data/input/test.mp4 --outdir data/output/keypoints --save-video
```

**Option B — `run_alphapose_api.sh`** (single video or directory):

```bash
# single video
bash scripts/run_alphapose_api.sh --video data/input/test.mp4 --outdir data/output/keypoints_api

# directory of videos — loads the model once and processes all videos in a loop
bash scripts/run_alphapose_api.sh --video data/input/ --outdir data/output/keypoints_api
```

Processing a directory is significantly faster than running Option A once per video; see the [Inference modes and speed](#inference-modes-and-speed) section for benchmarks.

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

## Script Reference

### `scripts/run_alphapose.sh`

Single video only. Can optionally save AlphaPose's own skeleton-overlay video.

```
Usage: bash scripts/run_alphapose.sh --video <path> [options]

Options:
  --video <path>       Input video (required)
  --keypoints 136|133  Keypoint format (default: 136)
  --track              Enable pose tracking
  --save-video         Save AlphaPose-rendered annotated video (default: off)
  --outdir <path>      Output directory (required)
```

### `scripts/run_alphapose_api.sh`

Single video or directory of videos. Loads the model once and processes all videos in a loop —
significantly faster than `run_alphapose.sh` for batches. JSON output only (no annotated video).

```
Usage: bash scripts/run_alphapose_api.sh --video <path|dir> --outdir <path> [options]

Options:
  --video <path|dir>   Input video file or directory (required)
  --keypoints 136|133  Keypoint format (default: 136)
  --track              Enable pose tracking
  --flip               Enable horizontal flip augmentation
  --outdir <path>      Output directory (required)
```

### `scripts/slurm_submit.sh`

Submit parallel SLURM jobs for large-scale batch processing:

```
Usage: bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]

Options:
  --chunks N           Number of parallel jobs (default: 1)
  --keypoints 136|133  Keypoint format (default: 136)
  --time <HH:MM:SS>    Time limit per job (default: 24:00:00)
```

---

## SLURM Cluster Processing

For large-scale processing on the UZH ScienceCluster, split videos across multiple GPU jobs:

```bash
bash scripts/slurm_submit.sh <input_dir> <output_dir> [--chunks N]
```

This distributes videos across N SLURM jobs (default: 4). Each job processes its chunk using `run_alphapose_api.sh`, which loads the model **once** per job and processes all assigned videos in a loop — significantly faster than reloading the model per video.

**Prerequisites:** the container image (`alphapose.sif`), model weights (`data/models/`), and Python virtual environment (`venv/`) must already be set up. The script must be run on a SLURM cluster with `sbatch` available.

**Example:**

```bash
# From the repo directory on the cluster:
bash scripts/slurm_submit.sh /path/to/videos /path/to/output --chunks 8

# Monitor jobs:
squeue -u $USER

# View logs:
tail -f /path/to/output/.slurm_logs/job_*.out
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

## Building the Container from Source

If the GHCR pull fails or you need to customise the container, build from source:

```bash
bash scripts/build_container.sh
```

> **Note:** This compiles AlphaPose from source and takes 30–60 minutes. Requires internet access and ~35 GB of free disk space.

On a SLURM cluster, submit as a job instead:
```bash
bash scripts/slurm_build_container.sh
```

> **Tip:** If the build fails repeatedly, temporary files from previous attempts may have exhausted disk space in `/tmp`. Check with `du -sh /tmp/build-temp-*` and remove any leftover directories before retrying.

## Pushing the Container to GHCR

Once built, the `alphapose.sif` image can be pushed to GHCR so others can pull it directly.

### Prerequisites

Create a GitHub Personal Access Token (PAT) with the `write:packages` scope:
[https://github.com/settings/tokens](https://github.com/settings/tokens)

Export it:
```bash
export GITHUB_TOKEN=<your_token>
```

### Push

```bash
bash scripts/push_to_ghcr.sh
```

With options:
```bash
bash scripts/push_to_ghcr.sh --tag v1.0 --user bricksdont --repo alphapose-singularity-uzh
```

### Making the package public

By default GHCR packages are private. To allow public access, go to:

> GitHub → Your profile → Packages → `alphapose` → Package Settings → Change visibility → Public

### Building the container on the cluster

Login nodes may not have enough memory to build the SIF image. Submit it as a SLURM job instead:

```bash
sbatch scripts/slurm_build_container.sh
```

---

## Inference modes and speed

There are two ways to run AlphaPose inference:

### `run_alphapose.sh` — demo_inference.py mode

Calls AlphaPose's built-in `demo_inference.py`. Supports one video per invocation; the model is loaded fresh each time. Can optionally save an AlphaPose-rendered annotated video (`--save-video`).

### `run_alphapose_api.sh` — API mode (recommended for batches)

Calls `scripts/alphapose_estimation.py`, which uses the AlphaPose Python API directly with a synchronous writer, bypassing `demo_inference.py`'s async DataWriter queue. The model is loaded once and all videos are processed in a single loop. Accepts a single video file or a directory of videos. Does not produce an annotated video — JSON output only.

### Speed comparison

Benchmarked on 3 × 133-frame videos (640×480, ~5 s each) on a single Tesla T4:

| Approach | Total time | Per video | Model loads |
|---|---|---|---|
| `run_alphapose.sh` (×3) | ~79 s | ~26 s each | 3 |
| `run_alphapose_api.sh` (directory) | ~35 s | ~24 s (first), ~7 s (subsequent) | 1 |

The API mode is **~2.3× faster** for batch processing. The first video still pays the full startup cost (~17 s for model load); subsequent videos cost only the inference time (~7 s each). The speed advantage grows with the number of videos.

`demo_inference.py` has no native batch/directory mode for videos, so model-load overhead cannot be avoided when using it for multiple videos.

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
│   ├── push_to_ghcr.sh
│   ├── download_models.sh
│   ├── test_gpu.sh
│   ├── download_test_video.sh
│   ├── run_alphapose.sh
│   ├── run_alphapose_api.sh
│   ├── alphapose_estimation.py
│   ├── convert_to_pose.sh
│   ├── convert_to_pose.py
│   ├── visualize_pose.sh
│   ├── visualize_pose.py
│   ├── setup_venv.sh
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

## References

- [MVIG-SJTU/AlphaPose](https://github.com/MVIG-SJTU/AlphaPose)
- [GerrySant/pose PR#191](https://github.com/sign-language-processing/pose/pull/191)
- [openpose-singularity-uzh](https://github.com/bricksdont/openpose-singularity-uzh)
- [GerrySant install script](https://github.com/GerrySant/multimodalhugs-pipelines/blob/multiple_support/scripts/environment/install-scripts/install_alphapose.sh)

---

## Acknowledgements

```bibtex
@misc{muller-et-al-2026alphapose-singularity-uzh, 
    title={Singularity/Apptainer container pipeline for running AlphaPose whole-body pose estimation},
    author={M{\"u}ller, Mathias and Sant, Gerard},
    howpublished={\url{https://github.com/bricksdont/alphapose-singularity-uzh}},
    year={2026}
}
```
