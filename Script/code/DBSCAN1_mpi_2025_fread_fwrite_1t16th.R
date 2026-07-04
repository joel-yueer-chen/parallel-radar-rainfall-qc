rm(list = ls())
gc()

library(sp)
# library(dplyr)   # not needed for this script
library(RANN)
library(Rcpp)
.libPaths(c("/projects/bignellr/cheny35/Rlibs", .libPaths()))
library(data.table)
setDTthreads(as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "1")))

close_function <- function(df, threshold, radius, tol, colname = "cluster_count") {
  radius_max <- radius + tol
  df[[colname]] <- close_count_omp(
    df$east,
    df$north,
    df$radar_value,
    threshold,
    radius_max,
    25L
  )
  df
}

onecluster_function <- function(df, colname, dist_target, tol) {
  df$id <- seq_len(nrow(df))
  cluster_colname <- sub("count", "num", colname)
  radius <- dist_target + tol
  df[[cluster_colname]] <- onecluster_omp(
    df$east,
    df$north,
    df[[colname]],
    radius
  )
  return(df)
}

base_dir <- "/projects/bignellr/cheny35/DBSCAN_SCRIPT"

sourceCpp(file.path(base_dir, "Script/code/onecluster_omp.cpp"))
sourceCpp(file.path(base_dir, "Script/code/close_omp.cpp"))
cat("Close OpenMP max threads:", close_openmp_threads(), "\n")
cat("OpenMP max threads:", openmp_threads(), "\n")

file_path <- file.path(base_dir, "Data/radar_grid")
out_dir <- file.path(base_dir, "results_full_year_2025_fread_fwrite_1t16th")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

mask <- as.data.frame(fread(file.path(base_dir, "Data/inside_ireland_mask.csv")))
mask$row <- round(mask$row)
mask$col <- round(mask$col)

dates <- list.files(
  file_path,
  pattern = "^2025-[0-9]{2}-[0-9]{2}\\.csv$",
  full.names = FALSE
)

dates <- sort(dates)

rank <- as.integer(Sys.getenv("SLURM_PROCID", unset = "0"))
ntasks <- as.integer(Sys.getenv("SLURM_NTASKS", unset = "1"))

if (is.na(rank)) rank <- 0
if (is.na(ntasks) || ntasks < 1) ntasks <- 1

all_dates <- dates
my_idx <- which(((seq_along(all_dates) - 1) %% ntasks) == rank)
dates <- all_dates[my_idx]

cat("MPI-style date parallelism for full year 2025\\n")
cat("Rank:", rank, "of", ntasks, "\\n")
cat("Number of 2025 files total:", length(all_dates), "\\n")
cat("Dates assigned to this rank:\\n")
print(dates)
cat("\\n")

# Version 2: use precomputed Ireland boundary mask

geo <- as.data.frame(fread(file.path(base_dir, "Data/radar_geo.csv")))
geo$east <- round(geo$east)
geo$north <- round(geo$north)

df_rain <- as.data.frame(fread(file.path(base_dir, "Script/rain/dailyqced.csv")))
df_rain$date <- as.Date(with(df_rain, paste(year, month, day, sep = "-")))

df_rain <- df_rain[
  df_rain$ind %in% c(
    "qc_ok",
    "regression",
    "regression & bootstrap",
    "bootstrapping",
    "regression_reject"
  ),
]

i <- 1

while (i <= length(dates)) {
  current_date <- as.Date(sub("\\.csv$", "", dates[i]))
  rain_sub <- df_rain[df_rain$date == current_date, ]
  
  mean_r <- mean(rain_sub$rainfall, na.rm = TRUE)
  any_over10 <- any(rain_sub$rainfall > 10, na.rm = TRUE)
  
  if (is.na(mean_r)) {
    print(paste0("no gauge", dates[i]))
    i <- i + 1
    next
  }

  if (isTRUE(mean_r > 1) || isTRUE(any_over10)) {
    
    cat("\nProcessing:", dates[i], "\n")
    
    t_total <- system.time({
      
      t_read <- system.time({
        df <- as.data.frame(fread(file.path(file_path, dates[i])))
      })
      
      if (boxplot.stats(df$value1)$stats[5] == 0) {
        print(paste0("no radar", dates[i]))
      } else {
        
t_mask_filter <- system.time({
  df$row <- round(df$row)
  df$col <- round(df$col)
  df$orig_order <- seq_len(nrow(df))
  df <- merge(mask, df, by = c("row", "col"), sort = FALSE)
  df <- df[order(df$orig_order), ]
  df <- df[, c("row", "col", "value1")]
  colnames(df) <- c("east", "north", "radar_value")
  df$east <- round(df$east)
  df$north <- round(df$north)
  df$mean_r <- mean_r
})
        
        t_merge <- system.time({
          df <- merge(df, geo, by = c("east", "north"))
        })
        
        if (nrow(df) < 70000) {
          print(paste0("geo wrong", dates[i]))
        } else {
          
          threshold <- boxplot.stats(df$radar_value)$stats[5]
          
          cat("threshold:", threshold, "\n")
          cat("rows after mask + geo merge:", nrow(df), "\n")
          
          t_close_2km <- system.time({
            df <- close_function(
              df,
              threshold,
              radius = 2000,
              tol = 100,
              colname = "cluster_count_2km"
            )
          })
          
          t_close_1km <- system.time({
            df <- close_function(
              df,
              threshold,
              radius = 1000,
              tol = 50,
              colname = "cluster_count_1km"
            )
          })
          
          t_cluster_1km <- system.time({
            df <- onecluster_function(
              df,
              colname = "cluster_count_1km",
              dist_target = 1000,
              tol = 50
            )
          })
          
          t_cluster_2km <- system.time({
            df <- onecluster_function(
              df,
              colname = "cluster_count_2km",
              dist_target = 2000,
              tol = 100
            )
          })
          
          t_write <- system.time({
            fwrite(df, file.path(out_dir, dates[i]))
          })
          
          cat("Timing for", dates[i], "\n")
          print(rbind(
            read_csv = t_read,
            mask_filter = t_mask_filter,
            merge_geo = t_merge,
            close_2km = t_close_2km,
            close_1km = t_close_1km,
            cluster_1km = t_cluster_1km,
            cluster_2km = t_cluster_2km,
            write_csv = t_write
          ))
          
          print(paste0("finish", dates[i]))
        }
      }
    })
    
    cat("Total time for", dates[i], ":\n")
    print(t_total)
    
    i <- i + 1
    
  } else {
    print(paste0("no rain", dates[i]))
    i <- i + 1
  }
}
