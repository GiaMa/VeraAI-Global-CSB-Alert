# =============================================================================
# 01_expansion_dynamics.R — Monthly expansion of detected accounts and
# reconstruction of the promotion rate of the recursive-discovery loop.
#
# Input : data/validation/rds/incidence.rds (from 00_build_graphs.R)
#         data/alerts/veraai_alerts_links.csv
# Output: data/validation/expansion_dynamics.csv   (one row per month)
#         data/validation/expansion_populations.csv (population definitions
#           + end-of-deployment totals, incl. the 2,126 / 19.6k checks)
#
# POPULATION DEFINITIONS (the paper must distinguish these precisely)
# -------------------------------------------------------------------
# coord      : distinct values of `coo_r_account_url` (accounts CooRnet
#              flagged as coordinated in an alert). Total = 14,832. This is
#              the node set of the co-sharing graph / 207-community catalogue.
# posting    : distinct values of `account_url` (the account whose post
#              triggered the alert record). Total = 9,368. Disjoint from
#              `coord` in this dataset.
# union      : coord OR posting. Total = 24,200 at end of deployment.
#              The ~19.6k plotted at the 0th percentile of the OLD
#              threshold-sensitivity figure equals this union pool as of
#              early June 2024 (cumulative union = 19,573 on 2024-06-02,
#              19,642 on 2024-06-03): the old figure was evidently produced
#              from a MID-DEPLOYMENT snapshot of the mixed
#              coordinated+posting population, not from the final archive.
#
# PROMOTION RECONSTRUCTION
# ------------------------
# PRIMARY definition (reproduces the published mean ~11.6% / CV 0.11):
#   detection frequency of an account through month m = number of DISTINCT
#   URLS (cumulative) on which the account was flagged as coordinated.
#   Candidates = all coordinated accounts seen so far; promoted = those with
#   frequency >= 90th percentile (quantile type 7); rate = promoted /
#   candidates. Computed for each of the 11 calendar months.
# SECONDARY definition (also saved): frequency = number of distinct
#   alert_ids. This variant saturates at rate = 1.0 for the first five
#   months (90th-pct threshold ties at 1 alert), so it cannot be the
#   definition behind the published figure.
# (The live system promoted accounts per 6-hour cycle; both are monthly
# reconstructions from the alert archive.)
# =============================================================================

suppressMessages(library(data.table))

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)

incidence <- readRDS("data/validation/rds/incidence.rds")
alerts    <- fread("data/alerts/veraai_alerts_links.csv")
alerts[, alert_date := as.Date(alert_date)]

month_of <- function(d) format(d, "%Y-%m")

# ---- First-seen month per population ----------------------------------------
first_coord <- incidence[, .(first = min(alert_date)), by = acct]
first_post  <- alerts[, .(first = min(alert_date)), by = .(acct = trimws(account_url))]
first_union <- rbind(first_coord, first_post)[, .(first = min(first)), by = acct]

monthly_new <- function(fs) {
  out <- fs[, .(new = .N), by = .(month = month_of(first))][order(month)]
  out[, cumulative := cumsum(new)]
  out
}
m_coord <- monthly_new(first_coord)
m_post  <- monthly_new(first_post)
m_union <- monthly_new(first_union)

# ---- Promotion-rate reconstruction (coordinated-account pool) ----------------
acct_alerts <- unique(incidence[, .(acct, alert_id, month = month_of(alert_date))])
acct_urls   <- unique(incidence[, .(acct, url, month = month_of(alert_date))])
months <- sort(unique(acct_alerts$month))

promo <- rbindlist(lapply(months, function(m) {
  freq_u <- acct_urls[month <= m][, .(n = uniqueN(url)), by = acct]      # PRIMARY
  freq_a <- acct_alerts[month <= m][, .(n = uniqueN(alert_id)), by = acct]
  thr_u  <- quantile(freq_u$n, 0.90, type = 7)
  thr_a  <- quantile(freq_a$n, 0.90, type = 7)
  data.table(month                    = m,
             candidates_cum           = nrow(freq_u),
             urlfreq_pctl90_threshold = thr_u,
             promoted_cum_urlfreq     = sum(freq_u$n >= thr_u),
             promotion_rate_urlfreq   = mean(freq_u$n >= thr_u),
             alertfreq_pctl90_threshold = thr_a,
             promotion_rate_alertfreq   = mean(freq_a$n >= thr_a))
}))

rate_mean <- mean(promo$promotion_rate_urlfreq)
rate_cv   <- sd(promo$promotion_rate_urlfreq) / rate_mean
message(sprintf("Monthly promotion rate (URL-freq, primary): mean = %.4f, CV = %.3f",
                rate_mean, rate_cv))

# ---- Assemble the per-month CSV ---------------------------------------------
out <- Reduce(function(a, b) merge(a, b, by = "month", all = TRUE), list(
  setnames(copy(m_coord), c("new", "cumulative"),
           c("new_coordinated_accounts", "cumulative_coordinated_accounts")),
  setnames(copy(m_post),  c("new", "cumulative"),
           c("new_posting_accounts", "cumulative_posting_accounts")),
  setnames(copy(m_union), c("new", "cumulative"),
           c("new_union_accounts", "cumulative_union_accounts")),
  promo
))
fwrite(out, "data/validation/expansion_dynamics.csv")
print(out)

# ---- End-of-deployment population totals and the 2,126 / 19.6k checks --------
freq_full <- unique(incidence[, .(acct, url)])[, .(n_urls = uniqueN(url)), by = acct]
thr90_full <- quantile(freq_full$n_urls, 0.90, type = 7)
top_decile_promoted <- sum(freq_full$n_urls >= thr90_full)

pops <- data.table(
  population = c("coordinated (coo_r_account_url)",
                 "posting (account_url)",
                 "union coordinated+posting",
                 "top-decile promoted from coordinated pool (URL-freq >= 90th pct)",
                 "published 'newly discovered accounts' (chapters)",
                 "old threshold-figure pool at 0th pct"),
  n     = c(nrow(first_coord), nrow(first_post), nrow(first_union),
            top_decile_promoted, 2126, 19600),
  note  = c("nodes of co-sharing graph; = sum n_accounts over 207 communities",
            "accounts whose post triggered an alert record; disjoint from coordinated set",
            "largest pool constructible from surviving link-alert data",
            sprintf("90th-pct detection-frequency threshold = %d distinct URLs", as.integer(thr90_full)),
            "live-cycle artifact (all three engines); NOT reproducible from link alerts alone",
            "matches union pool cumulative in early June 2024 (19,573 on 2024-06-02): old figure used a mid-deployment snapshot of the mixed population")
)
fwrite(pops, "data/validation/expansion_populations.csv")
print(pops)
