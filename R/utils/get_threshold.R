# =============================================================================
# Dynamic Engagement Threshold Calculation
# =============================================================================
#
# Description:
#   Calculates adaptive minimum interaction thresholds based on recent
#   activity levels in the monitored accounts. This prevents the system
#   from either missing coordination during low-activity periods or being
#   overwhelmed during high-activity periods.
#
# Algorithm:
#   1. Sample posts from the last 6 hours at 15-minute intervals
#   2. For each interval, query posts from seed lists and discovered accounts
#   3. Calculate mean total interactions (filtering for IQR)
#   4. Return average across all intervals as the threshold
#
# Configuration:
#   The `lists_path` variable should be set before calling get_threshold().
#   This is typically done in the main pipeline script.
#
# =============================================================================

#' Calculate Dynamic Engagement Threshold
#'
#' Computes an adaptive minimum interaction threshold based on recent
#' activity levels. The threshold ensures the monitoring system remains
#' calibrated to current engagement patterns.
#'
#' @param string_lids Comma-separated CrowdTangle list IDs to analyze
#'
#' @return Numeric value representing the recommended minimum interactions
#'   threshold. Returns 100 as fallback if API calls fail.
#'
#' @details
#' The function samples posts at 15-minute intervals over the past 6 hours.
#' For each sample, it:
#' 1. Queries posts from the specified CrowdTangle lists
#' 2. Queries posts from previously discovered coordinated accounts
#' 3. Calculates total interactions (sum of all reaction types)
#' 4. Filters to the interquartile range (25th-75th percentile)
#' 5. Computes mean interactions for that interval
#'
#' The final threshold is the average of all interval means, providing a
#' robust estimate that smooths out short-term fluctuations.
#'
#' @import dplyr
#' @import lubridate
#' @import httr
#' @import jsonlite
#' @import tidytable
#'
#' @examples
#' \dontrun{
#' threshold <- get_threshold("1760793,1760792")
#' # Returns something like 42.5
#' }

# -----------------------------------------------------------------------------
# Helper Function: Query CrowdTangle API with Retry Logic
# -----------------------------------------------------------------------------
query_api <- function(endDate, additional_params) {
  query.string <- paste0("https://api.crowdtangle.com/posts/search?",
                         "endDate=", endDate,
                         "&count=100",
                         additional_params,
                         "&token=", Sys.getenv("CROWDTANGLE_API_KEY"))
  
  # Initialize variables
  max_retries <- 3
  attempt <- 1
  
  while (attempt <= max_retries) {
    tryCatch({
      resp <- RETRY(verb = "GET", url = query.string, pause_base = 3, pause_min = 3)
      if (resp$status_code == 429) {
        Sys.sleep(15)  # Longer sleep if rate limit exceeded
        next
      }
      response.json <- content(resp, as = "text", type = "application/json", encoding = "UTF-8")
      parsed <- jsonlite::fromJSON(response.json, flatten = TRUE)
      return(parsed$result$posts)
    },
    error = function(e) {
      log_message(paste0("Error in API call. Attempt ", attempt, " of ", max_retries, ". Error message: ", e$message))
      attempt <- attempt + 1
      if (attempt > max_retries) {
        log_message("Max retries reached. Returning NULL.")
        return(NULL)  # Or return a default value
      }
      Sys.sleep(5)  # Delay before retrying
    })
  }
}

library(dplyr)
library(lubridate)
library(httr)
library(jsonlite)
library(tidytable)

get_threshold <- function(string_lids = "1770592,1770593") {
  qh <- seq(from = 900, to = 21600, by = 900) # intervals of 15 minutes
  
  expected_v <- vector("numeric", length(qh))
  
  pb <- txtProgressBar(min = 0, max = length(qh), style = 3)
  
  for (j in seq_along(qh)) {
    setTxtProgressBar(pb, j)
    
    endDate <- format_ISO8601(now() - qh[j])
    list_param <- paste0("&inListIds=", string_lids, "&sortBy=date")
    
    lposts <- query_api(endDate, list_param)
    
    # Check if the result of query_api is NULL and return 100L immediately
    if (is.null(lposts)) {
      log_message("query_api returned NULL. Returning 100L as a default value.")
      return(100L)
    }
    
    Sys.sleep(3.5)
    
    # Load discovered accounts list (path set in main pipeline configuration)
    idstoadd <- readRDS(file.path(lists_path, "idstoadd.rds"))
    newaccounts <- idstoadd %>% 
      group_by(platformId) %>%
      summarise(freq = n(), date = as.Date(min(date))) %>%
      filter(freq >= quantile(freq, 0.9) & date >= today("GMT") - 60) %>%
      arrange(-freq)
    
    if (nrow(newaccounts) > 450) {
      newaccounts <- head(newaccounts, 400)
    }
    
    newaccounts <- paste0(unique(newaccounts$platformId), collapse = ",")
    account_param <- paste0("&accounts=", newaccounts, "&sortBy=date")
    
    aposts <- query_api(endDate, account_param)
    
    # Check if the result of query_api is NULL and return 100L immediately
    if (is.null(aposts)) {
      log_message("query_api returned NULL. Returning 100L as a default value.")
      return(100L)
    }
    
    oposts <- bind_rows(lposts, aposts)
    
    if (length(oposts) > 0) {
      oposts <- oposts %>% 
        mutate(total_interactions = rowSums(across(c(statistics.actual.likeCount,
                                                     statistics.actual.shareCount,
                                                     statistics.actual.commentCount,
                                                     statistics.actual.loveCount,
                                                     statistics.actual.wowCount,
                                                     statistics.actual.hahaCount,
                                                     statistics.actual.sadCount,
                                                     statistics.actual.angryCount,
                                                     statistics.actual.thankfulCount,
                                                     statistics.actual.careCount)))) %>%
        filter(total_interactions <= quantile(total_interactions, 0.75) & total_interactions >= quantile(total_interactions, 0.25))
      
      expected_v[j] <- ifelse(mean(oposts$total_interactions, na.rm = TRUE) < 1, 1, mean(oposts$total_interactions, na.rm = TRUE))
    }
    Sys.sleep(3)
  }
  close(pb)
  return(mean(expected_v, na.rm = TRUE))
}

