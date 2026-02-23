# VERA-AI: Coordinated Behavior Monitoring System

A quasi-real-time monitoring workflow for detecting coordinated information operations on Facebook. This system cyclically monitors lists of known problematic actors to surface popular and potentially harmful content through automated alerting.

## Table of Contents

- [Overview](#overview)
- [Workflow](#workflow)
- [Implementation](#implementation)
- [Outputs & Analyses](#outputs--analyses)
- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
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

This system was developed as part of a research project examining deceptive information operations on Facebook. The theoretical framework integrates:

- **Strategic information operations** (Starbird et al., 2019): Understanding how malicious actors exploit platform affordances
- **Deception theory** (Chadwick & Stanyer, 2022): Analyzing communicative acts designed to mislead

The workflow has been used to detect operations including pro-Putin propaganda networks, online gambling promotion schemes, and unmoderated groups flooded with explicit content.

See [manuscripts/PAPERS.md](manuscripts/PAPERS.md) for detailed paper summaries.

### Quick Navigation

| Audience | Start Here |
|----------|------------|
| **Researchers** | [manuscripts/PAPERS.md](manuscripts/PAPERS.md) - Academic papers and theoretical framework |
| **Developers** | [R/README.md](R/README.md) - Code documentation and execution guide |
| **Policy Analysts** | [docs/WORKFLOW.md](docs/WORKFLOW.md) - Conceptual workflow explanation |
| **Data Users** | [data/README.md](data/README.md) - Dataset descriptions and data dictionary |

---

## Workflow

*Detailed documentation: [docs/WORKFLOW.md](docs/WORKFLOW.md)*

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
│   Alert Generation         │
│   • Slack notifications    │
│   • Google Sheets logging  │
│   • Network visualizations │
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

See [docs/DEFINITIONS.md](docs/DEFINITIONS.md) for terminology definitions.

---

## Implementation

*Detailed documentation: [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)*

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

- CrowdTangle API was deprecated in August 2024; system now uses Meta Content Library
- Rate limiting constraints on API queries
- GPT-4 labeling incurs API costs
- Network analysis memory requirements scale with dataset size

---

## Outputs & Analyses

*Detailed documentation: [docs/OUTPUTS.md](docs/OUTPUTS.md)*

### Datasets

| File | Description | Rows |
|------|-------------|------|
| [data/processed/community_engagement_classified.csv](data/processed/community_engagement_classified.csv) | Processed dataset with engagement metrics and LLM-derived classifications (geography, focus) | 208 |
| [data/alerts/veraai_alerts_links.csv](data/alerts/veraai_alerts_links.csv) | Original alert dataset - raw output from the monitoring workflow | 14,244 |

The classified dataset includes two LLM-derived dimensions for each detected community: **geographic region** (9 categories: North America, Latin America, Europe, Eastern Europe/Russia, Africa, South Asia, Southeast Asia, Asia-Pacific, Other/Mixed) and **operational focus** (11 categories: political movements, online gambling, news/media, entertainment, local community groups, religious, e-commerce, cryptocurrency, diaspora, pet communities, other).

![Region Distribution](analysis/figures/figure_04_region_distribution.png)

![Focus Distribution](analysis/figures/figure_05_focus_distribution.png)

![Region Focus Heatmap](analysis/figures/figure_06_region_focus_heatmap.png)

### Preliminary Analyses

The monitoring system identified **17 distinct networks** pursuing varied operational objectives:

- **Pro-Putin propaganda**: 27 coordinated groups with synchronized posting
- **Online gambling promotion**: 260 groups using AI-generated content and bot engagement
- **Unmoderated spam networks**: 222 groups exploiting poor moderation for explicit content

Key findings include:
- Coordinated posts achieving over 1 million views
- AI-generated imagery used for engagement bait
- Strategic group renaming to evade detection

See [docs/ALERTS.md](docs/ALERTS.md) for alert interpretation guidance.

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
├── .gitignore                    # Git ignore rules
│
├── docs/                         # Documentation
│   ├── WORKFLOW.md               # Conceptual workflow explanation
│   ├── IMPLEMENTATION.md         # Technical architecture details
│   ├── OUTPUTS.md                # Dataset and analysis guide
│   ├── DEFINITIONS.md            # Key terminology
│   └── ALERTS.md                 # Alert system documentation
│
├── manuscripts/                  # Academic papers
│   └── PAPERS.md                 # Related publications and references
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
├── data/                         # Data assets
│   ├── README.md                 # Data dictionary
│   ├── processed/                # Analysis-ready datasets
│   └── alerts/                   # Alert outputs
│
├── analysis/                     # Preliminary analyses
│   └── figures/                  # Visualizations
│
└── config/                       # Configuration templates
    └── config_template.R
```

---

## Citation

If using this repository, please cite:

> Giglietto, F., Marino, G., Mincigrucci, R., & Stanziano, A. (2023). A Workflow to Detect, Monitor, and Update Lists of Coordinated Social Media Accounts Across Time: The Case of the 2022 Italian Election. *Social Media + Society*, 9(3). https://doi.org/10.1177/20563051231196866

> Giglietto, F., Righetti, N., Rossi, L., & Marino, G. (2020). It takes a village to manipulate the media: coordinated link sharing behavior during 2018 and 2019 Italian elections. *Information, Communication & Society*, 23(6), 867-891.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Implementation Status

**Note:** This implementation is deprecated following the CrowdTangle API closure in August 2024.

For an active implementation of similar coordinated behavior detection methodology on TikTok, see Fabio Giglietto's project:
- **TikTok Coordinated Sharing Behavior Detection**: https://fabiogiglietto.github.io/tiktok_csbn/tt_viz.html

---

## Acknowledgments

This research was supported by [vera.ai](https://www.veraai.eu/home), a Horizon Europe project focused on tackling disinformation.
