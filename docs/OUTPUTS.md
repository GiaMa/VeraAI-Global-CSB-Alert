# Outputs & Data Guide

This document describes the datasets produced by the VERA-AI monitoring system and provides guidance for interpretation.

## Dataset Overview

| Dataset | Location | Rows | Size | Description |
|---------|----------|------|------|-------------|
| Community Engagement | `data/processed/community_engagement_classified.csv` | 208 | 934 KB | Processed dataset with Claude LLM classifications |
| Alert Links | `data/alerts/veraai_alerts_links.csv` | 14,244 | 24 MB | Original alert dataset (raw) |

## Dataset Descriptions

### community_engagement_classified.csv

**Purpose**: Processed dataset with comprehensive engagement metrics aggregated by community for analysis. The geographical origin (`region`) and primary content focus (`primary_focus`) classifications were generated using Claude LLM to analyze the network labels and account names.

**Provenance**: Aggregated from post-level engagement data across all detected coordinated content, with LLM-derived classifications added.

**Schema**:

| Column | Type | Description |
|--------|------|-------------|
| `community_id` | integer | Community identifier |
| `label` | string | Community description |
| `region` | string | Regional classification |
| `primary_focus` | string | Primary content category |
| `account_count` | integer | Number of accounts |
| `cross_community_urls` | integer | URLs shared with other communities |
| `exclusive_urls` | integer | URLs shared only within community |
| `coordinated_shares` | integer | Total coordinated share events |
| `total_likes` | integer | Aggregated like count |
| `total_shares` | integer | Aggregated share count |
| `total_comments` | integer | Aggregated comment count |
| `love_count` | integer | Love reactions |
| `wow_count` | integer | Wow reactions |
| `haha_count` | integer | Haha reactions |
| `sad_count` | integer | Sad reactions |
| `angry_count` | integer | Angry reactions |
| `thankful_count` | integer | Thankful reactions |
| `care_count` | integer | Care reactions |
| `cross_community_engagement` | integer | Engagement on cross-posted content |
| `exclusive_engagement` | integer | Engagement on exclusive content |

**Derived metrics**:
- `cross_community_ratio = cross_community_urls / (cross_community_urls + exclusive_urls)`
  - High ratio suggests network-wide amplification strategy
  - Low ratio suggests isolated community operation

**Analysis opportunities**:
- Compare engagement patterns across operation types
- Identify communities with unusual reaction distributions
- Detect content sharing patterns between communities

### veraai_alerts_links.csv

**Purpose**: Original dataset retrieved directly from the alert system. This is the raw output of the monitoring workflow, containing a comprehensive log of all coordinated link alerts.

**Provenance**: Appended during each monitoring cycle when coordinated links are detected. This is unprocessed alert data.

**Schema**:

| Column | Type | Description |
|--------|------|-------------|
| `expanded` | string | Full URL (expanded from shorteners) |
| `shares` | integer | Total share count |
| `cooR.shares` | integer | Coordinated share count |
| `engagement` | integer | Total engagement |
| `likes` | integer | Like count |
| `comments` | integer | Comment count |
| `shares_stat` | integer | Share count (statistics) |
| `love` | integer | Love reactions |
| `wow` | integer | Wow reactions |
| `haha` | integer | Haha reactions |
| `sad` | integer | Sad reactions |
| `angry` | integer | Angry reactions |
| `thankful` | integer | Thankful reactions |
| `care` | integer | Care reactions |
| `comments.shares.ratio` | float | Comment/share ratio (-1 to 1) |
| `component` | integer | Network component ID |
| `cluster` | integer | Cluster within component |
| `label` | string | GPT-4 generated network label |
| `redalert` | integer | Red alert score (0-3) |
| `alertId` | string | Unique alert identifier (SHA-256 hash) |
| `cooR.account.url` | string | URLs of coordinating accounts |
| `alert_date` | datetime | When alert was generated |

**Filtering recommendations**:
- `redalert >= 2`: High-priority alerts
- `cooR.shares >= 50`: Significant coordination
- `engagement >= 10000`: High-reach content

## Alert Interpretation Guide

