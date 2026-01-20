# =============================================================================
# VERA-AI Coordinated Behavior Monitoring Pipeline
# =============================================================================
#
# Description:
#   Main orchestration script for the VERA-AI quasi-real-time monitoring system.
#   Detects coordinated inauthentic behavior on Facebook by identifying accounts
#   that share links, messages, or image-text content in suspiciously similar
#   patterns within short time windows.
#
# Workflow Steps:
#   1. Load configuration and authenticate with external services
#   2. Retrieve overperforming posts from seed accounts (CrowdTangle lists)
#   3. Retrieve posts from previously discovered coordinated accounts
#   4. Generate Slack alerts for top shared/commented posts
#   5. Detect Coordinated Link Sharing Behavior (CLSB) using CooRnet
#   6. Detect Coordinated Message Sharing Behavior (CMSB)
#   7. Detect Coordinated Image-Text Sharing Behavior (CITSB)
#   8. Update monitoring pool with newly discovered coordinated accounts
#   9. Log results and clean up
#
# Dependencies:
#   - CrowdTangle API access (deprecated Aug 2024; use Meta Content Library)
#   - Google Sheets API (for alert logging)
#   - Slack API (for real-time notifications)
#   - OpenAI API (for network labeling via GPT-4)
#   - CooRnet R package (for CLSB detection)
#
# Configuration:
#   Set parameters in the "CONFIGURATION" section below or use config/config.R
#
# Usage:
#   source("R/main_pipeline.R")
#
# Related Documentation:
#   - docs/WORKFLOW.md: Conceptual explanation of the monitoring process
#   - docs/IMPLEMENTATION.md: Technical architecture details
#   - docs/ALERTS.md: Alert interpretation guide
#
# =============================================================================

# -----------------------------------------------------------------------------
# LOAD REQUIRED LIBRARIES
# -----------------------------------------------------------------------------

required_libraries <- c(
  "httr",           # HTTP requests to APIs
  "slackr",         # Slack notifications
  "googlesheets4",  # Google Sheets logging
  "tidytable",      # Fast data manipulation
  "dplyr",          # Data wrangling
  "urltools",       # URL parsing and encoding
  "lubridate",      # Date/time handling
  "CooRnet",        # Coordinated Link Sharing detection
  "googledrive",    # Google Drive for chart uploads
  "igraph",         # Network analysis
  "quanteda",       # Text analysis for CMSB
  "stringr",        # String manipulation
  "digest"          # Hash generation for alert IDs
)

invisible(lapply(required_libraries, library, character.only = TRUE))

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

#' Query CrowdTangle API
#'
#' Generic wrapper for CrowdTangle API calls with automatic retry logic.
#'
#' @param query_string Full API URL including parameters and token
#' @return Parsed JSON response as a list
query_ct_api <- function(query_string) {
  response <- httr::RETRY(verb = "GET", url = query_string)
  response_json <- httr::content(response, as = "text", type = "application/json", encoding = "UTF-8")
  jsonlite::fromJSON(response_json, flatten = TRUE)
}

#' Log Message with Timestamp
#'
#' Prints a timestamped message to the console for monitoring script progress.
#'
#' @param msg Message text to log
log_message <- function(msg) {
  message(paste0("\n", msg, "\t", Sys.time(), "\n"))
}

# -----------------------------------------------------------------------------
# LOAD MODULE SCRIPTS
# -----------------------------------------------------------------------------
# Note: Update these paths if you move the scripts to a different location

# Get the directory where this script is located
script_dir <- dirname(sys.frame(1)$ofile)
if (is.null(script_dir) || script_dir == "") {
  script_dir <- "R"  # Default fallback for interactive use
}

source(file.path(script_dir, "api", "crowdtangle_query.R"))
source(file.path(script_dir, "utils", "clean_urls.R"))
source(file.path(script_dir, "utils", "get_threshold.R"))
source(file.path(script_dir, "coordination_detection", "detect_CMSB.R"))
source(file.path(script_dir, "coordination_detection", "detect_CITSB.R"))
source(file.path(script_dir, "api", "gpt4_labeling.R"))

# =============================================================================
# CONFIGURATION
# =============================================================================
# Adjust these parameters for your specific monitoring setup.
# For sensitive credentials, use environment variables (see config/config_template.R)

log_message("######### SCRIPT STARTED, NOW COMPUTING PARAMETERS... #########")

# --- Run Mode ---
dry_run <- FALSE  # Set TRUE to skip writes to Slack/GSheets (for testing)

# --- API Query Parameters ---
posts_per_query <- 100                    # Number of posts to retrieve per API call
monitoring_window <- "6 HOUR"             # Time window for post retrieval
crowdtangle_list_ids <- "1760793,1760792,1797494,1797495,1770592,1770593,1818792,1818793"
# CrowdTangle list IDs to monitor:
#   - EU vs Disinfo pages/groups
#   - DMI Winter School 2023 pages/groups
#   - CLSB_2023 pages/groups
#   - Portal Kombat network (added 16/02/2024)

# --- Dynamic Threshold Calculation ---
# Calculate minimum interactions threshold based on recent activity
# In dry_run mode, use a fixed threshold for faster testing
if (dry_run) {
  min_interactions_threshold <- 100L
} else {
  min_interactions_threshold <- round(get_threshold(crowdtangle_list_ids = crowdtangle_list_ids), 0) * 10
}

