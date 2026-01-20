# =============================================================================
# URL Cleaning and Normalization
# =============================================================================
#
# Description:
#   Sanitizes and normalizes URLs to improve coordination detection accuracy.
#   Removes tracking parameters, normalizes URL formats, and filters out
#   platform-specific URLs that shouldn't be included in analysis.
#
# Purpose:
#   Different sharing tools add tracking parameters (utm_*, fbclid, etc.)
#   that make identical URLs appear different. This function removes these
#   parameters to properly identify when the same content is being shared.
#
# =============================================================================

#' Clean and Normalize URLs
#'
#' Sanitizes URLs by removing tracking parameters, normalizing formats,
#' and filtering out platform-specific URLs that shouldn't be analyzed.
#'
#' @param df A dataframe containing URLs to clean
#' @param url The name of the column containing URLs (as a string)
#'
#' @return The input dataframe with cleaned URLs in the specified column.
#'   Rows with invalid or filtered URLs are removed.
#'
#' @details
#' The function performs the following operations:
#'
#' **Parameter Removal:**
#' - UTM tracking parameters (utm_source, utm_medium, etc.)
#' - Facebook tracking (fbclid, fb_rel)
#' - Social sharing parameters (social, sr_share_)
#' - RSS and feed parameters
#' - Other common tracking parameters
#'
#' **URL Normalization:**
#' - Removes trailing slashes
#' - Decodes URL-encoded characters
#' - Normalizes YouTube URLs (m.youtube.com → www.youtube.com, youtu.be → full URL)
#'
#' **Filtered URLs (removed from output):**
#' - Platform root URLs (facebook.com/, youtube.com/, etc.)
#' - WhatsApp share links
#' - Login redirect URLs
#' - Localhost URLs
#'
#' @importFrom stringr str_replace
#' @importFrom urltools url_decode
#'
#' @examples
#' \dontrun{
#' posts <- data.frame(
#'   expanded = c(
#'     "https://example.com/article?utm_source=facebook",
#'     "https://youtu.be/abc123"
#'   )
#' )
#' cleaned <- clean_urls(posts, "expanded")
#' }

clean_urls <- function(df, url) {
  
  df <- df[!grepl("\\.\\.\\.$", df[[url]]),]
  df <- df[!grepl("/url?sa=t&source=web", df[[url]], fixed=TRUE),]
  
  paramters_to_clean <- paste("\\?utm_.*",
                              "feed_id.*",
                              "&_unique_id.*",
                              "\\?#.*",
                              "\\?ref.*",
                              "\\?fbclid.*",
                              "\\?rss.*",
                              "\\?ico.*",
                              "\\?recruiter.*",
                              "\\?sr_share_.*",
                              "\\?fb_rel.*",
                              "\\?social.*",
                              "\\?intcmp_.*",
                              "\\?xrs.*",
                              "\\?CMP.*",
                              "\\?tid.*",
                              "\\?ncid.*",
                              "&utm_.*",
                              "\\?rbs&utm_hp_ref.*",
                              "/#\\..*",
                              "\\?mobile.*",
                              "&fbclid.*",
                              ")",
                              "/$",
                              sep = "|")
  
  df[[url]] <- gsub(paramters_to_clean, "", df[[url]])
  df[[url]] <- gsub(paramters_to_clean, "", df[[url]])
  df[[url]] <- gsub(paramters_to_clean, "", df[[url]])
  
  df[[url]] <- gsub(".*(http)", "\\1", df[[url]]) # delete all before "http"
  df[[url]] <- gsub("\\/$", "", df[[url]]) # delete remaining trailing slash
  df[[url]] <- gsub("\\&$", "", df[[url]]) # delete remaining trailing &
  
  filter_urls <- c("^http://127.0.0.1", "^https://www.youtube.com/watch$", "^https://www.youtube.com/$", "^http://www.youtube.com/$",
                   "^https://youtu.be$", "^https://m.youtube.com$", "^https://m.facebook.com/story",
                   "^https://m.facebook.com/$", "^https://www.facebook.com/$", "^https://chat.whatsapp.com$",
                   "^http://chat.whatsapp.com$", "^http://wa.me$", "^https://wa.me$", "^https://api.whatsapp.com/send$",
                   "^https://api.whatsapp.com/$", "^https://play.google.com/store/apps/details$", "^https://www.twitter.com/$", "^https://www.twitter.com$",
                   "^https://instagram.com/accounts/login", "^https://www.instagram.com/accounts/login", "^https://t.me/joinchat$")
  
  df <- df[!grepl(paste(filter_urls, collapse = "|"), df[[url]]), ]
  
  df[[url]] <- urltools::url_decode(stringr::str_replace(df[[url]], 'https://www.facebook.com/login/?next=', ''))
  df <- df[grepl("http://|https://", df[[url]]),] # remove all the entries with the url that does not start with "http"
  
  df[[url]] <- stringr::str_replace(df[[url]], 'm.youtube.com', 'www.youtube.com')
  df[[url]] <- stringr::str_replace(df[[url]], 'youtu.be/', 'www.youtube.com/watch?v=')
  df[[url]] <- stringr::str_replace(df[[url]], '^(.*youtube\\.com/watch\\?).*(v=[^\\&]*).*', '\\1\\2') # cleanup YouTube URLs
  
  return(df)
}