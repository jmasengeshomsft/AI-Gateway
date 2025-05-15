variable "subscription_id" {
  type        = string
  default     = "5a552781-da94-4df2-b0d3-e36e2a4de7f9"
}

variable "app_suffix" {
  type        = string
  default     = "eq9wMc4L"
}

variable "resource_group_name" {
  type        = string
  default     = "lab-backend-pool-load-balancing-terraform"
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
}

variable "openai_backend_pool_name" {
  type        = string
  default     = "openai-backend-pool"
}

variable "openai_config" {
  default = {
    openai-uks = {
      name     = "meraki-test-001",
      location = "eastus",
      priority = 1,
      weight   = 100
    },
    openai-swc = {
      name     = "openai2",
      location = "swedencentral",
      priority = 2,
      weight   = 50
    },
    openai-frc = {
      name     = "openai3",
      location = "francecentral",
      priority = 2,
      weight   = 50
    }
  }
}

variable "openai_deployment_name" {
  type        = string
  default     = "gpt-4o"
}

variable "embedding_openai_deployment_name" {
  type        = string
  default     = "embedding"
}

variable "openai_sku" {
  type        = string
  default     = "S0"
}

variable "openai_model_name" {
  type        = string
  default     = "gpt-4o"
}

variable "openai_model_name_embedding" {
  type        = string
  default     = "text-embedding-3-small"
}

variable "openai_model_version" {
  type        = string
  default     = "2024-08-06"
}

variable "openai_model_version_embedding" {
  type        = string
  default     = "1"
}

variable "openai_model_capacity" {
  type        = number
  default     = 8
}

variable "openai_api_spec_url" {
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

variable "apim_resource_name" {
  type        = string
  default     = "apim"
}

variable "apim_resource_location" {
  type        = string
  default     = "eastus" # APIM SKU StandardV2 is not yet supported in the region Sweden Central
}

variable "apim_sku" {
  type        = string
  default     = "BasicV2"
}

variable "openai_api_version" {
  type        = string
  default     = "2024-10-21"
}