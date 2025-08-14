variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for AI services deployment"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name for AI services"
}

variable "resource_group_location" {
  type        = string
  description = "Location for the resource group"
}

variable "app_suffix" {
  type        = string
  description = "Unique suffix for resource naming"
}

variable "openai_config" {
  type = map(object({
    name     = string
    location = string
    priority = number
    weight   = number
  }))
  description = "Configuration for OpenAI services in this subscription"
}

variable "openai_deployments" {
  type = map(object({
    deployment_name = string
    model_name      = string
    model_version   = string
    model_capacity  = number
  }))
  description = "OpenAI model deployments configuration"
}

variable "openai_sku" {
  type        = string
  description = "SKU for OpenAI services"
  default     = "S0"
}

variable "apim_subnet_id" {
  type        = string
  description = "APIM subnet ID for network ACL configuration"
}

variable "apim_vnet_id" {
  type        = string
  description = "APIM VNet ID for VNet peering"
}

variable "apim_vnet_name" {
  type        = string
  description = "APIM VNet name for peering"
}

variable "apim_resource_group_name" {
  type        = string
  description = "APIM resource group name for cross-subscription peering"
}

# VNet Configuration for this subscription
variable "vnet_name" {
  type        = string
  description = "VNet name for AI services"
  default     = "ai-services-vnet"
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for AI services VNet"
  default     = "10.1.0.0/16"
}

variable "subnet_ai_services_address_space" {
  type        = string
  description = "Address space for AI services subnet"
  default     = "10.1.1.0/24"
}

variable "apim_principal_id" {
  type        = string
  description = "APIM principal ID for role assignments"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostics"
}