# --- Coordination Detection Parameters ---
coordination_interval <- "60 secs"        # Max time between posts to be considered coordinated
percentile_edge_weight <- 0.95            # Edge weight threshold (higher = stricter filtering)
chart_generation_threshold <- 50L         # Min coordinated shares to trigger chart upload

# --- Google Drive Integration ---
chart_upload_folder_id <- "1P3oGswmN7Hn24Sno0ABlrb45ykmUqVfP"  # GDrive folder for charts

# --- Evaluation Form ---
# Base URL for analyst evaluation form (pre-filled with alert data)
evaluation_form_base_url <- "https://docs.google.com/forms/d/e/1FAIpQLSeTOg5Elql70s4Iv3DSGmQxtLQA0eIrUsEpH1ygxqgkOfi4Lg/viewform?usp=pp_url&entry.513958351="

# --- Data Storage Paths ---
# Update these paths to match your local setup
data_base_path <- file.path(dirname(script_dir), "data")
lists_path <- file.path(data_base_path, "lists")

# --- Editorial Network Filter ---
# Some legitimate editorial networks may trigger coordination detection due to
# their cross-posting practices. Set to TRUE to include them, FALSE to filter out.
include_editorial_networks <- FALSE

# Account IDs for known editorial networks (UOL Brazil, CNN Prima CZ, etc.)
editorial_account_ids <- c(
  "303794233506",
  "2214398435317853",
  "1401409376737982",
  "1876655635924328",
  "53837363556",
  "1028207833910620",
  "103431853058644",
  "196979153651895",
  "125477330801477",
  "100084212586033",
  "400332483415594",
  "103226781082918",
  "128961073840396",
  "144301939056471",
  "97718196244",
  "596632770532911",
  "750140313058241",
  "838338540071832",
  "131915778646395",
  "224125974343626",
  "1260468564040808",
  "124493634232128",
  "21539158238",
  "143813098922",
  "123014924007",
  "120098554660",
  "115401215190141",
  "100064939351944",
  "100064376721819",
  "100064986720056",
  "100063588593171",
  "100064522518963",
  "100064506977451",
  "100064406753229",
  "100057369283601",
  "100064557526836",
  "100063724353221",
  "100063471495808"
)

# =============================================================================
# GOOGLE AUTHENTICATION
# =============================================================================

googlesheets4::gs4_deauth()
googlesheets4::gs4_auth(path = Sys.getenv("SERVICE_ACCOUNT"))

googledrive::drive_deauth()
googledrive::drive_auth(path = Sys.getenv("SERVICE_ACCOUNT"))

s_url <- "https://docs.google.com/spreadsheets/d/12JnAwcPw7jLLcECXCFb1ZmojFqRGmq1TOojbE7gIIRI/edit#gid=0"

# Retry mechanism
retry_count <- 0
ssid <- NULL

while(is.null(ssid) && retry_count < 3) {
  retry_count <- retry_count + 1
  tryCatch({
    ssid <- as_sheets_id(s_url)
  }, error = function(e) {
    cat(sprintf("Attempt %d failed: %s\n", retry_count, e$message))
    if (retry_count == max_retries) {
      cat("Max retry attempts reached, exiting...\n")
    }
  })
}

# =============================================================================
# STEP 1: RETRIEVE POSTS FROM SEED ACCOUNTS
# =============================================================================
# Query CrowdTangle for overperforming posts from monitored lists

log_message(paste0("######### Using min_interactions_threshold=", min_interactions_threshold, ", NOW GETTING POSTS #########"))

query_string <- paste0("https://api.crowdtangle.com/posts/search?",
                       "count=", posts_per_query,
                       "&minInteractions=", min_interactions_threshold,
                       "&inListIds=", crowdtangle_list_ids,
                       "&sortBy=overperforming",
                       "&monitoring_window=", url_encode(monitoring_window),
                       "&token=", Sys.getenv("CROWDTANGLE_API_KEY"))

parsed <- query_ct_api(query_string)
lposts <- parsed$result$posts

if (include_editorial_networks == FALSE) {
  lposts <- lposts %>%
    filter(!account.platformId %in% editorial_account_ids)
}

if (length(lposts) != 0) {
  lposts <- lposts %>%
    dplyr::mutate(comment.shares.ratio=(statistics.actual.commentCount-statistics.actual.shareCount)/(statistics.actual.commentCount+statistics.actual.shareCount)) %>%
    dplyr::mutate(combined.metric = score*comment.shares.ratio)
}


rm(parsed, query_string)

# =============================================================================
# STEP 2: RETRIEVE POSTS FROM DISCOVERED ACCOUNTS
# =============================================================================
# Query posts from accounts previously identified as coordinated
# These accounts were added to the monitoring pool in previous cycles

max_query_lengthgth <- 2000  # Maximum URL length for API queries

idstoadd <- readRDS(file.path(lists_path, "idstoadd.rds"))

