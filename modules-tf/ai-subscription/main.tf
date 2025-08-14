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
  }
}

# Locals for service deployments
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

  # RAI policy names for each service
  rai_policy_names = {
    for svc_key, svc in var.openai_config :
    svc_key => lower(replace("content-filter-${svc.name}-${var.app_suffix}", "-", ""))
  }
}

# Resource Group
resource "azurerm_resource_group" "ai_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Virtual Network for AI Services
resource "azurerm_virtual_network" "ai_vnet" {
  name                = "${var.vnet_name}-${var.app_suffix}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.ai_rg.location
  resource_group_name = azurerm_resource_group.ai_rg.name
}

# Subnet for AI Services
resource "azurerm_subnet" "ai_services_subnet" {
  name                 = "ai-services"
  resource_group_name  = azurerm_resource_group.ai_rg.name
  virtual_network_name = azurerm_virtual_network.ai_vnet.name
  address_prefixes     = [var.subnet_ai_services_address_space]

  service_endpoints = [
    "Microsoft.CognitiveServices"
  ]
}

# VNet Peering: AI subscription -> APIM subscription
resource "azurerm_virtual_network_peering" "ai_to_apim" {
  name                      = "ai-to-apim-${var.app_suffix}"
  resource_group_name       = azurerm_resource_group.ai_rg.name
  virtual_network_name      = azurerm_virtual_network.ai_vnet.name
  remote_virtual_network_id = var.apim_vnet_id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways         = false
}

# VNet Peering: APIM subscription -> AI subscription (using azapi for cross-subscription)
resource "azapi_resource" "apim_to_ai_peering" {
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01"
  name      = "apim-to-ai-${var.subscription_id}-${var.app_suffix}"
  parent_id = var.apim_vnet_id

  body = {
    properties = {
      remoteVirtualNetwork = {
        id = azurerm_virtual_network.ai_vnet.id
      }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways        = false
    }
  }

  depends_on = [
    azurerm_virtual_network_peering.ai_to_apim,
    azurerm_subnet.ai_services_subnet
  ]
}

# AI Services (OpenAI)
resource "azurerm_ai_services" "ai_services" {
  for_each = var.openai_config

  name                               = "${each.value.name}-${var.app_suffix}"
  location                           = each.value.location
  resource_group_name                = azurerm_resource_group.ai_rg.name
  sku_name                           = var.openai_sku
  local_authentication_enabled       = true
  public_network_access              = "Enabled"  # Enable for now, will be restricted by network ACLs
  outbound_network_access_restricted = true
  custom_subdomain_name              = "${each.value.name}-${var.app_suffix}"

  # Network ACLs: Allow access from APIM subnet via VNet peering
  network_acls {
    default_action = "Deny"
    virtual_network_rules {
      subnet_id = var.apim_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [custom_subdomain_name]
  }
}

# Diagnostic Settings for AI Services
resource "azurerm_monitor_diagnostic_setting" "ai_services_diag" {
  for_each            = var.openai_config
  name                = "${each.value.name}-diag-${var.app_suffix}"
  target_resource_id  = azurerm_ai_services.ai_services[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

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

# Content Filters (RAI Policies)
resource "azapi_resource" "ai_content_filter" {
  for_each  = var.openai_config
  type      = "Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01"
  parent_id = azurerm_ai_services.ai_services[each.key].id
  name      = local.rai_policy_names[each.key]

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

# Model Deployments
resource "azurerm_cognitive_deployment" "deploy" {
  for_each = local.service_deployments

  name                 = each.value.dep.deployment_name
  cognitive_account_id = azurerm_ai_services.ai_services[each.value.svc_key].id

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

  depends_on = [azapi_resource.ai_content_filter]
}

# Role Assignments for APIM to access AI services
resource "azurerm_role_assignment" "cognitive_services_openai_user" {
  for_each = var.openai_config

  scope                = azurerm_ai_services.ai_services[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.apim_principal_id
}
