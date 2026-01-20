# Alert System Documentation

This document describes the VERA-AI alert system, including notification types, interpretation guidance, and response protocols.

## Alert System Overview

The monitoring system generates three types of alerts:

1. **Slack notifications**: Real-time messages to designated channels
2. **Google Sheets logging**: Persistent record of all alerts
3. **Network visualizations**: Interactive charts for high-coordination events

## Alert Types

### Post Alerts

**Trigger**: Every 6-hour monitoring cycle (when ≥3 posts meet criteria)

**Content**: Top 3 most-shared and top 3 most-commented overperforming posts

**Format**:
```
The top 3 most shared over-performing posts during the last 6 HOURS are:
1. [post_url] (account_name) 🚩 - Evaluation form
2. [post_url] (account_name) - Evaluation form
3. [post_url] (account_name) 🚩🚩 - Evaluation form
```

**Fields included**:
- Post URL (direct link to Facebook post)
- Account name (posting account)
- Red alert flags (🚩 = 1, 🚩🚩 = 2, 🚩🚩🚩 = 3)
- Evaluation form link (for analyst review)

### Link Alerts

**Trigger**: When coordinated link sharing is detected

**Content**: Top 10 most-shared coordinated links

**Format**:
```
Top 10 mostly shared coordinated links of the last 6 HOURS are:
1. [url] (network_label) 🚩🚩 - Evaluation form
2. [url] (network_label) - Evaluation form
...
```

**Fields included**:
- Expanded URL (full link after shortener expansion)
- Network label (GPT-4 generated description of coordinating network)
- Red alert flags
- Evaluation form link

### Network Visualization Alerts

**Trigger**: Coordinated links exceeding 50 coordinated shares

**Content**: Interactive timeline chart uploaded to Google Drive

**File format**: `.rds` (R data format for CooRnet visualization)

**Access**: Shared Google Drive folder (requires permissions)

## Google Sheets Structure

### shared_posts Sheet

| Column | Description |
|--------|-------------|
| postUrl | Direct link to Facebook post |
| date | Post publication date |
| account.name | Posting account name |
| statistics.actual.likeCount | Like count |
| statistics.actual.shareCount | Share count |
| statistics.actual.commentCount | Comment count |
| statistics.actual.loveCount | Love reactions |
| statistics.actual.wowCount | Wow reactions |
| statistics.actual.hahaCount | Haha reactions |
| statistics.actual.sadCount | Sad reactions |
| statistics.actual.angryCount | Angry reactions |
| statistics.actual.thankfulCount | Thankful reactions |
| statistics.actual.careCount | Care reactions |
| score | CrowdTangle overperforming score |
| comment.shares.ratio | Comment/share ratio |
| combined.metric | score × comment.shares.ratio |
| alertId | Unique identifier (SHA-256) |
| alert_date | When alert was generated |

### commented_posts Sheet

Same structure as `shared_posts`, containing top commented posts.

### links Sheet

| Column | Description |
|--------|-------------|
| expanded | Full URL |
| cooR.shares | Coordinated share count |
| engagement | Total engagement |
| (reaction counts) | Individual reaction types |
| comments.shares.ratio | Comment/share ratio |
| component | Network component ID |
| cluster | Cluster within component |
| label | GPT-4 network description |
| redalert | Red alert score |
| alertId | Unique identifier |
| cooR.account.url | Coordinating account URLs |
| alert_date | Alert timestamp |

### Summary Statistics Sheets

Three sheets maintain rolling statistics for threshold calculation:
- `shared_posts_Summary_Stats`
- `commented_posts_Summary_Stats`
- `links_Summary_Stats`

Each contains:
- Median values for key metrics
- IQR (interquartile range) values
- Used to calculate dynamic thresholds

## Red Alert Scoring

### Calculation Method

For posts:
```
cp_redalert = 0  # commented posts
sp_redalert = 0  # shared posts

# Increment for each anomaly:
if (total_engagement outside median ± 1.5×IQR): score += 1
if (score outside median ± 1.5×IQR): score += 1
if (combined.metric outside median ± 1.5×IQR): score += 1
```

For links:
```
redalert = 0

if (engagement outside median ± 1.5×IQR): redalert += 1
if (comments.shares.ratio outside median ± 1.5×IQR): redalert += 1
```

### Interpreting Scores

| Score | Visual | Meaning | Priority |
|-------|--------|---------|----------|
| 0 | (none) | Normal parameters | Routine |
| 1 | 🚩 | One anomaly | Low |
| 2 | 🚩🚩 | Two anomalies | Medium |
| 3 | 🚩🚩🚩 | All anomalies | High |

### Anomaly Types

