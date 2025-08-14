output "apim_id" {
  value       = azapi_resource.apim.id
  description = "API Management service ID"
}

output "apim_name" {
  value       = azapi_resource.apim.name
  description = "API Management service name"
}

output "apim_gateway_url" {
  value       = azapi_resource.apim.output.properties.gatewayUrl
  description = "API Management Gateway URL"
}

output "apim_principal_id" {
  value       = azapi_resource.apim.identity.0.principal_id
  description = "API Management service principal ID for role assignments"
}

output "apim_vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "APIM VNet ID for cross-subscription peering"
}

output "apim_vnet_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "APIM VNet name for peering"
}

output "apim_subnet_id" {
  value       = azurerm_subnet.subnet_apim.id
  description = "APIM subnet ID for cross-subscription networking"
}

output "private_endpoints_subnet_id" {
  value       = azurerm_subnet.subnet_private_endpoints.id
  description = "Private endpoints subnet ID"
}

output "resource_group_name" {
  value       = azurerm_resource_group.apim_rg.name
  description = "Resource group name"
}

output "subscription_key" {
  value       = azurerm_api_management_subscription.apim_api_subscription_openai.primary_key
  description = "API Management subscription key"
  sensitive   = true
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.apim_log_analytics.id
  description = "Log Analytics workspace ID for AI services diagnostics"
}
