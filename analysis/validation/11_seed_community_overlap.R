# =============================================================================
# 11_seed_community_overlap.R — Does the seed list appear inside the
# discovered communities? The genealogical test behind the "discovered, not
# inherited" claim.
#
# WHY THIS EXISTS
# ---------------
# 09_/10_ characterise the CONTENT the seed accounts shared. That leaves the
# stronger objection untouched: inheritance travels through account identity,
# not page topic. Entertainment pages are content-agnostic amplifiers of
# viral false claims, and misinformation pages are documented to have been
# repurposed into gambling and commerce operations between the corpus period
# (modal year 2020) and the monitoring window (Oct 2023 - Aug 2024). Under
# either mechanism the entertainment and gambling communities could be seed
# accounts wearing new clothes, and no audit of URL topics can tell.
#
# This script tests it directly: how many accounts in each discovered
# community were already on the seed watched list?
#
#   overlap ~ 0 in the entertainment/gambling communities
#       -> those communities were reached by recursive expansion; neither
#          inheritance nor repurposing explains them.
#   overlap > 0
#       -> the "discovered, not inherited" claim must be weakened for the
#          affected communities, and the account-level route named.
#
# Input : highly_connected_coordinated_entities*.csv (repo root; the 1,225
#           seed accounts from the 2023 CooRnet run that built the watched
#           list — RESTRICTED, see below)
#         data/processed/community_engagement_classified.csv (207 communities
#           + `account_urls`, the membership list per community)
# Output: data/validation/seed_community_overlap.csv       (per community)
#         data/validation/seed_community_overlap_by_cat.csv (per category)
#
# REDISTRIBUTION: the seed account list is not released with this repository
# (the paper states the watched list is withheld). Only the aggregate overlap
# counts written to data/validation/ may be published. Keep the entities CSV
# out of git.
# =============================================================================

suppressMessages(library(data.table))

OUT <- "data/validation"

seed_file <- list.files(".", pattern = "^highly_connected_coordinated_entities.*\\.csv$")
stopifnot(length(seed_file) == 1)

seed <- fread(seed_file)
comm <- fread("data/processed/community_engagement_classified.csv")

# --- normalise account URLs so the two sources are comparable --------------
# Seed rows carry the CrowdTangle account URL in `name`; community membership
# is a semicolon-separated `account_urls` field. Both are facebook.com URLs but
# differ in protocol, www prefix and trailing slash.
norm <- function(x) {
  x <- tolower(trimws(x))
  x <- sub("^https?://", "", x)
  x <- sub("^www\\.", "", x)
  x <- sub("/+$", "", x)
  x <- sub("\\?.*$", "", x)
  x
}

seed_urls <- unique(norm(seed$name))
seed_urls <- seed_urls[nzchar(seed_urls) & !is.na(seed_urls)]

memb <- comm[, .(acct = norm(unlist(strsplit(account_urls, "[,;]")))),
             by = .(source_community, label, primary_focus, n_accounts)]
memb <- memb[nzchar(acct) & !is.na(acct)]
memb <- unique(memb, by = c("source_community", "acct"))

cat("seed accounts:", length(seed_urls),
    "| community memberships:", nrow(memb),
    "| distinct accounts in communities:", uniqueN(memb$acct), "\n")

memb[, is_seed := acct %in% seed_urls]

# --- per community ---------------------------------------------------------
per_comm <- memb[, .(accounts = .N,
                     seed_accounts = sum(is_seed)), by = .(source_community, label, primary_focus)]
per_comm[, seed_pct := round(100 * seed_accounts / accounts, 2)]
setorder(per_comm, -seed_accounts, -accounts)
fwrite(per_comm, file.path(OUT, "seed_community_overlap.csv"))

# --- per operational category ---------------------------------------------
per_cat <- memb[, .(communities = uniqueN(source_community),
                    accounts = .N,
                    seed_accounts = sum(is_seed)), by = primary_focus]
per_cat[, seed_pct := round(100 * seed_accounts / accounts, 2)]
setorder(per_cat, -accounts)
fwrite(per_cat, file.path(OUT, "seed_community_overlap_by_cat.csv"))

cat("\n=== seed overlap by operational category ===\n")
print(per_cat)

cat("\n=== overall ===\n")
cat("accounts in communities that were already on the seed list:",
    memb[is_seed == TRUE, .N], "of", nrow(memb),
    sprintf("(%.2f%%)\n", 100 * mean(memb$is_seed)))
cat("distinct seed accounts appearing in any community:",
    uniqueN(memb[is_seed == TRUE]$acct), "of", length(seed_urls),
    sprintf("(%.1f%% of the seed)\n",
            100 * uniqueN(memb[is_seed == TRUE]$acct) / length(seed_urls)))

cat("\n=== communities with any seed presence (top 15) ===\n")
print(head(per_comm[seed_accounts > 0], 15))

# --- ROBUSTNESS 1: does the match survive a different identifier scheme? ---
# 116 seed rows typed facebook_group carry a bare facebook.com/<digits> URL
# with no /groups/ segment, and some seed URL-IDs differ from the recorded
# account.platformId. If entertainment/gambling seed members were being
# missed through an identifier mismatch, the low overlap would be an
# artefact. Re-match on trailing numeric IDs, additionally injecting every
# account.platformId, and confirm the count is unchanged.
numid <- function(x) sub("^.*?([0-9]{6,})/?$", "\\1", x)
seed_ids <- unique(c(numid(seed_urls),
                     as.character(seed$account.platformId)))
