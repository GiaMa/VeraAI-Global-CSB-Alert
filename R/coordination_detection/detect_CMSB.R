# =============================================================================
# Coordinated Message Sharing Behavior (CMSB) Detection
# =============================================================================
#
# Description:
#   Detects accounts that share posts with highly similar text messages within
#   a short time window, indicating potential coordinated behavior.
#
# Algorithm:
#   1. Extract message text from monitored posts
#   2. Create document-feature matrix using quanteda
#   3. Calculate pairwise cosine similarity between messages
#   4. Filter pairs with similarity >= 0.7 (catches paraphrasing)
#   5. Query CrowdTangle for other posts with matching message text
#   6. Group posts by time intervals (coordination_interval)
#   7. Build bipartite network: accounts <-> similar messages
#   8. Project to account-account network (shared message = edge)
#   9. Filter edges by percentile_edge_weight threshold
#   10. Apply Louvain clustering to identify coordinated groups
#   11. Return platform IDs of highly connected accounts
#
# =============================================================================

#' Detect Coordinated Message Sharing Behavior (CMSB)
#'
#' Identifies accounts sharing posts with highly similar text messages within
#' a coordination window. Uses cosine similarity to detect paraphrased content.
#'
#' @param oposts A dataframe of posts returned by CrowdTangle search query.
#'   Must contain columns: platformId, date, message, account.name,
#'   account.handle, account.url, account.platformId, postUrl
#' @param timeframe Time window for CrowdTangle search (e.g., "6 HOUR", "1 DAY")
#' @param coordination_interval Maximum time between posts to be considered
#'   coordinated (e.g., "60 secs", "5 mins")
#' @param percentile_edge_weight Percentile threshold for edge weight filtering.
#'   Higher values (e.g., 0.95) keep only the most connected accounts.
#'
#' @return Character vector of account.platformId values for accounts
#'   exhibiting coordinated message sharing, or NULL if none detected.
#'
#' @details
#' The function uses quanteda's cosine similarity with a threshold of 0.7
#' to identify similar messages, allowing detection of paraphrased content
#' rather than requiring exact matches.
#'
#' Network analysis uses bipartite projection: accounts are connected if
#' they shared similar messages. Edge weight represents the number of
#' co-shared similar messages.
#'
#' @import dplyr
#' @import lubridate
#' @import quanteda
#' @import quanteda.textstats
#' @import urltools
#' @import stringr
#' @import igraph
#' @import tidytable
#'
#' @examples
#' \dontrun{
#' coordinated_ids <- detect_cmsb(
#'   oposts = posts_dataframe,
#'   timeframe = "6 HOUR",
#'   coordination_interval = "60 secs",
#'   percentile_edge_weight = 0.95
#' )
#' }

