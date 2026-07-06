# =============================================================================
# 05_rr_strict_replication.R — Strict replication of the Rogers & Righetti
# 99th-percentile coordination filter on the full co-sharing projection.
#
# Procedure: take the UNFILTERED weighted projection (weight = n distinct
# shared URLs), compute the 99th percentile of edge weights (quantile type 7),
# keep edges with weight >= threshold, drop isolates, and run weighted
# Louvain on the resulting strict subgraph.
#
# Comparison rows in the output:
#   reproduced      : this script's run
#   old_claimed     : the pre-restoration validation claim (633 / 7,603 / 19)
#   rr_published    : Rogers & Righetti's own figures  (743 / 16,670 / 19)
#
# The strict subgraph's Louvain communities are then mapped to the
# 207-community catalogue (majority vote over member accounts, using the
# account lists of data/processed/community_engagement_classified.csv;
# account URLs are normalised — protocol/www stripped — because the two
# files store them in different formats; the account lists of the 4 largest
# communities are truncated at ~32k characters in the CSV, so a small share
# of strict nodes cannot be mapped and are excluded from the vote).
#
# Output: data/validation/rr_strict_replication.csv
#         data/validation/rr_strict_communities.csv (per strict community:
#           size + mapped catalogue community + its label/actor type)
#         data/validation/rds/rr_strict_graph.rds (graph + membership,
#           for the network figure)
# =============================================================================

suppressMessages({
  library(data.table)
  library(igraph)
})

root <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
setwd(root)
set.seed(20260705)

g_full <- readRDS("data/validation/rds/projection_full.rds")
w <- E(g_full)$weight
thr99 <- quantile(w, 0.99, type = 7)
g_strict <- subgraph_from_edges(g_full, which(w >= thr99), delete.vertices = TRUE)

cl <- cluster_louvain(g_strict, weights = E(g_strict)$weight)
memb <- membership(cl)
sz <- sizes(cl)
message(sprintf("Strict subgraph: %d nodes, %d edges, %d Louvain communities (threshold >= %d shared URLs)",
                vcount(g_strict), ecount(g_strict), length(sz), thr99))

out <- data.table(
  source            = c("reproduced", "old_claimed", "rr_published"),
  pct_threshold     = c(99, 99, 99),
  weight_threshold  = c(thr99, NA, NA),
  nodes             = c(vcount(g_strict), 633, 743),
  edges             = c(ecount(g_strict), 7603, 16670),
  louvain_communities = c(length(sz), 19, 19),
  modularity        = c(round(modularity(cl), 3), NA, NA),
  community_sizes   = c(paste(sort(as.integer(sz), decreasing = TRUE), collapse = ";"), NA, NA)
)
fwrite(out, "data/validation/rr_strict_replication.csv")
print(out[, 1:6])

# ---- Map strict Louvain communities to the 207-community catalogue -----------
norm_url <- function(x) {
  x <- tolower(trimws(x))
  x <- sub("^https?://", "", x)
  x <- sub("^www\\.", "", x)
  sub("/$", "", x)
}

eng <- fread("data/processed/community_engagement_classified.csv")
cat_map <- eng[, .(acct_norm = norm_url(unlist(strsplit(account_urls, ";", fixed = TRUE)))),
               by = .(source_community, label)]

nodes <- data.table(acct = V(g_strict)$name, strict_comm = as.integer(memb))
nodes[, acct_norm := norm_url(acct)]
nodes <- merge(nodes, cat_map[, .(acct_norm, source_community)],
               by = "acct_norm", all.x = TRUE)
message(sprintf("Strict nodes mapped to catalogue: %d / %d (unmapped are in the 4 truncated account lists)",
                sum(!is.na(nodes$source_community)), nrow(nodes)))

vote <- nodes[!is.na(source_community),
              .N, by = .(strict_comm, source_community)][
              order(strict_comm, -N)][, .SD[1], by = strict_comm]

# Join catalogue metadata (labels + R&R types) from the writing project table
typ <- fread("/home/fg/projects/VeraAI-Alert-ResearchNote/source_materials/typology_table.csv")
# typology_table community_id and source_community use the same id space
# (verified: label + n_accounts join matches 207/207)
strict_comms <- merge(
  data.table(strict_comm = as.integer(names(sz)), size = as.integer(sz)),
  vote[, .(strict_comm, catalogue_community = source_community, votes = N)],
  by = "strict_comm", all.x = TRUE)
strict_comms <- merge(strict_comms,
                      typ[, .(catalogue_community = community_id, label,
                              primary_focus, rr_actor_type, rr_coord_type)],
                      by = "catalogue_community", all.x = TRUE)
setorder(strict_comms, -size)
fwrite(strict_comms, "data/validation/rr_strict_communities.csv")
message("Distinct catalogue communities in strict overlap: ",
        uniqueN(strict_comms$catalogue_community, na.rm = TRUE))
print(strict_comms[, .(strict_comm, size, catalogue_community, rr_actor_type)])

saveRDS(list(graph = g_strict, membership = memb, threshold = thr99,
             strict_comms = strict_comms),
        "data/validation/rds/rr_strict_graph.rds")
