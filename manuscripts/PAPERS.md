# Academic Papers

This document summarizes the academic papers associated with the VERA-AI monitoring system and explains how they relate to the repository code and outputs.

## Paper 1: Exploring the Zombie Internet

### Citation

> [Authors]. (2025). Exploring the Zombie Internet: Anatomy of Three Deceptive Information Operations on Facebook. *Journal of Information, Communication & Ethics in Society*.

### Publication Status

- **Journal**: Journal of Information, Communication & Ethics in Society (JICES)
- **Manuscript ID**: JICES-05-2025-0109.R1
- **Status**: Revision 1 (peer review stage)
- **File**: `JICES-05-2025-0109.R1_Proof_hi.pdf`

### Abstract

This paper introduces the concept of **deceptive information operations** to capture organized communicative activities on social media designed to mislead users and cause harm. Drawing on Starbird et al.'s (2019) framework of strategic information operations and Chadwick and Stanyer's (2022) concept of deception, the paper analyzes three case studies of coordinated networks on Facebook:

1. **Pro-Putin propaganda network** (27 groups): Coordinated dissemination of anti-Ukraine and pro-Russia content
2. **Online gambling promotion** (260 groups): AI-generated content and bot engagement promoting casino websites
3. **Unmoderated groups with explicit content** (222 groups): Exploitation of weak moderation for spam and scams

### Theoretical Framework

The paper organizes analysis along three dimensions:

| Dimension | Research Question | Repository Relevance |
|-----------|------------------|---------------------|
| **Deceptive content** | How are operations deceptive? | Case study findings in paper |
| **Platform exploitation** | How are affordances exploited? | Detection methods in code |
| **Participatory behavior** | How do users participate? | Network analysis in outputs |

### Key Findings

- **Coordinated posting patterns**: Pro-Putin content posted across 10 groups within 3-minute windows
- **Synthetic engagement**: Gambling groups showed comment/reaction ratios suggesting bot activity
- **Strategic renaming**: Groups changed names 13+ times to evade detection
- **Platform evasion**: "Listening to" activity status used to mask link destinations

### Relation to Repository

| Paper Section | Code Module | Output File |
|---------------|-------------|-------------|
| §3.1: CLSB Detection | CooRnet package | `veraai_alerts_links.csv` |
| §3.2: CMSB Detection | `R/coordination_detection/detect_CMSB.R` | Network components in alerts |
| §3.3: CITSB Detection | `R/coordination_detection/detect_CITSB.R` | Network components in alerts |
| §4: Network Analysis | Louvain clustering | `community_labels.csv` |
| Figure 1: Workflow | `R/main_pipeline.R` | N/A (process diagram) |
| Figure 2: Pro-Putin posts | Manual collection | N/A (paper only) |

### Contribution to the Field

1. **Conceptual**: Introduces "deceptive information operations" as broader category than CIB
2. **Methodological**: Demonstrates Meta Content Library for research at scale
3. **Empirical**: Documents three distinct operation types with different objectives

---

## Paper 2: Scaling Coordinated Behavior Detection

### Citation

> [Authors]. (2025). Scaling Coordinated Behavior Detection. *Computational Communication Research* [manuscript submitted].

### Publication Status

- **Target Journal**: Computational Communication Research (CCR)
- **Status**: Manuscript submitted
- **File**: `Scaling Coordinated Behavior Detection_manuscript for CCR.docx`

### Abstract

This paper presents the technical methodology for scaling coordinated behavior detection through:

1. **Dynamic list expansion**: Self-reinforcing detection that grows monitoring pool
2. **Quasi-real-time alerting**: 6-hour monitoring cycles with Slack notifications
3. **Multi-modal detection**: Combining CLSB, CMSB, and CITSB methods
4. **Automated labeling**: GPT-4 integration for network characterization

### Technical Contributions

| Contribution | Implementation | Parameters |
|--------------|----------------|------------|
| Dynamic thresholds | `R/utils/get_threshold.R` | Rolling median ± 1.5×IQR |
| Coordination interval | Detection modules | 60 seconds default |
| Edge weight filtering | CooRnet integration | 95th percentile |
| Account discovery | `R/main_pipeline.R` lines 749-873 | Top 90th percentile frequency |

### Scalability Results

