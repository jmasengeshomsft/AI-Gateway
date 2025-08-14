output "apim_gateway_url" {
  value       = module.apim_gateway.apim_gateway_url
  description = "API Management Gateway URL"
}

output "apim_subscription_key" {
  value       = module.apim_gateway.subscription_key
  description = "API Management subscription key"
  sensitive   = true
}

output "subscription1_ai_services" {
  value       = module.ai_subscription_1.ai_services
  description = "AI services deployed in subscription 1"
}

output "subscription2_ai_services" {
  value       = module.ai_subscription_2.ai_services
  description = "AI services deployed in subscription 2"
}

output "subscription1_deployments" {
  value       = module.ai_subscription_1.deployments
  description = "Model deployments in subscription 1"
}

output "subscription2_deployments" {
  value       = module.ai_subscription_2.deployments
  description = "Model deployments in subscription 2"
}

output "backend_pools" {
  value = [
    module.ai_subscription_1.backend_config,
    module.ai_subscription_2.backend_config,
  ]
  description = "Backend pool configurations"
}

output "apim_resource_group" {
  value       = module.apim_gateway.resource_group_name
  description = "APIM resource group name"
}

output "ai_subscription1_resource_group" {
  value       = module.ai_subscription_1.resource_group_name
  description = "AI subscription 1 resource group name"
}

output "ai_subscription2_resource_group" {
  value       = module.ai_subscription_2.resource_group_name
  description = "AI subscription 2 resource group name"
}
