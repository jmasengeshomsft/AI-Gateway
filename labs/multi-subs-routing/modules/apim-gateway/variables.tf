variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for APIM deployment"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name for APIM"
}

variable "resource_group_location" {
  type        = string
  description = "Location for the resource group"
}

variable "app_suffix" {
  type        = string
  description = "Unique suffix for resource naming"
}

variable "apim_resource_name" {
  type        = string
  description = "Name of the API Management service"
  default     = "apim"
}

variable "apim_resource_location" {
  type        = string
  description = "Location for APIM deployment"
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

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the virtual network"
}

variable "subnet_apim_address_space" {
  type        = string
  description = "Address space for the APIM subnet"
}

variable "subnet_private_endpoints_address_space" {
  type        = string
  description = "Address space for the private endpoints subnet"
}

variable "openai_api_spec_url" {
  type        = string
  description = "URL to OpenAI API specification"
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

variable "backend_pools" {
  type = list(object({
    subscription_id = string
    services = list(object({
      name     = string
      endpoint = string
      priority = number
      weight   = number
    }))
  }))
  description = "Backend pool configurations from AI subscription modules"
  default     = []
}

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
