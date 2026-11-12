# Conda Environments on Alpine

Notes on where my conda environments live, why they were moved, and how to create new ones.

## Background: why this exists

On Alpine, `/scratch` files are purged after 90 days. Conda envs that were
created in scratch (or in the default `~/.conda/envs` location) were being
deleted, which broke pipelines. The fix was to rebuild every env in
`/projects`, which is not purged, and to point conda at that location by default.

## Layout

```
/projects/$USER/
├── miniforge3/        # conda install (base env)
├── conda_envs/        # <-- ALL environments live here
├── conda_pkgs/        # package cache (also kept off scratch)
└── CondaEnvs/         # recipes, build scripts, logs (the backup)
    ├── <name>.yml         # minimal spec (what I asked for)
    ├── <name>.full.yml    # full export (exact versions, for rebuilding)
    ├── make_envs.sh / build_envs.sbatch   # scripts used to rebuild everything
    └── build_envs_<jobid>.log             # log from the rebuild job
```

## Current environments

All are in `/projects/$USER/conda_envs/`.

| Env | Main tools |
|---|---|
| `annot_env` | hmmer, seqkit, transdecoder, diamond (no Python by design) |
| `deeptools_kernel_v2` | deeptools |
| `fastp_env` | fastp |
| `hisat2_env_fixed` | hisat2 |
| `hisat2_env` | hisat2 (duplicate of `_fixed`, safe to remove) |
| `homer_env` | HOMER |
| `macs2_env` | macs2 |
| `miniprot_env` | miniprot |
| `pandas_env` | pandas, numpy |
| `rnaPseudo_clean2` | pandas, pysam, scipy |

## How the migration worked

1. Exported each env's spec to YAML (`<name>.yml` and `<name>.full.yml`).
2. Rebuilt each env into `/projects/.../conda_envs` using
   `conda env create -p <path> -f <name>.yml`, run as a Slurm job
   (`build_envs.sbatch`) so it didn't tie up the login node.
3. Checked the build log for errors (`grep -iE "error|fail" build_envs_*.log`).
4. Verified each env: structure check, `conda list`, `pip check`, and running
   the main tool from each env.
5. Removed the old scratch locations from `envs_dirs` and deleted the stale
   scratch copies.

## One-time conda configuration

Already done, listed here in case it needs redoing (for example on a new account).

```bash
conda config --add envs_dirs /projects/$USER/conda_envs
conda config --add pkgs_dirs /projects/$USER/conda_pkgs
```

Make sure `conda_envs` is listed **first** in `envs_dirs`:

```bash
conda config --show envs_dirs
conda config --show pkgs_dirs
conda config --show-sources     # shows which file each setting comes from (~/.condarc)
```

`conda config --remove` only works on entries you added yourself. Built-in
defaults (like `miniforge3/envs`) will error with "not present in config" and
can be ignored.

## Making a new environment

Run this on a compute node (`sinteractive` or `sbatch`), not the login node,
for anything beyond a tiny env.

### 1. Write a spec file (recommended)

Save it in `/projects/$USER/CondaEnvs/`:

```yaml
# myenv.yml
name: myenv
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - samtools
  - bedtools
```

### 2. Build it into /projects

```bash
conda env create -p /projects/$USER/conda_envs/myenv \
    -f /projects/$USER/CondaEnvs/myenv.yml
```

Always use `-p <full path>`. This guarantees it goes to `/projects` regardless
of config.

### Quick one-liner (no spec file)

```bash
conda create -p /projects/$USER/conda_envs/myenv \
    -c conda-forge -c bioconda python=3.11 samtools
```

### 3. Back it up

Export the exact installed versions right after it works:

```bash
conda env export -p /projects/$USER/conda_envs/myenv \
    > /projects/$USER/CondaEnvs/myenv.full.yml
```

### 4. Verify it

```bash
E=/projects/$USER/conda_envs
conda list -p $E/myenv | head          # packages installed?
$E/myenv/bin/samtools --version         # run the actual tool
$E/myenv/bin/python -m pip check        # only if the env has Python
```

An env that has no Python (like `annot_env`) won't have `bin/python`. That is
normal. Test its tools instead.

## Using environments

Interactive:

```bash
conda activate /projects/$USER/conda_envs/macs2_env
```

