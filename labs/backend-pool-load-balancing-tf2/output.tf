output "apim_resource_gateway_url" {
  value = azapi_resource.apim.output.properties.gatewayUrl
}

output "apim_subscription_key" {
  value     = azurerm_api_management_subscription.apim-api-subscription-openai.primary_key
  sensitive = true
}

output "primary_resource_group" {
  value = {
    name         = azurerm_resource_group.rg.name
    location     = azurerm_resource_group.rg.location
    subscription = var.subscription_id
  }
  description = "Primary resource group information"
}
