#!/bin/bash
################################################################################
# Create a spec in envs/ and build it, in one step.
# Run on a compute node (sinteractive or sbatch), not the login node.
#
# Usage: bash scripts/new_env.sh <env_name> <package> [<package> ...]
# Example: bash scripts/new_env.sh align_env python=3.11 samtools bwa
################################################################################
set -euo pipefail
name=${1:?usage: bash scripts/new_env.sh <env_name> <package> [<package> ...]}
shift
(( $# )) || { echo "Give at least one package" >&2; exit 1; }

REPO=$(cd "$(dirname "$0")/.." && pwd)
spec="$REPO/envs/$name.yml"
[[ -e "$spec" ]] && { echo "$spec already exists" >&2; exit 1; }

{
    echo "name: $name"
    echo "channels:"
    echo "  - conda-forge"
    echo "  - bioconda"
    echo "dependencies:"
    for p in "$@"; do echo "  - $p"; done
} > "$spec"
echo "Wrote $spec"

bash "$REPO/scripts/make_envs.sh" "$name"
echo "Tip: save an exact snapshot with: bash scripts/export_env.sh $name"
