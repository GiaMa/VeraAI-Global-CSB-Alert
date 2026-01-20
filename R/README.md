# R Code Documentation

This directory contains all R scripts implementing the VERA-AI coordinated behavior monitoring system.

## Quick Start

```r
# 1. Install dependencies
install.packages(c(
  "httr", "jsonlite", "quanteda", "igraph", "tidytable",
  "dplyr", "slackr", "googlesheets4", "googledrive",
  "urltools", "lubridate", "stringr", "digest"
))
devtools::install_github("fabiogiglietto/CooRnet")

# 2. Configure credentials (see config/config_template.R)
source("config/config.R")

# 3. Run the pipeline
source("R/main_pipeline.R")
```

## Directory Structure

```
R/
├── main_pipeline.R              # Main orchestration script
├── README.md                    # This file
│
├── coordination_detection/      # Detection algorithms
│   ├── detect_CMSB.R            # Coordinated Message Sharing
│   ├── detect_CITSB.R           # Coordinated Image-Text Sharing
│   └── README.md                # Detection module documentation
│
├── api/                         # External service wrappers
│   ├── crowdtangle_query.R      # CrowdTangle API with retry logic
│   └── gpt4_labeling.R          # OpenAI GPT-4 integration
│
└── utils/                       # Utility functions
    ├── clean_urls.R             # URL sanitization
    └── get_threshold.R          # Dynamic threshold calculation
```

## Module Overview

### main_pipeline.R

**Purpose**: Orchestrates the complete 9-step monitoring workflow.

**Lines**: ~876

**Key sections**:
| Lines | Function |
|-------|----------|
| 1-21 | Library loading and function definitions |
| 45-67 | Parameter configuration |
| 110-132 | Google authentication |
| 140-253 | Post retrieval (seed + discovered accounts) |
| 255-446 | Slack alerting for posts |
| 448-715 | CooRnet coordination detection |
| 717-747 | CMSB and CITSB detection |
| 749-873 | Account list updating |

**Entry point**: Script executes sequentially when sourced.

### coordination_detection/

See [coordination_detection/README.md](coordination_detection/README.md) for detailed documentation.

| Script | Purpose | Input | Output |
|--------|---------|-------|--------|
| `detect_CMSB.R` | Message similarity detection | Posts dataframe | Platform IDs |
| `detect_CITSB.R` | Image text detection | Posts dataframe | Platform IDs |

### api/

| Script | Purpose | External Service |
|--------|---------|------------------|
| `crowdtangle_query.R` | Robust API queries | CrowdTangle |
| `gpt4_labeling.R` | Network labeling | OpenAI GPT-4 |

### utils/

| Script | Purpose |
|--------|---------|
| `clean_urls.R` | URL normalization and cleaning |
| `get_threshold.R` | Dynamic engagement threshold calculation |

## Dependency Graph

```
main_pipeline.R
├── crowdtangle_query.R
├── clean_urls.R
├── get_threshold.R
├── detect_CMSB.R
├── detect_CITSB.R
├── gpt4_labeling.R
└── [External: CooRnet package]
```

## Function Reference

### main_pipeline.R

```r
query_ct_api(query_string)
# Generic CrowdTangle API wrapper
# Returns: Parsed JSON response

log_message(message)
# Timestamped logging to console
# Side effect: Prints message with timestamp

get_emoji(redalert_score)
# Convert red alert score to flag emoji
# Returns: String ("", "🚩", "🚩🚩", or "🚩🚩🚩")
```

### coordination_detection/detect_CMSB.R

```r
detect_cmsb(oposts, timeframe, coordination_interval, percentile_edge_weight)
# Detect coordinated message sharing behavior
# Parameters:
#   oposts: Dataframe of monitored posts with message text
#   timeframe: Monitoring window (e.g., "6 HOUR")
#   coordination_interval: Max time between coordinated posts (e.g., "60 secs")
#   percentile_edge_weight: Edge weight threshold (e.g., 0.95)
# Returns: Vector of platform IDs for coordinated accounts
```

