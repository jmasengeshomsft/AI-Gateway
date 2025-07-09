# Generate a unique suffix for resources
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  resource_suffix = random_string.suffix.result
  log_settings = {
    headers = ["Content-type", "User-agent", "x-ms-region", "x-ratelimit-remaining-tokens", "x-ratelimit-remaining-requests"]
    body = {
      bytes = 8192
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "workspace-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Custom table for pricing data
resource "azapi_resource" "pricing_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2023-09-01"
  name      = "PRICING_CL"
  parent_id = azurerm_log_analytics_workspace.main.id

  body = {
    properties = {
      totalRetentionInDays = 4383
      plan                 = "Analytics"
      schema = {
        name        = "PRICING_CL"
        description = "OpenAI models pricing table for ${azurerm_log_analytics_workspace.main.workspace_id}"
        columns = [
          {
            name = "TimeGenerated"
            type = "datetime"
          },
          {
            name = "Model"
            type = "string"
          },
          {
            name = "InputTokensPrice"
            type = "real"
          },
          {
            name = "OutputTokensPrice"
            type = "real"
          }
        ]
      }
      retentionInDays = 730
    }
  }
}

# Custom table for subscription quota data
resource "azapi_resource" "subscription_quota_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2023-09-01"
  name      = "SUBSCRIPTION_QUOTA_CL"
  parent_id = azurerm_log_analytics_workspace.main.id

  body = {
    properties = {
      totalRetentionInDays = 4383
      plan                 = "Analytics"
      schema = {
        name        = "SUBSCRIPTION_QUOTA_CL"
        description = "APIM subscriptions quota table for ${azurerm_log_analytics_workspace.main.workspace_id}"
        columns = [
          {
            name = "TimeGenerated"
            type = "datetime"
          },
          {
            name = "Subscription"
            type = "string"
          },
          {
            name = "CostQuota"
            type = "real"
          }
        ]
      }
      retentionInDays = 730
    }
  }
}

# Note: Data Collection Rules for custom table ingestion can be added later
# They require specific configuration for direct data ingestion which is complex

# Role assignments for DCRs can be added when DCRs are implemented

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "insights-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
}

# Set CustomMetricsOptedInType using azapi
resource "azapi_update_resource" "app_insights_custom_metrics" {
  type        = "Microsoft.Insights/components@2020-02-02"
  resource_id = azurerm_application_insights.main.id

  body = {
    properties = {
      CustomMetricsOptedInType = "WithDimensions"
    }
  }
}

# API Management Service (using azapi for faster deployment with StandardV2)
resource "azapi_resource" "apim" {
  type                      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name                      = "apim-${local.resource_suffix}-v2"
  parent_id                 = azurerm_resource_group.main.id
  location                  = azurerm_resource_group.main.location
  schema_validation_enabled = true

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name     = "StandardV2"
      capacity = 1
    }
    properties = {
      publisherEmail     = "noreply@microsoft.com"
      publisherName      = "Microsoft"
      publicNetworkAccess = "Enabled"
    }
  }

  response_export_values = ["*"]
}

# APIM Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  name                       = "apiManagementDiagnosticSettings"
  target_resource_id         = azapi_resource.apim.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log {
    category = "GatewayLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# APIM Logger for Application Insights
resource "azurerm_api_management_logger" "main" {
  name                = "apim-logger"
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
  resource_id         = azurerm_application_insights.main.id

  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# Cognitive Services (OpenAI)
resource "azurerm_cognitive_account" "openai" {
  name                = "openai-${local.resource_suffix}"
  location            = var.openai_resource_location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"

  custom_subdomain_name         = lower("openai-${local.resource_suffix}")
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# Cognitive Services Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "cognitive_services_diagnostics" {
  name                       = "${azurerm_cognitive_account.openai.name}-diagnostics"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }
  enabled_log {
    category = "Trace"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# OpenAI Deployments
resource "azurerm_cognitive_deployment" "openai_deployments" {
  for_each = { for idx, deployment in var.openai_deployments : idx => deployment }

  name                 = each.value.name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = each.value.model
    version = each.value.version
  }

  sku {
    name     = "Standard"
    capacity = each.value.capacity
  }
}

# Role assignment for APIM to access OpenAI
resource "azurerm_role_assignment" "openai_user_role" {
  scope              = azurerm_cognitive_account.openai.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
  principal_id       = azapi_resource.apim.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}
