# ──────────────────────────────────────────────
# Azure API Management (APIM)
# ──────────────────────────────────────────────

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
  }
}

# ──────────────────────────────────────────────
# OAuth 2.0 Authorization Server
# ──────────────────────────────────────────────
resource "azurerm_api_management_authorization_server" "oauth_server" {
  name                         = "oauth-server"
  api_management_name          = azurerm_api_management.apim.name
  resource_group_name          = azurerm_resource_group.rg.name
  display_name                 = "Azure AD OAuth2"
  authorization_endpoint       = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize"
  token_endpoint               = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
  client_id                    = azuread_application.client_app.client_id
  client_secret                = azuread_application_password.client_app_secret.value
  authorization_methods        = ["GET", "POST"]
  bearer_token_sending_methods = ["authorizationHeader"]
  grant_types                  = ["authorizationCode"]
  client_authentication_method = ["Body"]
  default_scope                = "api://${azuread_application.api_app.client_id}/api.access"
}

# ──────────────────────────────────────────────
# API Definition — Order Processing Service
# ──────────────────────────────────────────────
resource "azurerm_api_management_api" "order_api" {
  name                  = "order-processing-api"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Order Processing API"
  path                  = "orders"
  protocols             = ["https"]
  subscription_required = true

  service_url = "http://${azurerm_kubernetes_cluster.aks.fqdn}"

  oauth2_authorization {
    authorization_server_name = azurerm_api_management_authorization_server.oauth_server.name
  }
}

# ──────────────────────────────────────────────
# API Operations
# ──────────────────────────────────────────────
resource "azurerm_api_management_api_operation" "create_order" {
  operation_id        = "create-order"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Create Order"
  method              = "POST"
  url_template        = "/api/v1/orders"
}

resource "azurerm_api_management_api_operation" "get_orders" {
  operation_id        = "get-orders"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Get All Orders"
  method              = "GET"
  url_template        = "/api/v1/orders"
}

resource "azurerm_api_management_api_operation" "get_order_by_id" {
  operation_id        = "get-order-by-id"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Get Order By ID"
  method              = "GET"
  url_template        = "/api/v1/orders/{orderId}"

  template_parameter {
    name     = "orderId"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "update_order_status" {
  operation_id        = "update-order-status"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Update Order Status"
  method              = "PATCH"
  url_template        = "/api/v1/orders/{orderId}/status"

  template_parameter {
    name     = "orderId"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "delete_order" {
  operation_id        = "delete-order"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Delete Order"
  method              = "DELETE"
  url_template        = "/api/v1/orders/{orderId}"

  template_parameter {
    name     = "orderId"
    required = true
    type     = "string"
  }
}

# ──────────────────────────────────────────────
# APIM Policy — JWT Validation + Rate Limiting + CORS
# ──────────────────────────────────────────────
resource "azurerm_api_management_api_policy" "order_api_policy" {
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- Validate JWT token from Azure AD -->
    <validate-jwt header-name="Authorization"
                  failed-validation-httpcode="401"
                  failed-validation-error-message="Unauthorized. Invalid or missing token.">
      <openid-config url="https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://${azuread_application.api_app.client_id}</audience>
      </audiences>
      <issuers>
        <issuer>https://login.microsoftonline.com/${var.tenant_id}/v2.0</issuer>
      </issuers>
      <required-claims>
        <claim name="scp" match="any">
          <value>api.access</value>
        </claim>
      </required-claims>
    </validate-jwt>
    <!-- Rate limiting -->
    <rate-limit calls="100" renewal-period="60" />
    <!-- CORS -->
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PATCH</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ──────────────────────────────────────────────
# APIM Product & Subscription
# ──────────────────────────────────────────────
resource "azurerm_api_management_product" "order_product" {
  product_id            = "order-processing-product"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.rg.name
  display_name          = "Order Processing Product"
  description           = "Access to Order Processing APIs"
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_product_api" "order_product_api" {
  api_name            = azurerm_api_management_api.order_api.name
  product_id          = azurerm_api_management_product.order_product.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_api_management_subscription" "order_subscription" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Order Processing Subscription"
  product_id          = azurerm_api_management_product.order_product.id
  state               = "active"
}
