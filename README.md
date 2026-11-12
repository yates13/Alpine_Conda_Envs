# Alpine_Conda_Envs

Keep conda environments on **Alpine** (CU Research Computing) in `/projects`
instead of `/scratch` or `$HOME`, so they survive the 90-day scratch purge.
One YAML spec per environment, scripts to build, verify, and snapshot them,
and a Slurm wrapper for building on a compute node.

**Why:** files in `/scratch` are purged after 90 days. Conda envs created there
(or in the default `~/.conda/envs`) silently disappear and break pipelines.
`/projects` is not purged, but it has a quota, so watch your usage.

## Before you start

1. **An Alpine account** where you can log in and submit Slurm jobs.
2. **Miniforge (conda) in your projects directory.** If you don't have conda yet:

   ~~~bash
   cd /projects/$USER
   curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
   bash Miniforge3-Linux-x86_64.sh -b -p /projects/$USER/miniforge3
   /projects/$USER/miniforge3/bin/conda init bash
   ~~~

   Log out and back in. You should see `(base)` at your prompt.
3. **Your Slurm partition and QOS.** The defaults in this repo are
   `--partition=acpu --qos=cpu-normal`. If your account differs (or needs
   `--account`), see "Partition, QOS, and account" below.

## Quick start

~~bash
cd /projects/$USER
git clone https://github.com/yates13/Alpine_Conda_Envs.git
cd Alpine_Conda_Envs

bash scripts/setup_conda.sh                       # one-time: envs + package cache go to /projects
~~

The specs in `envs/` are **examples from a CUT&RUN / RNA-seq pipeline** (macs2,
hisat2, HOMER, deeptools, and so on). Building all of them takes a while and uses
quota, so try one first:

~~bash
sbatch scripts/build_envs.sbatch fastp_env        # build just one env
squeue -u $USER                                   # watch the job
~~

When the job finishes, the last line of the log should be `Done. Environments are in ...`:

~~bash
tail logs/build_envs_<jobid>.log
bash scripts/verify_envs.sh
/projects/$USER/conda_envs/fastp_env/bin/fastp --version    # run the real tool
~~

To build everything, run `sbatch scripts/build_envs.sbatch` with no arguments. To use your
own envs instead, delete the example specs in `envs/` and add yours (see below).
Always run `sbatch` from the repo root, because logs go to `logs/`.

## Partition, QOS, and account

Override at submit time. No need to edit the file:

~~bash
sbatch --partition=<partition> --qos=<qos> --account=<account> scripts/build_envs.sbatch
~~

If your paths differ from `/projects/$USER/...`:

~~bash
CONDA_BASE=/path/to/miniforge3 ENV_DIR=/path/to/conda_envs sbatch --export=ALL scripts/build_envs.sbatch
~~

## Repo layout

~~
envs/             one spec per environment (edit these)
  locked/         exact-version snapshots (*.full.yml)
scripts/          setup_conda.sh, make_envs.sh, new_env.sh,
                  export_env.sh, verify_envs.sh, build_envs.sbatch
logs/             Slurm logs (not committed)
docs/             notes on how this setup was migrated
~~

## Common tasks

Run these on a compute node (`sinteractive`), not the login node.

~~bash
bash scripts/make_envs.sh fastp_env                          # build one env
bash scripts/make_envs.sh                                    # build all (existing are skipped)
bash scripts/make_envs.sh --locked                           # build from exact-version snapshots
bash scripts/new_env.sh align_env python=3.11 samtools bwa   # write a spec and build it
bash scripts/export_env.sh align_env                         # snapshot to envs/locked/
~~

Or write a spec by hand, then run `bash scripts/make_envs.sh myenv`:

~~yaml
# envs/myenv.yml
name: myenv
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - samtools
~~

## Writing an environment spec (.yml)

Each environment is described by one YAML file in `envs/`. The simplest way to
make one is `bash scripts/new_env.sh <name> <packages...>`, which writes the file
for you. To write one by hand:

~~yaml
# envs/rnaseq_env.yml
name: rnaseq_env
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - samtools=1.20
  - hisat2
  - pandas>=2.0
  - pip
  - pip:
      - some-pypi-only-package
~~

What each part means:

- **`name`**: a label for the env. Set it to match the file name, because the scripts
  build into `<ENV_DIR>/<file name without .yml>`. So `envs/rnaseq_env.yml` becomes
  `/projects/$USER/conda_envs/rnaseq_env`, whatever `name:` says.
- **`channels`**: where conda looks for packages, in priority order. Use `conda-forge`
  first, then `bioconda` for bioinformatics tools. Keep that order, since mixing it up
  can cause conflicts.
- **`dependencies`**: the packages to install.
  - `samtools`: the latest compatible version.
  - `samtools=1.20`: that version (any build).
  - `pandas>=2.0`: a version range. Quote it in the file if you see parsing problems (`"pandas>=2.0"`).
  - Pin `python=3.x` if a tool needs a specific Python.
- **`pip:`**: only for packages that aren't on conda. List `pip` itself in
  `dependencies` first, then put the PyPI packages under `- pip:`.

**Finding package names:** search [anaconda.org](https://anaconda.org) or
[bioconda.github.io/recipes.html](https://bioconda.github.io/recipes.html), or run
`conda search -c conda-forge -c bioconda <name>` on the cluster.

**Making a spec from an env you already built:**

~~bash
conda env export -p /projects/$USER/conda_envs/myenv --from-history \
  | grep -v '^prefix:' > envs/myenv.yml
~~

`--from-history` lists only the packages you explicitly asked for, which gives a short,
readable spec. For exact versions of everything, use `bash scripts/export_env.sh myenv`
instead (it goes in `envs/locked/`).

**Test a new spec** before committing it:

~~bash
bash scripts/make_envs.sh rnaseq_env     # on a compute node
/projects/$USER/conda_envs/rnaseq_env/bin/samtools --version
~~

If the build fails with a conflict, remove the version pins one at a time to find the
culprit.

## Using an environment

Interactive:

~~bash
conda activate /projects/$USER/conda_envs/myenv
~~

In Slurm scripts, activate by **full path** so a same-named env elsewhere can never be picked up:

~~bash
source /projects/$USER/miniforge3/etc/profile.d/conda.sh
conda activate /projects/$USER/conda_envs/myenv
~~

## Rebuilding a broken or missing env

~~bash
conda env remove -p /projects/$USER/conda_envs/myenv
bash scripts/make_envs.sh myenv        # or: bash scripts/make_envs.sh --locked
~~

If an exact snapshot fails (old builds can disappear from channels), fall back to the plain spec.

## Verifying an env isn't broken

`bash scripts/verify_envs.sh` checks that each env has `conda-meta`, that `conda list`
works, and that `pip check` is clean (for envs with Python). Then run each env's main
program (for example `macs2 --version`). Some envs have no Python on purpose
(CLI-only tool envs), so a missing `bin/python` is not an error.

## Housekeeping

- Never create envs in `/scratch` or `~/.conda/envs`. Always build into `/projects`.
- Commit the specs: they are your backup.
- Never commit logs, or a `.full.yml` with a `prefix:` line (it contains your username).
  `export_env.sh` strips it. To clean existing files: `sed -i '/^prefix:/d' envs/locked/*.full.yml`
- `conda clean --all` frees cache space and doesn't touch existing envs.
- Check your `/projects` quota. Remove unused envs with `conda env remove -p <path>`.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `sbatch: error: invalid partition / qos / account` | Override at submit time: `sbatch --partition=... --qos=... --account=... scripts/build_envs.sbatch` |
| `conda: command not found` | Run `conda init bash`, then log out and back in. In job scripts, add `source /projects/$USER/miniforge3/etc/profile.d/conda.sh`. |
| Slurm error about `logs/` | Submit from the repo root. The `logs/` folder must exist. |
| `conda activate name` picks the wrong env | A same-named env exists in another `envs_dirs` path. Activate by full path. |
| `command not found` after activating | Package missing from the env. Check `conda list -p <path>`. |
| `error while loading shared libraries` | Broken env. Rebuild it. |
| Build is slow or killed | Don't build on the login node. Use `sbatch` or `sinteractive`. |
| `No module named ...` in a job | The job script didn't activate the env. Add the `source` and `conda activate` lines. |
| `hisat2 --version` prints `Compiler: ... ld returned 1` | Harmless build-info text in the binary, not a runtime error. |

## Background

How this setup was migrated from scratch to projects: [docs/MIGRATION_NOTES.md](docs/MIGRATION_NOTES.md).
