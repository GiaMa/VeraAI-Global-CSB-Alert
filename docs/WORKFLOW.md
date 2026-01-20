# Monitoring Workflow

This document explains the conceptual workflow of the VERA-AI coordinated behavior monitoring system.

## Conceptual Overview

### The Problem

Social media platforms like Facebook have become vectors for **deceptive information operations**---organized communicative activities designed to mislead users and cause harm. These operations:

- Deliberately pollute the digital information ecosystem with low-credibility content
- Flood platforms with clickbait, divisive memes, and emotionally charged posts
- Erode public trust and foster cynicism
- Blur boundaries between false and legitimate information

Traditional approaches focusing on "fake news" miss the broader spectrum of harmful coordinated activities, including:
- Political propaganda (domestic and foreign)
- Issue-based campaigns (conspiracy theories, anti-vaccine content)
- Lucrative operations (gambling promotion, scams, clickbait monetization)

### The Solution

The VERA-AI workflow implements **cyclical monitoring** of known problematic actors to:

1. Surface popular content before it spreads widely
2. Detect coordination patterns indicating organized operations
3. Dynamically expand monitoring as new coordinated accounts are discovered
4. Alert researchers in quasi-real-time for rapid response

## Actor List Management

### Seed List Construction

The monitoring begins with a curated seed list of Facebook accounts (Pages and public Groups) selected based on:

- **Fact-checking databases**: Accounts that repeatedly shared URLs flagged by Meta's third-party fact-checking partners
- **Investigative reports**: Accounts identified in journalistic investigations
- **Academic research**: Accounts documented in peer-reviewed studies
- **Platform reports**: Accounts flagged in Meta's Coordinated Inauthentic Behavior (CIB) reports

**Initial seed criteria**: Accounts must have coordinatedly shared a minimum of 4 URLs from a corpus of 36,091 web pages identified as false (2017-2022).

### List Structure

Lists are organized in CrowdTangle/Meta Content Library by:
- Account type (Pages vs. Groups)
- Geographic/thematic focus (e.g., "EU vs disinfo pages", "DMI Winter School 2023")
- Discovery method (seed vs. algorithmically discovered)

### Dynamic List Expansion

The system automatically expands monitoring by:
1. Detecting new accounts exhibiting coordinated behavior with seed accounts
2. Filtering to accounts above the 90th percentile of coordination frequency
3. Balancing novelty (recently discovered) with persistence (frequently detected)
4. Adding qualified accounts to the monitoring pool

This creates a **self-reinforcing detection mechanism** that adapts to evolving coordination patterns.

## Monitoring Cycle

### Cycle Frequency

The system runs on a **6-hour cycle**, chosen to:
- Capture content while still in early distribution phase
- Allow sufficient time for engagement patterns to emerge
- Balance API rate limits with monitoring comprehensiveness

### Cycle Steps

Each 6-hour cycle follows a 9-step workflow:

```
1. COMPILATION
   └── Load seed lists and previously discovered accounts

2. MONITORING
   └── Query CrowdTangle API for recent posts
   └── Filter by minimum interaction threshold (dynamically calculated)
   └── Retrieve top 100 overperforming posts

3. EVALUATION
   └── Calculate engagement metrics (comment/share ratio)
   └── Compute combined scoring algorithm
   └── Identify statistical outliers for "red alert" flagging

4. ANALYSIS
   └── Extract URLs, images, and text from posts
   └── Identify content shared across multiple accounts

5. SEARCH
   └── Query link endpoint for all shares of extracted URLs
   └── Paginate results (up to 10 pages per URL)

6. DETECTION
   └── Run coordination detection algorithms
   └── Build bipartite networks of accounts and shared content
   └── Apply edge weight thresholds

7. MATCHING
   └── Match detected networks to known communities
   └── Generate GPT-4 labels for new clusters

8. MERGING
   └── Combine results across detection methods
   └── Deduplicate accounts

9. UPDATING
   └── Add newly discovered coordinated accounts to monitoring pool
   └── Log alerts and update Google Sheets
   └── Send Slack notifications
```

### Threshold Calculation

The minimum interaction threshold is **dynamically calculated** to adapt to:
- Time-of-day variations in platform activity
- Day-of-week patterns
- Current events affecting engagement levels

The calculation:
1. Queries multiple timeframes (15 minutes to 6 hours)
2. Calculates median expected interactions for each
3. Applies quartile filtering to remove outliers
4. Returns averaged threshold multiplied by 10

This ensures the system surfaces genuinely overperforming content rather than typical high-engagement posts.

## Coordination Types

The system detects three types of coordinated behavior:

### CLSB: Coordinated Link Sharing Behavior

**Definition**: Multiple accounts sharing identical URLs within a short time window.

**Detection method**:
1. Extract URLs from monitored posts
2. Query all platform shares of each URL
3. Build bipartite network (accounts ↔ URLs)
4. Project to account-account network based on shared URLs
5. Filter edges by weight (95th percentile threshold)
6. Identify connected components as coordinated networks

**Key parameters**:
- Coordination interval: 60 seconds (default)
- Edge weight percentile: 0.95
- Minimum shares for URL inclusion: 2

**Implementation**: Uses the CooRnet R package (`get_coord_shares()`)

