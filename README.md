# Keycloak Auth R

This library is meant to help R developers to easily implement authentication and authorization
in their applications using [Keycloak](https://www.keycloak.org/).

## What is Keycloak?

Keycloak is an open source Identity and Access Management solution (supported by RedHat) aimed at
modern applications and services. It makes it easy to secure applications and services with little
to no code.

## What is Keycloak Auth R?

Keycloak Auth R is an R package that provides a simple interface to Keycloak's REST API. It allows
developers to easily implement authentication and authorization in their applications.

## Installation

This package is not yet available on CRAN. You can install it from GitHub using the `remotes`
package:

```r
remotes::install_github("andyquinterom/keycloakAuthR")
```

## Usage

This package is still in development. Many features are not yet implemented and
the API is subject to change. However, the basic functionality is there.

### Connecting to a Keycloak server

This package exports an R6 class called `keycloak_config` that is used to store the
configuration of a Keycloak server. You can create a new instance of this class
using `keycloak_config$new(...)`.

The `keycloak_config$new` method accepts the following arguments:

- `base_url`: The base URL of the auth endpoint of the Keycloak server.
- `realm`: The name of the realm to use.
- `client_id`: The client ID to use.
- `client_secret`: The client secret to use.

With these parameters the class is able to generate the URLs needed to interact with
the Keycloak server.

The `keycloak_config` class implements some methods that can be used to interact with
the Keycloak server. The most important ones are:

- `get_login_url`: Returns the URL that can be used to initiate the login process.
    - `redirect_uri`: The URL to redirect to after the login process is complete.
- `get_logout_url`: Returns the URL that can be used to initiate the logout process.
    - `redirect_uri`: This argument is optional. If provided, the user will be redirected
    to this URL after the logout process is complete.
- `request_token`: Requests a token from the Keycloak server. If successful, a `list` with
    an `access_token`, `refresh_token` (if enabled), and other information is returned.
    - `authorization_code`: The authorization code obtained after the login process is complete.
    - `redirect_uri`: The URL to redirect to after the login process is complete.
- `decode_token`: Decodes a token and throws and error if the token's signature is invalid.
    This method should not really be used directly, instead use the methods inside the
    `keycloak_access_token` class.
    - `token`: The token to decode.
- `refresh_jwks`: Refreshes the JWKS (JSON Web Key Set) used to verify the signature of
    tokens. This method is called automatically when needed, but it can also be called
    manually.

### Working with access tokens

This package exports an R6 class called `keycloak_access_token` that is used to store
information about an access token. You can create a new instance of this class using
`keycloak_access_token$new(...)`.

The `keycloak_access_token$new` method accepts the following arguments:

- `token`: The access token to store (this value can be taken from the list returned by the
    `request_token` method inside the `keycloak_config` class).
- `config`: An instance of the `keycloak_config` class.
- `refresh_token` (optional): The refresh token to store (this value can be taken from the list
    returned by the `request_token` method inside the `keycloak_config` class).

The `keycloak_access_token` class implements some methods that can be used to interact with
the access token. The most important ones are:

- `is_valid`: Returns `TRUE` if the token is valid, `FALSE` otherwise.
- `get_bearer`: Returns the bearer token that can be used to authenticate requests to other
    services.
- `get_access_token`: Returns the access token.
- `get_refresh_token`: Returns the refresh token.
- `get_realm_roles`: Returns the realm roles assigned to the user.
- `get_resource_roles`: Returns the resource/client roles assigned to the user.
- `has_realm_role`: Returns `TRUE` if the user has the specified realm role, `FALSE` otherwise.
- `has_resource_role`: Returns `TRUE` if the user has the specified resource/client role, `FALSE`
    otherwise.
- `expires_in`: Returns the number of seconds until the token expires.
- `expires_at`: Returns the date and time when the token expires.
- `is_expired`: Returns `TRUE` if the token is expired, `FALSE` otherwise.
- `get_preferred_username`: Returns the preferred username of the user.
- `get_email`: Returns the email of the user.
- `get_name`: Returns the name of the user.
- `get_given_name`: Returns the given name of the user.
- `get_family_name`: Returns the family name of the user.
- `is_email_verified`: Returns `TRUE` if the user's email is verified, `FALSE` otherwise.

### With Shiny Apps

Working with Shiny is really simple. You just need to create an instance of the
`keycloak_config` class. This instance can be passed on to different functions
that the library exports.

To enable authentication in your Shiny App, you need to start the
`keycloak_shiny_login_server` module. This module will handle the login process
and will return a reactive with an instance of the `keycloak_access_token` class.
This reactive can be used to check if the user is logged in and to get information
about the user.

The `keycloak_shiny_login_server` module accepts the following arguments:

- `config`: An instance of the `keycloak_config` class.
- `redirect_uri`: The URL to redirect to after the login process is complete.
- `auto_redirect` (optional): If `TRUE`, the user will be redirected to the login
    page automatically if they are not logged in. Defaults to `TRUE`.

To log a user out, you need to call the `keycloak_shiny_signout` function inside
a reactive context.

The implementation of the login and logout process handles tokens automatically with
httpOnly cookies. This means that you don't need to worry about storing tokens in
the browser's local storage or in cookies.

Here's a simple example:

```r
library(keycloakAuthR)
library(shiny)

config <- keycloak_config$new(
  Sys.getenv("KEYCLOAK_URL"),
  realm = Sys.getenv("KEYCLOAK_REALM"),
  client_id = Sys.getenv("KEYCLOAK_CLIENT_ID"),
  client_secret = Sys.getenv("KEYCLOAK_CLIENT_SECRET")
)

ui <- fluidPage(
  uiOutput("secret_message")
)

server <- function(input, output, session) {

  token <- keycloak_shiny_login_server(config, "http://localhost:3838", auto_redirect = FALSE)

  output$secret_message <- renderUI({
    if (token()$is_valid()) {
      tags$div(
        tags$h1("Secret message"),
        tags$p("This is a secret message that only logged in users can see."),
        actionButton("logout", "Logout")
      )
    } else {
      tags$a(
        href = config$get_login_url("http://localhost:3838"),
        tags$h1("Login")
      )
    }
  })

  observeEvent(input$logout, {
    keycloak_shiny_signout(config, redirect_uri = "http://localhost:3838")
  })
}

shinyApp(ui, server)
```
