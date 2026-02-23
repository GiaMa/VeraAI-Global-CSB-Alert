# =============================================================================
# VERA-AI Alerts Validation Tests
# Section 4 of the manuscript
# =============================================================================

library(tidyverse)

# Install missing packages if needed
if (!require(dunn.test, quietly = TRUE)) {
  install.packages("dunn.test", repos = "https://cloud.r-project.org")
  library(dunn.test)
}
if (!require(fitdistrplus, quietly = TRUE)) {
  install.packages("fitdistrplus", repos = "https://cloud.r-project.org")
  library(fitdistrplus)
}

# Load data
data <- read_csv("data/processed/community_engagement_classified.csv")

cat("\n========================================\n")
cat("VERA-AI Alerts Validation Tests\n")
cat("========================================\n\n")

# -----------------------------------------------------------------------------
# 4.2 INTERNAL CONSISTENCY
# -----------------------------------------------------------------------------

cat("\n--- 4.2 INTERNAL CONSISTENCY ---\n\n")

# 4.2.1 Chi-squared test: Regional-Focus Association
cat("4.2.1 Chi-squared Test: Region × Primary Focus Association\n")
cat("------------------------------------------------------------\n")

contingency_table <- table(data$region, data$primary_focus)
chi_result <- chisq.test(contingency_table, simulate.p.value = TRUE, B = 10000)

# Cramér's V
n <- sum(contingency_table)
k <- min(nrow(contingency_table), ncol(contingency_table))
cramers_v <- sqrt(chi_result$statistic / (n * (k - 1)))

cat("Chi-squared statistic:", round(chi_result$statistic, 2), "\n")
cat("p-value:", format.pval(chi_result$p.value, digits = 3), "\n")
cat("Cramér's V:", round(cramers_v, 2), "\n")
cat("Interpretation: V < 0.1 = weak, 0.1-0.3 = medium, > 0.3 = strong\n\n")

# 4.2.2 ANOVA: Engagement Patterns by Operational Focus
cat("4.2.2 ANOVA: Engagement Patterns by Operational Focus\n")
cat("-------------------------------------------------------\n")

# Calculate engagement per account
data <- data %>%
  mutate(
    engagement_per_account = total_engagement_all / n_accounts,
    angry_ratio = (total_angry_cross_community + total_angry_exclusive) / total_engagement_all,
    love_ratio = (total_love_cross_community + total_love_exclusive) / total_engagement_all
  )

# Replace NaN/Inf with NA
data <- data %>%
  mutate(across(c(engagement_per_account, angry_ratio, love_ratio),
                ~ifelse(is.infinite(.) | is.nan(.), NA, .)))

# ANOVA for engagement levels
anova_engagement <- aov(log1p(engagement_per_account) ~ primary_focus, data = data)
anova_summary <- summary(anova_engagement)

cat("ANOVA for engagement per account (log-transformed):\n")
print(anova_summary)

# Calculate effect size (eta-squared)
ss_between <- anova_summary[[1]]["primary_focus", "Sum Sq"]
ss_total <- sum(anova_summary[[1]][, "Sum Sq"])
eta_squared <- ss_between / ss_total

cat("\nEta-squared (η²):", round(eta_squared, 3), "\n")
cat("Interpretation: η² < 0.01 = small, 0.01-0.06 = medium, > 0.14 = large\n\n")

# 4.2.3 Community Size Distribution: Log-normal Fit
cat("4.2.3 Community Size Distribution: Log-normal Fit\n")
cat("---------------------------------------------------\n")

# Fit log-normal distribution to n_accounts
size_data <- data$n_accounts[data$n_accounts > 0]
fit_lnorm <- fitdist(size_data, "lnorm")

cat("Log-normal parameters:\n")
cat("  meanlog:", round(fit_lnorm$estimate["meanlog"], 2), "\n")
cat("  sdlog:", round(fit_lnorm$estimate["sdlog"], 2), "\n")

# Goodness of fit
gof <- gofstat(fit_lnorm)
cat("\nGoodness of fit:\n")
cat("  Kolmogorov-Smirnov statistic:", round(gof$ks, 4), "\n")
cat("  Anderson-Darling statistic:", round(gof$ad, 4), "\n\n")

# -----------------------------------------------------------------------------
# 4.3 EXPANSION DYNAMICS
# -----------------------------------------------------------------------------

cat("\n--- 4.3 EXPANSION DYNAMICS ---\n\n")

cat("4.3.1 Account Expansion\n")
cat("------------------------\n")
total_accounts <- sum(data$n_accounts)
seed_accounts <- 1225  # from manuscript
expansion_factor <- total_accounts / seed_accounts

cat("Seed accounts:", seed_accounts, "\n")
cat("Total accounts discovered:", total_accounts, "\n")
cat("Expansion factor:", round(expansion_factor, 1), "x\n\n")

cat("4.3.2 Cross-Community Coordination\n")
cat("------------------------------------\n")
# Communities with cross-community URLs
data <- data %>%
  mutate(has_cross_community = n_urls_cross_community > 0)

cross_community_pct <- mean(data$has_cross_community) * 100
cat("Communities with cross-community URLs:", round(cross_community_pct, 1), "%\n\n")

# -----------------------------------------------------------------------------
# 4.4 NETWORK STRUCTURE ANALYSIS
# -----------------------------------------------------------------------------

cat("\n--- 4.4 NETWORK STRUCTURE ANALYSIS ---\n\n")

cat("4.4.1 Component Statistics\n")
cat("---------------------------\n")
n_communities <- nrow(data)
cat("Total communities detected:", n_communities, "\n\n")