In Slurm scripts, **always activate by full path** so a stray copy with the
same name can never be picked up:

```bash
source /projects/$USER/miniforge3/etc/profile.d/conda.sh
conda activate /projects/$USER/conda_envs/macs2_env
```

## Installing more packages into an existing env

```bash
conda install -p /projects/$USER/conda_envs/myenv -c conda-forge somepackage
```

Then re-export the `.full.yml` and update the `.yml` so the backup stays current.

## Rebuilding an env that broke or disappeared

```bash
conda env remove -p /projects/$USER/conda_envs/myenv
conda env create -p /projects/$USER/conda_envs/myenv \
    -f /projects/$USER/CondaEnvs/myenv.yml
```

Use the `.full.yml` instead of `.yml` if you need the exact same versions.
It may fail on a different platform or if old builds were removed from the
channels, in which case fall back to the minimal `.yml`.

## Housekeeping

- Never create envs in `/scratch` or `~/.conda/envs`.
- Keep the `.yml` and `.full.yml` files. They are the backup.
- `/projects` has a quota. Check usage occasionally and remove unused envs
  with `conda env remove -p <path>`.
- Clean the package cache sometimes: `conda clean --all` (frees space, does
  not affect existing envs).
- Don't use `rm -rf` on an env without checking the path first.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `conda activate myenv` picks the wrong env | A same-named env exists in another `envs_dirs` path. Activate by full path. |
| `command not found` after activating | Env missing that package, or activation failed. Run `conda list -p <path>`. |
| `error while loading shared libraries` | Broken env. Rebuild it from its `.yml`. |
| Env build killed or very slow | Don't build on the login node. Use `sinteractive` or `sbatch`. |
| `hisat2 --version` prints `Compiler: ... error: ld returned 1` | Harmless. It's build-info text baked into the binary, not a runtime error. |
| `No module named ...` in a job | Script didn't activate the env. Add the `source .../conda.sh` and `conda activate <full path>` lines. |

---

## Using this repo (current layout)

The repo was reorganized after the notes above were written. Specs now live in
`envs/` (exact-version snapshots in `envs/locked/`) and scripts in `scripts/`.
Where the notes above refer to `CondaEnvs/<name>.yml` or `make_envs.sh`, use
`envs/<name>.yml` and `scripts/make_envs.sh`.

~~
envs/             one spec per environment (edit these)
  locked/         exact-version snapshots (*.full.yml)
scripts/          setup_conda.sh, make_envs.sh, new_env.sh,
                  export_env.sh, verify_envs.sh, build_envs.sbatch
logs/             Slurm logs (not committed)
~~

### Quick start (for anyone cloning this)

Prerequisite: conda or Miniforge installed at `/projects/$USER/miniforge3`.

~~bash
git clone https://github.com/yates13/Alpine_Conda_Envs.git
cd Alpine_Conda_Envs

bash scripts/setup_conda.sh            # one-time: envs + package cache go to /projects
sbatch scripts/build_envs.sbatch       # build every spec in envs/ as a Slurm job
bash scripts/verify_envs.sh            # when the job finishes
~~

Run `sbatch` from the repo root. Logs appear in `logs/`. The specs in `envs/`
are examples from a CUT&RUN / RNA-seq pipeline; delete or replace them with your own.

### Common tasks (run on a compute node, not the login node)

~~bash
bash scripts/make_envs.sh fastp_env                          # build one env
bash scripts/make_envs.sh                                    # build all (existing are skipped)
bash scripts/make_envs.sh --locked                           # build from exact-version snapshots
bash scripts/new_env.sh align_env python=3.11 samtools bwa   # write a spec and build it
bash scripts/export_env.sh myenv                             # snapshot to envs/locked/myenv.full.yml
~~

Paths default to `/projects/$USER/...`. Override with `ENV_DIR` and `CONDA_BASE`
if yours differ:

~~bash
CONDA_BASE=/path/to/miniforge3 ENV_DIR=/path/to/conda_envs sbatch --export=ALL scripts/build_envs.sbatch
~~

### Partition and QOS

`scripts/build_envs.sbatch` defaults to `--partition=acpu --qos=cpu-normal`.
If your account uses different names, override them at submit time without editing the file:

~~bash
sbatch --partition=<your-partition> --qos=<your-qos> scripts/build_envs.sbatch
~~
