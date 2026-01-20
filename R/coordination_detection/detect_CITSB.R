# =============================================================================
# Coordinated Image-Text Sharing Behavior (CITSB) Detection
# =============================================================================
#
# Description:
#   Detects accounts that share posts containing identical OCR-extracted
#   image text within a short time window, indicating potential coordinated
#   behavior using image-based content.
#
# Algorithm:
#   1. Extract imageText field from monitored posts (OCR data from CrowdTangle)
#   2. Identify image text appearing in multiple posts
#   3. Query CrowdTangle for other posts with matching image text
#   4. Group posts by time intervals (coordination_interval)
#   5. Build bipartite network: accounts <-> image text
#   6. Project to account-account network (shared image text = edge)
#   7. Filter edges by percentile_edge_weight threshold
#   8. Apply Louvain clustering to identify coordinated groups
#   9. Return platform IDs of highly connected accounts
#
# Note:
#   Unlike CMSB, this method uses EXACT matching on image text, making it
#   suitable for detecting coordinated sharing of memes, infographics, and
#   other image-based content. Requires additional API calls to CrowdTangle.
#
# =============================================================================

#' Detect Coordinated Image-Text Sharing Behavior (CITSB)
#'
#' Identifies accounts sharing posts with identical OCR-extracted image text
#' within a coordination window. Useful for detecting coordinated meme/image
#' sharing campaigns.
#'
#' @param oposts A dataframe of posts returned by CrowdTangle search query.
#'   Must contain columns: platformId, date, imageText, account.name,
#'   account.handle, account.url, account.platformId, postUrl
#' @param timeframe Time window for CrowdTangle search (e.g., "6 HOUR", "1 DAY")
#' @param coordination_interval Maximum time between posts to be considered
#'   coordinated (e.g., "60 secs", "5 mins")
#' @param percentile_edge_weight Percentile threshold for edge weight filtering.
#'   Higher values (e.g., 0.95) keep only the most connected accounts.
#'
#' @return Character vector of account.platformId values for accounts
#'   exhibiting coordinated image-text sharing, or NULL if none detected.
#'
#' @details
#' This function searches for posts with matching imageText (OCR-extracted
#' text from images). It requires additional API calls to CrowdTangle,
#' making it more expensive than CMSB detection.
#'
#' Network analysis uses bipartite projection: accounts are connected if
#' they shared identical image text. Edge weight represents the number of
#' co-shared image texts.
#'
#' @import tidytable
#' @import dplyr
#' @import lubridate
#' @import urltools
#' @import stringr
#' @import igraph
#' @import httr
#' @import jsonlite
#'
#' @examples
#' \dontrun{
#' coordinated_ids <- detect_citsb(
#'   oposts = posts_dataframe,
#'   timeframe = "6 HOUR",
#'   coordination_interval = "60 secs",
#'   percentile_edge_weight = 0.95
#' )
#' }

