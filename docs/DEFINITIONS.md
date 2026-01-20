# Key Definitions

This document provides definitions for terminology used throughout the VERA-AI monitoring system documentation.

## Actors & Networks

### Malicious Actors

**Operational definition**: Social media accounts (Pages or public Groups) that have:
1. Repeatedly shared URLs from fact-checked false content databases, OR
2. Exhibited coordinated behavior with accounts meeting criterion 1, OR
3. Been identified in documented Coordinated Inauthentic Behavior (CIB) takedowns

**Important caveats**:
- This is a behavioral definition based on observable patterns
- It does not attribute intent or identify real-world operators
- Accounts may be compromised or unwitting participants
- Classification may include false positives

### Coordinated Inauthentic Behavior (CIB)

**Platform definition** (Meta/Gleicher, 2018): Networks of accounts working together using fake accounts to mislead people about who they are or what they are doing.

**Research operationalization**: Groups of accounts exhibiting statistically improbable synchronization in content sharing, regardless of account authenticity.

**Key distinction**: CIB focuses on authenticity (fake vs. real accounts); our framework focuses on coordination patterns (synchronized vs. organic sharing).

### Coordinated Social Harm (CSH)

**Definition** (Meta): Networks of users who systematically violate platform policies to inflict harm, even when using authentic accounts.

**Examples**: Harassment campaigns, brigading, coordinated reporting abuse.

### Deceptive Information Operation

**Definition** (this research): Organized communicative activities on social media designed to circulate information with the intent to cause harm through deception.

**Three dimensions**:
1. **Deceptive content**: Information aimed at misleading users
2. **Platform exploitation**: Strategic use of platform affordances
3. **Participatory coordination**: Multiple accounts working together

**Relationship to disinformation**: Broader concept encompassing false content AND truthful content deployed deceptively (e.g., out of context, selectively edited).

### Information Operation

**Definition** (Starbird et al., 2019): Strategic campaigns that leverage online information flows and platform affordances to achieve objectives, often involving coordinated efforts to manipulate public opinion.

**Categories**:
- Political influence (domestic/foreign)
- Issue-based campaigns
- Lucrative/financial operations

## Coordination Types

### CLSB: Coordinated Link Sharing Behavior

**Definition**: Pattern where multiple accounts share identical URLs within a defined coordination interval (default: 60 seconds).

**Detection signal**: Statistically improbable temporal clustering of identical link shares.

**Interpretation**: Suggests automated or centrally-directed sharing rather than organic discovery.

### CMSB: Coordinated Message Sharing Behavior

**Definition**: Pattern where multiple accounts share highly similar text messages (cosine similarity ≥ 0.7) within a coordination interval.

**Detection signal**: Near-duplicate text appearing across accounts faster than organic spread would predict.

**Interpretation**: Indicates copy-paste sharing from common source or template-based content generation.

### CITSB: Coordinated Image-Text Sharing Behavior

**Definition**: Pattern where multiple accounts share posts containing identical image text (OCR-extracted) within a coordination interval.

**Detection signal**: Identical visual content (as determined by text extraction) appearing across accounts synchronously.

**Interpretation**: Suggests distribution of pre-created visual content from central source.

### Coordination Interval

**Definition**: Maximum time between two shares for them to be considered potentially coordinated.

**Default**: 60 seconds

**Rationale**: Organic content discovery and sharing typically takes longer due to reading, evaluating, and deciding to share.

### Edge Weight

**Definition**: In coordination networks, the number of times two accounts have shared the same content within the coordination interval.

**Filtering threshold**: 95th percentile (default)

**Interpretation**: Higher edge weights indicate stronger coordination signals; percentile filtering removes weak/coincidental connections.

## Metrics & Scoring

### Overperforming Score

**Source**: CrowdTangle

**Definition**: Ratio of actual engagement to expected engagement based on account's historical performance.

**Formula**: `actual_engagement / expected_engagement`

**Interpretation**: Score > 1 indicates content performing better than typical for that account.

### Comment/Share Ratio

**Definition**: Normalized ratio comparing comments to shares.

**Formula**: `(comments - shares) / (comments + shares)`

**Range**: -1 to 1
- Positive: More comments than shares
- Negative: More shares than comments
- Zero: Equal comments and shares

**Interpretation**:
- High positive values may indicate controversial/engaging content
- High negative values may indicate content optimized for sharing (potential amplification)

### Combined Metric

**Definition**: Product of overperforming score and comment/share ratio.

**Formula**: `score × comment_share_ratio`

**Purpose**: Identify content that is both overperforming AND exhibiting unusual engagement patterns.

### Red Alert Score

**Definition**: Count (0-3) of statistical anomalies for a post or link.

**Criteria checked**:
1. Total engagement outside expected range
2. Overperforming score outside expected range
3. Combined metric outside expected range

**Threshold calculation**: `median ± 1.5 × IQR` (interquartile range)

**Interpretation**:
- 0: Within normal parameters
- 1: One anomaly (minor flag)
- 2: Two anomalies (notable)
- 3: All anomalies (high priority)

## Technical Terms

### Bipartite Network

**Definition**: A graph with two types of nodes where edges only connect nodes of different types.

**In coordination detection**:
- Type 1: Accounts
- Type 2: Shared content (URLs, messages, image text)
- Edges: Account shared content

### Network Projection

**Definition**: Converting a bipartite network to a single-type network by connecting nodes that share common neighbors.

**In coordination detection**: Projects account-content network to account-account network where edge weight = number of shared content items.

### Louvain Clustering

**Definition**: Community detection algorithm that optimizes modularity to identify densely connected subgroups.

**In coordination detection**: Groups coordinated accounts into distinct networks/operations.

### Cosine Similarity

**Definition**: Measure of similarity between two vectors based on the cosine of the angle between them.

**Range**: 0 to 1 (for non-negative vectors)
- 1: Identical
- 0: Completely different

**In CMSB**: Used to compare document-term vectors of message text.

## Platform Concepts

### Facebook Page

**Definition**: Public profile for businesses, brands, organizations, or public figures.

**Monitoring relevance**: Pages have followers, post publicly, and can be tracked via CrowdTangle.

### Facebook Group

**Definition**: Shared space for members to communicate about common interests.

**Monitoring relevance**: Public groups can be tracked; may have weaker moderation than Pages.

### CrowdTangle

**Definition**: Meta's social media analytics tool providing API access to public Facebook/Instagram content.

**Status**: Deprecated August 2024; replaced by Meta Content Library.

**Relevance**: Primary data source for this monitoring system during development.

### Meta Content Library

**Definition**: Meta's researcher data access platform replacing CrowdTangle.

**Differences**:
- Different API structure
- Download limits
- Enhanced privacy protections

## Content Categories

### Engagement Bait

**Definition**: Content designed to artificially inflate engagement metrics through emotional manipulation, curiosity gaps, or direct requests for interaction.

**Examples**: "Tag a friend who...", "Comment 'yes' if you agree", incomplete stories requiring engagement to "see more"

### Brandjacking

**Definition**: Unauthorized use of known brand names/logos to imply legitimacy or affiliation.

**Example**: Gambling groups using "Orion Stars" or "Juwa" branding without official relationship.

### Clickbait

**Definition**: Content with sensationalized or misleading headlines designed to attract clicks.

**Characteristics**: Curiosity gap, emotional triggers, incomplete information requiring click-through.

### Synthetic Content

**Definition**: AI-generated or heavily manipulated media including images, text, or video.

**Detection signals**: Visual artifacts, implausible details, reverse image search failures.

---

*See [WORKFLOW.md](WORKFLOW.md) for how these concepts are applied in the monitoring system.*
