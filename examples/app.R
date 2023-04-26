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
