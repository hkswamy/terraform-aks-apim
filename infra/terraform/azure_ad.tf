# ──────────────────────────────────────────────
# Azure AD App Registrations (OAuth 2.0)
# ──────────────────────────────────────────────

# ─── Backend API App Registration ────────────
resource "azuread_application" "api_app" {
  display_name = "order-processing-api"

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Access Order Processing API"
      admin_consent_display_name = "Access API"
      id                         = "00000000-0000-0000-0000-000000000001" # Replace with a unique UUID
      enabled                    = true
      type                       = "User"
      value                      = "api.access"
    }
  }

  web {
    redirect_uris = [
      "https://${var.apim_name}.azure-api.net/signin-oauth/code/callback/oauth-server"
    ]
  }
}

resource "azuread_application_password" "api_app_secret" {
  application_id = azuread_application.api_app.id
  display_name   = "terraform-managed"
  end_date       = "2027-12-31T00:00:00Z"
}

resource "azuread_service_principal" "api_sp" {
  client_id = azuread_application.api_app.client_id
}

# ─── Client App Registration (API consumers) ─
resource "azuread_application" "client_app" {
  display_name = "order-processing-client"

  required_resource_access {
    resource_app_id = azuread_application.api_app.client_id

    resource_access {
      id   = "00000000-0000-0000-0000-000000000001"
      type = "Scope"
    }
  }
}

resource "azuread_application_password" "client_app_secret" {
  application_id = azuread_application.client_app.id
  display_name   = "terraform-managed"
  end_date       = "2027-12-31T00:00:00Z"
}
