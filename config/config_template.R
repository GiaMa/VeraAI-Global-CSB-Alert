# =============================================================================
# VERA-AI Monitoring System Configuration Template
# =============================================================================
#
# INSTRUCTIONS:
# 1. Copy this file to 'config.R' in the same directory
# 2. Replace all placeholder values with your actual credentials
# 3. NEVER commit config.R to version control (it's in .gitignore)
#
# =============================================================================

# -----------------------------------------------------------------------------
# API CREDENTIALS
# -----------------------------------------------------------------------------

# CrowdTangle API (deprecated August 2024 - use Meta Content Library for new projects)
Sys.setenv(CROWDTANGLE_API_KEY = "your_crowdtangle_api_key_here")

# OpenAI API (for GPT-4 network labeling)
Sys.setenv(OPENAI_API_KEY = "sk-your_openai_api_key_here")

# -----------------------------------------------------------------------------
# GOOGLE AUTHENTICATION
# -----------------------------------------------------------------------------

# Path to Google service account JSON file
# Used for Google Sheets logging and Google Drive chart uploads
Sys.setenv(SERVICE_ACCOUNT = "/path/to/your/service_account.json")

# Google Sheets URL for alert logging
# Create a new Google Sheet and share it with your service account email
GSHEET_URL <- "https://docs.google.com/spreadsheets/d/your_sheet_id_here/edit"

# Google Drive folder ID for chart uploads (optional)
GDRIVE_FOLDER_ID <- "your_drive_folder_id_here"

# -----------------------------------------------------------------------------
# SLACK INTEGRATION
# -----------------------------------------------------------------------------

# Slack bot tokens for notifications
# Create a Slack app at https://api.slack.com/apps
Sys.setenv(SLACK_TOKEN_MINE = "xoxb-your-personal-slack-bot-token")
Sys.setenv(SLACK_TOKEN_VERA = "xoxb-your-vera-channel-slack-bot-token")

# Slack channel IDs for notifications
SLACK_CHANNEL_POSTS <- "#vera-posts"      # Channel for post alerts
SLACK_CHANNEL_LINKS <- "#vera-links"      # Channel for link alerts
SLACK_CHANNEL_CHARTS <- "#vera-charts"    # Channel for network charts

# -----------------------------------------------------------------------------
# CROWDTANGLE LISTS
# -----------------------------------------------------------------------------

# Comma-separated CrowdTangle list IDs to monitor
# Find list IDs in CrowdTangle dashboard under "Saved Lists"
string_lids <- "list_id_1,list_id_2,list_id_3"

# -----------------------------------------------------------------------------
# MONITORING PARAMETERS
# -----------------------------------------------------------------------------

# Dry run mode (TRUE = skip writes to Slack/GSheets, useful for testing)
dryrun <- FALSE

# Number of posts to retrieve per API query
count <- 100

# Monitoring window (how far back to look for posts)
# Options: "1 HOUR", "6 HOUR", "12 HOUR", "1 DAY", "1 WEEK"
timeframe <- "6 HOUR"

# -----------------------------------------------------------------------------
# COORDINATION DETECTION PARAMETERS
# -----------------------------------------------------------------------------
# See docs/DEFINITIONS.md for detailed explanations

# Maximum time between posts to be considered coordinated
coordination_interval <- "60 secs"

# Percentile threshold for edge weight filtering (higher = stricter)
percentile_edge_weight <- 0.95

# Minimum coordinated shares to trigger chart generation
cooR.shares_cthreshold <- 50L

# -----------------------------------------------------------------------------
# THRESHOLD CALCULATION
# -----------------------------------------------------------------------------

# Method for calculating dynamic engagement thresholds
# Based on rolling statistics: median +/- (multiplier * IQR)
threshold_multiplier <- 1.5

# -----------------------------------------------------------------------------
# RED ALERT SCORING
# -----------------------------------------------------------------------------
# Score increments for statistical anomalies (0-3 scale)

# Metrics checked for anomalies:
# - Total engagement outside median +/- 1.5*IQR
# - Overperforming score outside median +/- 1.5*IQR
# - Combined metric outside median +/- 1.5*IQR

# -----------------------------------------------------------------------------
# GOOGLE FORMS INTEGRATION (Optional)
# -----------------------------------------------------------------------------

# Base URL for evaluation forms (pre-filled with alert data)
# Create a Google Form for analyst review and get the pre-filled URL format
EVAL_FORM_BASE_URL <- "https://docs.google.com/forms/d/e/your_form_id/viewform"
EVAL_FORM_ALERTID_ENTRY <- "entry.513958351"
EVAL_FORM_URL_ENTRY <- "entry.1457886713"

# -----------------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------------

# Log file path for error tracking
LOG_FILE <- "logs/vera_monitoring.log"

# Verbosity level: "minimal", "normal", "verbose"
LOG_LEVEL <- "normal"

# -----------------------------------------------------------------------------
# ADVANCED SETTINGS
# -----------------------------------------------------------------------------

# API rate limiting (seconds between requests)
api_sleep_time <- 1

# Maximum retry attempts for failed API calls
max_retries <- 3

# Timeout for API requests (seconds)
api_timeout <- 30

# =============================================================================
# VALIDATION (do not modify)
# =============================================================================

# Check that critical environment variables are set
.validate_config <- function() {
  required_vars <- c("CROWDTANGLE_API_KEY", "SERVICE_ACCOUNT")
  missing <- sapply(required_vars, function(v) Sys.getenv(v) == "")

  if (any(missing)) {
    warning(paste(
      "Missing required environment variables:",
      paste(names(missing)[missing], collapse = ", "),
      "\nPlease check your config.R file."
    ))
  }

  # Check service account file exists
  sa_path <- Sys.getenv("SERVICE_ACCOUNT")
  if (sa_path != "" && !file.exists(sa_path)) {
    warning(paste("Service account file not found:", sa_path))
  }
}

# Run validation on source
.validate_config()

# =============================================================================
# END OF CONFIGURATION
# =============================================================================
