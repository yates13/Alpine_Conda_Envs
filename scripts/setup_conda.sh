#!/bin/bash
# One-time setup: make conda put envs and its package cache in /projects.
# Usage: bash scripts/setup_conda.sh
set -euo pipefail
PROJECTS_DIR=${PROJECTS_DIR:-/projects/$USER}
mkdir -p "$PROJECTS_DIR/conda_envs" "$PROJECTS_DIR/conda_pkgs"
conda config --add envs_dirs "$PROJECTS_DIR/conda_envs"
conda config --add pkgs_dirs "$PROJECTS_DIR/conda_pkgs"
conda config --show envs_dirs pkgs_dirs