**Total engagement anomaly**:
- Content receiving unusually high OR low total engagement
- May indicate viral spread OR engagement suppression

**Score anomaly**:
- Content significantly over OR underperforming relative to account history
- High: content resonating beyond usual audience
- Low: content failing to engage typical audience

**Combined metric anomaly**:
- Unusual combination of performance and engagement type
- Flags content with atypical comment/share balance

## Evaluation Form

Each alert includes a link to an evaluation form for analyst review.

### Form Structure

Pre-filled fields:
- `alertId`: Links evaluation to specific alert
- `postUrl` or `expanded`: Content being evaluated

Analyst input fields:
- Content classification
- Deception assessment
- Recommended action
- Notes

### Form URL Construction

```
base_url + entry.513958351=[alertId] + entry.1457886713=[content_url]
```

## Response Protocols

### Triage Process

1. **Review Slack notification** - Check flag count and network labels
2. **Assess content** - Click through to evaluate post/link
3. **Check network context** - Review other recent alerts from same network
4. **Document in form** - Complete evaluation form
5. **Escalate if needed** - Flag for platform reporting or further investigation

### Priority Matrix

| Red Alert | Network Type | Recommended Response |
|-----------|--------------|---------------------|
| 3 | Political | Immediate review |
| 3 | Lucrative | Same-day review |
| 2 | Political | Same-day review |
| 2 | Lucrative | Next-cycle review |
| 1 | Any | Batch review |
| 0 | Any | No action unless pattern emerges |

### Escalation Criteria

Consider escalation to platform reporting when:
- Same network generates repeated high-scoring alerts
- Content violates platform policies (verified)
- Coordination pattern indicates active operation
- Content poses imminent harm risk

## Common Alert Patterns

### Legitimate High-Engagement (False Positives)

**Pattern**: High engagement, low coordination
- Breaking news from verified sources
- Viral content from known creators
- Seasonal/event-driven spikes

**Action**: Note in evaluation form; no further action

### Emerging Coordination

**Pattern**: Moderate scores, new network label
- Previously unknown accounts coordinating
- New content themes appearing
- Geographic expansion

**Action**: Add accounts to watch list; continue monitoring

### Active Operation

**Pattern**: Consistent high scores, established network
- Same network in multiple consecutive cycles
- Escalating coordination metrics
- Professional-quality content

**Action**: Document thoroughly; consider platform report

### Declining Operation

**Pattern**: Decreasing scores over time
- Content removal by platform
- Account suspensions reducing network
- Organic interest waning

**Action**: Continue monitoring; document decline pattern

## Alert History Analysis

### Accessing Historical Alerts

```r
library(googlesheets4)

# Authenticate
gs4_auth(path = Sys.getenv("SERVICE_ACCOUNT"))

# Read sheets
shared <- read_sheet(sheet_url, sheet = "shared_posts")
commented <- read_sheet(sheet_url, sheet = "commented_posts")
links <- read_sheet(sheet_url, sheet = "links")
```

### Trend Analysis

```r
library(tidyverse)

# Alerts over time
links %>%
  mutate(date = as.Date(alert_date)) %>%
  group_by(date, label) %>%
  summarise(
    alerts = n(),
    avg_redalert = mean(redalert),
    total_engagement = sum(engagement)
  ) %>%
  ggplot(aes(x = date, y = alerts, fill = label)) +
  geom_bar(stat = "identity")
```

### Network Activity Patterns

```r
# Identify most active networks
links %>%
  group_by(label) %>%
  summarise(
    total_alerts = n(),
    avg_score = mean(redalert),
    peak_engagement = max(engagement)
  ) %>%
  arrange(desc(total_alerts))
```

## Troubleshooting

### Missing Alerts

**Symptoms**: Expected alert not generated

**Possible causes**:
1. Content below minimum interaction threshold
2. Fewer than 3 qualifying posts
3. API rate limiting during data collection
4. dryrun = TRUE in configuration

**Resolution**: Check logs; verify parameters; retry manually

### Duplicate Alerts

**Symptoms**: Same content appearing in multiple cycles

**Possible causes**:
1. Content continues to perform over extended period
2. alertId generation issue (check hash inputs)

**Resolution**: Duplicate alerts for sustained performance are expected; verify alertId uniqueness

### High False Positive Rate

**Symptoms**: Many alerts flagging legitimate content

**Possible causes**:
1. Threshold statistics skewed by outliers
2. Breaking news events affecting baseline
3. Seed list includes legitimate high-engagement accounts

**Resolution**: Review summary statistics; consider temporary threshold adjustment; audit seed list

---

*See [OUTPUTS.md](OUTPUTS.md) for dataset documentation.*
*See [WORKFLOW.md](WORKFLOW.md) for monitoring cycle details.*
