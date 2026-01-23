# Data Directory

This directory contains all datasets produced by the VERA-AI coordinated behavior monitoring system.

## Directory Structure

```
data/
├── README.md                    # This file
├── processed/                   # Cleaned, analyzed datasets
│   └── community_engagement_classified.csv
├── alerts/                      # Alert system outputs
│   └── veraai_alerts_links.csv
└── raw/                         # Unprocessed data (excluded from repo)
```

## Dataset Summary

| Dataset | Location | Rows | Size | Description |
|---------|----------|------|------|-------------|
| Community Engagement | `processed/community_engagement_classified.csv` | 208 | 934 KB | Processed dataset with Claude LLM classifications |
| Alert Links | `alerts/veraai_alerts_links.csv` | 14,244 | 24 MB | Original alert dataset (raw) |

---

## Data Dictionary

### community_engagement_classified.csv

**Description**: Processed dataset with comprehensive engagement metrics aggregated at the community level. Includes reaction breakdowns, cross-community sharing patterns, and derived classification fields. The geographical origin (`region`) and primary content focus (`primary_focus`) classifications were generated using Claude LLM to analyze the network labels and account names.

**Primary key**: `community_id`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `community_id` | integer | Community identifier | `1` |
| `label` | string | Community description | `"Pro-Putin propaganda"` |
| `region` | string | Geographic classification | `"Eastern Europe"` |
| `primary_focus` | string | Primary content category | `"Political"` |
| `account_count` | integer | Number of accounts | `150` |
| `cross_community_urls` | integer | URLs shared with other communities | `234` |
| `exclusive_urls` | integer | URLs shared only within community | `1,456` |
| `coordinated_shares` | integer | Total coordinated share events | `5,678` |
| `total_likes` | integer | Aggregated like count | `123,456` |
| `total_shares` | integer | Aggregated share count | `45,678` |
| `total_comments` | integer | Aggregated comment count | `12,345` |
| `love_count` | integer | Love reactions | `8,901` |
| `wow_count` | integer | Wow reactions | `2,345` |
| `haha_count` | integer | Haha reactions | `1,234` |
| `sad_count` | integer | Sad reactions | `567` |
| `angry_count` | integer | Angry reactions | `890` |
| `thankful_count` | integer | Thankful reactions | `123` |
| `care_count` | integer | Care reactions | `456` |
| `cross_community_engagement` | integer | Engagement on cross-posted content | `34,567` |
| `exclusive_engagement` | integer | Engagement on exclusive content | `156,789` |

**Derived metrics**:

```
cross_community_ratio = cross_community_urls / (cross_community_urls + exclusive_urls)
```

| Ratio | Interpretation |
|-------|---------------|
| > 0.5 | Network-wide amplification strategy |
| < 0.2 | Isolated community operation |
| 0.2-0.5 | Mixed strategy |

---

### veraai_alerts_links.csv

**Description**: Original dataset retrieved directly from the alert system. This is the raw output of the monitoring workflow, containing a comprehensive log of all coordinated link sharing alerts. Each row represents a URL flagged for coordinated sharing behavior.

**Primary key**: `alertId`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `expanded` | string | Full URL (expanded from shorteners) | `"https://example.com/article"` |
| `shares` | integer | Total share count | `1,234` |
| `cooR.shares` | integer | Coordinated share count | `567` |
| `engagement` | integer | Total engagement (all reactions + comments + shares) | `12,345` |
| `likes` | integer | Like count | `5,678` |
| `comments` | integer | Comment count | `890` |
| `shares_stat` | integer | Share count (from statistics) | `1,234` |
| `love` | integer | Love reactions | `456` |
| `wow` | integer | Wow reactions | `123` |
| `haha` | integer | Haha reactions | `89` |
| `sad` | integer | Sad reactions | `45` |
| `angry` | integer | Angry reactions | `67` |
| `thankful` | integer | Thankful reactions | `12` |
| `care` | integer | Care reactions | `34` |
| `comments.shares.ratio` | float | Comment/share ratio (normalized) | `0.42` |
| `component` | integer | Network component ID | `1` |
| `cluster` | integer | Cluster within component | `3` |
| `label` | string | GPT-4 network description | `"Pro-Putin propaganda"` |
| `redalert` | integer | Red alert score (0-3) | `2` |
| `alertId` | string | Unique identifier (SHA-256) | `"a1b2c3..."` |
| `cooR.account.url` | string | Coordinating account URLs (pipe-separated) | `"url1\|url2\|url3"` |
| `alert_date` | datetime | Alert generation timestamp | `"2024-03-15 12:00:00"` |

