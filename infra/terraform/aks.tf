# ──────────────────────────────────────────────
# Azure Kubernetes Service (AKS)
# ──────────────────────────────────────────────

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "order-processing"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    vm_size         = var.vm_size
    vnet_subnet_id  = azurerm_subnet.aks_subnet.id
    os_disk_size_gb = 30

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    service_cidr      = "10.0.3.0/24"
    dns_service_ip    = "10.0.3.10"
    load_balancer_sku = "standard"
  }

  # Enable HTTP Application Routing / Web App Routing (Ingress)
  web_app_routing {
    dns_zone_ids = []
  }

  tags = {
    environment = var.environment
  }
}

# Grant AKS kubelet identity pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