### Understanding Red Alert Scores

| Score | Meaning | Recommended Action |
|-------|---------|-------------------|
| 0 | Within normal parameters | Routine monitoring |
| 1 | One statistical anomaly | Review if other indicators present |
| 2 | Two anomalies | Prioritize for manual review |
| 3 | All anomalies present | Immediate attention recommended |

### Coordination Indicators

**Strong coordination signals**:
- `cooR.shares / shares > 0.5`: Majority of shares are coordinated
- Multiple accounts from same network label
- Posting timestamps within seconds of each other

**Potential false positives**:
- Breaking news (organic rapid sharing)
- Viral content from known sources
- Editorial networks (news outlets cross-posting)

### Network Labels

Labels provide context for interpreting coordination:

| Label Pattern | Interpretation |
|---------------|---------------|
| Geographic + political | Likely political operation |
| Entertainment + gambling | Likely lucrative operation |
| Mixed topics | May be spam/engagement farm |
| Single platform focus | Targeted campaign |

## Preliminary Analyses Conducted

### Network Structure Analysis

**Method**: Louvain community detection on projected coordination network

**Key findings**:
- 17 distinct network communities identified
- Largest network: ~600,000 members across 260 groups (gambling)
- Most coordinated: Pro-Putin network with synchronized 3-minute posting windows

### Engagement Pattern Analysis

**Method**: Comparative analysis of engagement metrics across operation types

**Key findings**:
- Gambling networks show artificially inflated comment counts
- Political networks have higher share-to-comment ratios
- Unmoderated group networks have highest view counts

### Regional Distribution

**Method**: Classification based on language, content, and targeting

**Key findings**:
- Southeast Asia: Entertainment and gambling focus
- Eastern Europe: Political propaganda
- Latin America: Mixed political and entertainment
- Africa: Entertainment and news communities

## Reproducing Analyses

### Loading Data in R

```r
library(tidyverse)

# Load network nodes
nodes <- read_csv("data/processed/facebook_network_nodes.csv")

# Load community information
labels <- read_csv("data/processed/community_labels.csv")
engagement <- read_csv("data/processed/community_engagement_classified.csv")

# Load alerts
alerts <- read_csv("data/alerts/veraai_alerts_links.csv")

# Join for analysis
network_analysis <- nodes %>%
  left_join(labels, by = c("community" = "community_id"))
```

### Basic Visualizations

```r
library(ggplot2)

# Community size distribution
ggplot(labels, aes(x = reorder(label, size), y = size)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  labs(title = "Network Community Sizes", x = "Community", y = "Accounts")

# Alert score distribution
ggplot(alerts, aes(x = factor(redalert))) +
  geom_bar() +
  labs(title = "Red Alert Score Distribution", x = "Score", y = "Count")
```

### Network Visualization

```r
library(igraph)

# Create network from nodes
# (Requires edge data from coordination detection output)
g <- graph_from_data_frame(edges, vertices = nodes)

# Plot with community coloring
plot(g,
     vertex.color = nodes$community,
     vertex.size = log(nodes$degree + 1),
     vertex.label = NA)
```

## Data Access & Licensing

### Access Restrictions

- Full alert dataset (24 MB) may exceed GitHub size recommendations
- Consider hosting on Zenodo/OSF for archival access
- Sample data included in repository; full data available on request

### Citation Requirements

When using these datasets, please cite:
1. This repository
2. The associated academic papers (see [manuscripts/PAPERS.md](../manuscripts/PAPERS.md))
3. CooRnet package if using coordination detection methodology

### Privacy Considerations

- Account names are public Facebook page/group names
- No personal user data included
- URLs may link to content that has since been removed
- Exercise caution when republishing account-level data

## Large File Handling

The `veraai_alerts_links.csv` file (24 MB) approaches GitHub's recommended file size limits.

**Options for access**:
1. **Repository sample**: First 1,000 rows included in `data/alerts/`
2. **Full dataset**: Available via external repository

---

*See [ALERTS.md](ALERTS.md) for detailed alert system documentation.*
*See [data/README.md](../data/README.md) for complete data dictionary.*
