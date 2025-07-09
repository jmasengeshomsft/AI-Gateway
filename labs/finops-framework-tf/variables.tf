variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  default     = "38bfc61d-d89a-4df6-b8fb-0c14568dcf29"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-finops-framework"
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "East US"
}

variable "current_user_object_id" {
  description = "The object ID of the current user for role assignments"
  type        = string
}

variable "apim_sku" {
  description = "The SKU for API Management service"
  type        = string
  default     = "Developer_1"
}

variable "openai_resource_location" {
  description = "The Azure region for OpenAI resources"
  type        = string
  default     = "East US"
}

variable "openai_api_version" {
  description = "The API version for OpenAI"
  type        = string
  default     = "2024-02-01"
}

variable "openai_deployments" {
  description = "List of OpenAI model deployments"
  type = list(object({
    name     = string
    model    = string
    version  = string
    capacity = number
  }))
  default = []
}

variable "apim_subscriptions_config" {
  description = "Configuration for APIM subscriptions"
  type = list(object({
    name         = string
    display_name = string
    product      = string
  }))
  default = []
}

variable "apim_products_config" {
  description = "Configuration for APIM products"
  type = list(object({
    name         = string
    display_name = string
    tpm          = number
  }))
  default = []
}

variable "apim_users_config" {
  description = "Configuration for APIM users"
  type = list(object({
    name       = string
    first_name = string
    last_name  = string
    email      = string
  }))
  default = []
}
