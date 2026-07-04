# Parallel Radar Rainfall Quality Control

This repository contains a high-performance computing workflow for radar-assisted rainfall quality control using R, Rcpp, C++, OpenMP, Slurm and data.table.

The workflow was benchmarked on the Seagull HPC cluster and is being extended for testing on Callan.

## Current Seagull best configuration

The best-performing Seagull configuration was:

- 1 MPI task
- 16 OpenMP threads
- data.table::fread/fwrite I/O
- Full-year 2025 runtime: 8 minutes 50 seconds

Large input data files and full-year outputs are not included in this repository.
