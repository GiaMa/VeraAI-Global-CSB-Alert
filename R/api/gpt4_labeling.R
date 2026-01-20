# =============================================================================
# GPT-4 Network Labeling
# =============================================================================
#
# Description:
#   Uses OpenAI's GPT-4 API to automatically generate descriptive labels
#   for coordinated network clusters based on account names and characteristics.
#
# Purpose:
#   When coordination detection identifies groups of accounts, this function
#   analyzes the account names to generate human-readable labels that capture:
#   - Geographic focus (country or region)
#   - Primary language
#   - Main topic or theme
#
# Configuration:
#   Requires environment variables:
#   - OPENAI_VERAAI_API_KEY: OpenAI API key
#   - OPENAI_VERAAI_ORG_ID: OpenAI organization ID
#
# =============================================================================

#' Generate GPT-4 Labels for Coordinated Network Clusters
#'
#' Uses OpenAI's GPT-4 API to analyze account names and generate descriptive
#' English labels capturing geographic, linguistic, and thematic characteristics
#' of coordinated network clusters.
#'
#' @param df A dataframe containing coordinated link data with a
#'   `cooR.account.name` column listing account names for each cluster.
#' @param model OpenAI model to use (default: "gpt-4o"). Can also use
#'   "gpt-4", "gpt-4-turbo", or other compatible models.
#'
#' @return The input dataframe with an added `label` column containing
#'   GPT-4 generated descriptions for each row.
#'
#' @details
#' The function sends a prompt to GPT-4 asking it to identify common features
#' in the account names, focusing on country/language and topic. Labels are
#' generated with temperature=0 for consistent, reproducible results.
#'
#' API calls are rate-limited with 1-second delays between requests to avoid
#' hitting OpenAI rate limits. A progress bar displays labeling progress.
#'
#' @section Environment Variables:
#' Set these before calling the function:
#' ```r
#' Sys.setenv(OPENAI_VERAAI_API_KEY = "sk-your-api-key")
#' Sys.setenv(OPENAI_VERAAI_ORG_ID = "org-your-org-id")
#' ```
#'
#' @importFrom openai create_chat_completion
#' @importFrom utils txtProgressBar setTxtProgressBar
#'
#' @examples
#' \dontrun{
#' # Add labels to top coordinated URLs
#' top_urls <- CooRnet::get_top_coord_urls(output, top = 10)
#' labeled_urls <- get_gpt4_labels(top_urls, model = "gpt-4")
#' }

get_gpt4_labels <- function(df, model = "gpt-4o") {
  # Get API credentials from environment variables
  api_key <- Sys.getenv("OPENAI_VERAAI_API_KEY")
  org_id <- Sys.getenv("OPENAI_VERAAI_ORG_ID")
  
  if (nzchar(api_key)) {
    # Initialize an empty 'label' column in df
    df$label <- NA_character_
    # Initialize progress bar
    pb <- utils::txtProgressBar(min = 0, max = nrow(df), style = 3)
    
    for (j in seq_len(nrow(df))) {
      # Process the 'cooR.account.name' column
      text <- gsub(",", "\n", df$cooR.account.name[j], fixed = TRUE)
      text <- gsub("'", "", text, fixed = TRUE)
      text <- trimws(text)
      
      # Create message for GPT-4
      msg <- list(
        list(
          "role" = "system",
          "content" = paste(
            "As a research assistant, your task is to generate English labels for clusters of social media accounts.",
            "These labels should capture the country or, if unclear, the primary language, and the main topic of each cluster.",
            "Focus on identifying these aspects to accurately reflect their geographic, linguistic, and thematic characteristics."
          )
        ),
        list(
          "role" = "user",
          "content" = paste(
            "Based on a list of accounts in each cluster, with their titles, identify common features focusing on country/language and topic.",
            "Provide a concise English label that encapsulates these shared traits. Remember to include either country or language",
            "plus the main topic in the label. Response format: English label only.\n", 
            text
          )
        )
      )
      
      # API call to OpenAI GPT-4
      res <- tryCatch({
        openai::create_chat_completion(
          model = model,
          messages = msg,
          temperature = 0,
          # seed=1974,
          max_tokens = 256,
          openai_api_key = api_key,
          openai_organization = org_id
        )
      }, error = function(cond) {
        message("API call failed: ", cond$message)
        return(NULL)
      })
      
      # Handle API response
      if (!is.null(res) && !is.null(res$choices) && !is.null(res$choices$message.content)) {
        extracted_label <- gsub('"', '', res$choices$message.content, fixed = TRUE)
        df$label[j] <- extracted_label # Populate the 'label' column
      } else {
        df$label[j] <- "API failed!"
      }
      
      # Update progress bar
      setTxtProgressBar(pb, j)
      
      # Pause to avoid rate-limiting
      Sys.sleep(1)
    }
    
    close(pb) # Close the progress bar
    return(df) # Return the modified data frame with labels
  } else {
    stop("OpenAI API Key not found.")
  }
}