# Balance novelty and times spotted for additional coordinated accounts - UPDATE 02/03 
newaccounts <- idstoadd %>%
  group_by(platformId) %>%
  summarise(freq = n(), date = as.Date(min(date))) %>%
  filter(freq >= quantile(freq, probs = 0.9)) %>%
  ungroup() %>%
  mutate(
    # Calculate days since first spotted as a measure of recency
    days_since_spotted = as.numeric(difftime(today("GMT"), date, units = "days")),
    # Normalize frequency (0 to 1 scale)
    freq_norm = (freq - min(freq)) / (max(freq) - min(freq)),
    # Normalize days_since_spotted (inverse logic: more recent should have higher score)
    recency_norm = (max(days_since_spotted) - days_since_spotted) / (max(days_since_spotted) - min(days_since_spotted)),
    # Calculate final score (considering equal weight for simplicity)
    final_score = 0.5 * freq_norm + 0.5 * recency_norm
  ) %>%
  # Apply filter based on freq being above or equal to the median_freq
  filter(include_editorial_networks | !platformId %in% editorial_account_ids) %>%
  arrange(desc(final_score))

newaccounts_str <- paste0(unique(newaccounts$platformId), collapse=",")

query.string <- paste0("https://api.crowdtangle.com/posts/search?",
                       "count=", posts_per_query,
                       "&minInteractions=", min_interactions_threshold,
                       "&accounts=", newaccounts_str,
                       "&sortBy=overperforming",
                       "&monitoring_window=", url_encode(monitoring_window),
                       "&token=", Sys.getenv("CROWDTANGLE_API_KEY"))

# Check if the query string exceeds the max limit
if (nchar(query.string) > max_query_length) {
  # Placeholder for the accounts
  query.string.placeholder <- "https://api.crowdtangle.com/posts/search?"
  query.string.placeholder <- paste0(query.string.placeholder,
                                     "count=", posts_per_query,
                                     "&minInteractions=", min_interactions_threshold,
                                     "&accounts=",
                                     "&sortBy=overperforming",
                                     "&monitoring_window=", url_encode(monitoring_window),
                                     "&token=", Sys.getenv("CROWDTANGLE_API_KEY"))
  
  # Remaining length for accounts
  remaining_len <- max_query_length - nchar(query.string.placeholder)
  
  # Calculate how many accounts fit into the remaining length
  newaccounts$platformId_len <- nchar(newaccounts$platformId)
  newaccounts_cumsum <- cumsum(newaccounts$platformId_len + 1)  # +1 for the comma
  newaccounts <- newaccounts[newaccounts_cumsum <= remaining_len, ]
  
  # Reconstruct the full query string
  newaccounts_str <- paste0(unique(newaccounts$platformId), collapse=",")
  query.string <- gsub("&accounts=", paste0("&accounts=", newaccounts_str), query.string.placeholder)
}

# Rest of the code remains the same
parsed <- query_ct_api(query.string)

if (length(parsed$result$posts) > 0) {
  aposts <- parsed$result$posts
  aposts <- aposts %>%
    dplyr::mutate(comment.shares.ratio = (statistics.actual.commentCount-statistics.actual.shareCount)/(statistics.actual.commentCount+statistics.actual.shareCount)) %>%
    dplyr::mutate(combined.metric = score*comment.shares.ratio)
  
  oposts <- tidytable::bind_rows(lposts, aposts)
  
  rm(lposts, aposts)
  
} else {
  oposts <- lposts
  rm(lposts)
}

if (length(oposts) == 0) {
  stop("### Not enought posts! ###")
}

rm(parsed, query.string)

# =============================================================================
# STEP 3: GENERATE POST ALERTS
# =============================================================================
# Send Slack notifications for top shared and most commented overperforming posts

log_message(paste0("######### WORKING ON ", nrow(oposts), " POSTS, NOW SENDING SLACK ALERTS #########"))

# Function to get emoji based on redalert score
get_emoji <- function(redalert_score) {
  if (is.na(redalert_score) || !is.numeric(redalert_score)) {
    return("")  # or you might want to handle this differently
  }
  
  if (redalert_score == 1) {
    return(" 🚩️")
  } else if (redalert_score == 2) {
    return(" 🚩🚩")
  } else if (redalert_score >= 3) {
    return(" 🚩🚩🚩")
  } else {
    return("")
  }
}

oposts <- dplyr::arrange(oposts, combined.metric)

# Create the posts unique id hash
oposts$alertId <- sapply(with(oposts, paste(postUrl, date, account.name, sep = "|")), function(x) digest(x, algo = "sha256"))

keep <- c("postUrl",
          "date",
          "account.name",
          "statistics.actual.likeCount",
          "statistics.actual.shareCount",
          "statistics.actual.commentCount",
          "statistics.actual.loveCount",
          "statistics.actual.wowCount",
          "statistics.actual.hahaCount",
          "statistics.actual.sadCount",
          "statistics.actual.angryCount",
          "statistics.actual.thankfulCount",
          "statistics.actual.careCount",
          "score",
          "comment.shares.ratio",
          "combined.metric",
          "alertId")

unique_oposts <- unique(subset(oposts, select = keep))

# Calculate total engagement for each post
unique_oposts$total_engagement <- rowSums(unique_oposts[,c("statistics.actual.likeCount",
                                                           "statistics.actual.shareCount",
                                                           "statistics.actual.commentCount",
                                                           "statistics.actual.loveCount",
                                                           "statistics.actual.wowCount",
                                                           "statistics.actual.hahaCount",
                                                           "statistics.actual.sadCount",
                                                           "statistics.actual.angryCount",
                                                           "statistics.actual.thankfulCount",
                                                           "statistics.actual.careCount")])

