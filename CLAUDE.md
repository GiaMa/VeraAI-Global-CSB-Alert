# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VERA-AI is a quasi-real-time R-based monitoring system for detecting coordinated information operations on Facebook. It monitors curated lists of accounts to detect three types of coordinated behavior:
- **CLSB** (Coordinated Link Sharing Behavior) - via CooRnet package
- **CMSB** (Coordinated Message Sharing Behavior) - text similarity detection
- **CITSB** (Coordinated Image-Text Sharing Behavior) - OCR text matching

**Status**: Deprecated following CrowdTangle API closure (August 2024). Serves as reference implementation.

## Running the Pipeline

```r
# Setup: Copy config template and add credentials
cp config/config_template.R config/config.R

# Install dependencies
install.packages(c("httr", "jsonlite", "quanteda", "igraph", "tidytable",
                   "dplyr", "slackr", "googlesheets4", "googledrive",
                   "urltools", "lubridate", "stringr", "digest"))
devtools::install_github("fabiogiglietto/CooRnet")

# Run pipeline
source("config/config.R")
source("R/main_pipeline.R")

# Dry run mode (no external writes)
dryrun <- TRUE
source("R/main_pipeline.R")
```

**Scheduled execution**: Configure cron to run every 6 hours.

## Architecture

### Main Entry Point
`R/main_pipeline.R` (~876 lines) orchestrates a 9-step workflow:
- Lines 1-21: Library loading
- Lines 45-67: Parameter configuration
- Lines 110-132: Google authentication
- Lines 140-253: Post retrieval
- Lines 255-446: Slack alerting
- Lines 448-715: CooRnet coordination detection
- Lines 717-747: CMSB/CITSB detection
- Lines 749-873: Account list updating

### Module Dependencies
```
main_pipeline.R
├── R/api/crowdtangle_query.R     # API wrapper with retry logic
├── R/api/gpt4_labeling.R         # GPT-4 cluster descriptions
├── R/coordination_detection/detect_CMSB.R   # Text similarity (cosine ≥ 0.7)
├── R/coordination_detection/detect_CITSB.R  # Image-text matching
├── R/utils/clean_urls.R          # URL normalization
├── R/utils/get_threshold.R       # Dynamic engagement thresholds
└── CooRnet package (external)    # Link sharing detection
```

### External Services
- CrowdTangle/Meta Content Library (Facebook data)
- Google Sheets (alert logging)
- Google Drive (network visualizations)
- Slack API (real-time notifications)
- OpenAI GPT-4 (cluster labeling)

## Key Parameters

Configured in `config/config.R`:
- `dryrun`: Skip external writes for testing
- `timeframe`: Monitoring window (default: "6 HOUR")
- `coordination_interval`: Max time between coordinated posts (default: "60 secs")
- `percentile_edge_weight`: Network filtering threshold (default: 0.95)
- `threshold_multiplier`: Red alert calculation (default: 1.5)

## Testing Individual Modules

```r
# Test URL cleaning
source("R/utils/clean_urls.R")
test_df <- data.frame(url = c("https://example.com?utm_source=test"))
clean_urls(test_df, "url")

# Test threshold calculation
source("R/utils/get_threshold.R")
threshold <- get_threshold("your_list_ids")
```

## Key Concepts

- **Coordination window**: Posts within 60 seconds sharing same content are flagged as coordinated
- **Red alert score** (0-3): Based on engagement metrics exceeding median ± 1.5×IQR
- **Edge weight percentile**: 95th percentile filtering removes weak network connections

## Documentation References

- `docs/WORKFLOW.md`: Conceptual 9-step workflow explanation
- `docs/IMPLEMENTATION.md`: Technical architecture details
- `docs/DEFINITIONS.md`: Terminology (coordination types, metrics, thresholds)
- `docs/ALERTS.md`: Alert interpretation guide
- `R/README.md`: Code documentation and function reference
- `data/README.md`: Dataset descriptions and data dictionary

## Adding New Detection Methods

1. Create new file in `R/coordination_detection/`
2. Follow pattern of `detect_CMSB.R` (return platform IDs for detected accounts)
3. Add `source()` call in `main_pipeline.R`
4. Integrate with account updating logic (lines 749-873)
