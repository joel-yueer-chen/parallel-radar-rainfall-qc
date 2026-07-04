# Seagull Benchmark Results

Benchmarks were run on the Seagull HPC cluster using one compute node with 16 CPUs.

| Job ID | Configuration | I/O Method | Runtime | CPUs | Validation |
|---|---:|---|---:|---:|---|
| 43916 | 8 MPI tasks × 2 OpenMP threads | read.csv/write.csv | 20:24 | 16 | PASS |
| 43919 | 8 MPI tasks × 2 OpenMP threads | fread/fwrite | 10:35 | 16 | PASS |
| 43921 | 4 MPI tasks × 4 OpenMP threads | fread/fwrite | 09:48 | 16 | PASS |
| 43923 | 3 MPI tasks × 5 OpenMP threads | fread/fwrite | 09:33 | 15 | PASS |
| 43925 | 2 MPI tasks × 8 OpenMP threads | fread/fwrite | 09:14 | 16 | PASS |
| 43926 | 1 MPI task × 16 OpenMP threads | fread/fwrite | 08:50 | 16 | PASS |

The best-performing Seagull configuration was 1 MPI task × 16 OpenMP threads, completing the full-year workflow in 8 minutes 50 seconds.
