#!/usr/bin/env bash
# Build the AlphaPose Singularity container as a SLURM job.
# Useful on clusters where build nodes have internet access and more resources.
#
# Usage:
#   bash scripts/slurm_build_container.sh [options]
#
# Options:
#   --partition <name>   SLURM partition (default: cpu)
#   --time <HH:MM:SS>    Time limit (default: 02:00:00)
#   --mem <MB>           Memory (default: 16000)
#   --cpus N             CPUs (default: 8)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
PARTITION="cpu"
TIME_LIMIT="02:00:00"
MEM="16000"
CPUS=8

while [[ $# -gt 0 ]]; do
    case "$1" in
        --partition) PARTITION="$2"; shift 2 ;;
        --time)      TIME_LIMIT="$2"; shift 2 ;;
        --mem)       MEM="$2"; shift 2 ;;
        --cpus)      CPUS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash scripts/slurm_build_container.sh [--partition <name>] [--time HH:MM:SS] [--mem MB] [--cpus N]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

LOGS_DIR="$REPO_DIR/logs"
mkdir -p "$LOGS_DIR"

echo "=== Submitting container build job ==="
echo "Partition: $PARTITION"
echo "Time:      $TIME_LIMIT"
echo "Memory:    ${MEM}MB"
echo "CPUs:      $CPUS"
echo ""

JOB_ID=$(sbatch \
    --partition="$PARTITION" \
    --time="$TIME_LIMIT" \
    --mem="$MEM" \
    --cpus-per-task="$CPUS" \
    --output="$LOGS_DIR/build_container_%j.out" \
    --error="$LOGS_DIR/build_container_%j.err" \
    --job-name="alphapose_build" \
    --wrap="bash $SCRIPT_DIR/build_container.sh" \
    | awk '{print $NF}')

echo "Submitted job: $JOB_ID"
echo ""
echo "Monitor with:"
echo "  squeue -j $JOB_ID"
echo "  tail -f $LOGS_DIR/build_container_${JOB_ID}.out"
