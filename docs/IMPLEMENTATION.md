# Technical Implementation

This document details the technical architecture and code organization of the VERA-AI monitoring system.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MAIN PIPELINE                                │
│                      (main_pipeline.R)                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   INPUTS    │  │  DETECTION  │  │   ALERTS    │  │  OUTPUTS   │ │
│  │             │  │             │  │             │  │            │ │
│  │ • CT Lists  │  │ • CooRnet   │  │ • Slack     │  │ • CSV      │ │
│  │ • RDS files │──│ • CMSB      │──│ • GSheets   │──│ • RDS      │ │
│  │ • GSheets   │  │ • CITSB     │  │ • GDrive    │  │ • Charts   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    UTILITY MODULES                           │    │
│  │  clean_urls.R │ get_threshold.R │ query_link_endpoint.R     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    EXTERNAL SERVICES                         │    │
│  │  CrowdTangle API │ OpenAI API │ Google APIs │ Slack API     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Module Descriptions

### main_pipeline.R

**Purpose**: Orchestrates the entire monitoring workflow.

**Location**: `R/main_pipeline.R`

**Key functions**:
- `query_ct_api()`: Generic CrowdTangle API query wrapper
- `log_message()`: Timestamped logging
- `get_emoji()`: Red alert score to emoji conversion for Slack

**Workflow sections**:
1. Library loading and function sourcing (lines 1-21)
2. Parameter configuration (lines 45-67)
3. Google Sheets/Drive authentication (lines 110-132)
4. Post retrieval from seed lists (lines 140-166)
5. Post retrieval from discovered accounts (lines 168-253)
6. Slack alerting for top posts (lines 255-446)
7. Coordination detection via CooRnet (lines 448-715)
8. CMSB detection (lines 717-731)
9. CITSB detection (lines 733-747)
10. Account list updating (lines 749-873)

**Configuration parameters**:

```r
dryrun <- FALSE                    # Set TRUE to skip external writes
count <- 100                       # Posts per API query
string_lids <- "1760793,..."       # CrowdTangle list IDs
timeframe <- "6 HOUR"              # Monitoring window
cooR.shares_cthreshold <- 50L      # Minimum shares for network chart
coordination_interval <- "60 secs" # Coordination time window
percentile_edge_weight <- 0.95     # Network filtering threshold
```

### Detection Modules

#### detect_CMSB.R

**Purpose**: Detect Coordinated Message Sharing Behavior.

**Location**: `R/coordination_detection/detect_CMSB.R`

**Input**: `oposts` dataframe (monitored posts with message text)

**Output**: Vector of platform IDs for coordinated accounts

**Algorithm**:
1. Extract unique messages from posts
2. Create document-feature matrix (quanteda)
3. Calculate cosine similarity between all message pairs
4. Filter pairs with similarity ≥ 0.7
5. Build bipartite network of accounts and similar messages
6. Project to account-account network
7. Filter edges by 95th percentile weight
8. Return platform IDs of highly connected accounts

**Key parameters**:
```r
similarity_threshold <- 0.7
coordination_interval <- "60 secs"
percentile_edge_weight <- 0.95
```

#### detect_CITSB.R

**Purpose**: Detect Coordinated Image-Text Sharing Behavior.

**Location**: `R/coordination_detection/detect_CITSB.R`

**Input**: `oposts` dataframe (monitored posts with image text)

**Output**: Vector of platform IDs for coordinated accounts

**Algorithm**:
1. Extract posts containing image text
2. Query CrowdTangle for other posts with matching image text
3. Filter to posts within coordination interval
4. Build bipartite network of accounts and image text
5. Project to account-account network
6. Filter edges by 95th percentile weight
7. Return platform IDs of highly connected accounts

**Differences from CMSB**:
- Uses exact match on image text (not similarity)
- Requires additional API queries to find matching posts
- More computationally expensive due to search requirements

### API Wrappers

#### crowdtangle_query.R (query_link_endpoint.R)

**Purpose**: Robust CrowdTangle link endpoint wrapper with error handling.

**Location**: `R/api/crowdtangle_query.R`

**Function**: `query_link_endpoint(query.string, sleep_time)`

**Features**:
- Automatic retry on HTTP 429 (rate limit) errors
- Configurable sleep time between retries
- Error logging to `log.txt`
- JSON parsing with flattening

**Usage**:
```r
result <- query_link_endpoint(
  "https://api.crowdtangle.com/links?link=...",
  sleep_time = 0.5
)
```

#### gpt4_labeling.R (get_gpt4_labels.R)

**Purpose**: Generate descriptive labels for coordinated network clusters.

**Location**: `R/api/gpt4_labeling.R`

**Function**: `get_gpt4_labels(df, model = "gpt-4")`

**Input**: Dataframe with coordinated URL information including account URLs

**Output**: Same dataframe with added `label` column

**Prompt structure**:
- Requests geographic/linguistic characteristics
- Requests primary topic/theme of coordination
- Returns concise descriptive label

**Rate limiting**: Implements progress bar and respects API rate limits

### Utility Functions

#### clean_urls.R

**Purpose**: Sanitize and normalize URLs for comparison.

**Location**: `R/utils/clean_urls.R`

**Function**: `clean_urls(df, column_name)`

**Operations**:
1. Remove tracking parameters (UTM, fbclid, etc.)
2. Normalize social media URLs (YouTube, WhatsApp, Facebook)
3. Decode URL encoding
4. Remove redirect wrappers
5. Filter out low-value URLs (bare domains)