### coordination_detection/detect_CITSB.R

```r
detect_citsb(oposts, timeframe, coordination_interval, percentile_edge_weight)
# Detect coordinated image-text sharing behavior
# Parameters: Same as detect_cmsb
# Returns: Vector of platform IDs for coordinated accounts
```

### api/crowdtangle_query.R

```r
query_link_endpoint(query.string, sleep_time)
# Query CrowdTangle links endpoint with retry logic
# Parameters:
#   query.string: Full API URL with parameters
#   sleep_time: Seconds between requests
# Returns: Parsed JSON response or NA on failure
```

### api/gpt4_labeling.R

```r
get_gpt4_labels(df, model = "gpt-4")
# Generate descriptive labels for network clusters
# Parameters:
#   df: Dataframe with coordinated URL data
#   model: OpenAI model to use
# Returns: Input dataframe with added 'label' column
```

### utils/clean_urls.R

```r
clean_urls(df, column_name)
# Sanitize and normalize URLs
# Parameters:
#   df: Dataframe containing URLs
#   column_name: Name of URL column
# Returns: Dataframe with cleaned URLs
```

### utils/get_threshold.R

```r
get_threshold(string_lids)
# Calculate dynamic minimum interaction threshold
# Parameters:
#   string_lids: Comma-separated CrowdTangle list IDs
# Returns: Numeric threshold value
```

## Configuration

### Required Environment Variables

```bash
# CrowdTangle
CROWDTANGLE_API_KEY=your_key_here

# Google (service account JSON path)
SERVICE_ACCOUNT=/path/to/service_account.json

# Slack
SLACK_TOKEN_MINE=xoxb-your-token
SLACK_TOKEN_VERA=xoxb-your-token

# OpenAI
OPENAI_API_KEY=sk-your-key
```

### Script Parameters

Edit in `main_pipeline.R` lines 45-67:

```r
dryrun <- FALSE                     # Set TRUE to skip writes
count <- 100                        # Posts per query
string_lids <- "list,ids,here"      # CrowdTangle lists
timeframe <- "6 HOUR"               # Monitoring window
cooR.shares_cthreshold <- 50L       # Chart trigger threshold
coordination_interval <- "60 secs"  # Coordination window
percentile_edge_weight <- 0.95      # Network filter
```

## Testing

### Dry Run Mode

```r
dryrun <- TRUE
source("R/main_pipeline.R")
# Executes pipeline without Slack/GSheets writes
```

### Individual Module Testing

```r
# Test URL cleaning
source("R/utils/clean_urls.R")
test_df <- data.frame(url = c("https://example.com?utm_source=test"))
clean_urls(test_df, "url")

# Test threshold calculation
source("R/utils/get_threshold.R")
threshold <- get_threshold("your_list_ids")
```

## Error Handling

### API Errors

- **429 (Rate Limit)**: Automatic retry with sleep
- **Network errors**: Logged to `log.txt`
- **Parse errors**: Return NA, handled in conditionals

### Data Errors

- **Empty results**: Script stops with informative message
- **Missing columns**: Check input data structure
- **Type mismatches**: Ensure proper data types

## Performance Notes

### Memory Usage

- Large networks may require increased R memory
- Use `gc()` between major operations if needed
- Consider batch processing for historical analysis

### API Rate Limits

- CrowdTangle: Implement delays between requests
- GPT-4: Cost accumulates with large networks
- Google: Retry mechanism handles transient failures

## Extending the Code

### Adding New Detection Methods

1. Create new file in `coordination_detection/`
2. Follow pattern of `detect_CMSB.R`
3. Return platform IDs for detected accounts
4. Add source() call in `main_pipeline.R`
5. Integrate with account updating logic

### Adding New Alert Channels

1. Add authentication in parameter section
2. Create notification function following Slack pattern
3. Call in alert generation sections

---

*See [docs/IMPLEMENTATION.md](../docs/IMPLEMENTATION.md) for architecture details.*
*See [docs/WORKFLOW.md](../docs/WORKFLOW.md) for conceptual overview.*
