#include <Rcpp.h>
#include <unordered_map>
#include <vector>
#include <cmath>
#include <cstdint>

#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

// [[Rcpp::plugins(cpp11)]]
// [[Rcpp::plugins(openmp)]]

static inline unsigned long long make_key(long long bx, long long by) {
  return (static_cast<unsigned long long>(static_cast<unsigned int>(bx)) << 32) |
         static_cast<unsigned int>(by);
}

class DSU {
public:
  std::vector<int> parent;
  std::vector<int> rank;

  DSU(int n) : parent(n), rank(n, 0) {
    for (int i = 0; i < n; ++i) parent[i] = i;
  }

  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void unite(int a, int b) {
    int ra = find(a);
    int rb = find(b);
    if (ra == rb) return;

    if (rank[ra] < rank[rb]) {
      parent[ra] = rb;
    } else if (rank[ra] > rank[rb]) {
      parent[rb] = ra;
    } else {
      parent[rb] = ra;
      rank[ra]++;
    }
  }
};

// [[Rcpp::export]]
int openmp_threads() {
#ifdef _OPENMP
  return omp_get_max_threads();
#else
  return 1;
#endif
}

// [[Rcpp::export]]
IntegerVector onecluster_omp(NumericVector east,
                             NumericVector north,
                             NumericVector count,
                             double radius) {
  int n = east.size();
  IntegerVector cluster(n);

  double r2 = radius * radius;
  double cell_size = radius;

  std::unordered_map<unsigned long long, std::vector<int> > bins;
  bins.reserve(n * 2);

  std::vector<int> valid_indices;
  valid_indices.reserve(n);

  for (int i = 0; i < n; ++i) {
    if (NumericVector::is_na(count[i]) || count[i] <= 0) continue;
    if (!std::isfinite(east[i]) || !std::isfinite(north[i])) continue;

    valid_indices.push_back(i);

    long long bx = static_cast<long long>(std::floor(east[i] / cell_size));
    long long by = static_cast<long long>(std::floor(north[i] / cell_size));

    bins[make_key(bx, by)].push_back(i);
  }

#ifdef _OPENMP
  int nthreads = omp_get_max_threads();
#else
  int nthreads = 1;
#endif

  std::vector<std::vector<std::pair<int, int> > > thread_edges(nthreads);

#pragma omp parallel
  {
#ifdef _OPENMP
    int tid = omp_get_thread_num();
#else
    int tid = 0;
#endif

    std::vector<std::pair<int, int> >& local_edges = thread_edges[tid];

#pragma omp for schedule(static)
    for (int idx = 0; idx < static_cast<int>(valid_indices.size()); ++idx) {
      int i = valid_indices[idx];

      long long bx = static_cast<long long>(std::floor(east[i] / cell_size));
      long long by = static_cast<long long>(std::floor(north[i] / cell_size));

      for (long long dx_bin = -1; dx_bin <= 1; ++dx_bin) {
        for (long long dy_bin = -1; dy_bin <= 1; ++dy_bin) {
          unsigned long long key = make_key(bx + dx_bin, by + dy_bin);
          auto it = bins.find(key);
          if (it == bins.end()) continue;

          const std::vector<int>& candidates = it->second;

          for (int j : candidates) {
            if (j <= i) continue;

            double dx = east[j] - east[i];
            double dy = north[j] - north[i];
            double d2 = dx * dx + dy * dy;

            if (d2 < r2) {
              local_edges.push_back(std::make_pair(i, j));
            }
          }
        }
      }
    }
  }

  DSU dsu(n);

  for (int t = 0; t < nthreads; ++t) {
    for (const auto& e : thread_edges[t]) {
      dsu.unite(e.first, e.second);
    }
  }

  std::unordered_map<int, int> root_to_cluster;
  int k = 1;

  for (int i = 0; i < n; ++i) {
    if (NumericVector::is_na(count[i]) || count[i] <= 0) continue;

    int root = dsu.find(i);

    auto it = root_to_cluster.find(root);
    if (it == root_to_cluster.end()) {
      root_to_cluster[root] = k;
      cluster[i] = k;
      k++;
    } else {
      cluster[i] = it->second;
    }
  }

  return cluster;
}
