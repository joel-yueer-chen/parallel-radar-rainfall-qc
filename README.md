# Parallel Radar Rainfall Quality Control

This repository contains a high-performance computing workflow for radar-assisted rainfall quality control, developed as part of a Met Éireann / Trinity College Dublin HPC project.

The project focuses on accelerating a multi-stage rainfall quality control pipeline using R, Rcpp, C++, OpenMP, Slurm and data.table.

Large input data files and full-year output CSV files are not included in this repository.

## Project scope

This is not a single DBSCAN algorithm exercise. It is part of a larger multi-stage radar-assisted rainfall quality control workflow.

The overall project aims to reproduce the original rainfall quality control workflow on HPC, identify runtime bottlenecks, optimise I/O and spatial processing, benchmark Slurm/OpenMP configurations, validate optimised outputs, and extend the workflow to later stages such as `radar_rain_grid.R`.

## Stage 1: DBSCAN-like heavy rainfall connected-area workflow

Stage 1 has been completed and validated on Seagull.

The workflow reads daily radar grid rainfall files, applies an Ireland mask, joins radar grid metadata, computes local rainfall support counts, labels connected rainfall areas, and writes per-date output CSV files.

The key implementation files are:

- `Script/code/DBSCAN1_mpi_2025_fread_fwrite_1t16th.R`
- `Script/code/close_omp.cpp`
- `Script/code/onecluster_omp.cpp`
- `Script/code/run_dbscan_2025_fread_fwrite_1t16th.slurm`

The main R script coordinates the full-year workflow. The two C++ files implement the spatial neighbourhood and connected-component calculations using OpenMP. The Slurm script is the official Seagull 1x16 script corresponding to the best validated Seagull job.

## Current best Seagull configuration

The best-performing validated Seagull configuration is:

- Job ID: 43926
- Configuration: 1 MPI-style Slurm task x 16 OpenMP threads
- I/O method: data.table::fread/fwrite
- Runtime: 00:08:50
- Allocated CPUs: 16
- Node: seagull-n001
- Output: 180 CSV files, approximately 3.4 GB
- Validation: PASS against the 2x8 output

The controlled Seagull benchmark baseline was job 43916:

- Job 43916: 8 MPI-style tasks x 2 OpenMP threads, read.csv/write.csv, 20:24
- Job 43926: 1 MPI-style task x 16 OpenMP threads, fread/fwrite, 08:50

This gives a controlled speedup of 2.31x and a runtime reduction of 56.7%.

The original Met Éireann workflow before this project reportedly required approximately three days. This should be distinguished from the controlled Seagull benchmark baseline, which is the reproducible baseline used for the formal benchmark table.

## Important note on MPI-style parallelism

The workflow does not use a formal MPI library such as Rmpi. Instead, it uses Slurm environment variables such as `SLURM_PROCID` and `SLURM_NTASKS` to distribute dates across tasks.

For this reason, the project refers to this as MPI-style date parallelism rather than strict MPI message passing.

The Seagull benchmark showed that the workflow performed best when using fewer Slurm tasks and more OpenMP threads per task. The final best configuration used one task and sixteen OpenMP threads.

## Data not included

The following large data files are not included in this repository:

- `Data/radar_grid/*.csv`
- `Data/radar_geo.csv`
- `Data/inside_ireland_mask.csv`
- `Script/rain/dailyqced.csv`
- Full-year output CSV files

The repository contains code, Slurm scripts, and benchmark documentation only.

## Next stage

The next stage of the project is to analyse and optimise `radar_rain_grid.R`.

This stage has not yet been optimised. The correct next step is to inspect the script structure, identify inputs and outputs, map dependencies, run a safe small-date test, profile bottlenecks, and only then attempt optimisation or a full-year run.
