# =============================================================================
# 07_figures.R — Regenerate all manuscript figures from the restored
# validation outputs. ggplot2 + theme_minimal, vector PDF (print quality).
#
# Inputs : data/validation/*.csv, data/validation/rds/*.rds,
#          ../VeraAI-Alert-ResearchNote/source_materials/typology_table.csv
# Outputs: analysis/figures/*.pdf
#
# Known defects of the old figures fixed here:
#  - expansion_monthly_detections: population now explicitly the 14,832
#    coordinated accounts (the old figure plotted all accounts in alert
#    records incl. non-coordinated sharers, ~19.6k–20,450).
#  - threshold_sensitivity: true numeric x-axis (percentiles to scale);
#    candidate pool corrected to coordinated accounts only (the earlier
#    24,200 union pool was a parsing artifact — see 04).
#  - null_model_modularity_histogram: annotation box kept inside the panel.
#  - rr_strict_replication_network: real network plot (was a histogram).
#
# Colour: Okabe-Ito palette (colour-blind safe), fixed assignment per
# category across all figures.
# =============================================================================

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(igraph)
  library(grid)
})

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)
set.seed(20260705)

fig_dir <- "analysis/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

okabe <- c("#0072B2", "#E69F00", "#009E73", "#D55E00", "#CC79A7", "#56B4E9")

theme_set(theme_minimal(base_size = 11))
thm <- theme(plot.title = element_text(face = "bold", size = 11),
             plot.subtitle = element_text(size = 9, colour = "grey30"),
             plot.caption = element_text(size = 7.5, colour = "grey40", hjust = 0),
             panel.grid.minor = element_blank())

two_panel_pdf <- function(file, pA, pB, width = 9, height = 4) {
  pdf(file, width = width, height = height)
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(1, 2)))
  print(pA, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
  print(pB, vp = viewport(layout.pos.row = 1, layout.pos.col = 2))
  dev.off()
}

# =============================================================================
# 1. expansion_monthly_detections.pdf
# =============================================================================
exp_dt <- fread("data/validation/expansion_dynamics.csv")
exp_dt[, month_date := as.Date(paste0(month, "-01"))]

pA <- ggplot(exp_dt, aes(month_date, new_coordinated_accounts)) +
  geom_col(fill = okabe[1], width = 24) +
  scale_x_date(date_labels = "%b\n%Y", date_breaks = "2 months") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "New coordinated accounts per month",
       subtitle = "Accounts first appearing in URL-level coordination alerts",
       x = NULL, y = "New accounts") + thm

pB <- ggplot(exp_dt, aes(month_date, cumulative_coordinated_accounts)) +
  geom_line(colour = okabe[1], linewidth = 0.8) +
  geom_point(colour = okabe[1], size = 1.6) +
  geom_hline(yintercept = 14832, linetype = "dotted", colour = "grey50") +
  annotate("text", x = min(exp_dt$month_date), y = 14832, vjust = -0.6, hjust = 0,
           label = "14,832 total", size = 3, colour = "grey30") +
  scale_x_date(date_labels = "%b\n%Y", date_breaks = "2 months") +
  scale_y_continuous(labels = scales::comma, limits = c(0, 16500)) +
  labs(title = "Cumulative unique coordinated accounts",
       subtitle = "Population: coordinated accounts in alerts (N = 14,832),\nnot the watched list and not the mixed candidate pool",
       x = NULL, y = "Cumulative accounts") + thm

two_panel_pdf(file.path(fig_dir, "expansion_monthly_detections.pdf"), pA, pB)

# =============================================================================
# 2. expansion_promotion_rate.pdf
# =============================================================================
rate_mean <- mean(exp_dt$promotion_rate_urlfreq)
rate_cv   <- sd(exp_dt$promotion_rate_urlfreq) / rate_mean

p2 <- ggplot(exp_dt, aes(month_date, promotion_rate_urlfreq)) +
  geom_hline(yintercept = rate_mean, linetype = "dashed", colour = "grey45") +
  geom_line(colour = okabe[1], linewidth = 0.8) +
  geom_point(colour = okabe[1], size = 2) +
  annotate("text", x = max(exp_dt$month_date), y = rate_mean, vjust = -0.8,
           hjust = 1, size = 3, colour = "grey30",
           label = sprintf("mean = %.1f%%", 100 * rate_mean)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "2 months") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, max(exp_dt$promotion_rate_urlfreq) * 1.25)) +
  labs(title = "Monthly promotion rate of candidate accounts",
       subtitle = sprintf("Share of candidates at or above the 90th percentile of detection frequency (distinct alert URLs, cumulative). Mean = %.1f%%, CV = %.2f", 100 * rate_mean, rate_cv),
       caption = "Monthly reconstruction from the alert archive; the live system promoted accounts per 6-hour cycle.",
       x = NULL, y = "Promotion rate") + thm