| Metric | Value | Repository Evidence |
|--------|-------|---------------------|
| Monitoring period | 10 months | October 2023 - August 2024 |
| Initial seed accounts | 1,225 | CrowdTangle list IDs in code |
| Discovered accounts | 2,126 | Account expansion logic |
| Coordinated links | 10,681 | `veraai_alerts_links.csv` |
| Coordinated posts | 7,068 | Alert logging |
| Distinct networks | 17 | `community_labels.csv` |

### Relation to Repository

| Paper Section | Code Module | Function |
|---------------|-------------|----------|
| §2: System Architecture | `R/main_pipeline.R` | Full pipeline orchestration |
| §3: Detection Methods | `R/coordination_detection/` | CMSB, CITSB implementations |
| §4: Threshold Calibration | `R/utils/get_threshold.R` | Dynamic threshold calculation |
| §5: Alert System | Slack/GSheets integration | Notification dispatch |
| §6: Network Expansion | Account list updating | Lines 749-873 in main |

### Contribution to the Field

1. **Technical**: Scalable architecture for continuous monitoring
2. **Operational**: Practical deployment demonstrated over 10 months
3. **Reproducible**: Open-source code and methodology

---

## Cross-Reference Table

This table maps specific paper sections to repository components:

| Paper | Section | Topic | Code Location | Output File |
|-------|---------|-------|---------------|-------------|
| JICES | §2.1 | Theoretical framework | N/A (conceptual) | N/A |
| JICES | §3 | Case studies | Case-specific analysis | Paper figures |
| JICES | §4 | Discussion | N/A (interpretation) | N/A |
| CCR | §2 | Architecture | `R/main_pipeline.R` | N/A |
| CCR | §3.1 | CLSB | CooRnet package | `veraai_alerts_links.csv` |
| CCR | §3.2 | CMSB | `R/coordination_detection/detect_CMSB.R` | Network labels |
| CCR | §3.3 | CITSB | `R/coordination_detection/detect_CITSB.R` | Network labels |
| CCR | §4 | Thresholds | `R/utils/get_threshold.R` | Summary stats sheets |
| CCR | §5 | Alerting | Slack/GSheets code | Alert logs |
| CCR | §6 | Expansion | Account updating code | `idstoadd.rds` |

## Using Papers with Repository

### For Researchers

1. **Understanding methodology**: Read CCR paper §2-3 alongside `R/main_pipeline.R`
2. **Theoretical grounding**: JICES paper provides framework for interpreting outputs
3. **Replication**: CCR paper documents parameters needed for replication

### For Developers

1. **System overview**: CCR paper Figure 1 maps to repository structure
2. **Parameter selection**: CCR paper §4 explains threshold choices
3. **Extension**: Both papers identify limitations suggesting improvement areas

### For Policy Analysts

1. **Context**: JICES paper explains why this matters for platform governance
2. **Evidence**: Case studies demonstrate real-world operation patterns
3. **Implications**: Discussion sections address policy recommendations

## BibTeX Entries

```bibtex
@article{authors2025zombie,
  title={Exploring the Zombie Internet: Anatomy of Three Deceptive Information Operations on Facebook},
  author={[Authors]},
  journal={Journal of Information, Communication \& Ethics in Society},
  year={2025},
  note={Manuscript ID: JICES-05-2025-0109.R1}
}

@article{authors2025scaling,
  title={Scaling Coordinated Behavior Detection},
  author={[Authors]},
  journal={Computational Communication Research},
  year={2025},
  note={Manuscript submitted}
}
```

## Related Publications

### CooRnet Package

> Giglietto, F., Righetti, N., Rossi, L., & Marino, G. (2020). It takes a village to manipulate the media: coordinated link sharing behavior during 2018 and 2019 Italian elections. *Information, Communication & Society*, 23(6), 867-891.

The VERA-AI system builds on the CooRnet package for CLSB detection, extending it with CMSB and CITSB capabilities.

### Foundational Theory

> Starbird, K., Arif, A., & Wilson, T. (2019). Disinformation as Collaborative Work: Surfacing the Participatory Nature of Strategic Information Operations. *Proceedings of the ACM on Human-Computer Interaction*, 3(CSCW), 1-26.

> Chadwick, A., & Stanyer, J. (2022). Deception as a bridging concept in the study of disinformation, misinformation, and misperceptions. *Communication Theory*, 32(1), 1-24.

These papers provide the theoretical framework integrated in the JICES paper.

---

*See [docs/WORKFLOW.md](../docs/WORKFLOW.md) for practical implementation details.*
*See [README.md](../README.md) for repository overview.*
