# =============================================================================
# 04_threshold_sensitivity.R — Sensitivity of the promotion rule to the
# detection-frequency percentile threshold.
#
# CANDIDATE POOL: union of (a) coordinated accounts (coo_r_account_url
# entries; n = 14,832 — the co-sharing/community-graph population) and
# (b) posting accounts (account_url; n = 9,368; disjoint from (a)).
# Pool size = 24,200. NOTE: the pre-restoration figure showed ~19.6k
# promoted at the 0th percentile; no pool constructible from the surviving
# link-alert archive equals ~19.6k (candidates: 14,832 / 9,368 / 24,200),
# so the old figure's pool is documented as non-reproducible — it most
# likely also included live CMSB/CITSB cycle outputs that were not archived.
#
# Detection frequency = number of distinct alert URLs an account appears
# with (as coordinated account) or triggered (as posting account) — the same
# definition that reproduces the published promotion-rate series (see 01).
#
# For each threshold percentile P in {0,50,60,70,80,85,90,95,99}:
#   n_promoted = #{accounts with freq >= quantile(freq, P/100, type 7)}
#   coverage   = |promoted  intersect  coordinated| / 14,832
#                (share of the community-graph accounts that get promoted)
#   overlap    = |promoted  intersect  coordinated| / n_promoted
#                (share of promoted accounts that are in the community graph)
# Columns with suffix _coordpool repeat the exercise with candidates
# restricted to the 14,832 coordinated accounts.
#
# Output: data/validation/threshold_sensitivity.csv
# =============================================================================

suppressMessages(library(data.table))

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

incidence <- readRDS("data/validation/rds/incidence.rds")
alerts <- fread("data/alerts/veraai_alerts_links.csv")

coord_freq <- unique(incidence[, .(acct, url)])[, .(n_urls = uniqueN(url)), by = acct]
post_freq  <- unique(alerts[, .(acct = trimws(account_url), url)])[, .(n_urls = uniqueN(url)), by = acct]
coord_set  <- coord_freq$acct

# Union pool: accounts are disjoint across the two roles in this dataset,
# but sum frequencies defensively in case of overlap.
pool <- rbind(coord_freq, post_freq)[, .(n_urls = sum(n_urls)), by = acct]

pcts <- c(0, 50, 60, 70, 80, 85, 90, 95, 99)

sens <- rbindlist(lapply(pcts, function(p) {
  thr  <- quantile(pool$n_urls, p / 100, type = 7)
  prom <- pool[n_urls >= thr, acct]
  n_in_graph <- sum(prom %in% coord_set)
  thr_c  <- quantile(coord_freq$n_urls, p / 100, type = 7)
  prom_c <- coord_freq[n_urls >= thr_c, acct]
  data.table(percentile          = p,
             freq_threshold      = thr,
             n_promoted          = length(prom),
             coverage_of_14832   = n_in_graph / length(coord_set),
             overlap_with_graph  = n_in_graph / length(prom),
             freq_threshold_coordpool = thr_c,
             n_promoted_coordpool     = length(prom_c),
             coverage_of_14832_coordpool = length(prom_c) / length(coord_set))
}))

fwrite(sens, "data/validation/threshold_sensitivity.csv")
print(sens)