seed_ids <- seed_ids[grepl("^[0-9]{6,}$", seed_ids)]
memb[, is_seed_byid := numid(acct) %in% seed_ids]
cat("\n=== robustness: URL match vs numeric-ID match ===\n")
cat("matches by URL:", memb[is_seed == TRUE, .N],
    "| by numeric ID (+platformId):", memb[is_seed_byid == TRUE, .N],
    "| disagreements:", memb[is_seed != is_seed_byid, .N], "\n")

# --- ROBUSTNESS 2: entity type ---------------------------------------------
# Seed pages have a higher seed rate than seed groups, and category mixes
# differ, so check the contrast holds among groups alone.
memb[, is_group := grepl("/groups/", acct)]
cat("\n=== groups only ===\n")
print(memb[is_group == TRUE, .(accounts = .N, seed = sum(is_seed),
                               pct = round(100 * mean(is_seed), 2)),
           by = primary_focus][order(-accounts)][1:6])

# --- INFERENCE: accounts are clustered within communities ------------------
# Seed presence is heavily concentrated (103 of 271 political seed accounts
# sit in one Brazilian community; 9 of 14 entertainment ones in a single
# Indonesian community). Accounts are therefore not independent trials and a
# Fisher test on the 2x2 account table is anti-conservative by orders of
# magnitude. The community is the unit that varies, so inference is done by
# permuting community-level category labels and by bootstrapping communities.
DISC <- c("Entertainment/Fan communities", "Online gambling/betting", "Pet communities")
EXPD <- c("Political movements/activism", "News/Media", "E-commerce/Marketplace")

cstat <- memb[primary_focus %in% c(DISC, EXPD),
              .(accounts = .N, seed = sum(is_seed),
                pool = ifelse(primary_focus[1] %in% DISC, "discovered", "expected")),
              by = .(source_community, primary_focus)]

rate <- function(pool_vec, seed_v, acc_v, target)
  sum(seed_v[pool_vec == target]) / sum(acc_v[pool_vec == target])

obs_d <- rate(cstat$pool, cstat$seed, cstat$accounts, "discovered")
obs_e <- rate(cstat$pool, cstat$seed, cstat$accounts, "expected")
obs_rr <- obs_e / obs_d

set.seed(20260724)
B <- 20000
perm <- replicate(B, {
  p <- sample(cstat$pool)
  rate(p, cstat$seed, cstat$accounts, "expected") -
    rate(p, cstat$seed, cstat$accounts, "discovered")
})
p_perm <- (sum(perm >= (obs_e - obs_d)) + 1) / (B + 1)

boot <- replicate(2000, {
  i1 <- sample(which(cstat$pool == "discovered"), replace = TRUE)
  i2 <- sample(which(cstat$pool == "expected"), replace = TRUE)
  rd <- sum(cstat$seed[i1]) / sum(cstat$accounts[i1])
  re <- sum(cstat$seed[i2]) / sum(cstat$accounts[i2])
  re / rd
})
boot <- boot[is.finite(boot)]

cat("\n=== cluster-aware inference (community is the unit) ===\n")
cat(sprintf("expansion-claimed %.2f%% vs seed-expected %.2f%% | rate ratio %.1f\n",
            100 * obs_d, 100 * obs_e, obs_rr))
cat(sprintf("community-label permutation (B = %d): p = %.2g%s\n", B, p_perm,
            if (p_perm <= 2 / (B + 1)) " (resolution floor)" else ""))
cat(sprintf("cluster bootstrap 95%% CI for the rate ratio: %.1f-%.1f\n",
            quantile(boot, 0.025), quantile(boot, 0.975)))
cat(sprintf("Wilcoxon on per-community seed rates: p = %.3f\n",
            wilcox.test(seed / accounts ~ pool, data = cstat)$p.value))

# --- e-commerce vs political: are they actually different? ------------------
ec <- memb[primary_focus == "E-commerce/Marketplace", .(s = sum(is_seed), n = .N)]
po <- memb[primary_focus == "Political movements/activism", .(s = sum(is_seed), n = .N)]
cat("\n=== e-commerce vs political seed rate ===\n")
print(prop.test(c(ec$s, po$s), c(ec$n, po$n))[c("estimate", "p.value")])

# --- ONE-HOP CONTACT: the mechanism the membership test cannot see ---------
# A community need not CONTAIN seed accounts to have been reached through
# them: one seed account co-sharing one alerted URL with a large network
# pulls the whole network into the graph in a single step. Membership
# overlap answers "is this community the seed under a new name?"; one-hop
# contact answers "how many expansion generations from the seed is it?".
inc <- readRDS("data/validation/rds/incidence.rds")
setDT(inc)
inc[, acct_n := norm(acct)]
seed_urls_touched <- unique(inc[acct_n %in% seed_urls, url])
contact_accts <- unique(inc[url %in% seed_urls_touched, acct_n])
memb[, one_hop := acct %in% contact_accts]

onehop <- memb[, .(accounts = .N,
                   seed_members = sum(is_seed),
                   one_hop_pct = round(100 * mean(one_hop), 1)), by = primary_focus]
setorder(onehop, -accounts)
fwrite(onehop, file.path(OUT, "seed_one_hop_contact.csv"))
cat("\n=== one-hop seed contact (co-shared >=1 alerted URL with a seed account) ===\n")
print(onehop)
cat("\nalerted URLs co-shared by >=1 seed account:", length(seed_urls_touched),
    "of", uniqueN(inc$url), "\n")
cat("\n=== entertainment communities by one-hop contact (top 5) ===\n")
print(head(memb[primary_focus == "Entertainment/Fan communities",
                .(accounts = .N, seed = sum(is_seed),
                  one_hop_pct = round(100 * mean(one_hop), 1)),
                by = .(source_community, label)][order(-one_hop_pct)], 5))
