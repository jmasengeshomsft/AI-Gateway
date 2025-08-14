output "backend_config" {
  value = {
    subscription_id = var.subscription_id
    services = [
      for key, service in var.openai_config : {
        name     = service.name
        endpoint = azurerm_ai_services.ai_services[key].endpoint
        priority = service.priority
        weight   = service.weight
      }
    ]
  }
  description = "Backend configuration for APIM integration"
}

output "ai_services" {
  value = {
    for key, service in azurerm_ai_services.ai_services : key => {
      id       = service.id
      name     = service.name
      endpoint = service.endpoint
      location = service.location
    }
  }
  description = "AI services information"
}

output "resource_group_name" {
  value       = azurerm_resource_group.ai_rg.name
  description = "Resource group name"
}

output "deployments" {
  value = {
    for key, deployment in azurerm_cognitive_deployment.deploy : key => {
      name     = deployment.name
      model    = deployment.model[0].name
      version  = deployment.model[0].version
      capacity = deployment.sku[0].capacity
    }
  }
  description = "Deployed models information"
}
