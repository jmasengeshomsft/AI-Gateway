
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

  delegation {
    name = "webserverfarmdelegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      # actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "apim_nsg" {
  name                = "apim-nsg"
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
  public_network_access              = "Disabled"
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
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
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
      capacity = 1
    }
    properties = {
      publisherEmail      = "noreply@microsoft.com"
      publisherName       = "Microsoft
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