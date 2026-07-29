# =============================================================================
# 09_seed_corpus_profile.R — Descriptive profile of the fact-checked URL
# corpus the initial seed list was built from.
#
# WHY THIS EXISTS
# ---------------
# The 1,225-account seed was selected behaviourally: accounts that had
# coordinatedly shared >= 4 URLs from a corpus of fact-checked-false web
# pages (Messing et al. 2020 URL dataset, third-party fact-checker ratings,
# 2017-2022). Because discovery is recursive, the category mix of what the
# deployment finds is conditional on the thematic footprint of that corpus:
# a co-author review of the working paper asked, correctly, whether the
# "non-political coordination" finding is a discovery of the monitoring or
# an inheritance from the seed. This script characterises the seed corpus so
# the question can be answered from evidence rather than assumption.
#
# Input : data/private/seed_factcheck_urls.csv  (clean_url, first_post_time)
# Output: data/validation/seed_corpus_profile.csv    (headline counts)
#         data/validation/seed_corpus_years.csv      (URLs per year)
#         data/validation/seed_corpus_domains.csv    (top 100 domains)
#         data/validation/seed_corpus_tlds.csv       (top 40 suffixes)
#         data/private/seed_corpus_sample.csv        (n=1000, WITH URLs)
#         data/validation/seed_corpus_sample_public.csv (same rows, no URLs)
#
# REDISTRIBUTION LIMIT — READ BEFORE ADDING ANY OUTPUT
# ----------------------------------------------------
# The corpus URLs come from the Facebook Privacy-Protected Full URLs Data
# Set (Messing et al. 2020). The Data Sharing Agreement signed to obtain it
# forbids redistributing the URL-level rows, so the corpus and the
# URL-bearing coding sample live in data/private/ (gitignored) and MUST NOT
# be committed or uploaded to Zenodo. What may be released: the public
# sample (sample_id + year + flags, no URL or domain), the topic labels
# keyed by sample_id, and the aggregate profile tables. The top-domain and
# TLD tables are aggregates rather than rows; they are written to
# data/validation/ but their release is a judgement call for the PI, since
# the published chapters already name corpus domains in prose.
#
# COUNT RECONCILIATION (read before quoting any number)
# -----------------------------------------------------
# The file holds 38,099 rows. Rows are not unique URLs: 1,936 duplicate
# clean_url values and 316 rows with a missing clean_url. Restricting to
# rows with both a URL and a parseable first_post_time gives 36,092 unique
# URLs — the published figure is 36,091, i.e. the file reproduces it to
# within a single record (most plausibly one URL that normalised
# differently in the original 2023 run). Quote 36,091 in the paper for
# continuity with the two published chapters and note the file's 36,092.
#
# 72 rows carry no timestamp and 660 rows predate 2017; both are inside the
# 36,092 only if they carry a date, so the corpus is NOT strictly bounded at
# 2017 on its lower edge (the earliest first_post_time is 2011). The
# "2017-2022" description in the published chapters refers to the fact-check
# rating window, not to the posting dates of the rated pages.
#
# SAMPLE FOR TOPICAL CODING
# -------------------------
# Topical composition cannot be derived mechanically: the corpus carries no
# topic labels and most pages are long dead, so content cannot be refetched.
# The sample written here is coded from the URL string itself (domain +
# path slug) against seed_corpus_codebook.md in this directory. 17.6% of
# URLs are platform-hosted
# (YouTube, Twitter/X, BitChute, Rumble, Odysee, Facebook), whose paths are
# opaque IDs — these are coded `unclassifiable` and form a hard floor on
# what any URL-string method can resolve. Labels are produced by Claude,
# consistent with how the community-level `region` / `primary_focus` fields
# in data/processed/ were generated. The labelled CSV — keyed by sample_id,
# carrying no URLs — is the reproducibility record (an LLM pass is not
# bit-reproducible, and the URLs themselves cannot be redistributed).
#
# Sampling is from unique, dated URLs with a fixed seed (20260724).
# =============================================================================

suppressMessages({
  library(data.table)
  library(urltools)
})

IN   <- "data/private/seed_factcheck_urls.csv"
OUT  <- "data/validation"
PRIV <- "data/private"   # gitignored; never redistribute (see header)
SEED <- 20260724
N_SAMPLE <- 1000

stopifnot(file.exists(IN))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

raw <- fread(IN, na.strings = c("", "NA"))
stopifnot(all(c("clean_url", "first_post_time") %in% names(raw)))

raw[, year := as.integer(substr(first_post_time, 1, 4))]

# --- analysis set: one row per unique URL, timestamp present --------------
d <- raw[!is.na(clean_url) & !is.na(year)]
d <- d[!duplicated(clean_url)]

# --- headline counts ------------------------------------------------------
d[, domain := urltools::domain(clean_url)]
d[, suffix := urltools::suffix_extract(domain)$suffix]

