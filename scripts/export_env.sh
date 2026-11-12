#!/bin/bash
# Save an exact-version snapshot of a built env to envs/locked/<name>.full.yml
# (the machine-specific "prefix:" line is removed so it is safe to share).
# Usage: bash scripts/export_env.sh <env_name>
set -uo pipefail
name=${1:?usage: bash scripts/export_env.sh <env_name>}
REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV_DIR=${ENV_DIR:-/projects/$USER/conda_envs}

mkdir -p "$REPO/envs/locked"
conda env export -p "$ENV_DIR/$name" | grep -v '^prefix:' > "$REPO/envs/locked/$name.full.yml"
echo "Wrote envs/locked/$name.full.yml"
