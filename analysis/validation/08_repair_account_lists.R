# Repair truncated account lists in data/processed/community_engagement_classified.csv
#
# Four communities (1, 2, 6, 45) have account_urls/account_names cut at
# ~32,015 chars (Excel cell limit) with a literal "... [truncated]" marker.
# The missing members are reconstructed from the full co-sharing projection:
# every graph account absent from all 207 lists is assigned to the truncated
# community where its total co-share edge weight to known members is highest.
# The repair is accepted only if every community ends with exactly
# n_accounts members.
#
# Run from the project root: Rscript analysis/validation/08_repair_account_lists.R

library(data.table)
library(igraph)

set.seed(20260706)

csv_path <- "data/processed/community_engagement_classified.csv"
dt <- fread(csv_path, colClasses = "character")
dt[, n_accounts_i := as.integer(n_accounts)]

norm_url <- function(x) {
  x <- tolower(trimws(x))
  x <- sub("^https?://", "", x)
  x <- sub("^www\\.", "", x)
  sub("/$", "", x)
}

split_list <- function(s) {
  out <- trimws(strsplit(s, ";", fixed = TRUE)[[1]])
  out[nzchar(out)]
}

# --- parse lists, drop truncation artefacts -------------------------------
lists <- lapply(dt$account_urls, split_list)
names_l <- lapply(dt$account_names, split_list)
trunc_idx <- which(grepl("\\[truncated\\]$", dt$account_urls))
stopifnot(length(trunc_idx) == 4)
for (i in trunc_idx) {
  # last element is a cut fragment ("faceboo... [truncated]") — drop it
  lists[[i]] <- head(lists[[i]], -1)
  if (grepl("\\[truncated\\]$", tail(names_l[[i]], 1))) {
    names_l[[i]] <- head(names_l[[i]], -1)
  }
}

listed_norm <- lapply(lists, norm_url)
all_listed <- unlist(listed_norm)
cat("Listed accounts after dropping fragments:", length(all_listed),
    "(", uniqueN(all_listed), "unique )\n")

# --- graph accounts -------------------------------------------------------
g <- readRDS("data/validation/rds/projection_full.rds")
gnames <- V(g)$name
gnorm <- norm_url(gnames)
stopifnot(!anyDuplicated(gnorm))

missing_norm <- setdiff(gnorm, all_listed)
cat("Graph accounts missing from all lists:", length(missing_norm), "\n")
deficit <- dt$n_accounts_i[trunc_idx] - lengths(lists[trunc_idx])
cat("Deficits by truncated community:",
    paste(dt$source_community[trunc_idx], deficit, collapse = " | "), "\n")
stopifnot(sum(deficit) == length(missing_norm))

# --- assign missing accounts by co-share weight to known members ----------
edges <- as.data.table(as_data_frame(g, what = "edges"))
edges[, `:=`(from_n = norm_url(from), to_n = norm_url(to),
             weight = as.numeric(weight))]

member_of <- data.table(acc = unlist(listed_norm[trunc_idx]),
                        comm = rep(dt$source_community[trunc_idx],
                                   lengths(listed_norm[trunc_idx])))

# Iterative assignment: accounts whose only edges run to other missing
# accounts become assignable once their neighbours are placed.
assign <- data.table(miss = character(), comm = character(), w = numeric())
unplaced <- missing_norm
members <- copy(member_of)
repeat {
  long <- rbind(
    edges[from_n %in% unplaced & to_n %in% members$acc,
          .(miss = from_n, known = to_n, weight)],
    edges[to_n %in% unplaced & from_n %in% members$acc,
          .(miss = to_n, known = from_n, weight)]
  )
  if (nrow(long) == 0) break
  long <- merge(long, members, by.x = "known", by.y = "acc",
                allow.cartesian = TRUE)
  scores <- long[, .(w = sum(weight)), by = .(miss, comm)]
  new_assign <- scores[order(miss, -w), .SD[1], by = miss]
  if (nrow(new_assign) == 0) break
  assign <- rbind(assign, new_assign)
  members <- rbind(members, new_assign[, .(acc = miss, comm)])
  unplaced <- setdiff(unplaced, new_assign$miss)
  if (length(unplaced) == 0) break
}
cat("Assigned by co-share weight (incl. iterative passes):", nrow(assign), "\n")
cat("Still unplaced after iteration:", length(unplaced), "\n")

# Elimination fallback: place remaining accounts into communities whose
# deficit is not yet met (deterministic only if unambiguous).
if (length(unplaced) > 0) {
  got0 <- assign[, .N, by = comm]
  rem <- data.table(comm = dt$source_community[trunc_idx],
                    need = as.integer(deficit))
  rem <- merge(rem, got0, by = "comm", all.x = TRUE)
  rem[is.na(N), N := 0L][, left := need - N]
  cat("Remaining deficits:\n"); print(rem[, .(comm, left)])
  open <- rem[left > 0]
  stopifnot(sum(open$left) == length(unplaced))
  if (nrow(open) == 1) {
    assign <- rbind(assign,
                    data.table(miss = unplaced, comm = open$comm, w = 0))
  } else {
    stop("Ambiguous elimination: ", length(unplaced),
         " accounts, ", nrow(open), " open communities — manual review needed")
  }
}

