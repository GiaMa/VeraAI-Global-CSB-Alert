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

| Dataset | Location | Rows | Cols | Size | Description |
|---------|----------|------|------|------|-------------|
| Community Engagement | `processed/community_engagement_classified.csv` | 207 | 33 | 1.1 MB | Community-level engagement rollups with LLM classifications, plus the member account list per community |
| Alert Links | `alerts/veraai_alerts_links.csv` | 10,681 | 23 | 24 MB | Raw alert log, one row per URL-level coordination alert |

> **Note on row counts.** `wc -l` reports 14,244 for
> `veraai_alerts_links.csv`, but the file holds only **10,681 records** — the
> `account_name`, `coo_r_account_name` and `coord_network_label` fields contain
> embedded newlines. (The file also has no trailing newline, so its true line
> count is 14,245.) Count rows with a real CSV parser — `readr::read_csv`,
> `data.table::fread`, `pandas.read_csv` — never with `wc -l`.

---

## Data Dictionary

### community_engagement_classified.csv

**Description**: Processed dataset with comprehensive engagement metrics aggregated at the community level. Includes reaction breakdowns, cross-community sharing patterns, and derived classification fields. The geographical origin (`region`) and primary content focus (`primary_focus`) classifications were generated using Claude LLM to analyze the network labels and account names.

**Primary key**: `source_community` (207 unique values)

Every `total_*` and `n_urls_*` metric is split three ways by where the URL
travelled: `_cross_community` (also shared by at least one other community),
`_exclusive` (shared only inside this community), and `_all` (the two combined).

**Identification and classification**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `source_community` | integer | Community identifier from the Louvain partition. Not contiguous — IDs run to 100+ | `100` |
| `label` | string | LLM-generated description of the community | `"Online casino freeplay groups featuring Juwa, Orion Stars, Fire Kirin"` |
| `region` | string | Geographic classification (LLM). One of: Latin America, Europe, Southeast Asia, Other/Mixed, North America, Africa, Eastern Europe/Russia, South Asia, Asia-Pacific | `"North America"` |
| `primary_focus` | string | Content category (LLM). One of 11 values — see `data/validation/seed_community_overlap_by_cat.csv` for the full set | `"Online gambling/betting"` |
| `n_accounts` | integer | Member accounts in this community. Sums to 14,832 across the file | `795` |

**URL counts**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `n_urls_cross_community` | integer | URLs this community shared that other communities also shared | `40` |
| `n_urls_exclusive` | integer | URLs shared only within this community | `610` |
| `n_urls_total` | integer | `n_urls_cross_community + n_urls_exclusive` | `650` |

**Coordinated share counts**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `total_coo_r_shares_cross_community` | integer | Coordinated share events on cross-community URLs | `2026` |
| `total_coo_r_shares_exclusive` | integer | Coordinated share events on exclusive URLs | `9159` |
| `total_coo_r_shares_all` | integer | Both combined | `11185` |

**Engagement and reactions**

Each of the following exists in three variants — `_cross_community`,
`_exclusive`, and (for `engagement` only) `_all`:

| Column stem | Type | Description | Example (`_cross_community`) |
|--------|------|-------------|---------|
| `total_engagement_*` | integer | All reactions + comments + shares. `_all` variant present | `59669` |
| `total_likes_*` | integer | Like reactions | `34949` |
| `total_shares_*` | integer | Share count | `21` |
| `total_comments_*` | integer | Comment count | `24464` |
| `total_love_*` | integer | Love reactions | `24` |
| `total_wow_*` | integer | Wow reactions | `12` |
| `total_haha_*` | integer | Haha reactions | `193` |
| `total_sad_*` | integer | Sad reactions | `1` |
| `total_angry_*` | integer | Angry reactions | `5` |

> There are no `thankful` or `care` columns in this file, despite those
> reactions existing on the platform.

**Derived and member list**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `pct_cross_community_urls` | numeric | `100 * n_urls_cross_community / n_urls_total`, rounded to 2 dp. Already a percentage, not a proportion. Set to `0` (not `NaN`) in the three communities that have no URLs | `6.15` |
| `account_urls` | string | **Semicolon-separated** Facebook URLs of every member account. Authoritative: the split length equals `n_accounts` in all 207 rows | `"facebook.com/groups/1247341452360704; ..."` |
| `account_names` | string | **Semicolon-separated** display names. See the alignment warning below — do **not** assume these line up with `account_urls` | `"😂SENSATION TV😂; Slots games; ..."` |

