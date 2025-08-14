variable "primary_subscription_id" {
  type        = string
  description = "Primary subscription ID where APIM will be deployed"
  default     = "5a552781-da94-4df2-b0d3-e36e2a4de7f9"
}

variable "app_suffix" {
  type        = string
  description = "Unique suffix for resource naming"
  default     = "modular01"
}

variable "subscription_configs" {
  type = map(object({
    subscription_id         = string
    resource_group_name     = string
    resource_group_location = string
    openai_config = map(object({
      name     = string
      location = string
      priority = number
      weight   = number
    }))
    openai_deployments = map(object({
      deployment_name = string
      model_name      = string
      model_version   = string
      model_capacity  = number
    }))
  }))
  description = "Configuration for each AI subscription"
}

# APIM Configuration
variable "apim_resource_name" {
  type        = string
  description = "Name of the API Management service"
  default     = "apim"
}

variable "apim_resource_location" {
  type        = string
  description = "Location for APIM deployment"
  default     = "eastus2"
}

variable "apim_sku" {
  type        = string
  description = "SKU of the API Management service"
  default     = "StandardV2"
}

variable "apim_sku_capacity" {
  type        = number
  description = "Capacity of the API Management service"
  default     = 1
}

# Network Configuration
variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
  default     = "ai-gateway-network"
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the virtual network"
  default     = "10.0.254.0/24"
}

variable "subnet_apim_address_space" {
  type        = string
  description = "Address space for the APIM subnet"
  default     = "10.0.254.0/27"
}

variable "subnet_private_endpoints_address_space" {
  type        = string
  description = "Address space for the private endpoints subnet"
  default     = "10.0.254.128/25"
}

# OpenAI Configuration
variable "openai_sku" {
  type        = string
  description = "SKU for OpenAI services"
  default     = "S0"
}

variable "openai_api_spec_url" {
  type        = string
  description = "URL to OpenAI API specification"
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

# Auto Scaling Configuration
variable "enable_apim_autoscale" {
  type        = bool
  description = "Enable auto scaling for APIM"
  default     = true
}

variable "apim_autoscale_min_capacity" {
  type        = number
  description = "Minimum number of scale units for auto scaling"
  default     = 1
}

variable "apim_autoscale_max_capacity" {
  type        = number
  description = "Maximum number of scale units for auto scaling"
  default     = 10
}
