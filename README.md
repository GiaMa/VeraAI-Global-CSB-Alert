# VERA-AI: Coordinated Behavior Monitoring System

[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.21225024-blue)](https://doi.org/10.5281/zenodo.21225024)

> [!WARNING]
> **Deprecated:** This implementation relies on the CrowdTangle API, which was shut down in August 2024. The pipeline is no longer operational in its original form. For an active implementation of similar methodology on TikTok, see: https://fabiogiglietto.github.io/tiktok_csbn/tt_viz.html

A quasi-real-time monitoring workflow for detecting coordinated information operations on Facebook. This system cyclically monitors lists of known problematic actors to surface popular and potentially harmful content through automated alerting.

## Table of Contents

- [Overview](#overview)
- [Workflow](#workflow)
- [Implementation](#implementation)
- [Outputs & Analyses](#outputs--analyses)
- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
- [Reproducing the working paper's results](#reproducing-the-working-papers-results)
- [Citation](#citation)
- [License](#license)

---

## Overview

### What This Repository Contains

This repository documents the VERA-AI monitoring system, which:

- **Monitors** curated lists of Facebook accounts previously identified as spreading problematic content
- **Detects** three types of coordinated behavior: link sharing (CLSB), message sharing (CMSB), and image-text sharing (CITSB)
- **Alerts** researchers in quasi-real-time via Slack notifications and Google Sheets logging
- **Expands** monitoring dynamically by identifying new coordinated accounts
- **Outputs** datasets documenting detected coordination patterns and network structures

### Research Context

This system was developed as part of vera.ai (https://www.veraai.eu/), a Horizon Europe research project developing AI tools for fighting disinformation online. It implements a persistent, automated CSB monitoring system as advocated by Schroeder et al. (2026) for detecting, for example, AI-powered coordinated networks, which adapt their behaviour in real time and render retrospective detection insufficient. The workflow has been used to detect multiple types of deceptive information operations including pro-Putin propaganda networks, online gambling promotion schemes, and unmoderated groups flooded with explicit content.

### Quick Navigation

| Audience | Start Here |
|----------|------------|
| **Developers** | [R/README.md](R/README.md) - Code documentation and execution guide |
| **Data Users** | [data/README.md](data/README.md) - Dataset descriptions and data dictionary |
| **Researchers** | [Reproducing the working paper's results](#reproducing-the-working-papers-results) - Scripts behind every numeric claim |

---

## Workflow

### Monitoring Logic

The system operates through a cyclical 9-step workflow with three interconnected subsystems:

1. **Post Monitoring & Alerting**: Periodic collection of content from monitored accounts, identifying posts with unusual engagement patterns
2. **Coordination Detection**: Analysis of link, text, and image similarities to detect synchronized sharing behavior
3. **List Updating**: Dynamic expansion of monitored accounts based on newly discovered coordinated actors

### Data Flow

```
Seed Lists (known problematic accounts)
         │
         ▼
┌─────────────────────────────┐
│   CrowdTangle API Queries   │
│   (6-hour monitoring cycle) │
└─────────────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│   Coordination Detection    │
│   • CLSB (link sharing)     │
│   • CMSB (message sharing)  │
│   • CITSB (image-text)      │
└─────────────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│   Alert Generation          │
│   • Slack notifications     │
│   • Google Sheets logging   │
│   • Network visualizations  │
└─────────────────────────────┘
         │
         ▼
   New coordinated accounts
   added to monitoring pool
```

### Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Monitoring window | 6 hours | Time frame for content collection |
| Coordination interval | 60 seconds | Maximum time between posts to be considered coordinated |
| Edge weight percentile | 95th | Threshold for identifying highly coordinated accounts |
| Minimum interactions | Dynamic | Calculated based on historical engagement patterns |

---

## Implementation

### System Architecture

| Component | Script | Function |
|-----------|--------|----------|
| Orchestration | [R/main_pipeline.R](R/main_pipeline.R) | Main entry point; coordinates all subsystems |
| CLSB Detection | CooRnet package | Coordinated Link Sharing Behavior detection |
| CMSB Detection | [R/coordination_detection/detect_CMSB.R](R/coordination_detection/detect_CMSB.R) | Coordinated Message Sharing Behavior |
| CITSB Detection | [R/coordination_detection/detect_CITSB.R](R/coordination_detection/detect_CITSB.R) | Coordinated Image-Text Sharing Behavior |
| API Queries | [R/api/crowdtangle_query.R](R/api/crowdtangle_query.R) | CrowdTangle API wrapper with rate limiting |
| Network Labeling | [R/api/gpt4_labeling.R](R/api/gpt4_labeling.R) | GPT-4 integration for cluster descriptions |
| Threshold Calculation | [R/utils/get_threshold.R](R/utils/get_threshold.R) | Dynamic engagement threshold computation |
| URL Processing | [R/utils/clean_urls.R](R/utils/clean_urls.R) | URL sanitization and normalization |

### External Dependencies

- **CrowdTangle API** (deprecated August 2024): Facebook data access
- **Meta Content Library**: Current data access method
- **OpenAI GPT-4 API**: Automated network labeling
- **Google Sheets/Drive**: Alert logging and visualization storage
- **Slack API**: Real-time notifications

### Known Limitations

- CrowdTangle API was deprecated in August 2024
- Rate limiting constraints on API queries
- GPT-4 labeling incurs API costs
- Network analysis memory requirements scale with dataset size

---

## Outputs & Analyses

### Datasets

| File | Description | Rows |
|------|-------------|------|
| [data/processed/community_engagement_classified.csv](data/processed/community_engagement_classified.csv) | Processed dataset with engagement metrics and LLM-derived classifications (geography, focus) | 208 |
| [data/alerts/veraai_alerts_links.csv](data/alerts/veraai_alerts_links.csv) | Original alert dataset - raw output from the monitoring workflow | 14,244 |

The classified dataset includes two LLM-derived dimensions for each detected community: **geographic region** (9 categories: North America, Latin America, Europe, Eastern Europe/Russia, Africa, South Asia, Southeast Asia, Asia-Pacific, Other/Mixed) and **operational focus** (11 categories: political movements, online gambling, news/media, entertainment, local community groups, religious, e-commerce, cryptocurrency, diaspora, pet communities, other).

---

## Getting Started

### Prerequisites

- R version 4.0+
- Required packages: `httr`, `jsonlite`, `quanteda`, `igraph`, `CooRnet`, `tidytable`, `dplyr`, `slackr`, `googlesheets4`, `googledrive`
- API credentials: CrowdTangle/Meta Content Library, OpenAI, Google Service Account, Slack

### Installation

```r
# Install required packages
install.packages(c(
  "httr", "jsonlite", "quanteda", "igraph", "tidytable",
  "dplyr", "slackr", "googlesheets4", "googledrive",
  "urltools", "lubridate", "stringr", "digest"
))

# Install CooRnet from GitHub
devtools::install_github("fabiogiglietto/CooRnet")
```

### Configuration

1. Copy `config/config_template.R` to `config/config.R`
2. Add your API credentials (file is git-ignored)
3. Update the `source()` paths in `R/main_pipeline.R` to match your directory structure

### Running the Pipeline

```r
# Set working directory
setwd("path/to/vera-ai-monitoring")

# Source configuration
source("config/config.R")

# Run the main pipeline
source("R/main_pipeline.R")
```

For scheduled execution, configure a cron job to run the pipeline every 6 hours.

---

## Repository Structure

```
vera-ai-monitoring/
├── README.md                     # This file
├── CITATION.cff                  # Software citation metadata
├── renv.lock                     # Pinned R package versions (renv)
├── .gitignore                    # Git ignore rules
│
├── R/                            # Analysis code
│   ├── main_pipeline.R           # Main orchestration script
│   ├── README.md                 # Code documentation
│   ├── coordination_detection/   # Detection modules
│   │   ├── detect_CMSB.R
│   │   ├── detect_CITSB.R
│   │   └── README.md
│   ├── api/                      # External service wrappers
│   │   ├── crowdtangle_query.R
│   │   └── gpt4_labeling.R
│   └── utils/                    # Utility functions
│       ├── clean_urls.R
│       └── get_threshold.R
│
├── analysis/                     # Working-paper analyses
│   ├── validation/               # Scripts reproducing every numeric claim
│   └── figures/                  # Paper figures (PDF)
│
├── data/                         # Data assets
│   ├── README.md                 # Data dictionary
│   ├── processed/                # Analysis-ready datasets
│   ├── alerts/                   # Alert outputs
│   └── validation/               # Validation outputs (CSV + RDS permutation draws)
│
└── config/                       # Configuration templates
    └── config_template.R
```

---

## Reproducing the working paper's results

This repository is the companion to the working paper:

> Giglietto, F., Marino, G., Chakraborty, A., & Righetti, N. (2026). *Ten
> months of continuous coordinated-behaviour monitoring on Facebook: the
> VERA-AI Alert system, its empirical yield, and what retrospective case
> studies miss.* SocArXiv working paper. (OSF DOI to be added on publication;
> Zenodo archive of this repository: <https://doi.org/10.5281/zenodo.21225024> (all versions).)

Every numeric claim in the paper traces to a script under
`analysis/validation/` (seeds recorded in each script) reading the data in
`data/`:

| Paper claim | Value | Script |
|---|---|---|
| Graph construction (14,832 discovered accounts; 8,618 URLs) | `data/validation/graph_summary.csv` | `analysis/validation/00_build_graphs.R` |
| Expansion dynamics; monthly promotion rate mean 11.1%, CV 0.10 | `expansion_dynamics.csv` | `01_expansion_dynamics.R` |
| Bipartite null model (modularity 0.668 vs 0.067; p ≤ 0.001 on all 5 metrics — 4 in the expected direction, largest component in the lower tail; 1,000 Curveball permutations) | `null_model_pvalues.csv` | `02_null_model_bipartite.R` + `curveball.cpp` |
| Temporal (weekly-stratified) null | `null_model_temporal.csv` | `03_null_model_temporal.R` |
| Threshold sensitivity (1,602 promoted at 90th pct of 14,832) | `threshold_sensitivity.csv` | `04_threshold_sensitivity.R` |
| Rogers & Righetti strict replication (631 nodes / 9,732 edges / 19 communities → 15 catalogue communities) | `rr_strict_replication.csv`, `rr_strict_communities.csv` | `05_rr_strict_replication.R` |
| Engagement signatures (KW ε² 0.12–0.15; cosine permutation p ≤ 0.001, N = 204) | `engagement_signature.csv` | `06_engagement_signature.R` |
| All figures | `analysis/figures/*.pdf` | `07_figures.R` |
| Account-list repair of the community dataset | in-place fix of `community_engagement_classified.csv` | `08_repair_account_lists.R` |

Dependencies: R ≥ 4.5 with `data.table`, `igraph`, `tidytable`, `ggplot2`
(plus a C++ compiler for the Curveball permutation kernel via `Rcpp`).
Typical runtimes: null models ~50 and ~27 minutes on 2 cores; everything
else under a minute. Live-pipeline dependencies (CrowdTangle, Slack,
Google, OpenAI APIs) are **not** required to reproduce the analyses.

**Data policy.** `data/processed/community_engagement_classified.csv`
(207 communities, aggregate) and `data/alerts/veraai_alerts_links.csv`
(10,681 URL-level alert records) are included. The account-level watched
list and the live discovery queue are not shared; the paper documents the
schema and the promotion rule so the pipeline can be re-deployed on other
data.

---

## Citation

To cite the system and its empirical yield, cite the working paper above
(see also [CITATION.cff](CITATION.cff)). The upstream detection methodology:

> Giglietto, F., Marino, G., Mincigrucci, R., & Stanziano, A. (2023). A Workflow to Detect, Monitor, and Update Lists of Coordinated Social Media Accounts Across Time: The Case of the 2022 Italian Election. *Social Media + Society*, 9(3). https://doi.org/10.1177/20563051231196866

> Giglietto, F., Righetti, N., Rossi, L., & Marino, G. (2020). It takes a village to manipulate the media: coordinated link sharing behavior during 2018 and 2019 Italian elections. *Information, Communication & Society*, 23(6), 867-891.

> Schroeder, D. T., Cha, M., Baronchelli, A., Bostrom, N., Christakis, N. A., Garcia, D., Goldenberg, A., Kyrychenko, Y., Leyton-Brown, K., Lutz, N., Marcus, G., Menczer, F., Pennycook, G., Rand, D. G., Ressa, M., Schweitzer, F., Song, D., Summerfield, C., Tang, A., … Kunst, J. R. (2026). How malicious AI swarms can threaten democracy. *Science (New York, N.Y.)*, 391(6783), 354–357. https://doi.org/10.1126/science.adz1697

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

This research was supported by [vera.ai](https://www.veraai.eu/home) (VERification Assisted by Artificial Intelligence), co-funded by the European Commission under Horizon Europe grant agreement ID 101070093, and by the UK and Swiss authorities.

This repository reflects the views of the authors only. The European Commission cannot be held responsible for any use which may be made of the information contained herein.