**Red alert score interpretation**:

| Score | Meaning | Recommended Action |
|-------|---------|-------------------|
| 0 | Within normal parameters | Routine monitoring |
| 1 | One statistical anomaly | Review if patterns emerge |
| 2 | Two anomalies | Prioritize for manual review |
| 3 | All anomalies present | Immediate attention |

**Filtering recommendations**:

```r
# High-priority alerts
alerts %>% filter(redalert >= 2)

# Significant coordination
alerts %>% filter(cooR.shares >= 50)

# High-reach content
alerts %>% filter(engagement >= 10000)

# Strong coordination signal
alerts %>% filter(cooR.shares / shares > 0.5)
```

---

## Loading Data

### R

```r
library(tidyverse)

# Load all datasets
nodes <- read_csv("data/processed/facebook_network_nodes.csv")
labels <- read_csv("data/processed/community_labels.csv")
engagement <- read_csv("data/processed/community_engagement_classified.csv")
alerts <- read_csv("data/alerts/veraai_alerts_links.csv")

# Join for analysis
full_network <- nodes %>%
  left_join(labels, by = c("community" = "community_id")) %>%
  left_join(engagement, by = c("community" = "community_id"))
```

### Python

```python
import pandas as pd

nodes = pd.read_csv("data/processed/facebook_network_nodes.csv")
labels = pd.read_csv("data/processed/community_labels.csv")
engagement = pd.read_csv("data/processed/community_engagement_classified.csv")
alerts = pd.read_csv("data/alerts/veraai_alerts_links.csv")

# Join for analysis
full_network = nodes.merge(labels, left_on="community", right_on="community_id")
```

---

## Data Provenance

### Collection Period
- **Start**: October 2023
- **End**: August 2024
- **Duration**: 10 months

### Data Sources
- **Primary**: CrowdTangle API (deprecated August 2024)
- **Replacement**: Meta Content Library (for future work)

### Processing Pipeline
1. Raw posts retrieved via CrowdTangle API
2. Coordination detection (CLSB, CMSB, CITSB)
3. Network construction and Louvain clustering
4. GPT-4 labeling of clusters
5. Alert generation and logging

---

## Privacy & Ethics

### Data Included
- Public Facebook page and group names
- Aggregated engagement metrics
- Coordination network structure
- URL sharing patterns

### Data Excluded
- Individual user information
- Private group content
- Personal identifiers
- Raw post content (except URLs)

### Usage Guidelines
- Data is for research purposes only
- Exercise caution when republishing account-level data
- URLs may link to removed content
- Account names may have changed since collection

---

## Large File Handling

The `veraai_alerts_links.csv` file (24 MB) approaches GitHub's size recommendations.

**Access options**:
1. **Repository sample**: First 1,000 rows included
2. **Full dataset**: Available via external repository

---

## Citation

When using these datasets, please cite:

1. This repository
2. Associated papers (see [manuscripts/PAPERS.md](../manuscripts/PAPERS.md))
3. CooRnet package: Giglietto et al. (2020)

---

*See [docs/OUTPUTS.md](../docs/OUTPUTS.md) for analysis guidance.*
*See [docs/ALERTS.md](../docs/ALERTS.md) for alert interpretation.*