**Removed parameters**:
```r
c("utm_source", "utm_medium", "utm_campaign", "utm_term",
  "utm_content", "fbclid", "gclid", "ref", "source", ...)
```

#### get_threshold.R

**Purpose**: Calculate dynamic minimum interaction threshold.

**Location**: `R/utils/get_threshold.R`

**Function**: `get_threshold(string_lids)`

**Algorithm**:
1. Query posts at multiple time intervals (15 min to 6 hours)
2. Calculate median engagement for each interval
3. Apply quartile filtering to remove outliers
4. Average across intervals
5. Return threshold value

**Rationale**: Adapts to current platform activity levels, ensuring the system surfaces genuinely overperforming content.

## Execution Modes

### Interactive Execution

For testing and development:

```r
# Set dryrun to avoid external writes
dryrun <- TRUE

# Source and run
source("R/main_pipeline.R")
```

### Scheduled Execution

For production monitoring:

**Linux/Mac cron job**:
```bash
# Run every 6 hours
0 */6 * * * Rscript /path/to/R/main_pipeline.R >> /path/to/logs/vera.log 2>&1
```

**Windows Task Scheduler**:
- Program: `Rscript.exe`
- Arguments: `C:\path\to\R\main_pipeline.R`
- Trigger: Every 6 hours

### Batch/Historical Processing

For reprocessing historical data:

```r
# Modify timeframe parameter
timeframe <- "24 HOUR"  # or specific date range

# Disable real-time alerts
dryrun <- TRUE

# Run pipeline
source("R/main_pipeline.R")
```

## Configuration Parameters

### Full Parameter Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `dryrun` | logical | `FALSE` | Skip external writes (Slack, GSheets) |
| `count` | integer | `100` | Number of posts per API query |
| `string_lids` | character | (list IDs) | Comma-separated CrowdTangle list IDs |
| `minInteractions` | integer | dynamic | Minimum engagement threshold |
| `timeframe` | character | `"6 HOUR"` | Monitoring time window |
| `cooR.shares_cthreshold` | integer | `50` | Minimum shares for network chart |
| `autochart_gfolderid` | character | (folder ID) | Google Drive folder for charts |
| `coordination_interval` | character | `"60 secs"` | Maximum time between coordinated posts |
| `percentile_edge_weight` | numeric | `0.95` | Edge weight threshold for filtering |
| `keep_editorial_network` | logical | `FALSE` | Include known editorial accounts |

### Environment Variables Required

```bash
CROWDTANGLE_API_KEY     # Main CrowdTangle token
CROWDTANGLE_API_KEY_VERAAI  # Project-specific token (if different)
SERVICE_ACCOUNT         # Path to Google service account JSON
SLACK_TOKEN_MINE        # Slack bot token (primary)
SLACK_TOKEN_VERA        # Slack bot token (project channel)
OPENAI_API_KEY          # OpenAI API key for GPT-4
```

## Error Handling

### API Rate Limiting

CrowdTangle (429 errors):
- Automatic retry with exponential backoff
- Logged to `log.txt`
- Maximum 10 pagination iterations per URL

Google Sheets:
- Retry mechanism with 3 attempts
- Error messages written to console

### Missing Data

- Empty post results: Script stops with message "Not enough posts!"
- Missing URLs: Skipped with logging
- Failed API calls: Return NA, handled in conditionals

### Network Analysis Failures

CooRnet errors caught with `tryCatch()`:
- Returns NA on failure
- Processing continues with available data

## Memory Management

### Large Dataset Handling

The script includes explicit memory cleanup:

```r
rm(parsed, query_string)  # After API calls
rm(lposts, aposts)        # After merging
rm(list=setdiff(ls(), c("essential_vars")))  # After sections
```

### Network Size Considerations

For very large networks:
- Consider increasing R memory limits
- Process URLs in batches
- Use `gc()` between major operations

## Logging

### Log Output

Messages include timestamps:
```
######### SCRIPT STARTED, NOW COMPUTING PARAMETERS... ######### 2024-01-15 12:00:00
######### WORKING ON 100 POSTS, NOW SENDING SLACK ALERTS ######### 2024-01-15 12:01:30
```

### Log File

API errors written to `log.txt` in working directory.

### Google Sheets Logging

Alert data appended to sheets:
- `shared_posts`: Top shared posts per cycle
- `commented_posts`: Top commented posts per cycle
- `links`: Coordinated link alerts
- `*_Summary_Stats`: Rolling statistics for threshold calculation

## Known Limitations

### Platform Dependencies

1. **CrowdTangle deprecation** (August 2024): Primary data source no longer available
   - Workaround: Migrate to Meta Content Library
   - Impact: Some endpoint functionality differs

2. **API rate limits**: Constrain monitoring comprehensiveness
   - Workaround: Prioritize by engagement score
   - Impact: May miss lower-engagement coordination

### Algorithmic Limitations

1. **Coordination interval sensitivity**: 60-second window may miss slower coordination
2. **Edge weight threshold**: 95th percentile may be too aggressive for smaller networks
3. **Similarity threshold**: 0.7 cosine similarity may miss paraphrased content

### Scalability Constraints

1. **Memory**: Large networks require significant RAM
2. **API costs**: GPT-4 labeling incurs per-request charges
3. **Storage**: Long-term monitoring generates substantial data

---

*See [WORKFLOW.md](WORKFLOW.md) for conceptual overview.*
*See [R/README.md](../R/README.md) for code-level documentation.*
