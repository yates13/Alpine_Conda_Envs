#!/bin/bash
#SBATCH --job-name=build_envs
#SBATCH --partition=amilan
#SBATCH --qos=normal
#SBATCH --ntasks=4
#SBATCH --time=04:00:00
#SBATCH --output=build_envs_%j.log

# Submit from this folder:   sbatch build_envs.sbatch
# Override defaults if needed:
#   CONDA_BASE=/path/to/miniforge3 ENV_DIR=/path/to/conda_envs sbatch --export=ALL build_envs.sbatch
CONDA_BASE=${CONDA_BASE:-/projects/$USER/miniforge3}
ENV_DIR=${ENV_DIR:-/projects/$USER/conda_envs}

source "$CONDA_BASE/etc/profile.d/conda.sh"
bash "$SLURM_SUBMIT_DIR/make_envs.sh" "$ENV_DIR"
