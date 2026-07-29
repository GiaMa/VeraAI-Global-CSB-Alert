# =============================================================================
# 04_threshold_sensitivity.R — Sensitivity of the promotion rule to the
# detection-frequency percentile threshold.
#
# CANDIDATE POOL: the 14,832 coordinated accounts (coo_r_account_url
# entries; the co-sharing/community-graph population). Accounts that merely
# shared an alerted URL without being flagged as coordinated (`account_url`
# entries; 5,618 posting-only accounts after splitting the comma-separated
# lists) were NEVER eligible for promotion in the live system and are
# excluded by design.
#
# HISTORY: an earlier revision of this script pooled coordinated accounts
# with UNSPLIT `account_url` strings (9,368 comma-joined lists mistaken for
# single accounts, hence "disjoint" from the coordinated set) and reported a
# 24,200-account candidate pool with 2,438 promoted at the 90th percentile
# and 98.6% overlap with the coordination graph. All three figures are
# artifacts of that error: the pool was wrong both numerically (list
# strings are not accounts) and conceptually (sharers were never
# candidates), and on the corrected coordinated-only pool the overlap
# metric is 100% by construction and therefore uninformative. Never reuse
# 24,200 / 2,438 / 98.6%. The old pre-restoration figure's ~19.6k pool at
# the 0th percentile is closest to the properly split posting-account union
# (20,450; see 01_expansion_dynamics.R).
#
# Detection frequency = number of distinct alert URLs an account appears
# with as a coordinated account — the same definition that reproduces the
# published promotion-rate series (see 01).
#
# For each threshold percentile P in {0,50,60,70,80,85,90,95,99}:
#   freq_threshold = quantile(freq, P/100, type 7) in distinct URLs
#   n_promoted     = #{accounts with freq >= freq_threshold}
#   share_promoted = n_promoted / 14,832
#
# Output: data/validation/threshold_sensitivity.csv
# =============================================================================

suppressMessages(library(data.table))

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

incidence <- readRDS("data/validation/rds/incidence.rds")

coord_freq <- unique(incidence[, .(acct, url)])[, .(n_urls = uniqueN(url)), by = acct]

pcts <- c(0, 50, 60, 70, 80, 85, 90, 95, 99)

sens <- rbindlist(lapply(pcts, function(p) {
  thr  <- quantile(coord_freq$n_urls, p / 100, type = 7)
  prom <- coord_freq[n_urls >= thr, acct]
  data.table(percentile     = p,
             freq_threshold = thr,
             n_promoted     = length(prom),
             share_promoted = length(prom) / nrow(coord_freq))
}))

fwrite(sens, "data/validation/threshold_sensitivity.csv")
print(sens)