# Initialize redalert with 0
unique_oposts$cp_redalert <- 0
unique_oposts$sp_redalert <- 0

# Fetch shared and commented posts stats
commented_posts_stats <- googlesheets4::read_sheet(ss = ssid, sheet = "commented_posts_Summary_Stats")
shared_posts_stats <- googlesheets4::read_sheet(ss = ssid, sheet = "shared_posts_Summary_Stats")

# Calculate dynamic thresholds for commented posts
commented_posts_total_engagement_upper_threshold <- commented_posts_stats$total_engagement_median[1] + 1.5 * commented_posts_stats$total_engagement_iqr[1]
commented_posts_total_engagement_lower_threshold <- commented_posts_stats$total_engagement_median[1] - 1.5 * commented_posts_stats$total_engagement_iqr[1]
commented_posts_score_upper_threshold <- commented_posts_stats$score_median[1] + 1.5 * commented_posts_stats$score_iqr[1]
commented_posts_score_lower_threshold <- commented_posts_stats$score_median[1] - 1.5 * commented_posts_stats$score_iqr[1]
commented_posts_combined_metric_upper_threshold <- commented_posts_stats$combined_metric_median[1] + 1.5 * commented_posts_stats$combined_metric_iqr[1]
commented_posts_combined_metric_lower_threshold <- commented_posts_stats$combined_metric_median[1] - 1.5 * commented_posts_stats$combined_metric_iqr[1]

# Calculate dynamic thresholds for shared posts
shared_posts_total_engagement_upper_threshold <- shared_posts_stats$total_engagement_median[1] + 1.5 * shared_posts_stats$total_engagement_iqr[1]
shared_posts_total_engagement_lower_threshold <- shared_posts_stats$total_engagement_median[1] - 1.5 * shared_posts_stats$total_engagement_iqr[1]
shared_posts_score_upper_threshold <- shared_posts_stats$score_median[1] + 1.5 * shared_posts_stats$score_iqr[1]
shared_posts_score_lower_threshold <- shared_posts_stats$score_median[1] - 1.5 * shared_posts_stats$score_iqr[1]
shared_posts_combined_metric_upper_threshold <- shared_posts_stats$combined_metric_median[1] + 1.5 * shared_posts_stats$combined_metric_iqr[1]
shared_posts_combined_metric_lower_threshold <- shared_posts_stats$combined_metric_median[1] - 1.5 * shared_posts_stats$combined_metric_iqr[1]

# Update cp_redalert for commented posts based on thresholds
unique_oposts$cp_redalert <- rowSums(cbind(
  unique_oposts$total_engagement >= commented_posts_total_engagement_upper_threshold | unique_oposts$total_engagement <= commented_posts_total_engagement_lower_threshold,
  unique_oposts$score >= commented_posts_score_upper_threshold | unique_oposts$score <= commented_posts_score_lower_threshold,
  unique_oposts$combined.metric >= commented_posts_combined_metric_upper_threshold | unique_oposts$combined.metric <= commented_posts_combined_metric_lower_threshold
))

# Update sp_redalert for shared posts based on thresholds
unique_oposts$sp_redalert <- rowSums(cbind(
  unique_oposts$total_engagement >= shared_posts_total_engagement_upper_threshold | unique_oposts$total_engagement <= shared_posts_total_engagement_lower_threshold,
  unique_oposts$score >= shared_posts_score_upper_threshold | unique_oposts$score <= shared_posts_score_lower_threshold,
  unique_oposts$combined.metric >= shared_posts_combined_metric_upper_threshold | unique_oposts$combined.metric <= shared_posts_combined_metric_lower_threshold
))

