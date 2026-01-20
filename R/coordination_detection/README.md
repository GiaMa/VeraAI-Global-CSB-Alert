# Coordination Detection Modules

This directory contains detection algorithms for identifying coordinated sharing behavior.

## Overview

| Module | Behavior Type | Detection Method |
|--------|--------------|------------------|
| `detect_CMSB.R` | Message sharing | Cosine similarity on text |
| `detect_CITSB.R` | Image-text sharing | Exact match on OCR text |

Note: CLSB (Coordinated Link Sharing Behavior) is handled by the CooRnet package integrated in the main pipeline.

## detect_CMSB.R

### Purpose

Detect accounts sharing highly similar text messages within a coordination window.

### Algorithm

1. Extract message text from monitored posts
2. Create document-feature matrix using quanteda
3. Calculate pairwise cosine similarity
4. Filter pairs with similarity ≥ 0.7
5. Build bipartite network (accounts ↔ similar messages)
6. Project to account-account network
7. Filter edges by 95th percentile weight
8. Return highly connected account IDs

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `oposts` | dataframe | required | Monitored posts with message column |
| `timeframe` | character | "6 HOUR" | Monitoring window |
| `coordination_interval` | character | "60 secs" | Max time between coordinated posts |
| `percentile_edge_weight` | numeric | 0.95 | Edge weight threshold |

### Usage

```r
source("R/coordination_detection/detect_CMSB.R")

coordinated_ids <- detect_cmsb(
  oposts = posts_dataframe,
  timeframe = "6 HOUR",
  coordination_interval = "60 secs",
  percentile_edge_weight = 0.95
)
```

### Output

Vector of platform IDs (character) for accounts exhibiting coordinated message sharing.

### Dependencies

- quanteda (text analysis)
- igraph (network analysis)
- dplyr (data manipulation)

## detect_CITSB.R

### Purpose

Detect accounts sharing posts with identical image text (OCR-extracted) within a coordination window.

### Algorithm

1. Extract posts containing image text
2. Query CrowdTangle for other posts with matching image text
3. Filter to posts within coordination interval
4. Build bipartite network (accounts ↔ image text)
5. Project to account-account network
6. Filter edges by 95th percentile weight
7. Return highly connected account IDs

### Parameters

Same as `detect_CMSB.R`

### Usage

```r
source("R/coordination_detection/detect_CITSB.R")

coordinated_ids <- detect_citsb(
  oposts = posts_dataframe,
  timeframe = "6 HOUR",
  coordination_interval = "60 secs",
  percentile_edge_weight = 0.95
)
```

### Output

Vector of platform IDs (character) for accounts exhibiting coordinated image-text sharing.

### Dependencies

- httr (API requests)
- igraph (network analysis)
- CrowdTangle API access

### Note on API Usage

CITSB detection requires additional API queries to find matching image text, making it more expensive than CMSB detection.

## Comparison of Methods

| Aspect | CMSB | CITSB |
|--------|------|-------|
| Content type | Text messages | Image text (OCR) |
| Matching | Cosine similarity ≥ 0.7 | Exact match |
| API calls | None (local processing) | Additional queries required |
| Robustness | Handles paraphrasing | Exact matches only |
| Speed | Faster | Slower (API dependent) |

## Integration with Main Pipeline

Both modules are called from `main_pipeline.R`:

```r
# Lines 727-731
idstoadd_message <- detect_cmsb(
  oposts = oposts,
  timeframe = timeframe,
  coordination_interval = coordination_interval,
  percentile_edge_weight = percentile_edge_weight
)

# Lines 743-747
idstoadd_imgtxt <- detect_citsb(
  oposts = oposts,
  timeframe = timeframe,
  coordination_interval = coordination_interval,
  percentile_edge_weight = percentile_edge_weight
)
```

Results are then added to the monitoring pool if accounts are not already tracked.

## Extending Detection

### Adding New Detection Methods

1. Create new `.R` file following the pattern:
   - Accept standard parameters
   - Return vector of platform IDs
   - Handle edge cases (empty data, no coordination found)

2. Add source() call in main pipeline

3. Integrate with account updating logic (lines 749-873)

### Parameter Tuning

- **Similarity threshold**: Lower values catch more but increase false positives
- **Coordination interval**: Longer windows catch slower coordination
- **Edge weight percentile**: Lower values include weaker signals

---

*See [../README.md](../README.md) for full code documentation.*
*See [../../docs/WORKFLOW.md](../../docs/WORKFLOW.md) for conceptual explanation.*
