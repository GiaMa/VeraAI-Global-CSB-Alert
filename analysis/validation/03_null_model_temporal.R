# =============================================================================
# 03_null_model_temporal.R — Temporally stratified null model.
#
# Rationale: the Curveball null (02) destroys the temporal alignment of
# activity. This null preserves WEEKLY activity volumes: within each ISO week
# of alert_date, the account labels of that week's alert-level incidence rows
# (account x URL x alert occurrences) are randomly permuted across rows.
# Every account keeps its number of weekly appearances and every URL keeps
# its weekly number of coordinated-account slots; only the account-URL
# assignment is randomised within the week.
#
# After shuffling, the account x URL incidence is deduplicated, projected,
# filtered at the (re-computed) 95th-percentile edge weight, and the same
# five statistics as in 02 are computed. 200 permutations.
#
# Reproducibility: permutation b uses set.seed(31415 + b).
# Usage : Rscript 03_null_model_temporal.R [n_permutations]   (default 200)
# Output: data/validation/null_model_temporal.csv
#         data/validation/rds/null_temporal_perms.rds
# =============================================================================

suppressMessages({
  library(data.table)
  library(Matrix)
  library(igraph)
  library(parallel)
})

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

args   <- commandArgs(trailingOnly = TRUE)
n_perm <- if (length(args) >= 1) as.integer(args[1]) else 200L
n_cores <- max(1L, parallel::detectCores() - 2L)

incidence <- readRDS("data/validation/rds/incidence.rds")
incidence[, iso_week := format(alert_date, "%G-W%V")]

acct_levels <- sort(unique(incidence$acct))
url_levels  <- sort(unique(incidence$url))
inc <- data.table(ai = match(incidence$acct, acct_levels),
                  ui = match(incidence$url, url_levels),
                  wk = incidence$iso_week)
setorder(inc, wk)   # contiguous week blocks; within-week shuffles stay aligned
dims <- c(length(acct_levels), length(url_levels))

metrics_from_pairs <- function(ai, ui) {
  Bp <- sparseMatrix(i = ai, j = ui, x = 1, dims = dims, use.last.ij = TRUE)
  P <- tcrossprod(Bp)
  diag(P) <- 0
  P  <- drop0(P)
  tr <- summary(P)
  tr <- tr[tr$i < tr$j, ]
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

set.seed(31415)
obs <- metrics_from_pairs(inc$ai, inc$ui)
message("Observed: ", paste(names(obs), round(obs, 3), sep = "=", collapse = "  "))

run_perm <- function(b) {
  set.seed(31415 + b)
  # inc is sorted by wk, so by = wk returns groups in row order and the
  # concatenated shuffled labels align 1:1 with inc's rows
  ai_shuf <- inc[, .(ai = ai[sample.int(.N)]), by = wk]$ai
  metrics_from_pairs(ai_shuf, inc$ui)
}

t0 <- Sys.time()
perms <- do.call(rbind, mclapply(seq_len(n_perm), run_perm, mc.cores = n_cores))
message(sprintf("%d permutations in %.1f min", n_perm,
                as.numeric(Sys.time() - t0, units = "mins")))
saveRDS(list(observed = obs, perms = perms, seed_base = 31415),
        "data/validation/rds/null_temporal_perms.rds")

np <- nrow(perms)
out <- data.table(
  metric    = names(obs),
  observed  = as.numeric(obs),
  null_mean = colMeans(perms),
  null_sd   = apply(perms, 2, sd),
  p_ge      = sapply(names(obs), function(m) (1 + sum(perms[, m] >= obs[m])) / (np + 1)),
  p_le      = sapply(names(obs), function(m) (1 + sum(perms[, m] <= obs[m])) / (np + 1)),
  n_permutations = np,
  seed_rule = "set.seed(31415 + perm_index)"
)
fwrite(out, "data/validation/null_model_temporal.csv")
print(out)