# update Gsheet and post on Slack
if (!dry_run & nrow(unique_oposts) >= 3) {
  
  # Constructing the message for shared posts
  text_s <- paste0("The top 3 most shared over-performing posts during the last ", monitoring_window, "S are:")
  for (j in 1:3) {
    emoji <- get_emoji(unique_oposts$sp_redalert[j])
    text_s <- paste0(text_s, "\n", j, ". ", unique_oposts$postUrl[j], " (", unique_oposts$account.name[j], ")", emoji)
    # evaluation
    text_s <- paste0(text_s, " - <", evaluation_form_base_url, unique_oposts$alertId[j], "&entry.1457886713=", unique_oposts$postUrl[j], "|Evaluation form>") # add link to the form
  }
  
  # Constructing the message for commented posts
  text_c <- paste0("The top 3 most commented over-performing posts during the last ", monitoring_window, "S are:")
  counter <- 1
  for (j in (nrow(unique_oposts)-2):nrow(unique_oposts)) {
    emoji <- get_emoji(unique_oposts$cp_redalert[j])
    text_c <- paste0(text_c, "\n", counter, ". ", unique_oposts$postUrl[j], " (", unique_oposts$account.name[j], ")", emoji)
    text_c <- paste0(text_c, " - <", evaluation_form_base_url, unique_oposts$alertId[j], "&entry.1457886713=", unique_oposts$postUrl[j], "|Evaluation form>") # add link to the form
    counter <- counter + 1
  }
  
  rm(counter)
  
  # post a message on slack VERAAI_ALERTS channel for shared posts
  slackr::slackr_msg(txt = text_s,
                     channel = "C0602J391JM",
                     username = "VERAAI_ALERT",
                     token = Sys.getenv("SLACK_TOKEN_MINE"))
  
  # post a message on slack VERAAI_ALERTS channel for commented posts
  slackr::slackr_msg(txt = text_c,
                     channel = "C0602J391JM",
                     username = "VERAAI_ALERT",
                     token = Sys.getenv("SLACK_TOKEN_MINE"))
  
  # #### LARICA TEST ###
  # 
  # 
  # # post a message on slack VERAAI_ALERTS channel for shared posts
  # slackr::slackr_msg(txt = text_s,
  #                    channel = "C06FZJL4NHK",
  #                    username = "VERAAI_ALERT",
  #                    token = Sys.getenv("SLACK_TOKEN_LARICA"))
  # 
  # # post a message on slack VERAAI_ALERTS channel for commented posts
  # slackr::slackr_msg(txt = text_c,
  #                    channel = "C06FZJL4NHK",
  #                    username = "VERAAI_ALERT",
  #                    token = Sys.getenv("SLACK_TOKEN_LARICA"))
  # 
  # #### LARICA TEST ###
  # 
  #### VERA_AI SLACK TEST ###


  # post a message on slack VERAAI_ALERTS channel for shared posts
  slackr::slackr_msg(txt = text_s,
                     channel = "C06GFADLWV7",
                     username = "VERAAI_ALERT",
                     token = Sys.getenv("SLACK_TOKEN_VERA"))

  # post a message on slack VERAAI_ALERTS channel for commented posts
  slackr::slackr_msg(txt = text_c,
                     channel = "C06GFADLWV7",
                     username = "VERAAI_ALERT",
                     token = Sys.getenv("SLACK_TOKEN_VERA"))

  #### VERA_AI SLACK TEST ###
  
  # gsheet
  
  towrite <- subset(unique_oposts, select = keep)
  towrite <- unique(towrite)
  
  # update a google sheet with top 3
  s_posts <- head(towrite, 3)
  s_posts$alert_date <- lubridate::with_tz(Sys.time(), "CET")
  
  c_posts <- tail(towrite, 3)
  c_posts$alert_date <- lubridate::with_tz(Sys.time(), "CET")
  
  sheet_append(ssid, data = s_posts, sheet = "shared_posts")
  sheet_append(ssid, data = c_posts, sheet = "commented_posts")
  
  # cleanup
  rm(towrite, c_posts, s_posts, commented_posts_stats, shared_posts_stats)
}

rm(keep, unique_oposts)

# =============================================================================
# STEP 4: COORDINATED LINK SHARING BEHAVIOR (CLSB) DETECTION
# =============================================================================
# Use CooRnet package to identify accounts sharing the same URLs in coordination

# extract links that appear at least twice in the top performing 100
posts <- tidytable::unnest(oposts, expandedLinks, .drop = FALSE)
# remove duplicates created by the un-nesting
posts <- posts[!duplicated(posts[,c("id", "platformId", "postUrl", "expanded")]),]
posts <- clean_urls(posts, "expanded")

urls <- as.data.frame(table(posts$expanded))

