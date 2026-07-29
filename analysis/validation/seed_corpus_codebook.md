# Codebook: topical coding of the seed fact-check corpus

**Unit of analysis.** One URL from the seed fact-check corpus — a web page
rated false by Meta's third-party fact-checking partners and used, via
coordinated sharing, to select the 1,225-account seed list.

**Redistribution limit.** The corpus derives from the Facebook
Privacy-Protected Full URLs Data Set (Messing et al. 2020); the Data Sharing
Agreement signed to obtain it forbids redistributing the URL-level rows. The
corpus and the URL-bearing coding sample therefore stay in `data/private/`
(gitignored) and are never committed or uploaded to Zenodo. Released
artefacts carry no URLs: `seed_corpus_sample_public.csv` (sample_id, year,
flags), `seed_corpus_topics.csv` (sample_id, topic) and the aggregate
profile tables. Re-coding by a second coder therefore requires DSA-covered
access to the corpus; the sample_id keys make the results directly
comparable once that access is in place.

**Why this coding exists.** The discovery loop is recursive, so the category
mix of the communities it surfaces (207 communities, 11 operational
categories) is conditional on the thematic footprint of the corpus the seed
was drawn from. The coding is designed to answer one question: *are the
non-political communities the deployment surfaced reachable from a seed whose
content was not about those topics?*

**Evidence available to the coder.** The URL string only: registered domain
plus percent-decoded path slug. The pages are 2011–2022 and overwhelmingly
dead, so content cannot be refetched. Slugs are multilingual; decode before
coding. Where domain and slug conflict, the slug wins (a news domain hosting a
celebrity story is `entertainment_celebrity`).

## Categories

| Code | Applies when the page is about |
|:--|:--|
| `politics` | Elections, parties, politicians, government action, geopolitics and war, immigration, protest, partisan ideology, election fraud claims |
| `health` | COVID-19, vaccines, treatments, miracle cures, medical and public-health claims, anti-pharma content |
| `science_climate` | Climate, environment, energy, space, technology and non-medical science claims |
| `crime_society` | Crime, courts, terrorism, accidents, disasters, social conflict, education — reported without a partisan frame |
| `religion` | Faith content, prophecy, apparitions, church affairs, spiritual claims |
| `entertainment_celebrity` | Music, film, TV, sport, celebrity and royal gossip, fan content, viral human-interest and "amazing story" content |
| `commerce_scam` | Product promotion, retail giveaways and coupon bait, "make money" schemes, crypto and financial scams, fake job ads, adult-content lures |
| `gambling` | Betting, casino, lottery, free-play codes |
| `pets_animals` | Pets, animal rescue, wildlife |
| `other` | Codeable but fits none of the above |
| `unclassifiable` | The URL carries no topical information: platform-hosted opaque IDs (YouTube, BitChute, Rumble, Odysee, Twitter/X, Facebook, Vimeo), numeric-only archive paths, hashed slugs |

## Rollup

`political_or_news` = `politics` + `crime_society`
(the two categories a fact-check-driven, news-anchored corpus is expected to
be dominated by).

`discovered_not_inherited` = `entertainment_celebrity` + `pets_animals`
(the categories that, if near-absent from the corpus, cannot have been
inherited by the discovered communities and must have been reached through
network expansion).

`content_overlap` = `commerce_scam` + `gambling`
(the honest caveat: scam, giveaway and betting content *is* fact-checked, so
e-commerce and gambling communities are partly reachable from the corpus and
their discovery is a weaker claim than for entertainment and pets).

`health` is reported separately: it is neither political nor commercial, and
its size is a direct artefact of the COVID-19 period falling inside the
corpus window.

## Decision rules for edge cases

| Scenario | Code | Rationale |
|:--|:--|:--|
| Politician's statement about COVID or vaccines | `politics` | Frame is partisan; the claim is political |
| Vaccine-injury or miracle-cure claim, no politician named | `health` | Frame is medical |
| Celebrity death hoax on a news domain | `entertainment_celebrity` | Slug wins over domain |
| Supermarket voucher / free-iPhone giveaway page | `commerce_scam` | Bait, not retail news |
| Football match-fixing or betting-tips page | `gambling` | Betting frame dominates |
| Football match report or transfer rumour | `entertainment_celebrity` | Sport is coded with entertainment |
| Miracle / apparition / prophecy story | `religion` | Even when framed as news |
| YouTube, Rumble, BitChute, Odysee, Vimeo, Twitter, Facebook link | `unclassifiable` | Path is an opaque ID; no inference from the platform itself |
| Home page or section index, no article slug | `unclassifiable` | No page-level topic |
| Slug in a script the coder cannot read | `unclassifiable` | Do not guess from the ccTLD |

## Coding procedure

Sample: `data/private/seed_corpus_sample.csv` (restricted; public
counterpart without URLs at `data/validation/seed_corpus_sample_public.csv`),
n = 1,000 drawn without
replacement from the 36,092 unique dated URLs, `set.seed(20260724)` in
`09_seed_corpus_profile.R`.

Labels were assigned by Claude (Opus 4.8) reading domain + decoded slug, one
pass, and are recorded in `data/validation/seed_corpus_topics.csv`. This
matches how the community-level `region` and `primary_focus` fields in
`data/processed/community_engagement_classified.csv` were produced. An LLM
pass is not bit-reproducible, so the labelled CSV — not the prompt — is the
reproducibility record, and is committed for human audit and re-coding.

`10_seed_corpus_topics.R` validates that every sampled id is labelled exactly
once, computes category proportions with Wilson 95% intervals, and writes the
table used in the working paper's appendix.
