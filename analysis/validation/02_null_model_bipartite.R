# =============================================================================
# 02_null_model_bipartite.R — Degree-preserving bipartite null model for the
# structure of the 95th-percentile filtered co-sharing projection.
#
# Null model: Curveball algorithm (Strona et al. 2014, Nat. Commun.),
# implemented directly in C++ (analysis/validation/curveball.cpp; no external
# package). Each permutation performs 200 * n_accounts trades: pick two
# random account rows, keep their shared URLs, and randomly re-assign the
# non-shared URLs between them. This preserves BOTH margins of the bipartite
# incidence exactly (each account's number of URLs and each URL's number of
# accounts). 200N trades were chosen after a convergence check: at 5N-20N
# trades residual structure remains (null modularity ~0.35/~0.09); metrics
# stabilise from ~100N onwards (null modularity ~0.065-0.067).
#
# For every permuted incidence we rebuild the weighted projection, re-compute
# the 95th-percentile edge-weight threshold ON THE PERMUTED WEIGHTS (the same
# rule applied to the observed graph), filter, and compute five statistics:
#   1. n Louvain communities of size >= 5 (weighted Louvain)
#   2. Louvain modularity
#   3. global clustering coefficient (transitivity, unweighted)
#   4. n connected components of size >= 5
#   5. size of the largest connected component
#
# Empirical p-values: p_ge = (1 + #{null >= obs}) / (n_perm + 1)
#                     p_le = (1 + #{null <= obs}) / (n_perm + 1)
# (the largest-component statistic is expected to sit in the LOWER tail:
#  the observed graph is more fragmented than the null).
#
# Reproducibility: permutation b uses set.seed(20260705 + b). Chunked and
# resumable: results saved to data/validation/rds/null_bipartite_chunks/.
#
# Usage: Rscript 02_null_model_bipartite.R [n_permutations]  (default 1000)
# Output: data/validation/null_model_pvalues.csv
#         data/validation/rds/null_bipartite_perms.rds (all permuted values)
# =============================================================================

suppressMessages({
  library(data.table)
  library(Matrix)
  library(igraph)
  library(parallel)
  library(Rcpp)
})

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

args   <- commandArgs(trailingOnly = TRUE)
n_perm <- if (length(args) >= 1) as.integer(args[1]) else 1000L
n_cores <- max(1L, parallel::detectCores() - 2L)
chunk_size <- 25L
chunk_dir  <- "data/validation/rds/null_bipartite_chunks"
dir.create(chunk_dir, showWarnings = FALSE, recursive = TRUE)

B <- readRDS("data/validation/rds/bipartite_matrix.rds")
n_acct <- nrow(B)
n_trades <- 200L * n_acct

# Row-wise representation: list of URL column indices per account
Bt <- as(B, "TsparseMatrix")
rowlist <- split(Bt@j + 1L, factor(Bt@i + 1L, levels = seq_len(n_acct)))

# Compile the Curveball trade sequence (compiled in the parent process;
# forked mclapply workers inherit the loaded shared object)
sourceCpp("analysis/validation/curveball.cpp")

# ---- Metrics on a filtered projection ----------------------------------------
metrics_from_rowlist <- function(rl) {
  Bp <- sparseMatrix(i = rep.int(seq_along(rl), lengths(rl)),
                     j = unlist(rl, use.names = FALSE), x = 1,
                     dims = dim(B))
  P <- tcrossprod(Bp)
  diag(P) <- 0
  P  <- drop0(P)
  tr <- summary(P)                 # i, j, x triplets
  tr <- tr[tr$i < tr$j, ]          # each undirected edge once
  thr <- quantile(tr$x, 0.95, type = 7)
  keep <- tr[tr$x >= thr, ]
  g <- graph_from_data_frame(keep[, c("i", "j")], directed = FALSE)
  E(g)$weight <- keep$x
  cl   <- cluster_louvain(g, weights = E(g)$weight)
  comp <- components(g)
  c(louvain_communities_gte5 = sum(sizes(cl) >= 5),
    louvain_modularity       = modularity(cl),
    clustering_coefficient   = transitivity(g, type = "global"),
    n_components_gte5        = sum(comp$csize >= 5),
    largest_component        = max(comp$csize))
}

# ---- Observed values ----------------------------------------------------------
set.seed(20260705)
obs <- metrics_from_rowlist(rowlist)
message("Observed: ", paste(names(obs), round(obs, 3), sep = "=", collapse = "  "))

# ---- Permutations (chunked, resumable, parallel) -------------------------------
run_perm <- function(b) {
  set.seed(20260705 + b)
  rl <- curveball_cpp(rowlist, n_trades)
  metrics_from_rowlist(rl)
}

chunks <- split(seq_len(n_perm), ceiling(seq_len(n_perm) / chunk_size))
for (ci in seq_along(chunks)) {
  f <- file.path(chunk_dir, sprintf("chunk_%03d.rds", ci))
  if (file.exists(f)) next
  t0 <- Sys.time()
  res <- mclapply(chunks[[ci]], run_perm, mc.cores = n_cores)
  saveRDS(do.call(rbind, res), f)
  message(sprintf("chunk %d/%d done in %.1f min", ci, length(chunks),
                  as.numeric(Sys.time() - t0, units = "mins")))
}

perms <- do.call(rbind, lapply(seq_along(chunks), function(ci)
  readRDS(file.path(chunk_dir, sprintf("chunk_%03d.rds", ci)))))
perms <- perms[seq_len(min(nrow(perms), n_perm)), , drop = FALSE]
saveRDS(list(observed = obs, perms = perms, seed_base = 20260705,
             n_trades = n_trades), "data/validation/rds/null_bipartite_perms.rds")

# ---- p-values ------------------------------------------------------------------
np <- nrow(perms)
out <- data.table(
  metric    = names(obs),
  observed  = as.numeric(obs),
  null_mean = colMeans(perms),
  null_sd   = apply(perms, 2, sd),
  p_ge      = sapply(names(obs), function(m) (1 + sum(perms[, m] >= obs[m])) / (np + 1)),
  p_le      = sapply(names(obs), function(m) (1 + sum(perms[, m] <= obs[m])) / (np + 1)),
  n_permutations = np,
  seed_rule = "set.seed(20260705 + perm_index)"
)
fwrite(out, "data/validation/null_model_pvalues.csv")
print(out)
