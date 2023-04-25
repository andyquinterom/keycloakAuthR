#' @export
fetch_keycloak_access_token <- function(code, redirect_uri, config) {
  resp <- config$request_token(code, redirect_uri)
  keycloak_access_token$new(
    resp$access_token,
    config,
    refresh_token = resp$refresh_token
  )
}

#' @export
empty_keycloak_access_token <- R6::R6Class(
  classname = "empty_keycloak_access_token",
  public = list(
    is_valid = function() {
      FALSE
    },
    get_bearer = function() {
      NULL
    },
    get_access_token = function() {
      NULL
    },
    get_refresh_token = function() {
      NULL
    },
    get_realm_roles = function() {
      list()
    },
    get_resource_roles = function(resource) {
      list()
    },
    has_realm_role = function(role) {
      FALSE
    },
    has_resource_role = function(resource, role) {
      FALSE
    },
    expires_in = function() {
      -1
    },
    expires_at = function() {
      Sys.time() - 1
    },
    is_expired = function() {
      TRUE
    },
    get_preferred_username = function() {
      "Anonymous"
    },
    get_email = function() {
      ""
    },
    get_name = function() {
      ""
    },
    get_given_name = function() {
      ""
    },
    get_family_name = function() {
      ""
    },
    is_email_verified = function() {
      FALSE
    }
  )
)

#' @export
keycloak_access_token <- R6::R6Class(
  classname = "keycloak_access_token",
  public = list(
    initialize = function(token, config, refresh_token = NULL) {
      private$access_token <- token
      private$refresh_token <- refresh_token
      token <- config$decode_token(token)
      private$exp <- lubridate::as_datetime(token$exp)
      private$iat <- lubridate::as_datetime(token$iat)
      private$auth_time <- lubridate::as_datetime(token$auth_time)
      private$jti <- token$jti
      private$iss <- token$iss
      private$aud <- token$aud
      private$sub <- token$sub
      private$typ <- token$typ
      private$azp <- token$azp
      private$session_state <- token$session_state
      private$acr <- token$acr
      private$realm_access <- token$realm_access
      private$resource_access <- token$resource_access
      private$scope <- token$scope
      private$sid <- token$sid
      private$email_verified <- token$email_verified
      private$name <- token$name
      private$preferred_username <- token$preferred_username
      private$given_name <- token$given_name
      private$family_name <- token$family_name
      private$email <- token$email
    },
    is_valid = function() {
      !self$is_expired()
    },
    get_bearer = function() {
      paste0("Bearer ", private$access_token)
    },
    get_access_token = function() {
      private$access_token
    },
    get_refresh_token = function() {
      private$refresh_token
    },
    get_realm_roles = function() {
      private$realm_access$roles
    },
    get_resource_roles = function(resource) {
      private$resource_access[[resource]]$roles
    },
    has_realm_role = function(role) {
      role %in% self$get_realm_roles()
    },
    has_resource_role = function(resource, role) {
      role %in% self$get_resource_roles(resource)
    },
    expires_in = function() {
      private$exp - Sys.time()
    },
    expires_at = function() {
      private$exp
    },
    is_expired = function() {
      self$expires_in() < 0
    },
    get_preferred_username = function() {
      private$preferred_username
    },
    get_email = function() {
      private$email
    },
    get_name = function() {
      private$name
    },
    get_given_name = function() {
      private$given_name
    },
    get_family_name = function() {
      private$family_name
    },
    is_email_verified = function() {
      private$email_verified
    }
  ),
  private = list(
    access_token = NULL,
    refresh_token = NULL,
    exp = NULL,
    iat = NULL,
    auth_time = NULL,
    jti = NULL,
    iss = NULL,
    aud = NULL,
    sub = NULL,
    typ = NULL,
    azp = NULL,
    session_state = NULL,
    acr = NULL,
    realm_access = NULL,
    resource_access = NULL,
    scope = NULL,
    sid = NULL,
    email_verified = NULL,
    name = NULL,
    preferred_username = NULL,
    given_name = NULL,
    family_name = NULL,
    email = NULL
  )
)

#' @export
keycloak_config <- R6::R6Class(
  classname = "keycloak_config",
  public = list(
    initialize = function(base_url, realm, client_id, client_secret) {
      private$logout_url <- glue::glue("{base_url}/realms/{realm}/protocol/openid-connect/logout")
      private$auth_url <- glue::glue("{base_url}/realms/{realm}/protocol/openid-connect/auth")
      private$token_url <- glue::glue("{base_url}/realms/{realm}/protocol/openid-connect/token")
      private$jwks_url <- glue::glue("{base_url}/realms/{realm}/protocol/openid-connect/certs")
      private$realm <- realm
      private$client_id <- client_id
      private$client_secret <- client_secret
      self$refresh_jwks()
    },
    get_login_url = function(redirect_uri) {
      url <- httr2::url_parse(private$auth_url)
      url$query <- list(
        client_id = private$client_id,
        redirect_uri = redirect_uri,
        response_type = "code",
        scope = "openid"
      )
      httr2::url_build(url)
    },
    get_logout_url = function(redirect_uri) {
      url <- httr2::url_parse(private$logout_url)
      if (!is.null(redirect_uri)) {
        url$query <- list(
          client_id = private$client_id,
          post_logout_redirect_uri = redirect_uri
        )
      }
      httr2::url_build(url)
    },
    request_token = function(authorization_code, redirect_uri) {
      res <- httr2::request(private$token_url) |>
        httr2::req_method("POST") |>
        httr2::req_body_form(
          code = authorization_code,
          client_id = private$client_id,
          client_secret = private$client_secret,
          grant_type = "authorization_code",
          redirect_uri = redirect_uri
        ) |>
        httr2::req_perform()
      resp_status <- httr2::resp_status(res)
      if (resp_status != 200) {
        stop(httr2::resp_body_string(res))
      }
      httr2::resp_body_json(res)
    },
    refresh_jwks = function() {
      private$jwks <- httr2::request(private$jwks_url) |>
        httr2::req_method("GET") |>
        httr2::req_perform() |>
        httr2::resp_body_json() |>
        purrr::pluck("keys") |>
        purrr::map(jose::jwk_read)
    },
    decode_token = function(token) {
      decoded <- purrr::map(
        private$jwks,
        function(jwk) {
          tryCatch(
            expr = jose::jwt_decode_sig(token, jwk),
            error = function(e) {
              NULL
            }
          )
        }
      ) |>
        purrr::discard(is.null) |>
        purrr::pluck(1, .default = NULL)
      if (is.null(decoded)) {
        stop("Unable to decode token")
      }
      return(decoded)
    },
    get_client_id = function() {
      private$client_id
    }
  ),
  private = list(
    realm = NULL,
    logout_url = NULL,
    auth_url = NULL,
    jwks_url = NULL,
    token_url = NULL,
    client_id = NULL,
    client_secret = NULL,
    jwks = NULL
  )
)
