#!/bin/bash
################################################################################
# Build conda environments from the YAML specs in envs/.
# Envs that already exist are skipped; failures are reported at the end.
#
# Usage (from anywhere):
#   bash scripts/make_envs.sh                 # build every envs/*.yml
#   bash scripts/make_envs.sh fastp_env       # build only the named env(s)
#   bash scripts/make_envs.sh --locked        # build from envs/locked/*.full.yml
#                                             # (exact versions) instead
#
# Target directory: $ENV_DIR (default: /projects/$USER/conda_envs)
################################################################################
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ENV_DIR=${ENV_DIR:-/projects/$USER/conda_envs}

SPEC_DIR="$REPO/envs"; SUFFIX=".yml"
if [[ "${1:-}" == "--locked" ]]; then
    SPEC_DIR="$REPO/envs/locked"; SUFFIX=".full.yml"; shift
fi

command -v conda >/dev/null 2>&1 || { echo "ERROR: conda not found on PATH" >&2; exit 1; }
mkdir -p "$ENV_DIR"

# Which envs to build: names given as arguments, otherwise everything in SPEC_DIR
names=("$@")
if (( ${#names[@]} == 0 )); then
    for f in "$SPEC_DIR"/*"$SUFFIX"; do
        [[ -e "$f" ]] || { echo "No *$SUFFIX files found in $SPEC_DIR" >&2; exit 1; }
        names+=("$(basename "$f" "$SUFFIX")")
    done
fi

failed=()
for name in "${names[@]}"; do
    spec="$SPEC_DIR/$name$SUFFIX"
    if [[ ! -f "$spec" ]]; then
        echo "MISSING SPEC: $spec" >&2; failed+=("$name"); continue
    fi
    if [[ -f "$ENV_DIR/$name/conda-meta/history" ]]; then
        echo "EXISTS: $name - skipping"
        continue
    fi
    echo "Building: $name"
    if ! conda env create --file "$spec" --prefix "$ENV_DIR/$name" -y; then
        failed+=("$name")
    fi
done

if (( ${#failed[@]} )); then
    echo "FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "Done. Environments are in $ENV_DIR"
