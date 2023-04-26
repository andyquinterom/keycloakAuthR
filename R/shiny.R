get_query_params <- function(session = shiny::getDefaultReactiveDomain()) {
  shiny::parseQueryString(session$clientData$url_search)
}

# Simple function that **partially** parses a cookie string
# from session$userData$request$HTTP_COOKIE
parse_cookies <- function(x) {
  if (is.null(x)) return(list())
  cookie_pairs <- stringr::str_split(x, "; ")
  cookie_pairs <- purrr::map(cookie_pairs, ~ stringr::str_split(.x, "=", n = 2))[[1]]
  cookie_pairs <- purrr::map(cookie_pairs, function(.x) {
    .x[2] <- curl::curl_unescape(.x[2])
    setNames(.x[2], .x[1])
  })
  cookie_pairs <- purrr::flatten(cookie_pairs)
  return(cookie_pairs)
}

request_auth_token <- function(api_url, app_url, code, refresh_token) {
  promises::future_promise({
    mdco_get_token(api_url, app_url, code, refresh_token)
  })
}

return_null <- function(...) {
  return(NULL)
}

get_token_from_cookies <- function(session = shiny::getDefaultReactiveDomain()) {
  cookies <- parse_cookies(session$request$HTTP_COOKIE)
  access_token <- utils::URLdecode(cookies[["Authorization"]])
  refresh_token <- utils::URLdecode(cookies[["RefreshToken"]])
  return(list(access_token = access_token, refresh_token = refresh_token))
}

remove_bearer <- function(token) {
  if (is.null(token)) return(NULL)
  token <- stringr::str_remove(token, "^Bearer ")
  return(token)
}

#' @title Módulo de Shiny para iniciar sesión con API de AIS
#' @description
#' Este módulo de Shiny hace varias cosas:
#'
#' 1. Si no hay token, inicia el proceso de autorización.
#' 2. Crea un objeto de conexión a la API de AIS y la almacenará en `session$userData$conn`.
#' 3. Devuelve un `reactive` con un promise del perfil del usuario.
#'
#' Para utilizarlo se debe llamar esta función al inicio de la función
#' `server` de la aplicación de Shiny junto a sus argumentos.
#' @importFrom promises `%...>%`
#' @importFrom promises `%...!%`
#' @export
keycloak_shiny_login_server <- function(config, redirect_uri, auto_redirect = TRUE) {

  shiny::moduleServer("keycloak_login", function(input, output, session) {

    access_token <- shiny::reactiveVal(empty_keycloak_access_token$new())

    return_token <- shiny::reactive(access_token())

    tokens <- get_token_from_cookies()

    shiny::observe({
      tryCatch(
        expr = {
          token <- keycloak_access_token$new(remove_bearer(tokens$access_token), config)
          if (token$is_valid()) {
            access_token(token)
          } else {
            stop("Invalid token")
          }
        },
        error = function(e) {
          query <- get_query_params()
          if (isTruthy(query$code)) {
            token_resp <- promises::then(
              promises::future_promise(
                fetch_keycloak_access_token(query$code, redirect_uri, config)
              ),
              onRejected = function(...) {
                if (auto_redirect) {
                  open_login_url(config, redirect_uri)
                }
              }
            )

            promises::then(
              token_resp,
              ~ set_cookies(.x)
            )

            promises::then(
              token_resp,
              ~ access_token(.x)
            )

          } else if (auto_redirect) {
            open_login_url(config, redirect_uri)
          }
        }
      )
    })

    return(return_token)

  })

}

#' @export
open_login_url <- function(config, redirect_uri, session = shiny::getDefaultReactiveDomain()) {
  remove_cookies()
  login_url <- config$get_login_url(redirect_uri)
  script <- enc2utf8(glue::glue('window.location.replace("{login_url}");'))
  shiny::insertUI(
    "body",
    where = "afterBegin",
    ui = shiny::tags$script(htmltools::HTML(script)),
    immediate = TRUE
  )
  return()
}

build_cookie <- function(key, value) {
  glue::glue("{key}={value}; path=/; SameSite=Lax; HttpOnly")
}

#' @export
set_cookies <- function(token, session = shiny::getDefaultReactiveDomain()) {
  bearer <- token$get_bearer()
  refresh_token <- token$get_refresh_token()
  script_url <- session$registerDataObj(
    "signin-success",
    list(access_token = bearer, refresh_token = refresh_token),
    filterFunc = function(data, req) {
      shiny::httpResponse(
        200L,
        content_type = "text/javascript",
        content = enc2utf8('console.log("hello");'),
        headers = list(
          "Set-Cookie" = build_cookie("Authorization", data$access_token),
          "Set-Cookie" = build_cookie("RefreshToken", data$refresh_token)
        )
      )
    }
  )
  shiny::insertUI(
    "body",
    where = "afterBegin",
    ui = shiny::tags$script(src = script_url),
    immediate = TRUE
  )
}

#' @export
keycloak_shiny_signout <- function(config, redirect_uri = NULL, session = shiny::getDefaultReactiveDomain()) {
  logout_url <- config$get_logout_url(redirect_uri)
  client_id <- config$get_client_id()
  remove_cookies()
  script <- enc2utf8(glue::glue('window.location.replace("{logout_url}");'))
  shiny::insertUI(
    "body",
    where = "afterBegin",
    ui = shiny::tags$script(htmltools::HTML(script)),
    immediate = TRUE
  )
}

remove_cookies <- function(..., session = shiny::getDefaultReactiveDomain()) {
  session <- shiny::getDefaultReactiveDomain()
  script_url <- session$registerDataObj(
    "signout",
    list(),
    filterFunc = function(data, req) {
      shiny::httpResponse(
        200L,
        content_type = "text/javascript",
        content = enc2utf8("console.log('Signed out!');"),
        headers = list(
          "Set-Cookie" = paste0("Authorization=; path=/; SameSite=Lax; HttpOnly"),
          "Set-Cookie" = paste0("RefreshToken=; path=/; SameSite=Lax; HttpOnly")
        )
      )
    }
  )
  shiny::insertUI(
    "body",
    where = "afterBegin",
    ui = shiny::tags$script(src = script_url),
    immediate = TRUE
  )
}