ggsave(file.path(fig_dir, "expansion_promotion_rate.pdf"), p2, width = 7, height = 4)

# =============================================================================
# 3. threshold_sensitivity.pdf  (true numeric x-axis)
# =============================================================================
sens <- fread("data/validation/threshold_sensitivity.csv")

pA <- ggplot(sens, aes(percentile, n_promoted)) +
  geom_vline(xintercept = 90, linetype = "dashed", colour = "grey45") +
  geom_line(colour = okabe[1], linewidth = 0.7) +
  geom_point(colour = okabe[1], size = 2) +
  annotate("text", x = 90, y = max(sens$n_promoted), label = "deployed (90th)",
           hjust = 1.05, vjust = 1, size = 3, colour = "grey30") +
  geom_text(aes(label = scales::percent(share_promoted, accuracy = 0.1)),
            vjust = -0.9, size = 2.6, colour = "grey30") +
  scale_y_log10(labels = scales::comma,
                expand = expansion(mult = c(0.05, 0.12))) +
  scale_x_continuous(breaks = c(0, 25, 50, 75, 90, 99)) +
  labs(title = "Accounts promoted vs. threshold percentile",
       subtitle = "Candidate pool: 14,832 coordinated accounts (mere sharers of an\nalerted URL were never promotion candidates); log scale",
       x = "Detection-frequency percentile threshold", y = "Accounts promoted") + thm

pB <- ggplot(sens, aes(percentile, freq_threshold)) +
  geom_vline(xintercept = 90, linetype = "dashed", colour = "grey45") +
  geom_step(colour = okabe[2], linewidth = 0.7) +
  geom_point(colour = okabe[2], size = 2) +
  scale_y_log10(breaks = c(1, 2, 5, 10, 25, 50, 100)) +
  scale_x_continuous(breaks = c(0, 25, 50, 75, 90, 99)) +
  labs(title = "Implied detection-frequency threshold",
       subtitle = "Distinct alert URLs required for promotion at each percentile;\nthe deployed 90th percentile requires 10. Log scale",
       x = "Detection-frequency percentile threshold",
       y = "Distinct alert URLs required") + thm

two_panel_pdf(file.path(fig_dir, "threshold_sensitivity.pdf"), pA, pB, width = 10, height = 4.4)

# =============================================================================
# 4. null_model_modularity_histogram.pdf  (annotation inside panel)
# =============================================================================
nb <- readRDS("data/validation/rds/null_bipartite_perms.rds")
mod_null <- nb$perms[, "louvain_modularity"]
mod_obs  <- nb$observed["louvain_modularity"]
np       <- nrow(nb$perms)
p_val    <- (1 + sum(mod_null >= mod_obs)) / (np + 1)

ann <- sprintf("observed = %.3f\nnull mean = %.3f (SD %.3f)\np = %.2e (%d permutations)",
               mod_obs, mean(mod_null), sd(mod_null), p_val, np)

p4 <- ggplot(data.table(m = mod_null), aes(m)) +
  geom_histogram(bins = 40, fill = okabe[1], colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = mod_obs, colour = okabe[4], linewidth = 0.8) +
  annotate("label", x = mod_obs - 0.02, y = Inf, vjust = 1.15, hjust = 1,
           label = ann, size = 2.9, colour = "grey20",
           label.size = 0.2, fill = "white", alpha = 0.9) +
  scale_x_continuous(limits = c(0, max(0.75, mod_obs * 1.1))) +
  labs(title = "Louvain modularity: observed vs. Curveball null",
       subtitle = sprintf("Degree-preserving permutations of the account-URL bipartite graph (%d permutations, 200N trades each);\n95th-percentile edge filter re-applied to every permuted projection", np),
       x = "Modularity of the filtered co-sharing projection", y = "Permutations") + thm

ggsave(file.path(fig_dir, "null_model_modularity_histogram.pdf"), p4, width = 7, height = 4.2)

# =============================================================================
# 5. rr_strict_replication_network.pdf
# =============================================================================
rr <- readRDS("data/validation/rds/rr_strict_graph.rds")
g  <- rr$graph
memb <- rr$membership