if (nrow(urls) > 0) {
  names(urls) <- c("url", "freq")
  
  urls$scheme <- scheme(urls$url)
  urls$domain <- urltools::domain(urls$url)
  
  i <- which(!(urls$url==paste0(urls$scheme, "://", urls$domain))) # keep only well formed domains
  urls <- urls[i, ]
  i <- which(!(urls$url==paste0(urls$scheme, "://", urls$domain, "/")))
  urls <- urls[i, ]
  rm(i)
  
  urls <- subset(posts, posts$expanded %in% urls$url)
  
  urls <- urls %>%
    dplyr::group_by(expanded) %>%
    dplyr::summarise(date = min(date)) %>%
    dplyr::select(url=expanded, date)
  
  ##############################################
  # LOG UPDATE
  ##############################################
  
  log_message(paste0 ("\n", "######### RUNNING COORNET ON ", nrow(urls), " URLS #########"))
  
  ct_shares.df <- NULL
  datalist <- list()
  
  # query the CrowdTangle API
  for (i in 1:nrow(urls)) {
    
    url_ct_shares.df <- NULL
    url_datalist <- list()
    
    # set date limits: one week after date_published
    startDate <- as.POSIXct(urls$date[i], origin="1970-01-01", tz = "UTC")
    endDate <- startDate+604800
    
    link <- urls$url[i]
    
    # build the querystring
    query.string <- paste0("https://api.crowdtangle.com/links?",
                           "link=", urltools::url_encode(url=link),
                           "&platforms=facebook,instagram",
                           "&startDate=", gsub(" ", "T", as.character(startDate)),
                           "&endDate=", gsub(" ", "T", as.character(endDate)),
                           "&includeSummary=FALSE",
                           "&includeHistory=TRUE",
                           "&sortBy=date",
                           "&searchField=TEXT_FIELDS_AND_IMAGE_TEXT",
                           "&token=", Sys.getenv("CROWDTANGLE_API_KEY"),
                           "&count=1000")
    
    c <- query_link_endpoint(query.string, 0.5)
    
    if (any(!is.na(c))) { # check if the call failed returning NA
      
      if (length(c$result$posts) != 0) {
        
        url_datalist <- c(list(c$result$posts), url_datalist)
        
        # paginate
        counter <- 1L
        while (counter <= 10 & !is.null(c$result$pagination$nextPage)) # stop after 10 iterations
        {
          c <- query_link_endpoint(c$result$pagination$nextPage, 0.5)
          counter <- sum(counter, 1)
          
          if (any(!is.na(c))) {
            url_datalist <- c(list(c$result$posts), url_datalist)
          }
          else break}
      }
      
      if (length(url_datalist) != 0) {
        url_ct_shares.df <- tidytable::bind_rows(url_datalist)
      }
      else {
        url_ct_shares.df <- NULL
      }
      
      if (!is.null(url_ct_shares.df)) {
        # keep only fields actually used by CooRnet
        url_ct_shares.df <- url_ct_shares.df %>%
          dplyr::select_if(names(.) %in% c("platformId",
                                           "platform",
                                           "date",
                                           "type",
                                           "expandedLinks",
                                           "description",
                                           "postUrl",
                                           "history",
                                           "id",
                                           "message",
                                           "title",
                                           "statistics.actual.likeCount",
                                           "statistics.actual.shareCount",
                                           "statistics.actual.commentCount",
                                           "statistics.actual.loveCount",
                                           "statistics.actual.wowCount",
                                           "statistics.actual.hahaCount",
                                           "statistics.actual.sadCount",
                                           "statistics.actual.angryCount",
                                           "statistics.actual.thankfulCount",
                                           "statistics.actual.careCount",
                                           "account.id",
                                           "account.name",
                                           "account.handle",
                                           "account.subscriberCount",
                                           "account.url",
                                           "account.platform",
                                           "account.platformId",
                                           "account.accountType",
                                           "account.pageCategory",
                                           "account.pageAdminTopCountry",
                                           "account.pageDescription",
                                           "account.pageCreatedDate",
                                           "account.verified"))
        
        datalist <- c(list(url_ct_shares.df), datalist)
        
      }
      rm(url_ct_shares.df, url_datalist, c)
    }
  }
  
  if (!is.null(datalist)) {
    ct_shares.df <- tidytable::bind_rows(datalist)
    rm(datalist)
    
    # remove possible inconsistent rows with entity URL equal "https://facebook.com/null"
    ct_shares.df <- ct_shares.df[ct_shares.df$account.url!="https://facebook.com/null",]
    
    ct_shares.df <- tidytable::unnest(ct_shares.df, expandedLinks, .drop = FALSE)
    ct_shares.df$original <- NULL
    
    # remove duplicates created by the unnesting
    ct_shares.df <- ct_shares.df[!duplicated(ct_shares.df[,c("id", "platformId", "postUrl", "expanded")]),]
    
    ct_shares.df$is_orig <- ct_shares.df$expanded %in% urls$url
    
    if (length(ct_shares.df$is_orig[ct_shares.df$is_orig==TRUE]) > 0) {
      
      output <- tryCatch(
        {
          CooRnet::get_coord_shares(ct_shares.df = ct_shares.df, percentile_edge_weight = percentile_edge_weight, coordination_interval = coordination_interval, keep_ourl_only = TRUE)
        },
        error=function(cond) {
          message(cond)
          # Choose a return value in case of error
          return(NA)
        })
      
      ##############################################
      # Get new coordinated accounts and links
      ##############################################
      
      if(sum(!is.na(output))>0) {
        
        newids <- paste(trimws(basename(output[[3]]$name)),collapse=",")
        
        top10 <- CooRnet::get_top_coord_urls(output = output, group_by = "none", top = 10)
        top10 <- arrange(top10, comments.shares.ratio)
        
        # Fetch labels from GPT-4 for the top 10 coordinated links
        top10 <- get_gpt4_labels(df=top10, model = "gpt-4")  # Get the network labels via OpenAI
        
        # Fetch link stats
        link_stats <- googlesheets4::read_sheet(ss = ssid, sheet = "links_Summary_Stats")
        
        # Calculate thresholds for total engagement
        link_total_engagement_upper_threshold <- link_stats$total_engagement_median[1] + 1.5 * link_stats$total_engagement_iqr[1]
        link_total_engagement_lower_threshold <- link_stats$total_engagement_median[1] - 1.5 * link_stats$total_engagement_iqr[1]
        
        # Calculate dynamic thresholds for comments_shares_ratio, ensuring they don't exceed -1 to 1 range
        link_comment_shares_ratio_upper_threshold <- min(1, link_stats$comment_shares_ratio_median[1] + 1.5 * link_stats$comment_shares_ratio_iqr[1])
        link_comment_shares_ratio_lower_threshold <- max(-1, link_stats$comment_shares_ratio_median[1] - 1.5 * link_stats$comment_shares_ratio_iqr[1])
        
        # Add a red_alert variable to top 10 and initialize it to 0
        top10$redalert <- 0
        
        # Increment red_alert for outliers
        top10 <- top10 %>%
          mutate(
            redalert = redalert + ifelse(engagement >= link_total_engagement_upper_threshold | engagement <= link_total_engagement_lower_threshold, 1, 0),
            redalert = redalert + ifelse(comments.shares.ratio >= link_comment_shares_ratio_upper_threshold | comments.shares.ratio <= link_comment_shares_ratio_lower_threshold, 1, 0)
          )
        
        if (!dry_run & nrow(top10 >0)) {
          
          # add a unique id to the alerts
          top10$alertId <- sapply(with(top10, paste(expanded, cooR.account.url, sep = "|")), 
                                  function(x) digest(x, algo = "sha256"))
          
          # send a message to the slack channel and update the gsheet
          n <- nrow(top10)
          
          # slack
          mtext <- paste0("Top ", n, " mostly shared coordinated links of the last ", monitoring_window,"S are:")
          
          for (j in 1:n) {
            # Determine the emoji based on redalert status
            emoji <- get_emoji(top10$redalert[j])
            
            # set slack text with the emoji added before the related link
            mtext <- paste0(mtext, "\n", as.character(j), ". ", top10$expanded[j], " (", top10$label[j], ")", emoji)
            mtext <- paste0(mtext, " - <", evaluation_form_base_url, top10$alertId[j], "&entry.1457886713=", top10$expanded[j], "|Evaluation form>") # add link to the form
            
          }
          
          # post on slack
          slackr::slackr_msg(txt = mtext,
                             channel = "C0602J391JM",
                             username = "VERAAI_ALERT",
                             token = Sys.getenv("SLACK_TOKEN_MINE"))
          
          # post on slack
          slackr::slackr_msg(txt = mtext,
                             channel = "C06GFADLWV7",
                             username = "VERAAI_ALERT",
                             token = Sys.getenv("SLACK_TOKEN_VERA"))

          # gsheet
          top10$alert_date <- lubridate::with_tz(Sys.time(), "CET")
          sheet_append(ssid, data = top10, sheet = "links")
          
          # draw and upload plots of widely shared URLs
          top10 <- filter(top10, cooR.shares>=chart_generation_threshold)
          
          if (nrow(top10)>0) {
            for (y in 1:nrow(top10)) {
              p <- CooRnet::draw_url_timeline_chart(output = output, top_coord_urls = top10, top_url_id = y)
              saveRDS(p, "file.path(data_base_path, "autocharts", "p.rds")")
              drive_upload(media = "file.path(data_base_path, "autocharts", "p.rds")", path = as_id(chart_upload_folder_id), name = paste0(top10$expanded[y], "__", Sys.Date(), ".rds"))
              
              rm(p)
            }
            
            ##############################################
            # LOG UPDATE
            ##############################################
            
            message(paste0 ("\n", "######### SAVED ", nrow(top10), " INTERACTIVE CHARTS IN THE GDRIVE FOLDER #########"))
            
          }
          
          rm(n, j, top10, mtext, link_stats)
        } else message("dry_run=true or no top coordinated URLs!")
      }
    } else message("not enought shares of the orignal URLs!")
  } else message("not enought coordinated shares!")
  
  if (!dry_run) {
    rm(list=setdiff(ls(), c("log_message", "crowdtangle_list_ids", "newids", "dry_run", "polfilter", "oposts", "monitoring_window", "coordination_interval", "percentile_edge_weight", "detect_cmsb", "detect_citsb")))
  }
} else log_message("not enought URLs!")

