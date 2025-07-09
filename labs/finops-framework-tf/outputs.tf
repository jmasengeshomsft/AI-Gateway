output "application_insights_app_id" {
  description = "The Application ID of Application Insights"
  value       = azurerm_application_insights.main.app_id
}

output "application_insights_name" {
  description = "The name of Application Insights"
  value       = azurerm_application_insights.main.name
}

output "log_analytics_workspace_id" {
  description = "The customer ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "apim_service_id" {
  description = "The resource ID of the API Management service"
  value       = azapi_resource.apim.id
}

output "apim_gateway_url" {
  description = "The gateway URL of the API Management service"
  value       = azapi_resource.apim.output.properties.gatewayUrl
}

output "apim_subscriptions" {
  description = "List of APIM subscriptions with their keys"
  value = [
    for idx, subscription in var.apim_subscriptions_config : {
      name         = subscription.name
      display_name = subscription.display_name
      key          = azurerm_api_management_subscription.subscriptions[idx].primary_key
    }
  ]
  sensitive = true
}

# Note: DCR outputs have been removed as DCRs were causing deployment issues
# Custom tables can still be used for data ingestion via REST API or Azure Monitor Data Collection API
