terraform {
  required_version = ">=1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.26.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3"
    }
  }
}

# Primary provider (APIM subscription)
provider "azurerm" {
  alias = "primary"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.primary_subscription_id
}

# Secondary provider (AI services subscription 1)
provider "azurerm" {
  alias = "subscription1"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_configs.subscription1.subscription_id
}

# Tertiary provider (AI services subscription 2)
provider "azurerm" {
  alias = "subscription2"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_configs.subscription2.subscription_id
}

# Default provider (same as primary for backward compatibility)
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.primary_subscription_id
}

provider "azapi" {
}

provider "random" {
}
