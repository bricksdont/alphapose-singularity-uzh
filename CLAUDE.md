# CLAUDE.md — Notes for Claude

## Project overview

Singularity/Apptainer pipeline for running AlphaPose pose estimation on videos at UZH.
Mirrors conventions of [openpose-singularity-uzh](https://github.com/bricksdont/openpose-singularity-uzh).

## Key differences from openpose-singularity-uzh

- **Pre-built image on GHCR**: pull with `apptainer pull` or `singularity pull` (see below); building from source is the fallback
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
  output/      # .pose files (gitignored)
  models/      # downloaded weights (gitignored)
    yolov3-spp.weights
    pretrained_models/
      multi_domain_fast50_dcn_combined_256x192.pth
      multi_domain_fast50_regression_256x192.pth
      wholebody133_dcn_combined.pth
```

## Container image on GHCR

Pre-built image at `oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest`.

```bash
# Apptainer
apptainer pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest
# Singularity
singularity pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest
```

On the UZH cluster, load apptainer first: `module load apptainer`

**Login nodes may reject large pulls** ("unexpected EOF") due to resource/network limits.
Use `sbatch scripts/slurm_build_container.sh` instead, which pulls (or builds) inside a proper job.

**Apptainer cache is not auto-cleaned** after a pull. `slurm_build_container.sh` runs
`apptainer cache clean --force` after a successful pull to free the space.

## Runtime compatibility fixes (applied at singularity exec time, not in container)

Two issues required workarounds without rebuilding the container:

1. **GL library mismatch**: Singularity `--nv` injects host GL libs (Ubuntu 24.04) that are
   incompatible with the container's glibc. Fixed via `LD_PRELOAD` of the container's own GL libs.
   Applied in both `run_alphapose.sh` and `run_alphapose_api.sh`.

2. **numpy type aliases removed** (`np.float`, `np.int`, etc.) in NumPy ≥ 1.24, which breaks
   `cython_bbox` at import time. Fixed by bind-mounting `scripts/sitecustomize.py` into the
   container, which restores the aliases at Python startup.

## Two inference modes

- **`run_alphapose.sh`**: calls `demo_inference.py`, one video per invocation, can produce
  annotated video (`--save-video`). ~26 s/video on Tesla T4.
- **`run_alphapose_api.sh`**: calls `scripts/alphapose_estimation.py` via `singularity exec`,
  loads model once and loops over all videos in a directory. ~7 s/video after first (~24 s).
  JSON output only. 2.3× faster for batches.
- **`batch_to_pose.sh`**: the main user-facing script. Wraps `run_alphapose_api.sh` (API mode)
  followed by `convert_to_pose.sh` for each video. JSON written to a temp dir and cleaned up;
  only `.pose` files are kept.

## Building the container on the UZH ScienceCluster

Building with `sbatch scripts/slurm_build_container.sh --force-rebuild` required several fixes
that are now baked into `alphapose.def` and `build_container.sh`:

1. **Cluster auto-bind-mounts** (`/apps`, `/shares`, `/scratch`, etc.): the cluster injects these
   into every container. During a build the destinations must exist in the sandbox before `%post`
   runs, otherwise the build fails with "destination /apps doesn't exist in container". Fixed via
   a `%setup` section that pre-creates them using `$APPTAINER_ROOTFS` / `$SINGULARITY_ROOTFS`.

2. **Bundled fakeroot glibc incompatibility**: the cluster's apptainer ships `faked` and
   `libfakeroot.so` compiled against GLIBC_2.38. The container base image (Ubuntu 22.04) only
   has GLIBC_2.35. Fixed with `--ignore-fakeroot-command` in `apptainer build`.

3. **apt-get privilege drop fails without fakeroot**: with `--ignore-fakeroot-command`, apt tries
   to drop to the `_apt` user via setgroups, which is blocked in a user namespace. Fixed by
   writing `APT::Sandbox::User "root";` to `/etc/apt/apt.conf.d/00no-sandbox` at the start of
   `%post`.

4. **Base image**: switched from `pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel` (Ubuntu 20.04) to
   `nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04` + Miniforge, because the pytorch image's glibc
   was too old for the cluster's fakeroot. PyTorch 2.1.0 installed via pip (cu121 wheel).

5. **Miniforge instead of Miniconda**: Miniconda's default channels (pkgs/main, pkgs/r) now
   require interactive TOS acceptance, which breaks non-interactive builds.

6. **`setuptools<70`**: newer setuptools removes `pkg_resources`, which is required by
   `torch.utils.cpp_extension` during the AlphaPose build.

7. **`cython_bbox` pre-installed with `--no-build-isolation`**: pip's isolated build env lacks
   Cython, so cython_bbox must be pre-installed before `setup.py` runs.

## H200 GPU (sm_90) compatibility

The original `TORCH_CUDA_ARCH_LIST` (`6.0 6.1 7.0 7.5 8.0 8.6`) excluded the H200/H100 (Hopper,
sm_90). At runtime on an H200, DCN kernels fail silently:
`error in deformable_im2col: no kernel image is available for execution on the device`
AlphaPose appears to run but produces empty (2-byte) JSON files, and conversion fails with
`ValueError: need at least one array to stack`. Fixed by adding `9.0` to the arch list.

## SLURM: --lowprio option

`slurm_submit.sh --lowprio` adds `--partition=lowprio` to the sbatch call. Without `--lowprio`,
no partition is specified (scheduler picks any available GPU). In both cases `--gpus=1` is used.

## setup_venv.sh: SSH submodule workaround

The `pose-format` repo has a submodule with an SSH URL (`git@github.com:...`). Users without
GitHub SSH keys configured will hit "Permission denied (publickey)" during `pip install`.
Fixed in `setup_venv.sh` by setting `GIT_CONFIG_COUNT` env vars to redirect SSH GitHub URLs
to HTTPS for that one pip call (no global git config modified).

## CPU mode: not supported

AlphaPose's Deformable Convolution (DCN) layers are CUDA-only. Passing `--gpus -1` immediately
raises `NotImplementedError` in `alphapose/models/layers/dcn/deform_conv.py`. All exposed models
use DCN. A GPU is required.

## .pose conversion: always pass --original-video

`load_alphapose_wholebody_from_json` defaults to `width=1000, height=1000` if dimensions are not
provided. Always pass `--original-video` to `convert_to_pose.sh` so the header matches the actual
frame size; otherwise visualizations render small and offset in the upper-left corner.

## Typical workflow

```bash
# On the UZH cluster: get container via SLURM job (avoids login node limits)
sbatch scripts/slurm_build_container.sh

# Local machine with GPU:
apptainer pull alphapose.sif oras://ghcr.io/bricksdont/alphapose-singularity-uzh/alphapose:latest
bash scripts/setup_venv.sh
bash scripts/download_models.sh
bash scripts/download_test_video.sh
bash scripts/batch_to_pose.sh data/input/ data/output/
```
