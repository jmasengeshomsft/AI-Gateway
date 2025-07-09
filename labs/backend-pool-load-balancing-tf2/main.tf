locals {
  service_deployments = {
    for combo in flatten([
      for svc_key, svc in var.openai_config : [
        for dep_key, dep in var.openai_deployments : {
          key      = "${svc_key}-${dep_key}"
          svc_key  = svc_key
          svc      = svc
          dep_key  = dep_key
          dep      = dep
        }
      ]
    ]) : combo.key => {
      svc_key = combo.svc_key
      svc     = combo.svc
      dep_key = combo.dep_key
      dep     = combo.dep
    }
  }
}


resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}


// create a virtual network with 10.0.254.0/24. It should have two subnets:
// 1. subnet1 with address space /27 called apim
// 2. subnet2 with address space /25 called private-endpoints

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vnet_name}-${var.app_suffix}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.rg.name
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

resource "azurerm_network_security_group" "apim_nsg" {
  name                = "apim-nsg-${var.app_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "apim_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_apim.id
  network_security_group_id = azurerm_network_security_group.apim_nsg.id
}

resource "azurerm_subnet" "subnet_private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_private_endpoints_address_space]
}


resource "azurerm_ai_services" "ai-services" {
  for_each = var.openai_config

  name                               = "${each.value.name}-${var.app_suffix}"
  location                           = each.value.location
  resource_group_name                = azurerm_resource_group.rg.name
  sku_name                           = var.openai_sku
  local_authentication_enabled       = true
  public_network_access              = "Enabled"
  outbound_network_access_restricted = true
  custom_subdomain_name              = "${each.value.name}-${var.app_suffix}"

  network_acls {
    default_action = "Deny"
    virtual_network_rules {
      subnet_id = azurerm_subnet.subnet_apim.id
    }
  }

  lifecycle {
    ignore_changes = [custom_subdomain_name]
  }
}