# =============================================================================
# STEP 5: COORDINATED MESSAGE SHARING BEHAVIOR (CMSB) DETECTION
# =============================================================================
# Detect accounts sharing posts with highly similar text messages

log_message("######### DETECTING COORDINATED MESSAGE SHARING ACCOUNTS #########")

idstoadd_message <- detect_cmsb(oposts = oposts, monitoring_window = monitoring_window, coordination_interval = coordination_interval, percentile_edge_weight = percentile_edge_weight)

if (!is.null(idstoadd_message)) {
  idstoadd_message <- unlist(idstoadd_message)
}

# =============================================================================
# STEP 6: COORDINATED IMAGE-TEXT SHARING BEHAVIOR (CITSB) DETECTION
# =============================================================================
# Detect accounts sharing posts with identical OCR-extracted image text

log_message("######### DETECTING COORDINATED IMAGE-TEXT SHARING ACCOUNTS #########")

idstoadd_imgtxt <- detect_citsb(oposts = oposts, monitoring_window = monitoring_window, coordination_interval = coordination_interval, percentile_edge_weight = percentile_edge_weight)

if (!is.null(idstoadd_imgtxt)) {
  idstoadd_imgtxt <- unlist(idstoadd_imgtxt)
}

# =============================================================================
# STEP 7: UPDATE MONITORING POOL WITH NEW COORDINATED ACCOUNTS
# =============================================================================
# Add newly discovered coordinated accounts to the monitoring list for future cycles

# --- Helper code to retrieve account IDs from CrowdTangle lists ---
# (Uncomment if you need to rebuild the seed list)

