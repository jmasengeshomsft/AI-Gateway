output "primary_resource_group" {
  value = {
    name         = azurerm_resource_group.rg.name
    location     = azurerm_resource_group.rg.location
    subscription = var.subscription_id
  }
  description = "Primary resource group information"
}

output "secondary_resource_group" {
  value = {
    name         = azurerm_resource_group.rg_secondary.name
    location     = azurerm_resource_group.rg_secondary.location
    subscription = var.secondary_subscription_id
  }
  description = "Secondary resource group information"
}

output "apim_gateway_url" {
  value = azapi_resource.apim.output.properties.gatewayUrl
  description = "API Management Gateway URL"
}

output "apim_subscription_key" {
  value = azurerm_api_management_subscription.apim-api-subscription-openai.primary_key
  description = "API Management subscription key"
  sensitive = true
}