PLATFORM <- c("www.youtube.com", "youtube.com", "m.youtube.com", "youtu.be",
              "twitter.com", "www.twitter.com", "x.com",
              "www.bitchute.com", "bitchute.com", "rumble.com",
              "www.rumble.com", "odysee.com", "www.facebook.com",
              "facebook.com", "m.facebook.com", "t.me", "vk.com",
              "www.tiktok.com", "www.instagram.com")
d[, platform_hosted := domain %in% PLATFORM]

# word-like path tokens: proxy for whether the slug carries codeable text.
# Paths are percent-decoded first: a large share of the corpus is non-English
# (Greek, Cyrillic, Arabic, Thai scripts appear percent-encoded), and those
# slugs are perfectly codeable once decoded — counting raw ASCII letters
# would misclassify them as opaque.
pth <- urltools::path(d$clean_url)
pth[is.na(pth)] <- ""
# Some pages were percent-encoded in a legacy single-byte encoding; decoding
# then yields bytes that are not valid UTF-8. Mark those sub-strings rather
# than let the regex engine abort on them.
decode1 <- function(x) {
  out <- tryCatch(utils::URLdecode(x), error = function(e) x)
  if (is.na(out)) return("")
  if (!validUTF8(out)) out <- iconv(out, from = "latin1", to = "UTF-8", sub = "")
  if (is.na(out) || !validUTF8(out)) out <- gsub("[^\x20-\x7E]", "", x)
  out
}
d[, path_decoded := vapply(pth, decode1, character(1), USE.NAMES = FALSE)]
d[, slug_tokens := vapply(strsplit(gsub("[^[:alpha:]]+", "-", path_decoded), "-"),
                          function(x) sum(nchar(x) >= 3L), integer(1))]

profile <- data.table(
  metric = c("rows_in_file", "rows_missing_url", "duplicate_url_rows",
             "unique_urls_dated", "published_figure", "distinct_domains",
             "platform_hosted", "platform_hosted_pct",
             "codeable_slug", "codeable_slug_pct",
             "top100_domain_coverage_pct",
             "year_min", "year_median", "year_max", "year_mode"),
  value = c(nrow(raw),
            raw[is.na(clean_url), .N],
            nrow(raw) - uniqueN(raw$clean_url),
            nrow(d),
            36091,
            uniqueN(d$domain),
            d[platform_hosted == TRUE, .N],
            round(100 * mean(d$platform_hosted), 1),
            d[slug_tokens >= 3L, .N],
            round(100 * mean(d$slug_tokens >= 3L), 1),
            round(100 * sum(sort(table(d$domain), decreasing = TRUE)[1:100]) / nrow(d), 1),
            min(d$year), median(d$year), max(d$year),
            as.integer(d[, .N, by = year][order(-N)][1, year]))
)
fwrite(profile, file.path(OUT, "seed_corpus_profile.csv"))

years <- d[, .N, by = year][order(year)]
years[, pct := round(100 * N / sum(N), 1)]
fwrite(years, file.path(OUT, "seed_corpus_years.csv"))

domains <- d[, .N, by = domain][order(-N)][1:100]
domains[, pct := round(100 * N / nrow(d), 2)]
fwrite(domains, file.path(OUT, "seed_corpus_domains.csv"))

tlds <- d[, .N, by = suffix][order(-N)][1:40]
tlds[, pct := round(100 * N / nrow(d), 2)]
fwrite(tlds, file.path(OUT, "seed_corpus_tlds.csv"))

# --- sample for topical coding -------------------------------------------
set.seed(SEED)
idx <- sample.int(nrow(d), N_SAMPLE)
samp <- d[idx, .(clean_url, year, domain, platform_hosted, slug_tokens, path_decoded)]
samp[, sample_id := seq_len(.N)]
setcolorder(samp, "sample_id")

# The ad-farm flag is computed HERE, while the paths are still in hand, so
# that 10_ never needs to touch a URL: cloaked ad-farm pages carry an
# `entertainment-<n>-<year>` section prefix (see 10_ for what it is used for).
samp[, adfarm_entertainment_prefix :=
       grepl("entertainment-[0-9]+-20[0-9]{2}", path_decoded)]

dir.create(PRIV, showWarnings = FALSE, recursive = TRUE)
fwrite(samp, file.path(PRIV, "seed_corpus_sample.csv"))          # restricted
fwrite(samp[, .(sample_id, year, platform_hosted, slug_tokens,
                adfarm_entertainment_prefix)],
       file.path(OUT, "seed_corpus_sample_public.csv"))          # releasable

cat("seed corpus profile written\n")
print(profile)
cat("\nsample of", N_SAMPLE, "written to", file.path(PRIV, "seed_corpus_sample.csv"),
    "(restricted) and", file.path(OUT, "seed_corpus_sample_public.csv"), "(releasable)\n")
