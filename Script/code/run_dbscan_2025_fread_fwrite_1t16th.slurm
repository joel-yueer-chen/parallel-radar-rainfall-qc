#!/bin/bash
#SBATCH --job-name=dbscan_fread1x16
#SBATCH --output=/projects/bignellr/cheny35/DBSCAN_SCRIPT/logs/dbscan_fread1x16_%j.out
#SBATCH --error=/projects/bignellr/cheny35/DBSCAN_SCRIPT/logs/dbscan_fread1x16_%j.err
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=24G

set -e
set -x

echo "Job started at:"
date

echo "Running on node:"
hostname

echo "Current directory:"
pwd

export R_LIBS_USER=/projects/bignellr/cheny35/Rlibs
export TMPDIR=/projects/bignellr/cheny35/tmp
export PKG_CXXFLAGS="-fopenmp"
export PKG_LIBS="-fopenmp"
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

echo "SLURM_NTASKS:"
echo $SLURM_NTASKS

echo "OMP_NUM_THREADS per task:"
echo $OMP_NUM_THREADS

echo "Start running full year 2025 fixed MPI-style across dates:"
srun --kill-on-bad-exit=1 --cpu-bind=cores Rscript /projects/bignellr/cheny35/DBSCAN_SCRIPT/Script/code/DBSCAN1_mpi_2025_fread_fwrite_1t16th.R

echo "Job finished at:"
date
