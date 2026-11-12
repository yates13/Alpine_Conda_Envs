#!/bin/bash
# Write an exact-version, shareable snapshot of an env to <name>.full.yml
# (the machine-specific "prefix:" line is removed).
# Usage: bash export_env.sh <env_name> [ENV_DIR]
set -uo pipefail
name=${1:?usage: bash export_env.sh <env_name> [ENV_DIR]}
ENV_DIR=${2:-/projects/$USER/conda_envs}
HERE=$(cd "$(dirname "$0")" && pwd)

conda env export -p "$ENV_DIR/$name" | grep -v '^prefix:' > "$HERE/$name.full.yml"
echo "Wrote $HERE/$name.full.yml"
