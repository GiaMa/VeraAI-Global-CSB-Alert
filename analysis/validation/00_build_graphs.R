# =============================================================================
# 00_build_graphs.R — Build the account x URL bipartite incidence and the
# account-account co-sharing projections used by the whole validation suite.
#
# Input : data/alerts/veraai_alerts_links.csv (10,681 URL-alert records)
# Output: data/validation/rds/incidence.rds        (data.table: acct, url,
#           alert_id, alert_date — one row per account-URL-alert occurrence)
#         data/validation/rds/bipartite_matrix.rds (sparse 0/1 incidence,
#           rows = accounts, cols = URLs; entry 1 iff the account appeared in
#           >=1 coordination alert for that URL)
#         data/validation/rds/projection_full.rds  (igraph, weighted; weight =
#           number of distinct URLs the two accounts co-appeared on)
#         data/validation/rds/projection_p95.rds   (igraph; edges with weight
#           >= 95th percentile of full-projection edge weights, quantile
#           type 7; isolated vertices dropped)
#         data/validation/graph_summary.csv
#
# Construct definitions
# ---------------------
# "Coordinated account" = an entry of the comma-separated `coo_r_account_url`
# field of an alert record (the accounts CooRnet flagged as coordinated
# around that URL). This is DISTINCT from `account_url` (the account whose
# post triggered the alert row).
#
# CORRECTION (see 01_expansion_dynamics.R, POPULATION DEFINITIONS): an
# earlier revision of this header claimed the two populations are disjoint.
# They are not. That reading came from treating `account_url` as a single
# value when it is itself a comma-separated LIST; split properly, the posting
# population (20,450) is a strict SUPERSET of the coordinated one (14,832).
# Do not reuse the disjointness claim.
#
# The bipartite incidence is DEDUPLICATED at (account, URL) level: an account
# that co-shared the same URL in several alerts contributes a single 1.
# Projection weight = number of distinct shared URLs. The 95th-percentile
# threshold is computed on the vector of projection edge weights (each
# undirected edge counted once) and edges with weight >= threshold are kept
# (this convention exactly reproduces the published observed metrics).
# =============================================================================

suppressMessages({
  library(data.table)
  library(Matrix)
  library(igraph)
})

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

set.seed(20260705)  # Louvain in igraph uses randomised vertex order

alerts <- fread("data/alerts/veraai_alerts_links.csv")
stopifnot(nrow(alerts) == 10681)

# ---- Long incidence: one row per (alert row) x coordinated account --------
splits <- strsplit(alerts$coo_r_account_url, ",", fixed = TRUE)
incidence <- data.table(
  acct       = trimws(unlist(splits)),
  url        = rep(alerts$url,        lengths(splits)),
  alert_id   = rep(alerts$alert_id,   lengths(splits)),
  alert_date = rep(as.Date(alerts$alert_date), lengths(splits))
)
incidence <- incidence[acct != ""]

# ---- Deduplicated account x URL pairs --------------------------------------
au <- unique(incidence[, .(acct, url)])

n_accounts <- uniqueN(au$acct)   # expect 14,832
n_urls     <- uniqueN(au$url)    # expect  8,618
message("Distinct coordinated accounts: ", n_accounts)
message("Distinct URLs:                 ", n_urls)

# ---- (a) Bipartite sparse incidence matrix ---------------------------------
acct_f <- factor(au$acct)
url_f  <- factor(au$url)
B <- sparseMatrix(i = as.integer(acct_f), j = as.integer(url_f), x = 1)
rownames(B) <- levels(acct_f)
colnames(B) <- levels(url_f)

# ---- (b) Weighted account-account projection --------------------------------
P <- tcrossprod(B)          # (i,j) = number of distinct shared URLs
diag(P) <- 0
P <- drop0(P)
g_full <- graph_from_adjacency_matrix(P, mode = "undirected", weighted = TRUE)

# ---- (c) 95th-percentile edge-weight filtered projection --------------------
w <- E(g_full)$weight
thr95 <- quantile(w, 0.95, type = 7)   # = 8 shared URLs
g_p95 <- subgraph_from_edges(g_full, which(w >= thr95), delete.vertices = TRUE)

# ---- Save -------------------------------------------------------------------
saveRDS(incidence, "data/validation/rds/incidence.rds")
saveRDS(B,         "data/validation/rds/bipartite_matrix.rds")
saveRDS(g_full,    "data/validation/rds/projection_full.rds")
saveRDS(g_p95,     "data/validation/rds/projection_p95.rds")

summary_dt <- data.table(
  stage = c("alert_records", "incidence_rows_alert_level",
            "bipartite_account_url_pairs", "distinct_accounts",
            "distinct_urls", "projection_full_nodes", "projection_full_edges",
            "p95_weight_threshold", "projection_p95_nodes",
            "projection_p95_edges"),
  value = c(nrow(alerts), nrow(incidence), nrow(au), n_accounts, n_urls,
            vcount(g_full), ecount(g_full), thr95, vcount(g_p95),
            ecount(g_p95))
)
fwrite(summary_dt, "data/validation/graph_summary.csv")
print(summary_dt)