### CMSB: Coordinated Message Sharing Behavior

**Definition**: Multiple accounts sharing highly similar text messages within a coordination window.

**Detection method**:
1. Extract message text from monitored posts
2. Build document-term matrix using quanteda
3. Calculate pairwise cosine similarity
4. Identify message pairs exceeding similarity threshold (0.7)
5. Build coordination network from similar message sharing
6. Apply same edge weight filtering as CLSB

**Key parameters**:
- Similarity threshold: 0.7 (cosine similarity)
- Coordination interval: 60 seconds
- Edge weight percentile: 0.95

**Implementation**: `R/coordination_detection/detect_CMSB.R`

### CITSB: Coordinated Image-Text Sharing Behavior

**Definition**: Multiple accounts sharing posts with identical image text (OCR-extracted text from images) within a coordination window.

**Detection method**:
1. Extract image text from monitored posts (via CrowdTangle's OCR)
2. Query platform for other posts with matching image text
3. Build bipartite network (accounts ↔ image text)
4. Project to account-account network
5. Apply edge weight filtering

**Key parameters**:
- Match type: Exact match (image text only)
- Coordination interval: 60 seconds
- Edge weight percentile: 0.95

**Implementation**: `R/coordination_detection/detect_CITSB.R`

## Alert Triggering

### Red Alert Scoring

Posts and links receive "red alert" scores (0-3) based on:

1. **Total engagement**: Outside expected range (median ± 1.5 × IQR)
2. **Score**: CrowdTangle overperforming score outside expected range
3. **Combined metric**: score × comment/share ratio outside expected range

Each criterion met adds 1 to the red alert score. Posts with scores ≥ 1 receive flag indicators in Slack notifications.

### Alert Thresholds

Thresholds are calculated from historical data stored in Google Sheets:
- `commented_posts_Summary_Stats`: Statistics for most-commented posts
- `shared_posts_Summary_Stats`: Statistics for most-shared posts
- `links_Summary_Stats`: Statistics for coordinated links

Thresholds update continuously based on rolling statistics.

### Notification Triggers

Alerts are sent when:
- Minimum 3 posts meet criteria (prevents alerts on slow news cycles)
- Coordinated links exceed 50 coordinated shares (triggers network visualization)

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      INPUT SOURCES                               │
├─────────────────────────────────────────────────────────────────┤
│  • Seed lists (CrowdTangle list IDs)                            │
│  • Previously discovered accounts (idstoadd.rds)                 │
│  • Editorial filter list (accounts to exclude)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CROWDTANGLE API                               │
├─────────────────────────────────────────────────────────────────┤
│  Endpoints used:                                                 │
│  • /posts/search - Retrieve overperforming posts                │
│  • /links - Get all shares of specific URLs                     │
│  • /lists/{id}/accounts - Get accounts in lists                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  PROCESSING PIPELINE                             │
├─────────────────────────────────────────────────────────────────┤
│  1. URL extraction and cleaning                                  │
│  2. Coordination detection (CLSB, CMSB, CITSB)                  │
│  3. Network construction and clustering                          │
│  4. GPT-4 cluster labeling                                       │
│  5. Red alert scoring                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OUTPUTS                                     │
├─────────────────────────────────────────────────────────────────┤
│  • Slack notifications (top 3 shared/commented posts, top 10    │
│    coordinated links)                                            │
│  • Google Sheets (shared_posts, commented_posts, links)         │
│  • Google Drive (interactive network charts)                    │
│  • Local files (updated account lists)                          │
└─────────────────────────────────────────────────────────────────┘
```

## Key Assumptions

### About "Problematic Actors"

The system operationalizes "problematic actors" as accounts that:
1. Have repeatedly shared content flagged by fact-checkers
2. Exhibit coordinated sharing behavior with known problematic accounts
3. Are identified in documented CIB takedowns

**Important**: This is a behavioral definition, not an attribution of intent. Accounts may be:
- Deliberately malicious operators
- Compromised accounts used without owner knowledge
- Authentic users unknowingly participating in amplification

### About Coordination

Coordination is inferred from **temporal and content patterns**, not from direct evidence of communication between actors. The assumption is that:
- Identical content shared within 60 seconds suggests non-organic behavior
- High edge weights (95th percentile) filter out coincidental sharing
- Cluster analysis reveals structured networks rather than random overlap

### About Platform Affordances

The workflow assumes that coordinated actors exploit:
- **Algorithmic ranking**: Engagement signals boost content visibility
- **Group structures**: Large groups provide audiences for amplification
- **Identity flexibility**: Name changes and profile manipulation obscure operations

## Scalability Demonstration

During the 10-month operational period (October 2023 - August 2024):

| Metric | Value |
|--------|-------|
| Initial seed accounts | 1,225 |
| Newly discovered accounts | 2,126 |
| Total coordinated links detected | 10,681 |
| Coordinated posts captured | 7,068 |
| Distinct networks identified | 17 |

The self-reinforcing detection mechanism demonstrated substantial scalability, with the monitoring pool nearly doubling through algorithmic discovery.

---

*See [DEFINITIONS.md](DEFINITIONS.md) for detailed terminology definitions.*
*See [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical architecture details.*