cat("4.4.2 Distribution of Coordinated Shares\n")
cat("-----------------------------------------\n")
data <- data %>%
  mutate(
    share_category = case_when(
      total_coo_r_shares_all <= 10 ~ "1-10",
      total_coo_r_shares_all <= 50 ~ "11-50",
      TRUE ~ ">50"
    )
  )

share_dist <- data %>%
  count(share_category) %>%
  mutate(pct = round(n / sum(n) * 100, 1))

cat("Distribution of coordinated shares per community:\n")
print(share_dist)
cat("\n")

# -----------------------------------------------------------------------------
# 4.6 TYPOLOGICAL VALIDATION
# -----------------------------------------------------------------------------

cat("\n--- 4.6 TYPOLOGICAL VALIDATION ---\n\n")

cat("4.6.1 Kruskal-Wallis Tests\n")
cat("---------------------------\n")

# Test 1: Angry reaction ratio
kw_angry <- kruskal.test(angry_ratio ~ primary_focus, data = data)
n_groups <- length(unique(data$primary_focus[!is.na(data$angry_ratio)]))
n_obs <- sum(!is.na(data$angry_ratio))
epsilon_sq_angry <- kw_angry$statistic / (n_obs - 1)

cat("\nAngry reaction ratio by operational focus:\n")
cat("  H statistic:", round(kw_angry$statistic, 1), "\n")
cat("  df:", kw_angry$parameter, "\n")
cat("  p-value:", format.pval(kw_angry$p.value, digits = 3), "\n")
cat("  ε² (epsilon-squared):", round(epsilon_sq_angry, 2), "\n")

# Test 2: Engagement per account
kw_engagement <- kruskal.test(engagement_per_account ~ primary_focus, data = data)
n_obs_eng <- sum(!is.na(data$engagement_per_account))
epsilon_sq_eng <- kw_engagement$statistic / (n_obs_eng - 1)

cat("\nEngagement per account by operational focus:\n")
cat("  H statistic:", round(kw_engagement$statistic, 1), "\n")
cat("  df:", kw_engagement$parameter, "\n")
cat("  p-value:", format.pval(kw_engagement$p.value, digits = 3), "\n")
cat("  ε² (epsilon-squared):", round(epsilon_sq_eng, 2), "\n")

# Test 3: Cross-community URL ratio
data <- data %>%
  mutate(cross_community_ratio = n_urls_cross_community / n_urls_total)

kw_cross <- kruskal.test(cross_community_ratio ~ primary_focus, data = data)
n_obs_cross <- sum(!is.na(data$cross_community_ratio))
epsilon_sq_cross <- kw_cross$statistic / (n_obs_cross - 1)

cat("\nCross-community URL ratio by operational focus:\n")
cat("  H statistic:", round(kw_cross$statistic, 1), "\n")
cat("  df:", kw_cross$parameter, "\n")
cat("  p-value:", format.pval(kw_cross$p.value, digits = 3), "\n")
cat("  ε² (epsilon-squared):", round(epsilon_sq_cross, 2), "\n")

cat("\nEffect size interpretation: ε² < 0.01 = small, 0.01-0.06 = medium, > 0.14 = large\n")

# 4.6.2 Post-hoc Dunn's Tests
cat("\n4.6.2 Post-hoc Dunn's Tests (Bonferroni correction)\n")
cat("-----------------------------------------------------\n")

cat("\nDunn's test for Angry Ratio:\n")
dunn_angry <- dunn.test(data$angry_ratio, data$primary_focus, method = "bonferroni", kw = FALSE)

cat("\nDunn's test for Engagement per Account:\n")
dunn_engagement <- dunn.test(data$engagement_per_account, data$primary_focus, method = "bonferroni", kw = FALSE)

# -----------------------------------------------------------------------------
# SUMMARY TABLE
# -----------------------------------------------------------------------------

cat("\n\n========================================\n")
cat("VALIDATION SUMMARY (Table 2)\n")
cat("========================================\n\n")

summary_df <- data.frame(
  Validation_Type = c("Internal Consistency", "Internal Consistency", "Expansion Dynamics",
                      "Network Structure", "Typological", "Typological", "Typological"),
  Test = c("Chi-squared (Region × Focus)", "ANOVA (Engagement)", "Account Expansion",
           "Community Distribution", "KW: Angry Ratio", "KW: Engagement", "KW: Cross-community"),
  Statistic = c(
    paste0("χ² = ", round(chi_result$statistic, 1)),
    paste0("F = ", round(anova_summary[[1]]["primary_focus", "F value"], 2)),
    paste0(round(expansion_factor, 1), "x expansion"),
    paste0(n_communities, " communities"),
    paste0("H = ", round(kw_angry$statistic, 1)),
    paste0("H = ", round(kw_engagement$statistic, 1)),
    paste0("H = ", round(kw_cross$statistic, 1))
  ),
  P_value = c(
    format.pval(chi_result$p.value, digits = 3),
    format.pval(anova_summary[[1]]["primary_focus", "Pr(>F)"], digits = 3),
    "N/A",
    "N/A",
    format.pval(kw_angry$p.value, digits = 3),
    format.pval(kw_engagement$p.value, digits = 3),
    format.pval(kw_cross$p.value, digits = 3)
  ),
  Effect_Size = c(
    paste0("V = ", round(cramers_v, 2)),
    paste0("η² = ", round(eta_squared, 2)),
    "N/A",
    "Log-normal fit",
    paste0("ε² = ", round(epsilon_sq_angry, 2)),
    paste0("ε² = ", round(epsilon_sq_eng, 2)),
    paste0("ε² = ", round(epsilon_sq_cross, 2))
  )
)

print(summary_df, row.names = FALSE)

cat("\n\nValidation tests completed.\n")
cat("Results can be used to update Section 4 of the manuscript.\n")
