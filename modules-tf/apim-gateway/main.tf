terraform {
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

# Locals for backend pool management
locals {
  # Flatten all backend services from multiple subscriptions
  all_backends = flatten([
    for pool in var.backend_pools : [
      for service in pool.services : {
        name         = service.name
        endpoint     = service.endpoint
        priority     = service.priority
        weight       = service.weight
        subscription = pool.subscription_id
      }
    ]
  ])
}

# Resource Group
resource "azurerm_resource_group" "apim_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Virtual Network for APIM
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vnet_name}-${var.app_suffix}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.apim_rg.location
  resource_group_name = azurerm_resource_group.apim_rg.name
}

# APIM Subnet
resource "azurerm_subnet" "subnet_apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.apim_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_apim_address_space]

  service_endpoints = [
    "Microsoft.CognitiveServices"
  ]

  delegation {
    name = "webserverfarmdelegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Network Security Group for APIM
resource "azurerm_network_security_group" "apim_nsg" {
  name                = "apim-nsg-${var.app_suffix}"
  location            = azurerm_resource_group.apim_rg.location
  resource_group_name = azurerm_resource_group.apim_rg.name

  # Required security rules for APIM External VNet integration
  security_rule {
    name                       = "Client_communication_to_API_Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Management_endpoint_for_Azure_portal_and_PowerShell"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Dependency_on_Azure_Storage"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "Azure_Active_Directory"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureActiveDirectory"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_apim.id
  network_security_group_id = azurerm_network_security_group.apim_nsg.id
}

# Private Endpoints Subnet
resource "azurerm_subnet" "subnet_private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.apim_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_private_endpoints_address_space]
}

# API Management Instance
resource "azapi_resource" "apim" {
  type                      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name                      = "${var.apim_resource_name}-${var.app_suffix}"
  parent_id                 = azurerm_resource_group.apim_rg.id
  location                  = var.apim_resource_location
  schema_validation_enabled = true

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name     = var.apim_sku
      capacity = var.apim_sku_capacity
    }
    properties = {
      publisherEmail      = "jmasengesho@microsoft.com"
      publisherName       = "Microsoft"
      virtualNetworkType  = "External"
      virtualNetworkConfiguration = {
        subnetResourceId = azurerm_subnet.subnet_apim.id
      }
      publicNetworkAccess = "Enabled"
    }
  }

  response_export_values = ["*"]
}

# OpenAI API
resource "azurerm_api_management_api" "apim_api_openai" {
  name                  = "apim-api-openai"
  resource_group_name   = azurerm_resource_group.apim_rg.name
  api_management_name   = azapi_resource.apim.name
  revision              = "1"
  description           = "Azure OpenAI APIs for completions and search"
  display_name          = "OpenAI"
  path                  = "openai"
  protocols             = ["https"]
  service_url           = null
  subscription_required = true
  api_type              = "http"

  import {
    content_format = "openapi-link"
    content_value  = var.openai_api_spec_url
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

# Product for OpenAI APIs
resource "azurerm_api_management_product" "openai_product" {
  product_id           = "openai-product"
  display_name         = "OpenAI APIs"
  description          = "Product exposing Azure OpenAI endpoints"
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.apim_rg.name

  subscription_required = true
  approval_required     = false
  published             = true
}

# Add the OpenAI API to the product
resource "azurerm_api_management_product_api" "openai_product_api" {
  product_id           = azurerm_api_management_product.openai_product.product_id
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.apim_rg.name
  api_name             = azurerm_api_management_api.apim_api_openai.name
}

# Product policy (Rate limiting)
resource "azurerm_api_management_product_policy" "openai_policy" {
  product_id           = azurerm_api_management_product.openai_product.product_id
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.apim_rg.name

  xml_content = replace(file("${path.module}/../../shared/policies/product-policy.xml"), "{tokens-per-minute}", 8)
}

# Create individual backends for each AI service
resource "azapi_resource" "apim_backend" {
  for_each = {
    for backend in local.all_backends : backend.name => backend
  }
  
  type                      = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name                      = each.value.name
  parent_id                 = azapi_resource.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Backend for ${each.value.name}"
      type        = "Single"
      url         = each.value.endpoint
      protocol    = "http"
      tls = {
        validateCertificateChain = true
        validateCertificateName  = true
      }
    }
  }

  depends_on = [azurerm_api_management_api.apim_api_openai]
}