detect_cmsb <- function(oposts = NULL,
                        timeframe = "6 HOUR",
                        coordination_interval = "60 secs",
                        percentile_edge_weight = 0.95) {
  
  if(is.null(oposts)) {
    stop("Please provide a dataframe of posts returned by a CrowdTangle search posts query")
  }
  
  keep <- c("platformId",
            "type",
            "date",
            "message",
            "account.name",     
            "account.handle",
            "account.url",
            "account.platformId",
            "postUrl")
  
  # Filter to posts with message text

  msg_posts <- oposts %>%
    select(all_of(keep)) %>%
    distinct() %>%
    filter(!is.na(message) | message == "")

  # ---------------------------------------------------------------------------
  # Step 1: Compute text similarity using cosine similarity
  # ---------------------------------------------------------------------------
  # Create corpus and document-feature matrix for similarity calculation
  corp <- quanteda::corpus(msg_posts$message, docnames = row.names(msg_posts))
  dfm <- tokens(corp) %>%
    dfm()
  
  sim_msg <- as.list(quanteda.textstats::textstat_simil(dfm, method = "cosine", min_simil = 0.7, margin = "documents"), diag=FALSE)
  
  msg_posts <- msg_posts[rownames(msg_posts) %in% names(sim_msg), ] # keep only similar messages
  msg_posts$message <- gsub(" ?(f|ht)(tp)(s?)(://)(.*)[.|/](.*)", "", msg_posts$message) # remove hyperlinks
  
  m <- unique(msg_posts$message)
  m <- m[m != ""]
  clean_m <- stringr::str_replace_all(m, "[[:punct:]]", "")
  
  # get posts with matching messages
  if (length(m)>0) {
    
    datalist<- NULL
    
    for (i in 1:length(m)) {
      query.string <- paste0("https://api.crowdtangle.com/posts/search?",
                             "count=100",
                             "&timeframe=", url_encode(timeframe),
                             "&sortBy=date",
                             "&searchTerm=", url_encode(clean_m[i]),
                             "&searchField=text_fields_only",
                             "&token=", Sys.getenv("CROWDTANGLE_API_KEY"))
      
      resp <- httr::RETRY(verb = "GET", url = query.string, pause_base = 2, pause_min = 2)
      response.json <- httr::content(resp, as = "text", type="application/json", encoding = "UTF-8")
      parsed <- jsonlite::fromJSON(response.json, flatten = TRUE)
      
      if (length(parsed$result$posts) > 0) {
        lposts <- parsed$result$posts
        datalist <- c(list(lposts), datalist)
      }

      Sys.sleep(5)
    }
    
    if (!is.null(datalist) & length(datalist)>0) {
      
      ct_shares.df <- tidytable::bind_rows(datalist)
      rm(datalist)
      
      ct_shares.df <- subset(ct_shares.df, !is.na(message))
      
      # detect coordinated shares
      # for each unique message execute CooRnet code to find coordination
      
      datalist <- list()
      
      # progress bar
      total <- length(m)
      pb <- txtProgressBar(max=total, style=3)
      for (j in 1:total) {
        utils::setTxtProgressBar(pb, pb$getVal()+1)
        current_msg <- m[j]
        dat.summary <- ct_shares.df[row.names(ct_shares.df) %in% as.character(grep(pattern = current_msg, x = ct_shares.df$message, fixed = TRUE))]
        if (length(unique(dat.summary$account.url)) > 1) {
          dat.summary <- dat.summary %>%
            dplyr::mutate(cut = cut(as.POSIXct(date), breaks = coordination_interval)) %>%
            dplyr::group_by(cut) %>%
            dplyr::mutate(count=dplyr::n(),
                          account.url=list(account.url),
                          share_date=list(date),
                          message = current_msg) %>%
            dplyr::select(cut, count, account.url, share_date, message) %>%
            dplyr::filter(count > 1) %>%
            unique()
          
          if (nrow(dat.summary)>0) {
            datalist <- c(list(dat.summary), datalist)
          }
          rm(dat.summary)
        }
      }
      
      if (length(datalist) > 0) {
        datalist <- tidytable::bind_rows(datalist)
        coordinated_shares <- tidytable::unnest(datalist)
        rm(datalist)

        # Mark which shares in the dataset are coordinated
        ct_shares.df$is_coordinated <- ifelse(
          ct_shares.df$message %in% coordinated_shares$message &
          ct_shares.df$date %in% coordinated_shares$share_date &
          ct_shares.df$account.url %in% coordinated_shares$account.url,
          TRUE, FALSE
        )

        # -----------------------------------------------------------------------
        # Step 3: Build bipartite network (accounts <-> messages)
        # -----------------------------------------------------------------------
        # Create edge list: account.url -> message
        edge_list <- coordinated_shares[, c("account.url", "message", "share_date")]

        # Create vertex list with types (1 = account, 0 = message)
        account_vertices <- data.frame(node = unique(edge_list$account.url), type = 1)
        message_vertices <- data.frame(node = unique(edge_list$message), type = 0)
        vertices <- rbind(account_vertices, message_vertices)

        # Build bipartite graph
        bipartite_graph <- igraph::graph.data.frame(edge_list, directed = TRUE, vertices = vertices)
        bipartite_graph <- igraph::simplify(bipartite_graph, remove.multiple = TRUE, remove.loops = TRUE, edge.attr.comb = "min")

        # -----------------------------------------------------------------------
        # Step 4: Project to account-account network
        # -----------------------------------------------------------------------
        # Accounts sharing the same message are connected; edge weight = # shared messages
        full_g <- suppressWarnings(igraph::bipartite.projection(bipartite_graph, multiplicity = TRUE)$proj2)
        
        all_account_info <- ct_shares.df %>%
          dplyr::group_by(account.url) %>%
          dplyr::mutate(account.name.changed = ifelse(length(unique(account.name))>1, TRUE, FALSE), # deal with account.data that may have changed (name, handle)
                        account.name = paste(unique(account.name), collapse = " | "),
                        account.handle.changed = ifelse(length(unique(account.handle))>1, TRUE, FALSE),
                        account.handle = paste(unique(account.handle), collapse = " | ")) %>%
          dplyr::summarize(shares = dplyr::n(),
                           coord.shares = sum(is_coordinated==TRUE),
                           account.name = dplyr::first(account.name), # name
                           account.name.changed = dplyr::first(account.name.changed),
                           account.handle.changed = dplyr::first(account.handle.changed), # handle
                           account.handle = dplyr::first(account.handle),
                           account.platformId = dplyr::first(account.platformId))
        
        # add vertex attributes
        vertex.info <- subset(all_account_info, as.character(all_account_info$account.url) %in% igraph::V(full_g)$name)
        V(full_g)$account.platformId <- sapply(V(full_g)$name, function(x) vertex.info$account.platformId[vertex.info$account.url == x])
        V(full_g)$shares <- sapply(V(full_g)$name, function(x) vertex.info$shares[vertex.info$account.url == x])
        V(full_g)$coord.shares <- sapply(V(full_g)$name, function(x) vertex.info$coord.shares[vertex.info$account.url == x])
        V(full_g)$account.name <- sapply(V(full_g)$name, function(x) vertex.info$account.name[vertex.info$account.url == x])
        V(full_g)$name.changed <- sapply(V(full_g)$name, function(x) vertex.info$account.name.changed[vertex.info$account.url == x])
        V(full_g)$account.handle <- sapply(V(full_g)$name, function(x) vertex.info$account.handle[vertex.info$account.url == x])
        V(full_g)$handle.changed <- sapply(V(full_g)$name, function(x) vertex.info$account.handle.changed[vertex.info$account.url == x])
        # keep only highly coordinated entities
        V(full_g)$degree <- igraph::degree(full_g)
        q <- quantile(E(full_g)$weight, percentile_edge_weight) # set the percentile_edge_weight number of repeatedly coordinated link sharing to keep
        highly_connected_g <- igraph::induced_subgraph(graph = full_g, vids = V(full_g)[V(full_g)$degree > 0 ]) # filter for degree
        highly_connected_g <- igraph::subgraph.edges(highly_connected_g, eids = which(E(highly_connected_g)$weight >= q),delete.vertices = T) # filter for edge weight
        # find and annotate nodes-components
        V(highly_connected_g)$component <- igraph::components(highly_connected_g)$membership
        V(highly_connected_g)$cluster <- igraph::cluster_louvain(highly_connected_g)$membership # add cluster to simplify the analysis of large components
        V(highly_connected_g)$degree <- igraph::degree(highly_connected_g) # re-calculate the degree on the sub graph
        V(highly_connected_g)$strength <- igraph::strength(highly_connected_g) # sum up the edge weights of the adjacent edges for each vertex
        highly_connected_coordinated_entities <- igraph::as_data_frame(highly_connected_g, "vertices")
        
        if(nrow(highly_connected_coordinated_entities)>0) {
          rownames(highly_connected_coordinated_entities) <- 1:nrow(highly_connected_coordinated_entities)
        }
        
        ##############################################
        # LOG UPDATE
        ##############################################
        
        message(paste0 ("\n", "######### ", nrow(highly_connected_coordinated_entities), " COORDINATED IMAGE MESSAGE ACCOUNTS DETECTED #########", "\n"))
        
        return(unlist(highly_connected_coordinated_entities$account.platformId))
      } else {
        ##############################################
        # LOG UPDATE
        ##############################################
        
        message(paste0 ("\n", "######### NO COORDINATED POSTS MESSAGE DETECTED #########", "\n"))
        
        return(NULL)
      }
    }
  }
}