# vector_lids <- unlist(strsplit(crowdtangle_list_ids,","))
# account_ids <- NULL
# 
# for (y in 1:length(vector_lids)) {
#   query.string <- paste0("https://api.crowdtangle.com/lists/", vector_lids[y] ,"/accounts?",
#                          "&count=100",
#                          "&token=", Sys.getenv("CROWDTANGLE_API_KEY_VERAAI"))
# 
#   resp <- httr::RETRY(verb = "GET", url = query.string)
#   response.json <- httr::content(resp, as = "text", type="application/json", encoding = "UTF-8")
#   parsed <- jsonlite::fromJSON(response.json, flatten = TRUE)
# 
#   if (any(!is.na(parsed))) { # check if the call failed returning NA
# 
#     if (length(parsed$result$accounts) != 0) {
# 
#       account_ids <- c(parsed$result$accounts$platformId, account_ids)
# 
#       while (!is.null(parsed$result$pagination$nextPage))
#       {
#         resp <- httr::RETRY(verb = "GET", url = parsed$result$pagination$nextPage)
#         response.json <- httr::content(resp, as = "text", type="application/json", encoding = "UTF-8")
#         parsed <- jsonlite::fromJSON(response.json, flatten = TRUE)
# 
#         if (any(!is.na(parsed))) {
#           account_ids <- c(parsed$result$accounts$platformId, account_ids)
#         }
#         else break}
#     }
#   }
# }
# 
# account_ids <- unique(account_ids)
# saveRDS(account_ids, "./lists/VERAAI-IDS.rds")

# Use the configured lists_path from the CONFIGURATION section

if (!dry_run & exists("newids")) {
  if (!is.null(newids) & length(newids) > 0) {
    newids <- as.vector(el(strsplit(newids,",")))
    account_ids <- readRDS(file.path(lists_path, "VERAAI-IDS.rds"))
    idstoadd <- as.data.frame(setdiff(newids, account_ids)) # get new ids not in our original list
  }
  
  if (nrow(idstoadd) > 0) {
    
    ##############################################
    # LOG UPDATE
    ##############################################
    
    log_message(paste0 ("\n", "######### DETECTED ", nrow(idstoadd), " NEW CLSB ACCOUNTS TO BE MONITORED #########"))
    
    names(idstoadd) <- c("platformId")
    idstoadd$date <- lubridate::with_tz(Sys.time(), "CET") # add now as the date-time the records were added
    
    saveRDS(idstoadd, file.path(lists_path, "latest_idstoadd.rds")) # save a list of new ids found
    all_idstoadd <- readRDS(file.path(lists_path, "idstoadd.rds")) # load the list of all new ids found
    all_idstoadd <- rbind(all_idstoadd, idstoadd) # bind the two dataframes
    saveRDS(all_idstoadd, file.path(lists_path, "idstoadd.rds")) # save an updated list of new ids found
  } else {
    log_message("no new coordinated accounts found!")
  }
}

# # add newly discovered CITSB coordinated accounts
# 
if (!dry_run & exists("idstoadd_imgtxt") & !is.null(idstoadd_imgtxt)) {
  if (!is.null(idstoadd_imgtxt) & length(idstoadd_imgtxt) > 0) {
    newids <- idstoadd_imgtxt
    account_ids <- readRDS(file.path(lists_path, "VERAAI-IDS.rds"))
    idstoadd <- as.data.frame(setdiff(newids, account_ids)) # get new ids not in our original list

    if (nrow(idstoadd) > 0) {

      ##############################################
      # LOG UPDATE
      ##############################################

      message(paste0 ("\n", "######### DETECTED ", nrow(idstoadd), " NEW CITSB ACCOUNTS TO BE MONITORED #########", "\n"))

      names(idstoadd) <- c("platformId")
      idstoadd$date <- lubridate::with_tz(Sys.time(), "CET") # add now as the date-time the records were added

      saveRDS(idstoadd, file.path(lists_path, "latest_idstoadd.rds")) # save a list of new ids found
      all_idstoadd <- readRDS(file.path(lists_path, "idstoadd.rds")) # load the list of all new ids found
      all_idstoadd <- rbind(all_idstoadd, idstoadd) # bind the two dataframes
      saveRDS(all_idstoadd, file.path(lists_path, "idstoadd.rds")) # save an updated list of new ids found
    } else { message("no new CITSB accounts found!") }
  }
} else { message("no new CITSB accounts found!") }

# add newly discovered CMSB coordinated accounts

if (!dry_run & exists("idstoadd_message") & !is.null(idstoadd_message)) {
  if (!is.null(idstoadd_message) & length(idstoadd_message) > 0) {
    newids <- idstoadd_message
    account_ids <- readRDS(file.path(lists_path, "VERAAI-IDS.rds"))
    idstoadd <- as.data.frame(setdiff(newids, account_ids)) # get new ids not in our original list
    
    if (nrow(idstoadd) > 0) {
      
      ##############################################
      # LOG UPDATE
      ##############################################
      
      log_message(paste0 ("\n", "######### DETECTED ", nrow(idstoadd), " NEW CMSB ACCOUNTS TO BE MONITORED #########", "\n"))
      
      names(idstoadd) <- c("platformId")
      idstoadd$date <- lubridate::with_tz(Sys.time(), "CET") # add now as the date-time the records were added
      
      saveRDS(idstoadd, file.path(lists_path, "latest_idstoadd.rds")) # save a list of new ids found
      all_idstoadd <- readRDS(file.path(lists_path, "idstoadd.rds")) # load the list of all new ids found
      all_idstoadd <- rbind(all_idstoadd, idstoadd) # bind the two dataframes
      saveRDS(all_idstoadd, file.path(lists_path, "idstoadd.rds")) # save an updated list of new ids found
    } else { log_message("no new CMSB accounts found!") }
  }
} else { log_message("no new CMSB accounts found!") }

rm(list=ls())
