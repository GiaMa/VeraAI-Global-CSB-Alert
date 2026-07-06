// Curveball algorithm (Strona et al. 2014, Nature Communications 5:4114)
// for degree-preserving randomisation of a bipartite 0/1 incidence matrix.
//
// Representation: list of integer vectors, one per account row, holding the
// (1-based) URL column indices of that row. Each trade picks two random
// rows, keeps the URLs they share, and randomly re-assigns the non-shared
// URLs between them, preserving both row and column sums exactly.
//
// Uses R's RNG (unif_rand), so results are reproducible via set.seed().

#include <Rcpp.h>
#include <algorithm>
#include <vector>
using namespace Rcpp;

// [[Rcpp::export]]
List curveball_cpp(List rowlist, int n_trades) {
  int n = rowlist.size();
  std::vector<std::vector<int>> rows(n);
  for (int i = 0; i < n; ++i) {
    IntegerVector v = rowlist[i];
    rows[i] = std::vector<int>(v.begin(), v.end());
    std::sort(rows[i].begin(), rows[i].end());
  }
  std::vector<int> shared, only_a, only_b, pool;
  for (int t = 0; t < n_trades; ++t) {
    int a = (int)(unif_rand() * n);
    int b = (int)(unif_rand() * n);
    if (a == b) { --t; continue; }
    std::vector<int>& A = rows[a];
    std::vector<int>& B = rows[b];
    shared.clear(); only_a.clear(); only_b.clear();
    std::set_intersection(A.begin(), A.end(), B.begin(), B.end(),
                          std::back_inserter(shared));
    std::set_difference(A.begin(), A.end(), shared.begin(), shared.end(),
                        std::back_inserter(only_a));
    std::set_difference(B.begin(), B.end(), shared.begin(), shared.end(),
                        std::back_inserter(only_b));
    int la = only_a.size(), lb = only_b.size();
    if (la == 0 || lb == 0) continue;
    pool = only_a;
    pool.insert(pool.end(), only_b.begin(), only_b.end());
    // Fisher-Yates partial shuffle: first la elements become row a's share
    int m = pool.size();
    for (int i = 0; i < la; ++i) {
      int j = i + (int)(unif_rand() * (m - i));
      std::swap(pool[i], pool[j]);
    }
    A.assign(shared.begin(), shared.end());
    A.insert(A.end(), pool.begin(), pool.begin() + la);
    std::sort(A.begin(), A.end());
    B.assign(shared.begin(), shared.end());
    B.insert(B.end(), pool.begin() + la, pool.end());
    std::sort(B.begin(), B.end());
  }
  List out(n);
  for (int i = 0; i < n; ++i) out[i] = IntegerVector(rows[i].begin(), rows[i].end());
  return out;
}
