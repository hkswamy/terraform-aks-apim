# ──────────────────────────────────────────────
# Variables for Azure Infrastructure
# ──────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  default     = "rg-order-processing"
}

variable "location" {
  description = "Azure region for all resources"
  default     = "centralindia"
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  default     = "dev"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  default     = "aks-order-processing"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, alphanumeric only)"
  default     = "acrorderprocessing"
}

variable "apim_name" {
  description = "Name of the Azure API Management instance"
  default     = "apim-order-processing"
}

variable "node_count" {
  description = "Number of AKS worker nodes"
  default     = 2
}

variable "vm_size" {
  description = "VM size for AKS nodes"
  default     = "Standard_D2s_v3"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  default     = "1.30"
}

variable "apim_sku" {
  description = "SKU for API Management (Developer_1, Standard_1, Premium_1)"
  default     = "Developer_1"
}

variable "publisher_name" {
  description = "APIM publisher name"
  default     = "Kumaraswami Hosuru"
}

variable "publisher_email" {
  description = "APIM publisher email"
  default     = "admin@yourdomain.com"
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}