# Quota reconciliation: the weight-greedy pass can overfill one community
# at another's expense. Move the lowest-margin accounts from over-quota to
# under-quota communities until every deficit is met exactly.
quota <- data.table(comm = dt$source_community[trunc_idx],
                    need = as.integer(deficit))
repeat {
  got <- assign[, .N, by = comm]
  chk <- merge(quota, got, by = "comm", all.x = TRUE)[is.na(N), N := 0L]
  over  <- chk[N > need, comm]
  under <- chk[N < need, comm]
  if (length(over) == 0 && length(under) == 0) break
  cat("Reconciling quotas — over:", paste(over, collapse = ","),
      "| under:", paste(under, collapse = ","), "\n")
  members_final <- rbind(member_of, assign[, .(acc = miss, comm)])
  cand <- assign[comm %in% over]
  long2 <- rbind(
    edges[from_n %in% cand$miss & to_n %in% members_final$acc,
          .(miss = from_n, known = to_n, weight)],
    edges[to_n %in% cand$miss & from_n %in% members_final$acc,
          .(miss = to_n, known = from_n, weight)]
  )
  long2 <- merge(long2, members_final, by.x = "known", by.y = "acc",
                 allow.cartesian = TRUE)
  sc2 <- long2[comm %in% under, .(w_under = sum(weight)), by = .(miss, comm)]
  if (nrow(sc2) == 0) stop("No mover has any edge to an under-quota community")
  sc2 <- merge(sc2, assign[, .(miss, w_over = w, comm_over = comm)], by = "miss")
  sc2 <- sc2[comm_over %in% over][order(w_over - w_under, miss)]
  mv <- sc2[1]
  cat("  moving", mv$miss, "from", mv$comm_over, "to", mv$comm,
      "(w_over =", mv$w_over, ", w_under =", mv$w_under, ")\n")
  assign[miss == mv$miss, `:=`(comm = mv$comm, w = mv$w_under)]
}

got <- assign[, .N, by = comm][order(comm)]
print(got)
stopifnot(identical(
  got[match(dt$source_community[trunc_idx], comm), N],
  as.integer(deficit)
))

# --- rebuild the four lists (original URL form + names from alerts) -------
url_by_norm <- setNames(gnames, gnorm)
# canonical display form used in the CSV: strip protocol + www
display_url <- function(n) norm_url(url_by_norm[n])

alerts <- fread("data/alerts/veraai_alerts_links.csv", colClasses = "character",
                select = c("coo_r_account_url", "coo_r_account_name"))
# Account names may themselves contain commas, so positional pairing of the
# two comma-separated columns is only trusted where the counts agree.
pairs_list <- Map(function(us, ns) {
  u <- strsplit(us, ",", fixed = TRUE)[[1]]
  n <- strsplit(ns, ",", fixed = TRUE)[[1]]
  if (length(u) == length(n)) data.table(u = u, n = n) else NULL
}, alerts$coo_r_account_url, alerts$coo_r_account_name)
au <- rbindlist(pairs_list[!vapply(pairs_list, is.null, logical(1))])
au[, u := norm_url(u)]
au[, n := trimws(n)]
name_by_norm <- au[nzchar(n), .N, by = .(u, n)][order(u, -N), .SD[1], by = u]
name_lookup <- setNames(name_by_norm$n, name_by_norm$u)
cat("Name lookup covers", length(name_lookup), "accounts\n")

for (i in trunc_idx) {
  comm_id <- dt$source_community[i]
  add <- assign[comm == comm_id, miss]
  full_urls <- c(lists[[i]], display_url(add))
  add_names <- name_lookup[add]
  add_names[is.na(add_names)] <- display_url(add)[is.na(add_names)]
  full_names <- c(names_l[[i]], unname(add_names))
  stopifnot(length(full_urls) == dt$n_accounts_i[i])
  dt$account_urls[i] <- paste(full_urls, collapse = "; ")
  dt$account_names[i] <- paste(full_names, collapse = "; ")
}

# --- global verification ---------------------------------------------------
final_lists <- lapply(dt$account_urls, split_list)
stopifnot(all(lengths(final_lists) == dt$n_accounts_i))
stopifnot(sum(lengths(final_lists)) == 14832)
stopifnot(uniqueN(norm_url(unlist(final_lists))) == 14832)
cat("VERIFIED: all 207 lists match n_accounts; union = 14,832 unique accounts\n")

dt[, n_accounts_i := NULL]
fwrite(dt, csv_path, quote = TRUE)
cat("Repaired CSV written to", csv_path, "\n")