> **`account_urls` and `account_names` are account-level, not aggregate.**
> Together they enumerate the 14,832 discovered accounts — 14,207 public Groups,
> 623 Pages by numeric ID, 2 vanity handles, no personal profiles. Repaired by
> `analysis/validation/08_repair_account_lists.R`, which restored lists
> truncated in the original export.

> ⚠️ **The two lists are not reliably positionally aligned.** Splitting
> `account_urls` on `;` yields exactly `n_accounts` entries in every row.
> Splitting `account_names` yields 15,536 entries against 14,832 URLs, because
> **9 of the 207 rows contain display names that themselves include a
> semicolon**, which over-splits those rows. Zipping the two lists is safe only
> for the 198 rows where `lengths()` agree. Use `account_urls` as the account
> key; treat `account_names` as display text.

**Interpreting cross-community share**:

| `pct_cross_community_urls` | Interpretation |
|-------|---------------|
| > 50 | Network-wide amplification strategy |
| 20–50 | Mixed strategy |
| < 20 | Isolated community operation |

---

### veraai_alerts_links.csv

**Description**: Original dataset retrieved directly from the alert system. This is the raw output of the monitoring workflow, containing a comprehensive log of all coordinated link sharing alerts. Each row represents a URL flagged for coordinated sharing behavior.

**Primary key**: none single-column. Use the composite **(`url`, `alert_date`)**,
which is unique across all 10,681 rows. `alert_id` is *not* usable as a key —
it is empty in 4,619 rows (43%). The same `url` recurs across alert cycles:
8,618 distinct URLs over 10,681 alerts.

**Coverage**: 2023-10-09 to 2024-08-14.

**The URL and its reach**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `url` | string | The shared URL flagged for coordinated sharing, cleaned by `R/utils/clean_urls.R` (tracking parameters stripped). Often a `facebook.com` permalink rather than an external article | `"https://facebook.com/100075701667479"` |
| `shares` | integer | Total shares of this URL across all monitored accounts | `375` |
| `coo_r_shares` | integer | Of those, shares that met the coordination criterion (same URL within the 60-second window) | `362` |
| `engagement` | integer | All reactions + comments + shares | `1136` |

**Reaction breakdown**

All from CrowdTangle's `statistics.actual` block, summed across posts sharing this URL.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `statistics_actual_like_count` | integer | Like reactions | `332` |
| `statistics_actual_share_count` | integer | Shares (post statistics) | `2` |
| `statistics_actual_comment_count` | integer | Comments | `786` |
| `statistics_actual_love_count` | integer | Love reactions | `11` |
| `statistics_actual_wow_count` | integer | Wow reactions | `1` |
| `statistics_actual_haha_count` | integer | Haha reactions | `4` |
| `statistics_actual_sad_count` | integer | Sad reactions | `0` |
| `statistics_actual_angry_count` | integer | Angry reactions | `0` |

> There are no `thankful` or `care` columns in this file.

**Accounts**

All four fields are **comma-separated lists**, not single values. `account_*` is
the full set of accounts that posted the URL; `coo_r_account_*` is the subset
that did so coordinatedly (a strict subset — see
`analysis/validation/01_expansion_dynamics.R`). URLs and names are positionally
aligned within each field.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `account_url` | string | Facebook URLs of every account that posted this URL | `"https://www.facebook.com/groups/849767388883247,https://..."` |
| `coo_r_account_url` | string | URLs of the coordinating subset | `"https://www.facebook.com/groups/2890792931027355,https://..."` |
| `account_name` | string | Display names of the posting accounts. Values are individually double-quoted inside the field and **may contain embedded newlines** | `"""Hon Dr Musa Iliyasu Kwankwaso Support Group - AIWSG"",""..."""` |
| `coo_r_account_name` | string | Display names of the coordinating subset | `"""Portable Fans Group"",""Les Amis de Princesse Betu Majaabu Gospel"""` |

> Across the file these resolve to 20,450 distinct Facebook accounts — 19,207
> public Groups, 1,241 Pages by numeric ID, 2 vanity handles. No `profile.php`
> URLs are present; CrowdTangle indexed public Pages, public Groups and
> public-figure profiles only.

**Network position**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `components` | string | Connected component ID(s). **Comma-separated list, must be read as text** — 226 rows carry more than one | `"3"` |
| `clusters` | string | Louvain cluster ID(s) within the component. Comma-separated; 2,133 rows carry more than one | `"3,14,15"` |
| `coord_network_label` | string | GPT-4 description of the coordinated network(s). Where a row spans several clusters this is a **numbered multi-line list, containing literal newlines** | `"1. French Gospel Music Enthusiasts\n2. French Comedy Lovers..."` |

