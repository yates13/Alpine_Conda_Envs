#!/bin/bash
################################################################################
# Rebuild the conda environments for this pipeline from the .yml files in this
# folder. Environments that already exist are skipped.
#
# Usage:
#     bash CondaEnvs/make_envs.sh <ENV_DIR>
#
# Files named *.full.yml are exact-version exports and are NOT built here. To
# rebuild one exactly, run:
#     conda env create --file CondaEnvs/<name>.full.yml --prefix <ENV_DIR>/<name>
################################################################################
set -uo pipefail

ENV_DIR=${1:?usage: bash make_envs.sh <ENV_DIR>}
HERE=$(cd "$(dirname "$0")" && pwd)

command -v conda >/dev/null 2>&1 || { echo "ERROR: conda not found on PATH" >&2; exit 1; }
mkdir -p "$ENV_DIR"

failed=()
for yml in "$HERE"/*.yml; do
    [[ -e "$yml" ]] || { echo "No .yml files found in $HERE" >&2; exit 1; }
    name=$(basename "$yml" .yml)
    [[ "$name" == *.full ]] && continue

    if [[ -f "$ENV_DIR/$name/conda-meta/history" ]]; then
        echo "EXISTS: $name - skipping"
        continue
    fi

    echo "Building: $name"
    if ! conda env create --file "$yml" --prefix "$ENV_DIR/$name" -y; then
        failed+=("$name")
    fi
done

if (( ${#failed[@]} )); then
    echo "FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "All environments are in place in $ENV_DIR"