lay <- layout_with_fr(g, weights = E(g)$weight)
nodes <- data.table(x = lay[, 1], y = lay[, 2], comm = factor(memb),
                    deg = degree(g))
el <- as_edgelist(g, names = FALSE)
edges <- data.table(x = lay[el[, 1], 1], y = lay[el[, 1], 2],
                    xend = lay[el[, 2], 1], yend = lay[el[, 2], 2])

# one distinct qualitative hue per community (identity-by-position; no legend)
comm_cols <- grDevices::hcl.colors(nlevels(nodes$comm), "Dark 3")
cent <- nodes[, .(x = median(x), y = median(y), n = .N), by = comm][n >= 20]

p5 <- ggplot() +
  geom_segment(data = edges, aes(x = x, y = y, xend = xend, yend = yend),
               colour = "grey75", linewidth = 0.12, alpha = 0.35) +
  geom_point(data = nodes, aes(x, y, colour = comm), size = 1.1) +
  geom_label(data = cent, aes(x, y, label = paste0("n=", n)), size = 2.6,
             colour = "grey20", label.size = 0.15, alpha = 0.85) +
  scale_colour_manual(values = comm_cols, guide = "none") +
  coord_equal() +
  labs(title = "Strict-replication co-sharing network (99th-percentile filter)",
       subtitle = sprintf("%d accounts, %s edges (weight >= %d shared URLs), %d Louvain communities (coloured);\nlabels mark communities with >= 20 accounts",
                          vcount(g), format(ecount(g), big.mark = ","),
                          rr$threshold, length(unique(memb))),
       caption = "Replication of the Rogers & Righetti strict coordination filter on the full co-sharing projection.") +
  theme_void(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(size = 9, colour = "grey30"),
        plot.caption = element_text(size = 7.5, colour = "grey40", hjust = 0))

ggsave(file.path(fig_dir, "rr_strict_replication_network.pdf"), p5, width = 7, height = 6.5)

# =============================================================================
# 6. rr_typology_prevalence.pdf
# =============================================================================
typ <- fread("/home/fg/projects/VeraAI-Alert-ResearchNote/source_materials/typology_table.csv")
strict <- fread("data/validation/rr_strict_communities.csv")

actor_levels <- typ[, .N, by = rr_actor_type][order(-N), rr_actor_type]
prev <- rbind(
  typ[, .(n = .N), by = .(rr_actor_type)][, group := "All communities (n = 207)"],
  strict[!is.na(rr_actor_type), .(n = .N), by = .(rr_actor_type)][
    , group := "Strict-replication communities (n = 19)"])
prev[, share := n / sum(n), by = group]
prev[, rr_actor_type := factor(rr_actor_type, levels = rev(actor_levels))]

p6 <- ggplot(prev, aes(share, rr_actor_type, fill = group)) +
  geom_col(position = position_dodge(width = 0.8, preserve = "single"),
           width = 0.7) +
  geom_text(aes(label = n, group = group),
            position = position_dodge(width = 0.8, preserve = "single"),
            hjust = -0.25, size = 2.8, colour = "grey20") +
  scale_fill_manual(values = okabe[1:2], name = NULL) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                     expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Rogers & Righetti actor types: full catalogue vs. strict-replication set",
       subtitle = "Bars show within-group shares; labels show community counts",
       caption = "n = 19 refers to the Louvain communities of the strict (99th-percentile) subgraph, each assigned the\nactor type of the catalogue community holding the majority of its accounts.",
       x = "Share of communities", y = NULL) +
  thm + theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "rr_typology_prevalence.pdf"), p6, width = 7.5, height = 4.6)

# =============================================================================
# 7. coordination_degree_2d.pdf
# =============================================================================
# Threshold recovery (documented): among the 126 communities with a
# persistence score, the classes are separated (95.2% correctly) by
#   mean_alerts_per_account < 2                    -> sporadic / weakly coord.
#   otherwise gini < 0.171                         -> full-scale
#   otherwise gini < 0.486                         -> broad-distribution
#   otherwise                                      -> core-driven
# (gini cut points are midpoints of the empirical class ranges:
#  full-scale <= 0.152 < 0.190 <= broad <= 0.477 < 0.495 <= core-driven;
#  the 6 misclassified communities are small sporadic ones at exactly
#  2-2.5 mean alerts). 81 communities carry no persistence score (NA).
typ2 <- typ[!is.na(gini_persistence)]
thr1 <- (max(typ2[rr_coord_type == "full-scale", gini_persistence]) +
         min(typ2[rr_coord_type == "broad-distribution", gini_persistence])) / 2
