#include <Rcpp.h>
#include <unordered_map>
#include <vector>
#include <algorithm>
#include <cmath>
#include <cstdint>

#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

// [[Rcpp::plugins(cpp11)]]
// [[Rcpp::plugins(openmp)]]

static inline unsigned long long make_key_close(long long bx, long long by) {
  return (static_cast<unsigned long long>(static_cast<unsigned int>(bx)) << 32) |
         static_cast<unsigned int>(by);
}

struct Neighbor {
  double d2;
  int idx;
};

static inline bool neighbor_less(const Neighbor& a, const Neighbor& b) {
  if (a.d2 == b.d2) return a.idx < b.idx;
  return a.d2 < b.d2;
}

// [[Rcpp::export]]
int close_openmp_threads() {
#ifdef _OPENMP
  return omp_get_max_threads();
#else
  return 1;
#endif
}

// [[Rcpp::export]]
IntegerVector close_count_omp(NumericVector east_in,
                              NumericVector north_in,
                              NumericVector radar_in,
                              double threshold,
                              double radius,
                              int kmax = 25) {
  int n = east_in.size();

  std::vector<double> east(n), north(n), radar(n);
  for (int i = 0; i < n; ++i) {
    east[i] = east_in[i];
    north[i] = north_in[i];
    radar[i] = radar_in[i];
  }

  double r2 = radius * radius;
  double cell_size = radius;

  std::unordered_map<unsigned long long, std::vector<int> > bins;
  bins.reserve(n * 2);

  for (int i = 0; i < n; ++i) {
    if (!std::isfinite(east[i]) || !std::isfinite(north[i])) continue;

    long long bx = static_cast<long long>(std::floor(east[i] / cell_size));
    long long by = static_cast<long long>(std::floor(north[i] / cell_size));

    bins[make_key_close(bx, by)].push_back(i);
  }

  std::vector<int> counts(n, 0);

#pragma omp parallel for schedule(static)
  for (int i = 0; i < n; ++i) {
    if (!std::isfinite(east[i]) || !std::isfinite(north[i])) continue;

    long long bx = static_cast<long long>(std::floor(east[i] / cell_size));
    long long by = static_cast<long long>(std::floor(north[i] / cell_size));

    std::vector<Neighbor> neighbors;
    neighbors.reserve(kmax);

    for (long long dx_bin = -1; dx_bin <= 1; ++dx_bin) {
      for (long long dy_bin = -1; dy_bin <= 1; ++dy_bin) {
        unsigned long long key = make_key_close(bx + dx_bin, by + dy_bin);
        auto it = bins.find(key);
        if (it == bins.end()) continue;

        const std::vector<int>& candidates = it->second;

        for (int j : candidates) {
          double dx = east[j] - east[i];
          double dy = north[j] - north[i];
          double d2 = dx * dx + dy * dy;

          if (d2 >= 0.0 && d2 < r2) {
            Neighbor nb;
            nb.d2 = d2;
            nb.idx = j;
            neighbors.push_back(nb);
          }
        }
      }
    }

    if (neighbors.empty()) continue;

    std::sort(neighbors.begin(), neighbors.end(), neighbor_less);

    int use_k = std::min(static_cast<int>(neighbors.size()), kmax);

    double sum = 0.0;
    int valid_n = 0;

    for (int a = 0; a < use_k; ++a) {
      double v = radar[neighbors[a].idx];
      if (!std::isnan(v)) {
        sum += v;
        valid_n++;
      }
    }

    if (valid_n == 0) continue;

    double mean_value = sum / valid_n;

    if (mean_value >= threshold) {
      for (int a = 0; a < use_k; ++a) {
        int j = neighbors[a].idx;
#pragma omp atomic update
        counts[j] += 1;
      }
    }
  }

  IntegerVector out(n);
  for (int i = 0; i < n; ++i) {
    out[i] = counts[i];
  }

  return out;
}
