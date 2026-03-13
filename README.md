# alphapose-singularity-uzh

Singularity/Apptainer container pipeline for running [AlphaPose](https://github.com/MVIG-SJTU/AlphaPose) whole-body pose estimation. Dedicated code for running on the UZH SLURM cluster.

## Features

- **136 keypoints** (HALPE_136, default) or **133 keypoints** (COCO WholeBody)
- Whole-body pose: face, hands, body, feet
- Output: `.pose` format ([pose-format library](https://github.com/GerrySant/pose/tree/1ed292b03ff627fa9e2594b944c853ec7172aa74))
- SLURM support for batch processing on HPC clusters

## Requirements

- Singularity ≥ 3.x or Apptainer ≥ 1.x
- NVIDIA GPU with CUDA drivers (for inference)
- Python 3.8+ (for converting Alphapose output to .pose files)
- For building the container (usually not required): ~ 35GB of disk space

---

## Quick Start

Note: instructions are for a local machine with a GPU, not an HPC cluster setup. See [SLURM Cluster Processing](#slurm-cluster-processing) for SLURM.

```bash
git clone https://github.com/bricksdont/alphapose-singularity-uzh
cd alphapose-singularity-uzh
```

### 1. Get the container

Pull the pre-built image from GHCR (recommended) with Singularity or Apptainer:

```bash
# Singularity
singularity pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest

# Apptainer
apptainer pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest
```

> If the pull fails or you need to customise the container, see the [Building the Container from Source](#building-the-container-from-source) section.

### 2. Test GPU access

```bash
bash scripts/test_gpu.sh
```

### 3. Set up venv

```bash
bash scripts/setup_venv.sh
```

Installs `gdown` (needed for model download) and the post-processing dependencies.

### 4. Download model weights

```bash
bash scripts/download_models.sh
```

Downloads YOLO detector and pose models to `data/models/`. Requires `gdown` from the venv.

### 5. Run on a folder of videos

```bash
bash scripts/batch_to_pose.sh data/input/ data/output/
```

This runs AlphaPose on all videos in `data/input/` and writes one `.pose` file per video to `data/output/`. AlphaPose JSON keypoints are stored in a temporary directory and deleted after conversion — only the `.pose` files are kept.

To test with a sample video first:

```bash
bash scripts/download_test_video.sh   # downloads data/input/test.mp4
bash scripts/batch_to_pose.sh data/input/ data/output/
```

---

## SLURM Cluster Processing

**Getting the container on the cluster:** Login nodes may have network or resource limits that prevent pulling large images. Submit it as a SLURM job instead — the job first tries to pull the pre-built image from GHCR; if that fails, it builds from source automatically:

```bash
sbatch scripts/slurm_build_container.sh

# To skip the pull and always build from source:
sbatch scripts/slurm_build_container.sh --force-rebuild
```

For large-scale processing on the UZH ScienceCluster, split videos across multiple GPU jobs:

```bash
bash scripts/slurm_submit.sh <input_dir> <output_dir> [--chunks N] [--lowprio]
```

This distributes videos across N SLURM jobs (default: 1). Each job runs `batch_to_pose.sh` on its chunk — AlphaPose loads the model once per job and processes all assigned videos, then converts them to `.pose` files.

**Prerequisites:** the container image (`alphapose.sif`), model weights (`data/models/`), and Python virtual environment (`venv/`) must already be set up. The script must be run on a SLURM cluster with `sbatch` available.

**Example:**

```bash
# Submit a single job covering all videos (default):
bash scripts/slurm_submit.sh /path/to/videos /path/to/output

# Or split across multiple parallel jobs:
bash scripts/slurm_submit.sh /path/to/videos /path/to/output --chunks 4

# Monitor jobs:
squeue -u $USER

# View logs:
tail -f /path/to/output/.slurm_logs/job_*.out
```

---

## Advanced usage

This section is for users who want more control — for debugging, keeping intermediate JSON output, producing annotated videos, or running pipeline steps individually.

### Step 1: Run AlphaPose to get JSON keypoints

There are two inference scripts. Both produce identical keypoint output (136 keypoints per frame, COCO-format JSON), but differ in speed and features.

**`run_alphapose.sh`** — single video. Calls AlphaPose's built-in `demo_inference.py`; the model is loaded fresh each time. Can optionally save an annotated skeleton-overlay video.

```bash
bash scripts/run_alphapose.sh \
    --video data/input/test.mp4 \
    --outdir data/output/keypoints

# Also save AlphaPose's own skeleton-overlay video:
bash scripts/run_alphapose.sh \
    --video data/input/test.mp4 \
    --outdir data/output/keypoints \
    --save-video
```

**`run_alphapose_api.sh`** — single video or directory. Uses the AlphaPose Python API directly; loads the model once and processes all videos in a loop. Significantly faster for batches; JSON output only (no annotated video). This is what `batch_to_pose.sh` uses internally.

```bash
# Single video:
bash scripts/run_alphapose_api.sh \
    --video data/input/test.mp4 \
    --outdir data/output/keypoints_api

# Directory of videos (model loads once for all):
bash scripts/run_alphapose_api.sh \
    --video data/input/ \
    --outdir data/output/keypoints_api
```

**Speed comparison** — benchmarked on 3 × 133-frame videos (640×480, ~5 s each) on a single Tesla T4:

| Approach | Total time | Per video | Model loads |
|---|---|---|---|
| `run_alphapose.sh` (×3) | ~79 s | ~26 s each | 3 |
| `run_alphapose_api.sh` (directory) | ~35 s | ~24 s (first), ~7 s (subsequent) | 1 |

The API mode is **~2.3× faster** for batches. The speed advantage grows with the number of videos.

**CPU mode — not supported.** AlphaPose uses Deformable Convolutions (DCN), which are implemented as a CUDA-only extension. Passing `--gpus -1` triggers a `NotImplementedError` in the DCN layer immediately. A GPU is therefore required for all inference.

### Step 2: Convert JSON to .pose format

```bash
bash scripts/convert_to_pose.sh \
    -i data/output/keypoints/alphapose-results.json \
    -o data/output/test.pose \
    --original-video data/input/test.mp4
```

### Step 3: Visualize

```bash
bash scripts/visualize_pose.sh \
    -i data/output/test.pose \
    -o data/output/test_viz.mp4 \
    --video data/input/test.mp4
```

---

## Script Reference

### `scripts/batch_to_pose.sh`

Processes a directory of videos end-to-end: runs AlphaPose (API mode, model loaded once), then converts each result to `.pose` format. JSON keypoints are written to a temporary directory and deleted after conversion.

```
Usage: bash scripts/batch_to_pose.sh <input_dir> <output_dir> [options]

Options:
  --keypoints 136|133  Number of keypoints (default: 136)
```

### `scripts/run_alphapose.sh`

Single video only. Can optionally save AlphaPose's own skeleton-overlay video.

```
Usage: bash scripts/run_alphapose.sh --video <path> --outdir <path> [options]

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

### `scripts/slurm_submit.sh` / `scripts/slurm_job.sh`

Submit parallel SLURM jobs for large-scale batch processing. Each job runs `batch_to_pose.sh` on its assigned chunk of videos.

```
Usage: bash scripts/slurm_submit.sh <input_dir> <output_dir> [options]

Options:
  --chunks N           Number of parallel jobs (default: 1)
  --keypoints 136|133  Keypoint format (default: 136)
  --time <HH:MM:SS>    Time limit per job (default: 24:00:00)
  --lowprio            Use low-priority partition (adds --partition=lowprio)
                       In both cases --gpus=1 is used (any GPU)
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

On a SLURM cluster, submit as a job instead (tries GHCR pull first, builds from source if pull fails):
```bash
sbatch scripts/slurm_build_container.sh

# To skip the pull and always build from source:
sbatch scripts/slurm_build_container.sh --force-rebuild
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
│   ├── batch_to_pose.sh
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
    ├── output/            # .pose files, videos
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