# Dynamic backend pool creation (only if backends are provided)
resource "azapi_resource" "apim_backend_pool_openai" {
  count = length(local.all_backends) > 0 ? 1 : 0
  
  type                      = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name                      = "apim-backend-pool"
  parent_id                 = azapi_resource.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      type = "Pool"
      pool = {
        services = [
          for backend in local.all_backends : {
            id       = "/backends/${backend.name}"
            priority = backend.priority
            weight   = backend.weight
          }
        ]
      }
    }
  }

  depends_on = [azurerm_api_management_api.apim_api_openai, azapi_resource.apim_backend]
}

# API Policy (only if backend pool exists)
resource "azurerm_api_management_api_policy" "apim_openai_policy" {
  count = length(local.all_backends) > 0 ? 1 : 0
  
  api_name            = azurerm_api_management_api.apim_api_openai.name
  api_management_name = azurerm_api_management_api.apim_api_openai.api_management_name
  resource_group_name = azurerm_api_management_api.apim_api_openai.resource_group_name

  xml_content = replace(file("${path.module}/../../shared/policies/policy.xml"), "{backend-id}", azapi_resource.apim_backend_pool_openai[0].name)
}

# Subscription for testing
resource "azurerm_api_management_subscription" "apim_api_subscription_openai" {
  display_name        = "apim-api-subscription-openai"
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.apim_rg.name
  api_id              = replace(azurerm_api_management_api.apim_api_openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "apim_log_analytics" {
  name                = "${var.apim_resource_name}-log-analytics-${var.app_suffix}"
  location            = azurerm_resource_group.apim_rg.location
  resource_group_name = azurerm_resource_group.apim_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights
resource "azurerm_application_insights" "apim_ai_logger" {
  name                = "${var.apim_resource_name}-app-insights-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.apim_rg.name
  location            = azurerm_resource_group.apim_rg.location
  application_type    = "web"
  retention_in_days   = 30
  workspace_id        = azurerm_log_analytics_workspace.apim_log_analytics.id
}

# APIM Logger
resource "azapi_resource" "apim_logger" {
  type      = "Microsoft.ApiManagement/service/loggers@2021-08-01"
  parent_id = azapi_resource.apim.id
  name      = "appinsights"

  body = {
    properties = {
      loggerType  = "applicationInsights"
      description = "Logger for OpenAI APIs"
      credentials = {
        instrumentationKey = azurerm_application_insights.apim_ai_logger.instrumentation_key
      }
      resourceId = azurerm_application_insights.apim_ai_logger.id
    }
  }
}

# API Diagnostics
resource "azapi_resource" "apim_api_diagnostic" {
  type        = "Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01"
  parent_id   = azurerm_api_management_api.apim_api_openai.id
  name        = "applicationinsights"

  body = {
    properties = {
      alwaysLog   = "allErrors"
      sampling    = {
        samplingType = "fixed"
        percentage   = 100
      }
      verbosity   = "verbose"
      loggerId    = azapi_resource.apim_logger.id
    }
  }
}

# Auto Scaling (if enabled)
resource "azurerm_monitor_autoscale_setting" "apim_autoscale" {
  count               = var.enable_apim_autoscale ? 1 : 0
  name                = "apim-autoscale-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.apim_rg.name
  location            = azurerm_resource_group.apim_rg.location
  target_resource_id  = azapi_resource.apim.id

  profile {
    name = "default"

    capacity {
      default = var.apim_sku_capacity
      minimum = var.apim_autoscale_min_capacity
      maximum = var.apim_autoscale_max_capacity
    }

    # Scale out rule
    rule {
      metric_trigger {
        metric_name        = "Capacity"
        metric_resource_id = azapi_resource.apim.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
        metric_namespace   = "Microsoft.ApiManagement/service"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale in rule
    rule {
      metric_trigger {
        metric_name        = "Capacity"
        metric_resource_id = azapi_resource.apim.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
        metric_namespace   = "Microsoft.ApiManagement/service"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = ["jmasengesho@microsoft.com"]
    }
  }

  tags = {
    Environment = "monitoring"
    Purpose     = "apim-autoscaling"
  }
}
