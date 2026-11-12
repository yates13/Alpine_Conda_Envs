#!/bin/bash
# Structural health check for every env in $ENV_DIR.
# Usage: bash scripts/verify_envs.sh
set -uo pipefail
ENV_DIR=${ENV_DIR:-/projects/$USER/conda_envs}
command -v conda >/dev/null 2>&1 || { echo "ERROR: conda not found on PATH" >&2; exit 1; }

bad=0
for env in "$ENV_DIR"/*/; do
    [[ -d "$env" ]] || { echo "No envs found in $ENV_DIR"; exit 1; }
    n=$(basename "$env")
    [[ -d "$env/conda-meta" ]] || { echo "$n: conda-meta MISSING"; bad=1; }
    conda list -p "$env" >/dev/null 2>&1 || { echo "$n: conda list FAILED"; bad=1; }
    if [[ -x "$env/bin/python" ]]; then
        "$env/bin/python" -m pip check >/dev/null 2>&1 || { echo "$n: pip check reported problems"; bad=1; }
    fi
done
(( bad )) || echo "All envs look structurally sound."
echo "Also run each env's main tool (e.g. samtools --version) to confirm the binaries work."
