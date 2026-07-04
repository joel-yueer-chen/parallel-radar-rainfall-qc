#!/bin/bash
#SBATCH --job-name=radar_callan_1x64
#SBATCH --output=logs/callan_1x64_%j.out
#SBATCH --error=logs/callan_1x64_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --time=01:00:00

cd $SLURM_SUBMIT_DIR

export DBSCAN_BASE_DIR=$SLURM_SUBMIT_DIR
export DBSCAN_OUT_DIR=results_callan_1x64

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PROC_BIND=close
export OMP_PLACES=cores

mkdir -p logs $DBSCAN_OUT_DIR

Rscript Script/code/DBSCAN1_mpi_2025_fread_fwrite.R
