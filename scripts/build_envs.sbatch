#!/bin/bash
#SBATCH --job-name=build_envs
#SBATCH --partition=amilan
#SBATCH --qos=normal
#SBATCH --ntasks=4
#SBATCH --time=04:00:00
#SBATCH --output=logs/build_envs_%j.log

# Submit from the repo root:   sbatch scripts/build_envs.sbatch
# Defaults assume /projects/$USER; override at submit time if yours differ:
#   CONDA_BASE=/path/to/miniforge3 ENV_DIR=/path/to/conda_envs sbatch --export=ALL scripts/build_envs.sbatch
# Extra arguments are passed to make_envs.sh (env names, or --locked):
#   sbatch scripts/build_envs.sbatch fastp_env
CONDA_BASE=${CONDA_BASE:-/projects/$USER/miniforge3}
export ENV_DIR=${ENV_DIR:-/projects/$USER/conda_envs}

source "$CONDA_BASE/etc/profile.d/conda.sh"
bash "$SLURM_SUBMIT_DIR/scripts/make_envs.sh" "$@"
