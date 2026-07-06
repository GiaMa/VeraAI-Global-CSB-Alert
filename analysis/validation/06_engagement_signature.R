# =============================================================================
# 06_engagement_signature.R — Category-level engagement signatures.
#
# Input: data/processed/community_engagement_classified.csv (207 communities)
#
# (a) Kruskal-Wallis tests across the 11 `primary_focus` categories for each
#     reaction-share metric: share of love / angry / haha / sad / wow among
#     total REACTIONS (like + love + wow + haha + sad + angry; cross-community
#     + exclusive engagement summed). Communities with zero reactions are
#     excluded from these tests (n excluded reported in the CSV).
#     Effect size: epsilon-squared = (H - k + 1) / (n - k).
#
# (b) Cosine-distance permutation test on the ENGAGEMENT-SIGNATURE VECTOR:
#     the 8-component composition (likes, shares, comments, love, wow, haha,
#     sad, angry) as proportions of their sum. Communities with zero total
#     engagement are excluded (3 of 207 -> N = 204, choose(204,2) = 20,706
#     pairs, matching the published test). Statistic: mean cosine distance of
#     different-category pairs minus mean distance of same-category pairs;
#     null distribution from 1,000 random permutations of the category
#     labels; one-sided p = (1 + #{null >= observed}) / 1001.
#     (The 8-component vector is used because 6 of the 204 communities have
#     zero reactions, which would make a reactions-only cosine undefined —
#     confirming the published N = 204 requires the 8-component definition.)
#
# Output: data/validation/engagement_signature.csv
#         data/validation/rds/engagement_cosine_perms.rds
# =============================================================================

suppressMessages(library(data.table))

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)
set.seed(20260705)

eng <- fread("data/processed/community_engagement_classified.csv")

for (m in c("likes", "shares", "comments", "love", "wow", "haha", "sad", "angry")) {
  eng[[m]] <- eng[[paste0("total_", m, "_cross_community")]] +
              eng[[paste0("total_", m, "_exclusive")]]
}
eng[, reactions := likes + love + wow + haha + sad + angry]
eng[, engagement8 := likes + shares + comments + love + wow + haha + sad + angry]

# ---- (a) Kruskal-Wallis on reaction shares ------------------------------------
kw_dt <- eng[reactions > 0]
n_excluded_kw <- nrow(eng) - nrow(kw_dt)
k <- uniqueN(kw_dt$primary_focus)

kw_rows <- rbindlist(lapply(c("love", "angry", "haha", "sad", "wow"), function(m) {
  x <- kw_dt[[m]] / kw_dt$reactions
  kt <- kruskal.test(x, factor(kw_dt$primary_focus))
  n <- length(x)
  data.table(test          = paste0("kruskal_wallis_", m, "_share"),
             n_communities = n,
             n_excluded    = n_excluded_kw,
             statistic     = as.numeric(kt$statistic),
             df            = as.integer(kt$parameter),
             p_value       = kt$p.value,
             epsilon_sq    = (as.numeric(kt$statistic) - k + 1) / (n - k))
}))

# ---- (b) Cosine-distance permutation test -------------------------------------
cos_dt <- eng[engagement8 > 0]
n_excluded_cos <- nrow(eng) - nrow(cos_dt)
V <- as.matrix(cos_dt[, .(likes, shares, comments, love, wow, haha, sad, angry)])
V <- V / rowSums(V)
Vn <- V / sqrt(rowSums(V^2))
D <- 1 - tcrossprod(Vn)                 # cosine distance matrix
ut <- upper.tri(D)

cats <- cos_dt$primary_focus
stat_fn <- function(lab) {
  same <- outer(lab, lab, "==")[ut]
  mean(D[ut][!same]) - mean(D[ut][same])
}
obs_same <- {same <- outer(cats, cats, "==")[ut]; mean(D[ut][same])}
obs_diff <- {same <- outer(cats, cats, "==")[ut]; mean(D[ut][!same])}
obs_stat <- obs_diff - obs_same

n_perm <- 1000L
null_stats <- vapply(seq_len(n_perm), function(b) {
  set.seed(20260705 + b)
  stat_fn(sample(cats))
}, numeric(1))
p_cos <- (1 + sum(null_stats >= obs_stat)) / (n_perm + 1)

saveRDS(list(observed = obs_stat, null = null_stats, seed_base = 20260705,
             mean_same = obs_same, mean_diff = obs_diff,
             n = nrow(cos_dt), n_pairs = sum(ut)),
        "data/validation/rds/engagement_cosine_perms.rds")

cos_row <- data.table(
  test          = "cosine_distance_permutation",
  n_communities = nrow(cos_dt),
  n_excluded    = n_excluded_cos,
  statistic     = obs_stat,
  df            = NA_integer_,
  p_value       = p_cos,
  epsilon_sq    = NA_real_)

out <- rbind(kw_rows, cos_row)
out[, `:=`(n_pairs   = c(rep(NA_integer_, 5), sum(ut)),
           mean_same = c(rep(NA_real_, 5), obs_same),
           mean_diff = c(rep(NA_real_, 5), obs_diff),
           n_permutations = c(rep(NA_integer_, 5), n_perm))]
fwrite(out, "data/validation/engagement_signature.csv")
print(out)