resource "azurerm_monitor_diagnostic_setting" "ai_services_diag" {
  for_each            = var.openai_config
  name                = "${each.value.name}-diag-${var.app_suffix}"
  target_resource_id  = azurerm_ai_services.ai-services[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.apim_log_analytics.id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  enabled_log {
    category = "Trace"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
  
}


// Attach a RAIPolicy (content filter) to each AI service
resource "azapi_resource" "ai_content_filter" {
  for_each  = var.openai_config
  type      = "Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01"
  parent_id = azurerm_ai_services.ai-services[each.key].id
  name      = lower(replace("content-filter-${each.value.name}-${var.app_suffix}", "-", ""))

  body = {
    properties = {
       basePolicyName = "Microsoft.Default",
       contentFilters = [
        { name = "hate", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        { name = "sexual", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        { name = "selfharm", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        { name = "violence", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        { name = "hate", blocking = true, enabled = true, severityThreshold = "High", source = "Completion" },
        { name = "sexual", blocking = true, enabled = true, severityThreshold = "High", source = "Completion" },
        { name = "selfharm", blocking = true, enabled = true, severityThreshold = "High", source = "Completion" },
        { name = "violence", blocking = true, enabled = true, severityThreshold = "High", source = "Completion" },
        { name = "jailbreak", blocking = true, enabled = true, source = "Prompt" },
        { name = "protected_material_text", blocking = true, enabled = true, source = "Completion" },
        { name = "protected_material_code", blocking = true, enabled = true, source = "Completion" }
      ]
      mode = "Default"
    }
  }
}

# Add a local to store the predictable rai_policy_name for each service
locals {
  rai_policy_names = {
    for svc_key, svc in var.openai_config :
    svc_key => lower(replace("content-filter-${svc.name}-${var.app_suffix}", "-", ""))
  }
}

resource "azurerm_cognitive_deployment" "deploy" {
  for_each = local.service_deployments

  name                 = each.value.dep.deployment_name
  cognitive_account_id = azurerm_ai_services.ai-services[each.value.svc_key].id

  sku {
    name     = "GlobalStandard"
    capacity = each.value.dep.model_capacity
  }

  model {
    format  = "OpenAI"
    name    = each.value.dep.model_name
    version = each.value.dep.model_version
  }

  rai_policy_name = local.rai_policy_names[each.value.svc_key]
}

# Terraform azurerm provider doesn't support yet creating API Management instances with v2 SKU.
resource "azapi_resource" "apim" {
  type                      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name                      = "${var.apim_resource_name}-${var.app_suffix}"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = var.apim_resource_location # SKU BasicV2 is not yet supported in the region Sweden Central
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

resource "azurerm_role_assignment" "Cognitive-Services-OpenAI-User" {
  for_each = var.openai_config

  scope                = azurerm_ai_services.ai-services[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.identity.0.principal_id
}

resource "azurerm_api_management_api" "apim-api-openai" {
  name                  = "apim-api-openai"
  resource_group_name   = azurerm_resource_group.rg.name
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


resource "azurerm_api_management_product" "openai_product" {
  product_id           = "openai-product"
  display_name         = "OpenAI APIs"
  description          = "Product exposing Azure OpenAI endpoints"
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.rg.name

  subscription_required = true
  approval_required     = false
  published             = true
}

// 2. Add the OpenAI API to that product
resource "azurerm_api_management_product_api" "openai_product_api" {
  product_id           = azurerm_api_management_product.openai_product.product_id
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.rg.name
  api_name             = azurerm_api_management_api.apim-api-openai.name
}

resource "azurerm_api_management_product_policy" "openai_policy" {
  product_id           = azurerm_api_management_product.openai_product.product_id
  api_management_name  = azapi_resource.apim.name
  resource_group_name  = azurerm_resource_group.rg.name

  xml_content = replace(file("product-policy.xml"), "{tokens-per-minute}", 8)
}

resource "azurerm_api_management_backend" "apim-backend-openai" {
  for_each = var.openai_config

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  protocol            = "http"
  url                 = "${azurerm_ai_services.ai-services[each.key].endpoint}openai"
}

resource "azapi_update_resource" "apim-backend-circuit-breaker" {
  for_each = var.openai_config

  type        = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  resource_id = azurerm_api_management_backend.apim-backend-openai[each.key].id

  body = {
    properties = {
      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count = 1
              errorReasons = [
                "Server errors"
              ]
              interval = "PT5M"
              statusCodeRanges = [
                {
                  min = 429
                  max = 429
                }
              ]
            }
            name             = "openAIBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true // respects the Retry-After header
          }
        ]
      }
    }
  }
}

resource "azapi_resource" "apim-backend-pool-openai" {
  type                      = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name                      = "apim-backend-pool"
  parent_id                 = azapi_resource.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      type = "Pool"
      pool = {
        services = [
          for k, v in var.openai_config :
          {
            id       = azurerm_api_management_backend.apim-backend-openai[k].id
            priority = v.priority
            weight   = v.weight
          }
        ]
      }
    }
  }
}

resource "azurerm_api_management_api_policy" "apim-openai-policy-openai" {
  api_name            = azurerm_api_management_api.apim-api-openai.name
  api_management_name = azurerm_api_management_api.apim-api-openai.api_management_name
  resource_group_name = azurerm_api_management_api.apim-api-openai.resource_group_name

  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.apim-backend-pool-openai.name)
}

resource "azurerm_api_management_subscription" "apim-api-subscription-openai" {
  display_name        = "apim-api-subscription-openai"
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.apim-api-openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}

### Monitoring and Logging
# 1. Create a log analytics workspace for the APIM instance
resource "azurerm_log_analytics_workspace" "apim_log_analytics" {
  name                = "${var.apim_resource_name}-log-analytics-${var.app_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "apim_ai_logger" {
  name                = "${var.apim_resource_name}-app-insights-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  retention_in_days   = 30
  workspace_id        = azurerm_log_analytics_workspace.apim_log_analytics.id
}

// 2. Create an APIM logger that points at the AppInsights instance
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

// 3. Enable diagnostics on the OpenAI API to send traces to that logger
resource "azapi_resource" "apim_api_diagnostic" {
  type        = "Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01"
  parent_id   = azurerm_api_management_api.apim-api-openai.id
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

resource "azurerm_application_insights_workbook" "alerts" {
  name                    = "5388f0b3-f17a-4f1b-8c53-e9c1246ea26f"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location

  category       = "workbook"
  display_name   = "Alerts Workbook"
  data_json      = file("${path.module}/workbooks/alerts.json")
}

# Azure OpenAI Insights Workbook
resource "azurerm_application_insights_workbook" "azure_openai_insights" {
  name                    = "cf545a5a-d1b2-49fe-8c53-5fe5869577d2"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  category       = "workbook"
  display_name   = "Azure OpenAI Insights"
  data_json      = file("${path.module}/workbooks/azure-openai-insights.json")
}

# Cost Analysis Workbook
resource "azurerm_application_insights_workbook" "cost_analysis" {
  name                    = "6484f3bd-0e97-48e7-96a8-c6dd6606fe0b"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  category       = "workbook"
  display_name   = "Cost Analysis"
  data_json = file("${path.module}/workbooks/cost-analysis.json")
}

### Alert Rules and Notifications
# Action Group for email notifications
resource "azurerm_monitor_action_group" "apim_alerts" {
  name                = "apim-alerts-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "apimalerts"

  email_receiver {
    name          = "admin-email"
    email_address = "jmasengesho@microsoft.com"
  }

  tags = {
    Environment = "monitoring"
    Purpose     = "apim-alerting"
  }
}

# Metric Alert Rule for APIM 4xx errors
resource "azurerm_monitor_metric_alert" "apim_4xx_errors" {
  name                = "apim-4xx-errors-alert-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azapi_resource.apim.id]
  description         = "Alert when APIM has more than 10 4xx errors in 5 minutes"
  severity            = 2
  enabled             = true
  auto_mitigate       = true
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10

    dimension {
      name     = "BackendResponseCode"
      operator = "Include"
      values   = ["4*"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.apim_alerts.id
  }

  tags = {
    Environment = "monitoring"
    Purpose     = "apim-error-monitoring"
  }
}

# Metric Alert Rule for APIM capacity utilization
resource "azurerm_monitor_metric_alert" "apim_capacity" {
  name                = "apim-capacity-alert-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azapi_resource.apim.id]
  description         = "Alert when APIM capacity utilization is greater than or equal to 70%"
  severity            = 2
  enabled             = true
  auto_mitigate       = true
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Capacity"
    aggregation      = "Average"
    operator         = "GreaterThanOrEqual"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.apim_alerts.id
  }

  tags = {
    Environment = "monitoring"
    Purpose     = "apim-capacity-monitoring"
  }
}

# Metric Alert Rule for APIM latency
resource "azurerm_monitor_metric_alert" "apim_latency" {
  name                = "apim-latency-alert-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azapi_resource.apim.id]
  description         = "Alert when APIM response time is greater than 4 seconds"
  severity            = 2
  enabled             = true
  auto_mitigate       = true
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 4000  # 4 seconds in milliseconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.apim_alerts.id
  }

  tags = {
    Environment = "monitoring"
    Purpose     = "apim-latency-monitoring"
  }
}

### Auto Scaling Configuration
# Auto Scale Settings for APIM (requires StandardV2 or higher SKU)
resource "azurerm_monitor_autoscale_setting" "apim_autoscale" {
  count               = var.enable_apim_autoscale ? 1 : 0
  name                = "apim-autoscale-${var.app_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azapi_resource.apim.id

  profile {
    name = "default"

    capacity {
      default = var.apim_sku_capacity
      minimum = var.apim_autoscale_min_capacity
      maximum = var.apim_autoscale_max_capacity
    }

    # Scale out rule - increase capacity when CPU > 70%
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

    # Scale in rule - decrease capacity when CPU < 30%
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
    }    # Scale out rule based on request count
    # rule {
    #   metric_trigger {
    #     metric_name        = "Requests"
    #     metric_resource_id = azapi_resource.apim.id
    #     time_grain         = "PT1M"
    #     statistic          = "Sum"
    #     time_window        = "PT5M"
    #     time_aggregation   = "Total"
    #     operator           = "GreaterThan"
    #     threshold          = 1000  # Scale out if > 1000 requests in 5 minutes
    #     metric_namespace   = "Microsoft.ApiManagement/service"
    #   }

    #   scale_action {
    #     direction = "Increase"
    #     type      = "ChangeCount"
    #     value     = "1"
    #     cooldown  = "PT10M"
    #   }
    # }    # Scale in rule based on low request count
    # rule {
    #   metric_trigger {
    #     metric_name        = "Requests"
    #     metric_resource_id = azapi_resource.apim.id
    #     time_grain         = "PT1M"
    #     statistic          = "Sum"
    #     time_window        = "PT15M"
    #     time_aggregation   = "Total"
    #     operator           = "LessThan"
    #     threshold          = 100  # Scale in if < 100 requests in 15 minutes
    #     metric_namespace   = "Microsoft.ApiManagement/service"
    #   }

    #   scale_action {
    #     direction = "Decrease"
    #     type      = "ChangeCount"
    #     value     = "1"
    #     cooldown  = "PT15M"
    #   }
    # }
  }

  # Notification for scaling events
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

### Global Security Policies
# Apply IP whitelisting policy to the entire APIM instance using azapi_resource
resource "azapi_resource" "whitelist-global_policy" {
  type      = "Microsoft.ApiManagement/service/policies@2024-05-01"
  name      = "policy"
  parent_id = azapi_resource.apim.id

  body = {
    properties = {
      format = "xml"
      value  = file("global-policy.xml")
    }
  }
}