> ⚠️ **`components` and `clusters` are silently corrupted by type guessing.**
> `readr::read_csv()` infers them as numeric and reads `"3,14,15"` as the number
> **31415**, treating the commas as thousands separators — no warning, no `NA`.
> This mangles 2,133 rows of `clusters` and 226 of `components`. Always force
> the type:
>
> ```r
> alerts <- read_csv(
>   "data/alerts/veraai_alerts_links.csv",
>   col_types = cols(components = col_character(), clusters = col_character())
> )
> ```
>
> `data.table::fread()` and `pandas.read_csv()` read them as text correctly.

**Scoring and identifiers**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `comments_shares_metric` | numeric | Normalised comment-vs-share balance: `(comments - shares) / (comments + shares)`. Ranges **-1 to 1**, not 0 to 1. `+1` = comments only, `-1` = shares only. `NA` in 31 rows where both counts are zero | `0.9949238579` |
| `redalert_score` | integer | Engagement-anomaly score. **`NA` in 830 rows** | `0` |
| `alert_id` | string | SHA-256 of `postUrl \| date \| account.name`, 64 hex chars. **Empty in 4,619 rows**; 6,030 distinct values among the rest | `"e0e4f22c193cdaa0..."` |
| `alert_date` | POSIXct | Alert generation timestamp | `"2024-04-30 18:06:45"` |

**Red alert score interpretation**:

Documented as 0–3, but **only 0, 1 and 2 occur** in this dataset. Distribution:

| Score | Meaning | Rows | Recommended Action |
|-------|---------|------|-------------------|
| 0 | Within normal parameters | 6,201 | Routine monitoring |
| 1 | One statistical anomaly | 2,871 | Review if patterns emerge |
| 2 | Two anomalies | 779 | Prioritize for manual review |
| 3 | All anomalies present | 0 | Immediate attention |
| `NA` | Not scored | 830 | — |

**Filtering recommendations**:

```r
library(dplyr)

# High-priority alerts — filter() drops the 830 NA rows; make that explicit
alerts %>% filter(!is.na(redalert_score), redalert_score >= 2)

# Significant coordination
alerts %>% filter(coo_r_shares >= 50)

# High-reach content
alerts %>% filter(engagement >= 10000)

# Strong coordination signal
alerts %>% filter(coo_r_shares / shares > 0.5)

# Explode the account lists to one row per (URL, account)
alerts %>%
  tidyr::separate_rows(coo_r_account_url, sep = ",") %>%
  mutate(coo_r_account_url = trimws(coo_r_account_url))
```

---

## Loading Data

### R

The repository ships two datasets. `facebook_network_nodes.csv` and
`community_labels.csv` referenced by earlier versions of this file are no
longer distributed — the node list is now carried by the `account_urls` /
`account_names` columns of `community_engagement_classified.csv`, and the
labels by its `label` column.

### R

```r
library(tidyverse)

engagement <- read_csv("data/processed/community_engagement_classified.csv",
                       show_col_types = FALSE)

# Force the list-valued columns to text — see the warning above
alerts <- read_csv(
  "data/alerts/veraai_alerts_links.csv",
  col_types = cols(components = col_character(), clusters = col_character())
)

# Rebuild the node table from account_urls, the authoritative member list.
# Do not zip in account_names: it over-splits in 9 of 207 rows.
nodes <- engagement %>%
  select(source_community, label, region, primary_focus, account_urls) %>%
  separate_rows(account_urls, sep = ";") %>%
  mutate(id = trimws(account_urls), .keep = "unused")

nrow(nodes)              # 14832
n_distinct(nodes$id)     # 14832

# One row per (URL, coordinating account)
edges <- alerts %>%
  select(url, coo_r_account_url, alert_date) %>%
  separate_rows(coo_r_account_url, sep = ",") %>%
  mutate(coo_r_account_url = trimws(coo_r_account_url))
```

### Python

```python
import pandas as pd

engagement = pd.read_csv("data/processed/community_engagement_classified.csv")
alerts = pd.read_csv(
    "data/alerts/veraai_alerts_links.csv",
    dtype={"components": "string", "clusters": "string"},
)

nodes = (
    engagement
    .assign(id=lambda d: d["account_urls"].str.split(";"))
    .explode("id")
    .assign(id=lambda d: d["id"].str.strip())
    .loc[:, ["source_community", "label", "region", "primary_focus", "id"]]
)

len(nodes)              # 14832
nodes["id"].nunique()   # 14832
```

Both files must be read with a real CSV parser: the alert file's name and label
fields contain embedded newlines and quoted commas.

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
