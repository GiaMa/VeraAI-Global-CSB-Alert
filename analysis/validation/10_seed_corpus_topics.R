# =============================================================================
# 10_seed_corpus_topics.R — Topical composition of the seed fact-check corpus.
#
# Input : data/validation/seed_corpus_sample_public.csv  (from 09_; no URLs —
#           the corpus rows are restricted by the URL Shares Dataset DSA and
#           live in data/private/, so nothing here touches a URL)
#         data/validation/seed_corpus_topics.csv  (hand/LLM labels; see
#                                                  seed_corpus_codebook.md)
# Output: data/validation/seed_corpus_topic_shares.csv  (appendix table)
#         data/validation/seed_corpus_rollups.csv       (the four rollups)
#
# WHAT THE NUMBERS ARE FOR
# ------------------------
# The working paper claims the deployment surfaced substantial NON-POLITICAL
# coordination. A co-author objected, correctly, that a recursive/snowball
# procedure inherits its starting point, so that claim is only a finding if
# the seed corpus was not itself full of non-political content. These shares
# answer that. The decisive quantity is not "% political" but the
# entertainment / fan / pet share: if those are near-absent from the corpus
# while entertainment communities are the second-largest block of discovered
# accounts (5,406), those communities cannot have been inherited.
#
# CONSERVATIVE TREATMENT OF THE AD-FARM PAGES
# -------------------------------------------
# The corpus contains a cloaked ad-farm network (typosquatted news brands
# with digit-for-letter substitutions: live-br0adcast, gl0baln0w,
# austra1iannetw0rk, ...). Their paths are gibberish tokens, often behind an
# `entertainment-<n>-<year>` section prefix (flagged in 09_, where the paths
# are still available). They are coded `commerce_scam`
# because their function is ad revenue, not entertainment journalism — but
# that prefix is evidence the cloaked content may be entertainment-styled, so
# the script reports a SENSITIVITY: what the entertainment share would be if
# every ad-farm page carrying that prefix were counted as entertainment
# instead. Quote the sensitivity bound in the paper, not just the point
# estimate.
# =============================================================================

suppressMessages(library(data.table))

OUT <- "data/validation"

samp   <- fread(file.path(OUT, "seed_corpus_sample_public.csv"))
labels <- fread(file.path(OUT, "seed_corpus_topics.csv"))

# --- validation: every sampled id labelled exactly once -------------------
stopifnot(nrow(labels) == nrow(samp))
stopifnot(!anyDuplicated(labels$sample_id))
stopifnot(setequal(labels$sample_id, samp$sample_id))

VALID <- c("politics", "health", "science_climate", "crime_society",
           "religion", "entertainment_celebrity", "commerce_scam",
           "gambling", "pets_animals", "other", "unclassifiable")
stopifnot(all(labels$topic %in% VALID))

d <- merge(samp, labels, by = "sample_id")
N <- nrow(d)

# --- Wilson 95% interval ---------------------------------------------------
wilson <- function(x, n, conf = 0.95) {
  z <- qnorm(1 - (1 - conf) / 2)
  p <- x / n
  den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  list(lo = pmax(0, ctr - hw), hi = pmin(1, ctr + hw))
}

# Shares are reported twice: over the whole sample, and over the CODEABLE
# subset (everything the URL string could resolve). The codeable-only column
# is the honest denominator for statements about what the corpus is *about*,
# since the 25.7% opaque residue is a property of the URL-string method, not
# of the corpus's topic mix.
N_CODE <- d[topic != "unclassifiable", .N]

shares <- d[, .(n = .N), by = topic][order(-n)]
ci <- wilson(shares$n, N)
shares[, `:=`(pct = round(100 * n / N, 1),
              lo  = round(100 * ci$lo, 1),
              hi  = round(100 * ci$hi, 1))]
shares[, pct_codeable := ifelse(topic == "unclassifiable", NA_real_,
                                round(100 * n / N_CODE, 1))]
fwrite(shares, file.path(OUT, "seed_corpus_topic_shares.csv"))

# --- rollups (defined in seed_corpus_codebook.md) --------------------------
roll <- function(name, cats) {
  x <- d[topic %in% cats, .N]
  ci <- wilson(x, N)
  data.table(rollup = name, categories = paste(cats, collapse = "+"),
             n = x, pct = round(100 * x / N, 1),
             lo = round(100 * ci$lo, 1), hi = round(100 * ci$hi, 1))
}
rollups <- rbindlist(list(
  roll("political_or_news",        c("politics", "crime_society")),
  roll("health",                   "health"),
  roll("discovered_not_inherited", c("entertainment_celebrity", "pets_animals")),
  roll("content_overlap",          c("commerce_scam", "gambling")),
  roll("unclassifiable",           "unclassifiable")
))
fwrite(rollups, file.path(OUT, "seed_corpus_rollups.csv"))

# --- sensitivity: ad-farm pages recoded as entertainment -------------------
adfarm <- d[topic == "commerce_scam" & adfarm_entertainment_prefix == TRUE]
ent_now  <- d[topic %in% c("entertainment_celebrity", "pets_animals"), .N]
ent_max  <- ent_now + nrow(adfarm)
ci_max   <- wilson(ent_max, N)

cat("\n=== seed corpus topical composition (n =", N, ") ===\n")
print(shares[, .(topic, n, pct, ci = sprintf("[%.1f, %.1f]", lo, hi), pct_codeable)])
cat("\n=== rollups ===\n")
print(rollups[, .(rollup, n, pct, ci = sprintf("[%.1f, %.1f]", lo, hi))])
cat("\n=== ad-farm sensitivity ===\n")
cat("ad-farm pages with an 'entertainment-<n>-<year>' prefix:", nrow(adfarm),
    sprintf("(%.1f%% of sample)\n", 100 * nrow(adfarm) / N))
cat("entertainment+pets as coded:", ent_now, sprintf("(%.1f%%)\n", 100 * ent_now / N))
cat("upper bound if ALL ad-farm pages were entertainment:", ent_max,
    sprintf("(%.1f%%, 95%% CI [%.1f, %.1f])\n",
            100 * ent_max / N, 100 * ci_max$lo, 100 * ci_max$hi))

# --- how the sample distributes over the corpus's own strata ---------------
cat("\n=== codeability check ===\n")
cat("platform-hosted in sample:", d[platform_hosted == TRUE, .N],
    "| of which coded unclassifiable:",
    d[platform_hosted == TRUE & topic == "unclassifiable", .N], "\n")
cat("non-platform but unclassifiable:",
    d[platform_hosted == FALSE & topic == "unclassifiable", .N], "\n")
