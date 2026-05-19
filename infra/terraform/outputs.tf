# ──────────────────────────────────────────────
# Terraform Outputs
# ──────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.acr.login_server
}

output "apim_gateway_url" {
  description = "APIM gateway URL"
  value       = azurerm_api_management.apim.gateway_url
}

output "api_url" {
  description = "Full API base URL via APIM"
  value       = "${azurerm_api_management.apim.gateway_url}/orders"
}

output "subscription_key" {
  description = "APIM subscription primary key"
  value       = azurerm_api_management_subscription.order_subscription.primary_key
  sensitive   = true
}

output "client_app_id" {
  description = "Client App Registration ID (for OAuth token requests)"
  value       = azuread_application.client_app.client_id
}

output "api_app_id" {
  description = "Backend API App Registration ID"
  value       = azuread_application.api_app.client_id
}

output "kube_config" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}
