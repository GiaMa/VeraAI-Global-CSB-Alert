# =============================================================================
# CrowdTangle Links Endpoint Query Wrapper
# =============================================================================
#
# Description:
#   Robust wrapper for the CrowdTangle Links API endpoint with automatic
#   retry logic, rate limit handling, and error logging.
#
# API Documentation:
#   https://github.com/CrowdTangle/API/wiki/Links
#
# Note:
#   CrowdTangle API was deprecated in August 2024. For new projects,
#   use the Meta Content Library API instead.
#
# =============================================================================

#' Query CrowdTangle Links Endpoint
#'
#' A wrapper for the CrowdTangle API Links Endpoint with built-in retry logic
#' and error handling. Returns posts that shared a given URL.
#'
#' @param query_string A well-formed query string for the links endpoint,
#'   including the API token. Example:
#'   "https://api.crowdtangle.com/links?link=https://example.com&token=..."
#' @param sleep_time Seconds to wait between API calls and on rate limit (default: 10)
#'
#' @return A parsed JSON response as a list containing the API results,
#'   or NA if the request failed.
#'
#' @details
#' The function handles several error conditions:
#' - HTTP 200: Success - returns parsed JSON
#' - HTTP 429: Rate limit - waits and returns NA
#' - HTTP 401: Unauthorized - stops with error message
#' - Other errors: Logs to file and returns NA
#'
#' To use this function, set the CrowdTangle API key as an environment variable:
#' ```r
#' Sys.setenv(CROWDTANGLE_API_KEY = "your_api_key_here")
#' ```
#'
#' Or add to ~/.Renviron:
#' ```
#' CROWDTANGLE_API_KEY=your_api_key_here
#' ```
#'
#' @importFrom httr RETRY content http_type status_code
#' @importFrom jsonlite fromJSON
#'
#' @examples
#' \dontrun{
#' query <- paste0(
#'   "https://api.crowdtangle.com/links?",
#'   "link=", urltools::url_encode("https://example.com"),
#'   "&token=", Sys.getenv("CROWDTANGLE_API_KEY")
#' )
#' result <- query_link_endpoint(query, sleep_time = 1)
#' }

query_link_endpoint <- function(query_string, sleep_time = 10) {
  resp <- tryCatch(
    {
      httr::RETRY(verb = "GET", url = query_string, times=3, terminate_on=c(401), pause_base=sleep_time, pause_cap=10, pause_min=sleep_time)
    },
    error=function(cond) {
      print(paste(cond, "on call:", query_string))
      write(paste("\n", cond, "on call:", query_string), file = "log.txt", append = TRUE)
      return(NA)
    }
  )
  
  status <- httr::status_code(resp)
  
  tryCatch(
    {
      if (status == 200L) {
        
        if (httr::http_type(resp) != "application/json") {
          stop("API did not return json", call. = FALSE)
        }
        
        response.json <- httr::content(resp, as = "text", type="application/json", encoding = "UTF-8")
        parsed <- jsonlite::fromJSON(response.json, flatten = TRUE)
        return(parsed)
      }
      else if (status == 429L)
      {
        message("API rate limit hit, sleeping...")
        write(paste("API rate limit hit on call:", resp$url), file = "log.txt", append = TRUE)
        Sys.sleep(sleep_time)
        return(NA)
      }
      else if (status == 401L)
      {
        stop("Unauthorized, please check your API token...", call. = FALSE)
      }
      else
      {
        message(paste(resp$status, resp$url))
        write(paste("Unexpected http response code", resp$status, "on call ", resp$url), file = "log.txt", append = TRUE)
        return(NA)
      }
    },
    error=function(cond) {
      write(paste("Error:", message(cond), "on call:", resp$url), file = "log.txt", append = TRUE)
      return(NA)
    })
}