thr2 <- (max(typ2[rr_coord_type == "broad-distribution", gini_persistence]) +
         min(typ2[rr_coord_type == "core-driven", gini_persistence])) / 2
thr_x <- log10(2)
deg_levels <- c("sporadic / weakly coordinated", "broad-distribution",
                "full-scale", "core-driven")
typ2[, rr_coord_type := factor(rr_coord_type, levels = deg_levels)]

p7 <- ggplot(typ2, aes(log10(mean_alerts_per_account), gini_persistence,
                       colour = rr_coord_type, size = n_accounts)) +
  geom_hline(yintercept = c(thr1, thr2), linetype = "dashed", colour = "grey55") +
  geom_vline(xintercept = thr_x, linetype = "dashed", colour = "grey55") +
  geom_point(alpha = 0.75) +
  annotate("text", x = 1.58, y = thr1, vjust = -0.5, hjust = 1, size = 2.7,
           colour = "grey35", label = sprintf("gini = %.2f", thr1)) +
  annotate("text", x = 1.58, y = thr2, vjust = -0.5, hjust = 1, size = 2.7,
           colour = "grey35", label = sprintf("gini = %.2f", thr2)) +
  annotate("text", x = thr_x, y = 0.83, hjust = -0.1, size = 2.7,
           colour = "grey35", label = "2 alerts/account") +
  scale_colour_manual(values = okabe[c(6, 1, 3, 4)], name = "Coordination degree") +
  scale_size_area(max_size = 9, labels = scales::comma, name = "Accounts") +
  labs(title = "Coordination degree by persistence concentration and alert intensity",
       subtitle = sprintf("%d communities with a persistence score (%d carry none and are not shown).\nDashed lines: recovered class boundaries (95%% of scored communities separated).",
                          nrow(typ2), sum(is.na(typ$gini_persistence))),
       x = expression(log[10] * "(mean alerts per account)"),
       y = "Gini of account persistence") +
  thm + theme(legend.position = "right")

ggsave(file.path(fig_dir, "coordination_degree_2d.pdf"), p7, width = 7.5, height = 4.8)

# =============================================================================
# 8. engagement_signature.pdf
# =============================================================================
eng <- fread("data/processed/community_engagement_classified.csv")
for (m in c("likes", "shares", "comments", "love", "wow", "haha", "sad", "angry"))
  set(eng, j = m, value = eng[[paste0("total_", m, "_cross_community")]] +
                          eng[[paste0("total_", m, "_exclusive")]])
eng[, engagement8 := likes + shares + comments + love + wow + haha + sad + angry]
cos_dt <- eng[engagement8 > 0]
V <- as.matrix(cos_dt[, .(likes, shares, comments, love, wow, haha, sad, angry)])
V <- V / rowSums(V)
Vn <- V / sqrt(rowSums(V^2))
D <- 1 - tcrossprod(Vn)
ut <- upper.tri(D)
same <- outer(cos_dt$primary_focus, cos_dt$primary_focus, "==")[ut]
pairs_dt <- data.table(dist = D[ut],
                       type = fifelse(same, "Same category", "Different category"))
cp <- readRDS("data/validation/rds/engagement_cosine_perms.rds")
p_cos <- (1 + sum(cp$null >= cp$observed)) / (length(cp$null) + 1)

p8 <- ggplot(pairs_dt, aes(type, dist, fill = type)) +
  geom_violin(colour = NA, alpha = 0.65, width = 0.9) +
  geom_boxplot(width = 0.12, outlier.size = 0.4, outlier.alpha = 0.25,
               fill = "white", linewidth = 0.35) +
  scale_fill_manual(values = okabe[c(2, 1)], guide = "none") +
  scale_y_continuous(limits = c(0, 1)) +
  labs(title = "Engagement-signature similarity within vs. between categories",
       subtitle = sprintf("Pairwise cosine distances between community engagement compositions (8 reaction/engagement types).\nN = %d communities, %s pairs; label-permutation test p = %.3f (%d permutations)",
                          cp$n, format(cp$n_pairs, big.mark = ","), p_cos, length(cp$null)),
       caption = "3 of 207 communities excluded for zero recorded engagement.",
       x = NULL, y = "Cosine distance") + thm

ggsave(file.path(fig_dir, "engagement_signature.pdf"), p8, width = 7, height = 4.4)

message("All figures written to ", fig_dir)