detect_citsb <- function(oposts = NULL,
                         timeframe = "6 HOUR",
                         coordination_interval = "60 secs",
                         percentile_edge_weight = 0.95) {
  
  if(is.null(oposts)) {
    stop("Please provide a dataframe of posts returned by a CrowdTangle search posts query")
  }
  
  keep <- c("platformId",
            "type",
            "date",
            "imageText",
            "account.name",     
            "account.handle",
            "account.url",
            "account.platformId",
            "postUrl")
  
  imgtext_posts <- unique(subset(oposts, select = keep))
  imgtext_posts <- imgtext_posts %>% distinct()
  
  # remove posts where img_text is empty
  imgtext_posts <- subset(imgtext_posts, !is.na(imgtext_posts$imageText))
  
  # extract a frequency table of unique identical img_text in the dataset
  unique_imageText <- as.data.frame(table(imgtext_posts$imageText))
  names(unique_imageText) <- c("imageText", "ct_shares")
  unique_imageText$imageText <- as.character(unique_imageText$imageText)
  
  imgtext_posts <- subset(imgtext_posts, imgtext_posts$imageText %in% unique_imageText$imageText)
  
  # collects shares for unique img_text shared at least two times
  top_unique_imageText <- unique_imageText %>%
    arrange(-ct_shares) %>%
    filter(ct_shares>1)
  
  if (nrow(top_unique_imageText>0)) {
    
    datalist<- NULL
    
    for (i in 1:nrow(top_unique_imageText)) {
      query.string <- paste0("https://api.crowdtangle.com/posts/search?",
                             "count=100",
                             "&timeframe=", url_encode(timeframe),
                             "&sortBy=date",
                             "&searchTerm=", url_encode(top_unique_imageText$imageText[i]),
                             "&searchField=image_text_only",
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
      
      ct_shares.df <- subset(ct_shares.df, !is.na(imageText))
      
      # detect coordinated shares
      # for each unique img_text execute CooRnet code to find coordination
      
      datalist <- list()
      
      # progress bar
      total <- nrow(top_unique_imageText)
      pb <- txtProgressBar(max=total, style=3)
      for (j in 1:nrow(top_unique_imageText)) {
        utils::setTxtProgressBar(pb, pb$getVal()+1)
        current_imageText <- top_unique_imageText$imageText[j]
        
        dat.summary <- subset(ct_shares.df, ct_shares.df$imageText==current_imageText)
        if (length(unique(dat.summary$account.url)) > 1) {
          dat.summary <- dat.summary %>%
            dplyr::mutate(cut = cut(as.POSIXct(date), breaks = coordination_interval)) %>%
            dplyr::group_by(cut) %>%
            dplyr::summarize(count=dplyr::n(),
                             account.url=list(account.url),
                             share_date=list(date),
                             imageText = dplyr::first(current_imageText)) %>%
            dplyr::filter(count > 1) %>%
            unique()
          
          if (nrow(dat.summary)>0) {
            datalist <- c(list(dat.summary), datalist)
          }
          rm(dat.summary)
        }
      }
      
      if (length(datalist)>0) {
        datalist <- tidytable::bind_rows(datalist)
        coordinated_shares <- tidytable::unnest(datalist)
        rm(datalist)
        
        # mark the coordinated shares in the data set
        ct_shares.df$is_coordinated <- ifelse(ct_shares.df$imageText %in% coordinated_shares$imageText &
                                                ct_shares.df$date %in% coordinated_shares$share_date &
                                                ct_shares.df$account.url %in% coordinated_shares$account.url, TRUE, FALSE)
        
        el <- coordinated_shares[,c("account.url", "imageText", "share_date")] # drop unnecessary columns
        v1 <- data.frame(node=unique(el$account.url), type=1) # create a dataframe with nodes and type 0=imageText 1=page
        v2 <- data.frame(node=unique(el$imageText), type=0)
        v <- rbind(v1,v2)
        g2.bp <- igraph::graph.data.frame(el, directed = T, vertices = v) # makes the bipartite graph
        g2.bp <- igraph::simplify(g2.bp, remove.multiple = T, remove.loops = T, edge.attr.comb = "min") # simplify the bipartite network to avoid problems with resulting edge weight in projected network
        full_g <- suppressWarnings(igraph::bipartite.projection(g2.bp, multiplicity = T)$proj2) # project entity-entity network
        
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
        rownames(highly_connected_coordinated_entities) <- 1:nrow(highly_connected_coordinated_entities)
        
        ##############################################
        # LOG UPDATE
        ##############################################
        
        message(paste0 ("\n", "######### ", nrow(highly_connected_coordinated_entities), " COORDINATED IMAGE MESSAGE ACCOUNTS DETECTED #########", "\n"))
        
        return(unlist(highly_connected_coordinated_entities$account.platformId))
        
      } else {
        ##############################################
        # LOG UPDATE
        ##############################################
        
        message(paste0 ("\n", "######### NO COORDINATED IMAGE TXT POSTS DETECTED #########", "\n"))
        
        return(NULL)
      }
    } else {
      ##############################################
      # LOG UPDATE
      ##############################################
      
      message(paste0 ("\n", "######### NO COORDINATED IMAGE TXT POSTS DETECTED #########", "\n"))
      
      return(NULL)
    }
  } else {
    ##############################################
    # LOG UPDATE
    ##############################################
    
    message(paste0 ("\n", "######### NO COORDINATED IMAGE TXT POSTS DETECTED #########", "\n"))
    
    return(NULL)
  }
}